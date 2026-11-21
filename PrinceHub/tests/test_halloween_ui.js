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
NumberSequence = { new = pass }
NumberSequenceKeypoint = { new = pass }
Vector2 = { new = function(x, y) return { X = x, Y = y } end }
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
  if k == "MouseEnter" or k == "MouseLeave" or k == "InputBegan" then local sg = signal(); p[k] = sg; return sg end
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

-- نافذة Linoria وهمية (نفس الترتيب)
local function mk(cls, props, parent) local o = Instance.new(cls); for k, v in pairs(props or {}) do o[k] = v end; o.Parent = parent; return o end
SG = mk("ScreenGui", {})
OUTER = mk("Frame", { Name = "Outer" }, SG)
INNER = mk("Frame", { Name = "Inner" }, OUTER)
TITLE = mk("TextLabel", { Text = "Prince Hub", Position = UDim2.new(0, 7, 0, 0) }, INNER)
local mso = mk("Frame", { Name = "MSO", Position = UDim2.new(0, 8, 0, 25) }, INNER)
local msi = mk("Frame", { Name = "MSI" }, mso)
TABBAR = mk("ScrollingFrame", { Name = "PrinceTabBar" }, msi)
mk("UIListLayout", {}, TABBAR)
MAINCOLOR = { r = 44, g = 32, b = 56 }
TABBTN = mk("Frame", { Name = "TabBtn", BackgroundColor3 = MAINCOLOR }, TABBAR)
mk("TextLabel", { Text = "Prince AI" }, TABBTN)
TABBTN2 = mk("Frame", { Name = "TabBtn2", BackgroundColor3 = { r = 1, g = 1, b = 1 } }, TABBAR)
mk("TextLabel", { Text = "Config" }, TABBTN2)
mk("TextButton", { Name = "PrinceTabArrow" }, msi)
CONTAINER = mk("Frame", { Name = "TabContainer" }, msi)
TF = mk("Frame", { Name = "TabFrame", Visible = true, Position = UDim2.fromOffset(0, 0) }, CONTAINER)
SIDE = mk("ScrollingFrame", { Name = "LeftSide" }, TF)
mk("UIListLayout", {}, SIDE)
BOX = mk("Frame", { Name = "BoxOuter" }, SIDE)
local boxInner = mk("Frame", { Name = "BoxInner" }, BOX)
HIGHLIGHT = mk("Frame", { Name = "Highlight", Size = UDim2.new(1, 0, 0, 2) }, boxInner)
BOXTITLE = mk("TextLabel", { Text = "Prince AI", Position = UDim2.new(0, 4, 0, 2) }, boxInner)
CLOSE = mk("TextButton", { Name = "PrinceClose", Text = "X" }, OUTER)
MINI = mk("TextButton", { Name = "PrinceMini", Text = "P", Visible = true }, SG)
mk("UICorner", {}, MINI); mk("UIStroke", {}, MINI)
STATS = mk("ScreenGui", { Name = "PrinceStatsGui" })
local sf = mk("Frame", { Name = "PrinceStats" }, STATS); mk("UIStroke", {}, sf); mk("UICorner", {}, sf)
local top = mk("Frame", { Name = "Top" }, sf); mk("TextLabel", { Text = "Prince Stats" }, top)
G.PrinceStatsGui = STATS
NOTIFY = mk("Frame", { Name = "NotificationArea" })
REMOVED = {}
SHOWN = 0
Window = { Tabs = { ["Prince AI"] = { ShowTab = function() SHOWN = SHOWN + 1 end }, Config = { ShowTab = function() SHOWN = SHOWN + 1 end } } }
Library = { MainWindowFrame = OUTER, ScreenGui = SG, NotificationArea = NOTIFY, MainColor = MAINCOLOR,
  RegistryMap = { [TITLE] = { Properties = { TextColor3 = "FontColor" } }, [HIGHLIGHT] = { Properties = { BackgroundColor3 = "AccentColor" } }, [BOXTITLE] = { Properties = { TextColor3 = "FontColor" } } },
  GetDarkerColor = function(_, c) return c end, RemoveFromRegistry = function(_, o) REMOVED[o] = true end }
US = {}
PrinceNewTabs = {}
PN_LocalPlayer = { DisplayName = "Prince" }
function PN_statValue(n) return 420 end
`;
const body = `
local R = {}
local function check(n, c, x) R[#R + 1] = (c and "OK" or "FAIL") .. "\\t" .. n .. "\\t" .. tostring(x) end
local C = PN_Halloween.C
check("default theme is Halloween + motion on", PrinceNewTabs.theme == "Halloween" and US.theme == "Halloween" and US.motion == true)
check("tokens from the prompt", C.bg.r == 11 and C.primary.r == 255 and C.primary.g == 117 and C.lavender.r == 196 and C.text.r == 245)
PrinceNewTabs.applyPalette(Library)
check("palette: pumpkin accent only", Library.AccentColor == C.primary)
check("palette: cards / raised / thin lines", Library.BackgroundColor == C.surface and Library.MainColor == C.raised and Library.OutlineColor == C.line)
check("palette: extra registry colors", Library.HWLavender == C.lavender and Library.HWText2 == C.text2)
Library.MainColor = MAINCOLOR -- نخلي مرجع التبويب المختار مثل Linoria
PN_Halloween.apply(Library, Window)
check("title: short display text in Fantasy", TITLE.Text == "PRINCE HUB" and TITLE.Font == "Font.Fantasy", TITLE.Text)
check("no emoji in title", not TITLE.Text:find("[\\240-\\244]"))
check("drawn pumpkin icon in header", INNER:FindFirstChild("HWPumpkin") ~= nil and INNER.HWPumpkin:FindFirstChild("Body") ~= nil)
check("pumpkin has stem + carved face", INNER.HWPumpkin:FindFirstChild("Stem") and INNER.HWPumpkin.Body:FindFirstChild("Mouth") and INNER.HWPumpkin.Body:FindFirstChild("Eye"))
check("rounded window + thin moonlit rim", INNER:FindFirstChild("HWCorner") and INNER:FindFirstChild("HWStroke") and INNER.HWStroke.Thickness == 1)
check("soft window shadow", OUTER:FindFirstChild("HWShadow") ~= nil)
local bg = INNER:FindFirstChild("HalloweenBG")
check("background layers: moon, clouds, fog", bg and bg:FindFirstChild("HWMoon") and bg:FindFirstChild("HWCloud") and bg:FindFirstChild("HWFog"))
local card = INNER:FindFirstChild("HWProfile")
check("profile: avatar initial + name + level pill", card and card.Avatar.Text == "P" and card.PlayerName.Text == "Prince" and card.Level ~= nil)
check("close is a ghost button", CLOSE.BackgroundTransparency == 1 and CLOSE.MouseEnter ~= nil)
check("content area is one calm surface", CONTAINER.BackgroundColor3 == C.bg2 and REMOVED[CONTAINER] == true)
check("card: rounded, thin border", BOX:GetAttribute("HWStyled") and BOX.BorderSizePixel == 0 and BOX:FindFirstChild("HWStroke").Thickness == 1)
check("card: short lavender accent instead of full orange line", HIGHLIGHT.Size.X.Offset == 18 and Library.RegistryMap[HIGHLIGHT].Properties.BackgroundColor3 == "HWLavender")
check("card title: GothamBold lavender", BOXTITLE.Font == "Font.GothamBold" and BOXTITLE.TextColor3 == C.lavender)
check("active tab: bar + orange text (not color only)", TABBTN.HWActiveBar.Visible == true and TABBTN:FindFirstChildOfClass("TextLabel").TextColor3 == C.primary)
check("inactive tab: muted, no bar", TABBTN2.HWActiveBar.Visible == false and TABBTN2:FindFirstChildOfClass("TextLabel").TextColor3 == C.text2)
Window.Tabs.Config:ShowTab()
check("ShowTab still runs the original", SHOWN == 1)
check("switching tab moves the indicator", TABBTN2.HWActiveBar.Visible == true and TABBTN.HWActiveBar.Visible == false)
check("tab transition starts 6px lower", TF.Position.Y.Offset == 6)
local late = Instance.new("Frame"); late.Parent = SIDE
check("card added later is styled", late:GetAttribute("HWStyled") == true)
local lateTab = Instance.new("Frame"); lateTab.Parent = TABBAR
check("tab added later is styled", lateTab:GetAttribute("HWStyled") == true)
local toast = Instance.new("Frame"); toast.Parent = NOTIFY
check("toast notifications rounded", toast:FindFirstChild("HWCorner") ~= nil)
check("mini button: drawn pumpkin, no emoji", MINI.Text == "" and MINI:FindFirstChild("HWPumpkin") ~= nil and MINI:FindFirstChild("HWGlow") ~= nil)
check("stats window: card style + pumpkin icon", STATS.PrinceStats.Top:FindFirstChild("HWPumpkin") ~= nil and STATS.PrinceStats.Top:FindFirstChildOfClass("TextLabel").TextColor3 == C.lavender)
for _ = 1, 40 do for _, co in ipairs(SPAWNED) do if coroutine.status(co) == "suspended" then coroutine.resume(co) end end end
local n = 0
for _, c in ipairs(bg:GetChildren()) do if c.Name == "HWEmber" then n = n + 1 end end
check("embers: few and capped", n >= 1 and n <= PN_Halloween.maxEmbers, n)
check("status colors", PrinceNewTabs.hwStatusColor("ok") == C.success and PrinceNewTabs.hwStatusColor("bad") == C.danger)
US.motion = false
TF.Position = UDim2.fromOffset(0, 0)
Window.Tabs["Prince AI"]:ShowTab()
check("reduced motion: no tab slide", TF.Position.Y.Offset == 0)
local before = #INNER:GetChildren()
pcall(PN_Halloween.apply, Library, Window)
check("apply twice is safe", #INNER:GetChildren() == before)
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
