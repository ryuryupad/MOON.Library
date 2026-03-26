-- ╔══════════════════════════════════════════════════════╗
-- ║          使用例  LocalScript  (v2.0)                 ║
-- ╚══════════════════════════════════════════════════════╝

local Library = loadstring(game:HttpGet("https://github.com/ryuryupad/MOON.Library/blob/main/Library.lua/raw"))()

-- ─── KEYシステム オン の例 ───────────────────────────
local Window = Library:CreateWindow({
    Title    = "MOON UI",                       -- カスタム名
    Subtitle = "v2.0  •  by yourname",          -- 起動アニメに表示
    Color    = Color3.fromRGB(80, 160, 255),    -- アクセントカラー
    Keybind  = Enum.KeyCode.RightShift,
    Neon     = true,

    KeySystem = {
        Enabled = true,                         -- false にすれば無効化
        Key     = "MOON-2024-ULTRA",            -- 定数キー
        -- KeyList = "https://pastebin.com/raw/XXXXX",  -- 外部リスト(改行区切り)
        Title   = "MOON UI  •  Key Required",
        Hint    = "Discordサーバーでキーを入手してください",
    },
})

-- タブ
local MainTab     = Window:CreateTab("Main",     "⚡")
local CombatTab   = Window:CreateTab("Combat",   "⚔")
local SettingsTab = Window:CreateTab("Settings", "⚙")

-- Main
MainTab:Separator("Movement")
MainTab:Toggle("Infinite Jump", false, function(v) print("InfJump:", v) end, "空中でもジャンプできます")
MainTab:Slider("Walk Speed", {16, 250}, function(v)
    local c = game.Players.LocalPlayer.Character
    if c then c.Humanoid.WalkSpeed = v end
end, "移動速度")
MainTab:Slider("Jump Power", {50, 400}, function(v)
    local c = game.Players.LocalPlayer.Character
    if c then c.Humanoid.JumpPower = v end
end, "ジャンプ力")

MainTab:Separator("Misc")
MainTab:Button("Teleport to Spawn", function()
    local c = game.Players.LocalPlayer.Character
    if c then c:MoveTo(Vector3.new(0,5,0)) end
end)
MainTab:Dropdown("Select Server", {"Asia","EU","NA"}, function(v) print("Server:", v) end, "サーバー選択")
MainTab:Accordion("Changelogs", {"v2.0: KEYシステム追加","v1.9: 起動アニメ実装","v1.0: 初回リリース"})

-- Combat
CombatTab:Separator("Aimbot")
CombatTab:Toggle("Aimbot", false, function(v) print("Aimbot:", v) end)
CombatTab:Slider("FOV", {10, 360}, function(v) print("FOV:", v) end, "エイムFOV範囲")
CombatTab:Dropdown("Target Part", {"Head","Torso","HumanoidRootPart"}, function(v) print("Part:", v) end)

-- Settings
SettingsTab:Toggle("Show Notifications", true, function(v) end, "通知を表示する")
SettingsTab:Button("Unload UI", function()
    game.Players.LocalPlayer.PlayerGui.ryu_ui:Destroy()
end)
