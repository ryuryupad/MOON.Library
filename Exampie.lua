-- [[ MOON UI v3.0: Astralis Edition Example ]] --
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

-- ── 2. 固定キー ──────────────────────────────────
local HWID       = gethwid and gethwid()
                   or game:GetService("RbxAnalyticsService"):GetClientId()
local correctKey = "KOHUB-TEST-KEY-2026"

-- ── 3. ウィンドウ作成 ────────────────────────────
local Window = Library:CreateWindow({
    Title    = "ASTRALIS",
    Subtitle = "v6.0  •  by ryuryupad",
    Color    = Color3.fromRGB(80, 160, 255),
    Keybind  = Enum.KeyCode.RightShift,
    Neon     = true,

    -- グラデーション枠を使いたい場合はこちら (任意)
    -- Border = { Type = "rainbow" },
    -- Border = { Type = "gradient", Colors = { Color3.fromRGB(80,160,255), Color3.fromRGB(160,80,255) } },

    -- 左下ユーザーパネル (任意)
    -- UserPanel = { Enabled = true, Role = "Owner & Developer" },

    KeySystem = {
        Enabled   = true,
        Key       = correctKey,
        Title     = "ASTRALIS AUTHENTICATION",
        GetKeyURL = "https://xxxxxxxxxxxxxxxx",
        Hint      = "Get Keyを押すとリンクがコピーされます。",
    },
})

-- ── 4. タブ作成 ──────────────────────────────────
local MainTab     = Window:CreateTab("Main",     "⚡")
local CombatTab   = Window:CreateTab("Combat",   "⚔")
local SettingsTab = Window:CreateTab("Settings", "⚙")

-- ══ Main Tab ══════════════════════════════════════

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

-- FIX: コネクション漏れを修正 (Toggle毎に接続が増殖しない)
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
    MainTab:Notify("テレポート", "スポーンに移動しました", 2)
end)

-- ══ Combat Tab ════════════════════════════════════

CombatTab:Separator("AIM ASSIST")

CombatTab:Toggle("Aimbot Enable", false, function(v)
    print("Aimbot Status:", v)
end)

CombatTab:Slider("Aimbot FOV", { min=10, max=600 }, function(v)
    -- FOV描画の更新処理
end, "エイムが吸い付く範囲(円)のサイズ")

CombatTab:Dropdown("Target Priority", {"Head", "Torso", "HumanoidRootPart"}, function(v)
    print("Targeting:", v)
end, "優先的に狙う部位を選択")

-- ══ Settings Tab ══════════════════════════════════

SettingsTab:Separator("SYSTEM")

SettingsTab:Accordion("Astralis v6 Changelogs", {
    "v6.0: MOON UI v3.0 へのアップグレード",
    "v6.0: ColorPicker / Notify / Input 追加",
    "v6.0: グラデーション・虹色枠対応",
    "v6.0: 最小化バグ・認証灰色バグ修正",
})

SettingsTab:Button("Copy HWID", function()
    if setclipboard then
        setclipboard(HWID)
        SettingsTab:Notify("HWID", "クリップボードにコピーしました", 2)
    end
end)

SettingsTab:Button("Destroy UI", function()
    local pg = LocalPlayer:FindFirstChild("PlayerGui")
    -- v3.0 では "moon_ui" に変更
    local ui = pg and (pg:FindFirstChild("moon_ui") or pg:FindFirstChild("ryu_ui"))
    if ui then ui:Destroy() end
end)