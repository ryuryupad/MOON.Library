-- ╔══════════════════════════════════════════════════════╗
-- ║          使用例  LocalScript  (v2.0)                 ║
-- ╚══════════════════════════════════════════════════════╝

local success, Library = pcall(function()
    return loadstring(game:HttpGet("https://raw.githubusercontent.com/ryuryupad/MOON.Library/main/Library.lua"))()
end)

if not success or not Library then
    warn("MOON UI: ライブラリの読み込みに失敗しました。")
    return
end
local Window = Library:CreateWindow({
    Title    = "MOON UI",
    Subtitle = "v2.1  •  by yourname",
    Color    = Color3.fromRGB(80, 160, 255),
    Keybind  = Enum.KeyCode.RightShift,
    Neon     = true,

    KeySystem = {
        Enabled = false,                    -- true でキー認証ON
        Key     = "MOON-2024-ULTRA",
        -- KeyList = "https://pastebin.com/raw/XXXXX",
        Title   = "MOON UI  •  Key Required",
        Hint    = "Discordサーバーでキーを入手してください",
    },
})

local MainTab   = Window:CreateTab("Main",     "⚡")
local CombatTab = Window:CreateTab("Combat",   "⚔")
local SettingsTab = Window:CreateTab("Settings","⚙")

-- ── Main ──────────────────────────────────
MainTab:Separator("Movement")

MainTab:Toggle("Infinite Jump", false, function(v)
    -- 処理
end, "空中でもジャンプできます")

-- ★ Sliderは {min=N, max=N} 形式で指定
MainTab:Slider("Walk Speed", { min=16, max=250 }, function(v)
    local c = game.Players.LocalPlayer.Character
    if c then c.Humanoid.WalkSpeed = v end
end, "移動速度")

MainTab:Slider("Jump Power", { min=50, max=400 }, function(v)
    local c = game.Players.LocalPlayer.Character
    if c then c.Humanoid.JumpPower = v end
end, "ジャンプ力")

MainTab:Separator("Misc")

MainTab:Dropdown("Select Server", {"Asia","EU","NA","SA"}, function(v)
    print("Server:", v)
end, "サーバー選択")

MainTab:Accordion("Changelogs", {
    "v2.1: Dropdown/Sliderバグ修正",
    "v2.0: 起動アニメ・KEYシステム追加",
    "v1.0: 初回リリース",
})

MainTab:Button("Teleport to Spawn", function()
    local c = game.Players.LocalPlayer.Character
    if c then c:MoveTo(Vector3.new(0,5,0)) end
end)

-- ── Combat ────────────────────────────────
CombatTab:Separator("Aimbot")

CombatTab:Toggle("Aimbot", false, function(v) end)

CombatTab:Slider("FOV", { min=10, max=360 }, function(v)
    print("FOV:", v)
end, "エイムFOV範囲")

CombatTab:Dropdown("Target Part",
    {"Head","Torso","HumanoidRootPart"},
    function(v) print("Part:", v) end
)

-- ── Settings ──────────────────────────────
SettingsTab:Toggle("Show Notifications", true, function(v) end)

SettingsTab:Slider("UI Scale", { min=50, max=150 }, function(v)
    print("Scale:", v)
end, "UIの拡大縮小")

SettingsTab:Button("Unload UI", function()
    game.Players.LocalPlayer.PlayerGui.ryu_ui:Destroy()
end)
