-- [[ MOON UI v3.0: Astralis Edition Example ]] --
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

-- ── 3. ウィンドウ作成 (ASTRALIS 琥珀×漆黒カスタム) ───────────
-- ここで設定した色が、起動アニメーションからキー認証まですべてに連動する
local Window = Library:CreateWindow({
    Title    = "ASTRALIS",
    Subtitle = "v6.0  •  by ryuryupad",
    
    -- 【THEME: 琥珀 (Accent) & 漆黒 (Base)】
    Accent          = Color3.fromRGB(255, 170, 0),    -- 琥珀色
    BackgroundColor = Color3.fromRGB(5, 14, 26),     -- メイン背景 (漆黒)
    TopbarColor     = Color3.fromRGB(8, 18, 32),     -- トップバー
    SidebarColor    = Color3.fromRGB(6, 15, 28),     -- サイドバー
    ContentColor    = Color3.fromRGB(4, 11, 22),     -- コンテンツエリア
    ElementColor    = Color3.fromRGB(10, 22, 38),    -- ボタン・スライダー等の背景
    
    Keybind  = Enum.KeyCode.RightShift,
    Neon     = true,

    -- グラデーション枠 (Astralisの硬派な印象を出すなら none または固定色)
    Border = { Type = "none" }, 

    -- 左下ユーザーパネル
    UserPanel = { 
        Enabled = true, 
        Role = "Owner & Developer" 
    },

    -- 【KEY SYSTEM: 起動アニメ後に自動実行】
    KeySystem = {
        Enabled   = true,
        Key       = correctKey,
        Title     = "ASTRALIS AUTHENTICATION",
        GetKeyURL = "https://discord.gg/xxxxxxxx", -- キー取得先
        Hint      = "Get Keyを押すとリンクがコピーされます。",
    },
})

-- ── 4. タブ作成 ──────────────────────────────────
local MainTab     = Window:CreateTab("Main",     "⚡")
local CombatTab   = Window:CreateTab("Combat",   "⚔")
local SettingsTab = Window:CreateTab("Settings", "⚙")

-- ══ Main Tab: Movement & World ══════════════════════
MainTab:Separator("MOVEMENT BOOST")

MainTab:Slider("Walk Speed", { min=16, max=250 }, function(v)
    local char = LocalPlayer.Character
    local hum  = char and char:FindFirstChildOfClass("Humanoid")
    if hum then hum.WalkSpeed = v end
end, "キャラクターの移動速度を変更します")

MainTab:Slider("Jump Power", { min=50, max=400 }, function(v)
    local char = LocalPlayer.Character
    local hum  = char and char:FindFirstChildOfClass("Humanoid")
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
            local hum = LocalPlayer.Character
                and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
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

CombatTab:Slider("Aimbot FOV", { min=10, max=600 }, function(v)
    -- FOV描画の更新ロジックをここに
end, "エイムが吸い付く範囲(円)のサイズ")

CombatTab:Dropdown("Target Priority", {"Head", "Torso", "HumanoidRootPart"}, function(v)
    print("Targeting:", v)
end, "優先的に狙う部位を選択")

-- ══ Settings Tab: System ══════════════════════════
SettingsTab:Separator("SYSTEM")

SettingsTab:Accordion("Astralis v6 Changelogs", {
    "v6.0: MOON UI v3.0 へのアップグレード",
    "v6.0: 起動アニメーションの漆黒×琥珀連動",
    "v6.0: キー認証システムの色化け修正済",
    "v6.0: ColorPicker / Notify / Input 追加",
    "v6.0: 最小化バグ・認証灰色バグをバッサリ修正",
})

SettingsTab:Button("Copy HWID", function()
    if setclipboard then
        setclipboard(HWID)
        Window:Notify("System", "HWIDをコピーしました", 2)
    end
end)

SettingsTab:Button("Destroy UI", function()
    local pg = LocalPlayer:FindFirstChild("PlayerGui")
    local ui = pg and (pg:FindFirstChild("moon_ui") or pg:FindFirstChild("ryu_ui"))
    if ui then ui:Destroy() end
end)

-- 最後に通知を飛ばして完了
Window:Notify("Success", "Astralis v6.0 Loaded Successfully.", 3)
