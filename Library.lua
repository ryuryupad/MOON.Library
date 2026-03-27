-- ╔══════════════════════════════════════════════════════════════╗
-- ║                  Library.lua  (v2.1)                        ║
-- ║  Dropdown/Sliderバグ修正・ドラッグ・最小化・削除ボタン追加   ║
-- ╚══════════════════════════════════════════════════════════════╝

local Players          = game:GetService("Players")
local TweenService     = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui   = LocalPlayer:WaitForChild("PlayerGui")

-- ─────────────────────────────────────────
--  Tween ユーティリティ
-- ─────────────────────────────────────────
local TW_FAST = TweenInfo.new(0.12, Enum.EasingStyle.Quad,  Enum.EasingDirection.Out)
local TW_MED  = TweenInfo.new(0.22, Enum.EasingStyle.Quad,  Enum.EasingDirection.Out)
local TW_SLOW = TweenInfo.new(0.50, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)

local function tw(obj, props, info)
    TweenService:Create(obj, info or TW_FAST, props):Play()
end
local function twWait(obj, props, info)
    local t = TweenService:Create(obj, info or TW_FAST, props)
    t:Play(); t.Completed:Wait()
end

-- ─────────────────────────────────────────
--  インスタンスユーティリティ
-- ─────────────────────────────────────────
local function make(class, props, parent)
    local o = Instance.new(class)
    for k, v in pairs(props) do o[k] = v end
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

-- ─────────────────────────────────────────
--  グリッチテキスト
-- ─────────────────────────────────────────
local GLITCH_CHARS = "!<>-_\\/[]{}—=+*^?#"
local function glitchText(label, finalText, duration)
    local steps = math.floor(duration / 0.04)
    spawn(function()
        for i = 1, steps do
            local revealed = math.floor(#finalText * (i/steps))
            local result   = string.sub(finalText, 1, revealed)
            for _ = 1, #finalText - revealed do
                result = result .. string.sub(GLITCH_CHARS, math.random(1,#GLITCH_CHARS), math.random(1,#GLITCH_CHARS))
            end
            label.Text = result
            wait(0.04)
        end
        label.Text = finalText
    end)
end

-- ══════════════════════════════════════════
--  Library
-- ══════════════════════════════════════════
local Library = {}

function Library:CreateWindow(config)
    config = config or {}

    local Title     = config.Title    or "UI Library"
    local Subtitle  = config.Subtitle or "v1.0"
    local Accent    = config.Color    or Color3.fromRGB(40, 130, 255)
    local Keybind   = config.Keybind  or Enum.KeyCode.RightShift
    local Neon      = config.Neon     ~= nil and config.Neon or false
    local KeyConfig = config.KeySystem or { Enabled = false }

    -- テーマ
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
        TEXT_M       = Color3.fromRGB(55,   75, 105),
        ACCENT       = Accent,
        ACCENT_DIM   = dimColor(Accent, 0.22),
        ACCENT_TEXT  = lightenColor(Accent, 0.35),
        STATUS_GREEN = Color3.fromRGB(40,  200, 100),
        STATUS_RED   = Color3.fromRGB(220,  60,  60),
    }

    local gui = make("ScreenGui", {
        Name = "ryu_ui", ResetOnSpawn = false,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        IgnoreGuiInset = true,
    }, PlayerGui)

    -- ════════════════════════════
    --  1. 起動アニメーション
    -- ════════════════════════════
    local function playIntro()
        local overlay = make("Frame", {
            Size = UDim2.new(1,0,1,0),
            BackgroundColor3 = Color3.fromRGB(2,6,14),
            BorderSizePixel = 0, ZIndex = 100,
        }, gui)

        -- パーティクル
        local particles = {}
        for i = 1, 28 do
            local sz = math.random(2,5)
            local p = make("Frame", {
                Size = UDim2.new(0,sz,0,sz),
                Position = UDim2.new(math.random(0,100)/100, 0, math.random(0,100)/100, 0),
                BackgroundColor3 = Accent,
                BorderSizePixel = 0,
                BackgroundTransparency = math.random(40,85)/100,
                ZIndex = 101,
            }, overlay)
            corner(sz, p)
            table.insert(particles, p)
        end
        spawn(function()
            for _, p in pairs(particles) do
                local sp = p.Position
                spawn(function()
                    while p and p.Parent do
                        local tx = math.clamp(sp.X.Scale+(math.random(-8,8)/100),0,0.98)
                        local ty = math.clamp(sp.Y.Scale+(math.random(-8,8)/100),0,0.98)
                        tw(p, { Position=UDim2.new(tx,0,ty,0), BackgroundTransparency=math.random(30,80)/100 },
                            TweenInfo.new(math.random(15,30)/10, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut))
                        wait(math.random(15,30)/10)
                    end
                end)
            end
        end)

        local center = make("Frame", {
            Size=UDim2.new(0,320,0,140), Position=UDim2.new(0.5,-160,0.5,-70),
            BackgroundTransparency=1, ZIndex=102,
        }, overlay)

        local logoLine = make("Frame", {
            Size=UDim2.new(0,0,0,2), Position=UDim2.new(0.5,0,0,0),
            BackgroundColor3=Accent, BorderSizePixel=0, ZIndex=103,
        }, center)
        corner(1, logoLine)

        local titleLbl = make("TextLabel", {
            Text=Title, TextSize=38, Font=Enum.Font.GothamBold,
            TextColor3=T.TEXT_P, BackgroundTransparency=1,
            Size=UDim2.new(1,0,0,56), Position=UDim2.new(0,0,0,20),
            TextXAlignment=Enum.TextXAlignment.Center,
            TextTransparency=1, ZIndex=103,
        }, center)

        local subLbl = make("TextLabel", {
            Text=Subtitle, TextSize=13, Font=Enum.Font.Gotham,
            TextColor3=T.ACCENT_TEXT, BackgroundTransparency=1,
            Size=UDim2.new(1,0,0,20), Position=UDim2.new(0,0,0,78),
            TextXAlignment=Enum.TextXAlignment.Center,
            TextTransparency=1, ZIndex=103,
        }, center)

        local barTrack = make("Frame", {
            Size=UDim2.new(0,200,0,3), Position=UDim2.new(0.5,-100,0,112),
            BackgroundColor3=Color3.fromRGB(20,35,58),
            BorderSizePixel=0, ZIndex=103,
        }, center)
        corner(2, barTrack)
        local barFill = make("Frame", {
            Size=UDim2.new(0,0,1,0), BackgroundColor3=Accent,
            BorderSizePixel=0, ZIndex=104,
        }, barTrack)
        corner(2, barFill)

        local statusLbl = make("TextLabel", {
            Text="Initializing...", TextSize=11, Font=Enum.Font.Gotham,
            TextColor3=T.TEXT_M, BackgroundTransparency=1,
            Size=UDim2.new(1,0,0,16), Position=UDim2.new(0,0,0,122),
            TextXAlignment=Enum.TextXAlignment.Center, ZIndex=103,
        }, center)

        wait(0.1)
        twWait(logoLine, { Size=UDim2.new(1,0,0,2), Position=UDim2.new(0,0,0,0) }, TW_SLOW)
        tw(titleLbl, { TextTransparency=0 }, TweenInfo.new(0.4,Enum.EasingStyle.Quad,Enum.EasingDirection.Out))
        glitchText(titleLbl, Title, 0.7)
        wait(0.5)
        twWait(subLbl, { TextTransparency=0 }, TweenInfo.new(0.35,Enum.EasingStyle.Quad,Enum.EasingDirection.Out))

        for _, step in ipairs({
            { text="Loading modules...",  pct=0.30 },
            { text="Connecting...",       pct=0.55 },
            { text="Verifying assets...", pct=0.80 },
            { text="Ready.",              pct=1.00 },
        }) do
            statusLbl.Text = step.text
            twWait(barFill, { Size=UDim2.new(step.pct,0,1,0) },
                TweenInfo.new(0.3,Enum.EasingStyle.Quad,Enum.EasingDirection.Out))
            wait(0.18)
        end
        wait(0.3)
        twWait(overlay, { BackgroundTransparency=1 },
            TweenInfo.new(0.45,Enum.EasingStyle.Quad,Enum.EasingDirection.Out))
        overlay:Destroy()
    end

    -- ════════════════════════════
    --  2. KEYシステム
    -- ════════════════════════════
    local function showKeySystem()
        local successSignal = Instance.new("BindableEvent")

        local overlay = make("Frame", {
            Size=UDim2.new(1,0,1,0),
            BackgroundColor3=Color3.fromRGB(3,8,16),
            BackgroundTransparency=0.3,
            BorderSizePixel=0, ZIndex=50,
        }, gui)

        local card = make("Frame", {
            Size=UDim2.new(0,380,0,210),
            Position=UDim2.new(0.5,-190,0.5,-105),
            BackgroundColor3=T.BG_MAIN,
            BorderSizePixel=0, ZIndex=51,
            BackgroundTransparency=1,
        }, overlay)
        corner(14, card)
        uiStroke(T.BORDER, 1, card)
        tw(card, { BackgroundTransparency=0 }, TweenInfo.new(0.3,Enum.EasingStyle.Quad,Enum.EasingDirection.Out))

        -- アクセントトップライン
        local topLine = make("Frame", {
            Size=UDim2.new(1,0,0,2), BackgroundColor3=Accent,
            BorderSizePixel=0, ZIndex=52,
        }, card)
        corner(14, topLine)
        make("Frame", {
            Size=UDim2.new(1,0,0.5,0), Position=UDim2.new(0,0,0,1),
            BackgroundColor3=Accent, BorderSizePixel=0, ZIndex=52,
        }, topLine)

        pad(20,20,24,24, card)

        make("TextLabel", {
            Text=KeyConfig.Title or "Key Required",
            TextSize=17, Font=Enum.Font.GothamBold,
            TextColor3=T.TEXT_P, BackgroundTransparency=1,
            Size=UDim2.new(1,0,0,26), Position=UDim2.new(0,0,0,14),
            TextXAlignment=Enum.TextXAlignment.Left, ZIndex=53,
        }, card)
        make("TextLabel", {
            Text=KeyConfig.Hint or "有効なキーを入力してください",
            TextSize=11, Font=Enum.Font.Gotham,
            TextColor3=T.TEXT_M, BackgroundTransparency=1,
            Size=UDim2.new(1,0,0,16), Position=UDim2.new(0,0,0,42),
            TextXAlignment=Enum.TextXAlignment.Left, ZIndex=53,
        }, card)

        local inputBg = make("Frame", {
            Size=UDim2.new(1,0,0,38), Position=UDim2.new(0,0,0,70),
            BackgroundColor3=T.BG_ELEMENT, BorderSizePixel=0, ZIndex=53,
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
            ClearTextOnFocus=false, ZIndex=54,
        }, inputBg)

        input.Focused:Connect(function()  tw(inputStroke, { Color=Accent }) end)
        input.FocusLost:Connect(function() tw(inputStroke, { Color=T.BORDER }) end)

        local statusLbl = make("TextLabel", {
            Text="", TextSize=11, Font=Enum.Font.Gotham,
            TextColor3=T.TEXT_M, BackgroundTransparency=1,
            Size=UDim2.new(1,0,0,14), Position=UDim2.new(0,0,0,118),
            TextXAlignment=Enum.TextXAlignment.Left, ZIndex=53,
        }, card)

        local submitBtn = make("TextButton", {
            Text="Confirm", TextSize=13, Font=Enum.Font.GothamBold,
            TextColor3=T.BG_MAIN, BackgroundColor3=Accent,
            BorderSizePixel=0, AutoButtonColor=false,
            Size=UDim2.new(1,0,0,36), Position=UDim2.new(0,0,0,152),
            ZIndex=53,
        }, card)
        corner(8, submitBtn)
        submitBtn.MouseEnter:Connect(function() tw(submitBtn,{BackgroundColor3=lightenColor(Accent,0.1)}) end)
        submitBtn.MouseLeave:Connect(function() tw(submitBtn,{BackgroundColor3=Accent}) end)

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
        submitBtn.MouseButton1Click:Connect(function()
            if not active then return end
            if input.Text == "" then
                statusLbl.Text = "キーを入力してください"
                statusLbl.TextColor3 = T.STATUS_RED
                return
            end
            active = false
            statusLbl.Text = "Verifying..."
            statusLbl.TextColor3 = T.TEXT_M
            wait(0.4)
            if validateKey(input.Text) then
                statusLbl.Text = "✓ 認証成功"
                statusLbl.TextColor3 = T.STATUS_GREEN
                tw(topLine, { BackgroundColor3=T.STATUS_GREEN })
                wait(0.7)
                twWait(overlay, { BackgroundTransparency=1 },
                    TweenInfo.new(0.3,Enum.EasingStyle.Quad,Enum.EasingDirection.Out))
                overlay:Destroy()
                successSignal:Fire()
            else
                statusLbl.Text = "✕ 無効なキーです"
                statusLbl.TextColor3 = T.STATUS_RED
                local origPos = inputBg.Position
                for i = 1, 4 do
                    twWait(inputBg, {
                        Position=UDim2.new(0, i%2==0 and 6 or -6, 0, 70)
                    }, TweenInfo.new(0.05,Enum.EasingStyle.Quad))
                end
                inputBg.Position = origPos
                active = true
            end
        end)
        input.FocusLost:Connect(function(enter)
            if enter then submitBtn.MouseButton1Click:Fire() end
        end)

        successSignal.Event:Wait()
        successSignal:Destroy()
    end

    -- ════════════════════════════
    --  3. メインGUI
    -- ════════════════════════════
    local function buildMainGUI()
        -- ウィンドウサイズ定数
        local WIN_W, WIN_H = 680, 480
        local SIDEBAR_W    = 148
        local TOPBAR_H     = 50

        local main = make("Frame", {
            Name="MainFrame",
            Size=UDim2.new(0, WIN_W, 0, 0),
            Position=UDim2.new(0.5,-WIN_W/2, 0.5,-WIN_H/2),
            BackgroundColor3=T.BG_MAIN,
            BorderSizePixel=0, ClipsDescendants=true,
        }, gui)
        corner(12, main)
        uiStroke(T.BORDER, 1, main)

        -- 開くアニメ
        twWait(main, { Size=UDim2.new(0,WIN_W,0,WIN_H) }, TW_SLOW)

        -- Neon
        if Neon then
            local glow = make("UIStroke", {
                Color=Accent, Thickness=1.5,
                ApplyStrokeMode=Enum.ApplyStrokeMode.Border,
            }, main)
            spawn(function()
                local up = true
                while gui.Parent do
                    twWait(glow, { Thickness=up and 2.8 or 1.0 },
                        TweenInfo.new(1.4,Enum.EasingStyle.Sine,Enum.EasingDirection.InOut))
                    up = not up
                end
            end)
        end

        -- ── トップバー ──────────────────────
        local topBar = make("Frame", {
            Size=UDim2.new(1,0,0,TOPBAR_H),
            BackgroundColor3=T.BG_TOPBAR,
            BorderSizePixel=0, ZIndex=3,
        }, main)
        corner(12, topBar)
        -- 下半分角丸つぶし
        make("Frame", {
            Size=UDim2.new(1,0,0.5,0), Position=UDim2.new(0,0,0.5,0),
            BackgroundColor3=T.BG_TOPBAR, BorderSizePixel=0, ZIndex=3,
        }, topBar)
        -- 下境界線
        make("Frame", {
            Size=UDim2.new(1,0,0,1), Position=UDim2.new(0,0,1,-1),
            BackgroundColor3=T.BORDER, BorderSizePixel=0, ZIndex=4,
        }, topBar)

        -- トラフィックドット（装飾）
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
            corner(6, d)
        end

        -- タイトル（左寄せ、ドットの右から）
        make("TextLabel", {
            Text=Title, TextSize=14, Font=Enum.Font.GothamBold,
            TextColor3=T.ACCENT_TEXT, BackgroundTransparency=1,
            Size=UDim2.new(1,-180,1,0),
            Position=UDim2.new(0,78,0,0),   -- ドット群(14+54=68)の右に余白
            TextXAlignment=Enum.TextXAlignment.Left, ZIndex=5,
        }, topBar)

        -- ── 右側ボタン群（最小化・閉じる）──
        local btnArea = make("Frame", {
            Size=UDim2.new(0,64,1,0), Position=UDim2.new(1,-68,0,0),
            BackgroundTransparency=1, ZIndex=5,
        }, topBar)

        -- 最小化ボタン
        local minimized = false
        local minimizeBtn = make("TextButton", {
            Text="─", TextSize=14, Font=Enum.Font.GothamBold,
            TextColor3=T.TEXT_M, BackgroundTransparency=1,
            Size=UDim2.new(0,28,1,0), Position=UDim2.new(0,0,0,0),
            AutoButtonColor=false, ZIndex=5,
        }, btnArea)
        minimizeBtn.MouseEnter:Connect(function() tw(minimizeBtn,{TextColor3=Color3.fromRGB(254,188,46)}) end)
        minimizeBtn.MouseLeave:Connect(function() tw(minimizeBtn,{TextColor3=T.TEXT_M}) end)
        minimizeBtn.MouseButton1Click:Connect(function()
            minimized = not minimized
            if minimized then
                -- トップバーだけ残してコンテンツを隠す
                twWait(main, { Size=UDim2.new(0,WIN_W,0,TOPBAR_H) }, TW_MED)
            else
                twWait(main, { Size=UDim2.new(0,WIN_W,0,WIN_H) }, TW_MED)
            end
        end)

        -- 閉じるボタン
        local closeBtn = make("TextButton", {
            Text="✕", TextSize=13, Font=Enum.Font.GothamBold,
            TextColor3=T.TEXT_M, BackgroundTransparency=1,
            Size=UDim2.new(0,28,1,0), Position=UDim2.new(0,30,0,0),
            AutoButtonColor=false, ZIndex=5,
        }, btnArea)
        closeBtn.MouseEnter:Connect(function() tw(closeBtn,{TextColor3=Color3.fromRGB(255,95,87)}) end)
        closeBtn.MouseLeave:Connect(function() tw(closeBtn,{TextColor3=T.TEXT_M}) end)
        closeBtn.MouseButton1Click:Connect(function()
            twWait(main, { Size=UDim2.new(0,WIN_W,0,0) }, TW_MED)
            gui:Destroy()
        end)

        -- ── ドラッグ（トップバー限定）──────
        do
            local drag, ds, sp
            topBar.InputBegan:Connect(function(i)
                if i.UserInputType == Enum.UserInputType.MouseButton1 then
                    drag = true
                    ds   = i.Position
                    sp   = main.Position
                end
            end)
            UserInputService.InputChanged:Connect(function(i)
                if drag and i.UserInputType == Enum.UserInputType.MouseMovement then
                    local d = i.Position - ds
                    main.Position = UDim2.new(
                        sp.X.Scale, sp.X.Offset + d.X,
                        sp.Y.Scale, sp.Y.Offset + d.Y
                    )
                end
            end)
            UserInputService.InputEnded:Connect(function(i)
                if i.UserInputType == Enum.UserInputType.MouseButton1 then
                    drag = false
                end
            end)
        end

        -- ── サイドバー ──────────────────────
        local sidebar = make("Frame", {
            Size=UDim2.new(0,SIDEBAR_W,1,-TOPBAR_H),
            Position=UDim2.new(0,0,0,TOPBAR_H),
            BackgroundColor3=T.BG_SIDEBAR, BorderSizePixel=0, ZIndex=2,
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
        pad(10,10,0,0, sideScroll)

        -- ── コンテンツエリア ────────────────
        -- DropdownがUIの外に出られるようZIndexBehavior=Globalのフレームを使う
        local contentArea = make("Frame", {
            Size=UDim2.new(1,-SIDEBAR_W,1,-TOPBAR_H),
            Position=UDim2.new(0,SIDEBAR_W,0,TOPBAR_H),
            BackgroundColor3=T.BG_CONTENT, BorderSizePixel=0,
            ClipsDescendants=false,   -- Dropdown表示のためfalse
        }, main)

        -- キーバインドトグル
        local visible = true
        UserInputService.InputBegan:Connect(function(i, gpe)
            if gpe then return end
            if i.KeyCode == Keybind then
                visible = not visible
                tw(main, {
                    Size = visible
                        and UDim2.new(0,WIN_W,0,WIN_H)
                        or  UDim2.new(0,WIN_W,0,0)
                }, TW_MED)
            end
        end)

        -- タブ管理
        local pages    = {}
        local tabBtns  = {}
        local activeTab = nil

        local function switchTab(name)
            for n, pg in pairs(pages)   do pg.Visible = false end
            for n, tb in pairs(tabBtns) do
                if n ~= name then tb.deactivate() end
            end
            if pages[name]   then pages[name].Visible = true end
            if tabBtns[name] then tabBtns[name].activate()   end
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
            corner(2, accentBar)

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
                tw(btn,      { BackgroundTransparency=0.88 })
                tw(btn,      { BackgroundColor3=dimColor(T.ACCENT,0.4) })
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

            -- ページ（Dropdownがはみ出せるようClipsDescendants=false）
            local page = make("ScrollingFrame", {
                Size=UDim2.new(1,0,1,0),
                BackgroundTransparency=1, BorderSizePixel=0,
                ScrollBarThickness=3, ScrollBarImageColor3=T.BORDER,
                CanvasSize=UDim2.new(0,0,0,0),
                AutomaticCanvasSize=Enum.AutomaticSize.Y,
                Visible=false,
                ClipsDescendants=false,   -- ← Dropdown修正ポイント
            }, contentArea)
            make("UIListLayout", {
                SortOrder=Enum.SortOrder.LayoutOrder,
                Padding=UDim.new(0,6),
            }, page)
            pad(12,12,12,12, page)

            pages[name] = page
            if activeTab == nil then switchTab(name) end

            -- ─────────────────────────────
            --  Tab オブジェクト
            -- ─────────────────────────────
            local Tab = {}
            local elOrder = 0
            local function nO() elOrder += 1; return elOrder end

            -- 共通ラッパー
            local function makeWrap(h, ord)
                local w = make("Frame", {
                    Size=UDim2.new(1,0,0,h),
                    BackgroundColor3=T.BG_ELEMENT,
                    BorderSizePixel=0, LayoutOrder=ord,
                    ClipsDescendants=false,
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
            --  Slider  ★ {min=N, max=N} 形式
            -- ─────────────────────────────
            function Tab:Slider(name, range, callback, desc)
                -- {min=16, max=200} または {16, 200} 両対応
                local minVal = range.min or range[1] or 0
                local maxVal = range.max or range[2] or 100
                local value  = minVal

                local w = makeWrap(66, nO())
                w.Size = UDim2.new(1,0,0,66)

                -- 名前
                make("TextLabel", {
                    Text=name, TextSize=13, Font=Enum.Font.GothamBold,
                    TextColor3=T.TEXT_P, BackgroundTransparency=1,
                    Size=UDim2.new(0.65,0,0,20), Position=UDim2.new(0,0,0,6),
                    TextXAlignment=Enum.TextXAlignment.Left,
                }, w)

                -- 現在値
                local valLbl = make("TextLabel", {
                    Text=tostring(minVal),
                    TextSize=12, Font=Enum.Font.GothamBold,
                    TextColor3=T.ACCENT_TEXT, BackgroundTransparency=1,
                    Size=UDim2.new(0.35,0,0,20), Position=UDim2.new(0.65,0,0,6),
                    TextXAlignment=Enum.TextXAlignment.Right,
                }, w)

                -- min/max 表示
                make("TextLabel", {
                    Text=tostring(minVal),
                    TextSize=9, Font=Enum.Font.Gotham,
                    TextColor3=T.TEXT_M, BackgroundTransparency=1,
                    Size=UDim2.new(0,30,0,12), Position=UDim2.new(0,0,0,50),
                    TextXAlignment=Enum.TextXAlignment.Left,
                }, w)
                make("TextLabel", {
                    Text=tostring(maxVal),
                    TextSize=9, Font=Enum.Font.Gotham,
                    TextColor3=T.TEXT_M, BackgroundTransparency=1,
                    Size=UDim2.new(0,30,0,12), Position=UDim2.new(1,-30,0,50),
                    TextXAlignment=Enum.TextXAlignment.Right,
                }, w)

                -- トラック
                local track = make("Frame", {
                    Size=UDim2.new(1,0,0,5), Position=UDim2.new(0,0,0,36),
                    BackgroundColor3=T.BORDER, BorderSizePixel=0,
                }, w)
                corner(3, track)

                local fill = make("Frame", {
                    Size=UDim2.new(0,0,1,0),
                    BackgroundColor3=T.ACCENT, BorderSizePixel=0,
                }, track)
                corner(3, fill)

                local knob = make("Frame", {
                    Size=UDim2.new(0,14,0,14), Position=UDim2.new(1,-7,0.5,-7),
                    BackgroundColor3=T.TEXT_P, BorderSizePixel=0,
                }, fill)
                corner(7, knob)
                uiStroke(T.ACCENT, 1.5, knob)

                makeDesc(desc, w)

                -- ★ドラッグ処理（AbsolutePosition使用・フレーム更新待ち）
                local dragging = false

                local function updateByX(absX)
                    local tPos  = track.AbsolutePosition.X
                    local tSize = track.AbsoluteSize.X
                    if tSize <= 0 then return end
                    local ratio = math.clamp((absX - tPos) / tSize, 0, 1)
                    value = math.round(minVal + (maxVal - minVal) * ratio)
                    valLbl.Text = tostring(value)
                    fill.Size   = UDim2.new(ratio, 0, 1, 0)
                    if callback then callback(value) end
                end

                -- クリック開始
                track.InputBegan:Connect(function(i)
                    if i.UserInputType == Enum.UserInputType.MouseButton1 then
                        dragging = true
                        updateByX(i.Position.X)
                    end
                end)
                -- ドラッグ中
                UserInputService.InputChanged:Connect(function(i)
                    if dragging and i.UserInputType == Enum.UserInputType.MouseMovement then
                        updateByX(i.Position.X)
                    end
                end)
                -- 離す
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
            --  Dropdown  ★ ZIndex・親構造修正
            -- ─────────────────────────────
            function Tab:Dropdown(name, options, callback, desc)
                local open = false
                local selectedOpt = nil

                -- ★ ラッパーはClipsDescendants=false必須
                local w = make("Frame", {
                    Size=UDim2.new(1,0,0,52),
                    BackgroundColor3=T.BG_ELEMENT,
                    BorderSizePixel=0, LayoutOrder=nO(),
                    ClipsDescendants=false,   -- ← ここが重要
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

                -- ★ ドロップリストを gui 直下に置いてZIndex競合を回避
                local dropList = make("Frame", {
                    Size=UDim2.new(0,0,0,0),
                    BackgroundColor3=Color3.fromRGB(8,20,38),
                    BorderSizePixel=0, ZIndex=200,
                    ClipsDescendants=true,
                    Visible=false,
                }, gui)
                corner(8, dropList)
                uiStroke(T.BORDER, 0.7, dropList)

                make("UIListLayout", {
                    SortOrder=Enum.SortOrder.LayoutOrder,
                    Padding=UDim.new(0,2),
                }, dropList)
                pad(4,4,6,6, dropList)

                local ITEM_H   = 28
                local LIST_PAD = 8
                local totalH   = LIST_PAD + #options * (ITEM_H + 2)
                -- wの実ピクセル幅（ScreenGui基準）
                local DROP_W   = 0   -- 開くときAbsoluteで取得

                for i, opt in ipairs(options) do
                    local ob = make("TextButton", {
                        Text=opt, TextSize=12, Font=Enum.Font.Gotham,
                        TextColor3=T.TEXT_S,
                        BackgroundColor3=T.BG_ELEMENT, BackgroundTransparency=1,
                        BorderSizePixel=0, AutoButtonColor=false,
                        Size=UDim2.new(1,0,0,ITEM_H),
                        LayoutOrder=i,
                        TextXAlignment=Enum.TextXAlignment.Left,
                        ZIndex=201,
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
                        -- 閉じる
                        open = false
                        tw(dropList,{Size=UDim2.new(0,DROP_W,0,0)}, TW_MED)
                        tw(arrow,{Rotation=0})
                        task.delay(0.22, function() dropList.Visible=false end)
                        if callback then callback(opt) end
                    end)
                end

                -- ヘッダークリック
                local hb = make("TextButton", {
                    Text="", Size=UDim2.new(1,0,1,0),
                    BackgroundTransparency=1, BorderSizePixel=0,
                    AutoButtonColor=false, ZIndex=5,
                }, w)

                hb.MouseButton1Click:Connect(function()
                    open = not open
                    if open then
                        -- ★ AbsolutePositionで正確な座標を取得
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
                        task.delay(0.22, function() dropList.Visible=false end)
                    end
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
                    tw(w,  { Size=UDim2.new(1,0,0, open and OPEN_H or CLOSE_H) }, TW_MED)
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

            return Tab
        end -- CreateTab

        return Window
    end -- buildMainGUI

    -- ════════════════════════════
    --  シーケンス実行
    -- ════════════════════════════
    local realWindow = nil
    local queue      = {}

    local function runBuild()
        realWindow = buildMainGUI()
        for _, fn in ipairs(queue) do
            spawn(fn)
        end
    end

    spawn(function()
        playIntro()
        if KeyConfig.Enabled then showKeySystem() end
        runBuild()
    end)

    -- プロキシ（非同期でキューに溜める）
    local proxy = {}

    function proxy:CreateTab(name, icon)
        local tabProxy = {}
        local realTab  = nil
        local tabQueue = {}

        local function ensureTab()
            if realWindow and not realTab then
                realTab = realWindow:CreateTab(name, icon)
                for _, fn in ipairs(tabQueue) do fn() end
            end
        end

        for _, m in ipairs({"Toggle","Slider","Button","Dropdown","Accordion","Separator"}) do
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
