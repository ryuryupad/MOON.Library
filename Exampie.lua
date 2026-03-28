-- [[ 🍁 Astralis v6.0: Astralis Edition ]] --
-- Developer: ryuryupad
-- Version: 6.0 (Refined with Amber-Black Theme)

local Players          = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer      = Players.LocalPlayer

-- ── 1. ライブラリ読み込み ────────────────────────
local success, Library = pcall(function()
    return loadstring(game:HttpGet(
        "https://raw.githubusercontent.com/ryuryupad/MOON.Library/main/Library.lua"
    ))()
end)

if not success or not Library then
    warn("MOON UI: Fatal Error - Could not load library.")
    return
end

-- ── 2. 固定キー / HWID ──────────────────────────
local HWID       = gethwid and gethwid() 
                   or game:GetService("RbxAnalyticsService"):GetClientId()
local correctKey = "KOHUB-TEST-KEY-2026"

-- ── 3. 🔱 起動アニメーション (PlayIntro) ────────────────
-- ウィンドウ作成の「前」に実行して、読み込み時間を演出に変える
Library:PlayIntro({
    Title    = "ASTRALIS",
    Subtitle = "v6.0 Amber-Black",
    Color    = Color3.fromRGB(255, 170, 0) -- 琥珀色
})

-- ── 4. ウィンドウ作成 (ASTRALIS 琥珀×漆黒カスタム) ───────────
local Window = Library:CreateWindow({
    Title    = "ASTRALIS",
    Subtitle = "v6.0  •  by ryuryupad",
    
    -- 【THEME: 琥珀 (Accent) & 漆黒 (Base)】
    Accent          = Color3.fromRGB(255, 170, 0),    -- 琥珀色
    BackgroundColor = Color3.fromRGB(5, 14, 26),     -- 漆黒
    TopbarColor     = Color3.fromRGB(8, 18, 32),     -- トップバー
    SidebarColor    = Color3.fromRGB(6, 15, 28),     -- サイドバー
    ContentColor    = Color3.fromRGB(4, 11, 22),     -- コンテンツ
    ElementColor    = Color3.fromRGB(10, 22, 38),    -- 要素背景
    
    Keybind  = Enum.KeyCode.RightShift,
    Neon     = true,
    Border   = { Type = "none" }, 

    UserPanel = { 
        Enabled = true, 
        Role = "Owner & Developer" 
    },

    -- 【KEY SYSTEM】
    KeySystem = {
        Enabled   = true,
        Key       = correctKey,
        Title     = "ASTRALIS AUTHENTICATION",
        GetKeyURL = "https://discord.gg/xxxxxxxx",
        Hint      = "Get Keyを押すとリンクがコピーされます。",
    },
})

-- ── 5. タブ作成 ──────────────────────────────────
local MainTab     = Window:CreateTab("Main",     "⚡")
local CombatTab   = Window:CreateTab("Combat",   "⚔")
local SettingsTab = Window:CreateTab("Settings", "⚙")

-- ══ Main Tab: Movement & World ══════════════════════
MainTab:Separator("MOVEMENT BOOST")

-- 死亡時対策を入れた実戦用スライダー
MainTab:Slider("Walk Speed", { min=16, max=250, default=16 }, function(v)
    local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
    if hum then hum.WalkSpeed = v end
end, "キャラクターの移動速度を変更します")

MainTab:Slider("Jump Power", { min=50, max=400, default=50 }, function(v)
    local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
    if hum then
        hum.UseJumpPower = true
        hum.JumpPower    = v
    end
end, "ジャンプ力を変更します")

local infJumpConn
MainTab:Toggle("Infinite Jump", false, function(v)
    _G.InfJump = v
    if v and not infJumpConn then
        infJumpConn = UserInputService.JumpRequest:Connect(function()
            local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
            if _G.InfJump and hum then
                hum:ChangeState(Enum.HumanoidStateType.Jumping)
            end
        end)
    elseif not v and infJumpConn then
        infJumpConn:Disconnect()
        infJumpConn = nil
    end
end, "空中で無限にジャンプを可能にします")

MainTab:Separator("WORLD")

MainTab:Button("Teleport to Spawn", function()
    if LocalPlayer.Character then
        LocalPlayer.Character:MoveTo(Vector3.new(0, 10, 0))
    end
    Window:Notify("Teleport", "スポーンに移動しました", 2)
end)

-- ══ Combat Tab: Aim Assist ════════════════════════
CombatTab:Separator("AIM ASSIST")

CombatTab:Toggle("Aimbot Enable", false, function(v)
    print("Aimbot Status:", v)
end)

CombatTab:Slider("Aimbot FOV", { min=10, max=600, default=100 }, function(v)
    -- FOV描画の更新ロジック
end, "エイムが吸い付く範囲(円)のサイズ")

CombatTab:Dropdown("Target Priority", {"Head", "Torso", "HumanoidRootPart"}, function(v)
    print("Targeting:", v)
end, "優先的に狙う部位を選択")

-- ══ Settings Tab: System ══════════════════════════
SettingsTab:Separator("SYSTEM")

SettingsTab:Accordion("Astralis v6 Changelogs", {
    "v6.0: MOON UI v3.0 へのアップグレード",
    "v6.0: Orion風 PlayIntro 琥珀エディション実装",
    "v6.0: キャラクター死亡後のスライダー不具合を修正済",
    "v6.0: 最小化バグをバッサリ修正",
})

SettingsTab:Button("Copy HWID", function()
    setclipboard(HWID)
    Window:Notify("System", "HWIDをコピーしました", 2)
end)

SettingsTab:Button("Destroy UI", function()
    if infJumpConn then infJumpConn:Disconnect() end
    local ui = game:GetService("CoreGui"):FindFirstChild("moon_ui") or LocalPlayer.PlayerGui:FindFirstChild("moon_ui")
    if ui then ui:Destroy() end
end)

-- ── 6. 👑 完了通知 ──────────────────────────────
-- イントロが完全に終わるタイミング（約2.5秒〜3秒）で通知を出す
task.spawn(function()
    task.wait(2.8)
    Window:Notify("Success", "Astralis v6.0 Loaded. Welcome, ryuryupad.", 4)
end)
