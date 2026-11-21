// يشغّل Prince AI (CORE + GAME) بعالم وهمي يحاكي Roblox: شخصية علكانة وفارم Cupid شغال.
// يتأكد: الحواس تشتغل بدون أخطاء، Advise ما يلمس الشخصية، Auto-fix يرفعها، الحفظ والتبويب والأسئلة.
const fs = require('fs'), path = require('path');
const { lua, lauxlib, lualib, to_luastring } = require('fengari');
const src = (f) => fs.readFileSync(path.join(__dirname, '..', 'src', f), 'utf8');

const mock = `
local G = {}
function getgenv() return G end
function warn(...) end
local clock = 0
os.clock = function() return clock end
function ADVANCE(s) clock = clock + s end
local spawned = {}
task = {
  spawn = function(f, ...) spawned[#spawned + 1] = f end, -- الحلقات ما تشتغل بالاختبار
  delay = function(_, f) f() end,
  wait = function() end,
}
math.clamp = function(x, a, b) return math.max(a, math.min(b, x)) end
local V3 = {}
V3.__index = V3
V3.__add = function(a, b) return Vector3.new(a.X + b.X, a.Y + b.Y, a.Z + b.Z) end
Vector3 = { new = function(x, y, z) return setmetatable({ X = x or 0, Y = y or 0, Z = z or 0 }, V3) end }
local CF = {}
CF.__index = CF
CF.__add = function(a, v) return CFrame.new(a.Position.X + v.X, a.Position.Y + v.Y, a.Position.Z + v.Z) end
CFrame = { new = function(x, y, z)
  if type(x) == "table" then x, y, z = x.X, x.Y, x.Z end
  return setmetatable({ Position = Vector3.new(x, y, z) }, CF) end }
local function signal() return { Connect = function(_, f) return { Disconnect = function() end } end } end
HRP = { AssemblyLinearVelocity = Vector3.new(0, 0, 0) }
HRP.CFrame = CFrame.new(10, 100, 10)
setmetatable(HRP, { __index = function(t, k) if k == "Position" then return rawget(t, "CFrame").Position end end })
HUM = { Health = 1000, MaxHealth = 1000, Died = signal() }
local CHAR = { FindFirstChildOfClass = function(_, c) return c == "Humanoid" and HUM or nil end,
  FindFirstChild = function(_, n) return n == "HumanoidRootPart" and HRP or nil end,
  WaitForChild = function() return HUM end }
PN_LocalPlayer = { Name = "Tester", Character = CHAR, CharacterAdded = signal(), GetNetworkPing = function() return 0.05 end }
TELEPORTED = false
local services = {
  Stats = { Network = { ServerStatsItem = { ["Data Ping"] = { GetValue = function() return 90 end } } } },
  RunService = { Heartbeat = signal() },
  TeleportService = { Teleport = function() TELEPORTED = true end },
}
game = { PlaceId = 7465136166, JobId = "j", GetService = function(_, n) return services[n] end }
workspace = { DistributedGameTime = 1200 }
PN_Saved = {}
SAVES = 0
function PN_save() SAVES = SAVES + 1 end
function PN_statValue(n) if n == "Level" then return 300 end if n == "Peli" then return 1000 end end
CUPID_ON = true
PN_Farms = { { id = "Cupid", active = function() return CUPID_ON end, lines = function() return { { "State", "farming" }, { "Kills", "5" } } end } }
Kaitun = { enabled = false }
PN_NoAuto = false
RESTARTED = 0
function kaitunStop() end function kaitunStart() end
function cupidStop() end function cupidStart() RESTARTED = RESTARTED + 1 end
function wavesStop() end function wavesStart() end function itStop() end function itStart() end
function impelApi() end function impelApply() end
Waves = { mode = "Solo" }
`;
const testBody = `
local R = {}
local function check(n, c, x) R[#R + 1] = (c and "OK" or "FAIL") .. "\\t" .. n .. "\\t" .. (tostring(x):gsub("\\n", " / ")) end
local AI = getgenv().PrinceAI
check("published in getgenv", AI ~= nil)
check("defaults: Advise, EN, on", AI.mode == "Advise" and AI.lang == "EN" and AI.enabled == true)
AI.start()
check("start creates brain", AI.brain ~= nil and AI.running == true)
local s = AI.sense(0)
check("sense: hp/pos/ping/farms", s.hp == 1000 and s.pos.y == 100 and s.ping == 90 and s.farms[1] == "Cupid", s.ping)
check("sense: progress from farm lines", s.progress["Cupid.Kills"] == "5" and s.progress.level == 300)

-- Advise: علكان 40 ثانية -> ينصح بس، ما يحرك الشخصية
for i = 1, 40 do ADVANCE(1); AI.step() end
check("advise: stuck found", AI.brain.plan and AI.brain.plan.action == "unstick", AI.brain:summary())
check("advise: character not moved", HRP.CFrame.Position.Y == 100, HRP.CFrame.Position.Y)

-- Auto-fix: يرفع الشخصية 25
AI.mode = "Auto-fix"
ADVANCE(1); AI.step()
check("auto-fix: lifted 25", HRP.CFrame.Position.Y == 125, HRP.CFrame.Position.Y)
check("auto-fix: budget used", AI.brain:budgetLeft() == 5, AI.brain:budgetLeft())
-- بعدين يبقى علكان -> يتعلم إن unstick ما نفع
for i = 1, 20 do ADVANCE(1); AI.step() end
local st = AI.brain.stats["stuck|unstick"]
local escalated = false
for _, h in ipairs(AI.brain.history) do if h.action == "restart_farm" and h.auto then escalated = true end end
check("learned unstick fails -> escalated to restart_farm alone", escalated and RESTARTED >= 1, RESTARTED)
check("learning saved", st and st.n >= 1 and PN_Saved.AI.stats == AI.brain.stats and SAVES > 0, st and (st.s .. "/" .. st.n))

-- خطأ بسجل الهب يوصل للعقل
PH_Log.add("module Cupid", "boom")
ADVANCE(1); AI.step()
check("hub errors reach the brain", #AI.brain.st.errors == 1, #AI.brain.st.errors)

-- restart_farm: يطفي ويشغل Cupid
local ok, msg = AI.ACT.restart_farm()
check("restart_farm restarts Cupid", ok and RESTARTED >= 1, msg)
-- rejoin بالدنجن ممنوع
game.PlaceId = 11424731604
local ok2 = AI.ACT.rejoin()
check("rejoin refused in dungeon", ok2 == false and TELEPORTED == false)
game.PlaceId = 7465136166

-- التبويب: mock للواجهة
local made = {}
local function box()
  local b = {}
  local function el() return { SetText = function(self, t) self.text = t end } end
  function b:AddLabel(t) local e = el(); e.text = t; made[#made + 1] = e; return e end
  function b:AddToggle(id, o) made[id] = o; return el() end
  function b:AddDropdown(id, o) made[id] = o; return el() end
  function b:AddSlider(id, o) made[id] = o; return el() end
  function b:AddInput(id, o) made[id] = o; return el() end
  function b:AddButton(o) made[o.Text] = o; return el() end
  return b
end
local tab = { AddLeftGroupbox = function() return box() end, AddRightGroupbox = function() return box() end }
local Lib = { Notify = function() end, ScreenGui = { Parent = {} } }
G.Library = Lib
AI.buildTab(tab, Lib)
check("tab: controls built", made.PN_AIEnabled and made.PN_AIMode and made.PN_AIAsk and made["Apply suggestion"] and made["Copy analysis"])
made.PN_AILang.Callback("AR")
check("tab: language saved", AI.lang == "AR" and PN_Saved.AI.lang == "AR")
made.PN_AIAsk.Callback("ليش واكف")
local answer = made[#made].text
check("tab: Ask answers in Arabic", type(answer) == "string" and answer:find("المشكلة", 1, true) ~= nil, answer)
G.setclipboard = nil
setclipboard = function(t) CLIP = t end
made["Copy analysis"].Func()
check("tab: copy analysis has history", CLIP and CLIP:find("history:", 1, true) ~= nil and CLIP:find("unstick", 1, true) ~= nil)
AI.stop()
check("stop", AI.running == false)
return table.concat(R, "\\n")
`;
const code = mock + '\nlocal function chunk()\n' + src('00_header.lua') + '\n' + src('newtabs/23_ai_core.lua') + '\n' + src('newtabs/24_ai_game.lua') + '\n' + testBody + '\nend\nreturn chunk()';
const L = lauxlib.luaL_newstate(); lualib.luaL_openlibs(L);
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
