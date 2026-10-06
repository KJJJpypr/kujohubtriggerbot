local CONFIG_FILE = "TBUI_Config.json"
local AUTO_EXECUTE_URL = "https://github.com/KJJJpypr/kujohubtriggerbot/blob/main/kujohubtriggerbot.luau"
local LOCAL_AUTO_EXECUTE_FILE = "kujohubtriggerbot.luau"
local PANEL_WIDTH, PANEL_HEIGHT = 292, 536
local GUI_DISPLAY_ORDER = 2147483647

local Settings = {
    Enabled = false,
    RightClickOnly = false,
    AutoExecute = false,
    SilentExecute = false,
    Head = true,
    Torso = true,
    Legs = false,
    ReactionDelay = 0.10,
    ReleaseDelay = 0.10,
    MenuKey = "RightControl",
    ActivationKey = "MouseButton2"
}

local C = {
    Black = Color3.fromRGB(0, 0, 0),
    Panel = Color3.fromRGB(8, 8, 8),
    Panel2 = Color3.fromRGB(14, 14, 14),
    White = Color3.fromRGB(240, 240, 240),
    Gray = Color3.fromRGB(145, 145, 145),
    DarkGray = Color3.fromRGB(55, 55, 55),
    Border = Color3.fromRGB(38, 38, 38),
    Green = Color3.fromRGB(45, 210, 95),
    Yellow = Color3.fromRGB(235, 190, 65),
    Red = Color3.fromRGB(220, 70, 70)
}

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local HttpService = game:GetService("HttpService")
local GuiService = game:GetService("GuiService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local Camera = workspace.CurrentCamera

local GuiParent = PlayerGui
pcall(function()
    if type(gethui) == "function" then
        local hui = gethui()
        if hui then
            GuiParent = hui
        end
    end
end)

local function Create(className, properties, parent)
    local object = Instance.new(className)
    for property, value in pairs(properties) do
        object[property] = value
    end
    object.Parent = parent
    return object
end

local function AddCorner(object, radius)
    Create("UICorner", {
        CornerRadius = UDim.new(0, radius)
    }, object)
end

local function AddStroke(object, transparency)
    Create("UIStroke", {
        Color = C.Border,
        Thickness = 1,
        Transparency = transparency or 0
    }, object)
end

local function Tween(object, duration, properties, easingStyle, easingDirection)
    if duration <= 0 then
        for property, value in pairs(properties) do
            object[property] = value
        end
        return nil
    end

    local info = TweenInfo.new(
        duration,
        easingStyle or Enum.EasingStyle.Quart,
        easingDirection or Enum.EasingDirection.Out
    )

    local tween = TweenService:Create(object, info, properties)
    tween:Play()
    return tween
end

local function IsValidInputName(name)
    if type(name) ~= "string" then
        return false
    end

    if name == "MouseButton1" or name == "MouseButton2" or name == "MouseButton3" then
        return true
    end

    local ok, keyCode = pcall(function()
        return Enum.KeyCode[name]
    end)

    return ok and keyCode ~= nil
end

local function InputToName(input)
    if input.UserInputType == Enum.UserInputType.Keyboard then
        if input.KeyCode == Enum.KeyCode.Unknown then
            return nil
        end
        return input.KeyCode.Name
    end

    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        return "MouseButton1"
    end

    if input.UserInputType == Enum.UserInputType.MouseButton2 then
        return "MouseButton2"
    end

    if input.UserInputType == Enum.UserInputType.MouseButton3 then
        return "MouseButton3"
    end

    return nil
end

local function InputMatches(input, configuredName)
    return InputToName(input) == configuredName
end

local function PrettyInputName(name)
    local aliases = {
        MouseButton1 = "LMB",
        MouseButton2 = "RMB",
        MouseButton3 = "MMB",
        RightControl = "RCTRL",
        LeftControl = "LCTRL",
        RightShift = "RSHIFT",
        LeftShift = "LSHIFT",
        RightAlt = "RALT",
        LeftAlt = "LALT",
        Return = "ENTER",
        Backspace = "BACKSPACE",
        Space = "SPACE",
        Tab = "TAB",
        Escape = "ESC",
        CapsLock = "CAPSLOCK"
    }

    return aliases[name] or name
end

local function NormalizeAutoExecuteUrl(url)
    if type(url) ~= "string" then
        return nil
    end

    url = url:gsub("^%s+", ""):gsub("%s+$", "")
    if url == "" then
        return nil
    end

    local owner, repo, ref, path = url:match("^https://github%.com/([^/]+)/([^/]+)/blob/([^/]+)/(.+)$")
    if owner and repo and ref and path then
        return string.format(
            "https://raw.githubusercontent.com/%s/%s/%s/%s",
            owner,
            repo,
            ref,
            path
        )
    end

    return url
end

local function LoadConfig()
    if type(readfile) ~= "function" then
        return false
    end

    local fileContents
    local readOk = pcall(function()
        fileContents = readfile(CONFIG_FILE)
    end)

    if not readOk or type(fileContents) ~= "string" or fileContents == "" then
        return false
    end

    local decodeOk, data = pcall(function()
        return HttpService:JSONDecode(fileContents)
    end)

    if not decodeOk or type(data) ~= "table" then
        return false
    end

    local booleanKeys = {
        "Enabled",
        "RightClickOnly",
        "AutoExecute",
        "SilentExecute",
        "Head",
        "Torso",
        "Legs"
    }

    for _, key in ipairs(booleanKeys) do
        if type(data[key]) == "boolean" then
            Settings[key] = data[key]
        end
    end

    if type(data.ReactionDelay) == "number" then
        Settings.ReactionDelay = math.clamp(data.ReactionDelay, 0, 1)
    end

    if type(data.ReleaseDelay) == "number" then
        Settings.ReleaseDelay = math.clamp(data.ReleaseDelay, 0, 1)
    end

    if IsValidInputName(data.MenuKey) then
        Settings.MenuKey = data.MenuKey
    end

    if IsValidInputName(data.ActivationKey) then
        Settings.ActivationKey = data.ActivationKey
    end

    return true
end

local SaveStatusButton = nil
local SaveStatusToken = 0
local SaveStatusActive = false

local function ShowSaveStatus(text, success)
    if not SaveStatusButton or not SaveStatusButton.Parent then
        return
    end

    SaveStatusToken += 1
    local token = SaveStatusToken
    SaveStatusActive = true

    SaveStatusButton.Text = text
    SaveStatusButton.TextColor3 = C.White
    Tween(SaveStatusButton, 0.12, {
        BackgroundColor3 = success and C.Green or C.Red,
        BackgroundTransparency = 0
    })

    task.delay(1.25, function()
        if token ~= SaveStatusToken then
            return
        end

        SaveStatusButton.Text = "Save Config"
        SaveStatusActive = false
        Tween(SaveStatusButton, 0.12, {
            BackgroundColor3 = C.Panel2,
            BackgroundTransparency = 0.08
        })
    end)
end

local function SaveConfig()
    if type(writefile) ~= "function" then
        warn("TB: writefile is not available.")
        ShowSaveStatus("Save Failed", false)
        return false
    end

    local data = {
        Enabled = Settings.Enabled,
        RightClickOnly = Settings.RightClickOnly,
        AutoExecute = Settings.AutoExecute,
        SilentExecute = Settings.SilentExecute,
        Head = Settings.Head,
        Torso = Settings.Torso,
        Legs = Settings.Legs,
        ReactionDelay = Settings.ReactionDelay,
        ReleaseDelay = Settings.ReleaseDelay,
        MenuKey = Settings.MenuKey,
        ActivationKey = Settings.ActivationKey
    }

    local encodeOk, encoded = pcall(function()
        return HttpService:JSONEncode(data)
    end)

    if not encodeOk then
        warn("TB: failed to encode config:", encoded)
        ShowSaveStatus("Save Failed", false)
        return false
    end

    local writeOk, writeError = pcall(function()
        writefile(CONFIG_FILE, encoded)
    end)

    if not writeOk then
        warn("TB: failed to save config:", writeError)
        ShowSaveStatus("Save Failed", false)
        return false
    end

    ShowSaveStatus("Saved", true)
    return true
end

local function GetQueueOnTeleport()
    local queueFunction = queue_on_teleport or queueonteleport

    if type(queueFunction) ~= "function" and type(syn) == "table" then
        queueFunction = syn.queue_on_teleport
    end

    return queueFunction
end

local function QueueAutoExecute()
    if not Settings.AutoExecute then
        return false
    end

    local rawUrl = NormalizeAutoExecuteUrl(AUTO_EXECUTE_URL)
    if not rawUrl then
        warn("TB: AUTO_EXECUTE_URL is empty or invalid.")
        return false
    end

    local queueFunction = GetQueueOnTeleport()
    if type(queueFunction) ~= "function" then
        warn("TB: queue_on_teleport is unavailable.")
        return false
    end

    if type(readfile) ~= "function" then
        warn("TB: readfile is unavailable; Auto Execute cannot verify the config.")
        return false
    end

    local queuedCode = string.format([[local HttpService = game:GetService("HttpService")
local configOk, config = pcall(function()
    return HttpService:JSONDecode(readfile(%q))
end)

if configOk and type(config) == "table" and config.AutoExecute then
    local source = nil
    local requestOk, remoteSource = pcall(function()
        return game:HttpGet(%q)
    end)

    if requestOk and type(remoteSource) == "string" and remoteSource ~= "" then
        source = remoteSource
    elseif type(readfile) == "function" then
        local localOk, localSource = pcall(function()
            return readfile(%q)
        end)
        if localOk and type(localSource) == "string" and localSource ~= "" then
            source = localSource
        end
    end

    if type(source) ~= "string" or source == "" then
        warn("TB: Auto Execute failed. The GitHub repository is private or unreachable, and the local script file was not found.")
        return
    end

    local compileOk, fn = pcall(function()
        return loadstring(source)
    end)

    if not compileOk or type(fn) ~= "function" then
        warn("TB: Auto Execute failed to compile the script.", fn)
        return
    end

    local runOk, runError = pcall(fn)
    if not runOk then
        warn("TB: Auto Execute runtime error:", runError)
    end
end]], CONFIG_FILE, rawUrl, LOCAL_AUTO_EXECUTE_FILE)

    local queueOk, queueError = pcall(function()
        queueFunction(queuedCode)
    end)

    if not queueOk then
        warn("TB: failed to queue auto execute:", queueError)
        return false
    end

    return true
end

LoadConfig()

local ScreenGui = Create("ScreenGui", {
    Name = "TB",
    ResetOnSpawn = false,
    IgnoreGuiInset = true,
    ZIndexBehavior = Enum.ZIndexBehavior.Global,
    DisplayOrder = GUI_DISPLAY_ORDER
}, GuiParent)

local function KeepGuiAlive()
    pcall(function()
        if ScreenGui.Parent ~= GuiParent then
            ScreenGui.Parent = GuiParent
        end
        ScreenGui.DisplayOrder = GUI_DISPLAY_ORDER
        ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Global
    end)
end

local PanelPosition = UDim2.new(
    0.5,
    -PANEL_WIDTH / 2,
    0.5,
    -PANEL_HEIGHT / 2 + 10
)

local Panel = Create("Frame", {
    Size = UDim2.fromOffset(PANEL_WIDTH, PANEL_HEIGHT),
    Position = PanelPosition,
    BackgroundColor3 = C.Panel,
    BackgroundTransparency = 0.08,
    BorderSizePixel = 0,
    ClipsDescendants = true,
    ZIndex = 2
}, ScreenGui)
AddCorner(Panel, 9)
AddStroke(Panel, 0.25)

local function SetPanelPosition(position)
    Panel.Position = position
end

local function SetSavedPanelPosition(position)
    PanelPosition = position
end

local Header = Create("Frame", {
    Size = UDim2.new(1, 0, 0, 38),
    BackgroundColor3 = C.Panel2,
    BackgroundTransparency = 0.05,
    BorderSizePixel = 0,
    Active = true,
    ZIndex = 3
}, Panel)
AddCorner(Header, 9)

Create("Frame", {
    Size = UDim2.new(1, 0, 0, 9),
    Position = UDim2.new(0, 0, 1, -9),
    BackgroundColor3 = C.Panel2,
    BorderSizePixel = 0,
    ZIndex = 3
}, Header)

Create("TextLabel", {
    Size = UDim2.new(1, -25, 1, 0),
    Position = UDim2.fromOffset(13, 0),
    BackgroundTransparency = 1,
    Text = "TB",
    TextColor3 = C.White,
    TextSize = 12,
    Font = Enum.Font.GothamMedium,
    TextXAlignment = Enum.TextXAlignment.Left,
    ZIndex = 4
}, Header)

local EnabledDot = Create("Frame", {
    Size = UDim2.fromOffset(6, 6),
    Position = UDim2.new(1, -17, 0.5, -3),
    BackgroundColor3 = Settings.Enabled and C.Green or C.DarkGray,
    BorderSizePixel = 0,
    ZIndex = 4
}, Header)
AddCorner(EnabledDot, 10)

local Content = Create("Frame", {
    Size = UDim2.new(1, -24, 1, -52),
    Position = UDim2.fromOffset(12, 45),
    BackgroundTransparency = 1,
    ClipsDescendants = false,
    ZIndex = 3
}, Panel)

local ToggleRefreshers = {}
local SliderRefreshers = {}
local KeyBinders = {}
local ActiveCapture = nil
local ActivationHeld = false

local function SetToggleVisual(toggleButton, knob, settingKey, instant)
    local enabled = Settings[settingKey] == true
    local duration = instant and 0 or 0.18

    Tween(toggleButton, duration, {
        BackgroundColor3 = enabled and C.Green or Color3.fromRGB(65, 65, 65)
    })

    Tween(knob, duration, {
        Position = enabled and UDim2.new(1, -22, 0, 2) or UDim2.fromOffset(2, 2)
    })
end

local function CreateToggle(label, y, settingKey)
    local row = Create("Frame", {
        Size = UDim2.new(1, 0, 0, 40),
        Position = UDim2.fromOffset(0, y),
        BackgroundColor3 = C.Panel2,
        BackgroundTransparency = 0.08,
        BorderSizePixel = 0,
        ZIndex = 3
    }, Content)
    AddCorner(row, 7)
    AddStroke(row, 0.55)

    Create("TextLabel", {
        Size = UDim2.new(1, -65, 1, 0),
        Position = UDim2.fromOffset(12, 0),
        BackgroundTransparency = 1,
        Text = label,
        TextColor3 = C.White,
        TextSize = 11,
        Font = Enum.Font.GothamMedium,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 4
    }, row)

    local toggleButton = Create("TextButton", {
        Size = UDim2.fromOffset(42, 24),
        Position = UDim2.new(1, -54, 0.5, -12),
        BackgroundColor3 = Color3.fromRGB(65, 65, 65),
        BorderSizePixel = 0,
        Text = "",
        AutoButtonColor = false,
        ZIndex = 5
    }, row)
    AddCorner(toggleButton, 20)

    local knob = Create("Frame", {
        Size = UDim2.fromOffset(20, 20),
        Position = UDim2.fromOffset(2, 2),
        BackgroundColor3 = Color3.fromRGB(245, 245, 245),
        BorderSizePixel = 0,
        ZIndex = 6
    }, toggleButton)
    AddCorner(knob, 20)

    local function Refresh(instant)
        SetToggleVisual(toggleButton, knob, settingKey, instant)
    end

    toggleButton.MouseButton1Click:Connect(function()
        Settings[settingKey] = not Settings[settingKey]
        Refresh(false)

        if settingKey == "Enabled" then
            Tween(EnabledDot, 0.18, {
                BackgroundColor3 = Settings.Enabled and C.Green or C.DarkGray
            })
        end

        if settingKey == "AutoExecute" then
            local saved = SaveConfig()
            if Settings.AutoExecute and saved then
                local queued = QueueAutoExecute()
                if queued then
                    ShowSaveStatus("Queued", true)
                end
            end
        elseif settingKey == "SilentExecute" then
            SaveConfig()
        end
    end)

    ToggleRefreshers[settingKey] = Refresh
    Refresh(true)
end

CreateToggle("Enabled", 0, "Enabled")
CreateToggle("Hold Only", 45, "RightClickOnly")
CreateToggle("Auto Execute", 90, "AutoExecute")
CreateToggle("Silent Execute", 135, "SilentExecute")

local function CancelKeyCapture()
    if not ActiveCapture then
        return
    end

    local capture = ActiveCapture
    ActiveCapture = nil

    if capture.button and capture.button.Parent then
        capture.button.Text = PrettyInputName(Settings[capture.settingKey])
        capture.button.TextColor3 = C.White
        capture.button.BackgroundColor3 = C.Panel
    end
end

local function CompleteKeyCapture(input)
    if not ActiveCapture then
        return false
    end

    local capture = ActiveCapture
    local name = InputToName(input)

    if not name then
        return true
    end

    if name == "Escape" then
        CancelKeyCapture()
        return true
    end

    if os.clock() - capture.startedAt < 0.12 and name == "MouseButton1" then
        return true
    end

    Settings[capture.settingKey] = name
    ActiveCapture = nil

    capture.button.Text = PrettyInputName(name)
    capture.button.TextColor3 = C.White
    capture.button.BackgroundColor3 = C.Panel

    SaveConfig()
    return true
end

local function BeginKeyCapture(settingKey, button)
    CancelKeyCapture()

    ActiveCapture = {
        settingKey = settingKey,
        button = button,
        startedAt = os.clock()
    }

    button.Text = "Press key / mouse..."
    button.TextColor3 = C.Yellow
    Tween(button, 0.08, {
        BackgroundColor3 = Color3.fromRGB(26, 26, 26)
    })
end

local function CreateKeybind(label, y, settingKey)
    local row = Create("Frame", {
        Size = UDim2.new(1, 0, 0, 36),
        Position = UDim2.fromOffset(0, y),
        BackgroundColor3 = C.Panel2,
        BackgroundTransparency = 0.08,
        BorderSizePixel = 0,
        ZIndex = 3
    }, Content)
    AddCorner(row, 7)
    AddStroke(row, 0.55)

    Create("TextLabel", {
        Size = UDim2.new(0.5, 0, 1, 0),
        Position = UDim2.fromOffset(12, 0),
        BackgroundTransparency = 1,
        Text = label,
        TextColor3 = C.White,
        TextSize = 10,
        Font = Enum.Font.GothamMedium,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 4
    }, row)

    local button = Create("TextButton", {
        Size = UDim2.fromOffset(112, 24),
        Position = UDim2.new(1, -122, 0.5, -12),
        BackgroundColor3 = C.Panel,
        BorderSizePixel = 0,
        Text = PrettyInputName(Settings[settingKey]),
        TextColor3 = C.White,
        TextSize = 9,
        Font = Enum.Font.GothamMedium,
        AutoButtonColor = false,
        ZIndex = 5
    }, row)
    AddCorner(button, 6)
    AddStroke(button, 0.45)

    button.MouseEnter:Connect(function()
        if ActiveCapture == nil or ActiveCapture.button ~= button then
            Tween(button, 0.1, {
                BackgroundColor3 = Color3.fromRGB(22, 22, 22)
            })
        end
    end)

    button.MouseLeave:Connect(function()
        if ActiveCapture == nil or ActiveCapture.button ~= button then
            Tween(button, 0.1, {
                BackgroundColor3 = C.Panel
            })
        end
    end)

    button.MouseButton1Click:Connect(function()
        BeginKeyCapture(settingKey, button)
    end)

    KeyBinders[settingKey] = {
        Button = button,
        Refresh = function()
            if ActiveCapture and ActiveCapture.button == button then
                return
            end
            button.Text = PrettyInputName(Settings[settingKey])
            button.TextColor3 = C.White
            button.BackgroundColor3 = C.Panel
        end
    }
end

CreateKeybind("Menu Key", 185, "MenuKey")
CreateKeybind("Activation Key", 226, "ActivationKey")

Create("TextLabel", {
    Size = UDim2.new(1, 0, 0, 17),
    Position = UDim2.fromOffset(0, 271),
    BackgroundTransparency = 1,
    Text = "TARGET PARTS",
    TextColor3 = C.Gray,
    TextSize = 9,
    Font = Enum.Font.GothamMedium,
    TextXAlignment = Enum.TextXAlignment.Left,
    ZIndex = 4
}, Content)

local TargetContainer = Create("Frame", {
    Size = UDim2.new(1, 0, 0, 36),
    Position = UDim2.fromOffset(0, 289),
    BackgroundTransparency = 1,
    ZIndex = 3
}, Content)

local function CreateTargetToggle(label, x, settingKey)
    local button = Create("TextButton", {
        Size = UDim2.fromOffset(88, 34),
        Position = UDim2.fromOffset(x, 0),
        BackgroundColor3 = C.Panel2,
        BackgroundTransparency = 0.1,
        BorderSizePixel = 0,
        Text = "",
        AutoButtonColor = false,
        ZIndex = 4
    }, TargetContainer)
    AddCorner(button, 6)
    AddStroke(button, 0.6)

    local checkBox = Create("Frame", {
        Size = UDim2.fromOffset(15, 15),
        Position = UDim2.fromOffset(9, 9),
        BackgroundColor3 = C.Panel,
        BorderSizePixel = 0,
        ZIndex = 5
    }, button)
    AddCorner(checkBox, 4)
    AddStroke(checkBox, 0.35)

    local check = Create("TextLabel", {
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        Text = "✓",
        TextColor3 = C.Black,
        TextSize = 11,
        Font = Enum.Font.GothamBold,
        TextTransparency = 1,
        ZIndex = 6
    }, checkBox)

    Create("TextLabel", {
        Size = UDim2.new(1, -30, 1, 0),
        Position = UDim2.fromOffset(30, 0),
        BackgroundTransparency = 1,
        Text = label,
        TextColor3 = C.White,
        TextSize = 10,
        Font = Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 5
    }, button)

    local function Refresh(instant)
        local duration = instant and 0 or 0.12
        Tween(checkBox, duration, {
            BackgroundColor3 = Settings[settingKey] and C.White or C.Panel
        })
        Tween(check, duration, {
            TextTransparency = Settings[settingKey] and 0 or 1
        })
    end

    button.MouseEnter:Connect(function()
        Tween(button, 0.1, {
            BackgroundTransparency = 0
        })
    end)

    button.MouseLeave:Connect(function()
        Tween(button, 0.1, {
            BackgroundTransparency = 0.1
        })
    end)

    button.MouseButton1Click:Connect(function()
        Settings[settingKey] = not Settings[settingKey]
        Refresh(false)
    end)

    ToggleRefreshers[settingKey] = Refresh
    Refresh(true)
end

CreateTargetToggle("Head", 0, "Head")
CreateTargetToggle("Torso", 94, "Torso")
CreateTargetToggle("Legs", 188, "Legs")

local function CreateSlider(label, y, settingKey)
    local row = Create("Frame", {
        Size = UDim2.new(1, 0, 0, 43),
        Position = UDim2.fromOffset(0, y),
        BackgroundTransparency = 1,
        ZIndex = 3
    }, Content)

    Create("TextLabel", {
        Size = UDim2.new(0.7, 0, 0, 17),
        BackgroundTransparency = 1,
        Text = label,
        TextColor3 = C.White,
        TextSize = 10,
        Font = Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 4
    }, row)

    local valueLabel = Create("TextLabel", {
        Size = UDim2.new(0.3, 0, 0, 17),
        Position = UDim2.new(0.7, 0, 0, 0),
        BackgroundTransparency = 1,
        Text = "",
        TextColor3 = C.Gray,
        TextSize = 10,
        Font = Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Right,
        ZIndex = 4
    }, row)

    local bar = Create("Frame", {
        Size = UDim2.new(1, 0, 0, 4),
        Position = UDim2.fromOffset(0, 27),
        BackgroundColor3 = Color3.fromRGB(45, 45, 45),
        BorderSizePixel = 0,
        Active = true,
        ZIndex = 4
    }, row)
    AddCorner(bar, 4)

    local fill = Create("Frame", {
        Size = UDim2.new(Settings[settingKey], 0, 1, 0),
        BackgroundColor3 = C.White,
        BorderSizePixel = 0,
        ZIndex = 5
    }, bar)
    AddCorner(fill, 4)

    local knob = Create("Frame", {
        Size = UDim2.fromOffset(12, 12),
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(Settings[settingKey], 0, 0.5, 0),
        BackgroundColor3 = C.White,
        BorderSizePixel = 0,
        Active = true,
        ZIndex = 7
    }, bar)
    AddCorner(knob, 10)

    local dragging = false

    local function SetValue(value, animate)
        value = math.clamp(value, 0, 1)
        Settings[settingKey] = value
        valueLabel.Text = string.format("%.2f s", value)

        local duration = animate and 0.05 or 0
        Tween(fill, duration, {
            Size = UDim2.new(value, 0, 1, 0)
        })
        Tween(knob, duration, {
            Position = UDim2.new(value, 0, 0.5, 0)
        })
    end

    local function SetFromInput(input)
        local width = bar.AbsoluteSize.X
        if width <= 0 then
            return
        end

        local value = (input.Position.X - bar.AbsolutePosition.X) / width
        SetValue(value, true)
    end

    local function BeginDrag(input)
        if input.UserInputType ~= Enum.UserInputType.MouseButton1 then
            return
        end
        dragging = true
        SetFromInput(input)
    end

    bar.InputBegan:Connect(BeginDrag)
    knob.InputBegan:Connect(BeginDrag)

    UserInputService.InputChanged:Connect(function(input)
        if not dragging then
            return
        end

        if input.UserInputType == Enum.UserInputType.MouseMovement then
            SetFromInput(input)
        end
    end)

    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            if dragging then
                SaveConfig()
            end
            dragging = false
        end
    end)

    SliderRefreshers[settingKey] = function()
        SetValue(Settings[settingKey], false)
    end

    SetValue(Settings[settingKey], false)
end

CreateSlider("Reaction", 331, "ReactionDelay")
CreateSlider("Release", 380, "ReleaseDelay")

local SaveContainer = Create("Frame", {
    Size = UDim2.new(1, 0, 0, 38),
    Position = UDim2.fromOffset(0, 433),
    BackgroundTransparency = 1,
    ZIndex = 3
}, Content)

SaveStatusButton = Create("TextButton", {
    Size = UDim2.new(1, 0, 1, 0),
    Position = UDim2.fromOffset(0, 0),
    BackgroundColor3 = C.Panel2,
    BackgroundTransparency = 0.08,
    BorderSizePixel = 0,
    Text = "Save Config",
    TextColor3 = C.White,
    TextSize = 10,
    Font = Enum.Font.GothamMedium,
    AutoButtonColor = false,
    ZIndex = 4
}, SaveContainer)
AddCorner(SaveStatusButton, 7)
AddStroke(SaveStatusButton, 0.55)

SaveStatusButton.MouseEnter:Connect(function()
    if SaveStatusActive then
        return
    end
    Tween(SaveStatusButton, 0.1, {
        BackgroundTransparency = 0
    })
end)

SaveStatusButton.MouseLeave:Connect(function()
    if SaveStatusActive then
        return
    end
    Tween(SaveStatusButton, 0.1, {
        BackgroundTransparency = 0.08
    })
end)

SaveStatusButton.MouseButton1Click:Connect(function()
    SaveConfig()
end)

local MouseButtonPressed = false
local ManualMouseButtonDown = false
local SyntheticMouseButtonDown = false

local function IsMouseOverGui(input)
    if input.UserInputType ~= Enum.UserInputType.MouseButton1
        and input.UserInputType ~= Enum.UserInputType.MouseButton2
        and input.UserInputType ~= Enum.UserInputType.MouseButton3 then
        return false
    end

    local objects
    local ok = pcall(function()
        objects = GuiService:GetGuiObjectsAtPosition(input.Position.X, input.Position.Y)
    end)

    if not ok or type(objects) ~= "table" then
        return false
    end

    for _, guiObject in ipairs(objects) do
        if guiObject and guiObject:IsDescendantOf(ScreenGui) then
            return true
        end
    end

    return false
end

local function SendMouseButton(isDown)
    if isDown then
        SyntheticMouseButtonDown = true
    end

    local ok, err = pcall(function()
        VirtualInputManager:SendMouseButtonEvent(0, 0, 0, isDown, game, 0)
    end)

    if not ok then
        if isDown then
            SyntheticMouseButtonDown = false
        end

        warn("TB mouse button failed:", err)
        return false
    end

    if not isDown then
        SyntheticMouseButtonDown = false
    end

    return true
end

local function PressMouseButton()
    if MouseButtonPressed then
        return true
    end

    if SendMouseButton(true) then
        MouseButtonPressed = true
        return true
    end

    return false
end

local function ReleaseMouseButton()
    if not MouseButtonPressed then
        return
    end

    -- Never release the triggerbot click while the real mouse button
    -- is being held by the user.
    if ManualMouseButtonDown then
        return
    end

    SendMouseButton(false)
    MouseButtonPressed = false
end

local RaycastParamsObject = RaycastParams.new()
RaycastParamsObject.FilterType = Enum.RaycastFilterType.Exclude
RaycastParamsObject.IgnoreWater = true

local function GetViewportCenter()
    Camera = workspace.CurrentCamera
    if not Camera then
        return nil, nil
    end

    local viewportSize = Camera.ViewportSize
    return viewportSize.X * 0.5, viewportSize.Y * 0.5
end

local function GetSelectedParts(character)
    local parts = {}

    local function AddPart(name, groupName)
        local part = character:FindFirstChild(name)
        if part and part:IsA("BasePart") then
            table.insert(parts, {
                Part = part,
                Name = groupName
            })
        end
    end

    if Settings.Head then
        AddPart("Head", "Head")
    end

    if Settings.Torso then
        AddPart("UpperTorso", "Torso")
        AddPart("LowerTorso", "Torso")
        AddPart("HumanoidRootPart", "Torso")
        AddPart("Torso", "Torso")
    end

    if Settings.Legs then
        AddPart("LeftUpperLeg", "Legs")
        AddPart("RightUpperLeg", "Legs")
        AddPart("LeftLowerLeg", "Legs")
        AddPart("RightLowerLeg", "Legs")
        AddPart("LeftFoot", "Legs")
        AddPart("RightFoot", "Legs")
        AddPart("Left Leg", "Legs")
        AddPart("Right Leg", "Legs")
    end

    return parts
end

local function PartToGroup(part)
    if not part then
        return nil
    end

    local name = part.Name

    if name == "Head" then
        return "Head"
    end

    if name == "UpperTorso"
        or name == "LowerTorso"
        or name == "Torso"
        or name == "HumanoidRootPart" then
        return "Torso"
    end

    if name == "LeftUpperLeg"
        or name == "RightUpperLeg"
        or name == "LeftLowerLeg"
        or name == "RightLowerLeg"
        or name == "LeftFoot"
        or name == "RightFoot"
        or name == "Left Leg"
        or name == "Right Leg" then
        return "Legs"
    end

    return nil
end

local function IsGroupEnabled(groupName)
    if groupName == "Head" then
        return Settings.Head
    end
    if groupName == "Torso" then
        return Settings.Torso
    end
    if groupName == "Legs" then
        return Settings.Legs
    end
    return false
end

local function IsPartUnderCursor(part)
    local centerX, centerY = GetViewportCenter()
    if not centerX or not part or not part:IsA("BasePart") or not part.Parent then
        return false
    end

    local halfSize = part.Size * 0.5
    local minX = math.huge
    local minY = math.huge
    local maxX = -math.huge
    local maxY = -math.huge
    local anyVisibleCorner = false

    for sx = -1, 1, 2 do
        for sy = -1, 1, 2 do
            for sz = -1, 1, 2 do
                local worldCorner = part.CFrame:PointToWorldSpace(Vector3.new(
                    halfSize.X * sx,
                    halfSize.Y * sy,
                    halfSize.Z * sz
                ))

                local screenPoint = Camera:WorldToViewportPoint(worldCorner)
                if screenPoint.Z > 0 then
                    anyVisibleCorner = true
                    minX = math.min(minX, screenPoint.X)
                    minY = math.min(minY, screenPoint.Y)
                    maxX = math.max(maxX, screenPoint.X)
                    maxY = math.max(maxY, screenPoint.Y)
                end
            end
        end
    end

    if not anyVisibleCorner then
        return false
    end

    return centerX >= minX
        and centerX <= maxX
        and centerY >= minY
        and centerY <= maxY
end

local function GetCenterRaycast()
    local centerX, centerY = GetViewportCenter()
    if not centerX then
        return nil
    end

    local ray = Camera:ViewportPointToRay(centerX, centerY)
    RaycastParamsObject.FilterDescendantsInstances = { LocalPlayer.Character }

    return workspace:Raycast(
        ray.Origin,
        ray.Direction * 10000,
        RaycastParamsObject
    )
end

local function HasLineOfSight(character, part)
    if not character or not part or not part.Parent then
        return false
    end

    local cameraPosition = Camera.CFrame.Position
    local direction = part.Position - cameraPosition

    if direction.Magnitude <= 0.001 then
        return true
    end

    RaycastParamsObject.FilterDescendantsInstances = { LocalPlayer.Character }
    local hit = workspace:Raycast(cameraPosition, direction, RaycastParamsObject)

    if not hit then
        return true
    end

    return hit.Instance:IsDescendantOf(character)
end

local function BuildTarget(player, character, part, partGroup)
    return {
        Player = player,
        Character = character,
        Part = part,
        PartName = partGroup
    }
end

local function FindTarget()
    Camera = workspace.CurrentCamera
    if not Camera then
        return nil
    end

    local centerHit = GetCenterRaycast()

    if centerHit and centerHit.Instance then
        local hitPart = centerHit.Instance

        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= LocalPlayer and player.Character then
                local character = player.Character
                local humanoid = character:FindFirstChildOfClass("Humanoid")

                if humanoid and humanoid.Health > 0 and hitPart:IsDescendantOf(character) then
                    local directGroup = PartToGroup(hitPart)

                    if directGroup and IsGroupEnabled(directGroup) then
                        return BuildTarget(player, character, hitPart, directGroup)
                    end

                    for _, entry in ipairs(GetSelectedParts(character)) do
                        local part = entry.Part
                        if part and part.Parent and IsPartUnderCursor(part) and HasLineOfSight(character, part) then
                            return BuildTarget(player, character, part, entry.Name)
                        end
                    end

                    return nil
                end
            end
        end

        local model = hitPart:FindFirstAncestorOfClass("Model")
        if model and Players:GetPlayerFromCharacter(model) then
            return nil
        end
    end

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character then
            local character = player.Character
            local humanoid = character:FindFirstChildOfClass("Humanoid")

            if humanoid and humanoid.Health > 0 then
                for _, entry in ipairs(GetSelectedParts(character)) do
                    local part = entry.Part
                    if part and part.Parent and IsPartUnderCursor(part) and HasLineOfSight(character, part) then
                        return BuildTarget(player, character, part, entry.Name)
                    end
                end
            end
        end
    end

    return nil
end

local PendingShotToken = 0
local ReleaseToken = 0
local LastTargetPlayer = nil

local function CancelPendingShot()
    PendingShotToken += 1
end

local function CancelRelease()
    ReleaseToken += 1
end

local function ScheduleRelease()
    if not MouseButtonPressed or ManualMouseButtonDown then
        return
    end

    ReleaseToken += 1
    local token = ReleaseToken
    local delayTime = Settings.ReleaseDelay

    task.spawn(function()
        local startedAt = os.clock()

        while true do
            if token ~= ReleaseToken then
                return
            end

            if not Settings.Enabled then
                ReleaseMouseButton()
                return
            end

            if Settings.RightClickOnly and not ActivationHeld then
                ReleaseMouseButton()
                return
            end

            if FindTarget() then
                return
            end

            if os.clock() - startedAt >= delayTime then
                break
            end

            RunService.Heartbeat:Wait()
        end

        if token ~= ReleaseToken then
            return
        end

        if not FindTarget() then
            ReleaseMouseButton()
        end
    end)
end

local function UpdateTriggerbot()
    if not Settings.Enabled then
        CancelPendingShot()
        CancelRelease()
        if not ManualMouseButtonDown then
            ReleaseMouseButton()
        end
        LastTargetPlayer = nil
        return
    end

    if Settings.RightClickOnly and not ActivationHeld then
        CancelPendingShot()
        CancelRelease()
        if not ManualMouseButtonDown then
            ReleaseMouseButton()
        end
        LastTargetPlayer = nil
        return
    end

    local target = FindTarget()

    if target then
        CancelRelease()

        if MouseButtonPressed then
            LastTargetPlayer = target.Player
            return
        end

        if LastTargetPlayer ~= target.Player then
            PendingShotToken += 1
            local token = PendingShotToken
            local player = target.Player
            local delayTime = Settings.ReactionDelay

            task.spawn(function()
                if delayTime > 0 then
                    task.wait(delayTime)
                end

                if token ~= PendingShotToken then
                    return
                end

                if not Settings.Enabled or MouseButtonPressed then
                    return
                end

                if Settings.RightClickOnly and not ActivationHeld then
                    return
                end

                local latestTarget = FindTarget()
                if latestTarget and latestTarget.Player == player then
                    PressMouseButton()
                end
            end)
        end

        LastTargetPlayer = target.Player
        return
    end

    CancelPendingShot()
    LastTargetPlayer = nil

    if MouseButtonPressed and not ManualMouseButtonDown then
        ScheduleRelease()
    end
end

RunService.RenderStepped:Connect(function()
    -- Keep the manual state authoritative even if an input event is missed.
    -- Our own synthetic click is excluded while SyntheticMouseButtonDown is true.
    if not SyntheticMouseButtonDown then
        local physicalDown = false

        pcall(function()
            physicalDown = UserInputService:IsMouseButtonPressed(
                Enum.UserInputType.MouseButton1
            )
        end)

        if physicalDown then
            ManualMouseButtonDown = true
        end
    end

    UpdateTriggerbot()
end)

local DraggingPanel = false
local DragStart = nil
local PanelStart = nil

Header.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        DraggingPanel = true
        DragStart = input.Position
        PanelStart = Panel.Position
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if not DraggingPanel then
        return
    end

    if input.UserInputType ~= Enum.UserInputType.MouseMovement then
        return
    end

    if not DragStart or not PanelStart then
        return
    end

    local delta = input.Position - DragStart
    SetPanelPosition(UDim2.new(
        PanelStart.X.Scale,
        PanelStart.X.Offset + delta.X,
        PanelStart.Y.Scale,
        PanelStart.Y.Offset + delta.Y
    ))
end)

UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 and DraggingPanel then
        DraggingPanel = false
        SetSavedPanelPosition(Panel.Position)
        DragStart = nil
        PanelStart = nil
    end
end)

local SilentVisible = not Settings.SilentExecute
local AnimatingVisibility = false
local OriginalGuiState = {}

local function SavePanelVisualState()
    OriginalGuiState = {}

    local function Record(object)
        if object:IsA("GuiObject") then
            local entry = {
                Object = object,
                BackgroundTransparency = object.BackgroundTransparency
            }

            if object:IsA("TextLabel") or object:IsA("TextButton") or object:IsA("TextBox") then
                entry.TextTransparency = object.TextTransparency
                entry.TextStrokeTransparency = object.TextStrokeTransparency
            end

            if object:IsA("ImageLabel") or object:IsA("ImageButton") then
                entry.ImageTransparency = object.ImageTransparency
            end

            if object:IsA("ScrollingFrame") then
                entry.ScrollBarImageTransparency = object.ScrollBarImageTransparency
            end

            table.insert(OriginalGuiState, entry)
        elseif object:IsA("UIStroke") then
            table.insert(OriginalGuiState, {
                Object = object,
                Transparency = object.Transparency
            })
        end
    end

    Record(Panel)
    for _, descendant in ipairs(Panel:GetDescendants()) do
        Record(descendant)
    end
end

local function SetPanelTransparency(hidden, duration)
    for _, entry in ipairs(OriginalGuiState) do
        local object = entry.Object
        if object and object.Parent then
            local goal = {}

            if hidden then
                if entry.BackgroundTransparency ~= nil then
                    goal.BackgroundTransparency = 1
                end
                if entry.TextTransparency ~= nil then
                    goal.TextTransparency = 1
                end
                if entry.TextStrokeTransparency ~= nil then
                    goal.TextStrokeTransparency = 1
                end
                if entry.ImageTransparency ~= nil then
                    goal.ImageTransparency = 1
                end
                if entry.ScrollBarImageTransparency ~= nil then
                    goal.ScrollBarImageTransparency = 1
                end
                if entry.Transparency ~= nil then
                    goal.Transparency = 1
                end
            else
                if entry.BackgroundTransparency ~= nil then
                    goal.BackgroundTransparency = entry.BackgroundTransparency
                end
                if entry.TextTransparency ~= nil then
                    goal.TextTransparency = entry.TextTransparency
                end
                if entry.TextStrokeTransparency ~= nil then
                    goal.TextStrokeTransparency = entry.TextStrokeTransparency
                end
                if entry.ImageTransparency ~= nil then
                    goal.ImageTransparency = entry.ImageTransparency
                end
                if entry.ScrollBarImageTransparency ~= nil then
                    goal.ScrollBarImageTransparency = entry.ScrollBarImageTransparency
                end
                if entry.Transparency ~= nil then
                    goal.Transparency = entry.Transparency
                end
            end

            if next(goal) then
                Tween(object, duration, goal)
            end
        end
    end
end

local function ToggleMenu()
    if AnimatingVisibility then
        return
    end

    AnimatingVisibility = true
    SilentVisible = not SilentVisible

    if SilentVisible then
        Panel.Visible = true

        local hiddenStart = UDim2.new(
            PanelPosition.X.Scale,
            PanelPosition.X.Offset,
            PanelPosition.Y.Scale,
            PanelPosition.Y.Offset + 8
        )

        SetPanelPosition(hiddenStart)
        SetPanelTransparency(true, 0)
        SetPanelTransparency(false, 0.16)
        Tween(Panel, 0.16, {
            Position = PanelPosition
        })

        task.delay(0.18, function()
            if SilentVisible then
                SetPanelPosition(PanelPosition)
                SetPanelTransparency(false, 0)
            end
            AnimatingVisibility = false
        end)
    else
        SavePanelVisualState()
        SetPanelTransparency(true, 0.14)

        local hiddenPosition = UDim2.new(
            PanelPosition.X.Scale,
            PanelPosition.X.Offset,
            PanelPosition.Y.Scale,
            PanelPosition.Y.Offset + 6
        )

        Tween(Panel, 0.14, {
            Position = hiddenPosition
        })

        task.delay(0.15, function()
            if not SilentVisible then
                Panel.Visible = false
                SetPanelPosition(PanelPosition)
                SetPanelTransparency(false, 0)
            end
            AnimatingVisibility = false
        end)
    end
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if ActiveCapture then
        CompleteKeyCapture(input)
        return
    end

    local overGui = IsMouseOverGui(input)

    if InputMatches(input, Settings.ActivationKey) and not overGui and not gameProcessed then
        ActivationHeld = true
    end

    if InputMatches(input, Settings.MenuKey) and not overGui and not gameProcessed then
        ToggleMenu()
        return
    end
end)

UserInputService.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        -- Ignore the InputBegan generated by our own VirtualInputManager call.
        if not SyntheticMouseButtonDown then
            ManualMouseButtonDown = true
        end
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if InputMatches(input, Settings.ActivationKey) then
        ActivationHeld = false

        if Settings.RightClickOnly then
            CancelPendingShot()
            CancelRelease()
            ReleaseMouseButton()
            LastTargetPlayer = nil
        end
    end

    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        -- An actual physical release always ends the manual hold state.
        ManualMouseButtonDown = false
    end
end)

workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
    Camera = workspace.CurrentCamera
end)

LocalPlayer.CharacterAdded:Connect(function()
    task.wait(0.5)
    Camera = workspace.CurrentCamera
    CancelPendingShot()
    CancelRelease()
    if not ManualMouseButtonDown then
        ReleaseMouseButton()
    end
    LastTargetPlayer = nil
    ActivationHeld = false
end)

Players.PlayerRemoving:Connect(function(player)
    if LastTargetPlayer == player then
        LastTargetPlayer = nil
        CancelPendingShot()
        CancelRelease()
    end
end)

if Settings.SilentExecute then
    Panel.Visible = false
else
    Panel.Visible = true
    SetPanelPosition(PanelPosition)
end

SavePanelVisualState()
KeepGuiAlive()

RunService:BindToRenderStep(
    "TB_Controller",
    Enum.RenderPriority.Last.Value + 100,
    function()
        KeepGuiAlive()
    end
)

if Settings.AutoExecute then
    QueueAutoExecute()
end
