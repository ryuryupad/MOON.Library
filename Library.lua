-- ╔══════════════════════════════════════════════════════════════╗
-- ║                  Library.lua  (v2.0)                        ║
-- ║   起動アニメ × KEYシステム × ダークモダンGUI                ║
-- ╚══════════════════════════════════════════════════════════════╝

local Players          = game:GetService("Players")
local TweenService     = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local HttpService       = game:GetService("HttpService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui   = LocalPlayer:WaitForChild("PlayerGui")

-- ─────────────────────────────────────────
--  内部ユーティリティ
-- ─────────────────────────────────────────
local TW_FAST   = TweenInfo.new(0.12, Enum.EasingStyle.Quad,  Enum.EasingDirection.Out)
local TW_MED    = TweenInfo.new(0.22, Enum.EasingStyle.Quad,  Enum.EasingDirection.Out)
local TW_SLOW   = TweenInfo.new(0.5,  Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
local TW_EASE   = TweenInfo.new(0.8,  Enum.EasingStyle.Sine,  Enum.EasingDirection.InOut)

local function tw(obj, props, info)
    local t = TweenService:Create(obj, info or TW_FAST, props)
    t:Play(); return t
end

local function twWait(obj, props, info)
    local t = TweenService:Create(obj, info or TW_FAST, props)
    t:Play(); t.Completed:Wait()
end

local function make(class, props, parent)
    local o = Instance.new(class)
    for k, v in pairs(props) do o[k] = v end
    if parent then o.Parent = parent end
    return o
end

local function corner(r, p)  return make("UICorner",  { CornerRadius = UDim.new(0,r) }, p) end
local function stroke(c,t,p) return make("UIStroke",  { Color=c, Thickness=t or 0.8, ApplyStrokeMode=Enum.ApplyStrokeMode.Border }, p) end
local function pad(t,b,l,r,p) return make("UIPadding", { PaddingTop=UDim.new(0,t), PaddingBottom=UDim.new(0,b), PaddingLeft=UDim.new(0,l), PaddingRight=UDim.new(0,r) }, p) end

local function dimColor(c, f) f=f or 0.25; return Color3.new(c.R*f,c.G*f,c.B*f) end
local function lightenColor(c, f) f=f or 0.35
    return Color3.new(math.min(c.R+f,1), math.min(c.G+f,1), math.min(c.B+f,1))
end

-- ─────────────────────────────────────────
--  グリッチテキストエフェクト
-- ─────────────────────────────────────────
local GLITCH_CHARS = "!<>-_\\/[]{}—=+*^?#"
local function glitchText(label, finalText, duration)
    local steps = math.floor(duration / 0.04)
    spawn(function()
        for i = 1, steps do
            local progress = i / steps
            local revealed = math.floor(#finalText * progress)
            local result = string.sub(finalText, 1, revealed)
            -- 残りをランダム文字で埋める
            for _ = 1, #finalText - revealed do
                local idx = math.random(1, #GLITCH_CHARS)
                result = result .. string.sub(GLITCH_CHARS, idx, idx)
            end
            label.Text = result
            wait(0.04)
        end
        label.Text = finalText
    end)
end

-- ─────────────────────────────────────────
--  ライブラリ本体
-- ─────────────────────────────────────────
local Library = {}

function Library:CreateWindow(config)
    config = config or {}

    local Title      = config.Title      or "UI"
    local Subtitle   = config.Subtitle   or "v1.0"
    local Accent     = config.Color      or Color3.fromRGB(40, 130, 255)
    local Keybind    = config.Keybind    or Enum.KeyCode.RightShift
    local Neon       = config.Neon       ~= nil and config.Neon or false

    -- KEYシステム設定
    local KeyConfig  = config.KeySystem  or { Enabled = false }
    -- KeyConfig.Enabled   = true/false
    -- KeyConfig.Key       = "XXXX-XXXX" (定数キー)
    -- KeyConfig.KeyList   = "https://..." (URLからキー一覧取得。改行区切り)
    -- KeyConfig.Title     = "Key Required"
    -- KeyConfig.Hint      = "Discordで入手"

    -- ── テーマ ──────────────────────────
    local T = {
        BG_MAIN      = Color3.fromRGB(5,  14, 26),
        BG_TOPBAR    = Color3.fromRGB(8,  18, 32),
        BG_SIDEBAR   = Color3.fromRGB(6,  15, 28),
        BG_CONTENT   = Color3.fromRGB(4,  11, 22),
        BG_ELEMENT   = Color3.fromRGB(10, 22, 38),
        BG_ELEMENT_H = Color3.fromRGB(16, 32, 54),
        BORDER       = Color3.fromRGB(28, 46, 72),
        TEXT_P       = Color3.fromRGB(210, 220, 235),
        TEXT_S       = Color3.fromRGB(110, 130, 160),
        TEXT_M       = Color3.fromRGB(55,  75, 105),
        ACCENT       = Accent,
        ACCENT_DIM   = dimColor(Accent, 0.22),
        ACCENT_TEXT  = lightenColor(Accent, 0.35),
        STATUS_GREEN = Color3.fromRGB(40, 200, 100),
        STATUS_RED   = Color3.fromRGB(220, 60, 60),
    }

    -- ── ScreenGui ───────────────────────
    local gui = make("ScreenGui", {
        Name = "ryu_ui", ResetOnSpawn = false,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        IgnoreGuiInset = true,
    }, PlayerGui)

    -- ══════════════════════════════════════
    --  1. 起動アニメーション
    -- ══════════════════════════════════════
    local function playIntro()
        -- 全画面オーバーレイ
        local overlay = make("Frame", {
            Size = UDim2.new(1,0,1,0),
            BackgroundColor3 = Color3.fromRGB(2, 6, 14),
            BorderSizePixel = 0, ZIndex = 100,
        }, gui)

        -- ── パーティクル（光の粒子）──
        local particles = {}
        for i = 1, 28 do
            local size = math.random(2, 5)
            local p = make("Frame", {
                Size = UDim2.new(0, size, 0, size),
                Position = UDim2.new(math.random(0,100)/100, 0, math.random(0,100)/100, 0),
                BackgroundColor3 = Accent,
                BorderSizePixel = 0,
                BackgroundTransparency = math.random(40,85)/100,
                ZIndex = 101,
            }, overlay)
            corner(size, p)
            table.insert(particles, p)
        end

        -- パーティクルをゆっくり漂わせる
        spawn(function()
            for _, p in pairs(particles) do
                local startPos = p.Position
                spawn(function()
                    while p and p.Parent do
                        local tx = startPos.X.Scale + (math.random(-8,8)/100)
                        local ty = startPos.Y.Scale + (math.random(-8,8)/100)
                        tw(p, {
                            Position = UDim2.new(
                                math.clamp(tx,0,0.98), 0,
                                math.clamp(ty,0,0.98), 0
                            ),
                            BackgroundTransparency = math.random(30,80)/100,
                        }, TweenInfo.new(math.random(15,30)/10, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut))
                        wait(math.random(15,30)/10)
                    end
                end)
            end
        end)

        -- ── センターコンテナ ──
        local center = make("Frame", {
            Size = UDim2.new(0, 320, 0, 140),
            Position = UDim2.new(0.5, -160, 0.5, -70),
            BackgroundTransparency = 1,
            ZIndex = 102,
        }, overlay)

        -- ロゴライン（アクセントカラーの横線）
        local logoLine = make("Frame", {
            Size = UDim2.new(0, 0, 0, 2),
            Position = UDim2.new(0.5, 0, 0, 0),
            BackgroundColor3 = Accent,
            BorderSizePixel = 0, ZIndex = 103,
        }, center)
        corner(1, logoLine)

        -- タイトルラベル（最初は透明）
        local titleLbl = make("TextLabel", {
            Text = Title,
            TextSize = 38, Font = Enum.Font.GothamBold,
            TextColor3 = T.TEXT_P,
            BackgroundTransparency = 1,
            Size = UDim2.new(1,0,0,56),
            Position = UDim2.new(0,0,0,20),
            TextXAlignment = Enum.TextXAlignment.Center,
            TextTransparency = 1, ZIndex = 103,
        }, center)

        -- サブタイトル
        local subLbl = make("TextLabel", {
            Text = Subtitle,
            TextSize = 13, Font = Enum.Font.Gotham,
            TextColor3 = T.ACCENT_TEXT,
            BackgroundTransparency = 1,
            Size = UDim2.new(1,0,0,20),
            Position = UDim2.new(0,0,0,78),
            TextXAlignment = Enum.TextXAlignment.Center,
            TextTransparency = 1, ZIndex = 103,
        }, center)

        -- プログレスバートラック
        local barTrack = make("Frame", {
            Size = UDim2.new(0, 200, 0, 3),
            Position = UDim2.new(0.5,-100,0,112),
            BackgroundColor3 = Color3.fromRGB(20, 35, 58),
            BorderSizePixel = 0, ZIndex = 103,
        }, center)
        corner(2, barTrack)

        local barFill = make("Frame", {
            Size = UDim2.new(0,0,1,0),
            BackgroundColor3 = Accent,
            BorderSizePixel = 0, ZIndex = 104,
        }, barTrack)
        corner(2, barFill)

        -- ステータステキスト
        local statusLbl = make("TextLabel", {
            Text = "Initializing...",
            TextSize = 11, Font = Enum.Font.Gotham,
            TextColor3 = T.TEXT_M,
            BackgroundTransparency = 1,
            Size = UDim2.new(1,0,0,16),
            Position = UDim2.new(0,0,0,122),
            TextXAlignment = Enum.TextXAlignment.Center,
            ZIndex = 103,
        }, center)

        -- ── アニメーションシーケンス ──

        -- Step1: ラインが左右に広がる
        wait(0.1)
        twWait(logoLine, {
            Size = UDim2.new(1,0,0,2),
            Position = UDim2.new(0,0,0,0),
        }, TW_SLOW)

        -- Step2: タイトルがグリッチしながらフェードイン
        tw(titleLbl, { TextTransparency = 0 },
            TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out))
        glitchText(titleLbl, Title, 0.7)
        wait(0.5)

        -- Step3: サブタイトルフェードイン
        twWait(subLbl, { TextTransparency = 0 },
            TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out))

        -- Step4: プログレスバー進行
        local loadSteps = {
            { text = "Loading modules...",   pct = 0.3 },
            { text = "Connecting...",        pct = 0.55 },
            { text = "Verifying assets...",  pct = 0.8 },
            { text = "Ready.",               pct = 1.0 },
        }
        for _, step in ipairs(loadSteps) do
            statusLbl.Text = step.text
            twWait(barFill, { Size = UDim2.new(step.pct, 0, 1, 0) },
                TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out))
            wait(0.18)
        end
        wait(0.3)

        -- Step5: 全体フェードアウト
        twWait(overlay, { BackgroundTransparency = 1 },
            TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out))
        overlay:Destroy()
    end

    -- ══════════════════════════════════════
    --  2. KEYシステム
    -- ══════════════════════════════════════
    local function showKeySystem()
        local keyResolved = false
        local successSignal = Instance.new("BindableEvent")

        local keyGui = make("Frame", {
            Size = UDim2.new(1,0,1,0),
            BackgroundColor3 = Color3.fromRGB(3, 8, 16),
            BackgroundTransparency = 0.3,
            BorderSizePixel = 0, ZIndex = 50,
        }, gui)

        -- カード
        local card = make("Frame", {
            Size = UDim2.new(0, 380, 0, 210),
            Position = UDim2.new(0.5,-190,0.5,-105),
            BackgroundColor3 = T.BG_MAIN,
            BorderSizePixel = 0, ZIndex = 51,
            BackgroundTransparency = 1,
        }, keyGui)
        corner(14, card)
        stroke(T.BORDER, 1, card)

        -- フェードイン
        tw(card, { BackgroundTransparency = 0 },
            TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out))

        -- アクセントトップライン
        local topLine = make("Frame", {
            Size = UDim2.new(1,0,0,2),
            BackgroundColor3 = Accent,
            BorderSizePixel = 0, ZIndex = 52,
        }, card)
        corner(14, topLine)
        make("Frame", {  -- 下半分つぶし
            Size = UDim2.new(1,0,0.5,0), Position = UDim2.new(0,0,0,1),
            BackgroundColor3 = Accent, BorderSizePixel = 0, ZIndex = 52,
        }, topLine)

        pad(20,20,24,24, card)

        -- タイトル
        make("TextLabel", {
            Text = KeyConfig.Title or "Key Required",
            TextSize = 17, Font = Enum.Font.GothamBold,
            TextColor3 = T.TEXT_P, BackgroundTransparency = 1,
            Size = UDim2.new(1,0,0,26),
            Position = UDim2.new(0,0,0,14),
            TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 53,
        }, card)

        -- ヒントテキスト
        make("TextLabel", {
            Text = KeyConfig.Hint or "有効なキーを入力してください",
            TextSize = 11, Font = Enum.Font.Gotham,
            TextColor3 = T.TEXT_M, BackgroundTransparency = 1,
            Size = UDim2.new(1,0,0,16),
            Position = UDim2.new(0,0,0,42),
            TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 53,
        }, card)

        -- 入力フィールド
        local inputBg = make("Frame", {
            Size = UDim2.new(1,0,0,38),
            Position = UDim2.new(0,0,0,70),
            BackgroundColor3 = T.BG_ELEMENT,
            BorderSizePixel = 0, ZIndex = 53,
        }, card)
        corner(8, inputBg)
        stroke(T.BORDER, 0.8, inputBg)

        local input = make("TextBox", {
            PlaceholderText = "XXXX-XXXX-XXXX",
            Text = "",
            TextSize = 13, Font = Enum.Font.GothamBold,
            TextColor3 = T.TEXT_P,
            PlaceholderColor3 = T.TEXT_M,
            BackgroundTransparency = 1,
            Size = UDim2.new(1,-16,1,0),
            Position = UDim2.new(0,10,0,0),
            TextXAlignment = Enum.TextXAlignment.Left,
            ClearTextOnFocus = false, ZIndex = 54,
        }, inputBg)

        -- フォーカス時ボーダー光る
        input.Focused:Connect(function()
            tw(inputBg:FindFirstChildOfClass("UIStroke"), { Color = Accent })
        end)
        input.FocusLost:Connect(function()
            tw(inputBg:FindFirstChildOfClass("UIStroke"), { Color = T.BORDER })
        end)

        -- ステータスメッセージ
        local statusLbl = make("TextLabel", {
            Text = "", TextSize = 11, Font = Enum.Font.Gotham,
            TextColor3 = T.TEXT_M, BackgroundTransparency = 1,
            Size = UDim2.new(1,0,0,14),
            Position = UDim2.new(0,0,0,118),
            TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 53,
        }, card)

        -- 確認ボタン
        local submitBtn = make("TextButton", {
            Text = "Confirm",
            TextSize = 13, Font = Enum.Font.GothamBold,
            TextColor3 = T.BG_MAIN,
            BackgroundColor3 = Accent,
            BorderSizePixel = 0, AutoButtonColor = false,
            Size = UDim2.new(1,0,0,36),
            Position = UDim2.new(0,0,0,152),
            ZIndex = 53,
        }, card)
        corner(8, submitBtn)

        submitBtn.MouseEnter:Connect(function()
            tw(submitBtn, { BackgroundColor3 = lightenColor(Accent, 0.1) })
        end)
        submitBtn.MouseLeave:Connect(function()
            tw(submitBtn, { BackgroundColor3 = Accent })
        end)

        -- キー検証ロジック
        local function validateKey(key)
            key = key:match("^%s*(.-)%s*$")  -- trim

            -- 定数キー検証
            if KeyConfig.Key and key == KeyConfig.Key then
                return true
            end

            -- 外部リスト検証
            if KeyConfig.KeyList then
                local ok, result = pcall(function()
                    return game:HttpGet(KeyConfig.KeyList)
                end)
                if ok and result then
                    for line in result:gmatch("[^\n]+") do
                        local trimmed = line:match("^%s*(.-)%s*$")
                        if trimmed ~= "" and trimmed == key then
                            return true
                        end
                    end
                end
            end

            return false
        end

        submitBtn.MouseButton1Click:Connect(function()
            local key = input.Text
            if key == "" then
                statusLbl.Text = "キーを入力してください"
                statusLbl.TextColor3 = T.STATUS_RED
                return
            end

            statusLbl.Text = "Verifying..."
            statusLbl.TextColor3 = T.TEXT_M
            submitBtn.Active = false

            wait(0.4)  -- 検証中の演出

            if validateKey(key) then
                statusLbl.Text = "✓ 認証成功"
                statusLbl.TextColor3 = T.STATUS_GREEN
                tw(topLine, { BackgroundColor3 = T.STATUS_GREEN })
                wait(0.7)
                twWait(keyGui, { BackgroundTransparency = 1 },
                    TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out))
                keyGui:Destroy()
                keyResolved = true
                successSignal:Fire()
            else
                statusLbl.Text = "✕ 無効なキーです"
                statusLbl.TextColor3 = T.STATUS_RED
                -- 入力シェイクアニメ
                local origPos = inputBg.Position
                for i = 1, 4 do
                    local offset = (i % 2 == 0) and 6 or -6
                    twWait(inputBg, { Position = UDim2.new(0,offset,0,70) },
                        TweenInfo.new(0.05, Enum.EasingStyle.Quad))
                end
                inputBg.Position = origPos
                submitBtn.Active = true
            end
        end)

        -- Enterキーでも送信
        input.FocusLost:Connect(function(enterPressed)
            if enterPressed then
                submitBtn.MouseButton1Click:Fire()
            end
        end)

        successSignal.Event:Wait()
        successSignal:Destroy()
    end

    -- ══════════════════════════════════════
    --  3. メインGUI
    -- ══════════════════════════════════════
    local function buildMainGUI()
        -- メインフレーム（最初は縮んだ状態）
        local main = make("Frame", {
            Name = "MainFrame",
            Size = UDim2.new(0, 680, 0, 0),
            Position = UDim2.new(0.5,-340,0.5,-240),
            BackgroundColor3 = T.BG_MAIN,
            BorderSizePixel = 0, ClipsDescendants = true,
        }, gui)
        corner(12, main)
        stroke(T.BORDER, 1, main)

        -- 開くアニメ
        twWait(main, { Size = UDim2.new(0,680,0,480) }, TW_SLOW)

        -- Neon発光
        if Neon then
            local glow = make("UIStroke", {
                Color = Accent, Thickness = 1.5,
                ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
            }, main)
            spawn(function()
                local up = true
                while gui.Parent do
                    twWait(glow, { Thickness = up and 2.8 or 1.0 },
                        TweenInfo.new(1.4, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut))
                    up = not up
                end
            end)
        end

        -- ── ドラッグ ──
        do
            local drag, ds, sp
            main.InputBegan:Connect(function(i)
                if i.UserInputType == Enum.UserInputType.MouseButton1 then
                    drag=true; ds=i.Position; sp=main.Position
                end
            end)
            UserInputService.InputChanged:Connect(function(i)
                if drag and i.UserInputType == Enum.UserInputType.MouseMovement then
                    local d = i.Position - ds
                    main.Position = UDim2.new(sp.X.Scale, sp.X.Offset+d.X,
                                              sp.Y.Scale, sp.Y.Offset+d.Y)
                end
            end)
            UserInputService.InputEnded:Connect(function(i)
                if i.UserInputType == Enum.UserInputType.MouseButton1 then drag=false end
            end)
        end

        -- ── トップバー ──
        local topBar = make("Frame", {
            Size = UDim2.new(1,0,0,50),
            BackgroundColor3 = T.BG_TOPBAR,
            BorderSizePixel = 0, ZIndex = 3,
        }, main)
        corner(12, topBar)
        make("Frame", {
            Size = UDim2.new(1,0,0.5,0), Position = UDim2.new(0,0,0.5,0),
            BackgroundColor3 = T.BG_TOPBAR, BorderSizePixel = 0, ZIndex = 3,
        }, topBar)
        make("Frame", {
            Size = UDim2.new(1,0,0,1), Position = UDim2.new(0,0,1,-1),
            BackgroundColor3 = T.BORDER, BorderSizePixel = 0, ZIndex = 4,
        }, topBar)

        -- トラフィックドット
        local dotsF = make("Frame", {
            Size=UDim2.new(0,54,0,12), Position=UDim2.new(0,14,0.5,-6),
            BackgroundTransparency=1, ZIndex=5,
        }, topBar)
        for i, c in ipairs({
            Color3.fromRGB(255,95,87), Color3.fromRGB(254,188,46), Color3.fromRGB(40,200,65)
        }) do
            local d = make("Frame", {
                Size=UDim2.new(0,12,0,12), Position=UDim2.new(0,(i-1)*18,0,0),
                BackgroundColor3=c, BorderSizePixel=0, ZIndex=5,
            }, dotsF)
            corner(6,d)
        end

        -- タイトル
        make("TextLabel", {
            Text = Title, TextSize = 14, Font = Enum.Font.GothamBold,
            TextColor3 = T.ACCENT_TEXT, BackgroundTransparency = 1,
            Size = UDim2.new(0,200,1,0), Position = UDim2.new(0.5,-100,0,0),
            TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 5,
        }, topBar)

        -- 閉じるボタン
        local closeBtn = make("TextButton", {
            Text = "✕", TextSize = 13, Font = Enum.Font.GothamBold,
            TextColor3 = T.TEXT_M, BackgroundTransparency = 1,
            Size = UDim2.new(0,32,1,0), Position = UDim2.new(1,-36,0,0),
            AutoButtonColor = false, ZIndex = 5,
        }, topBar)
        closeBtn.MouseEnter:Connect(function() tw(closeBtn,{TextColor3=Color3.fromRGB(255,95,87)}) end)
        closeBtn.MouseLeave:Connect(function() tw(closeBtn,{TextColor3=T.TEXT_M}) end)
        closeBtn.MouseButton1Click:Connect(function()
            twWait(main, { Size = UDim2.new(0,680,0,0) }, TW_MED)
            gui:Destroy()
        end)

        -- ── サイドバー ──
        local sidebar = make("Frame", {
            Size = UDim2.new(0,148,1,-50), Position = UDim2.new(0,0,0,50),
            BackgroundColor3 = T.BG_SIDEBAR, BorderSizePixel = 0, ZIndex = 2,
        }, main)
        make("Frame", {
            Size=UDim2.new(0,1,1,0), Position=UDim2.new(1,-1,0,0),
            BackgroundColor3=T.BORDER, BorderSizePixel=0, ZIndex=3,
        }, sidebar)

        local sideScroll = make("ScrollingFrame", {
            Size=UDim2.new(1,0,1,0), BackgroundTransparency=1, BorderSizePixel=0,
            ScrollBarThickness=0, CanvasSize=UDim2.new(0,0,0,0),
            AutomaticCanvasSize=Enum.AutomaticSize.Y,
        }, sidebar)
        make("UIListLayout", { SortOrder=Enum.SortOrder.LayoutOrder, Padding=UDim.new(0,3) }, sideScroll)
        pad(10,10,0,0,sideScroll)

        -- ── コンテンツエリア ──
        local contentArea = make("Frame", {
            Size=UDim2.new(1,-148,1,-50), Position=UDim2.new(0,148,0,50),
            BackgroundColor3=T.BG_CONTENT, BorderSizePixel=0,
        }, main)

        -- ── キーバインドトグル ──
        local visible = true
        UserInputService.InputBegan:Connect(function(input, gpe)
            if gpe then return end
            if input.KeyCode == Keybind then
                visible = not visible
                tw(main, {
                    Size = visible and UDim2.new(0,680,0,480) or UDim2.new(0,680,0,0)
                }, TW_MED)
            end
        end)

        -- ─────────────────────────────────
        --  タブ管理
        -- ─────────────────────────────────
        local pages   = {}
        local tabBtns = {}
        local activeTab = nil

        local function switchTab(name)
            for n, page in pairs(pages)   do page.Visible = false end
            for n, info in pairs(tabBtns) do if n ~= name then info.deactivate() end end
            if pages[name]   then pages[name].Visible = true end
            if tabBtns[name] then tabBtns[name].activate() end
            activeTab = name
        end

        -- ─────────────────────────────────
        --  Window オブジェクト
        -- ─────────────────────────────────
        local Window = {}

        function Window:CreateTab(name, icon)
            icon = icon or "◎"

            local order = 0
            for _ in pairs(tabBtns) do order += 1 end

            local btn = make("TextButton", {
                Text="", Size=UDim2.new(1,-8,0,32),
                BackgroundColor3=T.ACCENT, BackgroundTransparency=1,
                BorderSizePixel=0, AutoButtonColor=false, LayoutOrder=order,
            }, sideScroll)
            corner(7, btn)

            local accentBar = make("Frame", {
                Size=UDim2.new(0,2,0.6,0), Position=UDim2.new(0,0,0.2,0),
                BackgroundColor3=T.ACCENT, BorderSizePixel=0, BackgroundTransparency=1,
            }, btn)
            corner(2,accentBar)

            make("TextLabel", {
                Text=icon, TextSize=13, Font=Enum.Font.Gotham,
                TextColor3=T.TEXT_M, BackgroundTransparency=1,
                Size=UDim2.new(0,20,1,0), Position=UDim2.new(0,10,0,0),
                TextXAlignment=Enum.TextXAlignment.Center,
            }, btn)

            local tabLbl = make("TextLabel", {
                Text=name, TextSize=12, Font=Enum.Font.Gotham,
                TextColor3=T.TEXT_S, BackgroundTransparency=1,
                Size=UDim2.new(1,-36,1,0), Position=UDim2.new(0,34,0,0),
                TextXAlignment=Enum.TextXAlignment.Left,
            }, btn)

            local function activate()
                tw(btn,{BackgroundTransparency=0.88})
                tw(btn,{BackgroundColor3=dimColor(T.ACCENT,0.4)})
                tw(accentBar,{BackgroundTransparency=0})
                tw(tabLbl,{TextColor3=T.ACCENT_TEXT})
            end
            local function deactivate()
                tw(btn,{BackgroundTransparency=1})
                tw(accentBar,{BackgroundTransparency=1})
                tw(tabLbl,{TextColor3=T.TEXT_S})
            end

            btn.MouseEnter:Connect(function()
                if activeTab ~= name then
                    tw(btn,{BackgroundTransparency=0.93})
                    tw(btn,{BackgroundColor3=T.ACCENT})
                end
            end)
            btn.MouseLeave:Connect(function()
                if activeTab ~= name then tw(btn,{BackgroundTransparency=1}) end
            end)
            btn.MouseButton1Click:Connect(function() switchTab(name) end)

            tabBtns[name] = { activate=activate, deactivate=deactivate }

            local page = make("ScrollingFrame", {
                Size=UDim2.new(1,0,1,0), BackgroundTransparency=1, BorderSizePixel=0,
                ScrollBarThickness=3, ScrollBarImageColor3=T.BORDER,
                CanvasSize=UDim2.new(0,0,0,0), AutomaticCanvasSize=Enum.AutomaticSize.Y,
                Visible=false,
            }, contentArea)
            make("UIListLayout", { SortOrder=Enum.SortOrder.LayoutOrder, Padding=UDim.new(0,6) }, page)
            pad(12,12,12,12,page)

            pages[name] = page
            if activeTab == nil then switchTab(name) end

            -- ─────────────────────────────
            --  Tab オブジェクト
            -- ─────────────────────────────
            local Tab = {}
            local elOrder = 0
            local function nO() elOrder+=1; return elOrder end

            local function makeWrap(h, order)
                local w = make("Frame", {
                    Size=UDim2.new(1,0,0,h or 52),
                    BackgroundColor3=T.BG_ELEMENT,
                    BorderSizePixel=0, LayoutOrder=order,
                }, page)
                corner(8,w); stroke(T.BORDER,0.7,w); pad(0,0,14,14,w)
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

            -- Toggle
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
                corner(10,track)
                local thumb = make("Frame", {
                    Size=UDim2.new(0,14,0,14), Position=UDim2.new(0,3,0.5,-7),
                    BackgroundColor3=T.TEXT_M, BorderSizePixel=0,
                }, track)
                corner(7,thumb)
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
                local cb = make("TextButton", { Text="", Size=UDim2.new(1,0,1,0), BackgroundTransparency=1, BorderSizePixel=0, AutoButtonColor=false }, w)
                cb.MouseButton1Click:Connect(function() state=not state; upd(); if callback then callback(state) end end)
                cb.MouseEnter:Connect(function() tw(w,{BackgroundColor3=T.BG_ELEMENT_H}) end)
                cb.MouseLeave:Connect(function() tw(w,{BackgroundColor3=T.BG_ELEMENT}) end)
            end

            -- Slider
            function Tab:Slider(name, range, callback, desc)
                local min,max = range[1] or 0, range[2] or 100
                local value = min
                local w = makeWrap(62, nO()); w.Size = UDim2.new(1,0,0,62)
                make("TextLabel", {
                    Text=name, TextSize=13, Font=Enum.Font.GothamBold,
                    TextColor3=T.TEXT_P, BackgroundTransparency=1,
                    Size=UDim2.new(0.7,0,0,20), Position=UDim2.new(0,0,0,6),
                    TextXAlignment=Enum.TextXAlignment.Left,
                }, w)
                local valLbl = make("TextLabel", {
                    Text=tostring(min), TextSize=12, Font=Enum.Font.GothamBold,
                    TextColor3=T.ACCENT_TEXT, BackgroundTransparency=1,
                    Size=UDim2.new(0.3,0,0,20), Position=UDim2.new(0.7,0,0,6),
                    TextXAlignment=Enum.TextXAlignment.Right,
                }, w)
                local track = make("Frame", {
                    Size=UDim2.new(1,0,0,5), Position=UDim2.new(0,0,0,34),
                    BackgroundColor3=T.BORDER, BorderSizePixel=0,
                }, w)
                corner(3,track)
                local fill = make("Frame", { Size=UDim2.new(0,0,1,0), BackgroundColor3=T.ACCENT, BorderSizePixel=0 }, track)
                corner(3,fill)
                local knob = make("Frame", {
                    Size=UDim2.new(0,14,0,14), Position=UDim2.new(0,-7,0.5,-7),
                    BackgroundColor3=T.TEXT_P, BorderSizePixel=0,
                }, fill)
                corner(7,knob); stroke(T.ACCENT,1.5,knob)
                makeDesc(desc,w)
                local dragging=false
                local function upd(absX)
                    local ratio = math.clamp((absX-track.AbsolutePosition.X)/track.AbsoluteSize.X,0,1)
                    value = math.floor(min+(max-min)*ratio)
                    valLbl.Text=tostring(value)
                    fill.Size=UDim2.new(ratio,0,1,0)
                    if callback then callback(value) end
                end
                track.InputBegan:Connect(function(i)
                    if i.UserInputType==Enum.UserInputType.MouseButton1 then dragging=true; upd(i.Position.X) end
                end)
                UserInputService.InputChanged:Connect(function(i)
                    if dragging and i.UserInputType==Enum.UserInputType.MouseMovement then upd(i.Position.X) end
                end)
                UserInputService.InputEnded:Connect(function(i)
                    if i.UserInputType==Enum.UserInputType.MouseButton1 then dragging=false end
                end)
                w.MouseEnter:Connect(function() tw(w,{BackgroundColor3=T.BG_ELEMENT_H}) end)
                w.MouseLeave:Connect(function() tw(w,{BackgroundColor3=T.BG_ELEMENT}) end)
            end

            -- Button
            function Tab:Button(name, callback)
                local w = make("TextButton", {
                    Text="", Size=UDim2.new(1,0,0,40),
                    BackgroundColor3=T.BG_ELEMENT, BorderSizePixel=0,
                    AutoButtonColor=false, LayoutOrder=nO(),
                }, page)
                corner(8,w); stroke(T.BORDER,0.7,w)
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
                w.MouseButton1Down:Connect(function() tw(w,{BackgroundColor3=dimColor(T.ACCENT,0.15)}) end)
                w.MouseButton1Up:Connect(function()
                    tw(w,{BackgroundColor3=T.BG_ELEMENT_H})
                    if callback then callback() end
                end)
            end

            -- Dropdown
            function Tab:Dropdown(name, options, callback, desc)
                local open=false
                local w = make("Frame", {
                    Size=UDim2.new(1,0,0,52), BackgroundColor3=T.BG_ELEMENT,
                    BorderSizePixel=0, LayoutOrder=nO(), ClipsDescendants=false,
                }, page)
                corner(8,w); stroke(T.BORDER,0.7,w); pad(0,0,14,14,w)
                make("TextLabel", {
                    Text=name, TextSize=13, Font=Enum.Font.GothamBold,
                    TextColor3=T.TEXT_P, BackgroundTransparency=1,
                    Size=UDim2.new(1,-50,0,20), Position=UDim2.new(0,0,0,8),
                    TextXAlignment=Enum.TextXAlignment.Left,
                }, w)
                makeDesc(desc,w)
                local selLbl = make("TextLabel", {
                    Text="選択してください", TextSize=11, Font=Enum.Font.Gotham,
                    TextColor3=T.TEXT_M, BackgroundTransparency=1,
                    Size=UDim2.new(1,-30,0,16), Position=UDim2.new(0,0,0,30),
                    TextXAlignment=Enum.TextXAlignment.Left,
                }, w)
                local arrow = make("TextLabel", {
                    Text="▾", TextSize=12, Font=Enum.Font.Gotham,
                    TextColor3=T.ACCENT, BackgroundTransparency=1,
                    Size=UDim2.new(0,20,1,0), Position=UDim2.new(1,-22,0,0),
                    TextXAlignment=Enum.TextXAlignment.Center,
                }, w)
                local dropList = make("Frame", {
                    Size=UDim2.new(1,0,0,0), Position=UDim2.new(0,0,1,4),
                    BackgroundColor3=Color3.fromRGB(8,20,38),
                    BorderSizePixel=0, ZIndex=10, ClipsDescendants=true, Visible=false,
                }, w)
                corner(8,dropList); stroke(T.BORDER,0.7,dropList)
                make("UIListLayout",{SortOrder=Enum.SortOrder.LayoutOrder,Padding=UDim.new(0,2)},dropList)
                pad(4,4,6,6,dropList)
                local totalH=8
                for i,opt in ipairs(options) do
                    local ob = make("TextButton", {
                        Text=opt, TextSize=12, Font=Enum.Font.Gotham,
                        TextColor3=T.TEXT_S, BackgroundTransparency=1,
                        BackgroundColor3=T.BG_ELEMENT, BorderSizePixel=0,
                        AutoButtonColor=false, Size=UDim2.new(1,0,0,28),
                        LayoutOrder=i, TextXAlignment=Enum.TextXAlignment.Left, ZIndex=11,
                    }, dropList)
                    pad(0,0,6,0,ob); corner(6,ob); totalH+=30
                    ob.MouseEnter:Connect(function() tw(ob,{BackgroundTransparency=0.85,BackgroundColor3=T.ACCENT,TextColor3=T.ACCENT_TEXT}) end)
                    ob.MouseLeave:Connect(function() tw(ob,{BackgroundTransparency=1,TextColor3=T.TEXT_S}) end)
                    ob.MouseButton1Click:Connect(function()
                        selLbl.Text=opt; tw(selLbl,{TextColor3=T.ACCENT_TEXT})
                        open=false
                        tw(dropList,{Size=UDim2.new(1,0,0,0)},TW_MED)
                        tw(arrow,{Rotation=0})
                        wait(0.21); dropList.Visible=false
                        if callback then callback(opt) end
                    end)
                end
                local hb = make("TextButton", {
                    Text="", Size=UDim2.new(1,0,1,0),
                    BackgroundTransparency=1, BorderSizePixel=0, AutoButtonColor=false, ZIndex=5,
                }, w)
                hb.MouseButton1Click:Connect(function()
                    open=not open
                    if open then
                        dropList.Visible=true; dropList.Size=UDim2.new(1,0,0,0)
                        tw(dropList,{Size=UDim2.new(1,0,0,totalH)},TW_MED)
                        tw(arrow,{Rotation=180})
                    else
                        tw(dropList,{Size=UDim2.new(1,0,0,0)},TW_MED)
                        tw(arrow,{Rotation=0}); wait(0.21); dropList.Visible=false
                    end
                end)
                w.MouseEnter:Connect(function() tw(w,{BackgroundColor3=T.BG_ELEMENT_H}) end)
                w.MouseLeave:Connect(function() tw(w,{BackgroundColor3=T.BG_ELEMENT}) end)
            end

            -- Accordion
            function Tab:Accordion(name, items, desc)
                local open=false
                local itemH,closedH=30,52
                local openH=closedH+(#items*(itemH+4))+8
                local w = make("Frame", {
                    Size=UDim2.new(1,0,0,closedH), BackgroundColor3=T.BG_ELEMENT,
                    BorderSizePixel=0, LayoutOrder=nO(), ClipsDescendants=true,
                }, page)
                corner(8,w); stroke(T.BORDER,0.7,w); pad(0,0,14,14,w)
                make("TextLabel", {
                    Text=name, TextSize=13, Font=Enum.Font.GothamBold,
                    TextColor3=T.TEXT_P, BackgroundTransparency=1,
                    Size=UDim2.new(1,-30,0,20), Position=UDim2.new(0,0,0,8),
                    TextXAlignment=Enum.TextXAlignment.Left,
                }, w)
                makeDesc(desc,w)
                local arrow = make("TextLabel", {
                    Text="▾", TextSize=12, Font=Enum.Font.Gotham,
                    TextColor3=T.ACCENT, BackgroundTransparency=1,
                    Size=UDim2.new(0,20,0,20), Position=UDim2.new(1,-22,0,8),
                    TextXAlignment=Enum.TextXAlignment.Center,
                }, w)
                make("Frame", {
                    Size=UDim2.new(1,0,0,1), Position=UDim2.new(0,0,0,closedH-1),
                    BackgroundColor3=T.BORDER, BorderSizePixel=0,
                }, w)
                for i,item in ipairs(items) do
                    make("TextLabel", {
                        Text="  · "..item, TextSize=12, Font=Enum.Font.Gotham,
                        TextColor3=T.TEXT_S, BackgroundTransparency=1,
                        Size=UDim2.new(1,0,0,itemH),
                        Position=UDim2.new(0,0,0,closedH+(i-1)*(itemH+4)+4),
                        TextXAlignment=Enum.TextXAlignment.Left,
                    }, w)
                end
                local hb = make("TextButton", {
                    Text="", Size=UDim2.new(1,0,0,closedH),
                    BackgroundTransparency=1, BorderSizePixel=0, AutoButtonColor=false,
                }, w)
                hb.MouseButton1Click:Connect(function()
                    open=not open
                    tw(w,{Size=UDim2.new(1,0,0,open and openH or closedH)},TW_MED)
                    tw(arrow,{Rotation=open and 180 or 0})
                end)
                w.MouseEnter:Connect(function() tw(w,{BackgroundColor3=T.BG_ELEMENT_H}) end)
                w.MouseLeave:Connect(function() tw(w,{BackgroundColor3=T.BG_ELEMENT}) end)
            end

            -- Separator
            function Tab:Separator(labelText)
                local sep = make("Frame", {
                    Size=UDim2.new(1,0,0,20), BackgroundTransparency=1,
                    BorderSizePixel=0, LayoutOrder=nO(),
                }, page)
                if labelText and labelText~="" then
                    make("TextLabel", {
                        Text=labelText, TextSize=10, Font=Enum.Font.GothamBold,
                        TextColor3=T.TEXT_M, BackgroundTransparency=1,
                        Size=UDim2.new(0,80,1,0), TextXAlignment=Enum.TextXAlignment.Left,
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

            return Tab
        end

        return Window
    end

    -- ══════════════════════════════════════
    --  シーケンス実行
    -- ══════════════════════════════════════
    spawn(function()
        -- 1. 起動アニメ
        playIntro()

        -- 2. KEYシステム（有効なら）
        if KeyConfig.Enabled then
            showKeySystem()
        end

        -- 3. メインGUI
        buildMainGUI()
    end)

    -- CreateWindowはすぐWindowオブジェクトを返せないため
    -- 非同期でGUIが構築される。Windowの参照を渡す中継オブジェクトを返す
    local proxy = {}
    local realWindow = nil
    local queue = {}

    -- buildMainGUI完了まで呼び出しをキューに溜める
    local originalBuild = buildMainGUI
    buildMainGUI = function()
        realWindow = originalBuild()
        for _, fn in ipairs(queue) do fn() end
    end

    function proxy:CreateTab(name, icon)
        -- Tabオブジェクトのプロキシ
        local tabProxy = {}
        local realTab = nil
        local tabQueue = {}

        local function ensureTab()
            if realWindow and not realTab then
                realTab = realWindow:CreateTab(name, icon)
                for _, fn in ipairs(tabQueue) do fn() end
            end
        end

        local methods = {"Toggle","Slider","Button","Dropdown","Accordion","Separator"}
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

    return proxy
end

return Library
