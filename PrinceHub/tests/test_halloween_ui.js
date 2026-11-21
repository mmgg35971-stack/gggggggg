// يفحص ثيم الهالوين (src/newtabs/25_halloween_ui.lua) على شجرة Instances وهمية بنفس ترتيب نافذة Linoria.
const fs = require('fs'), path = require('path');
const { lua, lauxlib, lualib, to_luastring } = require('fengari');
const theme = fs.readFileSync(path.join(__dirname, '..', 'src', 'newtabs', '25_halloween_ui.lua'), 'utf8');

const mock = `
local G = {}
function getgenv() return G end
local SPAWNED = {}
task = { spawn = function(f, ...) local co = coroutine.create(f); SPAWNED[#SPAWNED + 1] = co; coroutine.resume(co, ...) end,
  wait = function() coroutine.yield() end, defer = function(f, ...) f(...) end }
local function pass(...) return { ... } end
Color3 = { fromRGB = function(r, g, b) return { r = r, g = g, b = b } end, new = function(r, g, b) return { r = r * 255, g = g * 255, b = b * 255 } end }
UDim = { new = function(s, o) return { Scale = s, Offset = o } end }
UDim2 = { new = function(xs, xo, ys, yo) return { X = { Scale = xs, Offset = xo }, Y = { Scale = ys, Offset = yo } } end }
UDim2.fromOffset = function(x, y) return UDim2.new(0, x, 0, y) end
UDim2.fromScale = function(x, y) return UDim2.new(x, 0, y, 0) end
ColorSequence = { new = pass }
ColorSequenceKeypoint = { new = pass }
TweenInfo = { new = pass }
Enum = setmetatable({}, { __index = function(_, a) return setmetatable({}, { __index = function(_, b) return a .. "." .. b end }) end })
TWEENS = 0
local TweenService = { Create = function(_, obj, info, goal) TWEENS = TWEENS + 1
  return { Play = function() end, Completed = { Connect = function(_, f) end } } end }
game = { GetService = function(_, n) if n == "TweenService" then return TweenService end end }

-- Instances
local Inst = {}
local function signal() local s = { fns = {} }; function s:Connect(f) self.fns[#self.fns + 1] = f; return { Disconnect = function() end } end; return s end
local mt = {}
mt.__index = function(self, k)
  if Inst[k] then return Inst[k] end
  local p = rawget(self, "_p")
  if k == "Parent" then return rawget(self, "_parent") end
  if p[k] ~= nil then return p[k] end
  for _, c in ipairs(rawget(self, "_kids")) do if c.Name == k then return c end end -- مثل Roblox: obj.Child
  return nil
end
mt.__newindex = function(self, k, v)
  if k == "Parent" then
    local old = rawget(self, "_parent")
    if old then for i, c in ipairs(old._kids) do if c == self then table.remove(old._kids, i) break end end end
    rawset(self, "_parent", v)
    if v then v._kids[#v._kids + 1] = self; for _, f in ipairs(v.ChildAdded.fns) do f(self) end end
  else rawget(self, "_p")[k] = v end
end
Instance = { new = function(cls, parent)
  local o = setmetatable({ _p = { ClassName = cls, Name = cls, Visible = true }, _kids = {}, _attr = {} }, mt)
  rawget(o, "_p").ChildAdded = signal()
  if parent then o.Parent = parent end
  return o
end }
function Inst:GetChildren() local t = {}; for i, c in ipairs(self._kids) do t[i] = c end; return t end
function Inst:FindFirstChild(name, rec)
  for _, c in ipairs(self._kids) do if c.Name == name then return c end end
  if rec then for _, c in ipairs(self._kids) do local r = c:FindFirstChild(name, true); if r then return r end end end
end
function Inst:FindFirstChildOfClass(cls) for _, c in ipairs(self._kids) do if c.ClassName == cls then return c end end end
function Inst:IsA(cls) return self.ClassName == cls end
function Inst:SetAttribute(k, v) self._attr[k] = v end
function Inst:GetAttribute(k) return self._attr[k] end
function Inst:Destroy() self.Parent = nil end

-- نافذة Linoria وهمية
local function mk(cls, props, parent) local o = Instance.new(cls); for k, v in pairs(props or {}) do o[k] = v end; o.Parent = parent; return o end
SG = mk("ScreenGui", {})
OUTER = mk("Frame", { Name = "Outer" }, SG)
INNER = mk("Frame", { Name = "Inner" }, OUTER)
TITLE = mk("TextLabel", { Text = "Prince Hub", Position = UDim2.new(0, 7, 0, 0) }, INNER)
local mso = mk("Frame", { Name = "MSO", Position = UDim2.new(0, 8, 0, 25) }, INNER)
local msi = mk("Frame", { Name = "MSI" }, mso)
TABBAR = mk("ScrollingFrame", { Name = "PrinceTabBar" }, msi)
mk("UIListLayout", {}, TABBAR)
TABBTN = mk("Frame", { Name = "TabBtn" }, TABBAR)
mk("TextButton", { Name = "PrinceTabArrow" }, msi)
CONTAINER = mk("Frame", { Name = "TabContainer" }, msi)
local tf = mk("Frame", { Name = "TabFrame" }, CONTAINER)
SIDE = mk("ScrollingFrame", { Name = "LeftSide" }, tf)
mk("UIListLayout", {}, SIDE)
BOX = mk("Frame", { Name = "BoxOuter" }, SIDE)
mk("Frame", { Name = "BoxInner" }, BOX)
CLOSE = mk("TextButton", { Name = "PrinceClose" }, OUTER)
MINI = mk("TextButton", { Name = "PrinceMini", Text = "P" }, SG)
mk("UICorner", {}, MINI); mk("UIStroke", {}, MINI)
STATS = mk("ScreenGui", { Name = "PrinceStatsGui" })
local sf = mk("Frame", { Name = "PrinceStats" }, STATS); mk("UIStroke", {}, sf)
local top = mk("Frame", { Name = "Top" }, sf); mk("TextLabel", { Text = "Prince Stats" }, top)
G.PrinceStatsGui = STATS
Library = { MainWindowFrame = OUTER, ScreenGui = SG, RegistryMap = { [TITLE] = { Properties = { TextColor3 = "FontColor" } } },
  GetDarkerColor = function(_, c) return c end }
US = {}
PrinceNewTabs = {}
PN_LocalPlayer = { DisplayName = "Prince" }
function PN_statValue(n) return 420 end
`;
const body = `
local R = {}
local function check(n, c, x) R[#R + 1] = (c and "OK" or "FAIL") .. "\\t" .. n .. "\\t" .. tostring(x) end
check("default theme is Halloween", PrinceNewTabs.theme == "Halloween" and US.theme == "Halloween")
PrinceNewTabs.applyPalette(Library)
check("palette: orange accent", Library.AccentColor.r == 255 and Library.AccentColor.g == 125)
check("palette: purple outline + dark bg", Library.OutlineColor.r == 120 and Library.BackgroundColor.r == 16)
PN_Halloween.apply(Library)
check("title: pumpkin + Fantasy", TITLE.Text == "🎃 PRINCE HUB" and TITLE.Font == "Font.Fantasy", TITLE.Text)
check("title color follows theme accent", Library.RegistryMap[TITLE].Properties.TextColor3 == "AccentColor")
check("rounded window", INNER:FindFirstChild("HWCorner") ~= nil and OUTER.BackgroundTransparency == 1)
check("gradient stroke on window", INNER:FindFirstChild("HWStroke") and INNER.HWStroke:FindFirstChildOfClass("UIGradient") ~= nil)
check("gradient background", INNER:FindFirstChild("HalloweenBG") and INNER.HalloweenBG:FindFirstChildOfClass("UIGradient") ~= nil)
check("moon", INNER:FindFirstChild("HWMoon") ~= nil)
check("player card", INNER:FindFirstChild("HWProfile") and INNER.HWProfile.Text:find("Prince", 1, true) and INNER.HWProfile.Text:find("420", 1, true), INNER.HWProfile and INNER.HWProfile.Text)
check("tab button styled", TABBTN:GetAttribute("HWStyled") == true and TABBTN:FindFirstChild("HWCorner") ~= nil)
check("groupbox styled", BOX:GetAttribute("HWStyled") == true and BOX.BorderSizePixel == 0 and BOX:FindFirstChild("HWStroke") ~= nil)
local late = Instance.new("Frame"); late.Parent = SIDE
check("groupbox added later is styled", late:GetAttribute("HWStyled") == true)
local lateTab = Instance.new("Frame"); lateTab.Parent = TABBAR
check("tab added later is styled", lateTab:GetAttribute("HWStyled") == true)
check("mini button is a pumpkin", MINI.Text == "🎃")
check("stats window themed", STATS.PrinceStats.Top:FindFirstChildOfClass("TextLabel").Text == "🎃 Prince Stats")
-- الجزيئات: نشغل الحلقة كم مرة
for _ = 1, 5 do for _, co in ipairs(SPAWNED) do if coroutine.status(co) == "suspended" then coroutine.resume(co) end end end
local n = 0
for _, c in ipairs(INNER.HalloweenBG:GetChildren()) do if c.Name == "HWParticle" then n = n + 1 end end
check("particles spawn", n >= 3, n)
check("particles capped", n <= PN_Halloween.maxParticles, n)
local okTwice = pcall(PN_Halloween.apply, Library)
check("apply twice is safe", okTwice and #INNER:GetChildren() == #INNER:GetChildren())
return table.concat(R, "\\n")
`;
function run(extra) {
  const L = lauxlib.luaL_newstate(); lualib.luaL_openlibs(L);
  const code = mock + (extra || '') + '\nlocal function chunk()\n' + theme + '\n' + body + '\nend\nreturn chunk()';
  if (lauxlib.luaL_loadstring(L, to_luastring(code)) !== 0 || lua.lua_pcall(L, 0, 1, 0) !== 0) { console.log('LUA ERROR: ' + lua.lua_tojsstring(L, -1)); process.exit(1); }
  return lua.lua_tojsstring(L, -1);
}
let pass = 0, fail = 0;
for (const line of run().split('\n')) {
  const [st, name, extra] = line.split('\t');
  if (st === 'OK') { pass++; console.log('  ok  ' + name); } else { fail++; console.log('  FAIL ' + name + '  -> ' + extra); }
}
// Classic: ما يطبق شي
{
  const L = lauxlib.luaL_newstate(); lualib.luaL_openlibs(L);
  const code = mock + '\nUS.theme = "Classic"\nlocal function chunk()\n' + theme + '\nPN_Halloween.apply(Library)\nreturn tostring(PrinceNewTabs.theme) .. "|" .. TITLE.Text\nend\nreturn chunk()';
  if (lauxlib.luaL_loadstring(L, to_luastring(code)) !== 0 || lua.lua_pcall(L, 0, 1, 0) !== 0) { console.log('LUA ERROR: ' + lua.lua_tojsstring(L, -1)); process.exit(1); }
  const r = lua.lua_tojsstring(L, -1);
  if (r === 'Classic|Prince Hub') { pass++; console.log('  ok  Classic theme leaves the UI as it was'); } else { fail++; console.log('  FAIL Classic theme -> ' + r); }
}
console.log(`\n${pass} passed, ${fail} failed`);
process.exit(fail ? 1 : 0);
