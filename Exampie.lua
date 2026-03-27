-- [[ MOON UI v2.1: Astralis Edition Example ]] --
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

-- 1. ライブラリの読み込み
local success, Library = pcall(function()
    -- リポジトリから最新を読み込む
    return loadstring(game:HttpGet("https://raw.githubusercontent.com/ryuryupad/MOON.Library/main/Library.lua"))()
end)

if not success or not Library then
    warn("MOON UI: Fatal Error - Could not load library.")
    return
end

-- 2. 認証用データの動的生成 (Astralis v6 互換)
local HWID = gethwid and gethwid() or game:GetService("RbxAnalyticsService"):GetClientId()
local DATE = os.date("!%Y%m%d") -- UTC日付でJS側と同期
local SALT = "xxxxxxxxxxx"

-- 本来はここで correctKey を計算するロジックを入れる（前述の generateHash 関数を使用）
local correctKey = "KOHUB-TEST-KEY-2026" -- 実際には計算した値をここに入れる(固定キーなど）

-- 3. ウィンドウ作成
local Window = Library:CreateWindow({
    Title    = "ASTRALIS",
    Subtitle = "v6.0  •  by ryuryupad",
    Color    = Color3.fromRGB(80, 160, 255), -- ブルー
    Keybind  = Enum.KeyCode.RightShift,
    Neon     = true,

    KeySystem = {
        Enabled   = true, -- 認証を有効化
        Key       = correctKey,
        Title     = "ASTRALIS AUTHENTICATION",
        -- 改造したライブラリなら、ここに入れるだけでボタンが出る
        GetKeyURL = "https://ｘｘｘｘｘｘｘｘｘｘｘｘｘｘ",
        Hint      = "Get Keyを押すとリンクがコピーされます。",
    },
})

-- ── タブ作成 ──────────────────────────────
local MainTab     = Window:CreateTab("Main",     "⚡")
local CombatTab   = Window:CreateTab("Combat",   "⚔")
local SettingsTab = Window:CreateTab("Settings", "⚙")

-- ── Main Tab (Movement & Essentials) ──────
MainTab:Separator("MOVEMENT BOOST")

MainTab:Slider("Walk Speed", { min=16, max=250 }, function(v)
    local char = LocalPlayer.Character
    if char and char:FindFirstChild("Humanoid") then
        char.Humanoid.WalkSpeed = v
    end
end, "キャラクターの移動速度を変更します")

MainTab:Slider("Jump Power", { min=50, max=400 }, function(v)
    local char = LocalPlayer.Character
    if char and char:FindFirstChild("Humanoid") then
        char.Humanoid.UseJumpPower = true
        char.Humanoid.JumpPower = v
    end
end, "ジャンプ力を変更します")

MainTab:Toggle("Infinite Jump", false, function(v)
    _G.InfJump = v
    game:GetService("UserInputService").JumpRequest:Connect(function()
        if _G.InfJump then
            LocalPlayer.Character:FindFirstChildOfClass("Humanoid"):ChangeState("Jumping")
        end
    end)
end, "空中で無限にジャンプを可能にします")

MainTab:Separator("WORLD")

MainTab:Button("Teleport to Spawn", function()
    if LocalPlayer.Character then
        LocalPlayer.Character:MoveTo(Vector3.new(0, 10, 0))
    end
end)

-- ── Combat Tab (Aimbot & Visuals) ─────────
CombatTab:Separator("AIM ASSIST")

CombatTab:Toggle("Aimbot Enable", false, function(v)
    print("Aimbot Status:", v)
end)

CombatTab:Slider("Aimbot FOV", { min=10, max=600 }, function(v)
    -- FOV描画の更新処理など
end, "エイムが吸い付く範囲(円)のサイズ")

CombatTab:Dropdown("Target Priority", {"Head", "Torso", "HumanoidRootPart"}, function(v)
    print("Targeting:", v)
end, "優先的に狙う部位を選択")

-- ── Settings Tab (UI Customization) ───────
SettingsTab:Separator("SYSTEM")

SettingsTab:Accordion("Astralis v6 Changelogs", {
    "v6.0: 3層複合認証システム (UTC同期) 実装",
    "v6.0: MOON UI v2.1 へのアップグレード",
    "v6.0: JSFiddle連動型自動キー発行システム採用",
})

SettingsTab:Button("Copy HWID", function()
    setclipboard(HWID)
    -- ここでライブラリの通知機能があれば呼ぶ
end)

SettingsTab:Button("Destroy UI", function()
    local ui = PlayerGui:FindFirstChild("MOON_UI") or PlayerGui:FindFirstChild("ryu_ui")
    if ui then ui:Destroy() end
end)
