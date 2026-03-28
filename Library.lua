-- ╔══════════════════════════════════════════════════════════════╗
-- ║              MOON UI Library  (v3.0)                        ║
-- ║  by ryuryupad  |  完全リビルド版                            ║
-- ╚══════════════════════════════════════════════════════════════╝
--[[
  変更点 (v2.1 → v3.0)
  ────────────────────────────────────────────────────────────────
  BUG FIX
  [1] キー認証後に画面が灰色になる問題を修正
      → overlay の ZIndex 管理と Destroy タイミングを修正
  [2] 最小化時に角が尖る問題を修正
      → ClipsDescendants を使わず contentWrapper を隠す方式に変更
  [3] 最小化が機能しない問題を修正
      → minimized フラグと Tween の競合を解消
  [4] T.BG_TOP 未定義バグを修正 → T.BG_TOPBAR に統一
  [5] ドラッグロジック二重定義を削除
  
  NEW FEATURES
  [6] 赤青緑トラフィックドットを削除
  [7] タブアイコン: テキスト絵文字 & 画像ID 両対応
  [8] グラデーション枠 (UIGradient) & 虹色対応
  [9] 左下ユーザーパネル (config.UserPanel で ON/OFF)
  [10] ColorPicker (RGBスライダー3本 + プレビュー)
  [11] Notify (右下トースト通知)
  [12] Input (TextBox付きコンポーネント)
  ────────────────────────────────────────────────────────────────
]]

local Players          = game:GetService("Players")
local TweenService     = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui   = LocalPlayer:WaitForChild("PlayerGui")

-- ══════════════════════════════════════════════════════════════
--  ユーティリティ
-- ══════════════════════════════════════════════════════════════
local TW_FAST = TweenInfo.new(0.12, Enum.EasingStyle.Quad,  Enum.EasingDirection.Out)
local TW_MED  = TweenInfo.new(0.22, Enum.EasingStyle.Quad,  Enum.EasingDirection.Out)
local TW_SLOW = TweenInfo.new(0.50, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)

local function tw(obj, props, info)
    if not obj or not obj.Parent then return end
    TweenService:Create(obj, info or TW_FAST, props):Play()
end
local function twWait(obj, props, info)
    if not obj or not obj.Parent then return end
    local t = TweenService:Create(obj, info or TW_FAST, props)
    t:Play(); t.Completed:Wait()
end
local function make(class, props, parent)
    local o = Instance.new(class)
    for k, v in pairs(props) do
        pcall(function() o[k] = v end)
    end
    if parent then o.Parent = parent end
    return o
end
local function corner(r, p)
    return make("UICorner", { CornerRadius = UDim.new(0, r) }, p)
end
local function uiStroke(color, thick, p)
    return make("UIStroke", {
        Color = color, Thickness = thick or 0.8,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
    }, p)
end
local function pad(t, b, l, r, p)
    return make("UIPadding", {
        PaddingTop    = UDim.new(0, t), PaddingBottom = UDim.new(0, b),
        PaddingLeft   = UDim.new(0, l), PaddingRight  = UDim.new(0, r),
    }, p)
end
local function dimColor(c, f)
    f = f or 0.25
    return Color3.new(c.R*f, c.G*f, c.B*f)
end
local function lightenColor(c, f)
    f = f or 0.35
    return Color3.new(math.min(c.R+f,1), math.min(c.G+f,1), math.min(c.B+f,1))
end
local function rgb(r,g,b) return Color3.fromRGB(r,g,b) end

-- グリッチテキスト
local GLITCH_CHARS = "!<>-_\\/[]{}—=+*^?#"
local function glitchText(label, finalText, duration)
    local steps = math.floor(duration / 0.04)
    task.spawn(function()
        for i = 1, steps do
            local revealed = math.floor(#finalText * (i/steps))
            local result   = string.sub(finalText, 1, revealed)
            for _ = 1, #finalText - revealed do
                result = result .. string.sub(GLITCH_CHARS,
                    math.random(1,#GLITCH_CHARS), math.random(1,#GLITCH_CHARS))
            end
            label.Text = result
            task.wait(0.04)
        end
        label.Text = finalText
    end)
end

-- グラデーションストローク用 ColorSequence
local function rainbowColorSequence()
    local kp = {}
    local colors = {
        rgb(255,0,0), rgb(255,128,0), rgb(255,255,0),
        rgb(0,255,0), rgb(0,200,255), rgb(128,0,255), rgb(255,0,0)
    }
    for i, c in ipairs(colors) do
        table.insert(kp, ColorSequenceKeypoint.new((i-1)/(#colors-1), c))
    end
    return ColorSequence.new(kp)
end

local function gradientColorSequence(c1, c2)
    return ColorSequence.new({
        ColorSequenceKeypoint.new(0, c1),
        ColorSequenceKeypoint.new(1, c2),
    })
end

-- ══════════════════════════════════════════════════════════════
--  Library
-- ══════════════════════════════════════════════════════════════
local Library = {}

-- ──────────────────────────────────────────────────────────────
--  グローバル Notify (Window外からも呼べるように後で差し替え)
-- ──────────────────────────────────────────────────────────────
local _notifyFn = nil
function Library:Notify(title, content, duration)
    if _notifyFn then _notifyFn(title, content, duration) end
end

function Library:CreateWindow(config)
    config = config or {}

    local Title      = config.Title      or "MOON UI"
    local Subtitle   = config.Subtitle   or "v3.0"
    local Accent     = config.Color      or rgb(40, 130, 255)
    local Keybind    = config.Keybind    or Enum.KeyCode.RightShift
    local Neon       = config.Neon       ~= nil and config.Neon or false
    local KeyConfig  = config.KeySystem  or { Enabled = false }
    local UserPanel  = config.UserPanel  or { Enabled = false }

    -- グラデーション枠設定
    -- config.Border = { Type="gradient", Colors={c1,c2} } or { Type="rainbow" } or nil(通常)
    local BorderCfg  = config.Border or { Type = "solid" }

  -- ── テーマ (ここを書き換え) ──────────────────────
    local T = {
        -- 背景色シリーズ：config から取得、なければデフォルト
        BG_MAIN      = config.BackgroundColor or rgb(5, 14, 26),
        BG_TOPBAR    = config.TopbarColor      or rgb(8, 18, 32),
        BG_SIDEBAR   = config.SidebarColor     or rgb(6, 15, 28),
        BG_CONTENT   = config.ContentColor     or rgb(4, 11, 22),
        BG_ELEMENT   = config.ElementColor     or rgb(10, 22, 38),
        BG_ELEMENT_H = config.ElementHoverColor or rgb(16, 32, 54),
        
        BORDER       = rgb(28, 46, 72),
        TEXT_P       = rgb(210, 220, 235),
        TEXT_S       = rgb(110, 130, 160),
        TEXT_M       = rgb(55, 75, 105),
        
        ACCENT       = Accent,
        ACCENT_DIM   = dimColor(Accent, 0.22),
        ACCENT_TEXT  = lightenColor(Accent, 0.35),
        
        STATUS_GREEN = rgb(40, 200, 100),
        STATUS_RED   = rgb(220, 60, 60),
    }

    local gui = make("ScreenGui", {
        Name = "moon_ui", ResetOnSpawn = false,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        IgnoreGuiInset = true,
        DisplayOrder = 10,
    }, PlayerGui)

    -- ══════════════════════════════
    --  Notify システム (右下トースト)
    -- ══════════════════════════════

    local gui = make("ScreenGui", {
        Name = "moon_ui", ResetOnSpawn = false,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        IgnoreGuiInset = true,
        DisplayOrder = 10,
    }, PlayerGui)

    -- ══════════════════════════════
    --  Notify システム (右下トースト)
    -- ══════════════════════════════
    local notifyContainer = make("Frame", {
        Size = UDim2.new(0, 300, 1, 0),
        Position = UDim2.new(1, -310, 0, 0),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ZIndex = 500,
    }, gui)
    make("UIListLayout", {
        SortOrder = Enum.SortOrder.LayoutOrder,
        VerticalAlignment = Enum.VerticalAlignment.Bottom,
        Padding = UDim.new(0, 6),
    }, notifyContainer)
    pad(0, 12, 0, 0, notifyContainer)

    local notifyCount = 0
    local function doNotify(title, content, duration)
        duration = duration or 3
        notifyCount += 1

        local nt = make("Frame", {
            Size = UDim2.new(1, 0, 0, 0),
            BackgroundColor3 = T.BG_ELEMENT,
            BorderSizePixel = 0,
            ClipsDescendants = true,
            LayoutOrder = notifyCount,
            BackgroundTransparency = 1,
            ZIndex = 501,
        }, notifyContainer)
        corner(10, nt)
        uiStroke(T.BORDER, 0.8, nt)

        -- アクセントライン
        local accentLine = make("Frame", {
            Size = UDim2.new(0, 3, 1, 0),
            BackgroundColor3 = Accent,
            BorderSizePixel = 0,
            ZIndex = 502,
        }, nt)
        corner(2, accentLine)

        make("TextLabel", {
            Text = title,
            TextSize = 13, Font = Enum.Font.GothamBold,
            TextColor3 = T.TEXT_P, BackgroundTransparency = 1,
            Size = UDim2.new(1, -20, 0, 20),
            Position = UDim2.new(0, 14, 0, 8),
            TextXAlignment = Enum.TextXAlignment.Left,
            ZIndex = 502,
        }, nt)
        make("TextLabel", {
            Text = content,
            TextSize = 11, Font = Enum.Font.Gotham,
            TextColor3 = T.TEXT_S, BackgroundTransparency = 1,
            Size = UDim2.new(1, -20, 0, 16),
            Position = UDim2.new(0, 14, 0, 30),
            TextXAlignment = Enum.TextXAlignment.Left,
            TextWrapped = true,
            ZIndex = 502,
        }, nt)

        -- 進捗バー
        local progTrack = make("Frame", {
            Size = UDim2.new(1, -14, 0, 2),
            Position = UDim2.new(0, 14, 1, -6),
            BackgroundColor3 = T.BORDER,
            BorderSizePixel = 0,
            ZIndex = 502,
        }, nt)
        corner(1, progTrack)
        local progFill = make("Frame", {
            Size = UDim2.new(1, 0, 1, 0),
            BackgroundColor3 = Accent,
            BorderSizePixel = 0,
            ZIndex = 503,
        }, progTrack)
        corner(1, progFill)

        task.spawn(function()
            -- 登場
            twWait(nt, { Size = UDim2.new(1, 0, 0, 58), BackgroundTransparency = 0 }, TW_MED)
            -- プログレス
            tw(progFill, { Size = UDim2.new(0, 0, 1, 0) },
                TweenInfo.new(duration, Enum.EasingStyle.Linear, Enum.EasingDirection.Out))
            task.wait(duration)
            -- 退場
            twWait(nt, { Size = UDim2.new(1, 0, 0, 0), BackgroundTransparency = 1 }, TW_MED)
            nt:Destroy()
        end)
    end
    _notifyFn = doNotify

-- ══════════════════════════════
    --  1. 起動アニメーション (連動版)
    -- ══════════════════════════════
-- [[ 1. 起動アニメーション (カスタムライブラリ版) ]]
-- 呼び出し例: Library:PlayIntro({Title = "MOON", Subtitle = "v3.0", Color = Color3.fromRGB(255, 200, 0)})

function Library:PlayIntro(config)
    local Title = config.Title or "MOON UI"
    local Subtitle = config.Subtitle or "Standard Edition"
    local AccentColor = config.Color or T.ACCENT
    
    local overlay = make("Frame", {
        Size = UDim2.new(1,0,1,0),
        BackgroundColor3 = T.BG_MAIN,
        BorderSizePixel = 0, ZIndex = 500,
    }, gui) -- guiはScreenGui

    -- Orionコンテナ (ロゴとタイトルのセット)
    local orionContainer = make("Frame", {
        Size = UDim2.new(0, 0, 0, 40),
        Position = UDim2.new(0.5, 0, 0.48, 0),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundTransparency = 1, ZIndex = 501,
    }, overlay)

    local logo = make("ImageLabel", {
        Size = UDim2.new(0, 32, 0, 32),
        Position = UDim2.new(0.5, 0, 0.5, 0),
        AnchorPoint = Vector2.new(0.5, 0.5),
        Image = "rbxassetid://8834748103", -- Orion Logo
        ImageColor3 = AccentColor,
        BackgroundTransparency = 1, ImageTransparency = 1,
        ZIndex = 502,
    }, orionContainer)

    local titleLbl = make("TextLabel", {
        Text = Title, TextSize = 32, Font = Enum.Font.GothamBold,
        TextColor3 = T.TEXT_P, BackgroundTransparency = 1,
        TextTransparency = 1, TextXAlignment = Enum.TextXAlignment.Left,
        AutomaticSize = Enum.AutomaticSize.X,
        Position = UDim2.new(0, 42, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5),
        ZIndex = 502,
    }, orionContainer)

    -- パーティクル生成 (背景の賑やかし)
    local particles = {}
    for _ = 1, 15 do
        local sz = math.random(2,4)
        local p = make("Frame", {
            Size = UDim2.new(0,sz,0,sz),
            Position = UDim2.new(math.random(0,100)/100, 0, math.random(0,100)/100, 0),
            BackgroundColor3 = AccentColor, BackgroundTransparency = 1,
            BorderSizePixel = 0, ZIndex = 501,
        }, overlay)
        corner(sz, p)
        table.insert(particles, p)
    end

    -- ── シーケンス開始 ──
    task.spawn(function()
        -- 1. ロゴ出現
        twWait(logo, { ImageTransparency = 0 }, TW_MED)
        task.wait(0.5)

        -- 2. Orionムーブ (スライド展開)
        local totalWidth = 32 + 12 + titleLbl.TextBounds.X
        tw(orionContainer, { Size = UDim2.new(0, totalWidth, 0, 40) }, TW_MED)
        tw(logo, { Position = UDim2.new(0, 0, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5) }, TW_MED)
        task.wait(0.1)
        tw(titleLbl, { TextTransparency = 0 }, TW_MED)
        
        -- パーティクルをフワッと出す
        for _, p in pairs(particles) do
            tw(p, { BackgroundTransparency = 0.6 }, TW_SLOW)
        end
        
        task.wait(1.5)

        -- 3. 撤収
        tw(overlay, { BackgroundTransparency = 1 }, TW_MED)
        tw(logo, { ImageTransparency = 1 }, TW_FAST)
        tw(titleLbl, { TextTransparency = 1 }, TW_FAST)
        for _, p in pairs(particles) do tw(p, { BackgroundTransparency = 1 }, TW_FAST) end
        
        task.wait(0.6)
        overlay:Destroy()
    end)
end
 -- ══════════════════════════════
    --  2. キー認証システム (完全版)
    -- ══════════════════════════════
    local function showKeySystem()
        local successSignal = Instance.new("BindableEvent")

        -- 背景オーバーレイ (ZIndexをintroより上に設定)
        local overlay = make("Frame", {
            Size=UDim2.new(1,0,1,0),
            BackgroundColor3=T.BG_MAIN, -- 漆黒
            BackgroundTransparency=0.05,
            BorderSizePixel=0, ZIndex=310,
        }, gui)

        -- メインカード
        local card = make("Frame", {
            Size=UDim2.new(0,380,0,230),
            Position=UDim2.new(0.5,-190,0.5,-115),
            BackgroundColor3=T.BG_CONTENT,
            BorderSizePixel=0, ZIndex=311,
            BackgroundTransparency=1,
        }, overlay)
        corner(14, card)
        uiStroke(T.BORDER, 1, card)
        
        -- フェードイン
        tw(card, { BackgroundTransparency=0 },
            TweenInfo.new(0.3,Enum.EasingStyle.Quad,Enum.EasingDirection.Out))

        -- 装飾用のトップライン (琥珀)
        local topLine = make("Frame", {
            Size=UDim2.new(1,0,0,2), BackgroundColor3=Accent,
            BorderSizePixel=0, ZIndex=312,
        }, card)
        corner(14, topLine)

        pad(20,20,24,24, card)

        -- タイトルとヒント
        make("TextLabel", {
            Text=KeyConfig.Title or "Key Required",
            TextSize=17, Font=Enum.Font.GothamBold,
            TextColor3=Accent, -- 琥珀
            BackgroundTransparency=1,
            Size=UDim2.new(1,0,0,26), Position=UDim2.new(0,0,0,14),
            TextXAlignment=Enum.TextXAlignment.Left, ZIndex=313,
        }, card)
        
        make("TextLabel", {
            Text=KeyConfig.Hint or "有効なキーを入力してください",
            TextSize=11, Font=Enum.Font.Gotham,
            TextColor3=T.TEXT_M, BackgroundTransparency=1,
            Size=UDim2.new(1,0,0,16), Position=UDim2.new(0,0,0,42),
            TextXAlignment=Enum.TextXAlignment.Left, ZIndex=313,
        }, card)

        -- 入力フィールド
        local inputBg = make("Frame", {
            Size=UDim2.new(1,0,0,38), Position=UDim2.new(0,0,0,70),
            BackgroundColor3=T.BG_ELEMENT, BorderSizePixel=0, ZIndex=313,
        }, card)
        corner(8, inputBg)
        local inputStroke = uiStroke(T.BORDER, 0.8, inputBg)

        local input = make("TextBox", {
            PlaceholderText="XXXX-XXXX-XXXX", Text="",
            TextSize=13, Font=Enum.Font.GothamBold,
            TextColor3=T.TEXT_P, PlaceholderColor3=T.TEXT_M,
            BackgroundTransparency=1,
            Size=UDim2.new(1,-16,1,0), Position=UDim2.new(0,10,0,0),
            TextXAlignment=Enum.TextXAlignment.Left,
            ClearTextOnFocus=false, ZIndex=314,
        }, inputBg)

        -- フォーカス演出
        input.Focused:Connect(function()  tw(inputStroke, { Color=Accent }) end)
        input.FocusLost:Connect(function() tw(inputStroke, { Color=T.BORDER }) end)

        -- ステータス表示
        local statusLbl = make("TextLabel", {
            Text="", TextSize=11, Font=Enum.Font.Gotham,
            TextColor3=T.TEXT_M, BackgroundTransparency=1,
            Size=UDim2.new(1,0,0,14), Position=UDim2.new(0,0,0,118),
            TextXAlignment=Enum.TextXAlignment.Left, ZIndex=313,
        }, card)

        -- 確認ボタン (琥珀背景 / 漆黒文字)
        local submitBtn = make("TextButton", {
            Text="Confirm", TextSize=13, Font=Enum.Font.GothamBold,
            TextColor3=T.BG_MAIN, BackgroundColor3=Accent,
            BorderSizePixel=0, AutoButtonColor=false, ZIndex=313,
        }, card)
        corner(8, submitBtn)

        -- キー取得ボタン (設定がある場合のみ)
        local targetUrl = KeyConfig.GetKeyURL
        if targetUrl then
            submitBtn.Size     = UDim2.new(0.5,-5,0,38)
            submitBtn.Position = UDim2.new(0.5,5,0,165)
            
            local getKeyBtn = make("TextButton", {
                Text="Get Key", TextSize=13, Font=Enum.Font.GothamBold,
                TextColor3=T.TEXT_P, BackgroundColor3=T.BG_ELEMENT,
                BorderSizePixel=0, AutoButtonColor=false,
                Size=UDim2.new(0.5,-5,0,38), Position=UDim2.new(0,0,0,165),
                ZIndex=313,
            }, card)
            corner(8, getKeyBtn)
            uiStroke(T.BORDER, 0.8, getKeyBtn)
            
            getKeyBtn.MouseButton1Click:Connect(function()
                if setclipboard then
                    setclipboard(targetUrl)
                    local old = getKeyBtn.Text
                    getKeyBtn.Text = "Copied!"
                    getKeyBtn.TextColor3 = T.STATUS_GREEN
                    task.wait(1.5)
                    if getKeyBtn and getKeyBtn.Parent then
                        getKeyBtn.Text = old
                        getKeyBtn.TextColor3 = T.TEXT_P
                    end
                end
            end)
            getKeyBtn.MouseEnter:Connect(function() tw(getKeyBtn,{BackgroundColor3=T.BG_ELEMENT_H}) end)
            getKeyBtn.MouseLeave:Connect(function() tw(getKeyBtn,{BackgroundColor3=T.BG_ELEMENT}) end)
        else
            submitBtn.Size     = UDim2.new(1,0,0,38)
            submitBtn.Position = UDim2.new(0,0,0,165)
        end

        -- Confirmボタンホバー演出
        submitBtn.MouseEnter:Connect(function() tw(submitBtn,{BackgroundColor3=lightenColor(Accent,0.1)}) end)
        submitBtn.MouseLeave:Connect(function() tw(submitBtn,{BackgroundColor3=Accent}) end)

        -- 内部バリデーション
        local function validateKey(key)
            key = key:match("^%s*(.-)%s*$")
            if KeyConfig.Key and key == KeyConfig.Key then return true end
            if KeyConfig.KeyList then
                local ok, res = pcall(function() return game:HttpGet(KeyConfig.KeyList) end)
                if ok and res then
                    for line in res:gmatch("[^\n]+") do
                        if line:match("^%s*(.-)%s*$") == key then return true end
                    end
                end
            end
            return false
        end

        local active = true
        local function trySubmit()
            if not active then return end
            if input.Text == "" then
                statusLbl.Text = "キーを入力してください"
                statusLbl.TextColor3 = T.STATUS_RED
                return
            end

            active = false
            statusLbl.Text = "Verifying..."
            statusLbl.TextColor3 = T.TEXT_M
            task.wait(0.4)

            if validateKey(input.Text) then
                statusLbl.Text = "✓ 認証成功"
                statusLbl.TextColor3 = T.STATUS_GREEN
                tw(topLine, { BackgroundColor3=T.STATUS_GREEN })
                task.wait(0.7)
                
                twWait(overlay, { BackgroundTransparency=1 },
                    TweenInfo.new(0.3,Enum.EasingStyle.Quad,Enum.EasingDirection.Out))
                overlay:Destroy()
                task.wait(0.05)
                successSignal:Fire()
            else
                statusLbl.Text = "✕ 無効なキーです"
                statusLbl.TextColor3 = T.STATUS_RED
                
                -- シェイク演出
                local origPos = inputBg.Position
                for i = 1, 4 do
                    twWait(inputBg,
                        { Position=UDim2.new(0, i%2==0 and 6 or -6, 0, 70) },
                        TweenInfo.new(0.05,Enum.EasingStyle.Quad))
                end
                inputBg.Position = origPos
                active = true
            end
        end

        submitBtn.MouseButton1Click:Connect(trySubmit)
        input.FocusLost:Connect(function(enter)
            if enter then trySubmit() end
        end)

        successSignal.Event:Wait()
        successSignal:Destroy()
    end
    -- ══════════════════════════════
    --  3. メイン GUI
    -- ══════════════════════════════
  local function buildMainGUI()
        local WIN_W, WIN_H = 680, 480
        local SIDEBAR_W    = 148
        local TOPBAR_H     = 50
        local USERPANEL_H  = (UserPanel.Enabled) and 52 or 0

        -- ─── メインフレーム (レスポンシブ化) ───────────────────────
        local main = make("Frame", {
            Name = "MainFrame",
            -- [[ 🚀 FIX: ピクセル固定(0, 680)を捨てて、画面比率(0.6, 0)にする ]]
            Size = UDim2.new(0.6, 0, 0.6, 0), 
            Position = UDim2.new(0.5, 0, 0.5, 0),
            AnchorPoint = Vector2.new(0.5, 0.5), -- 中心を基準
            BackgroundColor3 = T.BG_MAIN,
            BorderSizePixel = 0,
            ClipsDescendants = false,
        }, gui)
        corner(12, main)

        -- [[ 🚀 重要: どのデバイスでも 680:480 の形を崩さない設定 ]]
        local Aspect = Instance.new("UIAspectRatioConstraint", main)
        Aspect.AspectRatio = 1.416 -- (680 / 480)
        Aspect.AspectType = Enum.AspectType.FitWithinMaxSize

        -- PCでデカすぎ、スマホで小さすぎを防止
        local SizeConstraint = Instance.new("UISizeConstraint", main)
        SizeConstraint.MaxSize = Vector2.new(800, 565)
        SizeConstraint.MinSize = Vector2.new(450, 318)

        -- 枠線 (グラデーション対応) -- ここから下はお前のコードをそのまま維持
        if BorderCfg.Type == "rainbow" then
            -- 虹色グラデーション枠
            local stroke = uiStroke(rgb(255,255,255), 1.5, main)
            local grad = make("UIGradient", {
                Color = rainbowColorSequence(),
                Rotation = 0,
            }, stroke)
            -- 回転アニメ
            task.spawn(function()
                local rot = 0
                while main and main.Parent do
                    rot = (rot + 1) % 360
                    grad.Rotation = rot
                    task.wait(0.016)
                end
            end)
        elseif BorderCfg.Type == "gradient" and BorderCfg.Colors then
            local stroke = uiStroke(rgb(255,255,255), 1.2, main)
            make("UIGradient", {
                Color = gradientColorSequence(BorderCfg.Colors[1], BorderCfg.Colors[2]),
                Rotation = BorderCfg.Rotation or 45,
            }, stroke)
        else
            -- 通常の単色枠
            local stroke = uiStroke(T.BORDER, 1, main)
            stroke.LineJoinMode = Enum.LineJoinMode.Round
            -- Neon パルス
            if Neon then
                task.spawn(function()
                    local up = true
                    while main and main.Parent do
                        twWait(stroke, { Thickness = up and 2.8 or 1.0 },
                            TweenInfo.new(1.4,Enum.EasingStyle.Sine,Enum.EasingDirection.InOut))
                        up = not up
                    end
                end)
            end
        end

        -- ─── コンテンツラッパー (FIX[2]: ここを隠す方式で最小化) ───
        local contentWrapper = make("Frame", {
            Name = "ContentWrapper",
            Size = UDim2.new(1, 0, 1, -TOPBAR_H),
            Position = UDim2.new(0, 0, 0, TOPBAR_H),
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            ClipsDescendants = false,
        }, main)

        -- ─── トップバー ───────────────────────────
        local topBar = make("Frame", {
            Size = UDim2.new(1,0,0,TOPBAR_H),
            BackgroundColor3 = T.BG_TOPBAR,
            BorderSizePixel = 0, ZIndex = 3,
        }, main)
        corner(12, topBar)
        -- 下半分の角丸をつぶす
        make("Frame", {
            Size = UDim2.new(1,0,0.5,0), Position = UDim2.new(0,0,0.5,0),
            BackgroundColor3 = T.BG_TOPBAR, BorderSizePixel = 0, ZIndex = 3,
        }, topBar)
        -- 下境界線
        make("Frame", {
            Size = UDim2.new(1,0,0,1), Position = UDim2.new(0,0,1,-1),
            BackgroundColor3 = T.BORDER, BorderSizePixel = 0, ZIndex = 4,
        }, topBar)

        -- タイトル (FIX[6]: ドットなし、タイトルを左端から)
        make("TextLabel", {
            Text = Title, TextSize = 14, Font = Enum.Font.GothamBold,
            TextColor3 = T.ACCENT_TEXT, BackgroundTransparency = 1,
            Size = UDim2.new(1,-90,1,0),
            Position = UDim2.new(0,16,0,0),
            TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 5,
        }, topBar)

-- ─── 右側ボタン (Orion完全パクリ・凝縮最小化版) ─────────
local btnArea = make("Frame", {
    Size = UDim2.new(0, 64, 1, 0), 
    Position = UDim2.new(1, -68, 0, 0),
    BackgroundTransparency = 1, 
    ZIndex = 5,
}, topBar)

local minimized = false
local originalSize = UDim2.new(0.65, 0, 0.65, 0)
-- Orionスタイル：150x50の棒じゃなく、45x45の「円形アイコン」に凝縮する
local iconSize = UDim2.new(0, 45, 0, 45) 

local minimizeBtn = make("TextButton", {
    Text = "─", TextSize = 14, Font = Enum.Font.GothamBold,
    TextColor3 = T.TEXT_M, BackgroundTransparency = 1,
    Size = UDim2.new(0, 28, 1, 0), Position = UDim2.new(0, 0, 0, 0),
    AutoButtonColor = false, ZIndex = 5,
}, btnArea)

minimizeBtn.MouseButton1Click:Connect(function()
    minimized = not minimized
    
    -- Orionの「弾む」動きを再現するために EasingStyle.Back を使う
    local style = minimized and Enum.EasingStyle.Back or Enum.EasingStyle.Quart
    main.ClipsDescendants = true
    
    if minimized then
        -- 1. 【Orionシーケンス】中身とトップバーを即座に殺す
        contentWrapper.Visible = false
        if sideBar then sideBar.Visible = false end
        title.Visible = false
        topBar.BackgroundTransparency = 1 -- バーの背景も消してアイコンだけにする
        
        -- 2. 枠を「円形アイコン」まで一気に凝縮
        tw(main, { 
            Size = iconSize,
            BackgroundColor3 = T.ACCENT -- 最小化時は琥珀色に発光
        }, 0.5, style)
        
        -- 3. 角を丸めて完全に「円」にする
        tw(main:FindFirstChildOfClass("UICorner"), { CornerRadius = UDim.new(0, 22) })
        
        -- 4. ボタンをアイコンの中央に配置
        btnArea.Position = UDim2.new(0, 0, 0, 0)
        btnArea.Size = UDim2.new(1, 0, 1, 0)
        closeBtn.Visible = false
        minimizeBtn.Size = UDim2.new(1, 0, 1, 0)
        minimizeBtn.Text = "🌙" -- Orionっぽくロゴ化
    else
        -- 復元
        tw(main, { 
            Size = originalSize,
            BackgroundColor3 = T.BG_MAIN 
        }, 0.5, style)
        
        tw(main:FindFirstChildOfClass("UICorner"), { CornerRadius = UDim.new(0, 12) })
        
        topBar.BackgroundTransparency = 0
        title.Visible = true
        contentWrapper.Visible = true
        if sideBar then sideBar.Visible = true end
        
        -- ボタン配置を戻す
        btnArea.Position = UDim2.new(1, -68, 0, 0)
        btnArea.Size = UDim2.new(0, 64, 1, 0)
        closeBtn.Visible = true
        minimizeBtn.Size = UDim2.new(0, 28, 1, 0)
        minimizeBtn.Text = "─"
        
        task.delay(0.5, function() main.ClipsDescendants = false end)
    end
end)

-- 閉じるボタン（ここはそのまま）
local closeBtn = make("TextButton", {
    Text = "✕", TextSize = 13, Font = Enum.Font.GothamBold,
    TextColor3 = T.TEXT_M, BackgroundTransparency = 1,
    Size = UDim2.new(0, 28, 1, 0), Position = UDim2.new(0, 30, 0, 0),
    AutoButtonColor = false, ZIndex = 5,
}, btnArea)

        closeBtn.MouseEnter:Connect(function() tw(closeBtn, {TextColor3 = Color3.fromRGB(255, 95, 87)}) end)
        closeBtn.MouseLeave:Connect(function() tw(closeBtn, {TextColor3 = T.TEXT_M}) end)

        closeBtn.MouseButton1Click:Connect(function()
            -- 閉じる時は中央に消滅
            twWait(main, { 
                Size = UDim2.new(0, 0, 0, 0), 
                BackgroundTransparency = 1 
            }, TW_MED)
            gui:Destroy()
        end)
    
-- ─── ドラッグ (topBar 限定、モバイル視点固定版) ────
        do
            local dragging, dragInput, dragStart, startPos
            
            -- モバイルで視点移動を強制停止させるためのダミーボタン
            local modalLock = make("TextButton", {
                Name = "ModalLock",
                Size = UDim2.new(1, 0, 1, 0),
                BackgroundTransparency = 1,
                Text = "",
                Modal = true, -- これが視点固定のキモ
                Visible = false,
            }, topBar)

            local function update(input)
                local delta = input.Position - dragStart
                TweenService:Create(main, TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                    Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
                }):Play()
            end

            topBar.InputBegan:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                    dragging = true
                    dragStart = input.Position
                    startPos = main.Position
                    
                    -- ドラッグ開始時に視点をロック
                    modalLock.Visible = true

                    input.Changed:Connect(function()
                        if input.UserInputState == Enum.UserInputState.End then
                            dragging = false
                            -- 指を離したら視点ロック解除
                            modalLock.Visible = false
                        end
                    end)
                end
            end)

            topBar.InputChanged:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
                    dragInput = input
                end
            end)

            UserInputService.InputChanged:Connect(function(input)
                if input == dragInput and dragging then
                    update(input)
                end
            end)
        end
    
        -- ─── サイドバー ───────────────────────────
        local sidebar = make("Frame", {
            Size = UDim2.new(0,SIDEBAR_W, 1, -USERPANEL_H),
            Position = UDim2.new(0,0,0,0),
            BackgroundColor3 = T.BG_SIDEBAR, BorderSizePixel = 0, ZIndex = 2,
        }, contentWrapper)
        corner(12, sidebar)
        make("Frame", {
            Size = UDim2.new(0,1,1,-12), Position = UDim2.new(1,-1,0,0),
            BackgroundColor3 = T.BORDER, BorderSizePixel = 0, ZIndex = 3,
        }, sidebar)

        local sideScroll = make("ScrollingFrame", {
            Size = UDim2.new(1,0,1,0), BackgroundTransparency = 1, BorderSizePixel = 0,
            ScrollBarThickness = 0, CanvasSize = UDim2.new(0,0,0,0),
            AutomaticCanvasSize = Enum.AutomaticSize.Y,
        }, sidebar)
        make("UIListLayout", {
            SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0,3),
        }, sideScroll)
        pad(10,10,10,0, sideScroll)

        -- ─── ユーザーパネル (左下) ────────────────
        if UserPanel.Enabled then
            local upFrame = make("Frame", {
                Size = UDim2.new(0,SIDEBAR_W,0,USERPANEL_H),
                Position = UDim2.new(0,0,1,-USERPANEL_H),
                BackgroundColor3 = T.BG_TOPBAR, BorderSizePixel = 0, ZIndex = 3,
            }, contentWrapper)
            corner(12, upFrame)
            make("Frame", {
                Size = UDim2.new(1,0,0,1), Position = UDim2.new(0,0,0,0),
                BackgroundColor3 = T.BORDER, BorderSizePixel = 0, ZIndex = 4,
            }, upFrame)

            -- アバターアイコン
            local iconFrame = make("Frame", {
                Size = UDim2.new(0,32,0,32), Position = UDim2.new(0,10,0.5,-16),
                BackgroundColor3 = T.BG_ELEMENT, BorderSizePixel = 0, ZIndex = 4,
            }, upFrame)
            corner(16, iconFrame)
            uiStroke(Accent, 1, iconFrame)

            -- プロフィール画像
            local userId = UserPanel.UserId or LocalPlayer.UserId
            local thumbImg = make("ImageLabel", {
                Size = UDim2.new(1,0,1,0),
                Image = "rbxthumb://type=AvatarHeadShot&id="..tostring(userId).."&w=48&h=48",
                BackgroundTransparency = 1, ZIndex = 5,
            }, iconFrame)
            corner(16, thumbImg)

            make("TextLabel", {
                Text = UserPanel.Name or LocalPlayer.DisplayName,
                TextSize = 12, Font = Enum.Font.GothamBold,
                TextColor3 = T.TEXT_P, BackgroundTransparency = 1,
                Size = UDim2.new(1,-54,0,16), Position = UDim2.new(0,48,0,10),
                TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 5,
            }, upFrame)
            make("TextLabel", {
                Text = UserPanel.Role or "@"..LocalPlayer.Name,
                TextSize = 10, Font = Enum.Font.Gotham,
                TextColor3 = T.ACCENT_TEXT, BackgroundTransparency = 1,
                Size = UDim2.new(1,-54,0,14), Position = UDim2.new(0,48,0,28),
                TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 5,
            }, upFrame)
        end

        -- ─── コンテンツエリア ─────────────────────
        local contentArea = make("Frame", {
            Size = UDim2.new(1,-SIDEBAR_W,1,-USERPANEL_H),
            Position = UDim2.new(0,SIDEBAR_W,0,0),
            BackgroundColor3 = T.BG_CONTENT, BorderSizePixel = 0,
            ClipsDescendants = false,
        }, contentWrapper)
        corner(12, contentArea)

        -- ─── キーバインドトグル ───────────────────
        local visible = true
        UserInputService.InputBegan:Connect(function(i, gpe)
            if gpe then return end
            if i.KeyCode == Keybind then
                visible = not visible
                tw(main, {
                    Size = visible
                        and UDim2.new(0,WIN_W,0,WIN_H)
                        or  UDim2.new(0,WIN_W,0,0),
                }, TW_MED)
                contentWrapper.Visible = visible
            end
        end)

        -- 開くアニメーション
        twWait(main, { Size=UDim2.new(0,WIN_W,0,WIN_H) }, TW_SLOW)

        -- ─── タブ管理 ─────────────────────────────
        local pages    = {}
        local tabBtns  = {}
        local activeTab = nil

        local function switchTab(name)
            for _, pg in pairs(pages)   do pg.Visible = false end
            for n,  tb in pairs(tabBtns) do
                if n ~= name then tb.deactivate() end
            end
            if pages[name]   then pages[name].Visible = true end
            if tabBtns[name] then tabBtns[name].activate() end
            activeTab = name
        end

        -- ══════════════════════════════
        --  Window オブジェクト
        -- ══════════════════════════════
        local Window = {}

        -- FIX[7]: アイコンを画像ID or テキスト絵文字で対応
        function Window:CreateTab(name, icon)
            -- icon: テキスト絵文字 ("⚙") or 数値 (rbxassetid) or nil
            local order = 0
            for _ in pairs(tabBtns) do order += 1 end

            local btn = make("TextButton", {
                Text="", Size=UDim2.new(1,-8,0,36),
                BackgroundColor3=T.ACCENT, BackgroundTransparency=1,
                BorderSizePixel=0, AutoButtonColor=false, LayoutOrder=order,
            }, sideScroll)
            corner(7, btn)

            local accentBar = make("Frame", {
                Size=UDim2.new(0,2,0.6,0), Position=UDim2.new(0,0,0.2,0),
                BackgroundColor3=T.ACCENT, BorderSizePixel=0, BackgroundTransparency=1,
            }, btn)
            corner(2, accentBar)

            -- アイコン表示
            if type(icon) == "number" then
                -- 画像ID
                local imgLbl = make("ImageLabel", {
                    Image = "rbxassetid://"..tostring(icon),
                    Size = UDim2.new(0,18,0,18),
                    Position = UDim2.new(0,10,0.5,-9),
                    BackgroundTransparency = 1,
                    ImageColor3 = T.TEXT_M,
                }, btn)
                -- アクティブ時に色変更
                local function activateIcon() tw(imgLbl,{ImageColor3=T.ACCENT_TEXT}) end
                local function deactivateIcon() tw(imgLbl,{ImageColor3=T.TEXT_M}) end
                -- 後で activate/deactivate に連携
                btn:SetAttribute("hasImageIcon", true)
            else
                make("TextLabel", {
                    Text = icon or "◎",
                    TextSize = 14, Font = Enum.Font.Gotham,
                    TextColor3 = T.TEXT_M, BackgroundTransparency = 1,
                    Size = UDim2.new(0,20,1,0), Position = UDim2.new(0,10,0,0),
                    TextXAlignment = Enum.TextXAlignment.Center,
                }, btn)
            end

            local tabLbl = make("TextLabel", {
                Text = name, TextSize = 12, Font = Enum.Font.Gotham,
                TextColor3 = T.TEXT_S, BackgroundTransparency = 1,
                Size = UDim2.new(1,-36,1,0), Position = UDim2.new(0,36,0,0),
                TextXAlignment = Enum.TextXAlignment.Left,
            }, btn)

            local function activate()
                tw(btn,      { BackgroundTransparency=0.88, BackgroundColor3=dimColor(T.ACCENT,0.4) })
                tw(accentBar,{ BackgroundTransparency=0 })
                tw(tabLbl,   { TextColor3=T.ACCENT_TEXT })
            end
            local function deactivate()
                tw(btn,      { BackgroundTransparency=1 })
                tw(accentBar,{ BackgroundTransparency=1 })
                tw(tabLbl,   { TextColor3=T.TEXT_S })
            end

            btn.MouseEnter:Connect(function()
                if activeTab ~= name then
                    tw(btn,{BackgroundTransparency=0.93, BackgroundColor3=T.ACCENT})
                end
            end)
            btn.MouseLeave:Connect(function()
                if activeTab ~= name then tw(btn,{BackgroundTransparency=1}) end
            end)
            btn.MouseButton1Click:Connect(function() switchTab(name) end)

            tabBtns[name] = { activate=activate, deactivate=deactivate }

            local page = make("ScrollingFrame", {
                Size = UDim2.new(1,0,1,0),
                BackgroundTransparency = 1, BorderSizePixel = 0,
                ScrollBarThickness = 3, ScrollBarImageColor3 = T.BORDER,
                CanvasSize = UDim2.new(0,0,0,0),
                AutomaticCanvasSize = Enum.AutomaticSize.Y,
                Visible = false,
                ClipsDescendants = false,
            }, contentArea)
            make("UIListLayout", {
                SortOrder = Enum.SortOrder.LayoutOrder,
                Padding = UDim.new(0,6),
            }, page)
            pad(12,12,12,12, page)

            pages[name] = page
            if activeTab == nil then switchTab(name) end

            -- ──────────────────────────────
            --  Tab コンポーネント
            -- ──────────────────────────────
            local Tab = {}
            local elOrder = 0
            local function nO() elOrder += 1; return elOrder end

            local function makeWrap(h, ord)
                local w = make("Frame", {
                    Size = UDim2.new(1,0,0,h),
                    BackgroundColor3 = T.BG_ELEMENT,
                    BorderSizePixel = 0, LayoutOrder = ord,
                    ClipsDescendants = false,
                }, page)
                corner(8,w); uiStroke(T.BORDER,0.7,w); pad(0,0,14,14,w)
                return w
            end

            local function makeDesc(text, parent)
                if not text or text=="" then return end
                make("TextLabel", {
                    Text=text, TextSize=10, Font=Enum.Font.Gotham,
                    TextColor3=T.TEXT_M, BackgroundTransparency=1,
                    Size=UDim2.new(1,-28,0,14), Position=UDim2.new(0,0,1,-18),
                    TextXAlignment=Enum.TextXAlignment.Left,
                    TextTruncate=Enum.TextTruncate.AtEnd,
                }, parent)
            end

            -- ─────────────────────────────
            --  Toggle
            -- ─────────────────────────────
            function Tab:Toggle(name, default, callback, desc)
                local state = default or false
                local w = makeWrap(52, nO())

                make("TextLabel", {
                    Text=name, TextSize=13, Font=Enum.Font.GothamBold,
                    TextColor3=T.TEXT_P, BackgroundTransparency=1,
                    Size=UDim2.new(1,-52,0,20), Position=UDim2.new(0,0,0,8),
                    TextXAlignment=Enum.TextXAlignment.Left,
                }, w)
                makeDesc(desc, w)

                local track = make("Frame", {
                    Size=UDim2.new(0,38,0,20), Position=UDim2.new(1,-38,0.5,-10),
                    BackgroundColor3=T.BORDER, BorderSizePixel=0,
                }, w)
                corner(10, track)
                local thumb = make("Frame", {
                    Size=UDim2.new(0,14,0,14), Position=UDim2.new(0,3,0.5,-7),
                    BackgroundColor3=T.TEXT_M, BorderSizePixel=0,
                }, track)
                corner(7, thumb)

                local function upd()
                    if state then
                        tw(track,{BackgroundColor3=T.ACCENT_DIM})
                        tw(thumb,{Position=UDim2.new(0,21,0.5,-7), BackgroundColor3=T.ACCENT})
                    else
                        tw(track,{BackgroundColor3=T.BORDER})
                        tw(thumb,{Position=UDim2.new(0,3,0.5,-7),  BackgroundColor3=T.TEXT_M})
                    end
                end
                upd()

                local cb = make("TextButton", {
                    Text="", Size=UDim2.new(1,0,1,0),
                    BackgroundTransparency=1, BorderSizePixel=0, AutoButtonColor=false,
                }, w)
                cb.MouseButton1Click:Connect(function()
                    state = not state; upd()
                    if callback then callback(state) end
                end)
                cb.MouseEnter:Connect(function() tw(w,{BackgroundColor3=T.BG_ELEMENT_H}) end)
                cb.MouseLeave:Connect(function() tw(w,{BackgroundColor3=T.BG_ELEMENT}) end)
            end

            -- ─────────────────────────────
            --  Slider
            -- ─────────────────────────────
            function Tab:Slider(name, range, callback, desc)
                local minVal = range.min or range[1] or 0
                local maxVal = range.max or range[2] or 100
                local value  = range.default or minVal

                local w = makeWrap(66, nO())
                w.Size = UDim2.new(1,0,0,66)

                make("TextLabel", {
                    Text=name, TextSize=13, Font=Enum.Font.GothamBold,
                    TextColor3=T.TEXT_P, BackgroundTransparency=1,
                    Size=UDim2.new(0.65,0,0,20), Position=UDim2.new(0,0,0,6),
                    TextXAlignment=Enum.TextXAlignment.Left,
                }, w)

                local valLbl = make("TextLabel", {
                    Text=tostring(value),
                    TextSize=12, Font=Enum.Font.GothamBold,
                    TextColor3=T.ACCENT_TEXT, BackgroundTransparency=1,
                    Size=UDim2.new(0.35,0,0,20), Position=UDim2.new(0.65,-10,0,6),
                    TextXAlignment=Enum.TextXAlignment.Right,
                }, w)

                local track = make("Frame", {
                    Size=UDim2.new(1,-20,0,5), Position=UDim2.new(0,10,0,36),
                    BackgroundColor3=T.BORDER, BorderSizePixel=0,
                }, w)
                corner(3, track)
                local fill = make("Frame", {
                    Size=UDim2.new(0,0,1,0),
                    BackgroundColor3=T.ACCENT, BorderSizePixel=0,
                }, track)
                corner(3, fill)
                local knob = make("Frame", {
                    Size=UDim2.new(0,14,0,14),
                    Position=UDim2.new(0,-7,0.5,-7),
                    BackgroundColor3=T.TEXT_P, BorderSizePixel=0, ZIndex=5,
                }, track)
                corner(7, knob)
                uiStroke(T.ACCENT, 1.5, knob)
                makeDesc(desc, w)

                -- 初期値反映
                local initRatio = (value - minVal) / (maxVal - minVal)
                fill.Size     = UDim2.new(initRatio, 0, 1, 0)
                knob.Position = UDim2.new(initRatio, -7, 0.5, -7)

                local dragging = false
                local function updateByX(absX)
                    local tPos  = track.AbsolutePosition.X
                    local tSize = track.AbsoluteSize.X
                    if tSize <= 0 then return end
                    local ratio = math.clamp((absX - tPos) / tSize, 0, 1)
                    value = math.round(minVal + (maxVal - minVal) * ratio)
                    valLbl.Text   = tostring(value)
                    fill.Size     = UDim2.new(ratio, 0, 1, 0)
                    knob.Position = UDim2.new(ratio, -7, 0.5, -7)
                    if callback then callback(value) end
                end

                w.InputBegan:Connect(function(i)
                    if i.UserInputType == Enum.UserInputType.MouseButton1 then
                        dragging = true; updateByX(i.Position.X)
                    end
                end)
                UserInputService.InputChanged:Connect(function(i)
                    if dragging and i.UserInputType == Enum.UserInputType.MouseMovement then
                        updateByX(i.Position.X)
                    end
                end)
                UserInputService.InputEnded:Connect(function(i)
                    if i.UserInputType == Enum.UserInputType.MouseButton1 then
                        dragging = false
                    end
                end)
                w.MouseEnter:Connect(function() tw(w,{BackgroundColor3=T.BG_ELEMENT_H}) end)
                w.MouseLeave:Connect(function() tw(w,{BackgroundColor3=T.BG_ELEMENT}) end)
            end

            -- ─────────────────────────────
            --  Button
            -- ─────────────────────────────
            function Tab:Button(name, callback)
                local w = make("TextButton", {
                    Text="", Size=UDim2.new(1,0,0,40),
                    BackgroundColor3=T.BG_ELEMENT, BorderSizePixel=0,
                    AutoButtonColor=false, LayoutOrder=nO(),
                    ClipsDescendants=false,
                }, page)
                corner(8,w); uiStroke(T.BORDER,0.7,w)

                local al = make("Frame", {
                    Size=UDim2.new(0,3,0.5,0), Position=UDim2.new(0,0,0.25,0),
                    BackgroundColor3=T.ACCENT, BorderSizePixel=0,
                }, w)
                corner(2,al)

                make("TextLabel", {
                    Text=name, TextSize=13, Font=Enum.Font.GothamBold,
                    TextColor3=T.TEXT_P, BackgroundTransparency=1,
                    Size=UDim2.new(1,-40,1,0), Position=UDim2.new(0,18,0,0),
                    TextXAlignment=Enum.TextXAlignment.Left,
                }, w)
                make("TextLabel", {
                    Text="›", TextSize=18, Font=Enum.Font.GothamBold,
                    TextColor3=T.ACCENT, BackgroundTransparency=1,
                    Size=UDim2.new(0,24,1,0), Position=UDim2.new(1,-28,0,0),
                    TextXAlignment=Enum.TextXAlignment.Center,
                }, w)

                w.MouseEnter:Connect(function()
                    tw(w,{BackgroundColor3=T.BG_ELEMENT_H})
                    tw(al,{Size=UDim2.new(0,3,0.7,0), Position=UDim2.new(0,0,0.15,0)})
                end)
                w.MouseLeave:Connect(function()
                    tw(w,{BackgroundColor3=T.BG_ELEMENT})
                    tw(al,{Size=UDim2.new(0,3,0.5,0), Position=UDim2.new(0,0,0.25,0)})
                end)
                w.MouseButton1Down:Connect(function()
                    tw(w,{BackgroundColor3=dimColor(T.ACCENT,0.15)})
                end)
                w.MouseButton1Up:Connect(function()
                    tw(w,{BackgroundColor3=T.BG_ELEMENT_H})
                    if callback then callback() end
                end)
            end

            -- ─────────────────────────────
            --  Dropdown
            -- ─────────────────────────────
            function Tab:Dropdown(name, options, callback, desc)
                local open = false
                local selectedOpt = nil

                local w = make("Frame", {
                    Size=UDim2.new(1,0,0,52),
                    BackgroundColor3=T.BG_ELEMENT,
                    BorderSizePixel=0, LayoutOrder=nO(),
                    ClipsDescendants=false,
                }, page)
                corner(8,w); uiStroke(T.BORDER,0.7,w); pad(0,0,14,14,w)

                make("TextLabel", {
                    Text=name, TextSize=13, Font=Enum.Font.GothamBold,
                    TextColor3=T.TEXT_P, BackgroundTransparency=1,
                    Size=UDim2.new(1,-50,0,20), Position=UDim2.new(0,0,0,8),
                    TextXAlignment=Enum.TextXAlignment.Left,
                }, w)
                makeDesc(desc, w)

                local selLbl = make("TextLabel", {
                    Text="選択してください",
                    TextSize=11, Font=Enum.Font.Gotham,
                    TextColor3=T.TEXT_M, BackgroundTransparency=1,
                    Size=UDim2.new(1,-30,0,16), Position=UDim2.new(0,0,0,30),
                    TextXAlignment=Enum.TextXAlignment.Left,
                }, w)
                local arrow = make("TextLabel", {
                    Text="▾", TextSize=12, Font=Enum.Font.Gotham,
                    TextColor3=T.ACCENT, BackgroundTransparency=1,
                    Size=UDim2.new(0,20,0,20), Position=UDim2.new(1,-22,0,16),
                    TextXAlignment=Enum.TextXAlignment.Center,
                }, w)

                local dropList = make("Frame", {
                    Size=UDim2.new(0,0,0,0),
                    BackgroundColor3=rgb(8,20,38),
                    BorderSizePixel=0, ZIndex=200,
                    ClipsDescendants=true, Visible=false,
                }, gui)
                corner(8, dropList)
                uiStroke(T.BORDER, 0.7, dropList)
                make("UIListLayout", {
                    SortOrder=Enum.SortOrder.LayoutOrder, Padding=UDim.new(0,2),
                }, dropList)
                pad(4,4,6,6, dropList)

                local ITEM_H   = 28
                local LIST_PAD = 8
                local totalH   = LIST_PAD + #options * (ITEM_H + 2)
                local DROP_W   = 0

                for i, opt in ipairs(options) do
                    local ob = make("TextButton", {
                        Text=opt, TextSize=12, Font=Enum.Font.Gotham,
                        TextColor3=T.TEXT_S,
                        BackgroundColor3=T.BG_ELEMENT, BackgroundTransparency=1,
                        BorderSizePixel=0, AutoButtonColor=false,
                        Size=UDim2.new(1,0,0,ITEM_H), LayoutOrder=i,
                        TextXAlignment=Enum.TextXAlignment.Left, ZIndex=201,
                    }, dropList)
                    pad(0,0,6,0,ob); corner(6,ob)
                    ob.MouseEnter:Connect(function()
                        tw(ob,{BackgroundTransparency=0.82, BackgroundColor3=T.ACCENT})
                        tw(ob,{TextColor3=T.ACCENT_TEXT})
                    end)
                    ob.MouseLeave:Connect(function()
                        tw(ob,{BackgroundTransparency=1})
                        tw(ob,{TextColor3=T.TEXT_S})
                    end)
                    ob.MouseButton1Click:Connect(function()
                        selectedOpt = opt
                        selLbl.Text = opt
                        tw(selLbl,{TextColor3=T.ACCENT_TEXT})
                        open = false
                        tw(dropList,{Size=UDim2.new(0,DROP_W,0,0)}, TW_MED)
                        tw(arrow,{Rotation=0})
                        task.delay(0.22, function()
                            if dropList and dropList.Parent then dropList.Visible=false end
                        end)
                        if callback then callback(opt) end
                    end)
                end

                local hb = make("TextButton", {
                    Text="", Size=UDim2.new(1,0,1,0),
                    BackgroundTransparency=1, BorderSizePixel=0,
                    AutoButtonColor=false, ZIndex=5,
                }, w)
                hb.MouseButton1Click:Connect(function()
                    open = not open
                    if open then
                        local absPos  = w.AbsolutePosition
                        local absSize = w.AbsoluteSize
                        DROP_W = absSize.X
                        dropList.Position = UDim2.new(0, absPos.X, 0, absPos.Y + absSize.Y + 4)
                        dropList.Size     = UDim2.new(0, DROP_W, 0, 0)
                        dropList.Visible  = true
                        tw(dropList,{Size=UDim2.new(0,DROP_W,0,totalH)}, TW_MED)
                        tw(arrow,{Rotation=180})
                    else
                        tw(dropList,{Size=UDim2.new(0,DROP_W,0,0)}, TW_MED)
                        tw(arrow,{Rotation=0})
                        task.delay(0.22, function()
                            if dropList and dropList.Parent then dropList.Visible=false end
                        end)
                    end
                end)
                w.MouseEnter:Connect(function() tw(w,{BackgroundColor3=T.BG_ELEMENT_H}) end)
                w.MouseLeave:Connect(function() tw(w,{BackgroundColor3=T.BG_ELEMENT}) end)
            end

            -- ─────────────────────────────
            --  Input (NEW)
            -- ─────────────────────────────
            function Tab:Input(name, placeholder, callback, desc)
                local w = makeWrap(64, nO())
                w.Size = UDim2.new(1,0,0,64)

                make("TextLabel", {
                    Text=name, TextSize=13, Font=Enum.Font.GothamBold,
                    TextColor3=T.TEXT_P, BackgroundTransparency=1,
                    Size=UDim2.new(1,0,0,20), Position=UDim2.new(0,0,0,6),
                    TextXAlignment=Enum.TextXAlignment.Left,
                }, w)

                local inputBg = make("Frame", {
                    Size=UDim2.new(1,0,0,28), Position=UDim2.new(0,0,0,30),
                    BackgroundColor3=T.BG_MAIN, BorderSizePixel=0,
                }, w)
                corner(6, inputBg)
                local iStroke = uiStroke(T.BORDER, 0.8, inputBg)

                local tb = make("TextBox", {
                    PlaceholderText = placeholder or "入力...",
                    Text = "",
                    TextSize=12, Font=Enum.Font.Gotham,
                    TextColor3=T.TEXT_P, PlaceholderColor3=T.TEXT_M,
                    BackgroundTransparency=1,
                    Size=UDim2.new(1,-12,1,0), Position=UDim2.new(0,6,0,0),
                    TextXAlignment=Enum.TextXAlignment.Left,
                    ClearTextOnFocus=false,
                }, inputBg)

                tb.Focused:Connect(function()  tw(iStroke,{Color=Accent}) end)
                tb.FocusLost:Connect(function(enter)
                    tw(iStroke,{Color=T.BORDER})
                    if callback then callback(tb.Text, enter) end
                end)
                makeDesc(desc, w)
                w.MouseEnter:Connect(function() tw(w,{BackgroundColor3=T.BG_ELEMENT_H}) end)
                w.MouseLeave:Connect(function() tw(w,{BackgroundColor3=T.BG_ELEMENT}) end)
            end

            -- ─────────────────────────────
            --  ColorPicker (NEW) - RGBスライダー3本
            -- ─────────────────────────────
            function Tab:ColorPicker(name, defaultColor, callback, desc)
                local color = defaultColor or rgb(255, 255, 255)
                local r = math.floor(color.R * 255)
                local g = math.floor(color.G * 255)
                local b = math.floor(color.B * 255)

                local OPEN_H  = 160
                local CLOSE_H = 52
                local open    = false

                local w = make("Frame", {
                    Size=UDim2.new(1,0,0,CLOSE_H),
                    BackgroundColor3=T.BG_ELEMENT,
                    BorderSizePixel=0, LayoutOrder=nO(),
                    ClipsDescendants=true,
                }, page)
                corner(8,w); uiStroke(T.BORDER,0.7,w); pad(0,0,14,14,w)

                make("TextLabel", {
                    Text=name, TextSize=13, Font=Enum.Font.GothamBold,
                    TextColor3=T.TEXT_P, BackgroundTransparency=1,
                    Size=UDim2.new(1,-60,0,20), Position=UDim2.new(0,0,0,8),
                    TextXAlignment=Enum.TextXAlignment.Left,
                }, w)

                -- カラープレビュー
                local preview = make("Frame", {
                    Size=UDim2.new(0,24,0,24), Position=UDim2.new(1,-26,0,4),
                    BackgroundColor3=color, BorderSizePixel=0,
                }, w)
                corner(6, preview)
                uiStroke(T.BORDER, 0.8, preview)

                local arrow = make("TextLabel", {
                    Text="▾", TextSize=12, Font=Enum.Font.Gotham,
                    TextColor3=T.ACCENT, BackgroundTransparency=1,
                    Size=UDim2.new(0,16,0,16), Position=UDim2.new(1,-44,0,8),
                    TextXAlignment=Enum.TextXAlignment.Center,
                }, w)

                local function updateColor()
                    color = rgb(r, g, b)
                    preview.BackgroundColor3 = color
                    if callback then callback(color) end
                end

                -- RGBスライダー3本を生成
                local sliderData = {
                    { label="R", color=rgb(220,60,60),  get=function() return r end,
                      set=function(v) r=v end },
                    { label="G", color=rgb(60,200,80),  get=function() return g end,
                      set=function(v) g=v end },
                    { label="B", color=rgb(60,130,255), get=function() return b end,
                      set=function(v) b=v end },
                }

                for i, sd in ipairs(sliderData) do
                    local sy = CLOSE_H + 4 + (i-1)*32

                    make("TextLabel", {
                        Text=sd.label, TextSize=11, Font=Enum.Font.GothamBold,
                        TextColor3=sd.color, BackgroundTransparency=1,
                        Size=UDim2.new(0,14,0,20), Position=UDim2.new(0,0,0,sy+6),
                        TextXAlignment=Enum.TextXAlignment.Left,
                    }, w)

                    local valL = make("TextLabel", {
                        Text=tostring(sd.get()),
                        TextSize=11, Font=Enum.Font.GothamBold,
                        TextColor3=T.TEXT_S, BackgroundTransparency=1,
                        Size=UDim2.new(0,28,0,20), Position=UDim2.new(1,-28,0,sy+6),
                        TextXAlignment=Enum.TextXAlignment.Right,
                    }, w)

                    local trk = make("Frame", {
                        Size=UDim2.new(1,-52,0,4),
                        Position=UDim2.new(0,18,0,sy+14),
                        BackgroundColor3=T.BORDER, BorderSizePixel=0,
                    }, w)
                    corner(2, trk)
                    local fl = make("Frame", {
                        Size=UDim2.new(sd.get()/255,0,1,0),
                        BackgroundColor3=sd.color, BorderSizePixel=0,
                    }, trk)
                    corner(2, fl)
                    local kn = make("Frame", {
                        Size=UDim2.new(0,12,0,12),
                        Position=UDim2.new(sd.get()/255,-6,0.5,-6),
                        BackgroundColor3=T.TEXT_P, BorderSizePixel=0, ZIndex=5,
                    }, trk)
                    corner(6, kn)

                    local dragging = false
                    local function updateSlider(absX)
                        local tp = trk.AbsolutePosition.X
                        local ts = trk.AbsoluteSize.X
                        if ts <= 0 then return end
                        local ratio = math.clamp((absX-tp)/ts, 0, 1)
                        local val   = math.round(ratio * 255)
                        sd.set(val)
                        valL.Text    = tostring(val)
                        fl.Size      = UDim2.new(ratio,0,1,0)
                        kn.Position  = UDim2.new(ratio,-6,0.5,-6)
                        updateColor()
                    end

                    trk.InputBegan:Connect(function(inp)
                        if inp.UserInputType == Enum.UserInputType.MouseButton1 then
                            dragging = true; updateSlider(inp.Position.X)
                        end
                    end)
                    UserInputService.InputChanged:Connect(function(inp)
                        if dragging and inp.UserInputType == Enum.UserInputType.MouseMovement then
                            updateSlider(inp.Position.X)
                        end
                    end)
                    UserInputService.InputEnded:Connect(function(inp)
                        if inp.UserInputType == Enum.UserInputType.MouseButton1 then
                            dragging = false
                        end
                    end)
                end

                makeDesc(desc, w)

                -- 開閉
                local hb = make("TextButton", {
                    Text="", Size=UDim2.new(1,0,0,CLOSE_H),
                    BackgroundTransparency=1, BorderSizePixel=0, AutoButtonColor=false,
                }, w)
                hb.MouseButton1Click:Connect(function()
                    open = not open
                    tw(w, { Size=UDim2.new(1,0,0, open and OPEN_H or CLOSE_H) }, TW_MED)
                    tw(arrow, { Rotation=open and 180 or 0 })
                end)
                w.MouseEnter:Connect(function() tw(w,{BackgroundColor3=T.BG_ELEMENT_H}) end)
                w.MouseLeave:Connect(function() tw(w,{BackgroundColor3=T.BG_ELEMENT}) end)
            end

            -- ─────────────────────────────
            --  Accordion
            -- ─────────────────────────────
            function Tab:Accordion(name, items, desc)
                local open    = false
                local ITEM_H  = 30
                local CLOSE_H = 52
                local OPEN_H  = CLOSE_H + (#items * (ITEM_H + 4)) + 8

                local w = make("Frame", {
                    Size=UDim2.new(1,0,0,CLOSE_H),
                    BackgroundColor3=T.BG_ELEMENT,
                    BorderSizePixel=0, LayoutOrder=nO(),
                    ClipsDescendants=true,
                }, page)
                corner(8,w); uiStroke(T.BORDER,0.7,w); pad(0,0,14,14,w)

                make("TextLabel", {
                    Text=name, TextSize=13, Font=Enum.Font.GothamBold,
                    TextColor3=T.TEXT_P, BackgroundTransparency=1,
                    Size=UDim2.new(1,-30,0,20), Position=UDim2.new(0,0,0,8),
                    TextXAlignment=Enum.TextXAlignment.Left,
                }, w)
                makeDesc(desc, w)

                local arrow = make("TextLabel", {
                    Text="▾", TextSize=12, Font=Enum.Font.Gotham,
                    TextColor3=T.ACCENT, BackgroundTransparency=1,
                    Size=UDim2.new(0,20,0,20), Position=UDim2.new(1,-22,0,8),
                    TextXAlignment=Enum.TextXAlignment.Center,
                }, w)

                make("Frame", {
                    Size=UDim2.new(1,0,0,1), Position=UDim2.new(0,0,0,CLOSE_H-1),
                    BackgroundColor3=T.BORDER, BorderSizePixel=0,
                }, w)

                for i, item in ipairs(items) do
                    make("TextLabel", {
                        Text="  · "..item, TextSize=12, Font=Enum.Font.Gotham,
                        TextColor3=T.TEXT_S, BackgroundTransparency=1,
                        Size=UDim2.new(1,0,0,ITEM_H),
                        Position=UDim2.new(0,0,0, CLOSE_H+(i-1)*(ITEM_H+4)+4),
                        TextXAlignment=Enum.TextXAlignment.Left,
                    }, w)
                end

                local hb = make("TextButton", {
                    Text="", Size=UDim2.new(1,0,0,CLOSE_H),
                    BackgroundTransparency=1, BorderSizePixel=0, AutoButtonColor=false,
                }, w)
                hb.MouseButton1Click:Connect(function()
                    open = not open
                    tw(w,    { Size=UDim2.new(1,0,0, open and OPEN_H or CLOSE_H) }, TW_MED)
                    tw(arrow,{ Rotation=open and 180 or 0 })
                end)
                w.MouseEnter:Connect(function() tw(w,{BackgroundColor3=T.BG_ELEMENT_H}) end)
                w.MouseLeave:Connect(function() tw(w,{BackgroundColor3=T.BG_ELEMENT}) end)
            end

            -- ─────────────────────────────
            --  Separator
            -- ─────────────────────────────
            function Tab:Separator(labelText)
                local sep = make("Frame", {
                    Size=UDim2.new(1,0,0,20),
                    BackgroundTransparency=1, BorderSizePixel=0,
                    LayoutOrder=nO(),
                }, page)
                if labelText and labelText ~= "" then
                    make("TextLabel", {
                        Text=labelText, TextSize=10, Font=Enum.Font.GothamBold,
                        TextColor3=T.TEXT_M, BackgroundTransparency=1,
                        Size=UDim2.new(0,80,1,0),
                        TextXAlignment=Enum.TextXAlignment.Left,
                    }, sep)
                    make("Frame", {
                        Size=UDim2.new(1,-88,0,1), Position=UDim2.new(0,84,0.5,0),
                        BackgroundColor3=T.BORDER, BorderSizePixel=0,
                    }, sep)
                else
                    make("Frame", {
                        Size=UDim2.new(1,0,0,1), Position=UDim2.new(0,0,0.5,0),
                        BackgroundColor3=T.BORDER, BorderSizePixel=0,
                    }, sep)
                end
            end

            -- Notify をタブから呼べるショートカット
            function Tab:Notify(title, content, duration)
                doNotify(title, content, duration)
            end

            return Tab
        end -- CreateTab

        return Window
    end -- buildMainGUI

    -- ══════════════════════════════════════
    --  シーケンス実行
    -- ══════════════════════════════════════
    local realWindow = nil
    local queue      = {}

    local function runBuild()
        realWindow = buildMainGUI()
        for _, fn in ipairs(queue) do
            task.spawn(fn)
        end
    end

    task.spawn(function()
        playIntro()
        if KeyConfig.Enabled then showKeySystem() end
        runBuild()
    end)

    -- プロキシ
    local proxy = {}

    function proxy:CreateTab(name, icon)
        local tabProxy = {}
        local realTab  = nil
        local tabQueue = {}

        local function ensureTab()
            if realWindow and not realTab then
                realTab = realWindow:CreateTab(name, icon)
                for _, fn in ipairs(tabQueue) do fn() end
                tabQueue = {}
            end
        end

        local methods = {
            "Toggle","Slider","Button","Dropdown",
            "Accordion","Separator","Input","ColorPicker","Notify"
        }
        for _, m in ipairs(methods) do
            tabProxy[m] = function(self, ...)
                local args = {...}
                if realTab then
                    realTab[m](realTab, table.unpack(args))
                else
                    table.insert(tabQueue, function()
                        ensureTab()
                        if realTab then realTab[m](realTab, table.unpack(args)) end
                    end)
                end
            end
        end

        table.insert(queue, ensureTab)
        return tabProxy
    end

    function proxy:Notify(title, content, duration)
        if _notifyFn then
            _notifyFn(title, content, duration)
        else
            -- まだ初期化前ならキューに積む
            table.insert(queue, function()
                _notifyFn(title, content, duration)
            end)
        end
    end

    return proxy
end

return Library
