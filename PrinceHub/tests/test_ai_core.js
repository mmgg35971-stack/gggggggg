// يشغّل tests/ai_scenarios.lua على عقل Prince AI (src/newtabs/23_ai_core.lua) بـ Lua 5.3 (fengari)
const fs = require('fs'), path = require('path');
const { lua, lauxlib, lualib, to_luastring } = require('fengari');
const core = fs.readFileSync(path.join(__dirname, '..', 'src', 'newtabs', '23_ai_core.lua'), 'utf8');
const tests = fs.readFileSync(path.join(__dirname, 'ai_scenarios.lua'), 'utf8');
const L = lauxlib.luaL_newstate(); lualib.luaL_openlibs(L);
const code = core + `
local results = (function()
${tests}
end)()
local out = {}
for _, r in ipairs(results) do
  out[#out + 1] = (r.ok and "OK" or "FAIL") .. "\\t" .. r.name .. "\\t" .. (tostring(r.extra == nil and "" or r.extra):gsub("\\n", " / "))
end
return table.concat(out, "\\n")`;
if (lauxlib.luaL_loadstring(L, to_luastring(code)) !== 0 || lua.lua_pcall(L, 0, 1, 0) !== 0) {
  console.log('LUA ERROR: ' + lua.lua_tojsstring(L, -1)); process.exit(1);
}
let pass = 0, fail = 0;
for (const line of lua.lua_tojsstring(L, -1).split('\n')) {
  const [st, name, extra] = line.split('\t');
  if (st === 'OK') { pass++; console.log('  ok  ' + name); } else { fail++; console.log('  FAIL ' + name + '  -> ' + extra); }
}
console.log(`\n${pass} passed, ${fail} failed`);
process.exit(fail ? 1 : 0);
