// يفحص hideMenuOnLoad (src/modules/07_Hub.lua): يخفي القائمة مرة وحدة بس، حتى لو انطلب مرتين،
// ويعيد المحاولة إذا أنيميشن الفتح بعده شغّال.
const fs = require('fs'), path = require('path');
const { lua, lauxlib, lualib, to_luastring } = require('fengari');
const hub = fs.readFileSync(path.join(__dirname, '..', 'src', 'modules', '07_Hub.lua'), 'utf8');
const m = hub.match(/local function hideMenuOnLoad\(\)\n[\s\S]*?\nend\n/);
if (!m) { console.log('FAIL hideMenuOnLoad not found'); process.exit(1); }

function run(setup, calls) {
  const L = lauxlib.luaL_newstate(); lualib.luaL_openlibs(L);
  const code = `
    task = { wait = function() Library._clock = Library._clock + 1 end }
    Library = { _clock = 0, toggles = 0, fadingUntil = 0 }
    function Library:Toggle()
      if self._clock < self.fadingUntil then return end -- مثل Linoria: يتجاهل وقت الأنيميشن
      self.toggles = self.toggles + 1
      self.Toggled = not self.Toggled
    end
    ${setup}
    ${m[0]}
    ${calls}
    return tostring(Library.Toggled) .. "," .. Library.toggles`;
  if (lauxlib.luaL_loadstring(L, to_luastring(code)) !== 0 || lua.lua_pcall(L, 0, 1, 0) !== 0) throw new Error(lua.lua_tojsstring(L, -1));
  return lua.lua_tojsstring(L, -1);
}
let pass = 0, fail = 0;
const check = (n, got, want) => { if (got === want) { pass++; console.log('  ok  ' + n); } else { fail++; console.log(`  FAIL ${n}: got ${got} want ${want}`); } };

check('open menu gets hidden', run('Library.Toggled = true', 'hideMenuOnLoad()'), 'false,1');
check('saved toggle + Config.AUTO_HIDE_UI: stays hidden', run('Library.Toggled = true', 'hideMenuOnLoad(); hideMenuOnLoad()'), 'false,1');
check('never shown: not opened', run('', 'hideMenuOnLoad()'), 'nil,0');
check('retries while fading', run('Library.Toggled = true; Library.fadingUntil = 3', 'hideMenuOnLoad()'), 'false,1');
console.log(`\n${pass} passed, ${fail} failed`); process.exit(fail ? 1 : 0);
