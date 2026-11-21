// يفحص CORE (src/00_header.lua) بـ Lua 5.3 (fengari) ويا mock بسيط لـ Roblox:
// منع التشغيل مرتين، ForceReload، وسجل الأخطاء PH_try / PH_Log.
const fs = require('fs'), path = require('path');
const { lua, lauxlib, lualib, to_luastring } = require('fengari');
const header = fs.readFileSync(path.join(__dirname, '..', 'src', '00_header.lua'), 'utf8');

function run(prelude, body) {
  const L = lauxlib.luaL_newstate();
  lualib.luaL_openlibs(L);
  const code = `
    local G = {}
    function getgenv() return G end
    game = { PlaceId = 123, JobId = "job" }
    warns = {}
    function warn(...) warns[#warns+1] = table.concat({...}, " ") end
    RESULT = {}
    ${prelude}
    local function chunk()
      ${header}
      ${body}
    end
    chunk()
    RESULT.G = G`;
  if (lauxlib.luaL_loadstring(L, to_luastring(code)) !== 0 || lua.lua_pcall(L, 0, 0, 0) !== 0) {
    throw new Error(lua.lua_tojsstring(L, -1));
  }
  const get = (expr) => {
    lauxlib.luaL_loadstring(L, to_luastring('return ' + expr));
    lua.lua_call(L, 0, 1);
    const t = lua.lua_type(L, -1);
    const v = t === lua.LUA_TNIL ? null : t === lua.LUA_TBOOLEAN ? lua.lua_toboolean(L, -1) : lua.lua_tojsstring(L, -1);
    lua.lua_pop(L, 1);
    return v;
  };
  return get;
}

let pass = 0, fail = 0;
function check(name, cond) { if (cond) { pass++; console.log('  ok  ' + name); } else { fail++; console.log('  FAIL ' + name); } }

// 1) أول تشغيل: يكمل
let g = run('', 'RESULT.reached = true');
check('first run continues', g('RESULT.reached') === true);
check('log is published in getgenv', g('RESULT.G.PrinceHubLog ~= nil') === true);

// 2) الهب شغّال: النسخة الثانية توكف
g = run('G.PrinceHubInstance = { version = "v18", alive = function() return true end }', 'RESULT.reached = true');
check('second run is blocked while hub is alive', g('RESULT.reached') === null);
check('second run warns', /already running/.test(g('warns[1]')));

// 3) الهب انشال (Unload): يكمل
g = run('G.PrinceHubInstance = { alive = function() return false end }', 'RESULT.reached = true');
check('runs again after Unload', g('RESULT.reached') === true);

// 4) alive يطلع خطأ: نعتبره مو شغّال
g = run('G.PrinceHubInstance = { alive = function() error("gone") end }', 'RESULT.reached = true');
check('broken alive() does not block', g('RESULT.reached') === true);

// 5) ForceReload يتجاوز المنع ويتصفّر
g = run('G.PrinceHubInstance = { alive = function() return true end }; G.PrinceHubForceReload = true', 'RESULT.reached = true');
check('ForceReload bypasses guard', g('RESULT.reached') === true);
check('ForceReload is reset after use', g('RESULT.G.PrinceHubForceReload') === null);

// 6) PH_try: نجاح يرجع القيم، والخطأ ينسجل ويا traceback
g = run('', `
  local ok, a, b = PH_try("t1", function(x, y) return x + y, "z" end, 2, 3)
  RESULT.ok1, RESULT.a, RESULT.b = ok, a, b
  local ok2, err = PH_try("t2", function() error("boom") end)
  RESULT.ok2, RESULT.err = ok2, err
  RESULT.n = #PH_Log.entries
  RESULT.where = PH_Log.entries[1].where
  RESULT.report = PH_Log.report()
  for i = 1, 100 do PH_Log.add("spam", i) end
  RESULT.capped = #PH_Log.entries`);
check('PH_try returns results', g('RESULT.ok1') === true && g('RESULT.a') === '5' && g('RESULT.b') === 'z');
check('PH_try catches error', g('RESULT.ok2') === false && /boom/.test(g('RESULT.err')));
check('error has traceback', /traceback/.test(g('RESULT.err')));
check('error is logged once', g('RESULT.n') === '1' && g('RESULT.where') === 't2');
check('report has version and error', /Prince Hub v18/.test(g('RESULT.report')) && /\[t2\] .*boom/.test(g('RESULT.report')));
check('log is capped at 60', g('RESULT.capped') === '60');

console.log(`\n${pass} passed, ${fail} failed`);
process.exit(fail ? 1 : 0);
