if not game:IsLoaded() then game.Loaded:Wait() end
local LarpZeroLockRoot=game:GetService("CoreGui")
local sharedLock=LarpZeroLockRoot:FindFirstChild("LarpZeroStartupLock")
if sharedLock then
    local menu=sharedLock:FindFirstChild("Menu")
    if menu and menu.Value and menu.Value.Parent then return end
    local started=sharedLock:GetAttribute("Started")
    if sharedLock:GetAttribute("Loading") and type(started)=="number" and os.clock()-started<90 then return end
    sharedLock:Destroy()
end
local LarpZeroUIRoot=type(gethui)=="function" and gethui() or game:GetService("CoreGui")
for _,gui in ipairs(LarpZeroUIRoot:GetChildren()) do
    if gui:GetAttribute("LarpZeroMenu") then return end
    if gui.Name=="Obsidian" then
        for _,label in ipairs(gui:GetDescendants()) do
            if label:IsA("TextLabel") and label.Text=="Larp Zero" then return end
        end
    end
end
local prior=getgenv().LarpZeroInstance
local sameServer=prior and prior.Place==game.PlaceId and prior.Server==game.JobId
local oldGui=prior and prior.Library and prior.Library.ScreenGui
local liveMenu=oldGui and oldGui.Parent~=nil and not prior.Library.Unloaded
local recentStart=prior and prior.Loading and os.clock()-(prior.Started or 0)<90
if sameServer and (recentStart or liveMenu) then return end
local LarpZeroStartupLock=Instance.new("Folder")
LarpZeroStartupLock.Name="LarpZeroStartupLock"
LarpZeroStartupLock:SetAttribute("Started",os.clock())
LarpZeroStartupLock:SetAttribute("Loading",true)
LarpZeroStartupLock.Parent=LarpZeroLockRoot
local LarpZeroInstance={Loading=true,Place=game.PlaceId,Server=game.JobId,Started=os.clock()}
getgenv().LarpZeroInstance=LarpZeroInstance
local InstallLocalProfiles=(function()
-- Local settings only. No reporting or runtime downloads.
return function(library,tab)
    local folder="LarpZeroProfiles"
    local codec=game:GetService("HttpService")
    local group=tab:AddRightGroupbox("Local configurations")
    local excluded={ProfileName=true}
    local loading=false
    local function ready()
        return type(readfile)=="function" and type(writefile)=="function"
            and type(isfile)=="function" and type(isfolder)=="function" and type(makefolder)=="function"
    end
    local function name()
        local value=library.Options.ProfileName.Value
        if type(value)~="string" or not value:match("^[%w_%-]+$") or #value>48 then
            error("Invalid profile name")
        end
        return value
    end
    local function path(value)return folder.."/"..value..".json"end
    local function prepare()
        if not ready() then error("Local storage unavailable")end
        if not isfolder(folder) then makefolder(folder)end
    end
    local function action(callback)
        if loading then library:Notify("A profile is already loading",3)return end
        local ok=pcall(callback)
        if not ok then library:Notify("Could not complete that profile action. Check the name and executor file support.",5)end
    end
    local function capture()
        local data={Version=1,Toggles={},Options={}}
        for key,toggle in pairs(library.Toggles)do
            data.Toggles[key]=toggle.Value==true
        end
        for key,option in pairs(library.Options)do
            if not excluded[key] and option.SpecialType~="Player" and option.SpecialType~="Team" then
                local kind=option.Type
                if kind=="ColorPicker" then
                    data.Options[key]={Type=kind,Value=option.Value:ToHex(),Transparency=option.Transparency}
                elseif kind=="KeyPicker" then
                    data.Options[key]={Type=kind,Value=option.Value,Mode=option.Mode}
                elseif kind=="Input" or kind=="Slider" or kind=="Dropdown" then
                    data.Options[key]={Type=kind,Value=option.Value}
                end
            end
        end
        return data
    end
    local function load(value,startup)
        prepare()
        local data=codec:JSONDecode(readfile(path(value)))
        if type(data)~="table" or data.Version~=1 or type(data.Options)~="table" or type(data.Toggles)~="table" then
            error("Invalid profile")
        end
        loading=true
        task.spawn(function()
            local ok=pcall(function()
                -- Stop active features before changing their supporting inputs.
                for _,toggle in pairs(library.Toggles)do
                    if toggle.Value and toggle~=library.Toggles.SafeModeToggle then
                        local disabled=toggle.Disabled
                        toggle:SetDisabled(false)
                        toggle:SetValue(false)
                        toggle:SetDisabled(disabled)
                    end
                end
                for key,row in pairs(data.Options)do
                    local option=library.Options[key]
                    if not excluded[key] and option and type(row)=="table" and option.Type==row.Type
                        and option.SpecialType~="Player" and option.SpecialType~="Team" then
                        if row.Type=="ColorPicker" then
                            option:SetValueRGB(Color3.fromHex(row.Value),row.Transparency)
                        elseif row.Type=="KeyPicker" then
                            option:SetValue({row.Value,row.Mode})
                        elseif key=="AutoSellDropdown" then
                            local labels={ ["0"]="none",["3"]="3-5",["4"]="4-5",["5"]="5",["none"]="none",["3-5"]="3-5",["4-5"]="4-5" }
                            option:SetValue(labels[tostring(row.Value)] or "5")
                        elseif key=="EventBossDropdown" then
                            local labels={CUPID_KILLS_="Cupid",EASTERBUNNY_KILLS_="Easter Bunny",KRAKEN_KILLS_="Kraken",VANE_KILLS_="Vane",FALLENKING_KILLS_="Fallen King",SANTA_KILLS_="Korrupted Klaus"}
                            option:SetValue(labels[row.Value] or row.Value)
                        elseif key=="OrbBuffDropdown" then
                            local labels={DamageBuffOrb="Damage Boost",UltChargeBuffOrb="Ultimate",HealthBuffOrb="Healing",DefenseBuffOrb="Shield"}
                            local values={}
                            if type(row.Value)=="table" then
                                for selected,active in pairs(row.Value)do
                                    if active==true then values[labels[selected] or selected]=true
                                    elseif type(active)=="string" then values[labels[active] or active]=true end
                                end
                            end
                            option:SetValue(values)
                        else option:SetValue(row.Value)end
                    end
                end
                local safe=data.Toggles.SafeModeToggle~=false
                if library.Toggles.SafeModeToggle then library.Toggles.SafeModeToggle:SetValue(safe)end
                for key,enabled in pairs(data.Toggles)do
                    local toggle=library.Toggles[key]
                    if key~="SafeModeToggle" and toggle and enabled==true then
                        -- Farming callbacks can yield for as long as a feature runs.
                        task.spawn(function()
                            if not library.Unloaded then pcall(function()
                                local disabled=toggle.Disabled
                                toggle:SetDisabled(false)
                                toggle:SetValue(true)
                                toggle:SetDisabled(disabled)
                            end)end
                        end)
                    end
                end
                if startup and data.Toggles.HideGuiToggle==true and library.Toggled then library:Toggle()end
            end)
            loading=false
            if not library.Unloaded then library:Notify(ok and "Configuration loaded" or "Configuration could not be fully applied",4)end
        end)
    end
    library.PrepareTeleportSettings=function()
        prepare()
        writefile(path("teleport_resume"),codec:JSONEncode(capture()))
    end
    group:AddInput("ProfileName",{Text="Configuration name",Default="default",Placeholder="Letters, numbers, dash or underscore"})
    group:AddButton({Text="Save configuration",Func=function()action(function()
        prepare() writefile(path(name()),codec:JSONEncode(capture())) library:Notify("Configuration saved",3)
    end)end})
    group:AddButton({Text="Load configuration",Func=function()action(function()load(name())end)end})
    group:AddButton({Text="Delete configuration",DoubleClick=true,Func=function()action(function()
        prepare()
        if type(delfile)~="function" then error("Delete unavailable")end
        local value=name()
        if isfile(path(value)) then delfile(path(value))end
        if isfile(folder.."/autoload.txt") and readfile(folder.."/autoload.txt")==value then delfile(folder.."/autoload.txt")end
        library:Notify("Configuration deleted",3)
    end)end})
    local autoload=group:AddLabel("Autoload: none")
    group:AddButton({Text="Autoload this configuration",Func=function()action(function()
        prepare() local value=name()
        if not isfile(path(value)) then error("Save configuration first")end
        writefile(folder.."/autoload.txt",value)
        autoload:SetText("Autoload: "..value)
    end)end})
    group:AddButton({Text="Clear autoload",Func=function()action(function()
        prepare()
        if type(delfile)~="function" then error("Delete unavailable")end
        if isfile(folder.."/autoload.txt") then delfile(folder.."/autoload.txt")end
        autoload:SetText("Autoload: none")
    end)end})
    return function()
    if ready() then
        local chosen=false
        local ok=pcall(function()
            if isfile(folder.."/autoload.txt") then
                local value=readfile(folder.."/autoload.txt")
                if value:match("^[%w_%-]+$") and #value<=48 and isfile(path(value)) then
                    library.Options.ProfileName:SetValue(value)
                    autoload:SetText("Autoload: "..value)
                    load(value,true)
                    chosen=true
                end
            end
        end)
        if not chosen and getgenv().LarpZeroResumeSettings then
            pcall(function()load("teleport_resume",true)end)
        end
        getgenv().LarpZeroResumeSettings=nil
        if not ok then library:Notify("Saved configuration could not be opened",4)end
    else group:AddLabel("Local file storage is unavailable in this executor.",true)end
    end
end

end)()
local function BundledUI()
local cloneref = (cloneref or clonereference or function(instance: any)
    return instance
end)
local CoreGui: CoreGui = cloneref(game:GetService("CoreGui"))
local Players: Players = cloneref(game:GetService("Players"))
local RunService: RunService = cloneref(game:GetService("RunService"))
local SoundService: SoundService = cloneref(game:GetService("SoundService"))
local UserInputService: UserInputService = cloneref(game:GetService("UserInputService"))
local TextService: TextService = cloneref(game:GetService("TextService"))
local Teams: Teams = cloneref(game:GetService("Teams"))
local TweenService: TweenService = cloneref(game:GetService("TweenService"))

local getgenv = getgenv or function()
    return shared
end
local setclipboard = setclipboard or nil
local protectgui = protectgui or (syn and syn.protect_gui) or function() end
local gethui = gethui or function()
    return CoreGui
end

local LocalPlayer = Players.LocalPlayer or Players.PlayerAdded:Wait()
local Mouse = cloneref(LocalPlayer:GetMouse())

local Labels = {}
local Buttons = {}
local Toggles = {}
local Options = {}
local Tooltips = {}

local CustomImageManager = {}
function CustomImageManager.GetAsset(name)
local ids={TransparencyTexture=139785960036434,SaturationMap=4155801252}
return ids[name] and ("rbxassetid://"..ids[name]) or nil
end
local Library = {
    LocalPlayer = LocalPlayer,
    DevicePlatform = nil,
    IsMobile = false,
    IsRobloxFocused = true,

    ScreenGui = nil,
    WindowContainer = nil,

    SearchText = "",
    Searching = false,
    GlobalSearch = false,
    LastSearchTab = nil,

    ActiveTab = nil,
    Tabs = {},
    TabButtons = {},
    DependencyBoxes = {},

    KeybindFrame = nil,
    KeybindContainer = nil,
    KeybindToggles = {},

    Notifications = {},
    Dialogues = {},
    ActiveLoading = nil,
    ActiveDialog = nil,

    Corners = {},
    SpecificCorners = {},

    ToggleKeybind = Enum.KeyCode.RightControl,
    TweenInfo = TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
    NotifyTweenInfo = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),

    Toggled = false,
    Unloaded = false,

    Labels = Labels,
    Buttons = Buttons,
    Toggles = Toggles,
    Options = Options,

    NotifySide = "Right",
    ShowCustomCursor = true,
    ForceCheckbox = false,
    ShowToggleFrameInKeybinds = true,
    NotifyOnError = false,

    CantDragForced = false,
    DraggableElements = {},

    Signals = {},
    UnloadSignals = {},

    OriginalMinSize = Vector2.new(480, 360),
    MinSize = Vector2.new(480, 360),
    DPIScale = 1,
    CornerRadius = 4,

    IsLightTheme = false,
    Scheme = {
        BackgroundColor = Color3.fromRGB(15, 15, 15),
        MainColor = Color3.fromRGB(25, 25, 25),
        AccentColor = Color3.fromRGB(125, 85, 255),
        OutlineColor = Color3.fromRGB(40, 40, 40),
        FontColor = Color3.new(1, 1, 1),
        Font = Font.fromEnum(Enum.Font.Code),

        RedColor = Color3.fromRGB(255, 50, 50),
        DestructiveColor = Color3.fromRGB(220, 38, 38),
        DarkColor = Color3.new(0, 0, 0),
        WhiteColor = Color3.new(1, 1, 1),
    },

    Registry = {},
	Scales = {},
	ScalesOffset = {},

    ImageManager = CustomImageManager,
    ShowCursorBinding = string.sub(tostring({}), 10),

    Notify = nil -- we love luau lsp
}

if RunService:IsStudio() then
    if UserInputService.TouchEnabled and not UserInputService.MouseEnabled then
        Library.IsMobile = true
        Library.OriginalMinSize = Vector2.new(480, 240)
    else
        Library.IsMobile = false
        Library.OriginalMinSize = Vector2.new(480, 360)
    end
else
    pcall(function()
        Library.DevicePlatform = UserInputService:GetPlatform()
    end)

    Library.IsMobile = (Library.DevicePlatform == Enum.Platform.Android or Library.DevicePlatform == Enum.Platform.IOS)
    Library.OriginalMinSize = Library.IsMobile and Vector2.new(480, 240) or Vector2.new(480, 360)
end

local Templates = {
    --// UI \\-
    Frame = {
        BorderSizePixel = 0,
    },
    ImageLabel = {
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
    },
    ImageButton = {
        AutoButtonColor = false,
        BorderSizePixel = 0,
    },
    ScrollingFrame = {
        BorderSizePixel = 0,
    },
    TextLabel = {
        BorderSizePixel = 0,
        FontFace = "Font",
        RichText = true,
        TextColor3 = "FontColor",
    },
    TextButton = {
        AutoButtonColor = false,
        BorderSizePixel = 0,
        FontFace = "Font",
        RichText = true,
        TextColor3 = "FontColor",
    },
    TextBox = {
        BorderSizePixel = 0,
        FontFace = "Font",
        PlaceholderColor3 = function()
            local H, S, V = Library.Scheme.FontColor:ToHSV()
            return Color3.fromHSV(H, S, V / 2)
        end,
        Text = "",
        TextColor3 = "FontColor",
    },
    UIListLayout = {
        SortOrder = Enum.SortOrder.LayoutOrder,
    },
    UIStroke = {
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
    },

    --// Library \\--
    Window = {
        Title = "No Title",
        Footer = "No Footer",
        Position = UDim2.fromOffset(6, 6),
        Size = UDim2.fromOffset(720, 600),
        IconSize = UDim2.fromOffset(30, 30),
        AutoShow = true,
        Center = true,
        Resizable = true,
        SearchbarSize = UDim2.fromScale(1, 1),
        GlobalSearch = false,
        CornerRadius = 4,
        NotifySide = "Right",
        ShowCustomCursor = true,
        Font = Enum.Font.Code,
        ToggleKeybind = Enum.KeyCode.RightControl,
        
        ShowMobileButtons = true,
        MobileButtonsSide = "Left",

        UnlockMouseWhileOpen = true,

        EnableSidebarResize = false,
        EnableCompacting = true,
        DisableCompactingSnap = false,
        SidebarCompacted = false,
        MinContainerWidth = 256,

        --// Snapping \\--
        MinSidebarWidth = 128,
        SidebarCompactWidth = 48,
        SidebarCollapseThreshold = 0.5,

        --// Dragging \\--
        CompactWidthActivation = 128,
    },
    Dialog = {
        Title = "Dialog",
        Description = "Description",
        AutoDismiss = true,
        OutsideClickDismiss = true,
        FooterButtons = {}
    },
    Loading = {
        Title = "mspaint",
        Icon = 95816097006870,
        IconSize = UDim2.fromOffset(30, 30),

        LoadingIcon = CustomImageManager.GetAsset("LoadingIcon"),
        LoadingIconColor = nil,
        LoadingIconTweenTime = 1,

        CurrentStep = 0,
        TotalSteps = 10,

        ShowSidebar = false,
        AutoResizeHeight = false,

        WindowWidth = 450,
        WindowHeight = 275,

        ContentWidth = 450,
        SidebarWidth = 250,
    },
    Toggle = {
        Text = "Toggle",
        Default = false,

        Callback = function() end,
        Changed = function() end,

        Risky = false,
        Disabled = false,
        Visible = true,
    },
    Input = {
        Text = "Input",
        Default = "",
        Finished = false,
        Numeric = false,
        ClearTextOnFocus = true,
        ClearTextOnBlur = false,
        Placeholder = "",
        AllowEmpty = true,
        EmptyReset = "---",

        Callback = function() end,
        Changed = function() end,
        VerifyValue = nil,

        Disabled = false,
        Visible = true,
    },
    Slider = {
        Text = "Slider",
        Default = 0,
        Min = 0,
        Max = 100,
        Rounding = 0,

        Prefix = "",
        Suffix = "",

        Callback = function() end,
        Changed = function() end,

        Disabled = false,
        Visible = true,

        AllowRightClickInput = true
    },
    Dropdown = {
        Values = {},
        DisabledValues = {},
        ValueImages = {},

        Multi = false,
        MaxVisibleDropdownItems = 8,

        Callback = function() end,
        Changed = function() end,

        Disabled = false,
        Visible = true,
    },
    Viewport = {
        Object = nil,
        Camera = nil,
        Clone = true,
        AutoFocus = true,
        Interactive = false,
        Height = 200,
        Visible = true,
    },
    Image = {
        Image = "",
        Transparency = 0,
        BackgroundTransparency = 0,
        Color = Color3.new(1, 1, 1),
        RectOffset = Vector2.zero,
        RectSize = Vector2.zero,
        ScaleType = Enum.ScaleType.Fit,
        Height = 200,
        Visible = true,
    },
    Video = {
        Video = "",
        Looped = false,
        Playing = false,
        Volume = 1,
        Height = 200,
        Visible = true,
    },
    UIPassthrough = {
        Instance = nil,
        Height = 24,
        Visible = true,
    },

    --// Addons \\-
    KeyPicker = {
        Text = "KeyPicker",

        Default = "None",
        DefaultModifiers = {},

        Blacklisted = {},
        BlacklistedModifiers = {},
        Whitelisted = {},
        WhitelistedModifiers = {},

        Mode = "Toggle",
        Modes = { "Always", "Toggle", "Hold" },
        SyncToggleState = false,

        Callback = function() end,
        ChangedCallback = function() end,
        Changed = function() end,
        Clicked = function() end,
    },
    ColorPicker = {
        Default = Color3.new(1, 1, 1),

        Callback = function() end,
        Changed = function() end,
    },
}

local Places = {
    Bottom = { 0, 1 },
    Right = { 1, 0 },
}
local Sizes = {
    Left = { 0.5, 1 },
    Right = { 0.5, 1 },
}

--// Scheme Functions \\--
local SchemeReplaceAlias = {
    RedColor = "Red",
    WhiteColor = "White",
    DarkColor = "Dark"
}

local SchemeAlias = {
    Red = "RedColor",
    White = "WhiteColor",
    Dark = "DarkColor"
}

local function GetSchemeValue(Index)
    if not Index then
        return nil
    end

    local ReplaceAliasIndex = SchemeReplaceAlias[Index]
    if ReplaceAliasIndex and Library.Scheme[ReplaceAliasIndex] ~= nil then
        Library.Scheme[Index] = Library.Scheme[ReplaceAliasIndex]
        Library.Scheme[ReplaceAliasIndex] = nil

        return Library.Scheme[Index]
    end

    local AliasIndex = SchemeAlias[Index]
    if AliasIndex and Library.Scheme[AliasIndex] ~= nil then
        
        return Library.Scheme[AliasIndex]
    end

    return Library.Scheme[Index]
end

--// Basic Functions \\--
local function WaitForEvent(Event, Timeout, Condition)
    local Bindable = Instance.new("BindableEvent")
    local Connection = Event:Once(function(...)
        if not Condition or typeof(Condition) == "function" and Condition(...) then
            Bindable:Fire(true)
        else
            Bindable:Fire(false)
        end
    end)
    task.delay(Timeout, function()
        Connection:Disconnect()
        Bindable:Fire(false)
    end)

    local Result = Bindable.Event:Wait()
    Bindable:Destroy()

    return Result
end

local function IsMouseInput(Input: InputObject, IncludeM2: boolean?)
    return Input.UserInputType == Enum.UserInputType.MouseButton1
        or (IncludeM2 == true and Input.UserInputType == Enum.UserInputType.MouseButton2)
        or Input.UserInputType == Enum.UserInputType.Touch
end
local function IsClickInput(Input: InputObject, IncludeM2: boolean?)
    return IsMouseInput(Input, IncludeM2)
        and Input.UserInputState == Enum.UserInputState.Begin
        and Library.IsRobloxFocused
end
local function IsHoverInput(Input: InputObject)
    return (Input.UserInputType == Enum.UserInputType.MouseMovement or Input.UserInputType == Enum.UserInputType.Touch)
        and Input.UserInputState == Enum.UserInputState.Change
end
local function IsDragInput(Input: InputObject, IncludeM2: boolean?)
    return IsMouseInput(Input, IncludeM2)
        and (Input.UserInputState == Enum.UserInputState.Begin or Input.UserInputState == Enum.UserInputState.Change)
        and Library.IsRobloxFocused
end
local function IsMouseClickInput(Input: InputObject)
    return Input.UserInputType == Enum.UserInputType.MouseButton1 or 
        Input.UserInputType == Enum.UserInputType.MouseButton2 or 
        Input.UserInputType == Enum.UserInputType.MouseButton3
end

local function GetTableSize(Table: { [any]: any })
    local Size = 0

    for _, _ in Table do
        Size += 1
    end

    return Size
end
local function StopTween(Tween: TweenBase)
    if not (Tween and Tween.PlaybackState == Enum.PlaybackState.Playing) then
        return
    end

    Tween:Cancel()
end
local function Trim(Text: string)
    return Text:match("^%s*(.-)%s*$")
end
local function Round(Value, Rounding)
    assert(Rounding >= 0, "Invalid rounding number.")

    if Rounding == 0 then
        return math.floor(Value)
    end

    return tonumber(string.format("%." .. Rounding .. "f", Value))
end

local function GetPlayers(ExcludeLocalPlayer: boolean?)
    local PlayerList = Players:GetPlayers()

    if ExcludeLocalPlayer then
        local Idx = table.find(PlayerList, LocalPlayer)
        if Idx then
            table.remove(PlayerList, Idx)
        end
    end

    table.sort(PlayerList, function(Player1, Player2)
        return Player1.Name:lower() < Player2.Name:lower()
    end)

    return PlayerList
end
local function GetTeams()
    local TeamList = Teams:GetTeams()

    table.sort(TeamList, function(Team1, Team2)
        return Team1.Name:lower() < Team2.Name:lower()
    end)

    return TeamList
end

function Library:UpdateDependencyBoxes()
    for _, Depbox in Library.DependencyBoxes do
        Depbox:Update(true)
    end

    if Library.Searching then
        Library:UpdateSearch(Library.SearchText)
    end
end

local function CheckDepbox(Box, Search)
    local VisibleElements = 0

    for _, ElementInfo in Box.Elements do
        if ElementInfo.Type == "Divider" then
            ElementInfo.Holder.Visible = false
            continue
        elseif ElementInfo.SubButton then
            --// Check if any of the Buttons Name matches with Search
            local Visible = false

            --// Check if Search matches Element's Name and if Element is Visible
            if ElementInfo.Text:lower():match(Search) and ElementInfo.Visible then
                Visible = true
            else
                ElementInfo.Base.Visible = false
            end
            if ElementInfo.SubButton.Text:lower():match(Search) and ElementInfo.SubButton.Visible then
                Visible = true
            else
                ElementInfo.SubButton.Base.Visible = false
            end
            ElementInfo.Holder.Visible = Visible
            if Visible then
                VisibleElements += 1
            end

            continue
        end

        --// Check if Search matches Element's Name and if Element is Visible
        if ElementInfo.Text and ElementInfo.Text:lower():match(Search) and ElementInfo.Visible then
            ElementInfo.Holder.Visible = true
            VisibleElements += 1
        else
            ElementInfo.Holder.Visible = false
        end
    end

    for _, Depbox in Box.DependencyBoxes do
        if not Depbox.Visible then
            continue
        end

        VisibleElements += CheckDepbox(Depbox, Search)
    end

    Box.Holder.Visible = VisibleElements > 0
    return VisibleElements
end
local function RestoreDepbox(Box)
    for _, ElementInfo in Box.Elements do
        ElementInfo.Holder.Visible = typeof(ElementInfo.Visible) == "boolean" and ElementInfo.Visible or true

        if ElementInfo.SubButton then
            ElementInfo.Base.Visible = ElementInfo.Visible
            ElementInfo.SubButton.Base.Visible = ElementInfo.SubButton.Visible
        end
    end

    Box:Resize()
    Box.Holder.Visible = true

    for _, Depbox in Box.DependencyBoxes do
        if not Depbox.Visible then
            continue
        end

        RestoreDepbox(Depbox)
    end
end

local function ApplySearchToTab(Tab, Search)
    if not Tab then
        return
    end

    local HasVisible = false

    --// Loop through Groupboxes to get Elements Info
    for _, Groupbox in Tab.Groupboxes do
        local VisibleElements = 0

        for _, ElementInfo in Groupbox.Elements do
            if ElementInfo.Type == "Divider" then
                ElementInfo.Holder.Visible = false
                continue
            elseif ElementInfo.SubButton then
                --// Check if any of the Buttons Name matches with Search
                local Visible = false

                --// Check if Search matches Element's Name and if Element is Visible
                if ElementInfo.Text:lower():match(Search) and ElementInfo.Visible then
                    Visible = true
                else
                    ElementInfo.Base.Visible = false
                end
                if ElementInfo.SubButton.Text:lower():match(Search) and ElementInfo.SubButton.Visible then
                    Visible = true
                else
                    ElementInfo.SubButton.Base.Visible = false
                end
                ElementInfo.Holder.Visible = Visible
                if Visible then
                    VisibleElements += 1
                end

                continue
            end

            --// Check if Search matches Element's Name and if Element is Visible
            if ElementInfo.Text and ElementInfo.Text:lower():match(Search) and ElementInfo.Visible then
                ElementInfo.Holder.Visible = true
                VisibleElements += 1
            else
                ElementInfo.Holder.Visible = false
            end
        end

        for _, Depbox in Groupbox.DependencyBoxes do
            if not Depbox.Visible then
                continue
            end

            VisibleElements += CheckDepbox(Depbox, Search)
        end

        --// Update Groupbox Size and Visibility if found any element
        if VisibleElements > 0 then
            Groupbox:Resize()
            HasVisible = true
        end
        Groupbox.BoxHolder.Visible = VisibleElements > 0
    end

    for _, Tabbox in Tab.Tabboxes do
        local VisibleTabs = 0
        local VisibleElements = {}

        for _, SubTab in Tabbox.Tabs do
            VisibleElements[SubTab] = 0

            for _, ElementInfo in SubTab.Elements do
                if ElementInfo.Type == "Divider" then
                    ElementInfo.Holder.Visible = false
                    continue
                elseif ElementInfo.SubButton then
                    --// Check if any of the Buttons Name matches with Search
                    local Visible = false

                    --// Check if Search matches Element's Name and if Element is Visible
                    if ElementInfo.Text:lower():match(Search) and ElementInfo.Visible then
                        Visible = true
                    else
                        ElementInfo.Base.Visible = false
                    end
                    if ElementInfo.SubButton.Text:lower():match(Search) and ElementInfo.SubButton.Visible then
                        Visible = true
                    else
                        ElementInfo.SubButton.Base.Visible = false
                    end
                    ElementInfo.Holder.Visible = Visible
                    if Visible then
                        VisibleElements[SubTab] += 1
                    end

                    continue
                end

                --// Check if Search matches Element's Name and if Element is Visible
                if ElementInfo.Text and ElementInfo.Text:lower():match(Search) and ElementInfo.Visible then
                    ElementInfo.Holder.Visible = true
                    VisibleElements[SubTab] += 1
                else
                    ElementInfo.Holder.Visible = false
                end
            end

            for _, Depbox in SubTab.DependencyBoxes do
                if not Depbox.Visible then
                    continue
                end

                VisibleElements[SubTab] += CheckDepbox(Depbox, Search)
            end
        end

        for SubTab, Visible in VisibleElements do
            SubTab.ButtonHolder.Visible = Visible > 0
            if Visible > 0 then
                VisibleTabs += 1
                HasVisible = true

                if Tabbox.ActiveTab == SubTab then
                    SubTab:Resize()
                elseif Tabbox.ActiveTab and VisibleElements[Tabbox.ActiveTab] == 0 then
                    SubTab:Show()
                end
            end
        end

        --// Update Tabbox Visibility if any visible
        Tabbox.BoxHolder.Visible = VisibleTabs > 0
    end

    return HasVisible
end
local function ResetTab(Tab)
    if not Tab then
        return
    end

    for _, Groupbox in Tab.Groupboxes do
        for _, ElementInfo in Groupbox.Elements do
            ElementInfo.Holder.Visible = typeof(ElementInfo.Visible) == "boolean" and ElementInfo.Visible or true

            if ElementInfo.SubButton then
                ElementInfo.Base.Visible = ElementInfo.Visible
                ElementInfo.SubButton.Base.Visible = ElementInfo.SubButton.Visible
            end
        end

        for _, Depbox in Groupbox.DependencyBoxes do
            if not Depbox.Visible then
                continue
            end

            RestoreDepbox(Depbox)
        end

        Groupbox:Resize()
        Groupbox.BoxHolder.Visible = true
    end

    for _, Tabbox in Tab.Tabboxes do
        for _, SubTab in Tabbox.Tabs do
            for _, ElementInfo in SubTab.Elements do
                ElementInfo.Holder.Visible = typeof(ElementInfo.Visible) == "boolean" and ElementInfo.Visible or true

                if ElementInfo.SubButton then
                    ElementInfo.Base.Visible = ElementInfo.Visible
                    ElementInfo.SubButton.Base.Visible = ElementInfo.SubButton.Visible
                end
            end

            for _, Depbox in SubTab.DependencyBoxes do
                if not Depbox.Visible then
                    continue
                end

                RestoreDepbox(Depbox)
            end

            SubTab.ButtonHolder.Visible = true
        end

        if Tabbox.ActiveTab then
            Tabbox.ActiveTab:Resize()
        end
        Tabbox.BoxHolder.Visible = true
    end
end

function Library:UpdateSearch(SearchText)
    Library.SearchText = SearchText

    local TabsToReset = {}

    if Library.GlobalSearch then
        for _, Tab in Library.Tabs do
            if typeof(Tab) == "table" and not Tab.IsKeyTab then
                table.insert(TabsToReset, Tab)
            end
        end
    elseif Library.LastSearchTab and typeof(Library.LastSearchTab) == "table" then
        table.insert(TabsToReset, Library.LastSearchTab)
    end

    for _, Tab in ipairs(TabsToReset) do
        ResetTab(Tab)
    end

    local Search = SearchText:lower()
    if Trim(Search) == "" then
        Library.Searching = false
        Library.LastSearchTab = nil
        return
    end
    if not Library.GlobalSearch and Library.ActiveTab and Library.ActiveTab.IsKeyTab then
        Library.Searching = false
        Library.LastSearchTab = nil
        return
    end

    Library.Searching = true

    local TabsToSearch = {}

    if Library.GlobalSearch then
        TabsToSearch = TabsToReset
        if #TabsToSearch == 0 then
            for _, Tab in Library.Tabs do
                if typeof(Tab) == "table" and not Tab.IsKeyTab then
                    table.insert(TabsToSearch, Tab)
                end
            end
        end
    elseif Library.ActiveTab then
        table.insert(TabsToSearch, Library.ActiveTab)
    end

    local FirstVisibleTab = nil
    local ActiveHasVisible = false

    for _, Tab in ipairs(TabsToSearch) do
        local HasVisible = ApplySearchToTab(Tab, Search)
        if HasVisible then
            if not FirstVisibleTab then
                FirstVisibleTab = Tab
            end
            if Tab == Library.ActiveTab then
                ActiveHasVisible = true
            end
        end
    end

    if Library.GlobalSearch then
        if ActiveHasVisible and Library.ActiveTab then
            Library.ActiveTab:RefreshSides()
        elseif FirstVisibleTab then
            local SearchMarker = SearchText
            task.defer(function()
                if Library.SearchText ~= SearchMarker then
                    return
                end

                if Library.ActiveTab ~= FirstVisibleTab then
                    FirstVisibleTab:Show()
                end
            end)
        end
        Library.LastSearchTab = nil
    else
        Library.LastSearchTab = Library.ActiveTab
    end
end

function Library:AddToRegistry(Instance, Properties)
    Library.Registry[Instance] = Properties
end

function Library:RemoveFromRegistry(Instance)
    Library.Registry[Instance] = nil
end

function Library:UpdateColorsUsingRegistry()
    for Instance, Properties in Library.Registry do
        for Property, Index in Properties do
            local SchemeValue = GetSchemeValue(Index)

            if SchemeValue or typeof(Index) == "function" then
                Instance[Property] = SchemeValue or Index()
            end
        end
    end
end

function Library:SetDPIScale(DPIScale: number)
    Library.DPIScale = DPIScale / 100
    Library.MinSize = Library.OriginalMinSize * Library.DPIScale

	for _, UIScale in Library.Scales do
        UIScale.Scale = Library.DPIScale - (tonumber(Library.ScalesOffset[UIScale]) or 0)
    end

    for _, Option in Options do
        if Option.Type == "Dropdown" then
            Option:RecalculateListSize()
        end
    end

    for _, Notification in Library.Notifications do
        Notification:Resize()
    end
end

function Library:GiveSignal(Connection: RBXScriptConnection | RBXScriptSignal)
    local ConnectionType = typeof(Connection)
    if Connection and (ConnectionType == "RBXScriptConnection" or ConnectionType == "RBXScriptSignal") then
        table.insert(Library.Signals, Connection)
    end

    return Connection
end

function IsValidCustomIcon(Icon: string)
    return typeof(Icon) == "string" and (Icon:match("rbxasset") or Icon:match("roblox%.com/asset/%?id=") or Icon:match("rbxthumb://type="))
end

type Icon = {
    Url: string,
    Id: number,
    IconName: string,
    ImageRectOffset: Vector2,
    ImageRectSize: Vector2,
}

type IconModule = {
    Icons: { string },
    GetAsset: (Name: string) -> Icon?,
}

local FetchIcons, Icons = false, nil
function Library:GetIcon(IconName: string)
    if not FetchIcons then
        return
    end

    local Success, Icon = pcall(Icons.GetAsset, IconName)
    if not Success then
        return
    end
    
    return Icon
end

function Library:GetCustomIcon(IconName: string): any
    if not IconName then
        return nil
    end

    if tonumber(IconName) then
        IconName = string.format("rbxassetid://%s", tostring(IconName))
    end

    local CustomIcon = IsValidCustomIcon(IconName)
    if CustomIcon then
        return {
            Url = IconName,
            ImageRectOffset = Vector2.zero,
            ImageRectSize = Vector2.zero,
            Custom = true,
        }
    end

    local LucideIcon = Library:GetIcon(IconName)
    if LucideIcon then
        return LucideIcon
    end

    return nil
end

function Library:Validate(Table: { [string]: any }, Template: { [string]: any }): { [string]: any }
    if typeof(Table) ~= "table" then
        return Template
    end

    for k, v in Template do
        if typeof(k) == "number" then
            continue
        end

        if typeof(v) == "table" then
            Table[k] = Library:Validate(Table[k], v)
        elseif Table[k] == nil then
            Table[k] = v
        end
    end

    return Table
end

--// Creator Functions \\--
local function FillInstance(Table: { [string]: any }, Instance: GuiObject)
    local ThemeProperties = Library.Registry[Instance] or {}

    for key, value in Table do
        if key ~= "Text" then
            local SchemeValue = GetSchemeValue(value)

            if SchemeValue or typeof(value) == "function" then
                ThemeProperties[key] = value
                value = SchemeValue or value()
            else
                ThemeProperties[key] = nil
            end
        end

        Instance[key] = value
    end

    if GetTableSize(ThemeProperties) > 0 then
        Library.Registry[Instance] = ThemeProperties
    end
end

local function New(ClassName: string, Properties: { [string]: any }): any
    local Instance = Instance.new(ClassName)

    if Templates[ClassName] then
        FillInstance(Templates[ClassName], Instance)
    end
    FillInstance(Properties, Instance)

    if Properties["Parent"] and not Properties["ZIndex"] then
        pcall(function()
            Instance.ZIndex = Properties.Parent.ZIndex
        end)
    end

    return Instance
end

--// Main Instances \\-
local function SafeParentUI(Instance: Instance, Parent: Instance | () -> Instance)
    local success, _error = pcall(function()
        if not Parent then
            Parent = CoreGui
        end

        local DestinationParent
        if typeof(Parent) == "function" then
            DestinationParent = Parent()
        else
            DestinationParent = Parent
        end

        Instance.Parent = DestinationParent
    end)

    if not (success and Instance.Parent) then
        Instance.Parent = Library.LocalPlayer:WaitForChild("PlayerGui", math.huge)
    end
end

local function ParentUI(UI: Instance, SkipHiddenUI: boolean?)
    if SkipHiddenUI then
        SafeParentUI(UI, CoreGui)
        return
    end

    pcall(protectgui, UI)
    SafeParentUI(UI, gethui)
end

local ScreenGui = New("ScreenGui", {
    Name = "Obsidian",
    DisplayOrder = 998,
    ResetOnSpawn = false,
})
ParentUI(ScreenGui)
Library.ScreenGui = ScreenGui

ScreenGui.DescendantRemoving:Connect(function(Instance)
    Library:RemoveFromRegistry(Instance)
end)

local ModalElement = New("TextButton", {
    BackgroundTransparency = 1,
    Modal = false,
    Size = UDim2.fromScale(0, 0),
    AnchorPoint = Vector2.zero,
    Text = "",
    ZIndex = -999,
    Parent = ScreenGui,
})

--// Cursor
local Cursor, CursorCustomImage
do
    Cursor = New("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = "WhiteColor",
        Size = UDim2.fromOffset(9, 1),
        Visible = false,
        ZIndex = 11000,
        Parent = ScreenGui,
    })
    New("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = "DarkColor",
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.new(1, 2, 1, 2),
        ZIndex = 10999,
        Parent = Cursor,
    })

    local CursorV = New("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = "WhiteColor",
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromOffset(1, 9),
        ZIndex = 11000,
        Parent = Cursor,
    })
    New("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = "DarkColor",
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.new(1, 2, 1, 2),
        ZIndex = 10999,
        Parent = CursorV,
    })

    CursorCustomImage = New("ImageLabel", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundTransparency = 1,
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromOffset(20, 20),
        ZIndex = 11000,
        Visible = false,
        Parent = Cursor
    })
end

--// Notification
local NotificationArea
local NotificationList
do
    NotificationArea = New("Frame", {
        AnchorPoint = Vector2.new(1, 0),
        BackgroundTransparency = 1,
        Position = UDim2.new(1, -6, 0, 6),
        Size = UDim2.new(0, 300, 1, -6),
        Parent = ScreenGui,
    })
    table.insert(
        Library.Scales,
        New("UIScale", {
            Parent = NotificationArea,
        })
    )

    NotificationList = New("UIListLayout", {
        HorizontalAlignment = Enum.HorizontalAlignment.Right,
        Padding = UDim.new(0, 8),
        Parent = NotificationArea,
    })
end

--// Lib Functions \\--
function Library:ResetCursorIcon()
    CursorCustomImage.Visible = false
    CursorCustomImage.Size = UDim2.fromOffset(20, 20)
end

function Library:ChangeCursorIcon(ImageId: string)
    if not ImageId or ImageId == "" then
        Library:ResetCursorIcon()
        return
    end

    local Icon = Library:GetCustomIcon(ImageId)
    assert(Icon, "Image must be a valid Roblox asset or a valid URL or a valid lucide icon.")

    CursorCustomImage.Visible = true
    CursorCustomImage.Image = Icon.Url
    CursorCustomImage.ImageRectOffset = Icon.ImageRectOffset
    CursorCustomImage.ImageRectSize = Icon.ImageRectSize
end

function Library:ChangeCursorIconSize(Size: UDim2)
    assert(typeof(Size) == "UDim2", "UDim2 expected.")
    CursorCustomImage.Size = Size
end

function Library:GetBetterColor(Color: Color3, Add: number): Color3
    Add = Add * (Library.IsLightTheme and -4 or 2)
    return Color3.fromRGB(
        math.clamp(Color.R * 255 + Add, 0, 255),
        math.clamp(Color.G * 255 + Add, 0, 255),
        math.clamp(Color.B * 255 + Add, 0, 255)
    )
end

function Library:GetLighterColor(Color: Color3): Color3
    local H, S, V = Color:ToHSV()
    return Color3.fromHSV(H, math.max(0, S - 0.1), math.min(1, V + 0.1))
end

function Library:GetDarkerColor(Color: Color3): Color3
    local H, S, V = Color:ToHSV()
    return Color3.fromHSV(H, S, V / 2)
end

function Library:GetKeyString(KeyCode: Enum.KeyCode)
    if KeyCode.EnumType == Enum.KeyCode and KeyCode.Value > 33 and KeyCode.Value < 127 then
        return string.char(KeyCode.Value)
    end

    return KeyCode.Name
end

function Library:GetTextBounds(Text: string, Font: Font, Size: number, Width: number?): (number, number)
    local Params = Instance.new("GetTextBoundsParams")
    Params.Text = Text
    Params.RichText = true
    Params.Font = Font
    Params.Size = Size
    Params.Width = Width or workspace.CurrentCamera.ViewportSize.X - 32

    local Bounds = TextService:GetTextBoundsAsync(Params)
    return Bounds.X, Bounds.Y
end

function Library:MouseIsOverFrame(Frame: GuiObject, Mouse: Vector2): boolean
    local AbsPos, AbsSize = Frame.AbsolutePosition, Frame.AbsoluteSize
    return Mouse.X >= AbsPos.X
        and Mouse.X <= AbsPos.X + AbsSize.X
        and Mouse.Y >= AbsPos.Y
        and Mouse.Y <= AbsPos.Y + AbsSize.Y
end

function Library:IsInsideFrame(ParentFrame: GuiObject, Frame: GuiObject)
    local GuiPos = Frame.AbsolutePosition
	local GuiSize = Frame.AbsoluteSize

	local FramePos = ParentFrame.AbsolutePosition
	local FrameSize = ParentFrame.AbsoluteSize

	return GuiPos.X >= FramePos.X
		and GuiPos.X + GuiSize.X <= FramePos.X + FrameSize.X
		and GuiPos.Y >= FramePos.Y
		and GuiPos.Y + GuiSize.Y <= FramePos.Y + FrameSize.Y
end

function Library:SafeCallback(Func: (...any) -> ...any, ...: any)
    if not (Func and typeof(Func) == "function") then
        return
    end

    local Result = table.pack(xpcall(Func, function(Error)
        task.defer(error, debug.traceback(Error, 2))
        if Library.NotifyOnError and Library.Notify then
            Library:Notify(Error)
        end

        return Error
    end, ...))

    if not Result[1] then
        return nil
    end

    return table.unpack(Result, 2, Result.n)
end

function GetOverlappingDraggable(UI: GuiObject, TargetPos: Vector2?)
    local Pos1 = TargetPos or UI.AbsolutePosition
    local Size1 = UI.AbsoluteSize
    
    for _, Other in ipairs(Library.DraggableElements) do
        if Other == UI or not Other.Visible or not Other.Parent then
            continue
        end

        local Pos2 = Other.AbsolutePosition
        local Size2 = Other.AbsoluteSize
        
        if Pos1.X < Pos2.X + Size2.X and
            Pos1.X + Size1.X > Pos2.X and
            Pos1.Y < Pos2.Y + Size2.Y and
            Pos1.Y + Size1.Y > Pos2.Y then
            return Other
        end
    end
    
    return nil
end

function GetNonOverlappingPosition(UI: GuiObject, StartPos: UDim2?)
    local ScreenSize = (workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1920, 1080)) - Vector2.new(100, 100)
    local Start = StartPos and Vector2.new(StartPos.X.Offset, StartPos.Y.Offset) or Vector2.new(6, 6)
    local Padding = 6
    
    local CurrentX = Start.X
    local CurrentY = Start.Y
    
    local Size = UI.AbsoluteSize
    if Size.X == 0 and Size.Y == 0 then
        RunService.RenderStepped:Wait()
        Size = UI.AbsoluteSize
    end
    
    if Size.X == 0 then Size = Vector2.new(150, 40) end

    local MaxXInColumn = Size.X

    while true do
        local Obstacle = GetOverlappingDraggable(UI, Vector2.new(CurrentX, CurrentY))
        if not Obstacle then
            break
        end
        
        if Obstacle.AbsoluteSize.X > MaxXInColumn then
            MaxXInColumn = Obstacle.AbsoluteSize.X
        end
        
        local NextY = Obstacle.AbsolutePosition.Y + Obstacle.AbsoluteSize.Y + Padding
        if NextY + Size.Y > ScreenSize.Y - Padding then
            local NextX = CurrentX + MaxXInColumn + Padding
            
            if NextX + Size.X > ScreenSize.X - Padding then
                break
            end
            
            CurrentY = Start.Y
            CurrentX = NextX
            MaxXInColumn = Size.X
        else
            CurrentY = NextY
        end
    end
    
    return UDim2.fromOffset(CurrentX, CurrentY)
end

function PositionDraggable(UI: GuiObject, StartPos: UDim2?)
    UI.Position = GetNonOverlappingPosition(UI, StartPos)
end

function Library:MakeDraggable(UI: GuiObject, DragFrame: GuiObject, IgnoreToggled: boolean?, IsMainWindow: boolean?)
    local StartPos
    local FramePos
    local Dragging = false
    local Changed
    local InputBegan
    local InputChanged

    InputBegan = DragFrame.InputBegan:Connect(function(Input: InputObject)
        if not IsClickInput(Input) or IsMainWindow and Library.CantDragForced then
            return
        end

        StartPos = Input.Position
        FramePos = UI.Position
        Dragging = true

        Changed = Input.Changed:Connect(function()
            if Input.UserInputState ~= Enum.UserInputState.End then
                return
            end

            Dragging = false
            if Changed and Changed.Connected then
                Changed:Disconnect()
                Changed = nil
            end
        end)
    end)

    InputChanged = UserInputService.InputChanged:Connect(function(Input: InputObject)
        if
            (not IgnoreToggled and not Library.Toggled)
            or (IsMainWindow and Library.CantDragForced)
            or not (ScreenGui and ScreenGui.Parent)
        then
            Dragging = false
            if Changed and Changed.Connected then
                Changed:Disconnect()
                Changed = nil
            end

            return
        end

        if Dragging and IsHoverInput(Input) then
            local Delta = Input.Position - StartPos
            UI.Position =
                UDim2.new(FramePos.X.Scale, FramePos.X.Offset + Delta.X, FramePos.Y.Scale, FramePos.Y.Offset + Delta.Y)
        end
    end)

    Library:GiveSignal(InputChanged)
    Library:GiveSignal(InputBegan)
    
    UI.Destroying:Once(function()
        if InputChanged and InputChanged.Connected then
            InputChanged:Disconnect()
        end

        if InputBegan and InputBegan.Connected then
            InputBegan:Disconnect()
        end

        if Changed and Changed.Connected then
            Changed:Disconnect()
        end

        local IdxChanged = table.find(Library.Signals, InputChanged)
        if IdxChanged then
            table.remove(Library.Signals, IdxChanged)
        end

        local IdxBegan = table.find(Library.Signals, InputBegan)
        if IdxBegan then
            table.remove(Library.Signals, IdxBegan)
        end
    end)
end

function Library:MakeResizable(UI: GuiObject, DragFrame: GuiObject, Callback: () -> ()?)
    local StartPos
    local FrameSize
    local Dragging = false
    local Changed
    local InputBegan
    local InputChanged

    InputBegan = DragFrame.InputBegan:Connect(function(Input: InputObject)
        if not IsClickInput(Input) then
            return
        end

        StartPos = Input.Position
        FrameSize = UI.Size
        Dragging = true

        Changed = Input.Changed:Connect(function()
            if Input.UserInputState ~= Enum.UserInputState.End then
                return
            end

            Dragging = false
            if Changed and Changed.Connected then
                Changed:Disconnect()
                Changed = nil
            end
        end)
    end)

    InputChanged = UserInputService.InputChanged:Connect(function(Input: InputObject)
        if not UI.Visible or not (ScreenGui and ScreenGui.Parent) then
            Dragging = false
            if Changed and Changed.Connected then
                Changed:Disconnect()
                Changed = nil
            end

            return
        end

        if Dragging and IsHoverInput(Input) then
            local Delta = Input.Position - StartPos
            UI.Size = UDim2.new(
                FrameSize.X.Scale,
                math.clamp(FrameSize.X.Offset + Delta.X, Library.MinSize.X, math.huge),
                FrameSize.Y.Scale,
                math.clamp(FrameSize.Y.Offset + Delta.Y, Library.MinSize.Y, math.huge)
            )
            if Callback then
                Library:SafeCallback(Callback)
            end
        end
    end)

    Library:GiveSignal(InputChanged)
    Library:GiveSignal(InputBegan)

    UI.Destroying:Once(function()
        if InputChanged and InputChanged.Connected then
            InputChanged:Disconnect()
        end

        if InputBegan and InputBegan.Connected then
            InputBegan:Disconnect()
        end

        if Changed and Changed.Connected then
            Changed:Disconnect()
        end

        local IdxChanged = table.find(Library.Signals, InputChanged)
        if IdxChanged then
            table.remove(Library.Signals, IdxChanged)
        end

        local IdxBegan = table.find(Library.Signals, InputBegan)
        if IdxBegan then
            table.remove(Library.Signals, IdxBegan)
        end
    end)
end

function Library:MakeCover(Holder: GuiObject, Place: string)
    local Pos = Places[Place] or { 0, 0 }
    local Size = Sizes[Place] or { 1, 0.5 }

    local Cover = New("Frame", {
        AnchorPoint = Vector2.new(Pos[1], Pos[2]),
        BackgroundColor3 = Holder.BackgroundColor3,
        Position = UDim2.fromScale(Pos[1], Pos[2]),
        Size = UDim2.fromScale(Size[1], Size[2]),
        Parent = Holder,
    })

    return Cover
end

function Library:MakeLine(Frame: GuiObject, Info)
    local Line = New("Frame", {
        AnchorPoint = Info.AnchorPoint or Vector2.zero,
        BackgroundColor3 = "OutlineColor",
        Position = Info.Position,
        Size = Info.Size,
        ZIndex = Info.ZIndex or Frame.ZIndex,
        Parent = Frame,
    })

    return Line
end

function Library:AddOutline(Frame: GuiObject)
    local OutlineStroke = New("UIStroke", {
        Color = "OutlineColor",
        Thickness = 1,
        ZIndex = 2,
        Parent = Frame,
    })
    local ShadowStroke = New("UIStroke", {
        Color = "DarkColor",
        Thickness = 1.5,
        ZIndex = 1,
        Parent = Frame,
    })
    return OutlineStroke, ShadowStroke
end

function Library:AddBlank(Frame: GuiObject, Size: UDim2)
    return New("Frame", {
        BackgroundTransparency = 1,
        Size = Size or UDim2.fromScale(0, 0),
        Parent = Frame,
    })
end

--// Deprecated \\--
function Library:MakeOutline(Frame: GuiObject, Corner: number?, ZIndex: number?)
    
    local Holder = New("Frame", {
        BackgroundColor3 = "DarkColor",
        Position = UDim2.fromOffset(-2, -2),
        Size = UDim2.new(1, 4, 1, 4),
        ZIndex = ZIndex,
        Parent = Frame,
    })

    local Outline = New("Frame", {
        BackgroundColor3 = "OutlineColor",
        Position = UDim2.fromOffset(1, 1),
        Size = UDim2.new(1, -2, 1, -2),
        ZIndex = ZIndex,
        Parent = Holder,
    })

    if Corner and Corner > 0 then
        New("UICorner", {
            CornerRadius = UDim.new(0, Corner + 1),
            Parent = Holder,
        })
        New("UICorner", {
            CornerRadius = UDim.new(0, Corner),
            Parent = Outline,
        })
    end

    return Holder, Outline
end

function Library:AddDraggableLabel(...)
    local Params = select(1, ...)
    local Text
    local Icon
    local IconPosition = "left"

    if typeof(Params) == "table" then
        Text = Params.Text
        Icon = Params.Icon
        IconPosition = Params.IconPosition or "left"
    elseif typeof(Params) == "string" then
        Text = Params
        Icon = select(2, ...)
        IconPosition = select(3, ...) or "left"
    end

    if typeof(IconPosition) ~= "string" then
        IconPosition = "left"
    end

    IconPosition = string.lower(IconPosition)
    assert(IconPosition == "left" or IconPosition == "right", "Icon Position needs to be either 'left' or 'right'.")

    local DraggableLabel = {
        Connections = {},
        Destroyed = false
    }

    local IconImage
    local Label = New("TextLabel", {
        AutomaticSize = Enum.AutomaticSize.XY,
        BackgroundColor3 = "BackgroundColor",
        Size = UDim2.fromOffset(0, 0),
        Position = UDim2.fromOffset(6, 6),
        Text = Text,
        TextSize = 15,
        ZIndex = 10,
        Parent = ScreenGui,
    })

    table.insert(
        Library.Corners, 
        New("UICorner", {
            CornerRadius = UDim.new(0, Library.CornerRadius),
            Parent = Label,
        })
    )

    local Padding = New("UIPadding", {
        PaddingBottom = UDim.new(0, 6),
        PaddingLeft = UDim.new(0, 12),
        PaddingRight = UDim.new(0, 12),
        PaddingTop = UDim.new(0, 6),
        Parent = Label,
    })
    table.insert(
        Library.Scales,
        New("UIScale", {
            Parent = Label,
        })
    )

    Library:AddOutline(Label)
    Library:MakeDraggable(Label, Label, true)

    function DraggableLabel:SetText(Text: string)
        Label.Text = Text
    end

    function DraggableLabel:SetIcon(NewIcon: string)
        Icon = NewIcon

        local IsNotEmpty = Icon and Trim(tostring(Icon)) ~= ""
        if IsNotEmpty then
            local CustomIcon = Library:GetCustomIcon(Icon)
            assert(CustomIcon, "Icon must be a valid Roblox asset or a valid URL or a valid lucide icon.")

            IconImage = IconImage or New("ImageLabel", {
                BackgroundTransparency = 1,
                ImageColor3 = "FontColor",
                Size = UDim2.fromOffset(16, 16),
                ZIndex = 11,
                Parent = Label,
            })

            IconImage.Image = CustomIcon.Url
            IconImage.ImageRectOffset = CustomIcon.ImageRectOffset
            IconImage.ImageRectSize = CustomIcon.ImageRectSize
        end

        if IconImage then IconImage.Visible = IsNotEmpty end
        DraggableLabel:SetIconPosition(IconPosition)
    end

    function DraggableLabel:SetIconPosition(NewPosition: string)
        IconPosition = string.lower(NewPosition)
        assert(IconPosition == "left" or IconPosition == "right", "Icon Position needs to be either 'left' or 'right'.")

        local IsNotEmpty = Icon and Trim(tostring(Icon)) ~= ""
        Padding.PaddingLeft = UDim.new(0, (IsNotEmpty and IconPosition == "left") and 34 or 12)
        Padding.PaddingRight = UDim.new(0, (IsNotEmpty and IconPosition == "right") and 34 or 12)

        if IconImage then
            if IconPosition == "left" then
                IconImage.AnchorPoint = Vector2.new(0, 0.5)
                IconImage.Position = UDim2.new(0, -22, 0.5, 0)
            else
                IconImage.AnchorPoint = Vector2.new(1, 0.5)
                IconImage.Position = UDim2.new(1, 22, 0.5, 0)
            end
        end
    end

    function DraggableLabel:SetVisible(Visible: boolean)
        Label.Visible = Visible
    end
    
    DraggableLabel:SetIcon(Icon)
    DraggableLabel.Label = Label

    if not table.find(Library.DraggableElements, Label) then
        table.insert(Library.DraggableElements, Label)
    end

    PositionDraggable(Label, Label.Position)

    function DraggableLabel:Destroy()
        DraggableLabel.Destroyed = true

        if DraggableLabel.Connections then
            for _, connection in DraggableLabel.Connections do
                connection:Disconnect()
            end
        end

        local ElemIdx = table.find(Library.DraggableElements, Label)
        if ElemIdx then
            table.remove(Library.DraggableElements, ElemIdx)
        end

        if Label then
            Label:Destroy()
        end
    end

    return DraggableLabel
end

function Library:AddDraggableButton(...)
    local Params = select(1, ...)

    local Text
    local Func
    local ExcludeScaling
    local ExcludeDragging

    if typeof(Params) == "table" then
        Text = Params.Text
        Func = Params.Callback or Params.Func
        ExcludeScaling = Params.ExcludeScaling
        ExcludeDragging = Params.ExcludeDragging
    elseif typeof(Params) == "string" then
        Text = Params
        Func = select(2, ...)
        ExcludeScaling = select(3, ...)
        ExcludeDragging = select(4, ...)
    end

    local DraggableButton = {
        Connections = {},
        Destroyed = false
    }

    local Button = New("TextButton", {
        BackgroundColor3 = "BackgroundColor",
        Position = UDim2.fromOffset(6, 6),
        TextSize = 16,
        ZIndex = 10,
        Parent = ScreenGui,
    })
    table.insert(
        Library.Corners, 
        New("UICorner", {
            CornerRadius = UDim.new(0, Library.CornerRadius),
            Parent = Button,
        })
    )
    if not ExcludeScaling then
        table.insert(
            Library.Scales,
            New("UIScale", {
                Parent = Button,
            })
        )
    end
    Library:AddOutline(Button)

    local DragThreshold = if ExcludeDragging then 0.25 else math.huge
    Button.InputBegan:Connect(function(Input: InputObject)
        if not IsClickInput(Input) then
            return
        end
        
        local Start = tick()

        local Changed
        Changed = Input.Changed:Connect(function()
            if Input.UserInputState ~= Enum.UserInputState.End then
                return
            end

            local IsLikelyDragging = tick() - Start > DragThreshold
            if IsLikelyDragging then
                return
            end

            Library:SafeCallback(Func, DraggableButton)

            if Changed and Changed.Connected then
                Changed:Disconnect()
                Changed = nil
            end
        end)
    end)

    function DraggableButton:SetText(Text: string)
        local X, Y = Library:GetTextBounds(Text, Library.Scheme.Font, 16)

        Button.Text = Text
        Button.Size = UDim2.fromOffset(X * 2, Y * 2)
    end

    Library:MakeDraggable(Button, Button, true)
    DraggableButton:SetText(Text)
    DraggableButton.Button = Button

    if not table.find(Library.DraggableElements, Button) then
        table.insert(Library.DraggableElements, Button)
    end

    PositionDraggable(Button, Button.Position)

    function DraggableButton:Destroy()
        DraggableButton.Destroyed = true

        if DraggableButton.Connections then
            for _, connection in DraggableButton.Connections do
                connection:Disconnect()
            end
        end

        local ElemIdx = table.find(Library.DraggableElements, Button)
        if ElemIdx then
            table.remove(Library.DraggableElements, ElemIdx)
        end

        if Button then
            Button:Destroy()
        end
    end

    return DraggableButton
end

function Library:AddDraggableMenu(Name: string)
    local Holder = New("Frame", {
        AutomaticSize = Enum.AutomaticSize.XY,
        BackgroundColor3 = "BackgroundColor",
        Position = UDim2.fromOffset(6, 6),
        Size = UDim2.fromOffset(0, 0),
        ZIndex = 10,
        Parent = ScreenGui,
    })
    table.insert(
        Library.Corners,
        New("UICorner", {
            CornerRadius = UDim.new(0, Library.CornerRadius),
            Parent = Holder,
        })
    )
    table.insert(
        Library.Scales,
        New("UIScale", {
            Parent = Holder,
        })
    )
    Library:AddOutline(Holder)

    Library:MakeLine(Holder, {
        Position = UDim2.fromOffset(0, 34),
        Size = UDim2.new(1, 0, 0, 1),
    })

    local Label = New("TextLabel", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 34),
        Text = Name,
        TextSize = 15,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = Holder,
    })
    New("UIPadding", {
        PaddingLeft = UDim.new(0, 12),
        PaddingRight = UDim.new(0, 12),
        Parent = Label,
    })

    local Container = New("Frame", {
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(0, 35),
        Size = UDim2.new(1, 0, 1, -35),
        Parent = Holder,
    })
    New("UIListLayout", {
        Padding = UDim.new(0, 7),
        Parent = Container,
    })
    New("UIPadding", {
        PaddingBottom = UDim.new(0, 7),
        PaddingLeft = UDim.new(0, 7),
        PaddingRight = UDim.new(0, 7),
        PaddingTop = UDim.new(0, 7),
        Parent = Container,
    })

    Library:MakeDraggable(Holder, Label, true)

    if not table.find(Library.DraggableElements, Holder) then
        table.insert(Library.DraggableElements, Holder)
    end

    PositionDraggable(Holder, Holder.Position)

    return Holder, Container
end

function Library:AddDraggableImageButton(...)
    local Params = select(1, ...)

    local Icon
    local IconSize
    local Func
    local ExcludeScaling
    local ExcludeDragging

    if typeof(Params) == "table" then
        Icon = Params.Icon
        IconSize = Params.IconSize or 24
        Func = Params.Callback or Params.Func
        ExcludeScaling = Params.ExcludeScaling
        ExcludeDragging = Params.ExcludeDragging
    elseif typeof(Params) == "string" or typeof(Params) == "number" then
        Icon = Params
        IconSize = select(2, ...)
        Func = select(3, ...)
        ExcludeScaling = select(4, ...)
        ExcludeDragging = select(5, ...)
    end

    local DraggableImageButton = {}

    local Button = New("TextButton", {
        BackgroundColor3 = "BackgroundColor",
        Position = UDim2.fromOffset(6, 6),
        Size = UDim2.fromOffset(IconSize + 12, IconSize + 12),
        Text = "",
        ZIndex = 10,
        Parent = ScreenGui,
    })
    
    local IconImage = New("ImageLabel", {
        BackgroundTransparency = 1,
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromOffset(IconSize, IconSize),
        ImageColor3 = "FontColor",
        ZIndex = 11,
        Parent = Button,
    })

    table.insert(
        Library.Corners, 
        New("UICorner", {
            CornerRadius = UDim.new(0, Library.CornerRadius),
            Parent = Button,
        })
    )
    if not ExcludeScaling then
        table.insert(
            Library.Scales,
            New("UIScale", {
                Parent = Button,
            })
        )
    end
    Library:AddOutline(Button)

    local DragThreshold = if ExcludeDragging then 0.25 else math.huge
    Button.InputBegan:Connect(function(Input: InputObject)
        if not IsClickInput(Input) then
            return
        end
        
        local Start = tick()

        local Changed
        Changed = Input.Changed:Connect(function()
            if Input.UserInputState ~= Enum.UserInputState.End then
                return
            end

            local IsLikelyDragging = tick() - Start > DragThreshold
            if IsLikelyDragging then
                return
            end

            Library:SafeCallback(Func, DraggableImageButton)

            if Changed and Changed.Connected then
                Changed:Disconnect()
                Changed = nil
            end
        end)
    end)

    function DraggableImageButton:SetIcon(NewIcon: string)
        Icon = NewIcon or Icon
        
        local CustomIcon = Library:GetCustomIcon(Icon)
        assert(CustomIcon, "Icon must be a valid Roblox asset or a valid URL or a valid lucide icon.")

        IconImage.Image = CustomIcon.Url
        IconImage.ImageRectOffset = CustomIcon.ImageRectOffset
        IconImage.ImageRectSize = CustomIcon.ImageRectSize
    end

    function DraggableImageButton:SetIconSize(NewSize: number)
        IconSize = NewSize
        IconImage.Size = UDim2.fromOffset(IconSize, IconSize)
        Button.Size = UDim2.fromOffset(IconSize + 12, IconSize + 12)
    end

    Library:MakeDraggable(Button, Button, true)
    DraggableImageButton:SetIcon(Icon)
    DraggableImageButton.Button = Button

    if not table.find(Library.DraggableElements, Button) then
        table.insert(Library.DraggableElements, Button)
    end

    PositionDraggable(Button, Button.Position)

    return DraggableImageButton
end

--// Watermark - Deprecated \\--
do
    local WatermarkLabel = Library:AddDraggableLabel("")
    WatermarkLabel:SetVisible(false)

    function Library:SetWatermark(Text: string)
        
        WatermarkLabel:SetText(Text)
    end

    function Library:SetWatermarkVisibility(Visible: boolean)
        
        WatermarkLabel:SetVisible(Visible)
    end
end

--// Context Menu \\--
local CurrentMenu
function Library:AddContextMenu(
    Holder: GuiObject,
    Size: UDim2 | () -> (),
    Offset: { [number]: number } | () -> {},
    List: number?,
    ActiveCallback: (Active: boolean) -> ()?,
    IgnoreCornerRadius: boolean?,
    SpecificCornersOnly: ("top" | "bottom" | "no_left" | "no_top_left")? -- stupid way of doing this
)
    local Menu
    local ParentGui = Holder:FindFirstAncestorOfClass("ScreenGui")
    if ParentGui ~= ScreenGui and (Library.ActiveLoading and ParentGui ~= Library.ActiveLoading.ScreenGui) then
        ParentGui = ScreenGui
    end

    if List then
        Menu = New("ScrollingFrame", {
            AutomaticCanvasSize = List == 2 and Enum.AutomaticSize.Y or Enum.AutomaticSize.None,
            AutomaticSize = List == 1 and Enum.AutomaticSize.Y or Enum.AutomaticSize.None,
            BackgroundColor3 = "BackgroundColor",
            BottomImage = "rbxasset://textures/ui/Scroll/scroll-middle.png",
            CanvasSize = UDim2.fromOffset(0, 0),
            ScrollBarImageColor3 = "OutlineColor",
            ScrollBarThickness = List == 2 and 2 or 0,
            Size = typeof(Size) == "function" and Size() or Size,
            TopImage = "rbxasset://textures/ui/Scroll/scroll-middle.png",
            Visible = false,
            ZIndex = 10,
            Parent = ParentGui,
        })
    else
        Menu = New("Frame", {
            BackgroundColor3 = "BackgroundColor",
            Size = typeof(Size) == "function" and Size() or Size,
            Visible = false,
            ZIndex = 10,
            Parent = ParentGui,
        })
    end
    table.insert(
        Library.Scales,
        New("UIScale", {
            Parent = Menu,
        })
    )

    New("UIStroke", {
        Color = "OutlineColor",
        Parent = Menu,
    })

    local Corner;
    if IgnoreCornerRadius ~= true then
        if SpecificCornersOnly == "top" then
            Corner = New("UICorner", {
                TopLeftRadius = UDim.new(0, Library.CornerRadius / 2),
                TopRightRadius = UDim.new(0, Library.CornerRadius / 2),
                BottomRightRadius = UDim.new(0, 0),
                BottomLeftRadius = UDim.new(0, 0),
                Parent = Menu,
            }); table.insert(Library.SpecificCorners, Corner)
        elseif SpecificCornersOnly == "bottom" then
            Corner = New("UICorner", {
                TopLeftRadius = UDim.new(0, 0),
                TopRightRadius = UDim.new(0, 0),
                BottomRightRadius = UDim.new(0, Library.CornerRadius / 2),
                BottomLeftRadius = UDim.new(0, Library.CornerRadius / 2),
                Parent = Menu,
            }); table.insert(Library.SpecificCorners, Corner)
        elseif SpecificCornersOnly == "no_left" then
            Corner = New("UICorner", {
                TopLeftRadius = UDim.new(0, 0),
                TopRightRadius = UDim.new(0, Library.CornerRadius / 2),
                BottomRightRadius = UDim.new(0, Library.CornerRadius / 2),
                BottomLeftRadius = UDim.new(0, 0),
                Parent = Menu,
            }); table.insert(Library.SpecificCorners, Corner)
        elseif SpecificCornersOnly == "no_top_left" then
            Corner = New("UICorner", {
                TopLeftRadius = UDim.new(0, 0),
                TopRightRadius = UDim.new(0, Library.CornerRadius / 2),
                BottomRightRadius = UDim.new(0, Library.CornerRadius / 2),
                BottomLeftRadius = UDim.new(0, Library.CornerRadius / 2),
                Parent = Menu,
            }); table.insert(Library.SpecificCorners, Corner)
        else
            Corner = New("UICorner", {
                CornerRadius = UDim.new(0, Library.CornerRadius / 2),
                Parent = Menu,
            }); table.insert(Library.Corners, Corner)
        end
    end

    local Table = {
        Connections = {},
        Destroyed = false,

        Active = false,
        Holder = Holder,
        Menu = Menu,
        List = nil,
        Signal = nil,

        Size = Size,
    }

    if List then
        Table.List = New("UIListLayout", {
            Parent = Menu,
        })
    end

    function Table:Open()
        if CurrentMenu == Table then
            return
        elseif CurrentMenu then
            CurrentMenu:Close()
        end

        CurrentMenu = Table
        Table.Active = true

        if typeof(Offset) == "function" then
            Menu.Position = UDim2.fromOffset(
                math.floor(Holder.AbsolutePosition.X + Offset()[1]),
                math.floor(Holder.AbsolutePosition.Y + Offset()[2])
            )
        else
            Menu.Position = UDim2.fromOffset(
                math.floor(Holder.AbsolutePosition.X + Offset[1]),
                math.floor(Holder.AbsolutePosition.Y + Offset[2])
            )
        end
        Menu.Size = typeof(Table.Size) == "function" and Table.Size() or Table.Size
        if typeof(ActiveCallback) == "function" then
            Library:SafeCallback(ActiveCallback, true)
        end

        Menu.Visible = true

        Table.Signal = Holder:GetPropertyChangedSignal("AbsolutePosition"):Connect(function()
            if typeof(Offset) == "function" then
                Menu.Position = UDim2.fromOffset(
                    math.floor(Holder.AbsolutePosition.X + Offset()[1]),
                    math.floor(Holder.AbsolutePosition.Y + Offset()[2])
                )
            else
                Menu.Position = UDim2.fromOffset(
                    math.floor(Holder.AbsolutePosition.X + Offset[1]),
                    math.floor(Holder.AbsolutePosition.Y + Offset[2])
                )
            end

            if not Library:IsInsideFrame(Library.WindowContainer, Holder) and Table.Active then
                Table:Close()
            end
        end)
    end

    function Table:Close()
        if CurrentMenu ~= Table then
            return
        end
        Menu.Visible = false

        if Table.Signal then
            Table.Signal:Disconnect()
            Table.Signal = nil
        end
        Table.Active = false
        CurrentMenu = nil
        if typeof(ActiveCallback) == "function" then
            Library:SafeCallback(ActiveCallback, false)
        end
    end

    function Table:Toggle()
        if Table.Active then
            Table:Close()
        else
            Table:Open()
        end
    end

    function Table:SetSize(Size)
        Table.Size = Size
        Menu.Size = typeof(Size) == "function" and Size() or Size
    end

    function Table:Destroy()
        Table.Destroyed = true

        if Table.Connections then
            for _, Connection in Table.Connections do
                Connection:Disconnect()
            end
        end

        if CurrentMenu == Table then
            Table:Close()
        end

        if Menu then
            Menu:Destroy()
        end
    end

    return Table
end

Library:GiveSignal(UserInputService.InputBegan:Connect(function(Input: InputObject)
    if Library.Unloaded then
        return
    end

    if IsClickInput(Input, true) then
        local Location = Input.Position

        if
            CurrentMenu
            and not (
                Library:MouseIsOverFrame(CurrentMenu.Menu, Location)
                or Library:MouseIsOverFrame(CurrentMenu.Holder, Location)
            )
        then
            CurrentMenu:Close()
        end
    end
end))

--// Tooltip \\--
local TooltipLabel = New("TextLabel", {
    AutomaticSize = Enum.AutomaticSize.Y,
    BackgroundColor3 = "BackgroundColor",
    TextSize = 14,
    TextWrapped = true,
    Visible = false,
    ZIndex = 20,
    Parent = ScreenGui,
})
New("UIPadding", {
    PaddingBottom = UDim.new(0, 2),
    PaddingLeft = UDim.new(0, 4),
    PaddingRight = UDim.new(0, 4),
    PaddingTop = UDim.new(0, 2),
    Parent = TooltipLabel,
})
table.insert(
    Library.Scales,
    New("UIScale", {
        Parent = TooltipLabel,
    })
)
New("UIStroke", {
    Color = "OutlineColor",
    Parent = TooltipLabel,
})
table.insert(
    Library.Corners,
    New("UICorner", {
        CornerRadius = UDim.new(0, Library.CornerRadius / 2),
        Parent = TooltipLabel,
    })
)
TooltipLabel:GetPropertyChangedSignal("AbsolutePosition"):Connect(function()
    if Library.Unloaded then
        return
    end

    local X, _ = Library:GetTextBounds(
        TooltipLabel.Text,
        TooltipLabel.FontFace,
        TooltipLabel.TextSize,
        (workspace.CurrentCamera.ViewportSize.X - TooltipLabel.AbsolutePosition.X - 8) / Library.DPIScale
    )

    TooltipLabel.Size = UDim2.fromOffset(X + 8, 0)
end)

local CurrentHoverInstance
function Library:AddTooltip(InfoStr: string, DisabledInfoStr: string, HoverInstance: GuiObject)
    local TooltipTable = {
        Disabled = false,
        Hovering = false,
        Signals = {},
    }

    local function DoHover()
        if
            CurrentHoverInstance == HoverInstance
            or Library.ActiveDialog
            or (CurrentMenu and Library:MouseIsOverFrame(CurrentMenu.Menu, Mouse))
            or (TooltipTable.Disabled and typeof(DisabledInfoStr) ~= "string")
            or (not TooltipTable.Disabled and typeof(InfoStr) ~= "string")
        then
            return
        end
        CurrentHoverInstance = HoverInstance

        local ParentGui = HoverInstance:FindFirstAncestorOfClass("ScreenGui")
        if ParentGui ~= ScreenGui and (Library.ActiveLoading and ParentGui ~= Library.ActiveLoading.ScreenGui) then
            ParentGui = ScreenGui
        end
        TooltipLabel.Parent = ParentGui

        TooltipLabel.Text = TooltipTable.Disabled and DisabledInfoStr or InfoStr
        TooltipLabel.Visible = true

        while
            (Library.Toggled or Library.ActiveLoading)
            and not Library.ActiveDialog
            and Library:MouseIsOverFrame(HoverInstance, Mouse)
            and not (CurrentMenu and Library:MouseIsOverFrame(CurrentMenu.Menu, Mouse))
        do
            TooltipLabel.Position = UDim2.fromOffset(
                Mouse.X + (Library.ShowCustomCursor and 8 or 14),
                Mouse.Y + (Library.ShowCustomCursor and 8 or 12)
            )

            RunService.RenderStepped:Wait()
        end

        TooltipLabel.Visible = false
        CurrentHoverInstance = nil
    end

    local function GiveSignal(Connection: RBXScriptConnection | RBXScriptSignal)
        local ConnectionType = typeof(Connection)
        if Connection and (ConnectionType == "RBXScriptConnection" or ConnectionType == "RBXScriptSignal") then
            table.insert(TooltipTable.Signals, Connection)
        end

        return Connection
    end

    GiveSignal(HoverInstance.MouseEnter:Connect(DoHover))
    GiveSignal(HoverInstance.MouseMoved:Connect(DoHover))
    GiveSignal(HoverInstance.MouseLeave:Connect(function()
        if CurrentHoverInstance ~= HoverInstance then
            return
        end

        TooltipLabel.Visible = false
        CurrentHoverInstance = nil
    end))

    function TooltipTable:Destroy()
        for Index = #TooltipTable.Signals, 1, -1 do
            local Connection = table.remove(TooltipTable.Signals, Index)
            if Connection and Connection.Connected then
                Connection:Disconnect()
            end
        end

        if CurrentHoverInstance == HoverInstance then
            if TooltipLabel then
                TooltipLabel.Visible = false
            end

            CurrentHoverInstance = nil
        end
    end

    table.insert(Tooltips, TooltipLabel)
    return TooltipTable
end

function Library:OnUnload(Callback)
    table.insert(Library.UnloadSignals, Callback)
end

local CheckIcon = Library:GetIcon("check")
local ArrowIcon = Library:GetIcon("chevron-up")
local ResizeIcon = Library:GetIcon("move-diagonal-2")
local KeyIcon = Library:GetIcon("key")
local MoveIcon = Library:GetIcon("move")

function Library:SetIconModule(module: IconModule)
    FetchIcons = true
    Icons = module

    -- Top ten fixes 🚀
    CheckIcon = Library:GetIcon("check")
    ArrowIcon = Library:GetIcon("chevron-up")
    ResizeIcon = Library:GetIcon("move-diagonal-2")
    KeyIcon = Library:GetIcon("key")
    MoveIcon = Library:GetIcon("move")
end

local BaseAddons = {}
do
    local Funcs = {}

    function Funcs:AddKeyPicker(Idx, Info)
        if self.Destroyed then return nil end

        Info = Library:Validate(Info, Templates.KeyPicker)

        local ParentObj = self
        local ToggleLabel = ParentObj.TextLabel

        if ParentObj.Type == "Button" or ParentObj.Type == "SubButton" then
            assert(Info.Mode == "Press", "KeyPicker on Buttons can only be applied with the 'Press' mode.")

            ToggleLabel = ParentObj.Base
        end

        local KeyPicker = {
            Connections = {},

            Text = Info.Text,
            Value = Info.Default, -- Key
            Modifiers = Info.DefaultModifiers, -- Modifiers
            DisplayValue = Info.Default, -- Picker Text

            Blacklisted = Info.Blacklisted,
            BlacklistedModifiers = Info.BlacklistedModifiers,
            Whitelisted = Info.Whitelisted,
            WhitelistedModifiers = Info.WhitelistedModifiers,

            Toggled = false,
            Mode = Info.Mode,
            SyncToggleState = Info.SyncToggleState,

            Callback = Info.Callback,
            ChangedCallback = Info.ChangedCallback,
            Changed = Info.Changed,
            Clicked = Info.Clicked,

            Type = "KeyPicker",
        }

        if KeyPicker.Mode == "Press" then
            assert(ParentObj.Type == "Label" or ParentObj.Type == "Button" or ParentObj.Type == "SubButton", "KeyPicker with the mode 'Press' can be only applied on Labels and Buttons.")

            KeyPicker.SyncToggleState = false
            Info.Modes = { "Press" }
            Info.Mode = "Press"
        end

        if KeyPicker.SyncToggleState then
            Info.Modes = { "Toggle", "Hold" }

            if not table.find(Info.Modes, Info.Mode) then
                Info.Mode = "Toggle"
            end
        end

        local Picking = false
        local IsForButton = ParentObj.Type == "Button" or ParentObj.Type == "SubButton"

        -- Special Keys
        local SpecialKeys = {
            ["MB1"] = Enum.UserInputType.MouseButton1,
            ["MB2"] = Enum.UserInputType.MouseButton2,
            ["MB3"] = Enum.UserInputType.MouseButton3,
        }

        local SpecialKeysInput = {
            [Enum.UserInputType.MouseButton1] = "MB1",
            [Enum.UserInputType.MouseButton2] = "MB2",
            [Enum.UserInputType.MouseButton3] = "MB3",
        }

        -- Modifiers
        local Modifiers = {
            ["LAlt"] = Enum.KeyCode.LeftAlt,
            ["RAlt"] = Enum.KeyCode.RightAlt,

            ["LCtrl"] = Enum.KeyCode.LeftControl,
            ["RCtrl"] = Enum.KeyCode.RightControl,

            ["LShift"] = Enum.KeyCode.LeftShift,
            ["RShift"] = Enum.KeyCode.RightShift,

            ["Tab"] = Enum.KeyCode.Tab,
            ["CapsLock"] = Enum.KeyCode.CapsLock,
        }

        local ModifiersInput = {
            [Enum.KeyCode.LeftAlt] = "LAlt",
            [Enum.KeyCode.RightAlt] = "RAlt",

            [Enum.KeyCode.LeftControl] = "LCtrl",
            [Enum.KeyCode.RightControl] = "RCtrl",

            [Enum.KeyCode.LeftShift] = "LShift",
            [Enum.KeyCode.RightShift] = "RShift",

            [Enum.KeyCode.Tab] = "Tab",
            [Enum.KeyCode.CapsLock] = "CapsLock",
        }

        local IsModifierInput = function(Input)
            return Input.UserInputType == Enum.UserInputType.Keyboard and ModifiersInput[Input.KeyCode] ~= nil
        end

        local GetActiveModifiers = function()
            local ActiveModifiers = {}

            for Name, Input in Modifiers do
                if table.find(ActiveModifiers, Name) then
                    continue
                end
                if not UserInputService:IsKeyDown(Input) then
                    continue
                end

                table.insert(ActiveModifiers, Name)
            end

            return ActiveModifiers
        end

        local AreModifiersHeld = function(Required)
            if not (typeof(Required) == "table" and GetTableSize(Required) > 0) then
                return true
            end

            local ActiveModifiers = GetActiveModifiers()
            local Holding = true

            for _, Name in Required do
                if table.find(ActiveModifiers, Name) then
                    continue
                end

                Holding = false
                break
            end

            return Holding
        end

        local IsInputDown = function(Input)
            if not Input then
                return false
            end

            if SpecialKeysInput[Input.UserInputType] ~= nil then
                return UserInputService:IsMouseButtonPressed(Input.UserInputType)
                    and not UserInputService:GetFocusedTextBox()
            elseif Input.UserInputType == Enum.UserInputType.Keyboard then
                return UserInputService:IsKeyDown(Input.KeyCode) and not UserInputService:GetFocusedTextBox()
            else
                return false
            end
        end

        local ConvertToInputModifiers = function(CurrentModifiers)
            local InputModifiers = {}

            for _, name in CurrentModifiers do
                table.insert(InputModifiers, Modifiers[name])
            end

            return InputModifiers
        end

        local VerifyModifiers = function(CurrentModifiers)
            if typeof(CurrentModifiers) ~= "table" then
                return {}
            end

            local ValidModifiers = {}

            for _, name in CurrentModifiers do
                if not Modifiers[name] then
                    continue
                end

                table.insert(ValidModifiers, name)
            end

            return ValidModifiers
        end

        KeyPicker.Modifiers = VerifyModifiers(KeyPicker.Modifiers)

        local SlideOverflow = true
        local MaxPickerWidth = 75
        local SlidingLabel

        local LastPickerWidth = 0
        local SlideForwardTween
        local SlideBackTween
        local HandleForwardTween = function(State)
            if State ~= Enum.PlaybackState.Completed then
                return
            end

            task.wait(1.5)
            if SlideBackTween then
                SlideBackTween:Play()
            end
        end

        local HandleBackTween = function(State)
            if State ~= Enum.PlaybackState.Completed then
                return
            end

            task.wait(1.5)
            if SlideForwardTween then
                SlideForwardTween:Play()
            end
        end

        local CancelSlidingTweens = function()
            if SlideForwardTween then
                SlideForwardTween:Cancel()
                SlideForwardTween:Destroy()
                SlideForwardTween = nil
            end

            if SlideBackTween then
                SlideBackTween:Cancel()
                SlideBackTween:Destroy()
                SlideBackTween = nil
            end
        end

        local Picker = New("TextButton", {
            BackgroundColor3 = "MainColor",
            Size = UDim2.fromOffset(18, 18),
            Text = (IsForButton and SlideOverflow) and "" or KeyPicker.Value,
            TextSize = 14,
            Parent = ToggleLabel,
        })

        if IsForButton and SlideOverflow then
            Picker.ClipsDescendants = true

            SlidingLabel = New("TextLabel", {
                BackgroundTransparency = 1,
                Size = UDim2.new(1, 0, 1, 0),
                Position = UDim2.new(0, 0, 0, 0),
                Text = KeyPicker.Value,
                TextSize = 14,
                FontFace = Picker.FontFace,
                TextXAlignment = Enum.TextXAlignment.Center,
                Parent = Picker,
            })

            Library:AddToRegistry(SlidingLabel, {
                TextColor3 = "FontColor",
            })
        end

        New("UIStroke", {
            Color = "OutlineColor",
            Parent = Picker,
        })

        local PickerCorner = New("UICorner", {
            TopLeftRadius = UDim.new(0, Library.CornerRadius / 2),
            TopRightRadius = UDim.new(0, Library.CornerRadius / 2),
            BottomRightRadius = UDim.new(0, Library.CornerRadius / 2),
            BottomLeftRadius = UDim.new(0, Library.CornerRadius / 2),
            Parent = Picker,
        }); table.insert(Library.SpecificCorners, PickerCorner)

        if IsForButton then
            local Holder = New("Frame", {
                BackgroundTransparency = 1,
                Size = UDim2.new(1, 0, 0, 21),
                Parent = ToggleLabel.Parent,
            })

            New("UIListLayout", {
                FillDirection = Enum.FillDirection.Horizontal,
                HorizontalFlex = Enum.UIFlexAlignment.Fill,
                Padding = UDim.new(0, 9),
                Parent = Holder,
            })

            ToggleLabel.Parent = Holder
            Picker.Parent = Holder

            Picker.Size = UDim2.new(0, 18, 1, 0)
        end

        local KeybindsToggle = { Normal = KeyPicker.Mode ~= "Toggle" }
        do
            local Holder = New("TextButton", {
                BackgroundTransparency = 1,
                Size = UDim2.new(1, 0, 0, 16),
                Text = "",
                Visible = not Info.NoUI,
                Parent = Library.KeybindContainer,
            })

            local Label = New("TextLabel", {
                AutomaticSize = Enum.AutomaticSize.X,
                BackgroundTransparency = 1,
                Size = UDim2.fromScale(0, 1),
                Text = "",
                TextSize = 14,
                TextTransparency = 0.5,
                Parent = Holder,
            })

            local Checkbox = New("Frame", {
                AnchorPoint = Vector2.new(0, 0.5),
                BackgroundColor3 = "MainColor",
                Position = UDim2.fromScale(0, 0.5),
                Size = UDim2.fromOffset(14, 14),
                SizeConstraint = Enum.SizeConstraint.RelativeYY,
                Parent = Holder,
            })
            table.insert(
                Library.Corners,
                New("UICorner", {
                    CornerRadius = UDim.new(0, Library.CornerRadius / 2),
                    Parent = Checkbox,
                })
            )
            New("UIStroke", {
                Color = "OutlineColor",
                Parent = Checkbox,
            })

            local CheckImage = New("ImageLabel", {
                Image = CheckIcon and CheckIcon.Url or "",
                ImageColor3 = "FontColor",
                ImageRectOffset = CheckIcon and CheckIcon.ImageRectOffset or Vector2.zero,
                ImageRectSize = CheckIcon and CheckIcon.ImageRectSize or Vector2.zero,
                ImageTransparency = 1,
                Position = UDim2.fromOffset(2, 2),
                Size = UDim2.new(1, -4, 1, -4),
                Parent = Checkbox,
            })

            function KeybindsToggle:Display(State)
                Label.TextTransparency = State and 0 or 0.5
                CheckImage.ImageTransparency = State and 0 or 1
            end

            function KeybindsToggle:SetText(Text)
                Label.Text = Text
            end

            function KeybindsToggle:SetVisibility(Visibility)
                Holder.Visible = Visibility
            end

            function KeybindsToggle:SetNormal(Normal)
                KeybindsToggle.Normal = Normal

                Holder.Active = not Normal
                Label.Position = Normal and UDim2.fromOffset(0, 0) or UDim2.fromOffset(22, 0)
                Checkbox.Visible = not Normal
            end

            KeyPicker.DoClick = function(...) end --// make luau lsp shut up
            Holder.MouseButton1Click:Connect(function()
                if KeybindsToggle.Normal then
                    return
                end

                KeyPicker.Toggled = not KeyPicker.Toggled
                KeyPicker:DoClick()
            end)

            KeybindsToggle.Holder = Holder
            KeybindsToggle.Label = Label
            KeybindsToggle.Checkbox = Checkbox
            KeybindsToggle.Loaded = true
            table.insert(Library.KeybindToggles, KeybindsToggle)
        end

        local ModeButtons = {}
        local TotalModeButtons = GetTableSize(Info.Modes)
        local MenuTable = Library:AddContextMenu(Picker, UDim2.fromOffset(62, 0), function()
            return { Picker.AbsoluteSize.X + 1.5, 0.5 }
        end, 1, function(Active: boolean)
            PickerCorner.TopRightRadius = Active and UDim.new(0, 0) or UDim.new(0, Library.CornerRadius / 2)
            PickerCorner.BottomRightRadius = Active and UDim.new(0, 0) or UDim.new(0, Library.CornerRadius / 2)
        end, false, if TotalModeButtons == 1 then "no_left" else "no_top_left")
        KeyPicker.Menu = MenuTable

        for Index, Mode in Info.Modes do
            local ModeButton = {}

            local Button = New("TextButton", {
                BackgroundColor3 = "MainColor",
                BackgroundTransparency = 1,
                Size = UDim2.new(1, 0, 0, IsForButton and 21 or (TotalModeButtons == 1 and 18 or 19)),
                Text = Mode,
                TextSize = 14,
                TextTransparency = 0.5,
                Parent = MenuTable.Menu,
            })
            
            if Index == 1 and TotalModeButtons == 1 then
                table.insert(Library.SpecificCorners, New("UICorner", {
                    TopLeftRadius = UDim.new(0, 0),
                    TopRightRadius = UDim.new(0, Library.CornerRadius / 2),
                    BottomLeftRadius = UDim.new(0, 0),
                    BottomRightRadius = UDim.new(0, Library.CornerRadius / 2),
                    Parent = Button,
                }))
            elseif Index == 1 then
                table.insert(Library.SpecificCorners, New("UICorner", {
                    TopLeftRadius = UDim.new(0, 0),
                    TopRightRadius = UDim.new(0, Library.CornerRadius / 2),
                    BottomLeftRadius = UDim.new(0, 0),
                    BottomRightRadius = UDim.new(0, 0),
                    Parent = Button,
                }))
            elseif Index == TotalModeButtons then
                table.insert(Library.SpecificCorners, New("UICorner", {
                    TopLeftRadius = UDim.new(0, 0),
                    TopRightRadius = UDim.new(0, 0),
                    BottomLeftRadius = UDim.new(0, Library.CornerRadius / 2),
                    BottomRightRadius = UDim.new(0, Library.CornerRadius / 2),
                    Parent = Button,
                }))
            end

            function ModeButton:Select()
                for _, Button in ModeButtons do
                    Button:Deselect()
                end

                KeyPicker.Mode = Mode

                Button.BackgroundTransparency = 0
                Button.TextTransparency = 0

                MenuTable:Close()
            end

            function ModeButton:Deselect()
                KeyPicker.Mode = nil

                Button.BackgroundTransparency = 1
                Button.TextTransparency = 0.5
            end

            Button.MouseButton1Click:Connect(function()
                ModeButton:Select()
            end)

            if KeyPicker.Mode == Mode then
                ModeButton:Select()
            end

            ModeButtons[Mode] = ModeButton
        end

        function KeyPicker:Display(PickerText)
            if Library.Unloaded then
                return
            end

            local DisplayText = PickerText or KeyPicker.DisplayValue
            if IsForButton and SlideOverflow then
                if LastPickerWidth == Picker.AbsoluteSize.X then
                    return
                end

                local X, _Y = Library:GetTextBounds(
                    DisplayText,
                    Picker.FontFace,
                    Picker.TextSize,
                    10000
                )

                SlidingLabel.Text = DisplayText

                local OffsetScale = X + 9
                local PickerWidth = math.min(OffsetScale, MaxPickerWidth)
                Picker.Size = UDim2.new(0, PickerWidth, 1, 0)

                if OffsetScale > PickerWidth then
                    SlidingLabel.TextXAlignment = Enum.TextXAlignment.Left
                    SlidingLabel.Size = UDim2.new(0, OffsetScale, 1, 0)
                    SlidingLabel.Position = UDim2.fromOffset(4.5, 0)

                    RunService.RenderStepped:Wait()

                    local RealPickerWidth = Picker.AbsoluteSize.X
                    if RealPickerWidth <= 0 then RealPickerWidth = PickerWidth end

                    LastPickerWidth = RealPickerWidth

                    local OverflowDistance = OffsetScale - RealPickerWidth - 4.5
                    if OverflowDistance > 0 then
                        CancelSlidingTweens()

                        local Duration = OverflowDistance / 25
                        local TweenInfo = TweenInfo.new(
                            Duration,
                            Enum.EasingStyle.Linear, Enum.EasingDirection.InOut
                        )

                        SlideForwardTween = TweenService:Create(SlidingLabel, TweenInfo, {
                            Position = UDim2.fromOffset(-OverflowDistance, 0)
                        })

                        SlideBackTween = TweenService:Create(SlidingLabel, TweenInfo, {
                            Position = UDim2.fromOffset(4.5, 0)
                        })

                        SlideForwardTween:Play()

                        SlideForwardTween.Completed:Connect(HandleForwardTween)
                        SlideBackTween.Completed:Connect(HandleBackTween)
                    else
                        CancelSlidingTweens()

                        SlidingLabel.TextXAlignment = Enum.TextXAlignment.Center
                        SlidingLabel.Size = UDim2.new(1, 0, 1, 0)
                        SlidingLabel.Position = UDim2.new(0, 0, 0, 0)
                    end
                else
                    CancelSlidingTweens()

                    SlidingLabel.TextXAlignment = Enum.TextXAlignment.Center
                    SlidingLabel.Size = UDim2.new(1, 0, 1, 0)
                    SlidingLabel.Position = UDim2.new(0, 0, 0, 0)
                end
            else
                local X, Y = Library:GetTextBounds(
                    DisplayText,
                    Picker.FontFace,
                    Picker.TextSize,
                    ToggleLabel.AbsoluteSize.X
                )
                Picker.Text = DisplayText
                Picker.Size = IsForButton and UDim2.new(0, X + 9, 1, 0) or UDim2.fromOffset((X + 9), (Y + 4))
            end
        end

        function KeyPicker:Update()
            KeyPicker:Display()

            if Info.NoUI then
                return
            end

            if KeyPicker.Mode == "Toggle" and ParentObj.Type == "Toggle" and ParentObj.Disabled then
                KeybindsToggle:SetVisibility(false)
                return
            end

            local State = KeyPicker:GetState()
            local ShowToggle = Library.ShowToggleFrameInKeybinds and KeyPicker.Mode == "Toggle"

            if KeyPicker.SyncToggleState and ParentObj.Value ~= State then
                ParentObj:SetValue(State)
            end

            if KeybindsToggle.Loaded then
                if ShowToggle then
                    KeybindsToggle:SetNormal(false)
                else
                    KeybindsToggle:SetNormal(true)
                end

                KeybindsToggle:SetText(("[%s] %s (%s)"):format(KeyPicker.DisplayValue, KeyPicker.Text, KeyPicker.Mode))
                KeybindsToggle:SetVisibility(true)
                KeybindsToggle:Display(State)
            end
        end

        function KeyPicker:GetState()
            if KeyPicker.Mode == "Always" then
                return true
            elseif KeyPicker.Mode == "Hold" then
                local Key = KeyPicker.Value
                if Key == "None" then
                    return false
                end

                if not AreModifiersHeld(KeyPicker.Modifiers) then
                    return false
                end

                if Library.IsPicking then
                    return false
                end

                if SpecialKeys[Key] ~= nil then
                    if Library.Toggled then
                        return false
                    end

                    return UserInputService:IsMouseButtonPressed(SpecialKeys[Key])
                        and not UserInputService:GetFocusedTextBox()
                else
                    return UserInputService:IsKeyDown(Enum.KeyCode[Key] :: any) and not UserInputService:GetFocusedTextBox()
                end
            else
                return KeyPicker.Toggled
            end
        end

        function KeyPicker:OnChanged(Func)
            KeyPicker.Changed = Func
        end

        function KeyPicker:OnClick(Func)
            KeyPicker.Clicked = Func
        end

        function KeyPicker:DoClick()
            if KeyPicker.Mode == "Press" then
                if KeyPicker.Toggled and Info.WaitForCallback == true then
                    return
                end

                KeyPicker.Toggled = true
            end

            Library:SafeCallback(KeyPicker.Callback, KeyPicker.Toggled)
            Library:SafeCallback(KeyPicker.Clicked, KeyPicker.Toggled)

            if IsForButton then
                Library:SafeCallback(ParentObj.Func, KeyPicker.Toggled)
            end

            if KeyPicker.Mode == "Press" then
                KeyPicker.Toggled = false
            end
        end

        function KeyPicker:SetValue(Data)
            local Key, Mode, Modifiers = Data[1], Data[2], Data[3]

            local IsKeyValid, KeyCode = pcall(function()
                if Key == "None" then
                    Key = nil
                    return nil
                end

                if SpecialKeys[Key] == nil then
                    return Enum.KeyCode[Key]
                end

                return SpecialKeys[Key]
            end)

            if Key == nil then
                KeyPicker.Value = "None"
            elseif IsKeyValid then
                KeyPicker.Value = Key
            else
                KeyPicker.Value = "Unknown"
            end

            KeyPicker.Modifiers =
                VerifyModifiers(if typeof(Modifiers) == "table" then Modifiers else KeyPicker.Modifiers)
            KeyPicker.DisplayValue = if GetTableSize(KeyPicker.Modifiers) > 0
                then (table.concat(KeyPicker.Modifiers, " + ") .. " + " .. KeyPicker.Value)
                else KeyPicker.Value

            if ModeButtons[Mode] then
                ModeButtons[Mode]:Select()
            end

            local NewModifiers = ConvertToInputModifiers(KeyPicker.Modifiers)
            Library:SafeCallback(KeyPicker.ChangedCallback, KeyCode, NewModifiers)
            Library:SafeCallback(KeyPicker.Changed, KeyCode, NewModifiers)

            KeyPicker:Update()
        end

        function KeyPicker:SetText(Text)
            KeybindsToggle:SetText(Text)
            KeyPicker:Update()
        end

        local SetPickingState = function(State)
            Picking = State
            Library.IsPicking = State

            if IsForButton then
                ToggleLabel.Visible = not Picking
                RunService.RenderStepped:Wait()
            end

            KeyPicker:Update()
        end

        Picker.MouseButton1Click:Connect(function()
            if Picking or Library.IsPicking then
                return
            end

            SetPickingState(true)

            if IsForButton and SlideOverflow then
                KeyPicker:Display("...")
            else
                Picker.Text = "..."
                Picker.Size = IsForButton and UDim2.new(0, 29, 1, 0) or UDim2.fromOffset(29, 18)
            end

            -- Wait for an non modifier key --
            local Input
            local ActiveModifiers = {}

            local GetInput = nil; GetInput = function()
                Input = UserInputService.InputBegan:Wait()
                if UserInputService:GetFocusedTextBox() ~= nil then
                    return true
                end

                if Input.KeyCode == Enum.KeyCode.Escape then
                    return false
                end

                local IsMod = IsModifierInput(Input)
                local KeyName
                if SpecialKeysInput[Input.UserInputType] ~= nil then
                    KeyName = SpecialKeysInput[Input.UserInputType]
                elseif Input.UserInputType == Enum.UserInputType.Keyboard then
                    if IsMod then
                        KeyName = ModifiersInput[Input.KeyCode]
                    else
                        KeyName = Input.KeyCode.Name
                    end
                end

                if KeyName then
                    if IsMod then
                        if KeyPicker.WhitelistedModifiers and #KeyPicker.WhitelistedModifiers > 0 and not table.find(KeyPicker.WhitelistedModifiers, KeyName) then
                            return GetInput()
                        end

                        if KeyPicker.BlacklistedModifiers and table.find(KeyPicker.BlacklistedModifiers, KeyName) then
                            return GetInput()
                        end
                    else
                        if KeyPicker.Whitelisted and #KeyPicker.Whitelisted > 0 and not table.find(KeyPicker.Whitelisted, KeyName) then
                            return GetInput()
                        end

                        if KeyPicker.Blacklisted and table.find(KeyPicker.Blacklisted, KeyName) then
                            return GetInput()
                        end
                    end
                end

                return false
            end

            repeat
                task.wait()

                -- Wait for any input --
                if IsForButton and SlideOverflow then
                    KeyPicker:Display("...")
                else
                    Picker.Text = "..."
                    Picker.Size = IsForButton and UDim2.new(0, 29, 1, 0) or UDim2.fromOffset(29, 18)
                end

                if GetInput() then
                    SetPickingState(false)
                    return
                end

                -- Escape --
                if Input.KeyCode == Enum.KeyCode.Escape then
                    break
                end

                -- Handle modifier keys --
                if IsModifierInput(Input) then
                    local StopLoop = false

                    repeat
                        task.wait()
                        if UserInputService:IsKeyDown(Input.KeyCode) then
                            task.wait(0.075)

                            if UserInputService:IsKeyDown(Input.KeyCode) then
                                -- Add modifier to the key list --
                                if not table.find(ActiveModifiers, ModifiersInput[Input.KeyCode]) then
                                    ActiveModifiers[#ActiveModifiers + 1] = ModifiersInput[Input.KeyCode]
                                    KeyPicker:Display(table.concat(ActiveModifiers, " + ") .. " + ...")
                                end

                                -- Wait for another input --
                                if GetInput() then
                                    StopLoop = true
                                    break -- Invalid Input
                                end

                                -- Escape --
                                if Input.KeyCode == Enum.KeyCode.Escape then
                                    break
                                end

                                -- Stop loop if its a normal key --
                                if not IsModifierInput(Input) then
                                    break
                                end
                            else
                                if not table.find(ActiveModifiers, ModifiersInput[Input.KeyCode]) then
                                    break -- Modifier is meant to be used as a normal key --
                                end
                            end
                        end
                    until false

                    if StopLoop then
                        SetPickingState(false)
                        return
                    end
                end

                break -- Input found, end loop
            until false

            local Key = "Unknown"
            if SpecialKeysInput[Input.UserInputType] ~= nil then
                Key = SpecialKeysInput[Input.UserInputType]
            elseif Input.UserInputType == Enum.UserInputType.Keyboard then
                Key = Input.KeyCode == Enum.KeyCode.Escape and "None" or Input.KeyCode.Name
            end

            ActiveModifiers = if Input.KeyCode == Enum.KeyCode.Escape or Key == "Unknown" then {} else ActiveModifiers

            KeyPicker.Toggled = false
            KeyPicker:SetValue({ Key, KeyPicker.Mode, ActiveModifiers })

            repeat
                task.wait()
            until not IsInputDown(Input) or UserInputService:GetFocusedTextBox()

            SetPickingState(false)
        end)
        Picker.MouseButton2Click:Connect(MenuTable.Toggle)

        table.insert(KeyPicker.Connections, UserInputService.InputBegan:Connect(function(Input: InputObject)
            if Library.Unloaded then
                return
            end

            local IsMouse = IsMouseClickInput(Input)
            if
                KeyPicker.Mode == "Always"
                or KeyPicker.Value == "Unknown"
                or KeyPicker.Value == "None"
                or Picking
                or Library.IsPicking
                or UserInputService:GetFocusedTextBox()
                or (IsMouse and Library.Toggled)
            then
                return
            end

            local Key = KeyPicker.Value
            local HoldingModifiers = AreModifiersHeld(KeyPicker.Modifiers)
            local HoldingKey = false

            if
                Key
                and HoldingModifiers == true
                and (
                    SpecialKeysInput[Input.UserInputType] == Key
                    or (Input.UserInputType == Enum.UserInputType.Keyboard and Input.KeyCode.Name == Key)
                )
            then
                HoldingKey = true
            end

            if KeyPicker.Mode == "Toggle" then
                if HoldingKey then
                    KeyPicker.Toggled = not KeyPicker.Toggled
                    KeyPicker:DoClick()
                end
            elseif KeyPicker.Mode == "Press" then
                if HoldingKey then
                    KeyPicker:DoClick()
                end
            end

            KeyPicker:Update()
        end))

        table.insert(KeyPicker.Connections, UserInputService.InputEnded:Connect(function(Input: InputObject)
            if Library.Unloaded then
                return
            end

            local IsMouse = IsMouseClickInput(Input)
            if
                KeyPicker.Value == "Unknown"
                or KeyPicker.Value == "None"
                or Picking
                or Library.IsPicking
                or UserInputService:GetFocusedTextBox()
                or (IsMouse and Library.Toggled)
            then
                return
            end

            KeyPicker:Update()
        end))

        KeyPicker:Update()

        if ParentObj.Addons then
            table.insert(ParentObj.Addons, KeyPicker)
        end

        KeyPicker.Default = KeyPicker.Value
        KeyPicker.DefaultModifiers = table.clone(KeyPicker.Modifiers or {})

        function KeyPicker:Destroy()
            KeyPicker.Destroyed = true

            if KeyPicker.Connections then
                for _, Connection in KeyPicker.Connections do
                    Connection:Disconnect()
                end
            end

            if KeybindsToggle and KeybindsToggle.Loaded then
                if KeybindsToggle.Holder then 
                    KeybindsToggle.Holder:Destroy()
                end
                local KTIdx = table.find(Library.KeybindToggles, KeybindsToggle)
                if KTIdx then
                    table.remove(Library.KeybindToggles, KTIdx)
                end
            end

            if MenuTable then 
                MenuTable:Destroy() 
            end

            if IsForButton and SlideOverflow then
                if SlideForwardTween then 
                    SlideForwardTween:Destroy() 
                end

                if SlideBackTween then 
                    SlideBackTween:Destroy() 
                end
            end

            if Picker then
                Picker:Destroy()
            end

            if ParentObj and ParentObj.Addons then
                local AddonIdx = table.find(ParentObj.Addons, KeyPicker)
                
                if AddonIdx then 
                    table.remove(ParentObj.Addons, AddonIdx) 
                end
            end

            Options[Idx] = nil
        end

        Options[Idx] = KeyPicker

        return self
    end

    local HueSequenceTable = {}
    for Hue = 0, 1, 0.1 do
        table.insert(HueSequenceTable, ColorSequenceKeypoint.new(Hue, Color3.fromHSV(Hue, 1, 1)))
    end
    function Funcs:AddColorPicker(Idx, Info)
        if self.Destroyed then return nil end

        Info = Library:Validate(Info, Templates.ColorPicker)

        local ParentObj = self
        local ToggleLabel = ParentObj.TextLabel

        local ColorPicker = {
            Connections = {},
            Destroyed = false,

            Value = Info.Default,

            Transparency = Info.Transparency or 0,
            Title = Info.Title,

            Callback = Info.Callback,
            Changed = Info.Changed,

            Type = "ColorPicker",
        }
        ColorPicker.Hue, ColorPicker.Sat, ColorPicker.Vib = ColorPicker.Value:ToHSV()

        local Holder = New("TextButton", {
            BackgroundColor3 = ColorPicker.Value,
            Size = UDim2.fromOffset(18, 18),
            Text = "",
            Parent = ToggleLabel,
        })

        local HolderStroke = New("UIStroke", {
            Color = Library:GetDarkerColor(ColorPicker.Value),
            Parent = Holder,
        })

        local ColorPickerCorner = New("UICorner", {
            TopLeftRadius = UDim.new(0, Library.CornerRadius / 2),
            TopRightRadius = UDim.new(0, Library.CornerRadius / 2),
            BottomRightRadius = UDim.new(0, Library.CornerRadius / 2),
            BottomLeftRadius = UDim.new(0, Library.CornerRadius / 2),
            Parent = Holder,
        }); table.insert(Library.SpecificCorners, ColorPickerCorner)

        local HolderTransparency = New("ImageLabel", {
            Image = CustomImageManager.GetAsset("TransparencyTexture"),
            ImageTransparency = (1 - ColorPicker.Transparency),
            ScaleType = Enum.ScaleType.Tile,
            Position = UDim2.new(0, -1, 0, -1),
            Size = UDim2.new(1, 2, 1, 2),
            TileSize = UDim2.fromOffset(9, 9),
            Parent = Holder,
        })

        table.insert(
            Library.Corners,
            New("UICorner", {
                CornerRadius = UDim.new(0, Library.CornerRadius / 2),
                Parent = HolderTransparency,
            })
        )

        --// Color Menu \\--
        local ColorMenu = Library:AddContextMenu(
            Holder,
            UDim2.fromOffset(Info.Transparency and 256 or 234, 0),
            function()
                return { 0.5, Holder.AbsoluteSize.Y + 1.5 }
            end,
            1, function(Active: boolean)
                ColorPickerCorner.BottomRightRadius = Active and UDim.new(0, 0) or UDim.new(0, Library.CornerRadius / 2)
                ColorPickerCorner.BottomLeftRadius = Active and UDim.new(0, 0) or UDim.new(0, Library.CornerRadius / 2)
            end, false, "no_top_left")
        ColorMenu.List.Padding = UDim.new(0, 8)
        ColorPicker.ColorMenu = ColorMenu

        New("UIPadding", {
            PaddingBottom = UDim.new(0, 6),
            PaddingLeft = UDim.new(0, 6),
            PaddingRight = UDim.new(0, 6),
            PaddingTop = UDim.new(0, 6),
            Parent = ColorMenu.Menu,
        })

        if typeof(ColorPicker.Title) == "string" then
            New("TextLabel", {
                BackgroundTransparency = 1,
                Size = UDim2.new(1, 0, 0, 8),
                Text = ColorPicker.Title,
                TextSize = 14,
                TextXAlignment = Enum.TextXAlignment.Left,
                Parent = ColorMenu.Menu,
            })
        end

        local ColorHolder = New("Frame", {
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, 200),
            Parent = ColorMenu.Menu,
        })
        New("UIListLayout", {
            FillDirection = Enum.FillDirection.Horizontal,
            Padding = UDim.new(0, 6),
            Parent = ColorHolder,
        })

        --// Sat Map
        local SatVipMap = New("ImageButton", {
            BackgroundColor3 = ColorPicker.Value,
            Image = CustomImageManager.GetAsset("SaturationMap"),
            Size = UDim2.fromOffset(200, 200),
            Parent = ColorHolder,
        })

        local SatVibCursor = New("Frame", {
            AnchorPoint = Vector2.new(0.5, 0.5),
            BackgroundColor3 = "WhiteColor",
            Size = UDim2.fromOffset(6, 6),
            Parent = SatVipMap,
        })
        New("UICorner", {
            CornerRadius = UDim.new(1, 0),
            Parent = SatVibCursor,
        })
        New("UIStroke", {
            Color = "DarkColor",
            Parent = SatVibCursor,
        })

        --// Hue
        local HueSelector = New("TextButton", {
            Size = UDim2.fromOffset(16, 200),
            Text = "",
            Parent = ColorHolder,
        })
        New("UIGradient", {
            Color = ColorSequence.new(HueSequenceTable),
            Rotation = 90,
            Parent = HueSelector,
        })

        local HueCursor = New("Frame", {
            AnchorPoint = Vector2.new(0.5, 0.5),
            BackgroundColor3 = "WhiteColor",
            BorderColor3 = "DarkColor",
            BorderSizePixel = 1,
            Position = UDim2.fromScale(0.5, ColorPicker.Hue),
            Size = UDim2.new(1, 2, 0, 1),
            Parent = HueSelector,
        })

        --// Alpha
        local TransparencySelector, TransparencyColor, TransparencyCursor
        if Info.Transparency then
            TransparencySelector = New("ImageButton", {
                Image = CustomImageManager.GetAsset("TransparencyTexture"),
                ScaleType = Enum.ScaleType.Tile,
                Size = UDim2.fromOffset(16, 200),
                TileSize = UDim2.fromOffset(8, 8),
                Parent = ColorHolder,
            })

            TransparencyColor = New("Frame", {
                BackgroundColor3 = ColorPicker.Value,
                Size = UDim2.fromScale(1, 1),
                Parent = TransparencySelector,
            })
            New("UIGradient", {
                Rotation = 90,
                Transparency = NumberSequence.new({
                    NumberSequenceKeypoint.new(0, 0),
                    NumberSequenceKeypoint.new(1, 1),
                }),
                Parent = TransparencyColor,
            })

            TransparencyCursor = New("Frame", {
                AnchorPoint = Vector2.new(0.5, 0.5),
                BackgroundColor3 = "WhiteColor",
                BorderColor3 = "DarkColor",
                BorderSizePixel = 1,
                Position = UDim2.fromScale(0.5, ColorPicker.Transparency),
                Size = UDim2.new(1, 2, 0, 1),
                Parent = TransparencySelector,
            })
        end

        local InfoHolder = New("Frame", {
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, 20),
            Parent = ColorMenu.Menu,
        })
        New("UIListLayout", {
            FillDirection = Enum.FillDirection.Horizontal,
            HorizontalFlex = Enum.UIFlexAlignment.Fill,
            Padding = UDim.new(0, 8),
            Parent = InfoHolder,
        })

        local HueBox = New("TextBox", {
            BackgroundColor3 = "MainColor",
            ClearTextOnFocus = false,
            Size = UDim2.fromScale(1, 1),
            Text = "#??????",
            TextSize = 14,
            Parent = InfoHolder,
        })

        New("UIStroke", {
            Color = "OutlineColor",
            Parent = HueBox,
        })

        table.insert(
            Library.Corners,
            New("UICorner", {
                CornerRadius = UDim.new(0, Library.CornerRadius / 2),
                Parent = HueBox,
            })
        )

        local RgbBox = New("TextBox", {
            BackgroundColor3 = "MainColor",
            ClearTextOnFocus = false,
            Size = UDim2.fromScale(1, 1),
            Text = "?, ?, ?",
            TextSize = 14,
            Parent = InfoHolder,
        })

        New("UIStroke", {
            Color = "OutlineColor",
            Parent = RgbBox,
        })

        table.insert(
            Library.Corners,
            New("UICorner", {
                CornerRadius = UDim.new(0, Library.CornerRadius / 2),
                Parent = RgbBox,
            })
        )

        --// Context Menu \\--
        local ContextMenu = Library:AddContextMenu(Holder, UDim2.fromOffset(93, 0), function()
            return { Holder.AbsoluteSize.X + 1.5, 0.5 }
        end, 1, function(Active: boolean)
            ColorPickerCorner.TopRightRadius = Active and UDim.new(0, 0) or UDim.new(0, Library.CornerRadius / 2)
            ColorPickerCorner.BottomRightRadius = Active and UDim.new(0, 0) or UDim.new(0, Library.CornerRadius / 2)
        end, false, "no_top_left")
        ColorPicker.ContextMenu = ContextMenu
        ContextMenu.List.Padding = UDim.new(0, 6)
        do
            local function CreateButton(Text, Func)
                local Button = New("TextButton", {
                    BackgroundTransparency = 1,
                    Size = UDim2.new(1, 0, 0, 21),
                    Text = Text,
                    TextSize = 14,
                    Parent = ContextMenu.Menu,
                })

                Button.MouseButton1Click:Connect(function()
                    Library:SafeCallback(Func)
                    ContextMenu:Close()
                end)
            end

            CreateButton("Copy color", function()
                Library.CopiedColor = { ColorPicker.Value, ColorPicker.Transparency }
            end)

            ColorPicker.SetValueRGB = function(...) end --// make luau lsp shut up
            CreateButton("Paste color", function()
                ColorPicker:SetValueRGB(Library.CopiedColor[1], Library.CopiedColor[2])
            end)

            if setclipboard then
                CreateButton("Copy Hex", function()
                    setclipboard(tostring(ColorPicker.Value:ToHex()))
                end)

                CreateButton("Copy RGB", function()
                    setclipboard(table.concat({
                        math.floor(ColorPicker.Value.R * 255),
                        math.floor(ColorPicker.Value.G * 255),
                        math.floor(ColorPicker.Value.B * 255),
                    }, ", "))
                end)
            end
        end

        --// End \\--
        function ColorPicker:SetHSVFromRGB(Color)
            ColorPicker.Hue, ColorPicker.Sat, ColorPicker.Vib = Color:ToHSV()
        end

        function ColorPicker:Display()
            if Library.Unloaded then
                return
            end

            ColorPicker.Value = Color3.fromHSV(ColorPicker.Hue, ColorPicker.Sat, ColorPicker.Vib)

            Holder.BackgroundColor3 = ColorPicker.Value
            HolderStroke.Color = Library:GetDarkerColor(ColorPicker.Value)
            HolderTransparency.ImageTransparency = (1 - ColorPicker.Transparency)

            SatVipMap.BackgroundColor3 = Color3.fromHSV(ColorPicker.Hue, 1, 1)
            if TransparencyColor then
                TransparencyColor.BackgroundColor3 = ColorPicker.Value
            end

            SatVibCursor.Position = UDim2.fromScale(ColorPicker.Sat, 1 - ColorPicker.Vib)
            HueCursor.Position = UDim2.fromScale(0.5, ColorPicker.Hue)
            if TransparencyCursor then
                TransparencyCursor.Position = UDim2.fromScale(0.5, ColorPicker.Transparency)
            end

            HueBox.Text = "#" .. ColorPicker.Value:ToHex()
            RgbBox.Text = table.concat({
                math.floor(ColorPicker.Value.R * 255),
                math.floor(ColorPicker.Value.G * 255),
                math.floor(ColorPicker.Value.B * 255),
            }, ", ")
        end

        function ColorPicker:Update()
            ColorPicker:Display()

            Library:SafeCallback(ColorPicker.Callback, ColorPicker.Value)
            Library:SafeCallback(ColorPicker.Changed, ColorPicker.Value)
        end

        function ColorPicker:OnChanged(Func)
            ColorPicker.Changed = Func
        end

        function ColorPicker:SetValue(HSV, Transparency)
            if typeof(HSV) == "Color3" then
                ColorPicker:SetValueRGB(HSV, Transparency)
                return
            end

            local Color = Color3.fromHSV(HSV[1], HSV[2], HSV[3])
            ColorPicker.Transparency = Info.Transparency and Transparency or 0
            ColorPicker:SetHSVFromRGB(Color)
            ColorPicker:Update()
        end

        function ColorPicker:SetValueRGB(Color, Transparency)
            ColorPicker.Transparency = Info.Transparency and Transparency or 0
            ColorPicker:SetHSVFromRGB(Color)
            ColorPicker:Update()
        end

        table.insert(ColorPicker.Connections, Holder.MouseButton1Click:Connect(ColorMenu.Toggle))
        table.insert(ColorPicker.Connections, Holder.MouseButton2Click:Connect(ContextMenu.Toggle))

        table.insert(ColorPicker.Connections, SatVipMap.InputBegan:Connect(function(Input: InputObject)
            while IsDragInput(Input) and not ColorPicker.Destroyed do
                local MinX = SatVipMap.AbsolutePosition.X
                local MaxX = MinX + SatVipMap.AbsoluteSize.X
                local LocationX = math.clamp(Mouse.X, MinX, MaxX)

                local MinY = SatVipMap.AbsolutePosition.Y
                local MaxY = MinY + SatVipMap.AbsoluteSize.Y
                local LocationY = math.clamp(Mouse.Y, MinY, MaxY)

                local OldSat = ColorPicker.Sat
                local OldVib = ColorPicker.Vib
                ColorPicker.Sat = (LocationX - MinX) / (MaxX - MinX)
                ColorPicker.Vib = 1 - ((LocationY - MinY) / (MaxY - MinY))

                if ColorPicker.Sat ~= OldSat or ColorPicker.Vib ~= OldVib then
                    ColorPicker:Update()
                end

                RunService.RenderStepped:Wait()
            end
        end))

        table.insert(ColorPicker.Connections, HueSelector.InputBegan:Connect(function(Input: InputObject)
            while IsDragInput(Input) and not ColorPicker.Destroyed do
                local Min = HueSelector.AbsolutePosition.Y
                local Max = Min + HueSelector.AbsoluteSize.Y
                local Location = math.clamp(Mouse.Y, Min, Max)

                local OldHue = ColorPicker.Hue
                ColorPicker.Hue = (Location - Min) / (Max - Min)

                if ColorPicker.Hue ~= OldHue then
                    ColorPicker:Update()
                end

                RunService.RenderStepped:Wait()
            end
        end))
        
        if TransparencySelector then
            table.insert(ColorPicker.Connections, TransparencySelector.InputBegan:Connect(function(Input: InputObject)
                while IsDragInput(Input) and not ColorPicker.Destroyed do
                    local Min = TransparencySelector.AbsolutePosition.Y
                    local Max = TransparencySelector.AbsolutePosition.Y + TransparencySelector.AbsoluteSize.Y
                    local Location = math.clamp(Mouse.Y, Min, Max)

                    local OldTransparency = ColorPicker.Transparency
                    ColorPicker.Transparency = (Location - Min) / (Max - Min)

                    if ColorPicker.Transparency ~= OldTransparency then
                        ColorPicker:Update()
                    end

                    RunService.RenderStepped:Wait()
                end
            end))
        end

        table.insert(ColorPicker.Connections, HueBox.FocusLost:Connect(function(Enter)
            if not Enter then
                return
            end

            local Success, Color = pcall(Color3.fromHex, HueBox.Text)
            if Success and typeof(Color) == "Color3" then
                ColorPicker.Hue, ColorPicker.Sat, ColorPicker.Vib = Color:ToHSV()
            end

            ColorPicker:Update()
        end))

        table.insert(ColorPicker.Connections, RgbBox.FocusLost:Connect(function(Enter)
            if not Enter then
                return
            end

            local R, G, B = RgbBox.Text:match("(%d+),%s*(%d+),%s*(%d+)")
            if R and G and B then
                ColorPicker:SetHSVFromRGB(Color3.fromRGB(R, G, B))
            end

            ColorPicker:Update()
        end))

        ColorPicker:Display()

        if ParentObj.Addons then
            table.insert(ParentObj.Addons, ColorPicker)
        end

        ColorPicker.Default = ColorPicker.Value

        function ColorPicker:Destroy()
            ColorPicker.Destroyed = true

            if ColorPicker.Connections then
                for _, Connection in ColorPicker.Connections do
                    Connection:Disconnect()
                end
            end

            if ColorMenu then 
                ColorMenu:Destroy() 
            end

            if ContextMenu then 
                ContextMenu:Destroy() 
            end

            if Holder then 
                Holder:Destroy() 
            end

            if ParentObj and ParentObj.Addons then
                local AddonIdx = table.find(ParentObj.Addons, ColorPicker)
                
                if AddonIdx then 
                    table.remove(ParentObj.Addons, AddonIdx) 
                end
            end

            Options[Idx] = nil
        end

        Options[Idx] = ColorPicker

        return self
    end

    BaseAddons.__index = Funcs
    BaseAddons.__namecall = function(_, Key, ...)
        return Funcs[Key](...)
    end
end

local BaseGroupbox = {}
do
    local Funcs = {}

    function Funcs:AddDivider(...)
        if self.Destroyed then return nil end

        local Params = select(1, ...)
        local Text
        local MarginTop = 0
        local MarginBottom = 0

        if typeof(Params) == "table" then
            Text = Params.Text
            MarginTop = Params.MarginTop or Params.Margin or 0
            MarginBottom = Params.MarginBottom or Params.Margin or 0
        elseif typeof(Params) == "string" then
            Text = Params
        end

        local Groupbox = self
        local Container = Groupbox.Container

        local Holder = New("Frame", {
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, 6 + MarginTop + MarginBottom),
            Parent = Container,
        })

        local InnerHolder = New("Frame", {
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 1, 0),
            Parent = Holder,
        })

        New("UIPadding", {
            PaddingTop = UDim.new(0, MarginTop),
            PaddingBottom = UDim.new(0, MarginBottom),
            Parent = Holder,
        })

        if Text then
            local TextLabel = New("TextLabel", {
                AutomaticSize = Enum.AutomaticSize.X,
                BackgroundTransparency = 1,
                Size = UDim2.fromScale(1, 0),
                Text = Text,
                TextSize = 14,
                TextTransparency = 0.5,
                TextXAlignment = Enum.TextXAlignment.Center,
                Parent = InnerHolder,
            })

            local X, _ = Library:GetTextBounds(Text, TextLabel.FontFace, TextLabel.TextSize, TextLabel.AbsoluteSize.X)
            local SizeX = X // 2 + 10

            New("Frame", {
                AnchorPoint = Vector2.new(0, 0.5),
                BackgroundColor3 = "MainColor",
                BorderColor3 = "OutlineColor",
                BorderSizePixel = 1,
                Position = UDim2.fromScale(0, 0.5),
                Size = UDim2.new(0.5, -SizeX, 0, 2),
                Parent = InnerHolder,
            })
            New("Frame", {
                AnchorPoint = Vector2.new(1, 0.5),
                BackgroundColor3 = "MainColor",
                BorderColor3 = "OutlineColor",
                BorderSizePixel = 1,
                Position = UDim2.fromScale(1, 0.5),
                Size = UDim2.new(0.5, -SizeX, 0, 2),
                Parent = InnerHolder,
            })
        else
            New("Frame", {
                AnchorPoint = Vector2.new(0, 0.5),
                BackgroundColor3 = "MainColor",
                BorderColor3 = "OutlineColor",
                BorderSizePixel = 1,
                Position = UDim2.fromScale(0, 0.5),
                Size = UDim2.new(1, 0, 0, 2),
                Parent = InnerHolder,
            })
        end

        Groupbox:Resize()

        local Divider = {
            Connections = {},
            Destroyed = false,

            Holder = Holder,
            Text = Text,
            MarginTop = MarginTop,
            MarginBottom = MarginBottom,
            Type = "Divider",
        }

        function Divider:SetVisible(Value)
            Holder.Visible = Value == true
            Groupbox:Resize()
        end

        function Divider:Destroy()
            Divider.Destroyed = true

            if Divider.Connections then
                for _, Connection in Divider.Connections do
                    Connection:Disconnect()
                end
            end

            if Holder then 
                Holder:Destroy() 
            end

            local ElemIdx = table.find(Groupbox.Elements, Divider)
            if ElemIdx then 
                table.remove(Groupbox.Elements, ElemIdx) 
            end

            Groupbox:Resize()
        end

        table.insert(Groupbox.Elements, Divider)
        return Divider
    end

    function Funcs:AddLabel(...)
        if self.Destroyed then return nil end

        local Data = {}
        local Addons = {}

        local First = select(1, ...)
        local Second = select(2, ...)

        if typeof(First) == "table" or typeof(Second) == "table" then
            local Params = typeof(First) == "table" and First or Second

            Data.Text = Params.Text or ""
            Data.DoesWrap = Params.DoesWrap or false
            Data.Size = Params.Size or 14
            Data.Visible = Params.Visible or true
            Data.Idx = typeof(Second) == "table" and First or nil
        else
            Data.Text = First or ""
            Data.DoesWrap = Second or false
            Data.Size = 14
            Data.Visible = true
            Data.Idx = select(3, ...) or nil
        end

        local Groupbox = self
        local Container = Groupbox.Container

        local Label = {
            Connections = {},
            Destroyed = false,

            Text = Data.Text,
            DoesWrap = Data.DoesWrap,

            Addons = Addons,

            Visible = Data.Visible,
            Type = "Label",
        }

        local TextLabel = New("TextLabel", {
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, 18),
            Text = Label.Text,
            TextSize = Data.Size,
            TextWrapped = Label.DoesWrap,
            TextXAlignment = Groupbox.IsKeyTab and Enum.TextXAlignment.Center or Enum.TextXAlignment.Left,
            Parent = Container,
        })

        function Label:SetVisible(Visible: boolean)
            Label.Visible = Visible

            TextLabel.Visible = Label.Visible
            Groupbox:Resize()
        end

        function Label:SetText(Text: string)
            Label.Text = Text
            TextLabel.Text = Text

            if Label.DoesWrap then
                local _, Y =
                    Library:GetTextBounds(Label.Text, TextLabel.FontFace, TextLabel.TextSize, TextLabel.AbsoluteSize.X)
                TextLabel.Size = UDim2.new(1, 0, 0, Y + 4)
            end

            Groupbox:Resize()
        end

        if Label.DoesWrap then
            local _, Y =
                Library:GetTextBounds(Label.Text, TextLabel.FontFace, TextLabel.TextSize, TextLabel.AbsoluteSize.X)
            TextLabel.Size = UDim2.new(1, 0, 0, Y + 4)

            local Last = TextLabel.AbsoluteSize
            TextLabel:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
                if TextLabel.AbsoluteSize == Last then
                    return
                end

                local _, Y =
                    Library:GetTextBounds(Label.Text, TextLabel.FontFace, TextLabel.TextSize, TextLabel.AbsoluteSize.X)
                TextLabel.Size = UDim2.new(1, 0, 0, Y + 4)

                Last = TextLabel.AbsoluteSize
                Groupbox:Resize()
            end)
        else
            New("UIListLayout", {
                FillDirection = Enum.FillDirection.Horizontal,
                HorizontalAlignment = Enum.HorizontalAlignment.Right,
                Padding = UDim.new(0, 6),
                Parent = TextLabel,
            })
        end

        Groupbox:Resize()

        Label.TextLabel = TextLabel
        Label.Container = Container
        if not Data.DoesWrap then
            setmetatable(Label, BaseAddons)
        end

        Label.Holder = TextLabel
        table.insert(Groupbox.Elements, Label)

        if Data.Idx then
            Labels[Data.Idx] = Label
        else
            table.insert(Labels, Label)
        end

        function Label:Destroy()
            Label.Destroyed = true

            if Label.Connections then
                for _, Connection in Label.Connections do
                    Connection:Disconnect()
                end
            end

            if TextLabel then 
                TextLabel:Destroy() 
            end

            local ElemIdx = table.find(Groupbox.Elements, Label)
            if ElemIdx then 
                table.remove(Groupbox.Elements, ElemIdx) 
            end

            Groupbox:Resize()

            if Data.Idx then
                Labels[Data.Idx] = nil
            else
                local LblIdx = table.find(Labels, Label)
                
                if LblIdx then 
                    table.remove(Labels, LblIdx) 
                end
            end
        end

        return Label
    end

    function Funcs:AddButton(...)
        if self.Destroyed then return nil end

        local function GetInfo(...)
            local Info = {}

            local First = select(1, ...)
            local Second = select(2, ...)

            if typeof(First) == "table" or typeof(Second) == "table" then
                local Params = typeof(First) == "table" and First or Second

                Info.Text = Params.Text or ""
                Info.Func = Params.Func or Params.Callback or function() end
                Info.DoubleClick = Params.DoubleClick

                Info.Tooltip = Params.Tooltip
                Info.DisabledTooltip = Params.DisabledTooltip

                Info.Risky = Params.Risky or false
                Info.Disabled = Params.Disabled or false
                Info.Visible = Params.Visible or true
                Info.Idx = typeof(Second) == "table" and First or nil
            else
                Info.Text = First or ""
                Info.Func = Second or function() end
                Info.DoubleClick = false

                Info.Tooltip = nil
                Info.DisabledTooltip = nil

                Info.Risky = false
                Info.Disabled = false
                Info.Visible = true
                Info.Idx = select(3, ...) or nil
            end

            return Info
        end
        local Info = GetInfo(...)

        local Groupbox = self
        local Container = Groupbox.Container

        local Button = {
            Connections = {},
            Destroyed = false,

            Text = Info.Text,
            Func = Info.Func,
            DoubleClick = Info.DoubleClick,

            Tooltip = Info.Tooltip,
            DisabledTooltip = Info.DisabledTooltip,
            TooltipTable = nil,

            Risky = Info.Risky,
            Disabled = Info.Disabled,
            Visible = Info.Visible,

            Tween = nil,
            Type = "Button",
        }

        local Holder = New("Frame", {
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, 21),
            Parent = Container,
        })

        New("UIListLayout", {
            FillDirection = Enum.FillDirection.Horizontal,
            HorizontalFlex = Enum.UIFlexAlignment.Fill,
            Padding = UDim.new(0, 9),
            Parent = Holder,
        })

        local function CreateButton(Button)
            local Base = New("TextButton", {
                Active = not Button.Disabled,
                BackgroundColor3 = Button.Disabled and "BackgroundColor" or "MainColor",
                Size = UDim2.fromScale(1, 1),
                Text = Button.Text,
                TextSize = 14,
                TextTransparency = 0.4,
                Visible = Button.Visible,
                Parent = Holder,
            })

            local Stroke = New("UIStroke", {
                Color = "OutlineColor",
                Transparency = Button.Disabled and 0.5 or 0,
                Parent = Base,
            })

            table.insert(
                Library.Corners,
                New("UICorner", {
                    CornerRadius = UDim.new(0, Library.CornerRadius / 2),
                    Parent = Base,
                })
            )

            return Base, Stroke
        end

        local function InitEvents(Button)
            Button.Base.MouseEnter:Connect(function()
                if Button.Disabled then
                    return
                end

                Button.Tween = TweenService:Create(Button.Base, Library.TweenInfo, {
                    TextTransparency = 0,
                })
                Button.Tween:Play()
            end)
            Button.Base.MouseLeave:Connect(function()
                if Button.Disabled then
                    return
                end

                Button.Tween = TweenService:Create(Button.Base, Library.TweenInfo, {
                    TextTransparency = 0.4,
                })
                Button.Tween:Play()
            end)

            Button.Base.MouseButton1Click:Connect(function()
                if Button.Disabled or Button.Locked then
                    return
                end

                if Button.DoubleClick then
                    Button.Locked = true

                    Button.Base.Text = "Are you sure?"
                    Button.Base.TextColor3 = Library.Scheme.AccentColor
                    Library.Registry[Button.Base].TextColor3 = "AccentColor"

                    local Clicked = WaitForEvent(Button.Base.MouseButton1Click, 0.5)

                    Button.Base.Text = Button.Text
                    Button.Base.TextColor3 = Button.Risky and Library.Scheme.RedColor or Library.Scheme.FontColor
                    Library.Registry[Button.Base].TextColor3 = Button.Risky and "RedColor" or "FontColor"

                    if Clicked then
                        Library:SafeCallback(Button.Func)
                    end

                    RunService.RenderStepped:Wait() --// Mouse Button fires without waiting (i hate roblox)
                    Button.Locked = false
                    return
                end

                Library:SafeCallback(Button.Func)
            end)
        end

        Button.Base, Button.Stroke = CreateButton(Button)
        InitEvents(Button)

        function Button:AddButton(...)
            local Info = GetInfo(...)

            local SubButton = {
                Connections = {},
                Destroyed = false,

                Text = Info.Text,
                Func = Info.Func,
                DoubleClick = Info.DoubleClick,

                Tooltip = Info.Tooltip,
                DisabledTooltip = Info.DisabledTooltip,
                TooltipTable = nil,

                Risky = Info.Risky,
                Disabled = Info.Disabled,
                Visible = Info.Visible,

                Tween = nil,
                Type = "SubButton",
            }

            Button.SubButton = SubButton
            SubButton.Base, SubButton.Stroke = CreateButton(SubButton)
            InitEvents(SubButton)

            function SubButton:UpdateColors()
                if Library.Unloaded then
                    return
                end

                StopTween(SubButton.Tween)

                SubButton.Base.BackgroundColor3 = SubButton.Disabled and Library.Scheme.BackgroundColor
                    or Library.Scheme.MainColor
                SubButton.Base.TextTransparency = SubButton.Disabled and 0.8 or 0.4
                SubButton.Stroke.Transparency = SubButton.Disabled and 0.5 or 0

                Library.Registry[SubButton.Base].BackgroundColor3 = SubButton.Disabled and "BackgroundColor"
                    or "MainColor"
            end

            function SubButton:SetDisabled(Disabled: boolean)
                SubButton.Disabled = Disabled

                if SubButton.TooltipTable then
                    SubButton.TooltipTable.Disabled = SubButton.Disabled
                end

                SubButton.Base.Active = not SubButton.Disabled
                SubButton:UpdateColors()
            end

            function SubButton:SetVisible(Visible: boolean)
                SubButton.Visible = Visible

                SubButton.Base.Visible = SubButton.Visible
                Groupbox:Resize()
            end

            function SubButton:SetText(Text: string)
                SubButton.Text = Text
                SubButton.Base.Text = Text
            end

            if typeof(SubButton.Tooltip) == "string" or typeof(SubButton.DisabledTooltip) == "string" then
                SubButton.TooltipTable =
                    Library:AddTooltip(SubButton.Tooltip, SubButton.DisabledTooltip, SubButton.Base)
                SubButton.TooltipTable.Disabled = SubButton.Disabled
            end

            if SubButton.Risky then
                SubButton.Base.TextColor3 = Library.Scheme.RedColor
                Library.Registry[SubButton.Base].TextColor3 = "RedColor"
            end

            SubButton:UpdateColors()

            if Info.Idx then
                Buttons[Info.Idx] = SubButton
            else
                table.insert(Buttons, SubButton)
            end

            SubButton.AddKeyPicker = BaseAddons.__index.AddKeyPicker

            function SubButton:Destroy()
                SubButton.Destroyed = true

                if SubButton.TooltipTable then 
                    SubButton.TooltipTable:Destroy() 
                end

                if SubButton.Tween then 
                    SubButton.Tween:Destroy() 
                end

                if SubButton.Base then 
                    SubButton.Base:Destroy() 
                end

                if Info.Idx then
                    Buttons[Info.Idx] = nil
                else
                    local BIdx = table.find(Buttons, SubButton)
                    
                    if BIdx then 
                        table.remove(Buttons, BIdx) 
                    end
                end
            end

            return SubButton
        end

        function Button:UpdateColors()
            if Library.Unloaded then
                return
            end

            StopTween(Button.Tween)

            Button.Base.BackgroundColor3 = Button.Disabled and Library.Scheme.BackgroundColor
                or Library.Scheme.MainColor
            Button.Base.TextTransparency = Button.Disabled and 0.8 or 0.4
            Button.Stroke.Transparency = Button.Disabled and 0.5 or 0

            Library.Registry[Button.Base].BackgroundColor3 = Button.Disabled and "BackgroundColor" or "MainColor"
        end

        function Button:SetDisabled(Disabled: boolean)
            Button.Disabled = Disabled

            if Button.TooltipTable then
                Button.TooltipTable.Disabled = Button.Disabled
            end

            Button.Base.Active = not Button.Disabled
            Button:UpdateColors()
        end

        function Button:SetVisible(Visible: boolean)
            Button.Visible = Visible

            Holder.Visible = Button.Visible
            Groupbox:Resize()
        end

        function Button:SetText(Text: string)
            Button.Text = Text
            Button.Base.Text = Text
        end

        if typeof(Button.Tooltip) == "string" or typeof(Button.DisabledTooltip) == "string" then
            Button.TooltipTable = Library:AddTooltip(Button.Tooltip, Button.DisabledTooltip, Button.Base)
            Button.TooltipTable.Disabled = Button.Disabled
        end

        if Button.Risky then
            Button.Base.TextColor3 = Library.Scheme.RedColor
            Library.Registry[Button.Base].TextColor3 = "RedColor"
        end

        Button:UpdateColors()
        Groupbox:Resize()

        Button.Holder = Holder
        table.insert(Groupbox.Elements, Button)

        if Info.Idx then
            Buttons[Info.Idx] = Button
        else
            table.insert(Buttons, Button)
        end

        Button.AddKeyPicker = BaseAddons.__index.AddKeyPicker

        function Button:Destroy()
            Button.Destroyed = true

            if Button.TooltipTable then 
                Button.TooltipTable:Destroy() 
            end

            if Button.Tween then 
                Button.Tween:Destroy() 
            end

            if Button.SubButton then 
                Button.SubButton:Destroy() 
            end

            if Holder then 
                Holder:Destroy() 
            end

            local ElemIdx = table.find(Groupbox.Elements, Button)
            if ElemIdx then 
                table.remove(Groupbox.Elements, ElemIdx) 
            end

            Groupbox:Resize()

            if Info.Idx then
                Buttons[Info.Idx] = nil
            else
                local BIdx = table.find(Buttons, Button)
                
                if BIdx then 
                    table.remove(Buttons, BIdx) 
                end
            end
        end

        return Button
    end

    function Funcs:AddCheckbox(Idx, Info)
        if self.Destroyed then return nil end

        Info = Library:Validate(Info, Templates.Toggle)

        local Groupbox = self
        local Container = Groupbox.Container

        local Toggle = {
            Connections = {},
            Destroyed = false,

            Text = Info.Text,
            Value = Info.Default,

            Tooltip = Info.Tooltip,
            DisabledTooltip = Info.DisabledTooltip,
            TooltipTable = nil,

            Callback = Info.Callback,
            Changed = Info.Changed,

            Risky = Info.Risky,
            Disabled = Info.Disabled,
            Visible = Info.Visible,
            Addons = {},

            Variant = "Checkbox",
            Type = "Toggle",
        }

        local Button = New("TextButton", {
            Active = not Toggle.Disabled,
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, 18),
            Text = "",
            Visible = Toggle.Visible,
            Parent = Container,
        })

        local Label = New("TextLabel", {
            BackgroundTransparency = 1,
            Position = UDim2.fromOffset(26, 0),
            Size = UDim2.new(1, -26, 1, 0),
            Text = Toggle.Text,
            TextSize = 14,
            TextTransparency = 0.4,
            TextXAlignment = Enum.TextXAlignment.Left,
            Parent = Button,
        })

        New("UIListLayout", {
            FillDirection = Enum.FillDirection.Horizontal,
            HorizontalAlignment = Enum.HorizontalAlignment.Right,
            Padding = UDim.new(0, 6),
            Parent = Label,
        })

        local Checkbox = New("Frame", {
            BackgroundColor3 = "MainColor",
            Size = UDim2.fromScale(1, 1),
            SizeConstraint = Enum.SizeConstraint.RelativeYY,
            Parent = Button,
        })
        table.insert(
            Library.Corners,
            New("UICorner", {
                CornerRadius = UDim.new(0, Library.CornerRadius / 2),
                Parent = Checkbox,
            })
        )

        local CheckboxStroke = New("UIStroke", {
            Color = "OutlineColor",
            Parent = Checkbox,
        })

        local CheckImage = New("ImageLabel", {
            Image = CheckIcon and CheckIcon.Url or "",
            ImageColor3 = "FontColor",
            ImageRectOffset = CheckIcon and CheckIcon.ImageRectOffset or Vector2.zero,
            ImageRectSize = CheckIcon and CheckIcon.ImageRectSize or Vector2.zero,
            ImageTransparency = 1,
            Position = UDim2.fromOffset(2, 2),
            Size = UDim2.new(1, -4, 1, -4),
            Parent = Checkbox,
        })

        function Toggle:UpdateColors()
            Toggle:Display()
        end

        function Toggle:Display()
            if Library.Unloaded then
                return
            end

            CheckboxStroke.Transparency = Toggle.Disabled and 0.5 or 0

            if Toggle.Disabled then
                Label.TextTransparency = 0.8
                CheckImage.ImageTransparency = Toggle.Value and 0.8 or 1

                Checkbox.BackgroundColor3 = Library.Scheme.BackgroundColor
                Library.Registry[Checkbox].BackgroundColor3 = "BackgroundColor"

                return
            end

            TweenService:Create(Label, Library.TweenInfo, {
                TextTransparency = Toggle.Value and 0 or 0.4,
            }):Play()
            TweenService:Create(CheckImage, Library.TweenInfo, {
                ImageTransparency = Toggle.Value and 0 or 1,
            }):Play()

            Checkbox.BackgroundColor3 = Library.Scheme.MainColor
            Library.Registry[Checkbox].BackgroundColor3 = "MainColor"
        end

        function Toggle:OnChanged(Func)
            Toggle.Changed = Func
        end

        function Toggle:SetValue(Value)
            if Toggle.Disabled then
                return
            end

            Toggle.Value = Value
            Toggle:Display()

            for _, Addon in Toggle.Addons do
                if Addon.Type == "KeyPicker" and Addon.SyncToggleState then
                    Addon.Toggled = Toggle.Value
                    Addon:Update()
                end
            end

            Library:UpdateDependencyBoxes()
            Library:SafeCallback(Toggle.Callback, Toggle.Value)
            Library:SafeCallback(Toggle.Changed, Toggle.Value)
        end

        function Toggle:SetDisabled(Disabled: boolean)
            Toggle.Disabled = Disabled

            if Toggle.TooltipTable then
                Toggle.TooltipTable.Disabled = Toggle.Disabled
            end

            for _, Addon in Toggle.Addons do
                if Addon.Type == "KeyPicker" and Addon.SyncToggleState then
                    Addon:Update()
                end
            end

            Button.Active = not Toggle.Disabled
            Toggle:Display()
        end

        function Toggle:SetVisible(Visible: boolean)
            Toggle.Visible = Visible

            Button.Visible = Toggle.Visible
            Groupbox:Resize()
        end

        function Toggle:SetText(Text: string)
            Toggle.Text = Text
            Label.Text = Text
        end

        table.insert(Toggle.Connections, Button.MouseButton1Click:Connect(function()
            if Toggle.Disabled then
                return
            end

            Toggle:SetValue(not Toggle.Value)
        end))

        if typeof(Toggle.Tooltip) == "string" or typeof(Toggle.DisabledTooltip) == "string" then
            Toggle.TooltipTable = Library:AddTooltip(Toggle.Tooltip, Toggle.DisabledTooltip, Button)
            Toggle.TooltipTable.Disabled = Toggle.Disabled
        end

        if Toggle.Risky then
            Label.TextColor3 = Library.Scheme.RedColor
            Library.Registry[Label].TextColor3 = "RedColor"
        end

        Toggle:Display()
        Groupbox:Resize()

        Toggle.TextLabel = Label
        Toggle.Container = Container
        setmetatable(Toggle, BaseAddons)

        Toggle.Holder = Button
        table.insert(Groupbox.Elements, Toggle)

        Toggle.Default = Toggle.Value

        Toggles[Idx] = Toggle

        function Toggle:Destroy()
            Toggle.Destroyed = true

            if Toggle.Connections then
                for _, Connection in Toggle.Connections do
                    Connection:Disconnect()
                end
            end

            if Toggle.TooltipTable then 
                Toggle.TooltipTable:Destroy() 
            end

            if Button then 
                Button:Destroy() 
            end

            if Toggle.Addons then
                for Index = #Toggle.Addons, 1, -1 do
                    local Addon = table.remove(Toggle.Addons, Index)
                    if Addon and Addon.Destroy then
                        Addon:Destroy()
                    end
                end
            end

            local ElemIdx = table.find(Groupbox.Elements, Toggle)
            if ElemIdx then 
                table.remove(Groupbox.Elements, ElemIdx) 
            end

            Groupbox:Resize()
            Toggles[Idx] = nil
        end

        return Toggle
    end

    function Funcs:AddToggle(Idx, Info)
        if self.Destroyed then return nil end

        if Library.ForceCheckbox then
            return Funcs.AddCheckbox(self, Idx, Info)
        end

        Info = Library:Validate(Info, Templates.Toggle)

        local Groupbox = self
        local Container = Groupbox.Container

        local Toggle = {
            Connections = {},
            Destroyed = false,

            Text = Info.Text,
            Value = Info.Default,

            Tooltip = Info.Tooltip,
            DisabledTooltip = Info.DisabledTooltip,
            TooltipTable = nil,

            Callback = Info.Callback,
            Changed = Info.Changed,

            Risky = Info.Risky,
            Disabled = Info.Disabled,
            Visible = Info.Visible,
            Addons = {},

            Variant = "Switch",
            Type = "Toggle",
        }

        local Button = New("TextButton", {
            Active = not Toggle.Disabled,
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, 18),
            Text = "",
            Visible = Toggle.Visible,
            Parent = Container,
        })

        local Label = New("TextLabel", {
            BackgroundTransparency = 1,
            Size = UDim2.new(1, -40, 1, 0),
            Text = Toggle.Text,
            TextSize = 14,
            TextTransparency = 0.4,
            TextXAlignment = Enum.TextXAlignment.Left,
            Parent = Button,
        })

        New("UIListLayout", {
            FillDirection = Enum.FillDirection.Horizontal,
            HorizontalAlignment = Enum.HorizontalAlignment.Right,
            Padding = UDim.new(0, 6),
            Parent = Label,
        })

        local Switch = New("Frame", {
            AnchorPoint = Vector2.new(1, 0),
            BackgroundColor3 = "MainColor",
            Position = UDim2.fromScale(1, 0),
            Size = UDim2.fromOffset(32, 18),
            Parent = Button,
        })
        New("UICorner", {
            CornerRadius = UDim.new(1, 0),
            Parent = Switch,
        })
        New("UIPadding", {
            PaddingBottom = UDim.new(0, 2),
            PaddingLeft = UDim.new(0, 2),
            PaddingRight = UDim.new(0, 2),
            PaddingTop = UDim.new(0, 2),
            Parent = Switch,
        })
        local SwitchStroke = New("UIStroke", {
            Color = "OutlineColor",
            Parent = Switch,
        })

        local Ball = New("Frame", {
            BackgroundColor3 = "FontColor",
            Size = UDim2.fromScale(1, 1),
            SizeConstraint = Enum.SizeConstraint.RelativeYY,
            Parent = Switch,
        })
        New("UICorner", {
            CornerRadius = UDim.new(1, 0),
            Parent = Ball,
        })

        function Toggle:UpdateColors()
            Toggle:Display()
        end

        function Toggle:Display()
            if Library.Unloaded then
                return
            end

            local Offset = Toggle.Value and 1 or 0

            Switch.BackgroundTransparency = Toggle.Disabled and 0.75 or 0
            SwitchStroke.Transparency = Toggle.Disabled and 0.75 or 0

            Switch.BackgroundColor3 = Toggle.Value and Library.Scheme.AccentColor or Library.Scheme.MainColor
            SwitchStroke.Color = Toggle.Value and Library.Scheme.AccentColor or Library.Scheme.OutlineColor

            Library.Registry[Switch].BackgroundColor3 = Toggle.Value and "AccentColor" or "MainColor"
            Library.Registry[SwitchStroke].Color = Toggle.Value and "AccentColor" or "OutlineColor"

            if Toggle.Disabled then
                Label.TextTransparency = 0.8
                Ball.AnchorPoint = Vector2.new(Offset, 0)
                Ball.Position = UDim2.fromScale(Offset, 0)

                Ball.BackgroundColor3 = Library:GetDarkerColor(Library.Scheme.FontColor)
                Library.Registry[Ball].BackgroundColor3 = function()
                    return Library:GetDarkerColor(Library.Scheme.FontColor)
                end

                return
            end

            TweenService:Create(Label, Library.TweenInfo, {
                TextTransparency = Toggle.Value and 0 or 0.4,
            }):Play()
            TweenService:Create(Ball, Library.TweenInfo, {
                AnchorPoint = Vector2.new(Offset, 0),
                Position = UDim2.fromScale(Offset, 0),
            }):Play()

            Ball.BackgroundColor3 = Library.Scheme.FontColor
            Library.Registry[Ball].BackgroundColor3 = "FontColor"
        end

        function Toggle:OnChanged(Func)
            Toggle.Changed = Func
        end

        function Toggle:SetValue(Value)
            if Toggle.Disabled then
                return
            end

            Toggle.Value = Value
            Toggle:Display()

            for _, Addon in Toggle.Addons do
                if Addon.Type == "KeyPicker" and Addon.SyncToggleState then
                    Addon.Toggled = Toggle.Value
                    Addon:Update()
                end
            end

            Library:UpdateDependencyBoxes()
            Library:SafeCallback(Toggle.Callback, Toggle.Value)
            Library:SafeCallback(Toggle.Changed, Toggle.Value)
        end

        function Toggle:SetDisabled(Disabled: boolean)
            Toggle.Disabled = Disabled

            if Toggle.TooltipTable then
                Toggle.TooltipTable.Disabled = Toggle.Disabled
            end

            for _, Addon in Toggle.Addons do
                if Addon.Type == "KeyPicker" and Addon.SyncToggleState then
                    Addon:Update()
                end
            end

            Button.Active = not Toggle.Disabled
            Toggle:Display()
        end

        function Toggle:SetVisible(Visible: boolean)
            Toggle.Visible = Visible

            Button.Visible = Toggle.Visible
            Groupbox:Resize()
        end

        function Toggle:SetText(Text: string)
            Toggle.Text = Text
            Label.Text = Text
        end

        table.insert(Toggle.Connections, Button.MouseButton1Click:Connect(function()
            if Toggle.Disabled then
                return
            end

            Toggle:SetValue(not Toggle.Value)
        end))

        if typeof(Toggle.Tooltip) == "string" or typeof(Toggle.DisabledTooltip) == "string" then
            Toggle.TooltipTable = Library:AddTooltip(Toggle.Tooltip, Toggle.DisabledTooltip, Button)
            Toggle.TooltipTable.Disabled = Toggle.Disabled
        end

        if Toggle.Risky then
            Label.TextColor3 = Library.Scheme.RedColor
            Library.Registry[Label].TextColor3 = "RedColor"
        end

        Toggle:Display()
        Groupbox:Resize()

        Toggle.TextLabel = Label
        Toggle.Container = Container
        setmetatable(Toggle, BaseAddons)

        Toggle.Holder = Button
        table.insert(Groupbox.Elements, Toggle)

        Toggle.Default = Toggle.Value

        Toggles[Idx] = Toggle

        function Toggle:Destroy()
            Toggle.Destroyed = true

            if Toggle.Connections then
                for _, Connection in Toggle.Connections do
                    Connection:Disconnect()
                end
            end

            if Toggle.TooltipTable then 
                Toggle.TooltipTable:Destroy() 
            end

            if Button then 
                Button:Destroy() 
            end

            if Toggle.Addons then
                for Index = #Toggle.Addons, 1, -1 do
                    local Addon = table.remove(Toggle.Addons, Index)
                    if Addon and Addon.Destroy then
                        Addon:Destroy()
                    end
                end
            end

            local ElemIdx = table.find(Groupbox.Elements, Toggle)
            if ElemIdx then 
                table.remove(Groupbox.Elements, ElemIdx) 
            end

            Groupbox:Resize()
            Toggles[Idx] = nil
        end

        return Toggle
    end

    function Funcs:AddInput(Idx, Info)
        if self.Destroyed then return nil end

        if typeof(Info) == "table" and (typeof(Info.VerifyValue) == "function" and Info.Finished ~= true) then
            Info.Finished = true
        end

        Info = Library:Validate(Info, Templates.Input)

        local Groupbox = self
        local Container = Groupbox.Container

        local Input = {
            Connections = {},
            Destroyed = false,

            Text = Info.Text,
            Value = Info.Default,

            Finished = Info.Finished,
            Numeric = Info.Numeric,
            ClearTextOnFocus = Info.ClearTextOnFocus,
            ClearTextOnBlur = Info.ClearTextOnBlur,
            Placeholder = Info.Placeholder,
            AllowEmpty = Info.AllowEmpty,
            EmptyReset = Info.EmptyReset,

            Tooltip = Info.Tooltip,
            DisabledTooltip = Info.DisabledTooltip,
            TooltipTable = nil,

            Callback = Info.Callback,
            Changed = Info.Changed,
            VerifyValue = Info.VerifyValue,

            Disabled = Info.Disabled,
            Visible = Info.Visible,

            Type = "Input",
        }

        local Holder = New("Frame", {
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, 39),
            Visible = Input.Visible,
            Parent = Container,
        })

        local Label = New("TextLabel", {
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, 14),
            Text = Input.Text,
            TextSize = 14,
            TextXAlignment = Enum.TextXAlignment.Left,
            Parent = Holder,
        })

        local Box = New("TextBox", {
            AnchorPoint = Vector2.new(0, 1),
            BackgroundColor3 = "MainColor",
            ClearTextOnFocus = not Input.Disabled and Input.ClearTextOnFocus,
            PlaceholderText = Input.Placeholder,
            Position = UDim2.fromScale(0, 1),
            Size = UDim2.new(1, 0, 0, 21),
            Text = Input.Value,
            TextEditable = not Input.Disabled,
            TextScaled = true,
            TextXAlignment = Enum.TextXAlignment.Left,
            Parent = Holder,
        })

        New("UIPadding", {
            PaddingBottom = UDim.new(0, 3),
            PaddingLeft = UDim.new(0, 8),
            PaddingRight = UDim.new(0, 8),
            PaddingTop = UDim.new(0, 4),
            Parent = Box,
        })

        New("UIStroke", {
            Color = "OutlineColor",
            Parent = Box,
        })

        table.insert(
            Library.Corners,
            New("UICorner", {
                CornerRadius = UDim.new(0, Library.CornerRadius / 2),
                Parent = Box,
            })
        )

        function Input:UpdateColors()
            if Library.Unloaded then
                return
            end

            Label.TextTransparency = Input.Disabled and 0.8 or 0
            Box.TextTransparency = Input.Disabled and 0.8 or 0
        end

        function Input:OnChanged(Func)
            Input.Changed = Func
        end

        function Input:SetValue(Text)
            if not Input.AllowEmpty and Trim(Text) == "" then
                Text = Input.EmptyReset
            end

            if Info.MaxLength and #Text > Info.MaxLength then
                Text = Text:sub(1, Info.MaxLength)
            end

            if Input.Numeric then
                if #tostring(Text) > 0 and not tonumber(Text) then
                    Text = Input.Value
                end
            end

            if typeof(Info.VerifyValue) == "function" and (Text ~= Input.EmptyReset and Info.VerifyValue(Text) ~= true) then
                Text = Input.EmptyReset
            end

            Input.Value = Text
            Box.Text = Text

            if not Input.Disabled then
                Library:SafeCallback(Input.Callback, Input.Value)
                Library:SafeCallback(Input.Changed, Input.Value)
            end
        end

        function Input:SetDisabled(Disabled: boolean)
            Input.Disabled = Disabled

            if Input.TooltipTable then
                Input.TooltipTable.Disabled = Input.Disabled
            end

            Box.ClearTextOnFocus = not Input.Disabled and Input.ClearTextOnFocus
            Box.TextEditable = not Input.Disabled
            Input:UpdateColors()
        end

        function Input:SetVisible(Visible: boolean)
            Input.Visible = Visible

            Holder.Visible = Input.Visible
            Groupbox:Resize()
        end

        function Input:SetText(Text: string)
            Input.Text = Text
            Label.Text = Text
        end

        if Input.Finished then
            table.insert(Input.Connections, Box.FocusLost:Connect(function(Enter)
                if not Enter then
                    if Input.ClearTextOnBlur then
                        Box.Text = Input.Value
                    end

                    return
                end

                Input:SetValue(Box.Text)
            end))
        else
            table.insert(Input.Connections, Box:GetPropertyChangedSignal("Text"):Connect(function()
                if Box.Text == Input.Value then return end
                
                Input:SetValue(Box.Text)
            end))
        end

        if typeof(Input.Tooltip) == "string" or typeof(Input.DisabledTooltip) == "string" then
            Input.TooltipTable = Library:AddTooltip(Input.Tooltip, Input.DisabledTooltip, Box)
            Input.TooltipTable.Disabled = Input.Disabled
        end

        Groupbox:Resize()

        Input.Holder = Holder
        table.insert(Groupbox.Elements, Input)

        Input.Default = Input.Value
        if typeof(Info.VerifyValue) == "function" and (Input.Default ~= Input.EmptyReset and Info.VerifyValue(Input.Default) ~= true) then
            Input:SetValue(Input.EmptyReset)
            Input.Default = Input.EmptyReset
        end
        
        Options[Idx] = Input

        function Input:Destroy()
            Input.Destroyed = true

            if Input.Connections then
                for _, Connection in Input.Connections do
                    Connection:Disconnect()
                end
            end

            if Input.TooltipTable then 
                Input.TooltipTable:Destroy() 
            end

            if Holder then 
                Holder:Destroy() 
            end

            local ElemIdx = table.find(Groupbox.Elements, Input)
            if ElemIdx then 
                table.remove(Groupbox.Elements, ElemIdx) 
            end

            Groupbox:Resize()
            Options[Idx] = nil
        end

        return Input
    end

    function Funcs:AddSlider(Idx, Info)
        if self.Destroyed then return nil end

        Info = Library:Validate(Info, Templates.Slider)

        local Groupbox = self
        local Container = Groupbox.Container

        local Slider = {
            Connections = {},
            Destroyed = false,

            Text = Info.Text,
            Value = Info.Default,

            Min = Info.Min,
            Max = Info.Max,

            Prefix = Info.Prefix,
            Suffix = Info.Suffix,
            Compact = Info.Compact,
            Rounding = Info.Rounding,
            HideMax = Info.HideMax,

            Tooltip = Info.Tooltip,
            DisabledTooltip = Info.DisabledTooltip,
            TooltipTable = nil,

            Callback = Info.Callback,
            Changed = Info.Changed,

            Disabled = Info.Disabled,
            Visible = Info.Visible,

            AllowRightClickInput = Info.AllowRightClickInput,

            Type = "Slider",
        }

        local Holder = New("Frame", {
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, Info.Compact and 15 or 33),
            Visible = Slider.Visible,
            Parent = Container,
        })

        local SliderLabel
        if not Info.Compact then
            SliderLabel = New("TextLabel", {
                BackgroundTransparency = 1,
                Size = UDim2.new(1, 0, 0, 14),
                Text = Slider.Text,
                TextSize = 14,
                TextXAlignment = Enum.TextXAlignment.Left,
                Parent = Holder,
            })
        end

        local Bar = New("TextButton", {
            Active = not Slider.Disabled,
            AnchorPoint = Vector2.new(0, 1),
            BackgroundColor3 = "MainColor",
            Position = UDim2.fromScale(0, 1),
            Size = UDim2.new(1, 0, 0, 15),
            Text = "",
            Parent = Holder,
        })

        New("UIStroke", {
            Color = "OutlineColor",
            Parent = Bar,
        })

        local DisplayLabel = New("TextLabel", {
            BackgroundTransparency = 1,
            Size = UDim2.fromScale(1, 1),
            Text = "",
            TextSize = 14,
            ZIndex = 2,
            Parent = Bar,
        })
        New("UIStroke", {
            ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
            Color = "DarkColor",
            LineJoinMode = Enum.LineJoinMode.Miter,
            Parent = DisplayLabel,
        })

        local InputTextBox
        if Info.AllowRightClickInput then
            InputTextBox = New("TextBox", {
                BackgroundTransparency = 1,
                Size = UDim2.fromScale(1, 1),
                Text = "",
                TextSize = 14,
                ZIndex = 3,
                Visible = false,
                ClearTextOnFocus = false,
                Parent = Bar,
            })
            New("UIStroke", {
                ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
                Color = "DarkColor",
                LineJoinMode = Enum.LineJoinMode.Miter,
                Parent = InputTextBox,
            })
        end

        local Fill = New("Frame", {
            BackgroundColor3 = "AccentColor",
            Size = UDim2.fromScale(0.5, 1),
            Parent = Bar,
        })

        table.insert(
            Library.Corners,
            New("UICorner", {
                CornerRadius = UDim.new(0, Library.CornerRadius / 2),
                Parent = Bar,
            })
        )

        table.insert(
            Library.Corners,
            New("UICorner", {
                CornerRadius = UDim.new(0, Library.CornerRadius / 2),
                Parent = Fill,
            })
        )

        function Slider:UpdateColors()
            if Library.Unloaded then
                return
            end

            if SliderLabel then
                SliderLabel.TextTransparency = Slider.Disabled and 0.8 or 0
            end
            DisplayLabel.TextTransparency = Slider.Disabled and 0.8 or 0
            
            if Info.AllowRightClickInput then
                InputTextBox.TextTransparency = Slider.Disabled and 0.8 or 0
            end

            Fill.BackgroundColor3 = Slider.Disabled and Library.Scheme.OutlineColor or Library.Scheme.AccentColor
            Library.Registry[Fill].BackgroundColor3 = Slider.Disabled and "OutlineColor" or "AccentColor"
        end

        function Slider:Display()
            if Library.Unloaded then
                return
            end

            local CustomDisplayText = nil
            if Info.FormatDisplayValue then
                CustomDisplayText = Info.FormatDisplayValue(Slider, Slider.Value)
            end

            if CustomDisplayText then
                DisplayLabel.Text = tostring(CustomDisplayText)
            else
                if Info.Compact then
                    DisplayLabel.Text =
                        string.format("%s: %s%s%s", Slider.Text, Slider.Prefix, Slider.Value, Slider.Suffix)
                elseif Info.HideMax then
                    DisplayLabel.Text = string.format("%s%s%s", Slider.Prefix, Slider.Value, Slider.Suffix)
                else
                    DisplayLabel.Text = string.format(
                        "%s%s%s/%s%s%s",
                        Slider.Prefix,
                        Slider.Value,
                        Slider.Suffix,
                        Slider.Prefix,
                        Slider.Max,
                        Slider.Suffix
                    )
                end
            end

            local X = (Slider.Value - Slider.Min) / (Slider.Max - Slider.Min)
            Fill.Size = UDim2.fromScale(X, 1)
        end

        function Slider:OnChanged(Func)
            Slider.Changed = Func
        end

        function Slider:SetMax(Value)
            assert(Value > Slider.Min, "Max value cannot be less than the current min value.")

            Slider:SetValue(math.clamp(Slider.Value, Slider.Min, Value))
            Slider.Max = Value
            Slider:Display()
        end

        function Slider:SetMin(Value)
            assert(Value < Slider.Max, "Min value cannot be greater than the current max value.")

            Slider:SetValue(math.clamp(Slider.Value, Value, Slider.Max))
            Slider.Min = Value
            Slider:Display()
        end

        function Slider:SetValue(Str)
            if Slider.Disabled then
                return
            end

            local Num = tonumber(Str)
            if not Num or Num == Slider.Value then
                return
            end

            Num = math.clamp(Num, Slider.Min, Slider.Max)

            Slider.Value = Num
            Slider:Display()

            Library:SafeCallback(Slider.Callback, Slider.Value)
            Library:SafeCallback(Slider.Changed, Slider.Value)
        end

        function Slider:SetDisabled(Disabled: boolean)
            Slider.Disabled = Disabled

            if Slider.TooltipTable then
                Slider.TooltipTable.Disabled = Slider.Disabled
            end

            Bar.Active = not Slider.Disabled
            Slider:UpdateColors()
        end

        function Slider:SetVisible(Visible: boolean)
            Slider.Visible = Visible

            Holder.Visible = Slider.Visible
            Groupbox:Resize()
        end


        function Slider:SetText(Text: string)
            Slider.Text = Text
            if SliderLabel then
                SliderLabel.Text = Text
                return
            end
            Slider:Display()
        end

        function Slider:SetPrefix(Prefix: string)
            Slider.Prefix = Prefix
            Slider:Display()
        end

        function Slider:SetSuffix(Suffix: string)
            Slider.Suffix = Suffix
            Slider:Display()
        end

        if Info.AllowRightClickInput then
            local LastValidText = ""
            table.insert(Slider.Connections, InputTextBox:GetPropertyChangedSignal("Text"):Connect(function()
                local Text = InputTextBox.Text
                local AsNum = tonumber(Text)

                if #tostring(Text) > 0 and not AsNum and Text ~= "-" then
                    InputTextBox.Text = LastValidText
                else
                    if Slider.Rounding == 0 and Text:find("%.") then
                        InputTextBox.Text = LastValidText
                        return
                    end

                    local DecimalPos = Text:find("%.")
                    if DecimalPos and Slider.Rounding > 0 then
                        local Decimals = #Text - DecimalPos
                        if Decimals > Slider.Rounding then
                            InputTextBox.Text = LastValidText
                            return
                        end
                    end

                    LastValidText = Text

                    if AsNum then
                        if AsNum > Slider.Max then
                            InputTextBox.Text = tostring(Slider.Max)
                        elseif AsNum < Slider.Min then
                            InputTextBox.Text = tostring(Slider.Min)
                        end
                    end
                end
            end))

            table.insert(Slider.Connections, InputTextBox.FocusLost:Connect(function()
                InputTextBox.Visible = false
                DisplayLabel.Visible = true

                local Num = tonumber(InputTextBox.Text)
                if not Num then
                    return
                end

                Num = Round(Num, Slider.Rounding)
                Slider:SetValue(Num)
            end))
        end

        local LastTap = 0
        table.insert(Slider.Connections, Bar.InputBegan:Connect(function(Input: InputObject)
            local ValidInput = IsClickInput(Input) or Input.UserInputType == Enum.UserInputType.MouseButton2
            if not ValidInput or Slider.Disabled then
                return
            end

            if Info.AllowRightClickInput then
                local IsRightClick = Input.UserInputType == Enum.UserInputType.MouseButton2
                local IsDoubleTap = false

                if Library.IsMobile and Input.UserInputType == Enum.UserInputType.Touch then
                    if tick() - LastTap < 0.3 then
                        IsDoubleTap = true
                    end
                    
                    LastTap = tick()
                end

                if IsRightClick or IsDoubleTap then
                    InputTextBox.Text = tostring(Slider.Value)
                    InputTextBox.Visible = true
                    DisplayLabel.Visible = false

                    task.spawn(InputTextBox.CaptureFocus, InputTextBox)
                    return
                end
            end

            if not IsClickInput(Input) then
                return
            end

            if Library.ActiveTab then
                for _, Side in Library.ActiveTab.Sides do
                    Side.ScrollingEnabled = false
                end
            end

            if Library.ActiveLoading and Library.ActiveLoading.Sidebar then
                Library.ActiveLoading.Sidebar.Container.ScrollingEnabled = false
            end

            while IsDragInput(Input) and not Slider.Destroyed do
                local Location = Mouse.X
                local Scale = math.clamp((Location - Bar.AbsolutePosition.X) / Bar.AbsoluteSize.X, 0, 1)

                local OldValue = Slider.Value
                Slider.Value = Round(Slider.Min + ((Slider.Max - Slider.Min) * Scale), Slider.Rounding)

                Slider:Display()
                if Slider.Value ~= OldValue then
                    Library:SafeCallback(Slider.Callback, Slider.Value)
                    Library:SafeCallback(Slider.Changed, Slider.Value)
                end

                RunService.RenderStepped:Wait()
            end

            if Library.ActiveTab then
                for _, Side in Library.ActiveTab.Sides do
                    Side.ScrollingEnabled = true
                end
            end

            if Library.ActiveLoading and Library.ActiveLoading.Sidebar then
                Library.ActiveLoading.Sidebar.Container.ScrollingEnabled = true
            end
        end))

        if typeof(Slider.Tooltip) == "string" or typeof(Slider.DisabledTooltip) == "string" then
            Slider.TooltipTable = Library:AddTooltip(Slider.Tooltip, Slider.DisabledTooltip, Bar)
            Slider.TooltipTable.Disabled = Slider.Disabled
        end

        Slider:UpdateColors()
        Slider:Display()
        Groupbox:Resize()

        Slider.Holder = Holder
        table.insert(Groupbox.Elements, Slider)

        Slider.Default = Slider.Value

        Options[Idx] = Slider

        function Slider:Destroy()
            Slider.Destroyed = true

            if Slider.Connections then
                for _, Connection in Slider.Connections do
                    Connection:Disconnect()
                end
            end

            if Slider.TooltipTable then 
                Slider.TooltipTable:Destroy() 
            end

            if Holder then 
                Holder:Destroy() 
            end

            local ElemIdx = table.find(Groupbox.Elements, Slider)
            if ElemIdx then 
                table.remove(Groupbox.Elements, ElemIdx) 
            end

            Groupbox:Resize()
            Options[Idx] = nil
        end

        return Slider
    end

    function Funcs:AddDropdown(Idx, Info)
        if self.Destroyed then return nil end

        Info = Library:Validate(Info, Templates.Dropdown)

        local Groupbox = self
        local Container = Groupbox.Container

        if Info.SpecialType == "Player" then
            Info.Values = GetPlayers(Info.ExcludeLocalPlayer)
            Info.AllowNull = true
        elseif Info.SpecialType == "Team" then
            Info.Values = GetTeams()
            Info.AllowNull = true
        end

        local Dropdown = {
            Connections = {},
            Destroyed = false,

            Text = typeof(Info.Text) == "string" and Info.Text or nil,

            Value = Info.Multi and {} or nil,
            Values = Info.Values,
            DisabledValues = Info.DisabledValues,
            ValueImages = Info.ValueImages,

            Multi = Info.Multi,

            SpecialType = Info.SpecialType,
            ExcludeLocalPlayer = Info.ExcludeLocalPlayer,
            EnablePlayerImages = Info.EnablePlayerImages,

            Tooltip = Info.Tooltip,
            DisabledTooltip = Info.DisabledTooltip,
            TooltipTable = nil,

            Callback = Info.Callback,
            Changed = Info.Changed,

            Disabled = Info.Disabled,
            Visible = Info.Visible,

            Type = "Dropdown",
        }

        local Holder = New("Frame", {
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, Dropdown.Text and 39 or 21),
            Visible = Dropdown.Visible,
            Parent = Container,
        })

        local Label = New("TextLabel", {
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, 14),
            Text = Dropdown.Text,
            TextSize = 14,
            TextXAlignment = Enum.TextXAlignment.Left,
            Visible = not not Info.Text,
            ZIndex = 3,
            Parent = Holder,
        })

        local DisplayContainer = New("TextButton", {
            AnchorPoint = Vector2.new(0, 1),
            BackgroundColor3 = "MainColor",
            Position = UDim2.fromScale(0, 1),
            Size = UDim2.new(0.99999, 0, 0, 21),
            Text = "",
            TextTransparency = 1,
            ZIndex = 2,
            Parent = Holder,
        })

        New("UIPadding", {
            PaddingLeft = UDim.new(0, 8),
            PaddingRight = UDim.new(0, 4),
            Parent = DisplayContainer,
        })

        New("UIStroke", {
            Color = "OutlineColor",
            Parent = DisplayContainer,
        })

        local DropdownCorner = New("UICorner", {
            TopLeftRadius = UDim.new(0, Library.CornerRadius / 2),
            TopRightRadius = UDim.new(0, Library.CornerRadius / 2),
            BottomRightRadius = UDim.new(0, Library.CornerRadius / 2),
            BottomLeftRadius = UDim.new(0, Library.CornerRadius / 2),
            Parent = DisplayContainer,
        }); table.insert(Library.SpecificCorners, DropdownCorner)

        local DisplayImage = New("ImageLabel", {
            BackgroundTransparency = 1,
            Position = UDim2.fromOffset(-4, 3),
            Size = UDim2.fromOffset(16, 16),
            Image = "",
            ImageTransparency = 1,
            ZIndex = 2,
            Parent = DisplayContainer,
        })

        local DisplayButton = New("TextButton", {
            Active = not Dropdown.Disabled,
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, 21),
            Text = "---",
            TextSize = 14,
            TextXAlignment = Enum.TextXAlignment.Left,
            ZIndex = 2,
            Parent = DisplayContainer,
        })

        local ArrowImage = New("ImageLabel", {
            AnchorPoint = Vector2.new(1, 0.5),
            Image = ArrowIcon and ArrowIcon.Url or "",
            ImageColor3 = "FontColor",
            ImageRectOffset = ArrowIcon and ArrowIcon.ImageRectOffset or Vector2.zero,
            ImageRectSize = ArrowIcon and ArrowIcon.ImageRectSize or Vector2.zero,
            ImageTransparency = 0.5,
            Position = UDim2.fromScale(1, 0.5),
            Size = UDim2.fromOffset(16, 16),
            Parent = DisplayContainer,
        })

        local SearchBox
        if Info.Searchable then
            SearchBox = New("TextBox", {
                BackgroundTransparency = 1,
                PlaceholderText = "Search...",
                Position = UDim2.fromOffset(-8, 0),
                Size = UDim2.new(1, -12, 1, 0),
                TextSize = 14,
                TextXAlignment = Enum.TextXAlignment.Left,
                Visible = false,
                Parent = DisplayButton,
            })
            New("UIPadding", {
                PaddingLeft = UDim.new(0, 8),
                Parent = SearchBox,
            })
        end

        local GetValueImage = function(Value)
            if not Value then
                return nil
            end

            local ValueImage = nil
            if Dropdown.SpecialType == "Player" and Dropdown.EnablePlayerImages == true then
                if typeof(Value) == "Instance" and Value:IsA("Player") then
                    ValueImage = { Url = string.format("rbxthumb://type=AvatarHeadShot&id=%s&w=48&h=48", tostring(Value.UserId)) }
                end
            else
                if Info.ValueImages and Info.ValueImages[Value] then
                    ValueImage = Library:GetCustomIcon(Info.ValueImages[Value])
                end
            end

            return ValueImage
        end

        local MenuTable = Library:AddContextMenu(
            DisplayContainer,
            function()
                return UDim2.fromOffset((DisplayContainer.AbsoluteSize.X / Library.DPIScale), 0)
            end,
            function()
                return { 0.5, DisplayContainer.AbsoluteSize.Y + 1.5 }
            end,
            2,
            function(Active: boolean)
                DisplayButton.TextTransparency = (Active and SearchBox) and 1 or 0

                ArrowImage.ImageTransparency = Active and 0 or 0.5
                ArrowImage.Rotation = Active and 180 or 0

                if SearchBox then
                    SearchBox.Text = ""
                    SearchBox.Visible = Active
                end

                DropdownCorner.BottomRightRadius = Active and UDim.new(0, 0) or UDim.new(0, Library.CornerRadius / 2)
                DropdownCorner.BottomLeftRadius = Active and UDim.new(0, 0) or UDim.new(0, Library.CornerRadius / 2)
            end,
            false,
            "bottom"
        )
        Dropdown.Menu = MenuTable

        function Dropdown:RecalculateListSize(Count)
            local Y = math.clamp((Count or GetTableSize(Dropdown.Values)) * 21, 0, Info.MaxVisibleDropdownItems * 21)

            MenuTable:SetSize(function()
                return UDim2.fromOffset((DisplayContainer.AbsoluteSize.X / Library.DPIScale), Y)
            end)
        end

        function Dropdown:UpdateColors()
            if Library.Unloaded then
                return
            end

            Label.TextTransparency = Dropdown.Disabled and 0.8 or 0
            DisplayButton.TextTransparency = Dropdown.Disabled and 0.8 or 0
            DisplayImage.ImageTransparency = Dropdown.Disabled and 0.8 or 0
            ArrowImage.ImageTransparency = Dropdown.Disabled and 0.8 or MenuTable.Active and 0 or 0.5
        end

        function Dropdown:Display()
            if Library.Unloaded then
                return
            end

            local Str = ""
            local ValueImage = nil

            if Info.Multi then
                for _, Value in Dropdown.Values do
                    if Dropdown.Value[Value] then
                        if not ValueImage then
                            ValueImage = GetValueImage(Value)
                        end

                        Str = Str
                            .. (Info.FormatDisplayValue and tostring(Info.FormatDisplayValue(Value)) or tostring(Value))
                            .. ", "
                    end
                end

                Str = Str:sub(1, #Str - 2)
            else
                ValueImage = GetValueImage(Dropdown.Value)
                Str = Dropdown.Value and tostring(Dropdown.Value) or ""

                if Str ~= "" and Info.FormatDisplayValue then
                    Str = tostring(Info.FormatDisplayValue(Str))
                end
            end

            if #Str > 25 then
                Str = Str:sub(1, 22) .. "..."
            end

            DisplayButton.Text = (Str == "" and "---" or Str)
            
            if ValueImage then
                DisplayImage.Image = ValueImage.Url
                DisplayImage.ImageRectOffset = ValueImage.ImageRectOffset or Vector2.zero
                DisplayImage.ImageRectSize = ValueImage.ImageRectSize or Vector2.zero
                DisplayImage.ImageTransparency = 0
            else
                DisplayImage.Image = ""
                DisplayImage.ImageTransparency = 1
            end

            DisplayButton.Size = ValueImage and UDim2.new(1, -8, 0, 21) or UDim2.new(1, 0, 0, 21)
            DisplayButton.Position = ValueImage and UDim2.fromOffset(14, 0) or UDim2.fromOffset(0, 0)
        end

        function Dropdown:OnChanged(Func)
            Dropdown.Changed = Func
        end

        function Dropdown:GetActiveValues(ReturnCount)
            local Table = {}

            if Info.Multi then
                for Value, _ in Dropdown.Value do
                    table.insert(Table, Value)
                end
            else
                if Dropdown.Value then
                    table.insert(Table, Dropdown.Value)
                end
            end

            return ReturnCount == true and GetTableSize(Table) or Table
        end

        local Buttons = {}
        function Dropdown:BuildDropdownList()
            local Values = Dropdown.Values
            local DisabledValues = Dropdown.DisabledValues

            for Button, _ in Buttons do
                Button.Parent:Destroy()
            end
            table.clear(Buttons)
            
            local Count = 0
            local ProcessedCount = 0
            local TotalLen = GetTableSize(Values) + GetTableSize(DisabledValues)

            for _, Value in Values do
                ProcessedCount += 1

                local FormattedValue = tostring(Info.FormatListValue and Info.FormatListValue(Value) or Value)
                if SearchBox and not FormattedValue:lower():match(SearchBox.Text:lower()) then
                    continue
                end

                Count += 1

                local IsDisabled = table.find(DisabledValues, Value)
                local Table = {}
                local ValueImage = GetValueImage(Value)

                local Container = New("Frame", {
                    BackgroundColor3 = "MainColor",
                    BackgroundTransparency = 1,
                    LayoutOrder = IsDisabled and 1 or 0,
                    Size = UDim2.new(1, 0, 0, 21),
                    Parent = MenuTable.Menu,
                })

                if ProcessedCount == TotalLen then
                    local Corner = New("UICorner", {
                        TopLeftRadius = UDim.new(0, 0),
                        TopRightRadius = UDim.new(0, 0),
                        BottomRightRadius = UDim.new(0, Library.CornerRadius / 2),
                        BottomLeftRadius = UDim.new(0, Library.CornerRadius / 2),
                        Parent = Container,
                    }); table.insert(Library.SpecificCorners, Corner)
                end

                local Image = ValueImage and New("ImageLabel", {
                    BackgroundTransparency = 1,
                    Image = ValueImage.Url,
                    ImageRectOffset = ValueImage.ImageRectOffset,
                    ImageRectSize = ValueImage.ImageRectSize,
                    ImageTransparency = 0.5,
                    Size = UDim2.fromOffset(16, 16),
                    Position = UDim2.fromOffset(4, 3),
                    Parent = Container,
                })

                local Button = New("TextButton", {
                    BackgroundTransparency = 1,
                    Size = ValueImage and UDim2.new(1, -18, 0, 21) or UDim2.new(1, 0, 0, 21),
                    Position = ValueImage and UDim2.fromOffset(18, 0) or UDim2.fromOffset(0, 0),
                    Text = FormattedValue,
                    TextSize = 14,
                    TextTransparency = 0.5,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    Parent = Container,
                })
                New("UIPadding", {
                    PaddingLeft = UDim.new(0, 7),
                    PaddingRight = UDim.new(0, 7),
                    Parent = Button,
                })

                local Selected
                if Info.Multi then
                    Selected = Dropdown.Value[Value]
                else
                    Selected = Dropdown.Value == Value
                end

                function Table:UpdateButton()
                    if Info.Multi then
                        Selected = Dropdown.Value[Value]
                    else
                        Selected = Dropdown.Value == Value
                    end

                    Container.BackgroundTransparency = Selected and 0 or 1
                    Button.TextTransparency = IsDisabled and 0.8 or Selected and 0 or 0.5

                    if Image then
                        Image.ImageTransparency = IsDisabled and 0.8 or Selected and 0 or 0.5
                    end
                end

                if not IsDisabled then
                    Button.MouseButton1Click:Connect(function()
                        local Try = not Selected

                        if not (Dropdown:GetActiveValues(true) == 1 and not Try and not Info.AllowNull) then
                            Selected = Try
                            if Info.Multi then
                                Dropdown.Value[Value] = Selected and true or nil
                            else
                                Dropdown.Value = Selected and Value or nil
                            end

                            for _, OtherButton in Buttons do
                                OtherButton:UpdateButton()
                            end
                        end

                        Table:UpdateButton()
                        Dropdown:Display()

                        Library:UpdateDependencyBoxes()
                        Library:SafeCallback(Dropdown.Callback, Dropdown.Value)
                        Library:SafeCallback(Dropdown.Changed, Dropdown.Value)
                    end)
                end

                Table:UpdateButton()
                Dropdown:Display()

                Buttons[Button] = Table
            end

            Dropdown:RecalculateListSize(Count)
        end

        function Dropdown:SetValue(Value)
            if Info.Multi then
                local Table = {}
				
                for Val, Active in Value or {} do
                    if typeof(Active) ~= "boolean" then
                        Table[Active] = true
                    elseif Active and table.find(Dropdown.Values, Val) then
                        Table[Val] = true
                    end
                end

                Dropdown.Value = Table
            else
                if table.find(Dropdown.Values, Value) then
                    Dropdown.Value = Value
                elseif not Value then
                    Dropdown.Value = nil
                end
            end

            Dropdown:Display()
            for _, Button in Buttons do
                Button:UpdateButton()
            end

            if not Dropdown.Disabled then
                Library:UpdateDependencyBoxes()
                Library:SafeCallback(Dropdown.Callback, Dropdown.Value)
                Library:SafeCallback(Dropdown.Changed, Dropdown.Value)
            end
        end

        function Dropdown:SetValues(Values)
            Dropdown.Values = Values
            Dropdown:BuildDropdownList()
        end

        function Dropdown:AddValues(Values)
            if typeof(Values) == "table" then
                for _, val in Values do
                    table.insert(Dropdown.Values, val)
                end
            elseif typeof(Values) == "string" then
                table.insert(Dropdown.Values, Values)
            else
                return
            end

            Dropdown:BuildDropdownList()
        end

        function Dropdown:SetDisabledValues(DisabledValues)
            Dropdown.DisabledValues = DisabledValues
            Dropdown:BuildDropdownList()
        end

        function Dropdown:AddDisabledValues(DisabledValues)
            if typeof(DisabledValues) == "table" then
                for _, val in DisabledValues do
                    table.insert(Dropdown.DisabledValues, val)
                end
            elseif typeof(DisabledValues) == "string" then
                table.insert(Dropdown.DisabledValues, DisabledValues)
            else
                return
            end

            Dropdown:BuildDropdownList()
        end

        function Dropdown:SetValueImages(ValueImages)
            if typeof(ValueImages) ~= "table" then
                return
            end
            
            Dropdown.ValueImages = ValueImages
            Dropdown:BuildDropdownList()
        end

        function Dropdown:AddValueImages(ValueImages)
            if typeof(ValueImages) ~= "table" then
                return
            end
            
            for key, val in ValueImages do
                Dropdown.ValueImages[key] = val
            end
            
            Dropdown:BuildDropdownList()
        end

        function Dropdown:SetDisabled(Disabled: boolean)
            Dropdown.Disabled = Disabled

            if Dropdown.TooltipTable then
                Dropdown.TooltipTable.Disabled = Dropdown.Disabled
            end

            MenuTable:Close()
            DisplayButton.Active = not Dropdown.Disabled
            Dropdown:UpdateColors()
        end

        function Dropdown:SetVisible(Visible: boolean)
            Dropdown.Visible = Visible

            Holder.Visible = Dropdown.Visible
            Groupbox:Resize()
        end

        function Dropdown:SetText(Text: string)
            Dropdown.Text = Text
            Holder.Size = UDim2.new(1, 0, 0, Text and 39 or 21)

            Label.Text = Text and Text or ""
            Label.Visible = not not Text
        end

        local ToggleDropdown = function()
            if Dropdown.Disabled then
                return
            end

            MenuTable:Toggle()
        end

        table.insert(Dropdown.Connections, DisplayContainer.MouseButton1Click:Connect(ToggleDropdown))
        table.insert(Dropdown.Connections, DisplayButton.MouseButton1Click:Connect(ToggleDropdown))

        if SearchBox then
            table.insert(Dropdown.Connections, SearchBox:GetPropertyChangedSignal("Text"):Connect(Dropdown.BuildDropdownList))
        end

        local Defaults = {}
        if typeof(Info.Default) == "string" then
            local Index = table.find(Dropdown.Values, Info.Default)
            if Index then
                table.insert(Defaults, Index)
            end
        elseif typeof(Info.Default) == "table" then
            for _, Value in next, Info.Default do
                local Index = table.find(Dropdown.Values, Value)
                if Index then
                    table.insert(Defaults, Index)
                end
            end
        elseif Dropdown.Values[Info.Default] ~= nil then
            table.insert(Defaults, Info.Default)
        end

        if next(Defaults) then
            for i = 1, #Defaults do
                local Index = Defaults[i]
                if Info.Multi then
                    Dropdown.Value[Dropdown.Values[Index]] = true
                else
                    Dropdown.Value = Dropdown.Values[Index]
                end

                if not Info.Multi then
                    break
                end
            end
        end

        if typeof(Dropdown.Tooltip) == "string" or typeof(Dropdown.DisabledTooltip) == "string" then
            Dropdown.TooltipTable = Library:AddTooltip(Dropdown.Tooltip, Dropdown.DisabledTooltip, DisplayContainer)
            Dropdown.TooltipTable.Disabled = Dropdown.Disabled
        end

        Dropdown:UpdateColors()
        Dropdown:Display()
        Dropdown:BuildDropdownList()
        Groupbox:Resize()

        Dropdown.Holder = Holder
        table.insert(Groupbox.Elements, Dropdown)

        Dropdown.Default = Defaults
        Dropdown.DefaultValues = Dropdown.Values

        Options[Idx] = Dropdown

        function Dropdown:Destroy()
            Dropdown.Destroyed = true

            if Dropdown.Connections then
                for _, Connection in Dropdown.Connections do
                    Connection:Disconnect()
                end
            end

            if Dropdown.TooltipTable then 
                Dropdown.TooltipTable:Destroy() 
            end

            if MenuTable then 
                MenuTable:Destroy() 
            end

            if Holder then 
                Holder:Destroy() 
            end

            local ElemIdx = table.find(Groupbox.Elements, Dropdown)
            if ElemIdx then 
                table.remove(Groupbox.Elements, ElemIdx) 
            end

            Groupbox:Resize()
            Options[Idx] = nil
        end

        return Dropdown
    end

    function Funcs:AddViewport(Idx, Info)
        if self.Destroyed then return nil end

        Info = Library:Validate(Info, Templates.Viewport)

        local Groupbox = self
        local Container = Groupbox.Container

        local Dragging, Pinching = false, false
        local LastMousePos, LastPinchDist = nil, 0

        local ViewportObject = Info.Object
        if Info.Clone and typeof(Info.Object) == "Instance" then
            if Info.Object.Archivable then
                ViewportObject = ViewportObject:Clone()
            else
                Info.Object.Archivable = true
                ViewportObject = ViewportObject:Clone()
                Info.Object.Archivable = false
            end
        end

        local Viewport = {
            Connections = {},
            Destroyed = false,

            Object = ViewportObject :: PVInstance,
            Camera = if not Info.Camera then Instance.new("Camera") else Info.Camera,
            Interactive = Info.Interactive,
            AutoFocus = Info.AutoFocus,
            Visible = Info.Visible,
            Type = "Viewport",
        }

        assert(
            typeof(Viewport.Object) == "Instance" and (Viewport.Object:IsA("BasePart") or Viewport.Object:IsA("Model")),
            "Instance must be a BasePart or Model."
        )

        assert(
            typeof(Viewport.Camera) == "Instance" and Viewport.Camera:IsA("Camera"),
            "Camera must be a valid Camera instance."
        )

        local function GetModelSize(model)
            if model:IsA("BasePart") then
                return model.Size
            end

            return select(2, model:GetBoundingBox())
        end

        local function FocusCamera()
            local ModelSize = GetModelSize(Viewport.Object)
            local MaxExtent = math.max(ModelSize.X, ModelSize.Y, ModelSize.Z)
            local CameraDistance = MaxExtent * 2
            local ModelPosition = (Viewport.Object :: PVInstance):GetPivot().Position

            Viewport.Camera.CFrame = CFrame.new(ModelPosition + Vector3.new(0, MaxExtent / 2, CameraDistance), ModelPosition)
        end

        local Holder = New("Frame", {
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, Info.Height),
            Visible = Viewport.Visible,
            Parent = Container,
        })

        local Box = New("Frame", {
            AnchorPoint = Vector2.new(0, 1),
            BackgroundColor3 = "MainColor",
            BorderColor3 = "OutlineColor",
            BorderSizePixel = 1,
            Position = UDim2.fromScale(0, 1),
            Size = UDim2.fromScale(1, 1),
            Parent = Holder,
        })

        New("UIPadding", {
            PaddingBottom = UDim.new(0, 3),
            PaddingLeft = UDim.new(0, 8),
            PaddingRight = UDim.new(0, 8),
            PaddingTop = UDim.new(0, 4),
            Parent = Box,
        })

        local ViewportFrame = New("ViewportFrame", {
            BackgroundTransparency = 1,
            Size = UDim2.fromScale(1, 1),
            Parent = Box,
            CurrentCamera = Viewport.Camera,
            Active = Viewport.Interactive,
        })

        table.insert(Viewport.Connections, ViewportFrame.MouseEnter:Connect(function()
            if not Viewport.Interactive then
                return
            end

            for _, Side in Groupbox.Tab.Sides do
                Side.ScrollingEnabled = false
            end
        end))

        table.insert(Viewport.Connections, ViewportFrame.MouseLeave:Connect(function()
            if not Viewport.Interactive then
                return
            end

            for _, Side in Groupbox.Tab.Sides do
                Side.ScrollingEnabled = true
            end
        end))

        table.insert(Viewport.Connections, ViewportFrame.InputBegan:Connect(function(input)
            if not Viewport.Interactive then
                return
            end

            if input.UserInputType == Enum.UserInputType.MouseButton2 then
                Dragging = true
                LastMousePos = input.Position
            elseif input.UserInputType == Enum.UserInputType.Touch and not Pinching then
                Dragging = true
                LastMousePos = input.Position
            end
        end))

        table.insert(Viewport.Connections, UserInputService.InputEnded:Connect(function(input)
            if Library.Unloaded then
                return
            end

            if not Viewport.Interactive then
                return
            end

            if input.UserInputType == Enum.UserInputType.MouseButton2 then
                Dragging = false
            elseif input.UserInputType == Enum.UserInputType.Touch then
                Dragging = false
            end
        end))

        table.insert(Viewport.Connections, UserInputService.InputChanged:Connect(function(input)
            if Library.Unloaded then
                return
            end

            if not Viewport.Interactive or not Dragging or Pinching then
                return
            end

            if
                input.UserInputType == Enum.UserInputType.MouseMovement
                or input.UserInputType == Enum.UserInputType.Touch
            then
                local MouseDelta = input.Position - LastMousePos
                LastMousePos = input.Position

                local Position = (Viewport.Object :: PVInstance):GetPivot().Position
                local Camera = Viewport.Camera

                local RotationY = CFrame.fromAxisAngle(Vector3.new(0, 1, 0), -MouseDelta.X * 0.01)
                Camera.CFrame = CFrame.new(Position) * RotationY * CFrame.new(-Position) * Camera.CFrame

                local RotationX = CFrame.fromAxisAngle(Camera.CFrame.RightVector, -MouseDelta.Y * 0.01)
                local PitchedCFrame = CFrame.new(Position) * RotationX * CFrame.new(-Position) * Camera.CFrame

                if PitchedCFrame.UpVector.Y > 0.1 then
                    Camera.CFrame = PitchedCFrame
                end
            end
        end))

        table.insert(Viewport.Connections, ViewportFrame.InputChanged:Connect(function(input)
            if not Viewport.Interactive then
                return
            end

            if input.UserInputType == Enum.UserInputType.MouseWheel then
                local ZoomAmount = input.Position.Z * 2
                Viewport.Camera.CFrame += Viewport.Camera.CFrame.LookVector * ZoomAmount
            end
        end))

        table.insert(Viewport.Connections, UserInputService.TouchPinch:Connect(function(touchPositions, scale, velocity, state)
            if Library.Unloaded then
                return
            end

            if not Viewport.Interactive or not Library:MouseIsOverFrame(ViewportFrame, touchPositions[1]) then
                return
            end

            if state == Enum.UserInputState.Begin then
                Pinching = true
                Dragging = false
                LastPinchDist = (touchPositions[1] - touchPositions[2]).Magnitude
            elseif state == Enum.UserInputState.Change then
                local currentDist = (touchPositions[1] - touchPositions[2]).Magnitude
                local delta = (currentDist - LastPinchDist) * 0.1
                LastPinchDist = currentDist
                Viewport.Camera.CFrame += Viewport.Camera.CFrame.LookVector * delta
            elseif state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel then
                Pinching = false
            end
        end))

        ;(Viewport.Object :: PVInstance).Parent = ViewportFrame
        if Viewport.AutoFocus then
            FocusCamera()
        end

        function Viewport:SetObject(Object: Instance, Clone: boolean?)
            assert(Object, "Object cannot be nil.")

            if Clone then
                Object = Object:Clone()
            end

            if Viewport.Object then
                Viewport.Object:Destroy()
            end

            Viewport.Object = Object
            ;(Viewport.Object :: PVInstance).Parent = ViewportFrame

            Groupbox:Resize()
        end

        function Viewport:SetHeight(Height: number)
            assert(Height > 0, "Height must be greater than 0.")

            Holder.Size = UDim2.new(1, 0, 0, Height)
            Groupbox:Resize()
        end

        function Viewport:Focus()
            if not Viewport.Object then
                return
            end

            FocusCamera()
        end

        function Viewport:SetCamera(Camera: Instance)
            assert(
                Camera and typeof(Camera) == "Instance" and Camera:IsA("Camera"),
                "Camera must be a valid Camera instance."
            )

            Viewport.Camera = Camera
            ViewportFrame.CurrentCamera = Camera
        end

        function Viewport:SetInteractive(Interactive: boolean)
            Viewport.Interactive = Interactive
            ViewportFrame.Active = Interactive
        end

        function Viewport:SetVisible(Visible: boolean)
            Viewport.Visible = Visible

            Holder.Visible = Viewport.Visible
            Groupbox:Resize()
        end

        Groupbox:Resize()

        Viewport.Holder = Holder
        table.insert(Groupbox.Elements, Viewport)

        Options[Idx] = Viewport

        function Viewport:Destroy()
            Viewport.Destroyed = true

            if Viewport.Connections then
                for _, Connection in Viewport.Connections do
                    Connection:Disconnect()
                end
            end

            if Holder then 
                Holder:Destroy() 
            end

            local ElemIdx = table.find(Groupbox.Elements, Viewport)
            if ElemIdx then 
                table.remove(Groupbox.Elements, ElemIdx) 
            end

            Groupbox:Resize()
            Options[Idx] = nil
        end

        return Viewport
    end

    function Funcs:AddImage(Idx, Info)
        if self.Destroyed then return nil end

        Info = Library:Validate(Info, Templates.Image)

        local Groupbox = self
        local Container = Groupbox.Container

        local Image = {
            Connections = {},
            Destroyed = false,

            Image = Info.Image,
            Color = Info.Color,
            RectOffset = Info.RectOffset,
            RectSize = Info.RectSize,
            Height = Info.Height,
            ScaleType = Info.ScaleType,
            Transparency = Info.Transparency,
            BackgroundTransparency = Info.BackgroundTransparency,

            Visible = Info.Visible,
            Type = "Image",
        }

        local Holder = New("Frame", {
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, Info.Height),
            Visible = Image.Visible,
            Parent = Container,
        })

        local Box = New("Frame", {
            AnchorPoint = Vector2.new(0, 1),
            BackgroundColor3 = "MainColor",
            BorderColor3 = "OutlineColor",
            BorderSizePixel = 1,
            BackgroundTransparency = Image.BackgroundTransparency,
            Position = UDim2.fromScale(0, 1),
            Size = UDim2.fromScale(1, 1),
            Parent = Holder,
        })

        New("UIPadding", {
            PaddingBottom = UDim.new(0, 3),
            PaddingLeft = UDim.new(0, 8),
            PaddingRight = UDim.new(0, 8),
            PaddingTop = UDim.new(0, 4),
            Parent = Box,
        })

        local ImageProperties = {
            BackgroundTransparency = 1,
            Size = UDim2.fromScale(1, 1),
            Image = Image.Image,
            ImageTransparency = Image.Transparency,
            ImageColor3 = Image.Color,
            ImageRectOffset = Image.RectOffset,
            ImageRectSize = Image.RectSize,
            ScaleType = Image.ScaleType,
            Parent = Box,
        }

        local Icon = Library:GetCustomIcon(ImageProperties.Image)
        assert(Icon, "Image must be a valid Roblox asset or a valid URL or a valid lucide icon.")

        ImageProperties.Image = Icon.Url
        ImageProperties.ImageRectOffset = Icon.ImageRectOffset
        ImageProperties.ImageRectSize = Icon.ImageRectSize

        local ImageLabel = New("ImageLabel", ImageProperties)

        function Image:SetHeight(Height: number)
            assert(Height > 0, "Height must be greater than 0.")

            Image.Height = Height
            Holder.Size = UDim2.new(1, 0, 0, Height)
            Groupbox:Resize()
        end

        function Image:SetImage(NewImage: string)
            assert(typeof(NewImage) == "string", "Image must be a string.")

            local Icon = Library:GetCustomIcon(NewImage)
            assert(Icon, "Image must be a valid Roblox asset or a valid URL or a valid lucide icon.")

            NewImage = Icon.Url
            Image.RectOffset = Icon.ImageRectOffset
            Image.RectSize = Icon.ImageRectSize

            ImageLabel.Image = NewImage
            Image.Image = NewImage
        end

        function Image:SetColor(Color: Color3)
            assert(typeof(Color) == "Color3", "Color must be a Color3 value.")

            ImageLabel.ImageColor3 = Color
            Image.Color = Color
        end

        function Image:SetRectOffset(RectOffset: Vector2)
            assert(typeof(RectOffset) == "Vector2", "RectOffset must be a Vector2 value.")

            ImageLabel.ImageRectOffset = RectOffset
            Image.RectOffset = RectOffset
        end

        function Image:SetRectSize(RectSize: Vector2)
            assert(typeof(RectSize) == "Vector2", "RectSize must be a Vector2 value.")

            ImageLabel.ImageRectSize = RectSize
            Image.RectSize = RectSize
        end

        function Image:SetScaleType(ScaleType: Enum.ScaleType)
            assert(
                typeof(ScaleType) == "EnumItem" and ScaleType:IsA("ScaleType"),
                "ScaleType must be a valid Enum.ScaleType."
            )

            ImageLabel.ScaleType = ScaleType
            Image.ScaleType = ScaleType
        end

        function Image:SetTransparency(Transparency: number)
            assert(typeof(Transparency) == "number", "Transparency must be a number between 0 and 1.")
            assert(Transparency >= 0 and Transparency <= 1, "Transparency must be between 0 and 1.")

            ImageLabel.ImageTransparency = Transparency
            Image.Transparency = Transparency
        end

        function Image:SetVisible(Visible: boolean)
            Image.Visible = Visible

            Holder.Visible = Image.Visible
            Groupbox:Resize()
        end

        Groupbox:Resize()

        Image.Holder = Holder
        table.insert(Groupbox.Elements, Image)

        Options[Idx] = Image

        function Image:Destroy()
            Image.Destroyed = true

            if Holder then 
                Holder:Destroy() 
            end

            local ElemIdx = table.find(Groupbox.Elements, Image)
            if ElemIdx then 
                table.remove(Groupbox.Elements, ElemIdx) 
            end

            Groupbox:Resize()
            Options[Idx] = nil
        end

        return Image
    end

    function Funcs:AddVideo(Idx, Info)
        if self.Destroyed then return nil end

        Info = Library:Validate(Info, Templates.Video)

        local Groupbox = self
        local Container = Groupbox.Container

        local Video = {
            Connections = {},
            Destroyed = false,

            Video = Info.Video,
            Looped = Info.Looped,
            Playing = Info.Playing,
            Volume = Info.Volume,
            Height = Info.Height,
            Visible = Info.Visible,

            Type = "Video",
        }

        local Holder = New("Frame", {
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, Info.Height),
            Visible = Video.Visible,
            Parent = Container,
        })

        local Box = New("Frame", {
            AnchorPoint = Vector2.new(0, 1),
            BackgroundColor3 = "MainColor",
            BorderColor3 = "OutlineColor",
            BorderSizePixel = 1,
            Position = UDim2.fromScale(0, 1),
            Size = UDim2.fromScale(1, 1),
            Parent = Holder,
        })

        New("UIPadding", {
            PaddingBottom = UDim.new(0, 3),
            PaddingLeft = UDim.new(0, 8),
            PaddingRight = UDim.new(0, 8),
            PaddingTop = UDim.new(0, 4),
            Parent = Box,
        })

        local VideoFrameInstance = New("VideoFrame", {
            BackgroundTransparency = 1,
            Size = UDim2.fromScale(1, 1),
            Video = Video.Video,
            Looped = Video.Looped,
            Volume = Video.Volume,
            Parent = Box,
        })

        VideoFrameInstance.Playing = Video.Playing

        function Video:SetHeight(Height: number)
            assert(Height > 0, "Height must be greater than 0.")

            Video.Height = Height
            Holder.Size = UDim2.new(1, 0, 0, Height)
            Groupbox:Resize()
        end

        function Video:SetVideo(NewVideo: string)
            assert(typeof(NewVideo) == "string", "Video must be a string.")

            VideoFrameInstance.Video = NewVideo
            Video.Video = NewVideo
        end

        function Video:SetLooped(Looped: boolean)
            assert(typeof(Looped) == "boolean", "Looped must be a boolean.")

            VideoFrameInstance.Looped = Looped
            Video.Looped = Looped
        end

        function Video:SetVolume(Volume: number)
            assert(typeof(Volume) == "number", "Volume must be a number between 0 and 10.")

            VideoFrameInstance.Volume = Volume
            Video.Volume = Volume
        end

        function Video:SetPlaying(Playing: boolean)
            assert(typeof(Playing) == "boolean", "Playing must be a boolean.")

            VideoFrameInstance.Playing = Playing
            Video.Playing = Playing
        end

        function Video:Play()
            VideoFrameInstance.Playing = true
            Video.Playing = true
        end

        function Video:Pause()
            VideoFrameInstance.Playing = false
            Video.Playing = false
        end

        function Video:SetVisible(Visible: boolean)
            Video.Visible = Visible

            Holder.Visible = Video.Visible
            Groupbox:Resize()
        end

        Groupbox:Resize()

        Video.Holder = Holder
        Video.VideoFrame = VideoFrameInstance
        table.insert(Groupbox.Elements, Video)

        Options[Idx] = Video

        function Video:Destroy()
            Video.Destroyed = true

            if Video.Connections then
                for _, Connection in Video.Connections do
                    Connection:Disconnect()
                end
            end

            if Holder then 
                Holder:Destroy() 
            end

            local ElemIdx = table.find(Groupbox.Elements, Video)
            if ElemIdx then 
                table.remove(Groupbox.Elements, ElemIdx) 
            end

            Groupbox:Resize()
            Options[Idx] = nil
        end

        return Video
    end

    function Funcs:AddUIPassthrough(Idx, Info)
        if self.Destroyed then return nil end

        Info = Library:Validate(Info, Templates.UIPassthrough)

        local Groupbox = self
        local Container = Groupbox.Container

        assert(Info.Instance, "Instance must be provided.")
        assert(
            typeof(Info.Instance) == "Instance" and Info.Instance:IsA("GuiBase2d"),
            "Instance must inherit from GuiBase2d."
        )
        assert(typeof(Info.Height) == "number" and Info.Height > 0, "Height must be a number greater than 0.")

        local Passthrough = {
            Connections = {},
            Destroyed = false,

            Instance = Info.Instance,
            Height = Info.Height,
            Visible = Info.Visible,

            Type = "UIPassthrough",
        }

        local Holder = New("Frame", {
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, Info.Height),
            Visible = Passthrough.Visible,
            Parent = Container,
        })

        Passthrough.Instance.Parent = Holder

        Groupbox:Resize()

        function Passthrough:SetHeight(Height: number)
            assert(typeof(Height) == "number" and Height > 0, "Height must be a number greater than 0.")

            Passthrough.Height = Height
            Holder.Size = UDim2.new(1, 0, 0, Height)
            Groupbox:Resize()
        end

        function Passthrough:SetInstance(Instance: Instance)
            assert(Instance, "Instance must be provided.")
            assert(
                typeof(Instance) == "Instance" and Instance:IsA("GuiBase2d"),
                "Instance must inherit from GuiBase2d."
            )

            if Passthrough.Instance then
                Passthrough.Instance.Parent = nil
            end

            Passthrough.Instance = Instance
            Passthrough.Instance.Parent = Holder
        end

        function Passthrough:SetVisible(Visible: boolean)
            Passthrough.Visible = Visible

            Holder.Visible = Passthrough.Visible
            Groupbox:Resize()
        end

        Passthrough.Holder = Holder
        table.insert(Groupbox.Elements, Passthrough)

        Options[Idx] = Passthrough

        function Passthrough:Destroy()
            Passthrough.Destroyed = true

            if Passthrough.Connections then
                for _, Connection in Passthrough.Connections do
                    Connection:Disconnect()
                end
            end

            if Holder then 
                Holder:Destroy() 
            end

            local ElemIdx = table.find(Groupbox.Elements, Passthrough)
            if ElemIdx then 
                table.remove(Groupbox.Elements, ElemIdx) 
            end

            Groupbox:Resize()
            Options[Idx] = nil
        end

        return Passthrough
    end

    function Funcs:AddDependencyBox()
        if self.Destroyed then return nil end

        local Groupbox = self
        local Container = Groupbox.Container

        local DepboxContainer
        local DepboxList

        do
            DepboxContainer = New("Frame", {
                BackgroundTransparency = 1,
                Size = UDim2.fromScale(1, 1),
                Visible = false,
                Parent = Container,
            })

            DepboxList = New("UIListLayout", {
                Padding = UDim.new(0, 8),
                Parent = DepboxContainer,
            })
        end

        local Depbox = {
            Connections = {},
            Destroyed = false,

            Visible = false,
            Dependencies = {},

            Holder = DepboxContainer,
            Container = DepboxContainer,

            Elements = {},
            DependencyBoxes = {},
        }

        function Depbox:Resize()
            DepboxContainer.Size = UDim2.new(1, 0, 0, DepboxList.AbsoluteContentSize.Y / Library.DPIScale)
            Groupbox:Resize()
        end

        function Depbox:Update(CancelSearch)
            for _, Dependency in Depbox.Dependencies do
                local Element = Dependency[1]
                local Value = Dependency[2]

                if Element.Type == "Toggle" and Element.Value ~= Value then
                    DepboxContainer.Visible = false
                    Depbox.Visible = false
                    return
                elseif Element.Type == "Dropdown" then
                    if typeof(Element.Value) == "table" then
                        if not Element.Value[Value] then
                            DepboxContainer.Visible = false
                            Depbox.Visible = false
                            return
                        end
                    else
                        if Element.Value ~= Value then
                            DepboxContainer.Visible = false
                            Depbox.Visible = false
                            return
                        end
                    end
                end
            end

            Depbox.Visible = true
            DepboxContainer.Visible = true
            if not Library.Searching then
                task.defer(function()
                    Depbox:Resize()
                end)
            elseif not CancelSearch then
                Library:UpdateSearch(Library.SearchText)
            end
        end

        DepboxList:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
            if not Depbox.Visible then
                return
            end

            Depbox:Resize()
        end)

        function Depbox:SetupDependencies(Dependencies)
            for _, Dependency in Dependencies do
                assert(typeof(Dependency) == "table", "Dependency should be a table.")
                assert(Dependency[1] ~= nil, "Dependency is missing element.")
                assert(Dependency[2] ~= nil, "Dependency is missing expected value.")
            end

            Depbox.Dependencies = Dependencies
            Depbox:Update()
        end

        DepboxContainer:GetPropertyChangedSignal("Visible"):Connect(function()
            Depbox:Resize()
        end)

        setmetatable(Depbox, BaseGroupbox)

        table.insert(Groupbox.DependencyBoxes, Depbox)
        table.insert(Library.DependencyBoxes, Depbox)

        function Depbox:Destroy()
            Depbox.Destroyed = true

            if Depbox.Connections then
                for _, Connection in Depbox.Connections do
                    Connection:Disconnect()
                end
            end

            for _, Element in Depbox.Elements do
                if Element.Destroy then
                    Element:Destroy()
                end
            end

            for _, SubDepbox in Depbox.DependencyBoxes do
                if SubDepbox.Destroy then
                    SubDepbox:Destroy()
                end
            end

            if DepboxContainer then 
                DepboxContainer:Destroy() 
            end

            local ElemIdx = table.find(Groupbox.DependencyBoxes, Depbox)
            if ElemIdx then 
                table.remove(Groupbox.DependencyBoxes, ElemIdx)
            end

            local LibIdx = table.find(Library.DependencyBoxes, Depbox)
            if LibIdx then 
                table.remove(Library.DependencyBoxes, LibIdx) 
            end
        end

        return Depbox
    end

    function Funcs:AddDependencyGroupbox()
        if self.Destroyed then return nil end

        local Groupbox = self
        local Tab = Groupbox.Tab
        local BoxHolder = Groupbox.BoxHolder

        local DepGroupboxContainer
        local DepGroupboxList

        do
            DepGroupboxContainer = New("Frame", {
                BackgroundColor3 = "BackgroundColor",
                Size = UDim2.fromScale(1, 0),
                Visible = false,
                Parent = BoxHolder,
            })
            table.insert(
                Library.Corners,
                New("UICorner", {
                    CornerRadius = UDim.new(0, Library.CornerRadius),
                    Parent = DepGroupboxContainer,
                })
            )
            Library:AddOutline(DepGroupboxContainer)

            DepGroupboxList = New("UIListLayout", {
                Padding = UDim.new(0, 8),
                Parent = DepGroupboxContainer,
            })
            New("UIPadding", {
                PaddingBottom = UDim.new(0, 7),
                PaddingLeft = UDim.new(0, 7),
                PaddingRight = UDim.new(0, 7),
                PaddingTop = UDim.new(0, 7),
                Parent = DepGroupboxContainer,
            })
        end

        local DepGroupbox = {
            Connections = {},
            Destroyed = false,

            Visible = false,
            Dependencies = {},

            BoxHolder = BoxHolder,
            Holder = DepGroupboxContainer,
            Container = DepGroupboxContainer,

            Tab = Tab,
            Elements = {},
            DependencyBoxes = {},
        }

        function DepGroupbox:Resize()
            DepGroupboxContainer.Size = UDim2.new(1, 0, 0, (DepGroupboxList.AbsoluteContentSize.Y / Library.DPIScale) + 18)
        end

        function DepGroupbox:Update(CancelSearch)
            for _, Dependency in DepGroupbox.Dependencies do
                local Element = Dependency[1]
                local Value = Dependency[2]

                if Element.Type == "Toggle" and Element.Value ~= Value then
                    DepGroupboxContainer.Visible = false
                    DepGroupbox.Visible = false
                    return
                elseif Element.Type == "Dropdown" then
                    if typeof(Element.Value) == "table" then
                        if not Element.Value[Value] then
                            DepGroupboxContainer.Visible = false
                            DepGroupbox.Visible = false
                            return
                        end
                    else
                        if Element.Value ~= Value then
                            DepGroupboxContainer.Visible = false
                            DepGroupbox.Visible = false
                            return
                        end
                    end
                end
            end

            DepGroupbox.Visible = true
            if not Library.Searching then
                DepGroupboxContainer.Visible = true
                DepGroupbox:Resize()
            elseif not CancelSearch then
                Library:UpdateSearch(Library.SearchText)
            end
        end

        function DepGroupbox:SetupDependencies(Dependencies)
            for _, Dependency in Dependencies do
                assert(typeof(Dependency) == "table", "Dependency should be a table.")
                assert(Dependency[1] ~= nil, "Dependency is missing element.")
                assert(Dependency[2] ~= nil, "Dependency is missing expected value.")
            end

            DepGroupbox.Dependencies = Dependencies
            DepGroupbox:Update()
        end

        setmetatable(DepGroupbox, BaseGroupbox)

        table.insert(Tab.DependencyGroupboxes, DepGroupbox)
        table.insert(Library.DependencyBoxes, DepGroupbox :: any)

        function DepGroupbox:Destroy()
            DepGroupbox.Destroyed = true

            if DepGroupbox.Connections then
                for _, Connection in DepGroupbox.Connections do
                    Connection:Disconnect()
                end
            end

            for _, Element in DepGroupbox.Elements do
                if Element.Destroy then
                    Element:Destroy()
                end
            end

            for _, SubDepbox in DepGroupbox.DependencyBoxes do
                if SubDepbox.Destroy then
                    SubDepbox:Destroy()
                end
            end

            if DepGroupboxContainer then 
                DepGroupboxContainer:Destroy() 
            end

            local ElemIdx = table.find(Tab.DependencyGroupboxes, DepGroupbox)
            if ElemIdx then 
                table.remove(Tab.DependencyGroupboxes, ElemIdx) 
            end

            local LibIdx = table.find(Library.DependencyBoxes, DepGroupbox)
            if LibIdx then 
                table.remove(Library.DependencyBoxes, LibIdx) 
            end
        end

        return DepGroupbox
    end

    BaseGroupbox.__index = Funcs
    BaseGroupbox.__namecall = function(_, Key, ...)
        return Funcs[Key](...)
    end
end

function Library:SetFont(FontFace)
    if typeof(FontFace) == "EnumItem" then
        FontFace = Font.fromEnum(FontFace :: any)
    end

    Library.Scheme.Font = FontFace
    Library:UpdateColorsUsingRegistry()
end

function Library:SetNotifySide(Side: string)
    Library.NotifySide = Side

    if Side:lower() == "left" then
        NotificationArea.AnchorPoint = Vector2.new(0, 0)
        NotificationArea.Position = UDim2.fromOffset(6, 6)
        NotificationList.HorizontalAlignment = Enum.HorizontalAlignment.Left
    else
        NotificationArea.AnchorPoint = Vector2.new(1, 0)
        NotificationArea.Position = UDim2.new(1, -6, 0, 6)
        NotificationList.HorizontalAlignment = Enum.HorizontalAlignment.Right
    end
end

function Library:Notify(...)
    local Data = {}
    local Info = select(1, ...)

    if typeof(Info) == "table" then
        Data.Title = tostring(Info.Title)
        Data.Description = tostring(Info.Description)
        Data.Time = Info.Time or 5
        Data.SoundId = Info.SoundId
        Data.Steps = Info.Steps
        Data.Persist = Info.Persist
        Data.Icon = Info.Icon
        Data.BigIcon = Info.BigIcon
        Data.IconColor = Info.IconColor
        Data.Volume = tonumber(Info.Volume) or 3
    else
        Data.Description = tostring(Info)
        Data.Time = select(2, ...) or 5
        Data.SoundId = select(3, ...)
        Data.Volume = select(4, ...) or 3
    end
    Data.Destroyed = false

    local DeletedInstance = false
    local DeleteConnection = nil
    if typeof(Data.Time) == "Instance" then
        DeleteConnection = Data.Time.Destroying:Connect(function()
            DeletedInstance = true

            DeleteConnection:Disconnect()
            DeleteConnection = nil
        end)
    end

    local FakeBackground = New("Frame", {
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        Size = UDim2.fromScale(1, 0),
        Visible = false,
        Parent = NotificationArea,
    })

    local Holder = New("Frame", {
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundColor3 = "MainColor",
        Position = Library.NotifySide:lower() == "left" and UDim2.new(-1, -8, 0, -2) or UDim2.new(1, 8, 0, -2),
        Size = UDim2.fromScale(1, 1),
        ZIndex = 5,
        Parent = FakeBackground,
    })
    table.insert(
        Library.Corners,
        New("UICorner", {
            CornerRadius = UDim.new(0, Library.CornerRadius),
            Parent = Holder,
        })
    )
    New("UIListLayout", {
        Padding = UDim.new(0, 4),
        Parent = Holder,
    })
    New("UIPadding", {
        PaddingBottom = UDim.new(0, 8),
        PaddingLeft = UDim.new(0, 8),
        PaddingRight = UDim.new(0, 8),
        PaddingTop = UDim.new(0, 8),
        Parent = Holder,
    })
    Library:AddOutline(Holder)

    local ContentContainer = New("Frame", {
        BackgroundTransparency = 1,
        AutomaticSize = Enum.AutomaticSize.XY,
        Size = UDim2.fromScale(1, 0),
        Parent = Holder,
    })
    
    if Data.BigIcon then
        New("UIListLayout", {
            Padding = UDim.new(0, 8),
            FillDirection = Enum.FillDirection.Horizontal,
            VerticalAlignment = Enum.VerticalAlignment.Center,
            Parent = ContentContainer,
        })
    end

    local BigIconLabel
    if Data.BigIcon then
        local ParsedIcon = Library:GetCustomIcon(Data.BigIcon)
        if ParsedIcon then
            BigIconLabel = New("ImageLabel", {
                BackgroundTransparency = 1,
                Size = UDim2.fromOffset(24, 24),
                Image = ParsedIcon.Url,
                ImageColor3 = Data.IconColor or "AccentColor",
                ImageRectOffset = ParsedIcon.ImageRectOffset,
                ImageRectSize = ParsedIcon.ImageRectSize,
                Parent = ContentContainer,
            })
        end
    end

    local TextContainer = New("Frame", {
        BackgroundTransparency = 1,
        AutomaticSize = Enum.AutomaticSize.XY,
        Size = UDim2.fromScale(0, 0),
        Parent = ContentContainer,
    })
    New("UIListLayout", {
        Padding = UDim.new(0, 4),
        Parent = TextContainer,
    })
    
    local TitleContainer
    if Data.Title then
        TitleContainer = New("Frame", {
            BackgroundTransparency = 1,
            Size = UDim2.fromScale(0, 0),
            Parent = TextContainer,
        })
    end

    local IconLabel
    if Data.Icon and TitleContainer then
        local ParsedIcon = Library:GetCustomIcon(Data.Icon)
        if ParsedIcon then
            IconLabel = New("ImageLabel", {
                BackgroundTransparency = 1,
                AnchorPoint = Vector2.new(0, 0.5),
                Position = UDim2.new(0, 0, 0.5, 1),
                Size = UDim2.fromOffset(15, 15),
                Image = ParsedIcon.Url,
                ImageColor3 = Data.IconColor or "FontColor",
                ImageRectOffset = ParsedIcon.ImageRectOffset,
                ImageRectSize = ParsedIcon.ImageRectSize,
                Parent = TitleContainer,
            })
        end
    end

    local Title
    local Desc
    local TitleX = 0
    local DescX = 0

    local TimerFill

    if Data.Title then
        Title = New("TextLabel", {
            AutomaticSize = Enum.AutomaticSize.None,
            BackgroundTransparency = 1,
            AnchorPoint = Vector2.new(0, 0.5),
            Position = UDim2.new(0, (Data.Icon and 21 or 0), 0.5, 0),
            Size = UDim2.fromScale(0, 0),
            Text = Data.Title,
            TextSize = 15,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextYAlignment = Enum.TextYAlignment.Center,
            TextWrapped = true,
            Parent = TitleContainer,
        })
    end

    if Data.Description then
        Desc = New("TextLabel", {
            AutomaticSize = Enum.AutomaticSize.None,
            BackgroundTransparency = 1,
            Size = UDim2.fromScale(0, 0),
            Text = Data.Description,
            TextSize = 14,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextWrapped = true,
            Parent = TextContainer,
        })
    end

    function Data:Resize()
        local ExtraWidth = BigIconLabel and 32 or 0
        local IconWidth = IconLabel and 21 or 0

        if Title then
            local X, Y =
                Library:GetTextBounds(Title.Text, Title.FontFace, Title.TextSize, (NotificationArea.AbsoluteSize.X / Library.DPIScale) - 24 - ExtraWidth - IconWidth)
            Title.Size = UDim2.fromOffset(X, Y)
            TitleX = X + IconWidth
            TitleContainer.Size = UDim2.fromOffset(TitleX, math.max(Y, IconLabel and 16 or 0))
        end

        if Desc then
            local X, Y =
                Library:GetTextBounds(Desc.Text, Desc.FontFace, Desc.TextSize, (NotificationArea.AbsoluteSize.X / Library.DPIScale) - 24 - ExtraWidth)
            Desc.Size = UDim2.fromOffset(X, Y)
            DescX = X
        end

        FakeBackground.Size = UDim2.fromOffset(math.max(TitleX, DescX) + 24 + ExtraWidth, 0)
    end

    function Data:ChangeTitle(Text)
        if Title then
            Data.Title = tostring(Text)
            Title.Text = Data.Title
            Data:Resize()
        end
    end

    function Data:ChangeDescription(Text)
        if Desc then
            Data.Description = tostring(Text)
            Desc.Text = Data.Description
            Data:Resize()
        end
    end

    function Data:ChangeStep(NewStep)
        if TimerFill and Data.Steps then
            NewStep = math.clamp(NewStep or 0, 0, Data.Steps)
            TimerFill.Size = UDim2.fromScale(NewStep / Data.Steps, 1)
        end
    end

    function Data:Destroy()
        Data.Destroyed = true

        if typeof(Data.Time) == "Instance" then
            pcall(Data.Time.Destroy, Data.Time)
        end

        if DeleteConnection then
            DeleteConnection:Disconnect()
        end

        TweenService
            :Create(Holder, Library.NotifyTweenInfo, {
                Position = Library.NotifySide:lower() == "left" and UDim2.new(-1, -8, 0, -2) or UDim2.new(1, 8, 0, -2),
            })
            :Play()

        task.delay(Library.NotifyTweenInfo.Time, function()
            Library.Notifications[FakeBackground] = nil
            FakeBackground:Destroy()
        end)
    end

    Data:Resize()

    local TimerHolder = New("Frame", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 7),
        Visible = (Data.Persist ~= true and typeof(Data.Time) ~= "Instance") or typeof(Data.Steps) == "number",
        Parent = Holder,
    })
    local TimerBar = New("Frame", {
        BackgroundColor3 = "BackgroundColor",
        BorderColor3 = "OutlineColor",
        BorderSizePixel = 1,
        Position = UDim2.fromOffset(0, 3),
        Size = UDim2.new(1, 0, 0, 2),
        Parent = TimerHolder,
    })
    TimerFill = New("Frame", {
        BackgroundColor3 = "AccentColor",
        Size = UDim2.fromScale(1, 1),
        Parent = TimerBar,
    })

    if typeof(Data.Time) == "Instance" then
        TimerFill.Size = UDim2.fromScale(0, 1)
    end
    if Data.SoundId then
        local SoundId = Data.SoundId
        if typeof(SoundId) == "number" then
            SoundId = string.format("rbxassetid://%d", SoundId)
        end

        New("Sound", {
            SoundId = SoundId,
            Volume = tonumber(Data.Volume) or 3,
            PlayOnRemove = true,
            Parent = SoundService,
        }):Destroy()
    end

    Library.Notifications[FakeBackground] = Data

    FakeBackground.Visible = true
    TweenService:Create(Holder, Library.NotifyTweenInfo, {
        Position = UDim2.fromOffset(0, 0),
    }):Play()

    task.delay(Library.NotifyTweenInfo.Time, function()
        if Data.Persist then
            return
        elseif typeof(Data.Time) == "Instance" then
            repeat
                task.wait()
            until DeletedInstance or Data.Destroyed
        else
            TweenService
                :Create(TimerFill, TweenInfo.new(Data.Time, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut), {
                    Size = UDim2.fromScale(0, 1),
                })
                :Play()
            task.wait(Data.Time)
        end

        if not Data.Destroyed then
            Data:Destroy()
        end
    end)

    return Data
end

function Library:CreateWindow(WindowInfo)
    WindowInfo = Library:Validate(WindowInfo, Templates.Window)
    local ViewportSize: Vector2 = workspace.CurrentCamera.ViewportSize
    if RunService:IsStudio() and ViewportSize.X <= 5 and ViewportSize.Y <= 5 then
        repeat
            ViewportSize = workspace.CurrentCamera.ViewportSize
            task.wait()
        until ViewportSize.X > 5 and ViewportSize.Y > 5
    end

    local MaxX = ViewportSize.X - 64
    local MaxY = ViewportSize.Y - 64

    Library.OriginalMinSize =
        Vector2.new(math.min(Library.OriginalMinSize.X, MaxX), math.min(Library.OriginalMinSize.Y, MaxY))
    Library.MinSize = Library.OriginalMinSize

    WindowInfo.Size = UDim2.fromOffset(
        math.clamp(WindowInfo.Size.X.Offset, Library.MinSize.X, MaxX),
        math.clamp(WindowInfo.Size.Y.Offset, Library.MinSize.Y, MaxY)
    )
    if typeof(WindowInfo.Font) == "EnumItem" then
        WindowInfo.Font = Font.fromEnum(WindowInfo.Font :: any)
    end
    WindowInfo.CornerRadius = math.min(WindowInfo.CornerRadius, 20)
    
    --// Old Naming \\--
    if WindowInfo.Compact ~= nil then
        WindowInfo.SidebarCompacted = WindowInfo.Compact
    end
    if WindowInfo.SidebarMinWidth ~= nil then
        WindowInfo.MinSidebarWidth = WindowInfo.SidebarMinWidth
    end
    WindowInfo.MinSidebarWidth = math.max(64, WindowInfo.MinSidebarWidth)
    WindowInfo.SidebarCompactWidth = math.max(48, WindowInfo.SidebarCompactWidth)
    WindowInfo.SidebarCollapseThreshold = math.clamp(WindowInfo.SidebarCollapseThreshold, 0.1, 0.9)
    WindowInfo.CompactWidthActivation = math.max(48, WindowInfo.CompactWidthActivation)

    Library.CornerRadius = WindowInfo.CornerRadius
    Library:SetNotifySide(WindowInfo.NotifySide)
    Library.ShowCustomCursor = WindowInfo.ShowCustomCursor
    Library.Scheme.Font = WindowInfo.Font
    Library.ToggleKeybind = WindowInfo.ToggleKeybind
    Library.GlobalSearch = WindowInfo.GlobalSearch

    local IsDefaultSearchbarSize = WindowInfo.SearchbarSize == UDim2.fromScale(1, 1)
    local MainFrame
    local DividerLine
    local TitleHolder
    local WindowTitle
    local WindowIcon
    local RightWrapper
    local SearchBox
    local CurrentTabInfo
    local CurrentTabLabel
    local CurrentTabDescription
    local ResizeButton
    local Tabs
    local Container
    local BackgroundImage
    local BottomBackground
    local FooterLabel

    local InitialLeftWidth = math.ceil(WindowInfo.Size.X.Offset * 0.3)
    local IsCompact = WindowInfo.SidebarCompacted
    local LastExpandedWidth = InitialLeftWidth

    do
        Library.KeybindFrame, Library.KeybindContainer = Library:AddDraggableMenu("Keybinds")
        Library.KeybindFrame.AnchorPoint = Vector2.new(0, 0.5)
        Library.KeybindFrame.Position = UDim2.new(0, 6, 0.5, 0)
        Library.KeybindFrame.Visible = false

        MainFrame = New("TextButton", {
            BackgroundColor3 = function()
                return Library:GetBetterColor(Library.Scheme.BackgroundColor, -1)
            end,
            Name = "Main",
            Text = "",
            Position = WindowInfo.Position,
            Size = WindowInfo.Size,
            Visible = false,
            Parent = ScreenGui,
        })
        table.insert(
            Library.Corners,
            New("UICorner", {
                CornerRadius = UDim.new(0, WindowInfo.CornerRadius),
                Parent = MainFrame,
            })
        )
        table.insert(
            Library.Scales,
            New("UIScale", {
                Parent = MainFrame,
            })
        )
        Library:AddOutline(MainFrame)
        Library:MakeLine(MainFrame, {
            Position = UDim2.fromOffset(0, 48),
            Size = UDim2.new(1, 0, 0, 1),
        })

        DividerLine = New("Frame", {
            BackgroundColor3 = "OutlineColor",
            Position = UDim2.fromOffset(InitialLeftWidth, 0),
            Size = UDim2.new(0, 1, 1, -21),
            Parent = MainFrame,
        })

        if WindowInfo.BackgroundImage then
            BackgroundImage = New("ImageLabel", {
                Image = WindowInfo.BackgroundImage,
                Position = UDim2.fromScale(0, 0),
                Size = UDim2.fromScale(1, 1),
                ScaleType = Enum.ScaleType.Stretch,
                ZIndex = 999,
                BackgroundTransparency = 1,
                ImageTransparency = 0.75,
                Parent = MainFrame,
            })

            table.insert(
                Library.Corners,
                New("UICorner", {
                    CornerRadius = UDim.new(0, WindowInfo.CornerRadius),
                    Parent = BackgroundImage,
                })
            )
        end

        if WindowInfo.Center then
            MainFrame.Position = UDim2.new(0.5, -MainFrame.Size.X.Offset / 2, 0.5, -MainFrame.Size.Y.Offset / 2)
        end

        --// Top Bar \\-
        local TopBar = New("Frame", {
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, 48),
            Parent = MainFrame,
        })
        Library:MakeDraggable(MainFrame, TopBar, false, true)

        --// Title \\--
        TitleHolder = New("Frame", {
            BackgroundTransparency = 1,
            Size = UDim2.new(0, InitialLeftWidth, 1, 0),
            Parent = TopBar,
        })
        New("UIListLayout", {
            FillDirection = Enum.FillDirection.Horizontal,
            HorizontalAlignment = Enum.HorizontalAlignment.Center,
            VerticalAlignment = Enum.VerticalAlignment.Center,
            Padding = UDim.new(0, 6),
            Parent = TitleHolder,
        })

        if WindowInfo.Icon then
            local Icon = Library:GetCustomIcon(WindowInfo.Icon)
            WindowIcon = New("ImageLabel", {
                Image = Icon.Url,
                ImageRectOffset = Icon.ImageRectOffset,
                ImageRectSize = Icon.ImageRectSize,
                Size = WindowInfo.IconSize,
                Parent = TitleHolder,
            })
        else
            WindowIcon = New("TextLabel", {
                BackgroundTransparency = 1,
                Size = WindowInfo.IconSize,
                Text = WindowInfo.Title:sub(1, 1),
                TextScaled = true,
                Visible = false,
                Parent = TitleHolder,
            })
        end

        local X = Library:GetTextBounds(
            WindowInfo.Title,
            Library.Scheme.Font,
            20,
            TitleHolder.AbsoluteSize.X - (WindowInfo.Icon and WindowInfo.IconSize.X.Offset + 6 or 0) - 12
        )
        WindowTitle = New("TextLabel", {
            BackgroundTransparency = 1,
            Size = UDim2.new(0, X, 1, 0),
            Text = WindowInfo.Title,
            TextSize = 20,
            Parent = TitleHolder,
        })

        --// Top Right Bar \\--
        RightWrapper = New("Frame", {
            AnchorPoint = Vector2.new(1, 0.5),
            BackgroundTransparency = 1,
            Position = UDim2.new(1, -49, 0.5, 0),
            Size = UDim2.new(1, -InitialLeftWidth - 57 - 1, 1, -16),
            Parent = TopBar,
        })

        New("UIListLayout", {
            FillDirection = Enum.FillDirection.Horizontal,
            HorizontalAlignment = Enum.HorizontalAlignment.Left,
            VerticalAlignment = Enum.VerticalAlignment.Center,
            Padding = UDim.new(0, 8),
            Parent = RightWrapper,
        })

        CurrentTabInfo = New("Frame", {
            Size = UDim2.fromScale(WindowInfo.DisableSearch and 1 or 0.5, 1),
            Visible = false,
            BackgroundTransparency = 1,
            Parent = RightWrapper,
        })

        New("UIFlexItem", {
            FlexMode = Enum.UIFlexMode.Grow,
            Parent = CurrentTabInfo,
        })

        New("UIListLayout", {
            FillDirection = Enum.FillDirection.Vertical,
            HorizontalAlignment = Enum.HorizontalAlignment.Left,
            VerticalAlignment = Enum.VerticalAlignment.Center,
            Parent = CurrentTabInfo,
        })

        New("UIPadding", {
            PaddingBottom = UDim.new(0, 8),
            PaddingLeft = UDim.new(0, 8),
            PaddingRight = UDim.new(0, 8),
            PaddingTop = UDim.new(0, 8),
            Parent = CurrentTabInfo,
        })

        CurrentTabLabel = New("TextLabel", {
            BackgroundTransparency = 1,
            Size = UDim2.fromScale(1, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            Text = "",
            TextSize = 14,
            TextXAlignment = Enum.TextXAlignment.Left,
            Parent = CurrentTabInfo,
        })

        CurrentTabDescription = New("TextLabel", {
            BackgroundTransparency = 1,
            Size = UDim2.fromScale(1, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            Text = "",
            TextWrapped = true,
            TextSize = 14,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextTransparency = 0.5,
            Parent = CurrentTabInfo,
        })

        SearchBox = New("TextBox", {
            BackgroundColor3 = "MainColor",
            PlaceholderText = "Search",
            Size = WindowInfo.SearchbarSize,
            TextScaled = true,
            Visible = not (WindowInfo.DisableSearch or false),
            Parent = RightWrapper,
        })
        New("UIFlexItem", {
            FlexMode = Enum.UIFlexMode.Shrink,
            Parent = SearchBox,
        })
        table.insert(
            Library.Corners,
            New("UICorner", {
                CornerRadius = UDim.new(0, WindowInfo.CornerRadius),
                Parent = SearchBox,
            })
        )
        New("UIPadding", {
            PaddingBottom = UDim.new(0, 8),
            PaddingLeft = UDim.new(0, 8),
            PaddingRight = UDim.new(0, 8),
            PaddingTop = UDim.new(0, 8),
            Parent = SearchBox,
        })
        New("UIStroke", {
            Color = "OutlineColor",
            Parent = SearchBox,
        })

        local SearchIcon = Library:GetIcon("search")
        if SearchIcon then
            New("ImageLabel", {
                Image = SearchIcon.Url,
                ImageColor3 = "FontColor",
                ImageRectOffset = SearchIcon.ImageRectOffset,
                ImageRectSize = SearchIcon.ImageRectSize,
                ImageTransparency = 0.5,
                Size = UDim2.fromScale(1, 1),
                SizeConstraint = Enum.SizeConstraint.RelativeYY,
                Parent = SearchBox,
            })
        end

        if MoveIcon then
            New("ImageLabel", {
                AnchorPoint = Vector2.new(1, 0.5),
                Image = MoveIcon.Url,
                ImageColor3 = "OutlineColor",
                ImageRectOffset = MoveIcon.ImageRectOffset,
                ImageRectSize = MoveIcon.ImageRectSize,
                Position = UDim2.new(1, -10, 0.5, 0),
                Size = UDim2.fromOffset(28, 28),
                SizeConstraint = Enum.SizeConstraint.RelativeYY,
                Parent = TopBar,
            })
        end

        --// Bottom Bar \\--
        BottomBackground = New("Frame", {
            AnchorPoint = Vector2.new(0, 1),
            BackgroundColor3 = function()
                return Library:GetBetterColor(Library.Scheme.BackgroundColor, 4)
            end,
            Position = UDim2.fromScale(0, 1),
            Size = UDim2.new(1, 0, 0, 20 + WindowInfo.CornerRadius),
            Parent = MainFrame
        })
        Library:MakeLine(MainFrame, {
            AnchorPoint = Vector2.new(0, 1),
            Position = UDim2.new(0, 0, 1, -20),
            Size = UDim2.new(1, 0, 0, 1),
        })

        local BottomBar = New("Frame", {
            AnchorPoint = Vector2.new(0, 1),
            BackgroundTransparency = 1,
            Position = UDim2.fromScale(0, 1),
            Size = UDim2.new(1, 0, 0, 20),
            Parent = MainFrame,
        })
        table.insert(
            Library.Corners,
            New("UICorner", {
                CornerRadius = UDim.new(0, WindowInfo.CornerRadius),
                Parent = BottomBackground,
            })
        )

        --// Footer \\-
        FooterLabel = New("TextLabel", {
            BackgroundTransparency = 1,
            Size = UDim2.fromScale(1, 1),
            Text = WindowInfo.Footer,
            TextSize = 14,
            TextTransparency = 0.5,
            Parent = BottomBar,
        })

        --// Resize Button \\--
        if WindowInfo.Resizable then
            ResizeButton = New("TextButton", {
                AnchorPoint = Vector2.new(1, 0),
                BackgroundTransparency = 1,
                Position = UDim2.new(1, -WindowInfo.CornerRadius / 4, 0, 0),
                Size = UDim2.fromScale(1, 1),
                SizeConstraint = Enum.SizeConstraint.RelativeYY,
                Text = "",
                Parent = BottomBar,
            })

            Library:MakeResizable(MainFrame, ResizeButton, function()
                for _, Tab in Library.Tabs do
                    Tab:Resize(true)
                end
            end)
        end

        New("ImageLabel", {
            Image = ResizeIcon and ResizeIcon.Url or "",
            ImageColor3 = "FontColor",
            ImageRectOffset = ResizeIcon and ResizeIcon.ImageRectOffset or Vector2.zero,
            ImageRectSize = ResizeIcon and ResizeIcon.ImageRectSize or Vector2.zero,
            ImageTransparency = 0.5,
            Position = UDim2.fromOffset(2, 2),
            Size = UDim2.new(1, -4, 1, -4),
            Parent = ResizeButton,
        })

        --// Tabs \\--
        Tabs = New("ScrollingFrame", {
            AutomaticCanvasSize = Enum.AutomaticSize.Y,
            BackgroundColor3 = "BackgroundColor",
            CanvasSize = UDim2.fromScale(0, 0),
            Position = UDim2.fromOffset(0, 49),
            ScrollBarThickness = 0,
            Size = UDim2.new(0, InitialLeftWidth, 1, -70),
            Parent = MainFrame,
        })
        New("UIListLayout", {
            Parent = Tabs,
        })

        --// Container \\--
        Container = New("Frame", {
            AnchorPoint = Vector2.new(1, 0),
            BackgroundColor3 = function()
                return Library:GetBetterColor(Library.Scheme.BackgroundColor, 1)
            end,
            Name = "Container",
            Position = UDim2.new(1, 0, 0, 49),
            Size = UDim2.new(1, -InitialLeftWidth - 1, 1, -70),
            Parent = MainFrame,
        })
        New("UIPadding", {
            PaddingBottom = UDim.new(0, 0),
            PaddingLeft = UDim.new(0, 6),
            PaddingRight = UDim.new(0, 6),
            PaddingTop = UDim.new(0, 0),
            Parent = Container,
        })

        Library.WindowContainer = Container
    end

    --// Window Table \\--
    local Window = {}

    local function SetUICorner(UICorner, Corner, HalfCurrent, HalfValue, Value)
        local Current = UICorner[Corner]
        if Current.Offset == 0 and Current.Scale == 0 then
            return
        end

        UICorner[Corner] = Current.Offset == HalfCurrent and HalfValue or Value
    end

    function Window:ChangeTitle(title)
        assert(typeof(title) == "string", "Expected string for title got: " .. typeof(title))

        WindowTitle.Text = title
        WindowInfo.Title = title
    end

    if WindowInfo.BackgroundImage then
        function Window:SetBackgroundImage(Image: string)
            assert(typeof(Image) == "string", "Expected string for Image got: " .. typeof(Image))
    
            BackgroundImage.Image = Image
            WindowInfo.BackgroundImage = Image
        end
    end

    function Window:SetFooter(footer: string)
        assert(typeof(footer) == "string", "Expected string for footer got: " .. typeof(footer))

        FooterLabel.Text = footer
        WindowInfo.Footer = footer
    end

    function Window:SetCornerRadius(Radius: number)
        assert(typeof(Radius) == "number", "Expected number for Radius got: " .. typeof(Radius))
        Radius = math.min(Radius, 20)

        local RadiusHalf = UDim.new(0, Radius / 2)
        local RadiusUDim = UDim.new(0, Radius / 2)
        local HalfCurrent = Library.CornerRadius / 2

        for _, UICorner in Library.Corners do
            if UICorner.CornerRadius.Offset == HalfCurrent then
                UICorner.CornerRadius = RadiusHalf
            else
                UICorner.CornerRadius = RadiusUDim
            end
        end

        for _, UICorner in Library.SpecificCorners do
            SetUICorner(UICorner, "TopRightRadius", HalfCurrent, RadiusHalf, RadiusUDim)
            SetUICorner(UICorner, "TopLeftRadius", HalfCurrent, RadiusHalf, RadiusUDim)
            SetUICorner(UICorner, "BottomRightRadius", HalfCurrent, RadiusHalf, RadiusUDim)
            SetUICorner(UICorner, "BottomLeftRadius", HalfCurrent, RadiusHalf, RadiusUDim)
        end

        Library.CornerRadius = Radius
        WindowInfo.CornerRadius = Radius

        ResizeButton.Position = UDim2.new(1, -Radius / 4, 0, 0)
        BottomBackground.Size = UDim2.new(1, 0, 0, 20 + Radius)

        for _, Tab in Library.Tabs do
            if Tab.IsKeyTab then
                continue
            end

            for _, Tabbox in Tab.Tabboxes do
                Tabbox:UpdateCorners()
            end
        end
    end

    local function ApplyCompact()
        IsCompact = Window:GetSidebarWidth() == WindowInfo.SidebarCompactWidth
        if WindowInfo.DisableCompactingSnap then
            IsCompact = Window:GetSidebarWidth() <= WindowInfo.CompactWidthActivation
        end

        WindowTitle.Visible = not IsCompact
        if not WindowInfo.Icon then
            WindowIcon.Visible = IsCompact
        end

        for _, Button in Library.TabButtons do
            if not Button.Icon then
                continue
            end

            Button.Label.Visible = not IsCompact
            Button.Padding.PaddingBottom = UDim.new(0, IsCompact and 6 or 11)
            Button.Padding.PaddingLeft = UDim.new(0, IsCompact and 6 or 12)
            Button.Padding.PaddingRight = UDim.new(0, IsCompact and 6 or 12)
            Button.Padding.PaddingTop = UDim.new(0, IsCompact and 6 or 11)
            Button.Icon.SizeConstraint = IsCompact and Enum.SizeConstraint.RelativeXY or Enum.SizeConstraint.RelativeYY
        end
    end

    function Window:IsSidebarCompacted()
        return IsCompact
    end

    function Window:SetCompact(State)
        Window:SetSidebarWidth(State and WindowInfo.SidebarCompactWidth or LastExpandedWidth)
    end

    function Window:GetSidebarWidth()
        return Tabs.Size.X.Offset
    end

    function Window:SetSidebarWidth(Width)
        Width = math.clamp(Width, 48, MainFrame.Size.X.Offset - WindowInfo.MinContainerWidth - 1)

        DividerLine.Position = UDim2.fromOffset(Width, 0)

        TitleHolder.Size = UDim2.new(0, Width, 1, 0)
        RightWrapper.Size = UDim2.new(1, -Width - 57 - 1, 1, -16)
        Tabs.Size = UDim2.new(0, Width, 1, -70)
        Container.Size = UDim2.new(1, -Width - 1, 1, -70)

        if WindowInfo.EnableCompacting then
            ApplyCompact()
        end
        if not IsCompact then
            LastExpandedWidth = Width
        end
    end

    function Window:ShowTabInfo(Name, Description)
        CurrentTabLabel.Text = Name
        CurrentTabDescription.Text = Description

        if IsDefaultSearchbarSize then
            SearchBox.Size = UDim2.fromScale(0.5, 1)
        end
        CurrentTabInfo.Visible = true
    end

    function Window:HideTabInfo()
        CurrentTabInfo.Visible = false
        if IsDefaultSearchbarSize then
            SearchBox.Size = UDim2.fromScale(1, 1)
        end
    end

    function Window:AddTab(...)
        local Name = nil
        local Icon = nil
        local Description = nil

        if select("#", ...) == 1 and typeof(...) == "table" then
            local Info = select(1, ...)
            Name = Info.Name or "Tab"
            Icon = Info.Icon
            Description = Info.Description
        else
            Name = select(1, ...)
            Icon = select(2, ...)
            Description = select(3, ...)
        end

        local TabButton: TextButton
        local TabLabel
        local TabIcon

        local TabContainer
        local TabLeft
        local TabRight

        Icon = Library:GetCustomIcon(Icon)
        do
            TabButton = New("TextButton", {
                BackgroundColor3 = "MainColor",
                BackgroundTransparency = 1,
                Size = UDim2.new(1, 0, 0, 40),
                Text = "",
                Parent = Tabs,
            })
            local ButtonPadding = New("UIPadding", {
                PaddingBottom = UDim.new(0, IsCompact and 6 or 11),
                PaddingLeft = UDim.new(0, IsCompact and 6 or 12),
                PaddingRight = UDim.new(0, IsCompact and 6 or 12),
                PaddingTop = UDim.new(0, IsCompact and 6 or 11),
                Parent = TabButton,
            })

            TabLabel = New("TextLabel", {
                BackgroundTransparency = 1,
                Position = UDim2.fromOffset(30, 0),
                Size = UDim2.new(1, -30, 1, 0),
                Text = Name,
                TextSize = 16,
                TextTransparency = 0.5,
                TextXAlignment = Enum.TextXAlignment.Left,
                Visible = not IsCompact,
                Parent = TabButton,
            })

            if Icon then
                TabIcon = New("ImageLabel", {
                    Image = Icon.Url,
                    ImageColor3 = Icon.Custom and "WhiteColor" or "AccentColor",
                    ImageRectOffset = Icon.ImageRectOffset,
                    ImageRectSize = Icon.ImageRectSize,
                    ImageTransparency = 0.5,
                    ScaleType = Enum.ScaleType.Fit,
                    Size = UDim2.fromScale(1, 1),
                    SizeConstraint = IsCompact and Enum.SizeConstraint.RelativeXY or Enum.SizeConstraint.RelativeYY,
                    Parent = TabButton,
                })
            end

            table.insert(Library.TabButtons, {
                Label = TabLabel,
                Padding = ButtonPadding,
                Icon = TabIcon,
            })

            --// Tab Container \\--
            TabContainer = New("Frame", {
                BackgroundTransparency = 1,
                Size = UDim2.fromScale(1, 1),
                Visible = false,
                Parent = Container,
            })

            TabLeft = New("ScrollingFrame", {
                AutomaticCanvasSize = Enum.AutomaticSize.Y,
                BackgroundTransparency = 1,
                CanvasSize = UDim2.fromScale(0, 0),
                ScrollBarImageTransparency = 1,
                ScrollBarThickness = 0,
                Size = UDim2.new(0.5, -3, 1, 0),
                Parent = TabContainer,
            })
            New("UIListLayout", {
                Padding = UDim.new(0, 2),
                Parent = TabLeft,
            })
            New("UIPadding", {
                PaddingBottom = UDim.new(0, 2),
                PaddingLeft = UDim.new(0, 2),
                PaddingRight = UDim.new(0, 2),
                PaddingTop = UDim.new(0, 2),
                Parent = TabLeft,
            })
            do
                New("Frame", {
                    BackgroundTransparency = 1,
                    LayoutOrder = -1,
                    Parent = TabLeft,
                })
                New("Frame", {
                    BackgroundTransparency = 1,
                    LayoutOrder = 1,
                    Parent = TabLeft,
                })
            end

            TabRight = New("ScrollingFrame", {
                AnchorPoint = Vector2.new(1, 0),
                AutomaticCanvasSize = Enum.AutomaticSize.Y,
                BackgroundTransparency = 1,
                CanvasSize = UDim2.fromScale(0, 0),
                Position = UDim2.fromScale(1, 0),
                ScrollBarImageTransparency = 1,
                ScrollBarThickness = 0,
                Size = UDim2.new(0.5, -3, 1, 0),
                Parent = TabContainer,
            })
            New("UIListLayout", {
                Padding = UDim.new(0, 2),
                Parent = TabRight,
            })
            New("UIPadding", {
                PaddingBottom = UDim.new(0, 2),
                PaddingLeft = UDim.new(0, 2),
                PaddingRight = UDim.new(0, 2),
                PaddingTop = UDim.new(0, 2),
                Parent = TabRight,
            })
            do
                New("Frame", {
                    BackgroundTransparency = 1,
                    LayoutOrder = -1,
                    Parent = TabRight,
                })
                New("Frame", {
                    BackgroundTransparency = 1,
                    LayoutOrder = 1,
                    Parent = TabRight,
                })
            end
        end

        --// Warning Box \\--
        local WarningBoxHolder = New("Frame", {
            AutomaticSize = Enum.AutomaticSize.Y,
            BackgroundTransparency = 1,
            Position = UDim2.fromOffset(0, 7),
            Size = UDim2.fromScale(1, 0),
            Visible = false,
            Parent = TabContainer,
        })

        local WarningBox
        local WarningBoxOutline
        local WarningBoxShadowOutline
        local WarningBoxScrollingFrame
        local WarningTitle
        local WarningStroke
        local WarningText
        do
            WarningBox = New("Frame", {
                BackgroundColor3 = "BackgroundColor",
                Position = UDim2.fromOffset(2, 0),
                Size = UDim2.new(1, -5, 0, 0),
                Parent = WarningBoxHolder,
            })
            table.insert(
                Library.Corners,
                New("UICorner", {
                    CornerRadius = UDim.new(0, WindowInfo.CornerRadius),
                    Parent = WarningBox,
                })
            )
            WarningBoxOutline, WarningBoxShadowOutline = Library:AddOutline(WarningBox)

            WarningBoxScrollingFrame = New("ScrollingFrame", {
                BackgroundTransparency = 1,
                BorderSizePixel = 0,
                Size = UDim2.fromScale(1, 1),
                CanvasSize = UDim2.new(0, 0, 0, 0),
                ScrollBarThickness = 3,
                ScrollingDirection = Enum.ScrollingDirection.Y,
                Parent = WarningBox,
            })
            New("UIPadding", {
                PaddingBottom = UDim.new(0, 4),
                PaddingLeft = UDim.new(0, 6),
                PaddingRight = UDim.new(0, 6),
                PaddingTop = UDim.new(0, 4),
                Parent = WarningBoxScrollingFrame,
            })

            WarningTitle = New("TextLabel", {
                BackgroundTransparency = 1,
                Size = UDim2.new(1, -4, 0, 14),
                Text = "",
                TextColor3 = Color3.fromRGB(255, 50, 50),
                TextSize = 14,
                TextXAlignment = Enum.TextXAlignment.Left,
                Parent = WarningBoxScrollingFrame,
            })

            WarningStroke = New("UIStroke", {
                ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
                Color = Color3.fromRGB(169, 0, 0),
                LineJoinMode = Enum.LineJoinMode.Miter,
                Parent = WarningTitle,
            })

            WarningText = New("TextLabel", {
                BackgroundTransparency = 1,
                Position = UDim2.fromOffset(0, 16),
                Size = UDim2.new(1, -4, 0, 0),
                Text = "",
                TextSize = 14,
                TextWrapped = true,
                Parent = WarningBoxScrollingFrame,
                TextXAlignment = Enum.TextXAlignment.Left,
                TextYAlignment = Enum.TextYAlignment.Top,
            })

            New("UIStroke", {
                ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
                Color = "DarkColor",
                LineJoinMode = Enum.LineJoinMode.Miter,
                Parent = WarningText,
            })
        end

        --// Tab Table \\--
        local Tab = {
            Connections = {},
            Destroyed = false,

            Groupboxes = {},
            Tabboxes = {},
            DependencyGroupboxes = {},
            Description = Description,
            Sides = {
                TabLeft,
                TabRight,
            },
            WarningBox = {
                IsNormal = false,
                LockSize = false,
                Visible = false,
                Title = "WARNING",
                Text = "",
            },
        }

        function Tab:UpdateWarningBox(Info)
            if typeof(Info.IsNormal) == "boolean" then
                Tab.WarningBox.IsNormal = Info.IsNormal
            end
            if typeof(Info.LockSize) == "boolean" then
                Tab.WarningBox.LockSize = Info.LockSize
            end
            if typeof(Info.Visible) == "boolean" then
                Tab.WarningBox.Visible = Info.Visible
            end
            if typeof(Info.Title) == "string" then
                Tab.WarningBox.Title = Info.Title
            end
            if typeof(Info.Text) == "string" then
                Tab.WarningBox.Text = Info.Text
            end

            WarningBoxHolder.Visible = Tab.WarningBox.Visible
            WarningTitle.Text = Tab.WarningBox.Title
            WarningText.Text = Tab.WarningBox.Text
            Tab:Resize(true)

            WarningBox.BackgroundColor3 = Tab.WarningBox.IsNormal == true and Library.Scheme.BackgroundColor
                or Color3.fromRGB(127, 0, 0)

            WarningBoxShadowOutline.Color = Tab.WarningBox.IsNormal == true and Library.Scheme.DarkColor
                or Color3.fromRGB(85, 0, 0)
            WarningBoxOutline.Color = Tab.WarningBox.IsNormal == true and Library.Scheme.OutlineColor
                or Color3.fromRGB(255, 50, 50)

            WarningTitle.TextColor3 = Tab.WarningBox.IsNormal == true and Library.Scheme.FontColor
                or Color3.fromRGB(255, 50, 50)
            WarningStroke.Color = Tab.WarningBox.IsNormal == true and Library.Scheme.OutlineColor
                or Color3.fromRGB(169, 0, 0)

            if not Library.Registry[WarningBox] then
                Library:AddToRegistry(WarningBox, {})
            end
            if not Library.Registry[WarningBoxShadowOutline] then
                Library:AddToRegistry(WarningBoxShadowOutline, {})
            end
            if not Library.Registry[WarningBoxOutline] then
                Library:AddToRegistry(WarningBoxOutline, {})
            end
            if not Library.Registry[WarningTitle] then
                Library:AddToRegistry(WarningTitle, {})
            end
            if not Library.Registry[WarningStroke] then
                Library:AddToRegistry(WarningStroke, {})
            end

            Library.Registry[WarningBox].BackgroundColor3 = function()
                return Tab.WarningBox.IsNormal == true and Library.Scheme.BackgroundColor or Color3.fromRGB(127, 0, 0)
            end

            Library.Registry[WarningBoxShadowOutline].Color = function()
                return Tab.WarningBox.IsNormal == true and Library.Scheme.DarkColor or Color3.fromRGB(85, 0, 0)
            end

            Library.Registry[WarningBoxOutline].Color = function()
                return Tab.WarningBox.IsNormal == true and Library.Scheme.OutlineColor or Color3.fromRGB(255, 50, 50)
            end

            Library.Registry[WarningTitle].TextColor3 = function()
                return Tab.WarningBox.IsNormal == true and Library.Scheme.FontColor or Color3.fromRGB(255, 50, 50)
            end

            Library.Registry[WarningStroke].Color = function()
                return Tab.WarningBox.IsNormal == true and Library.Scheme.OutlineColor or Color3.fromRGB(169, 0, 0)
            end
        end

        function Tab:RefreshSides()
            local Offset = WarningBoxHolder.Visible and WarningBox.Size.Y.Offset + 8 or 0
            for _, Side in Tab.Sides do
                Side.Position = UDim2.new(Side.Position.X.Scale, 0, 0, Offset)
                Side.Size = UDim2.new(0.5, -3, 1, -Offset)
            end
        end

        function Tab:Resize(ResizeWarningBox: boolean?)
            if ResizeWarningBox then
                local MaximumSize = math.floor(TabContainer.AbsoluteSize.Y / 3.25)
                local _, YText = Library:GetTextBounds(
                    WarningText.Text,
                    Library.Scheme.Font,
                    WarningText.TextSize,
                    WarningText.AbsoluteSize.X
                )

                local YBox = 24 + YText
                if Tab.WarningBox.LockSize == true and YBox >= MaximumSize then
                    WarningBoxScrollingFrame.CanvasSize = UDim2.fromOffset(0, YBox)
                    YBox = MaximumSize
                else
                    WarningBoxScrollingFrame.CanvasSize = UDim2.fromOffset(0, 0)
                end

                WarningText.Size = UDim2.new(1, -4, 0, YText)
                WarningBox.Size = UDim2.new(1, -5, 0, YBox + 4)
            end

            Tab:RefreshSides()
        end

        function Tab:AddGroupbox(Info)
            local BoxHolder = New("Frame", {
                AutomaticSize = Enum.AutomaticSize.Y,
                BackgroundTransparency = 1,
                Size = UDim2.fromScale(1, 0),
                Parent = Info.Side == 1 and TabLeft or TabRight,
            })
            New("UIListLayout", {
                Padding = UDim.new(0, 6),
                Parent = BoxHolder,
            })
            New("UIPadding", {
                PaddingBottom = UDim.new(0, 4),
                PaddingTop = UDim.new(0, 4),
                Parent = BoxHolder,
            })

            local GroupboxHolder
            local GroupboxLabel

            local GroupboxContainer
            local GroupboxList

            do
                GroupboxHolder = New("Frame", {
                    BackgroundColor3 = "BackgroundColor",
                    Size = UDim2.fromScale(1, 0),
                    Parent = BoxHolder,
                })
                table.insert(
                    Library.Corners,
                    New("UICorner", {
                        CornerRadius = UDim.new(0, WindowInfo.CornerRadius),
                        Parent = GroupboxHolder,
                    })
                )
                Library:AddOutline(GroupboxHolder)

                Library:MakeLine(GroupboxHolder, {
                    Position = UDim2.fromOffset(0, 34),
                    Size = UDim2.new(1, 0, 0, 1),
                })

                local BoxIcon = Library:GetCustomIcon(Info.IconName)
                if BoxIcon then
                    New("ImageLabel", {
                        Image = BoxIcon.Url,
                        ImageColor3 = BoxIcon.Custom and "WhiteColor" or "AccentColor",
                        ImageRectOffset = BoxIcon.ImageRectOffset,
                        ImageRectSize = BoxIcon.ImageRectSize,
                        Position = UDim2.fromOffset(6, 6),
                        Size = UDim2.fromOffset(22, 22),
                        Parent = GroupboxHolder,
                    })
                end

                GroupboxLabel = New("TextLabel", {
                    BackgroundTransparency = 1,
                    Position = UDim2.fromOffset(BoxIcon and 24 or 0, 0),
                    Size = UDim2.new(1, 0, 0, 34),
                    Text = Info.Name,
                    TextSize = 15,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    Parent = GroupboxHolder,
                })
                New("UIPadding", {
                    PaddingLeft = UDim.new(0, 12),
                    PaddingRight = UDim.new(0, 12),
                    Parent = GroupboxLabel,
                })

                GroupboxContainer = New("Frame", {
                    BackgroundTransparency = 1,
                    Position = UDim2.fromOffset(0, 35),
                    Size = UDim2.new(1, 0, 1, -35),
                    Parent = GroupboxHolder,
                })

                GroupboxList = New("UIListLayout", {
                    Padding = UDim.new(0, 8),
                    Parent = GroupboxContainer,
                })
                New("UIPadding", {
                    PaddingBottom = UDim.new(0, 7),
                    PaddingLeft = UDim.new(0, 7),
                    PaddingRight = UDim.new(0, 7),
                    PaddingTop = UDim.new(0, 7),
                    Parent = GroupboxContainer,
                })
            end

            local Groupbox = {
                Connections = {},
                Destroyed = false,

                BoxHolder = BoxHolder,
                Holder = GroupboxHolder,
                Container = GroupboxContainer,

                Tab = Tab,
                DependencyBoxes = {},
                Elements = {},
            }

            function Groupbox:Resize()
                GroupboxHolder.Size = UDim2.new(1, 0, 0, (GroupboxList.AbsoluteContentSize.Y / Library.DPIScale) + 49)
            end

            function Groupbox:Destroy()
                Groupbox.Destroyed = true

                if Groupbox.Connections then
                    for _, Connection in Groupbox.Connections do
                        Connection:Disconnect()
                    end
                end

                for _, Element in Groupbox.Elements do
                    if Element.Destroy then
                        Element:Destroy()
                    end
                end
                table.clear(Groupbox.Elements)

                for _, SubDepbox in Groupbox.DependencyBoxes do
                    if SubDepbox.Destroy then
                        SubDepbox:Destroy()
                    end
                end
                table.clear(Groupbox.DependencyBoxes)

                if GroupboxHolder then 
                    GroupboxHolder:Destroy() 
                end

                if BoxHolder then
                    BoxHolder:Destroy()
                end
            end

            setmetatable(Groupbox, BaseGroupbox)

            Groupbox:Resize()
            Tab.Groupboxes[Info.Name] = Groupbox

            return Groupbox
        end

        function Tab:AddLeftGroupbox(Name, IconName)
            return Tab:AddGroupbox({ Side = 1, Name = Name, IconName = IconName })
        end

        function Tab:AddRightGroupbox(Name, IconName)
            return Tab:AddGroupbox({ Side = 2, Name = Name, IconName = IconName })
        end

        function Tab:AddTabbox(Info)
            local BoxHolder = New("Frame", {
                AutomaticSize = Enum.AutomaticSize.Y,
                BackgroundTransparency = 1,
                Size = UDim2.fromScale(1, 0),
                Parent = Info.Side == 1 and TabLeft or TabRight,
            })
            New("UIListLayout", {
                Padding = UDim.new(0, 6),
                Parent = BoxHolder,
            })
            New("UIPadding", {
                PaddingBottom = UDim.new(0, 4),
                PaddingTop = UDim.new(0, 4),
                Parent = BoxHolder,
            })

            local TabboxHolder
            local TabboxButtons

            do
                TabboxHolder = New("Frame", {
                    BackgroundColor3 = "BackgroundColor",
                    Size = UDim2.fromScale(1, 0),
                    Parent = BoxHolder,
                })
                table.insert(
                    Library.Corners,
                    New("UICorner", {
                        CornerRadius = UDim.new(0, WindowInfo.CornerRadius),
                        Parent = TabboxHolder,
                    })
                )
                Library:AddOutline(TabboxHolder)

                TabboxButtons = New("Frame", {
                    BackgroundTransparency = 1,
                    Size = UDim2.new(1, 0, 0, 34),
                    Parent = TabboxHolder,
                })
                New("UIListLayout", {
                    FillDirection = Enum.FillDirection.Horizontal,
                    HorizontalFlex = Enum.UIFlexAlignment.Fill,
                    Parent = TabboxButtons,
                })
            end

            local TotalButtons, TotalTabs = 0, 1
            local Tabbox = {
                Connections = {},
                Destroyed = false,

                ActiveTab = nil,

                BoxHolder = BoxHolder,
                Holder = TabboxHolder,
                Tabs = {}
            }

            function Tabbox:UpdateCorners()
                for _, Tab in Tabbox.Tabs do
                    Tab:UpdateCorners()
                end
            end

            function Tabbox:AddTab(Name, IconName)
                local TabIndex = TotalTabs

                TotalButtons = TotalButtons + 1
                TotalTabs = TotalTabs + 1

                local BoxIcon = Library:GetCustomIcon(IconName)

                local Button = New("TextButton", {
                    BackgroundColor3 = "MainColor",
                    BackgroundTransparency = 0,
                    Size = UDim2.fromOffset(0, 34),
                    Text = "",
                    Parent = TabboxButtons,
                })

                local ButtonCorner = New("UICorner", {
                    TopLeftRadius = UDim.new(0, WindowInfo.CornerRadius / 2),
                    TopRightRadius = UDim.new(0, WindowInfo.CornerRadius / 2),
                    BottomRightRadius = UDim.new(0, 0),
                    BottomLeftRadius = UDim.new(0, 0),
                    Parent = Button,
                }); table.insert(Library.SpecificCorners, ButtonCorner)

                local ButtonContent = New("Frame", {
                    AnchorPoint = Vector2.new(0.5, 0.5),
                    AutomaticSize = Enum.AutomaticSize.X,
                    BackgroundTransparency = 1,
                    Position = UDim2.fromScale(0.5, 0.5),
                    Size = UDim2.fromOffset(0, 16),
                    Parent = Button,
                })
                New("UIListLayout", {
                    FillDirection = Enum.FillDirection.Horizontal,
                    HorizontalAlignment = Enum.HorizontalAlignment.Center,
                    VerticalAlignment = Enum.VerticalAlignment.Center,
                    Padding = UDim.new(0, 8),
                    Parent = ButtonContent,
                })

                local ButtonIcon
                if BoxIcon then
                    ButtonIcon = New("ImageLabel", {
                        Image = BoxIcon.Url,
                        ImageColor3 = BoxIcon.Custom and "WhiteColor" or "AccentColor",
                        ImageRectOffset = BoxIcon.ImageRectOffset,
                        ImageRectSize = BoxIcon.ImageRectSize,
                        ImageTransparency = 0.5,
                        Size = UDim2.fromOffset(16, 16),
                        Parent = ButtonContent,
                    })
                end

                local ButtonLabel = New("TextLabel", {
                    AutomaticSize = Enum.AutomaticSize.X,
                    BackgroundTransparency = 1,
                    Size = UDim2.fromOffset(0, 16),
                    Text = Name,
                    TextSize = 15,
                    TextTransparency = 0.5,
                    Parent = ButtonContent,
                })

                local Line = Library:MakeLine(Button, {
                    AnchorPoint = Vector2.new(0, 1),
                    Position = UDim2.new(0, 0, 1, 1),
                    Size = UDim2.new(1, 0, 0, 1),
                })

                local Container = New("Frame", {
                    BackgroundTransparency = 1,
                    Position = UDim2.fromOffset(0, 35),
                    Size = UDim2.new(1, 0, 1, -35),
                    Visible = false,
                    Parent = TabboxHolder,
                })
                local List = New("UIListLayout", {
                    Padding = UDim.new(0, 8),
                    Parent = Container,
                })
                New("UIPadding", {
                    PaddingBottom = UDim.new(0, 7),
                    PaddingLeft = UDim.new(0, 7),
                    PaddingRight = UDim.new(0, 7),
                    PaddingTop = UDim.new(0, 7),
                    Parent = Container,
                })

                local Tab = {
                    Connections = {},
                    Destroyed = false,

                    ButtonHolder = Button,
                    Container = Container,
                    ButtonCorner = ButtonCorner,

                    Tab = Tab,
                    Elements = {},
                    DependencyBoxes = {},
                }

                function Tab:Show()
                    if Tabbox.ActiveTab then
                        Tabbox.ActiveTab:Hide()
                    end

                    Button.BackgroundTransparency = 1

                    ButtonLabel.TextTransparency = 0
                    if ButtonIcon then
                        ButtonIcon.ImageTransparency = 0
                    end
                    Line.Visible = false

                    Container.Visible = true

                    Tabbox.ActiveTab = Tab
                    Tab:Resize()
                end

                function Tab:Hide()
                    Button.BackgroundTransparency = 0

                    ButtonLabel.TextTransparency = 0.5
                    if ButtonIcon then
                        ButtonIcon.ImageTransparency = 0.5
                    end
                    Line.Visible = true
                    Container.Visible = false

                    Tabbox.ActiveTab = nil
                end

                function Tab:Resize()
                    if Tabbox.ActiveTab ~= Tab then
                        return
                    end

                    TabboxHolder.Size = UDim2.new(1, 0, 0, (List.AbsoluteContentSize.Y / Library.DPIScale) + 49)
                end

                function Tab:UpdateCorners()
                    local Radius = WindowInfo.CornerRadius / 2

                    ButtonCorner.TopLeftRadius = UDim.new(0, TabIndex == 1 and Radius or 0)
                    ButtonCorner.TopRightRadius = UDim.new(0, TabIndex == TotalButtons and Radius or 0)
                end

                function Tab:Destroy()
                    Tab.Destroyed = true

                    if Tab.Connections then
                        for _, Connection in Tab.Connections do
                            Connection:Disconnect()
                        end
                    end

                    for _, Element in Tab.Elements do
                        if Element.Destroy then
                            Element:Destroy()
                        end
                    end

                    for _, SubDepbox in Tab.DependencyBoxes do
                        if SubDepbox.Destroy then
                            SubDepbox:Destroy()
                        end
                    end

                    if Container then
                        Container:Destroy()
                    end

                    if Button then
                        Button:Destroy()
                    end
                end

                --// Execution \\--
                if not Tabbox.ActiveTab then
                    Tab:Show()
                end

                Button.MouseButton1Click:Connect(Tab.Show)

                setmetatable(Tab, BaseGroupbox)

                Tabbox.Tabs[Name] = Tab
                Tabbox:UpdateCorners()

                return Tab
            end

            function Tabbox:Destroy()
                Tabbox.Destroyed = true

                if Tabbox.Connections then
                    for _, Connection in Tabbox.Connections do
                        Connection:Disconnect()
                    end
                end

                for _, Tab in Tabbox.Tabs do
                    if Tab.Destroy then
                        Tab:Destroy()
                    end
                end

                if TabboxHolder then
                    TabboxHolder:Destroy()
                end

                if BoxHolder then
                    BoxHolder:Destroy()
                end
            end

            if Info.Name then
                Tab.Tabboxes[Info.Name] = Tabbox
            else
                table.insert(Tab.Tabboxes, Tabbox)
            end

            return Tabbox
        end

        function Tab:AddLeftTabbox(Name)
            return Tab:AddTabbox({ Side = 1, Name = Name })
        end

        function Tab:AddRightTabbox(Name)
            return Tab:AddTabbox({ Side = 2, Name = Name })
        end

        function Tab:Hover(Hovering)
            if Library.ActiveTab == Tab then
                return
            end

            TweenService:Create(TabLabel, Library.TweenInfo, {
                TextTransparency = Hovering and 0.25 or 0.5,
            }):Play()
            if TabIcon then
                TweenService:Create(TabIcon, Library.TweenInfo, {
                    ImageTransparency = Hovering and 0.25 or 0.5,
                }):Play()
            end
        end

        function Tab:Show()
            if Library.ActiveTab then
                Library.ActiveTab:Hide()
            end

            TweenService:Create(TabButton, Library.TweenInfo, {
                BackgroundTransparency = 0,
            }):Play()
            TweenService:Create(TabLabel, Library.TweenInfo, {
                TextTransparency = 0,
            }):Play()
            if TabIcon then
                TweenService:Create(TabIcon, Library.TweenInfo, {
                    ImageTransparency = 0,
                }):Play()
            end

            if Description then
                Window:ShowTabInfo(Name, Description)
            end

            TabContainer.Visible = true
            Tab:RefreshSides()

            Library.ActiveTab = Tab

            if Library.Searching then
                Library:UpdateSearch(Library.SearchText)
            end
        end

        function Tab:Hide()
            TweenService:Create(TabButton, Library.TweenInfo, {
                BackgroundTransparency = 1,
            }):Play()
            TweenService:Create(TabLabel, Library.TweenInfo, {
                TextTransparency = 0.5,
            }):Play()
            if TabIcon then
                TweenService:Create(TabIcon, Library.TweenInfo, {
                    ImageTransparency = 0.5,
                }):Play()
            end
            TabContainer.Visible = false

            Window:HideTabInfo()

            Library.ActiveTab = nil
        end

        function Tab:SetVisible(Visible: boolean)
            TabButton.Visible = Visible

            if not Visible and Library.ActiveTab == Tab then
                Tab:Hide()
            end
        end

        function Tab:Destroy()
            Tab.Destroyed = true

            if Tab.Connections then
                for _, Connection in Tab.Connections do
                    Connection:Disconnect()
                end
            end

            for _, Groupbox in Tab.Groupboxes do
                if Groupbox.Destroy then
                    Groupbox:Destroy()
                end
            end
            table.clear(Tab.Groupboxes)

            for _, Tabbox in Tab.Tabboxes do
                if Tabbox.Destroy then
                    Tabbox:Destroy()
                end
            end
            table.clear(Tab.Tabboxes)

            for _, DepGroupbox in Tab.DependencyGroupboxes do
                if DepGroupbox.Destroy then
                    DepGroupbox:Destroy()
                end
            end

            if TabContainer then
                TabContainer:Destroy()
            end

            if TabButton then
                for Index, Entry in Library.TabButtons do
                    if typeof(Entry) == "table" and Entry.Button == TabButton then
                        table.remove(Library.TabButtons, Index)
                        break
                    end
                end
                
                TabButton:Destroy()
            end
            
            Library.Tabs[Name] = nil
        end

        --// Execution \\--
        if not Library.ActiveTab then
            Tab:Show()
        end

        TabButton.MouseEnter:Connect(function()
            Tab:Hover(true)
        end)
        TabButton.MouseLeave:Connect(function()
            Tab:Hover(false)
        end)
        TabButton.MouseButton1Click:Connect(Tab.Show)

        Library.Tabs[Name] = Tab

        return Tab
    end

    function Window:AddKeyTab(...)
        local Name = nil
        local Icon = nil
        local Description = nil

        if select("#", ...) == 1 and typeof(...) == "table" then
            local Info = select(1, ...)
            Name = Info.Name or "Tab"
            Icon = Info.Icon
            Description = Info.Description
        else
            Name = select(1, ...) or "Tab"
            Icon = select(2, ...)
            Description = select(3, ...)
        end

        Icon = Icon or "key"

        local TabButton: TextButton
        local TabLabel
        local TabIcon

        local TabContainer

        Icon = if Icon == "key" then KeyIcon else Library:GetCustomIcon(Icon)
        do
            TabButton = New("TextButton", {
                BackgroundColor3 = "MainColor",
                BackgroundTransparency = 1,
                Size = UDim2.new(1, 0, 0, 40),
                Text = "",
                Parent = Tabs,
            })
            local ButtonPadding = New("UIPadding", {
                PaddingBottom = UDim.new(0, IsCompact and 6 or 11),
                PaddingLeft = UDim.new(0, IsCompact and 6 or 12),
                PaddingRight = UDim.new(0, IsCompact and 6 or 12),
                PaddingTop = UDim.new(0, IsCompact and 6 or 11),
                Parent = TabButton,
            })

            TabLabel = New("TextLabel", {
                BackgroundTransparency = 1,
                Position = UDim2.fromOffset(30, 0),
                Size = UDim2.new(1, -30, 1, 0),
                Text = Name,
                TextSize = 16,
                TextTransparency = 0.5,
                TextXAlignment = Enum.TextXAlignment.Left,
                Visible = not IsCompact,
                Parent = TabButton,
            })

            if Icon then
                TabIcon = New("ImageLabel", {
                    Image = Icon.Url,
                    ImageColor3 = Icon.Custom and "WhiteColor" or "AccentColor",
                    ImageRectOffset = Icon.ImageRectOffset,
                    ImageRectSize = Icon.ImageRectSize,
                    ImageTransparency = 0.5,
                    Size = UDim2.fromScale(1, 1),
                    SizeConstraint = IsCompact and Enum.SizeConstraint.RelativeXY or Enum.SizeConstraint.RelativeYY,
                    Parent = TabButton,
                })
            end

            table.insert(Library.TabButtons, {
                Label = TabLabel,
                Padding = ButtonPadding,
                Icon = TabIcon,
            })

            --// Tab Container \\--
            TabContainer = New("ScrollingFrame", {
                AutomaticCanvasSize = Enum.AutomaticSize.Y,
                BackgroundTransparency = 1,
                CanvasSize = UDim2.fromScale(0, 0),
                ScrollBarThickness = 0,
                Size = UDim2.fromScale(1, 1),
                Visible = false,
                Parent = Container,
            })
            New("UIListLayout", {
                HorizontalAlignment = Enum.HorizontalAlignment.Center,
                Padding = UDim.new(0, 8),
                VerticalAlignment = Enum.VerticalAlignment.Center,
                Parent = TabContainer,
            })
            New("UIPadding", {
                PaddingLeft = UDim.new(0, 1),
                PaddingRight = UDim.new(0, 1),
                Parent = TabContainer,
            })
        end

        --// Tab Table \\--
        local Tab = {
            Elements = {},
            Description = Description,
            IsKeyTab = true,
        }

        function Tab:AddKeyBox(Callback)
            assert(typeof(Callback) == "function", "Callback must be a function")

            local Holder = New("Frame", {
                BackgroundTransparency = 1,
                Size = UDim2.new(0.75, 0, 0, 21),
                Parent = TabContainer,
            })

            local Box = New("TextBox", {
                BackgroundColor3 = "MainColor",
                PlaceholderText = "Key",
                Size = UDim2.new(1, -71, 1, 0),
                TextSize = 14,
                TextXAlignment = Enum.TextXAlignment.Left,
                Parent = Holder,
            })
            New("UIPadding", {
                PaddingLeft = UDim.new(0, 8),
                PaddingRight = UDim.new(0, 8),
                Parent = Box,
            })
            New("UIStroke", {
                Color = "OutlineColor",
                Parent = Box,
            })
            table.insert(
                Library.Corners,
                New("UICorner", {
                    CornerRadius = UDim.new(0, Library.CornerRadius / 2),
                    Parent = Box,
                })
            )

            local Button = New("TextButton", {
                AnchorPoint = Vector2.new(1, 0),
                BackgroundColor3 = "MainColor",
                Position = UDim2.fromScale(1, 0),
                Size = UDim2.new(0, 63, 1, 0),
                Text = "Execute",
                TextSize = 14,
                Parent = Holder,
            })
            New("UIStroke", {
                Color = "OutlineColor",
                Parent = Button,
            })
            table.insert(
                Library.Corners,
                New("UICorner", {
                    CornerRadius = UDim.new(0, Library.CornerRadius / 2),
                    Parent = Button,
                })
            )

            Button.InputBegan:Connect(function(Input)
                if not IsClickInput(Input) then
                    return
                end

                if not Library:MouseIsOverFrame(Button, Input.Position) then
                    return
                end

                Callback(Box.Text)
            end)
        end
        
        function Tab:Destroy()
            if TabContainer then
                TabContainer:Destroy()
            end

            if TabButton then
                for Index, Entry in Library.TabButtons do
                    if typeof(Entry) == "table" and Entry.Button == TabButton then
                        table.remove(Library.TabButtons, Index)
                        break
                    end
                end
                
                TabButton:Destroy()
            end
            
            Library.Tabs[Name] = nil
        end

        function Tab:RefreshSides() end
        function Tab:Resize() end
        function Tab:UpdateCorners() end

        function Tab:Hover(Hovering)
            if Library.ActiveTab == Tab then
                return
            end

            TweenService:Create(TabLabel, Library.TweenInfo, {
                TextTransparency = Hovering and 0.25 or 0.5,
            }):Play()
            if TabIcon then
                TweenService:Create(TabIcon, Library.TweenInfo, {
                    ImageTransparency = Hovering and 0.25 or 0.5,
                }):Play()
            end
        end

        function Tab:Show()
            if Library.ActiveTab then
                Library.ActiveTab:Hide()
            end

            TweenService:Create(TabButton, Library.TweenInfo, {
                BackgroundTransparency = 0,
            }):Play()
            TweenService:Create(TabLabel, Library.TweenInfo, {
                TextTransparency = 0,
            }):Play()
            if TabIcon then
                TweenService:Create(TabIcon, Library.TweenInfo, {
                    ImageTransparency = 0,
                }):Play()
            end
            TabContainer.Visible = true

            if Description then
                Window:ShowTabInfo(Name, Description)
            end

            Tab:RefreshSides()

            Library.ActiveTab = Tab

            if Library.Searching then
                Library:UpdateSearch(Library.SearchText)
            end
        end

        function Tab:Hide()
            TweenService:Create(TabButton, Library.TweenInfo, {
                BackgroundTransparency = 1,
            }):Play()
            TweenService:Create(TabLabel, Library.TweenInfo, {
                TextTransparency = 0.5,
            }):Play()
            if TabIcon then
                TweenService:Create(TabIcon, Library.TweenInfo, {
                    ImageTransparency = 0.5,
                }):Play()
            end
            TabContainer.Visible = false

            Window:HideTabInfo()

            Library.ActiveTab = nil
        end

        function Tab:SetVisible(Visible: boolean)
            TabButton.Visible = Visible

            if not Visible and Library.ActiveTab == Tab then
                Tab:Hide()
            end
        end

        --// Execution \\--
        if not Library.ActiveTab then
            Tab:Show()
        end

        TabButton.MouseEnter:Connect(function()
            Tab:Hover(true)
        end)
        TabButton.MouseLeave:Connect(function()
            Tab:Hover(false)
        end)
        TabButton.MouseButton1Click:Connect(Tab.Show)

        Tab.Container = TabContainer
        setmetatable(Tab, BaseGroupbox)

        Library.Tabs[Name] = Tab

        return Tab
    end

    function Window:AddDialog(Idx, Info)
        Info = Library:Validate(Info, Templates.Dialog)

        local DialogFrame
        local DialogOverlay
        local DialogContainer
        local ButtonsHolder
        local FooterButtonsList = {}

        DialogOverlay = New("TextButton", {
            AutoButtonColor = false,
            BackgroundColor3 = "DarkColor",
            BackgroundTransparency = 1,
            Size = UDim2.fromScale(1, 1),
            Text = "",
            Active = false,
            ZIndex = 9000,
            Visible = true,
            Parent = MainFrame,
        })
        TweenService:Create(DialogOverlay, Library.TweenInfo, {
            BackgroundTransparency = 0.5,
        }):Play()

        DialogFrame = New("TextButton", {
            AnchorPoint = Vector2.new(0.5, 0.5),
            BackgroundColor3 = "BackgroundColor",
            Position = UDim2.fromScale(0.5, 0.5),
            Size = UDim2.fromOffset(300, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            Text = "",
            AutoButtonColor = false,
            ZIndex = 9001,
            Parent = DialogOverlay,
        })
        table.insert(
            Library.Corners,
            New("UICorner", {
                CornerRadius = UDim.new(0, WindowInfo.CornerRadius),
                Parent = DialogFrame,
            })
        )
        Library:AddOutline(DialogFrame)

        local InnerContainer = New("Frame", {
            BackgroundTransparency = 1,
            Size = UDim2.fromScale(1, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            ZIndex = 9002,
            Parent = DialogFrame,
        })
        local DialogScale = New("UIScale", {
            Scale = 0.95,
            Parent = DialogFrame,
        })
        TweenService:Create(DialogScale, Library.TweenInfo, {
            Scale = 1
        }):Play()
        local _InnerPadding = New("UIPadding", {
            PaddingBottom = UDim.new(0, 15),
            PaddingLeft = UDim.new(0, 15),
            PaddingRight = UDim.new(0, 15),
            PaddingTop = UDim.new(0, 15),
            Parent = InnerContainer,
        })
        local _InnerLayout = New("UIListLayout", {
            Padding = UDim.new(0, 10),
            SortOrder = Enum.SortOrder.LayoutOrder,
            Parent = InnerContainer,
        })

        local HeaderContainer = New("Frame", {
            BackgroundTransparency = 1,
            Size = UDim2.fromScale(1, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            LayoutOrder = 1,
            ZIndex = 9002,
            Parent = InnerContainer,
        })
        New("UIListLayout", {
            Padding = UDim.new(0, 6),
            SortOrder = Enum.SortOrder.LayoutOrder,
            Parent = HeaderContainer,
        })
        New("UIPadding", {
            PaddingBottom = UDim.new(0, 5),
            Parent = HeaderContainer,
        })

        local TitleRow = New("Frame", {
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, 20),
            AutomaticSize = Enum.AutomaticSize.Y,
            LayoutOrder = 1,
            ZIndex = 9002,
            Parent = HeaderContainer,
        })
        New("UIListLayout", {
            Padding = UDim.new(0, 6),
            FillDirection = Enum.FillDirection.Horizontal,
            VerticalAlignment = Enum.VerticalAlignment.Center,
            SortOrder = Enum.SortOrder.LayoutOrder,
            Parent = TitleRow,
        })

        if Info.Icon then
            local ParsedIcon = Library:GetCustomIcon(Info.Icon)
            if ParsedIcon then
                local IconImg = New("ImageLabel", {
                    BackgroundTransparency = 1,
                    Size = UDim2.fromOffset(16, 16),
                    Image = ParsedIcon.Url,
                    ImageColor3 = "FontColor",
                    ImageRectOffset = ParsedIcon.ImageRectOffset,
                    ImageRectSize = ParsedIcon.ImageRectSize,
                    LayoutOrder = 1,
                    ZIndex = 9002,
                    Parent = TitleRow,
                })
                if Info.TitleColor then
                    IconImg.ImageColor3 = Info.TitleColor
                end
            end
        end

        local TitleLabel = New("TextLabel", {
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, 18),
            AutomaticSize = Enum.AutomaticSize.Y,
            Text = Info.Title,
            TextSize = 18,
            TextXAlignment = Enum.TextXAlignment.Left,
            LayoutOrder = 2,
            ZIndex = 9002,
            Parent = TitleRow,
        })
        if Info.TitleColor then
            TitleLabel.TextColor3 = Info.TitleColor
        end

        local DescriptionLabel = New("TextLabel", {
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, 14),
            AutomaticSize = Enum.AutomaticSize.Y,
            Text = Info.Description,
            TextSize = 14,
            TextTransparency = Info.DescriptionColor and 0 or 0.2,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextWrapped = true,
            LayoutOrder = 2,
            ZIndex = 9002,
            Parent = HeaderContainer,
        })
        if Info.DescriptionColor then
            DescriptionLabel.TextColor3 = Info.DescriptionColor
        end

        DialogContainer = New("Frame", {
            BackgroundTransparency = 1,
            Size = UDim2.fromScale(1, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            LayoutOrder = 4,
            ZIndex = 9002,
            Parent = InnerContainer,
        })
        local _DialogContainerLayout = New("UIListLayout", {
            Padding = UDim.new(0, 8),
            SortOrder = Enum.SortOrder.LayoutOrder,
            Parent = DialogContainer,
        })
        New("UIPadding", {
            PaddingBottom = UDim.new(0, 5),
            Parent = DialogContainer,
        })
        
        local _Sep2 = New("Frame", {
            BackgroundColor3 = "OutlineColor",
            BackgroundTransparency = 0,
            BorderSizePixel = 0,
            Size = UDim2.new(1, 0, 0, 1),
            LayoutOrder = 5,
            ZIndex = 9002,
            Parent = InnerContainer,
        })

        ButtonsHolder = New("Frame", {
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            LayoutOrder = 6,
            ZIndex = 9002,
            Parent = InnerContainer,
        })
        New("UIListLayout", {
            Padding = UDim.new(0, 8),
            FillDirection = Enum.FillDirection.Horizontal,
            HorizontalAlignment = Enum.HorizontalAlignment.Right,
            Wraps = true,
            SortOrder = Enum.SortOrder.LayoutOrder,
            Parent = ButtonsHolder,
        })
        New("UIPadding", {
            PaddingTop = UDim.new(0, 5),
            Parent = ButtonsHolder,
        })

        local Dialog = {
            Elements = {},
            Container = DialogContainer,
        }

        function Dialog:Resize()
            local MaxWidth = MainFrame.AbsoluteSize.X * 0.75
            local MinWidth = 400

            local TotalButtonWidth = 0
            local ButtonCount = 0
            local HasButtons = false

            for _, BtnWrap in FooterButtonsList do
                HasButtons = true
                ButtonCount = ButtonCount + 1
                TotalButtonWidth = TotalButtonWidth + BtnWrap.Container.Size.X.Offset
            end

            local TargetWidth = MinWidth
            if HasButtons then
                local RequiredWidth = TotalButtonWidth + ((ButtonCount - 1) * 8) + 30
                TargetWidth = math.max(MinWidth, math.min(RequiredWidth, MaxWidth))
            end

            DialogFrame.Size = UDim2.fromOffset(TargetWidth, 0)

            local _DescX, DescY = Library:GetTextBounds(DescriptionLabel.Text, Library.Scheme.Font, 14, TargetWidth - 30)
            DescriptionLabel.Size = UDim2.new(1, 0, 0, DescY)

            local HasElements = false
            for _, v in DialogContainer:GetChildren() do
                if not v:IsA("UIListLayout") and not v:IsA("UIPadding") then
                    HasElements = true
                    break
                end
            end
            DialogContainer.Visible = HasElements

            ButtonsHolder.Visible = HasButtons
            _Sep2.Visible = HasButtons
        end

        function Dialog:SetTitle(Title)
            TitleLabel.Text = Title
            Dialog:Resize()
        end

        function Dialog:SetDescription(Description)
            DescriptionLabel.Text = Description
            Dialog:Resize()
        end

        function Dialog:Dismiss()
            Library.ActiveDialog = nil
            local CloseTween = TweenService:Create(DialogScale, Library.TweenInfo, { Scale = 0.95 })
            TweenService:Create(DialogOverlay, Library.TweenInfo, { BackgroundTransparency = 1 }):Play()
            CloseTween:Play()
            
            task.delay(Library.TweenInfo.Time, function()
                DialogOverlay:Destroy()
            end)
            Library.Dialogues[Idx] = nil
        end

        DialogOverlay.MouseButton1Click:Connect(function()
            if Info.OutsideClickDismiss then
                Dialog:Dismiss()
            end
        end)

        function Dialog:RemoveFooterButton(ButtonIdx)
            if FooterButtonsList[ButtonIdx] then
                FooterButtonsList[ButtonIdx].Container:Destroy()
                FooterButtonsList[ButtonIdx] = nil
            end
        end

        function Dialog:SetButtonDisabled(ButtonIdx, Disabled)
            if FooterButtonsList[ButtonIdx] and type(FooterButtonsList[ButtonIdx].SetDisabled) == "function" then
                FooterButtonsList[ButtonIdx]:SetDisabled(Disabled)
            end
        end

        function Dialog:SetButtonOrder(ButtonIdx, Order)
            if FooterButtonsList[ButtonIdx] and FooterButtonsList[ButtonIdx].Container then
                FooterButtonsList[ButtonIdx].Container.LayoutOrder = Order
            end
        end

        function Dialog:AddFooterButton(ButtonIdx, ButtonInfo)
            Dialog:RemoveFooterButton(ButtonIdx)

            local WaitTime = ButtonInfo.WaitTime or 0

            local ButtonContainer = New("Frame", {
                BackgroundTransparency = 1,
                Size = UDim2.fromOffset(0, 26),
                LayoutOrder = ButtonInfo.Order or 0,
                ZIndex = 9002,
                Parent = ButtonsHolder,
            })
            
            local BtnColor = "MainColor"
            local BtnOutline = "OutlineColor"
            local Variant = ButtonInfo.Variant or "Primary"
            
            if Variant == "Primary" then
                BtnColor = "FontColor"
                BtnOutline = "FontColor"
            elseif Variant == "Secondary" then
                BtnColor = "MainColor"
                BtnOutline = "OutlineColor"
            elseif Variant == "Destructive" then
                BtnColor = "DestructiveColor"
                BtnOutline = "DestructiveColor"
            elseif Variant == "Ghost" then
                BtnColor = "BackgroundColor"
                BtnOutline = "BackgroundColor"
            end

            local TextBtn = New("TextButton", {
                BackgroundColor3 = BtnColor,
                BorderColor3 = BtnOutline,
                BackgroundTransparency = WaitTime > 0 and 0.5 or 0,
                Size = UDim2.fromOffset(0, 26),
                Text = "",
                AutoButtonColor = false,
                ZIndex = 9002,
                Parent = ButtonContainer,
            })
            Library:AddOutline(TextBtn)
            table.insert(
                Library.Corners,
                New("UICorner", { 
                    CornerRadius = UDim.new(0, Library.CornerRadius), 
                    Parent = TextBtn 
                })
            )

            local _BtnPadding = New("UIPadding", {
                PaddingLeft = UDim.new(0, 15),
                PaddingRight = UDim.new(0, 15),
                Parent = TextBtn,
            })

            local TextColor = Library.Scheme.FontColor
            if Variant == "Primary" then
                TextColor = Library.Scheme.BackgroundColor
            elseif Variant == "Destructive" then
                TextColor = Color3.new(1, 1, 1)
            end
            
            local BtnLabel = New("TextLabel", {
                BackgroundTransparency = 1,
                Size = UDim2.fromScale(1, 1),
                Text = ButtonInfo.Title or ButtonIdx,
                TextColor3 = TextColor,
                TextTransparency = WaitTime > 0 and 0.5 or 0,
                TextSize = 14,
                ZIndex = 9002,
                Parent = TextBtn,
            })
            
            local LabelX, _ = Library:GetTextBounds(BtnLabel.Text, Library.Scheme.Font, 14, 250)
            ButtonContainer.Size = UDim2.fromOffset(LabelX + 30, 26)
            TextBtn.Size = UDim2.fromOffset(LabelX + 30, 26)

            local ProgressBar
            if WaitTime > 0 then
                ProgressBar = New("Frame", {
                    BackgroundColor3 = "AccentColor",
                    BorderSizePixel = 0,
                    Position = UDim2.new(0, 0, 1, -2),
                    Size = UDim2.new(0, 0, 0, 2),
                    ZIndex = 2,
                    Parent = TextBtn,
                })
                table.insert(
                    Library.Corners,
                    New("UICorner", { 
                        CornerRadius = UDim.new(0, Library.CornerRadius), 
                        Parent = ProgressBar 
                    })
                )
            end

            local IsActive = WaitTime <= 0

            local ButtonWrap = {
                Container = ButtonContainer,
                SetDisabled = function(self, Disabled)
                    IsActive = not Disabled
                    if Disabled then
                        TweenService:Create(TextBtn, Library.TweenInfo, { BackgroundTransparency = 0.5 }):Play()
                        TweenService:Create(BtnLabel, Library.TweenInfo, { TextTransparency = 0.5 }):Play()
                    else
                        TweenService:Create(TextBtn, Library.TweenInfo, { BackgroundTransparency = 0 }):Play()
                        TweenService:Create(BtnLabel, Library.TweenInfo, { TextTransparency = 0 }):Play()
                    end
                end
            }

            local ActiveColor = typeof(BtnColor) == "Color3" and BtnColor or Library.Scheme[BtnColor]
            local HoverColor = Variant == "Ghost" and Library.Scheme.MainColor or Library:GetBetterColor(ActiveColor, 10)

            TextBtn.MouseEnter:Connect(function()
                if not IsActive then return end
                TweenService:Create(TextBtn, Library.TweenInfo, {
                    BackgroundColor3 = HoverColor
                }):Play()
            end)
            TextBtn.MouseLeave:Connect(function()
                if not IsActive then return end
                TweenService:Create(TextBtn, Library.TweenInfo, {
                    BackgroundColor3 = ActiveColor
                }):Play()
            end)

            TextBtn.MouseButton1Click:Connect(function()
                if not IsActive then return end
                if ButtonInfo.Callback then
                    ButtonInfo.Callback(Dialog)
                end
                if Info.AutoDismiss then
                    Dialog:Dismiss()
                end
            end)

            if WaitTime > 0 then
                TweenService:Create(ProgressBar, TweenInfo.new(WaitTime, Enum.EasingStyle.Linear), {
                    Size = UDim2.new(1, 0, 0, 2)
                }):Play()
                
                task.delay(WaitTime, function()
                    ButtonWrap:SetDisabled(false)
                    if ProgressBar then
                        TweenService:Create(ProgressBar, Library.TweenInfo, {
                            BackgroundTransparency = 1
                        }):Play()
                    end
                end)
            end

            FooterButtonsList[ButtonIdx] = ButtonWrap
        end

        for BIdx, BInfo in Info.FooterButtons do
            if type(BIdx) == "number" and BInfo.Id then BIdx = BInfo.Id end
            Dialog:AddFooterButton(BIdx, BInfo)
        end

        setmetatable(Dialog, BaseGroupbox)
        Library.Dialogues[Idx] = Dialog

        Dialog:Resize()
        
        Library.ActiveDialog = Dialog
        return Dialog
    end

    function Window:Toggle(Value: boolean?)
        if Library.ActiveLoading then
            if Value == true then
                return
            end

            if not Library.Toggled then
                return
            end
        end

        if typeof(Value) == "boolean" then
            Library.Toggled = Value
        else
            Library.Toggled = not Library.Toggled
        end

        MainFrame.Visible = Library.Toggled

        if WindowInfo.UnlockMouseWhileOpen then
            ModalElement.Modal = Library.Toggled
        end

        if Library.Toggled and not Library.IsMobile then
            local OldMouseIconEnabled = UserInputService.MouseIconEnabled
            local ShowCursorBinding = Library.ShowCursorBinding
            pcall(function()
                RunService:UnbindFromRenderStep(ShowCursorBinding)
            end)
            RunService:BindToRenderStep(ShowCursorBinding, Enum.RenderPriority.Last.Value, function()
                UserInputService.MouseIconEnabled = not Library.ShowCustomCursor

                Cursor.Position = UDim2.fromOffset(Mouse.X, Mouse.Y)
                Cursor.Visible = Library.ShowCustomCursor

                if not (Library.Toggled and ScreenGui and ScreenGui.Parent) then
                    UserInputService.MouseIconEnabled = OldMouseIconEnabled
                    Cursor.Visible = false
                    RunService:UnbindFromRenderStep(ShowCursorBinding)
                end
            end)
        elseif not Library.Toggled then
            TooltipLabel.Visible = false

            for _, Option in Library.Options do
                if Option.Type == "ColorPicker" then
                    Option.ColorMenu:Close()
                    Option.ContextMenu:Close()
                elseif Option.Type == "Dropdown" or Option.Type == "KeyPicker" then
                    Option.Menu:Close()
                end
            end
        end
    end

    function Library:Toggle(Value: boolean?)
        return Window:Toggle(Value)
    end

    if WindowInfo.EnableSidebarResize then
        local Threshold = (WindowInfo.MinSidebarWidth + WindowInfo.SidebarCompactWidth) * WindowInfo.SidebarCollapseThreshold
        local StartPos, StartWidth
        local Dragging = false
        local Changed

        local SidebarGrabber = New("TextButton", {
            AnchorPoint = Vector2.new(0.5, 0),
            BackgroundTransparency = 1,
            Position = UDim2.fromScale(0.5, 0),
            Size = UDim2.new(0, 8, 1, 0),
            Text = "",
            Parent = DividerLine,
        })
        SidebarGrabber.MouseEnter:Connect(function()
            TweenService:Create(DividerLine, Library.TweenInfo, {
                BackgroundColor3 = Library:GetLighterColor(Library.Scheme.OutlineColor),
            }):Play()
        end)
        SidebarGrabber.MouseLeave:Connect(function()
            if Dragging then
                return
            end
            TweenService:Create(DividerLine, Library.TweenInfo, {
                BackgroundColor3 = Library.Scheme.OutlineColor,
            }):Play()
        end)

        SidebarGrabber.InputBegan:Connect(function(Input: InputObject)
            if not IsClickInput(Input) then
                return
            end

            Library.CantDragForced = true

            StartPos = Input.Position
            StartWidth = Window:GetSidebarWidth()
            Dragging = true

            Changed = Input.Changed:Connect(function()
                if Input.UserInputState ~= Enum.UserInputState.End then
                    return
                end

                Library.CantDragForced = false
                TweenService:Create(DividerLine, Library.TweenInfo, {
                    BackgroundColor3 = Library.Scheme.OutlineColor,
                }):Play()

                Dragging = false
                if Changed and Changed.Connected then
                    Changed:Disconnect()
                    Changed = nil
                end
            end)
        end)

        Library:GiveSignal(UserInputService.InputChanged:Connect(function(Input: InputObject)
            if not Library.Toggled or not (ScreenGui and ScreenGui.Parent) then
                Dragging = false
                if Changed and Changed.Connected then
                    Changed:Disconnect()
                    Changed = nil
                end

                return
            end

            if Dragging and IsHoverInput(Input) then
                local Delta = Input.Position - StartPos
                local Width = StartWidth + Delta.X

                if WindowInfo.DisableCompactingSnap then
                    Window:SetSidebarWidth(Width)
                    return
                end

                if Width > Threshold then
                    Window:SetSidebarWidth(math.max(Width, WindowInfo.MinSidebarWidth))
                else
                    Window:SetSidebarWidth(WindowInfo.SidebarCompactWidth)
                end
            end
        end))
    end
    if WindowInfo.EnableCompacting and WindowInfo.SidebarCompacted then
        Window:SetSidebarWidth(WindowInfo.SidebarCompactWidth)
    end
    if WindowInfo.AutoShow and not Library.ActiveLoading then
        task.spawn(Library.Toggle)
    end

    if Library.IsMobile then
        local ToggleButton = Library:AddDraggableButton("Toggle", function()
            Library:Toggle()
        end, true, true)

        local LockButton = Library:AddDraggableButton("Lock", function(self)
            Library.CantDragForced = not Library.CantDragForced
            self:SetText(Library.CantDragForced and "Unlock" or "Lock")
        end, true, true)

        if WindowInfo.MobileButtonsSide == "Right" then
            ToggleButton.Button.AnchorPoint = Vector2.new(1, 0)
            ToggleButton.Button.Position = UDim2.new(1, -6, 0, 6)

            LockButton.Button.AnchorPoint = Vector2.new(1, 0)
            LockButton.Button.Position = UDim2.new(1, -(ToggleButton.Button.Size.X.Offset + 12), 0, 6)
        else
            ToggleButton.Button.AnchorPoint = Vector2.new(0, 0)
            ToggleButton.Button.Position = UDim2.fromOffset(6, 6)

            LockButton.Button.AnchorPoint = Vector2.new(0, 0)
            LockButton.Button.Position = UDim2.fromOffset(ToggleButton.Button.Size.X.Offset + 12, 6)
        end

        if WindowInfo.ShowMobileButtons == false then
            ToggleButton.Button.Visible = false
            LockButton.Button.Visible = false
        end
    end

    --// Execution \\--
    SearchBox:GetPropertyChangedSignal("Text"):Connect(function()
        Library:UpdateSearch(SearchBox.Text)
    end)

    Library:GiveSignal(UserInputService.InputBegan:Connect(function(Input: InputObject)
        if Library.Unloaded then
            return
        end

        if UserInputService:GetFocusedTextBox() then
            return
        end

        if
            (
                typeof(Library.ToggleKeybind) == "table"
                and Library.ToggleKeybind.Type == "KeyPicker"
                and Input.KeyCode.Name == Library.ToggleKeybind.Value
            ) or Input.KeyCode == Library.ToggleKeybind
        then
            Library.Toggle()
        end
    end))

    Library:GiveSignal(UserInputService.WindowFocused:Connect(function()
        Library.IsRobloxFocused = true
    end))
    Library:GiveSignal(UserInputService.WindowFocusReleased:Connect(function()
        Library.IsRobloxFocused = false
    end))

    return Window
end

function Library:CreateLoading(LoadingInfo)
    if Library.ActiveLoading then
        
        return Library.ActiveLoading
    end

    LoadingInfo = Library:Validate(LoadingInfo, Templates.Loading)

    local Loading = {
        CurrentStep = LoadingInfo.CurrentStep,
        TotalSteps = LoadingInfo.TotalSteps,

        ShowSidebar = LoadingInfo.ShowSidebar,
        AutoResizeHeight = LoadingInfo.AutoResizeHeight,
        IsError = false,
        Destroyed = false,

        WindowWidth = LoadingInfo.WindowWidth,
        WindowHeight = LoadingInfo.WindowHeight,
        BaseWindowHeight = LoadingInfo.WindowHeight,
        WindowErrorHeight = LoadingInfo.WindowHeight,

        ContentWidth = LoadingInfo.ContentWidth,
        SidebarWidth = LoadingInfo.SidebarWidth,
    }

    --// ScreenGui \\--
    local ScreenGui = New("ScreenGui", {
        Name = "ObsidianLoading",
        DisplayOrder = 999,
        ResetOnSpawn = false
    })
    ParentUI(ScreenGui)
    Loading.ScreenGui = ScreenGui

    ScreenGui.DescendantRemoving:Connect(function(Instance)
        Library:RemoveFromRegistry(Instance)
    end)

    --// Main Frame \\--
    local MainFrame = New("TextButton", {
        Name = "Main",
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = function()
            return Library:GetBetterColor(Library.Scheme.BackgroundColor, -1)
        end,
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromOffset(Loading.ShowSidebar and (Loading.ContentWidth + Loading.SidebarWidth) or Loading.WindowWidth, Loading.WindowHeight),
        ClipsDescendants = true,
        Text = "",
        AutoButtonColor = false,
        Parent = ScreenGui,
    })
    Library:AddOutline(MainFrame)
    table.insert(Library.Corners, New("UICorner", { CornerRadius = UDim.new(0, Library.CornerRadius), Parent = MainFrame }))
    
	local MainScale = New("UIScale", {
		Scale = Library.IsMobile and 0.8 or 1,
		Parent = MainFrame
	})
	table.insert(Library.Scales, MainScale)
	Library.ScalesOffset[MainScale] = Library.IsMobile and 0.2 or 0

    --// Layout Containers \\--
    local Container = New("Frame", {
        Name = "Content",
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(0, 0),
        Size = UDim2.new(0, Loading.ContentWidth, 1, 0),
        Parent = MainFrame,
    })

    local SideBar = New("Frame", {
        Name = "SideBar",
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(Loading.ContentWidth, 0),
        Size = UDim2.new(0, Loading.ShowSidebar and Loading.SidebarWidth or 0, 1, 0),
        ClipsDescendants = true,
        Visible = Loading.ShowSidebar,
        Parent = MainFrame,
    })
    local SidebarCorner = New("UICorner", { CornerRadius = UDim.new(0, Library.CornerRadius), Parent = SideBar })
    table.insert(Library.Corners, SidebarCorner)
    
    Library:AddOutline(SideBar)
    
    local SidebarDivider = New("Frame", {
        BackgroundColor3 = "OutlineColor",
        BorderSizePixel = 0,
        Position = UDim2.fromOffset(0, 0),
        Size = UDim2.new(0, 1, 1, 0),
        Visible = Loading.ShowSidebar,
        Parent = SideBar,
    })

    --// Top Bar \\--
    local TopBar = New("Frame", {
        Name = "TopBar",
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 48),
        ZIndex = 2,
        Parent = Container,
    })
    Library:MakeDraggable(MainFrame, TopBar, true, true)

    local TitleHolder = New("Frame", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 1, 0),
        Parent = TopBar,
    })
    New("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        HorizontalAlignment = Enum.HorizontalAlignment.Left,
        VerticalAlignment = Enum.VerticalAlignment.Center,
        Padding = UDim.new(0, 6),
        Parent = TitleHolder,
    })
    New("UIPadding", {
        PaddingLeft = UDim.new(0, 12),
        Parent = TitleHolder,
    })

    if LoadingInfo.Icon then
        local Icon = Library:GetCustomIcon(LoadingInfo.Icon)
        local _WindowIcon = New("ImageLabel", {
            Image = Icon.Url,
            ImageRectOffset = Icon.ImageRectOffset,
            ImageRectSize = Icon.ImageRectSize,
            Size = LoadingInfo.IconSize,
            Parent = TitleHolder,
        })
    else
        local _WindowIcon = New("TextLabel", {
            BackgroundTransparency = 1,
            Size = LoadingInfo.IconSize,
            Text = LoadingInfo.Title:sub(1, 1),
            TextScaled = true,
            Visible = false,
            Parent = TitleHolder,
        })
    end

    local TitleX = Library:GetTextBounds(
        LoadingInfo.Title,
        Library.Scheme.Font,
        20,
        TitleHolder.AbsoluteSize.X - (LoadingInfo.Icon and (LoadingInfo.IconSize.X.Offset + 6) or 0) - 12
    )
    local _WindowTitle = New("TextLabel", {
        BackgroundTransparency = 1,
        Size = UDim2.new(0, TitleX, 1, 0),
        Text = LoadingInfo.Title,
        TextSize = 20,
        Parent = TitleHolder,
    })

    Library:MakeLine(Container, {
        Position = UDim2.fromOffset(0, 48),
        Size = UDim2.new(1, 0, 0, 1),
    })

    --// Loading Content Elements \\--
    local InnerContent = New("Frame", {
        Name = "InnerContent",
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(0, 49),
        Size = UDim2.new(1, 0, 1, -49),
        Parent = Container,
    })

    New("UIListLayout", {
        FillDirection = Enum.FillDirection.Vertical,
        HorizontalAlignment = Enum.HorizontalAlignment.Center,
        VerticalAlignment = Enum.VerticalAlignment.Center,
        Padding = UDim.new(0, 12),
        Parent = InnerContent,
    })

    local IconHolder = New("Frame", {
        Name = "IconHolder",
        BackgroundTransparency = 1,
        Size = UDim2.fromOffset(64, 64),
        Parent = InnerContent,
    })

    local LoaderIcon = Library:GetCustomIcon(LoadingInfo.LoadingIcon)
    local LoadingIcon = New("ImageLabel", {
        Name = "LoaderIcon",
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundTransparency = 1,
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromScale(1, 1),
        Image = LoaderIcon.Url,
        ImageRectOffset = LoaderIcon.ImageRectOffset,
        ImageRectSize = LoaderIcon.ImageRectSize,
        ImageColor3 = LoadingInfo.LoadingIconColor or ((LoadingInfo.LoadingIcon == Templates.Loading.LoadingIcon) and "AccentColor" or "WhiteColor"),
        Parent = IconHolder,
    })

    local RotationTween
    if LoadingInfo.LoadingIconTweenTime > 0 then
        RotationTween = TweenService:Create(
            LoadingIcon,
            TweenInfo.new(LoadingInfo.LoadingIconTweenTime, Enum.EasingStyle.Linear, Enum.EasingDirection.Out, -1),
            { Rotation = 360 }
        )
        RotationTween:Play()
    end

    local MessageLabel = New("TextLabel", {
        BackgroundTransparency = 1,
        AutomaticSize = Loading.AutoResizeHeight and Enum.AutomaticSize.Y or Enum.AutomaticSize.XY,
        Size = Loading.AutoResizeHeight and UDim2.new(1, -60, 0, 0) or UDim2.fromOffset(0, 0),
        Text = "",
        TextSize = 18,
        TextWrapped = Loading.AutoResizeHeight,
        Parent = InnerContent,
    })

    local DescriptionLabel = New("TextLabel", {
        BackgroundTransparency = 1,
        AutomaticSize = Loading.AutoResizeHeight and Enum.AutomaticSize.Y or Enum.AutomaticSize.XY,
        Size = Loading.AutoResizeHeight and UDim2.new(1, -60, 0, 0) or UDim2.fromOffset(0, 0),
        Text = "",
        TextSize = 14,
        TextTransparency = 0.5,
        TextWrapped = Loading.AutoResizeHeight,
        Parent = InnerContent,
    })

    --// Progress Bar \\--
    local SliderBar = New("Frame", {
        BackgroundColor3 = "MainColor",
        Size = UDim2.new(0.7, 0, 0, 15),
        Parent = InnerContent,
    })
    Library:AddOutline(SliderBar)
    table.insert(Library.Corners, New("UICorner", { CornerRadius = UDim.new(0, Library.CornerRadius / 2), Parent = SliderBar }))

    local SliderFill = New("Frame", {
        BackgroundColor3 = "AccentColor",
        BorderSizePixel = 0,
        Size = UDim2.fromScale(0, 1),
        Parent = SliderBar,
    })
    table.insert(Library.Corners, New("UICorner", { CornerRadius = UDim.new(0, Library.CornerRadius / 2), Parent = SliderFill }))

    local ProgressLabel = New("TextLabel", {
        BackgroundTransparency = 1,
        Size = UDim2.fromScale(1, 1),
        Text = "",
        TextSize = 14,
        ZIndex = 2,
        Parent = SliderBar,
    })
    New("UIStroke", {
        ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
        Color = "DarkColor",
        LineJoinMode = Enum.LineJoinMode.Miter,
        Parent = ProgressLabel,
    })

    --// Sidebar Object \\--
    local SidebarScrolling = New("ScrollingFrame", {
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        Size = UDim2.fromScale(1, 1),
        ScrollBarThickness = 2,
        ScrollBarImageColor3 = "OutlineColor",
        Parent = SideBar,
    })
    local SidebarList = New("UIListLayout", {
        Padding = UDim.new(0, 8),
        SortOrder = Enum.SortOrder.LayoutOrder,
        Parent = SidebarScrolling,
    })
    New("UIPadding", {
        PaddingBottom = UDim.new(0, 12),
        PaddingLeft = UDim.new(0, 12),
        PaddingRight = UDim.new(0, 12),
        PaddingTop = UDim.new(0, 12),
        Parent = SidebarScrolling,
    })

    local SidebarObject = {
        Elements = {},
        DependencyBoxes = {},
        Tabboxes = {},
        
        BoxHolder = SidebarScrolling,
        Container = SidebarScrolling,
        
        Resize = function(self)
            SidebarScrolling.CanvasSize = UDim2.fromOffset(0, SidebarList.AbsoluteContentSize.Y + 24)
        end,
        Tab = {
            Elements = {},
            DependencyBoxes = {},
            DependencyGroupboxes = {},
            Tabboxes = {},
        },
    }

    SidebarList:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        SidebarObject:Resize()
    end)

    setmetatable(SidebarObject, BaseGroupbox)
    Loading.Sidebar = SidebarObject

    --// Error Frame \\--
    local ErrorFrame = New("Frame", {
        Name = "Error",
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(0, 49),
        Size = UDim2.new(1, 0, 1, -49),
        ClipsDescendants = true,
        Visible = false,
        Parent = Container,
    })

    local _ErrorTitle = New("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(15, 15),
        Size = UDim2.new(1, -30, 0, 18),
        Text = "Error",
        TextColor3 = "RedColor",
        TextSize = 18,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = ErrorFrame,
    })

    local ErrorLabel = New("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(15, 39),
        Size = UDim2.new(1, -30, 1, -90),
        Text = "Error Message",
        TextSize = 14,
        TextTransparency = 0.2,
        TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top,
        Parent = ErrorFrame,
    })

    local ErrorButtonsDivider = New("Frame", {
        BackgroundColor3 = "OutlineColor",
        BackgroundTransparency = 0,
        BorderSizePixel = 0,
        AnchorPoint = Vector2.new(0.5, 0),
        Position = UDim2.new(0.5, 0, 1, -48),
        Size = UDim2.new(1, -30, 0, 1),
        Visible = false,
        Parent = ErrorFrame,
    })

    local ErrorButtonsHolder = New("Frame", {
        AnchorPoint = Vector2.new(0.5, 1),
        BackgroundTransparency = 1,
        Position = UDim2.new(0.5, 0, 1, 0),
        Size = UDim2.new(1, 0, 0, 42),
        Visible = false,
        Parent = ErrorFrame,
    })
    New("UIListLayout", {
        Padding = UDim.new(0, 8),
        FillDirection = Enum.FillDirection.Horizontal,
        HorizontalAlignment = Enum.HorizontalAlignment.Right,
        VerticalAlignment = Enum.VerticalAlignment.Center,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Parent = ErrorButtonsHolder,
    })
    New("UIPadding", {
        PaddingTop = UDim.new(0, 5),
        PaddingBottom = UDim.new(0, 15),
        PaddingRight = UDim.new(0, 15),
        Parent = ErrorButtonsHolder,
    })

    function Loading:UpdateLayout()
        if Loading.IsError then
            Loading:RecalculateErrorHeight()
        end

        local ShowSidebar = Loading.ShowSidebar
        local FinalWidth = ShowSidebar and (Loading.ContentWidth + Loading.SidebarWidth) or Loading.WindowWidth
        local FinalHeight = Loading.IsError and Loading.WindowErrorHeight or Loading.WindowHeight
        
        if ShowSidebar then
            SideBar.Visible = true
            SidebarDivider.Visible = true
        end

        TweenService:Create(MainFrame, Library.TweenInfo, { Size = UDim2.fromOffset(FinalWidth, FinalHeight) }):Play()
        TweenService:Create(SideBar, Library.TweenInfo, { Position = UDim2.fromOffset(Loading.ContentWidth, 0), Size = UDim2.new(0, ShowSidebar and Loading.SidebarWidth or 0, 1, 0) }):Play()
        TweenService:Create(Container, Library.TweenInfo, { Size = UDim2.new(0, ShowSidebar and Loading.ContentWidth or Loading.WindowWidth, 1, 0) }):Play()

        if not ShowSidebar then
            task.delay(Library.TweenInfo.Time, function()
                if not Loading.ShowSidebar then
                    SideBar.Visible = false
                    SidebarDivider.Visible = false
                end
            end)
        end
    end

    --// Content Page \\--
    function Loading:RecalculateLoadingHeight()
        if not Loading.AutoResizeHeight then
            return
        end

        local RequiredHeight = 
              49 -- TopBar
            + 48 -- Padding
            + InnerContent.UIListLayout.AbsoluteContentSize.Y

        Loading.WindowHeight = math.max(Loading.BaseWindowHeight, RequiredHeight)
    end

    function Loading:SetMessage(Text)
        MessageLabel.Text = Text

        if Loading.AutoResizeHeight then
            Loading:RecalculateLoadingHeight()
            Loading:UpdateLayout()
        end
    end

    function Loading:SetDescription(Text)
        DescriptionLabel.Text = Text

        if Loading.AutoResizeHeight then
            Loading:RecalculateLoadingHeight()
            Loading:UpdateLayout()
        end
    end

    function Loading:SetLoadingIcon(Icon)
        local IconData = Library:GetCustomIcon(Icon)
        LoadingIcon.Image = IconData.Url
        LoadingIcon.ImageRectOffset = IconData.ImageRectOffset
        LoadingIcon.ImageRectSize = IconData.ImageRectSize
    end

    function Loading:SetLoadingIconTweenTime(TweenTime)
        if RotationTween then
            RotationTween:Cancel()
            RotationTween:Destroy()
        end

        if TweenTime > 0 then
            RotationTween = TweenService:Create(
                LoadingIcon,
                TweenInfo.new(TweenTime, Enum.EasingStyle.Linear, Enum.EasingDirection.Out, -1),
                { Rotation = 360 }
            )
            RotationTween:Play()
        else
            LoadingIcon.Rotation = 0
        end
    end

    function Loading:SetLoadingIconColor(Color)
        LoadingIcon.ImageColor3 = Color
    end

    function Loading:SetCurrentStep(Step)
        Loading.CurrentStep = math.clamp(Step, 0, Loading.TotalSteps)

        local Progress = Loading.CurrentStep / Loading.TotalSteps
        TweenService:Create(SliderFill, Library.TweenInfo, { Size = UDim2.fromScale(Progress, 1) }):Play()

        ProgressLabel.Text = string.format("%d/%d", Loading.CurrentStep, Loading.TotalSteps)
    end

    function Loading:SetTotalSteps(Steps)
        Loading.TotalSteps = Steps
        Loading:SetCurrentStep(Loading.CurrentStep)
    end

    --// Size \\--
    function Loading:SetWindowHeight(Height)
        Loading.WindowHeight = Height
        Loading:UpdateLayout()
    end

    function Loading:SetWindowWidth(Width)
        Loading.WindowWidth = Width
        Loading:UpdateLayout()
    end

    function Loading:SetContentWidth(Width)
        Loading.ContentWidth = Width
        Loading:UpdateLayout()
    end

    function Loading:SetSidebarWidth(Width)
        Loading.SidebarWidth = Width
        Loading:UpdateLayout()
    end

    --// Sidebar \\--
    function Loading:ShowSidebarPage(Bool)
        Loading.ShowSidebar = Bool
        Loading:UpdateLayout()
    end

    --// Error Page \\--
    function Loading:ShowErrorPage(Enabled)
        Loading.IsError = Enabled
        InnerContent.Visible = not Enabled
        ErrorFrame.Visible = Enabled

        if Loading.ShowSidebar then
            Loading:ShowSidebarPage(not Enabled)
        else
            Loading:UpdateLayout()
        end
    end

    function Loading:RecalculateErrorHeight()
        local TargetWidth = (Loading.ShowSidebar and Loading.ContentWidth or Loading.WindowWidth) - 30
        local _, ErrorY = Library:GetTextBounds(ErrorLabel.Text, Library.Scheme.Font, 14, TargetWidth)

        ErrorLabel.Size = UDim2.new(1, -30, 0, ErrorY)

        local HasButtons = ErrorButtonsHolder.Visible
        local RequiredHeight =
              49                        -- TopBar
            + 15                        -- Padding Top
            + 18                        -- Title Height
            + 6                         -- Padding between Title and Label
            + ErrorY                    -- Label Height
            + 15                        -- Padding between Label and Buttons
            + (HasButtons and 48 or 0)  -- Buttons Area

        Loading.WindowErrorHeight = RequiredHeight -- math.max(Loading.WindowHeight, RequiredHeight)
    end

    function Loading:SetErrorMessage(Text)
        ErrorLabel.Text = Text
        Loading:UpdateLayout()
    end

    function Loading:SetErrorButtons(Buttons)
        assert(typeof(Buttons) == "table", "Buttons must be a table")

        for _, button in ErrorButtonsHolder:GetChildren() do
            if button:IsA("Frame") then 
                button:Destroy() 
            end
        end

        local HasButtons = GetTableSize(Buttons) > 0
        ErrorButtonsHolder.Visible = HasButtons
        ErrorButtonsDivider.Visible = HasButtons

        for Idx, ButtonInfo in Buttons do
            local ButtonContainer = New("Frame", {
                BackgroundTransparency = 1,
                Size = UDim2.fromOffset(0, 26),
                Parent = ErrorButtonsHolder,
            })
            
            local BtnColor = "MainColor"
            local BtnOutline = "OutlineColor"
            local Variant = ButtonInfo.Variant or "Primary"
            
            if Variant == "Primary" then
                BtnColor = "FontColor"
                BtnOutline = "FontColor"
            elseif Variant == "Secondary" then
                BtnColor = "MainColor"
                BtnOutline = "OutlineColor"
            elseif Variant == "Destructive" then
                BtnColor = "DestructiveColor"
                BtnOutline = "DestructiveColor"
            elseif Variant == "Ghost" then
                BtnColor = "BackgroundColor"
                BtnOutline = "BackgroundColor"
            end

            local TextBtn = New("TextButton", {
                BackgroundColor3 = BtnColor,
                BorderColor3 = BtnOutline,
                Size = UDim2.fromOffset(0, 26),
                Text = "",
                AutoButtonColor = false,
                Parent = ButtonContainer,
            })
            Library:AddOutline(TextBtn)
            table.insert(
                Library.Corners,
                New("UICorner", { 
                    CornerRadius = UDim.new(0, Library.CornerRadius), 
                    Parent = TextBtn 
                })
            )

            New("UIPadding", {
                PaddingLeft = UDim.new(0, 15),
                PaddingRight = UDim.new(0, 15),
                Parent = TextBtn,
            })

            local TextColor = Library.Scheme.FontColor
            if Variant == "Primary" then
                TextColor = Library.Scheme.BackgroundColor
            elseif Variant == "Destructive" then
                TextColor = Color3.new(1, 1, 1)
            end

            local BtnLabel = New("TextLabel", {
                BackgroundTransparency = 1,
                Size = UDim2.fromScale(1, 1),
                Text = ButtonInfo.Title or Idx,
                TextColor3 = TextColor,
                TextSize = 14,
                Parent = TextBtn,
            })
            
            local LabelX, _ = Library:GetTextBounds(BtnLabel.Text, Library.Scheme.Font, 14, 250)
            ButtonContainer.Size = UDim2.fromOffset(LabelX + 30, 26)
            TextBtn.Size = UDim2.fromOffset(LabelX + 30, 26)

            local ActiveColor = typeof(BtnColor) == "Color3" and BtnColor or Library.Scheme[BtnColor]
            local HoverColor = Variant == "Ghost" and Library.Scheme.MainColor or Library:GetBetterColor(ActiveColor, 10)

            TextBtn.MouseEnter:Connect(function()
                TweenService:Create(TextBtn, Library.TweenInfo, {
                    BackgroundColor3 = HoverColor
                }):Play()
            end)
            TextBtn.MouseLeave:Connect(function()
                TweenService:Create(TextBtn, Library.TweenInfo, {
                    BackgroundColor3 = ActiveColor
                }):Play()
            end)

            TextBtn.MouseButton1Click:Connect(function()
                if ButtonInfo.Callback then
                    ButtonInfo.Callback(Loading)
                end
            end)
        end

        Loading:UpdateLayout()
    end

    --// Destroy/Continue \\--
    function Loading:Destroy()
        if RotationTween then
            RotationTween:Cancel()
        end

        ScreenGui:Destroy()
        Loading.Destroyed = true
        Library.ActiveLoading = nil

        if Library.Toggle and Library.Toggled == false and Library.Unloaded ~= true then
            Library:Toggle(true)
        end
    end

    Loading.Continue = Loading.Destroy;

    if Library.Toggle and Library.Toggled and Library.Unloaded ~= true then
        Library:Toggle(false)
    end

    Loading:SetCurrentStep(Loading.CurrentStep)

    Library.ActiveLoading = Loading
    return Loading
end

local function OnPlayerChange()
    if Library.Unloaded then
        return
    end

    local PlayerList, ExcludedPlayerList = GetPlayers(), GetPlayers(true)
    for _, Dropdown in Options do
        if Dropdown.Type == "Dropdown" and Dropdown.SpecialType == "Player" then
            Dropdown:SetValues(Dropdown.ExcludeLocalPlayer and ExcludedPlayerList or PlayerList)
        end
    end
end

local function OnTeamChange()
    if Library.Unloaded then
        return
    end

    local TeamList = GetTeams()
    for _, Dropdown in Options do
        if Dropdown.Type == "Dropdown" and Dropdown.SpecialType == "Team" then
            Dropdown:SetValues(TeamList)
        end
    end
end

Library:GiveSignal(Players.PlayerAdded:Connect(OnPlayerChange))
Library:GiveSignal(Players.PlayerRemoving:Connect(OnPlayerChange))

Library:GiveSignal(Teams.ChildAdded:Connect(OnTeamChange))
Library:GiveSignal(Teams.ChildRemoved:Connect(OnTeamChange))

function Library:Unload()
    Library.Unloaded = true

    --// Disconnect connections
    for Index = #Library.Signals, 1, -1 do
        local Connection = table.remove(Library.Signals, Index)

        if Connection and Connection.Connected then
            Connection:Disconnect()
        end
    end

    --// Run Unload Callbacks
    for Index = #Library.UnloadSignals, 1, -1 do
        local Callback = table.remove(Library.UnloadSignals, Index)

        if Callback then
            Library:SafeCallback(Callback)
        end
    end

    --// Destroy elements
    for Index = #Library.Tabs, 1, -1 do
        local Tab = table.remove(Library.Tabs, Index)

        if Tab and Tab.Destroy then
            Library:SafeCallback(Tab.Destroy, Tab)
        end
    end

    for Index = #Tooltips, 1, -1 do
        local Tooltip = table.remove(Tooltips, Index)

        if Tooltip and Tooltip.Destroy then
            Library:SafeCallback(Tooltip.Destroy, Tooltip)
        end
    end

    if Library.ActiveLoading then
        Library.ActiveLoading:Destroy()
    end

    if ScreenGui then
        ScreenGui:Destroy()
    end

    --// Clear tables
    table.clear(Library.Registry)

    table.clear(Options)
    table.clear(Toggles)
    table.clear(Buttons)
    table.clear(Labels)
    table.clear(Tooltips)

    table.clear(Library.Tabs)
    table.clear(Library.TabButtons)

    table.clear(Library.Scales)
    table.clear(Library.ScalesOffset)

    table.clear(Library.Corners)
    table.clear(Library.SpecificCorners)

    table.clear(Library.Notifications)
    table.clear(Library.Dialogues)
    table.clear(Library.DraggableElements)
    table.clear(Library.KeybindToggles)
    table.clear(Library.DependencyBoxes)
    
    Library.Toggle = function(...) end
    Library.ScreenGui = nil
    Library.WindowContainer = nil
    Library.KeybindFrame = nil
    Library.KeybindContainer = nil

    getgenv().Library = nil
end

getgenv().Library = Library
return Library

end
local function BundledClasses()
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

--[[
Reference [Class].SkillInfo[skilltables]
NEW SKILL = { NumberOfAttacks, AttackName, Cooldown, Type, Range }
[1] = number of attacks for the designated skill table
[2] = name of attack being referenced
    ↳ a table of attacks will treat each value as its own attack (no number added)
    ↳ if you have a table of attacks add +1 to the number of attacks for each attack in the table
    ↳ GetRemote() will always return a table of attacks
[3] = cooldown for the attack
    ↳ if a table of cooldowns is entered the script will sequentially go down the list for the number of attacks entered
        ↳ EX: { 4, "Slash", {1, 2, 3, 4}, type, range } = Slash cd 1, Slash cd 2, Slash cd 3 etc (cd = cooldown)
[4] = attack type (tables not supported)
[5] = attack range
    ↳ if a table of cooldowns is entered the script will sequentially go down the list for the number of attacks entered
        ↳ EX: { 4, "Slash", cd, type, {1, 2, 3, 4} } = Slash r 1, Slash r 2, Slash r 3 etc (r = range)
SkipFirst = don't add a number to the end of the first attack
Rollback = remove 1 from the count each iteration (use if a class has an attack that goes from Attack → Attack1 → Attack2 etc )
IncrementD = number of attacks to go through before slowly increasing the attack distance for each new attack
     ↳ EX: {1, 2}
          ↳ 1 = in place of 1 is where the attack will start adding distance to each addition value created after it for that specific attack
          ↳ 2 = in place of 2 is how much range is being added to each attack after it
AddCd = number of attacks to go through before adding more cooldown to each attack created after it (SHOULD ONLY BE USED IF INCREASE IS LINEAR)
     ↳ EX: {1, 2}
          ↳ 1 = in place of 1 is where the attack will add an additional cooldown
          ↳ 2 = in place of 2 is how much range is being added to each attack after it
]]

local function GetRemote(Class, ...) -- name of class where "Class" is and "..." is all the other remote names entered past the name to return
    local RemoteTable = {}
    for Index, RemoteName in {...} do
        table.insert(RemoteTable, Remotes:WaitForChild(string.format(
        "Skillset_%s_%s",
        Class, RemoteName
        )))
    end
    return RemoteTable
end

local ClassData = {
    Swordmaster = {
        DisplayName = "Swordmaster",
        Distance = "Melee",
        SkillInfo = {
            { 6, "Swordmaster", 0.34, "Melee", 20 }, -- m1
            { 5, "CrescentStrike", 5.1, "Ranged", 40 }, -- skill 1
            { 1, "Leap", 8.1, "Melee", 20 }, -- skill 2
            { 20, "SwordCyclone", 30.1, "Melee", 40 } -- ultimate
        }
    },
    Defender = {
        DisplayName = "Defender",
        Distance = "Melee",
        SkillInfo = {
            { 5, "Defender", 0.66, "Melee", 20 }, -- m1
            { 1, "Groundbreaker", 5.1, "Ranged", 20 }, -- skill 1
            { 8, "Spin", 8.1, "Melee", 20 }, -- skill 2
            { 1, "DefenderShield", 30.1, "Melee", 20 }, -- ultimate
            { 1, GetRemote("Defender", "Ultimate"), 1, "CFrameRemote", 20 } -- ultimate
        }
    },
    Mage = {
        DisplayName = "Arcane Mage",
        Distance = "Ranged",
        SkillInfo = {
            { 3, "Mage", 0.33, "Ranged", 65 }, -- m1
            { 2, {"ArcaneBlast", "ArcaneBlastAOE"}, 5.1, "Ranged", 45 }, -- skill 1
            { 12, "ArcaneWave", 8.1, "Ranged", 40, IncrementD = {6, 5} }, -- skill 2
            { 1, "ArcaneAscension", 30.1, "Ranged", 75 } -- ultimate
        }
    },
    DualWielder = {
        DisplayName = "Dual Wielder",
        Distance = "Melee",
        SkillInfo = {
            { 10, "DualWield", 0.55, "Melee", 20, AddCd = {5, 0.20} }, -- m1
            { 1, "DashStrike", 6.1, "Melee", 20 }, -- skill 2
            { 10, "CrossSlash", 8.1, "Ranged", 50 }, -- skill 3
            { 8, "DualWieldUltimateHit", 30.1, "Ranged", 20 }, -- ultimate
            { 4, "DualWieldUltimateSlam", 30.1, "Ranged", 20, SkipFirst = true, Rollback = true }, -- ultimate
            { 16, "DualWieldUltimateSword", 30.1, "Ranged", 20 }, -- ultimate
            { 1, GetRemote("DualWielder", "AttackBuff"), 1, "Remote", 50 } -- skill 1
        }
    },
    IcefireMage = {
        DisplayName = "Elementalist",
        Distance = "Ranged",
        SkillInfo = {
            { 3, "IcefireMage", 0.55, "Ranged", 100 }, -- m1
            { 1, "IcySpikes", 6.1, "Ranged", 40 }, -- skill 1 
            { 2, {"IcefireMageFireball", "IcefireMageFireballBlast"}, 7.1, "Ranged", 100 }, -- skill 2
            { 5, "LightningStrike", 10.1, "Ranged", 100 }, -- skill 3
            { 1, "IcefireMageUltimateFrost", 30.1, "Ranged", 100 }, -- ultimate
            { 10, "IcefireMageUltimateMeteor", 30.1, "Ranged", 100 } -- ultimate
        }
    },
    Guardian = {
        DisplayName = "Guardian",
        Distance = "Melee",
        SkillInfo = {
            { 4, "Guardian", 0.6, "Melee", 20 }, -- m1
            { 3, "RockSpikes", 6.1, "Ranged", 30, IncrementD = {2, 2.5} }, -- skill 2
            { 8, "SlashFury", 8.1, "Ranged", 30 }, -- skill 3
            { 12, "SwordPrison", 30.1, "Ranged", 120, IncrementD = {7, 10} }, -- ultimate
            { 1, GetRemote("Guardian", "AggroDraw"), 1, "Remote", 180 }, -- skill 1
            { 1, GetRemote("Guardian", "Ultimate"), 1, "GuardianRemote", 180 } -- ultimate status
        }
    },
    MageOfLight = {
        DisplayName = "Mage of Light",
        Distance = "Ranged",
        SkillInfo = {
            { 4, {"MageOfLight", "MageOfLightBlast", "MageOfLightCharged", "MageOfLightBlastCharged"}, {0.26, 0.31, 0.34, 0.34}, "Ranged", 100 }, -- m1 and m1 boosted
            { 2, GetRemote("MageOfLight", "HealCircle", "Ultimate"), 1, "Remote", 100 }, -- skill 1 and ultimate
            { 1, GetRemote("MageOfLight", "Barrier"), 1, "PlayerRemote", 100 } -- skill 3
            -- skill 2 not needed
        }
    },
    Paladin = {
        DisplayName = "Paladin",
        Distance = "Melee",
        SkillInfo = {
            { 1, "BlockingPaladin", 0.37, "Ranged", 20 }, -- skill 1
            { 4, "Paladin", 0.52, "Melee", 20 }, -- m1
            { 4, "LightPaladin", 0.52, "Melee", 20 }, -- m1 boosted
            { 3, GetRemote("Paladin", "Block", "GuildedLight", "LightThrust"), 1, "Remote", 80 }, -- skill 2 and skill 3
            { 1, GetRemote("Paladin", "Ultimate"), 1, "PlayerPositionRemote", 80 } -- ultimate
        }
    },
    Berserker = {
        DisplayName = "Berserker",
        Distance = "Melee",
        SkillInfo = {
            { 6, "Berserker", 0.51, "Melee", 20 }, -- m1
            { 1, "AggroSlam", 5.1, "Ranged", 40 }, -- skill 1
            { 8, "GigaSpin", 7.1, "Ranged", 40}, -- skill 2
            { 2, "Fissure", 10.1, "Ranged", 40 }, -- skill 3
            { 8, "FissureErrupt", 10.1, "Ranged", 60 }, -- ultimate
            { 2, GetRemote("Berserker", "AggroSlam", "Ultimate"), 1, "Remote", 60 } -- slam to take aggro and move ultimate fire and ultimate
        }
    },
    Archer = {
        DisplayName = "Spirit Archer",
        Distance = "Ranged",
        SkillInfo = {
            { 1, "Archer", 0.47, "Ranged", 80 }, -- m1
            { 9, "PiercingArrow", 5.1, "Ranged", 100 }, -- skill 1
            { 1, "SpiritBomb", 10.1, "Ranged", 210 }, -- skill 2
            { 8, "MortarStrike", 10.1, "Ranged", {60, 77, 94, 111, 128, 144, 162, 180} }, -- skill 3
            { 6, "HeavenlySword", 30.1, "Ranged", 145 }, -- ultimate
            { 1, "BackstepAttack", 3.1, "Ranged", 200 } -- dodge
        }
    },
    Dragoon = {
        DisplayName = "Dragoon",
        Distance = "Melee",
        SkillInfo = {
            { 6, "Dragoon", 0.45, "Melee", 20 }, -- m1
            { 1, "DragoonDash", 6.1, "Ranged", 20 }, -- skill 1 
            { 10, "DragoonCross", 6.1, "Ranged", 20 }, -- skill 1
            { 5, "MultiStrike", 6.1, "Melee", 20 }, -- skill 2
            { 1, "DragoonFall", 8.1, "Melee", 20 }, -- skill 3
            { 1, "DragoonUltimate", 30.1, "Ranged", 50 }, -- ultimate
            { 18, "UltimateDragon", 30.1, "Ranged", 100 }, -- ultimate
            { 1, GetRemote("Dragoon", "Ultimate"), 1, "Remote", 100 } -- ultimate
            -- other dragoon remotes are handled in main script
        }
    },
    Demon = {
        DisplayName = "Demon",
        Distance = "Melee",
        SkillInfo = {
            { 9, "DemonDPS", {0.85, 1.2, 1.5, 1.85, 2.15, 2.55, 2.9, 3.3, 3.6}, "Melee", 20 }, -- m1
            { 9, "DemonDPS*Ult", {0.85, 1.2, 1.5, 1.85, 2.15, 2.55, 2.9, 3.3, 3.6}, "Melee", 20, FormatSkill = true }, -- m1 boosted
            { 3, "ScytheThrowDPS", 5.1, "Ranged", 150 }, -- skill 2
            { 9, "ScytheThrow", 5.1, "Ranged", 150 }, -- skill 2
            { 1, "DemonLifeStealDPS", 8.1, "Ranged", 60 }, -- skill 3
            { 3, "DemonSoulDPS", 30.1, "Ranged", 30 }, -- ultimate
            { 1, GetRemote("Demon", "Ultimate"), 1, "Remote", 150 } -- ultimate
            -- skill 1 handled by main script
        }
    },
    Warlord = {
        DisplayName = "Warlord",
        Distance = "Melee",
        SkillInfo = {
            { 4, "Warlord", 0.42, "Melee", 20 }, -- m1
            { 1, "ChainsOfWar", 8.1, "Ranged", 75 }, -- skill 3
            { 1, "BlockingWarlord", 2.5, "Ranged", 20 }, -- skill 2
            { 3, "Piledriver", {5.1, 6.1, 7.1}, "Ranged", 13 }, -- skill 1
            { 5, "WarlordUltimate", 30.1, "Ranged", 55 }, -- ultimate
            { 1, GetRemote("Warlord", "Block"), 1, "Remote", 75 } -- skill 2
        }
    },
    Summoner = {
        DisplayName = "Summoner",
        Distance = "Ranged",
        SkillInfo = {
            { 4, "Summoner", {0.55, 0.75, 1.05, 1.3}, "Ranged", 80 }, -- m1
            { 5, "SoulHarvest", 1.1, "Ranged", 75 }, -- skill 3
            { 2, GetRemote("Summoner", "Summon", "Ultimate"), 1, "Remote", 80 } -- skill 1 and ultimate
        }
    },
    Assassin = {
        DisplayName = "Shadowblade",
        Distance = "Melee",
        SkillInfo = {
            { 8, "Assassin", 0.26, "Melee", 20 }, -- m1
            { 1, "ShadowLeap", 3.1, "Ranged", 50 }, -- skill 2
            { 2, "ShadowSlash", 6.1, "Ranged", 60 }, -- skill 3
            { 1, "RealmOfShadows", 30.1, "Ranged", 80 }, -- ultimate
            { 5, "ShadowMulti", 30.1, "Ranged", 60 }, -- ultimate
            { 2, GetRemote("Assassin", "EventStealthWalk", "Ultimate"), 1, "Remote", 60 } -- skill 1 and ultimate
        }
    },
    Stormcaller = {
        DisplayName = "Stormcaller",
        Distance = "Melee",
        SkillInfo = {
            { 3, "Stormcaller", 0.4, "Ranged", 100 }, -- m1
            { 8, "ChainLightning", 10.1, "Ranged", 120 }, -- skill 2
            { 2, {"StormSurgeInit", "StormSurge"}, 12.1, "Ranged", {20, 40} }, -- skill 3
            { 1, "UltimateDischarge", 1.5, "Ranged", 35 }, -- ultimate
            { 1, "StormcallerUltBlast", 30.1, "Melee", 44 }, -- ultimate
            { 8, "StormcallerThunderGod", {0.3, 0.5, 0.7, 1, 1.2, 1.6, 2, 2.3}, "Melee", 20 }, -- ultimate
            { 1, "ShockDashBall", 3.1, "Ranged", 40 }, -- dodge
            { 3, "ShockDash", 3.1, "Ranged", 40 }, -- dash
            { 1, GetRemote("Stormcaller", "Ultimate"), 1, "Remote", 120 } -- ultimate
        }
    },
    MageOfShadows = {
        DisplayName = "Mage of Shadows",
        Distance = "Ranged",
        SkillInfo = {
            { 4, {"MageOfShadows", "MageOfShadowsBlast", "MageOfShadowsCharged", "MageOfShadowsBlastCharged"} , {0.25, 0.5, 0.5, 0.5}, "Ranged", 100 }, -- m1 and m1 boosted
            { 1, "BighShadowOrb", 0.5, "Ranged", 100 }, -- skill 2
            { 1, "MageOfShadowsDamageCircle", 0.5, "Ranged", 125 }, -- skill 1
            { 1, GetRemote("MageOfShadows", "ShadowChains"), 6.1, "ShadowChain", 125 } -- skill 3
        }
    },
    Crusader = {
        DisplayName = "Crusader",
        Distance = "Melee",
        SkillInfo = {
            { 4, "Crusader", 0.31, "Melee", 20 }, -- m1
            { 4, "CrusaderRally", 6.1, "Ranged", 30 }, -- skill 1
            { 4, "CrusaderDecree", 14.1, "Ranged", 130 }, -- skill 3
            { 5, "CrusaderGloryWave", 30.1, "Ranged", 100 }, -- ultimate
            { 1, "CrusaderGloryBlast", 30.1, "Ranged", 100 }, -- ultimate
            { 4, GetRemote("Crusader", "Rally", "Armament", "LightDash", "Ultimate"), {6.1, 11.1, 2.1, 1}, "Remote", 130 }, -- skill 1, skill 2, dodge, ultimate
            { 1, GetRemote("Crusader", "Decree"), 13.1, "MobPositionRemote", 130 } -- skill 3
        }
    },
    Hunter = {
        DisplayName = "Hunter",
        Distance = "Ranged",
        SkillInfo = {
            { 3, "Hunter", 0.47, "Ranged", 80, SkipFirst = true }, -- m1
            { 5, "HunterExplosiveArrow", 4.1, "Ranged", 150, SkipFirst = true }, -- skill 1
            { 3, {"BearTrap", "BearTrapAOE", "FamiliarBurst"}, {1.1, 1.1, 5.1}, "Ranged", 150 }, -- skill 3
            { 10, "DivineArrow", 30.1, "Ranged", 150 }, -- ultimate
            { 1, "BackstepAttackHunter", 3.1, "Ranged", 150 }, -- dodge
            { 2, GetRemote("Hunter", "Summon", "Frenzy"), {15, 1}, "Remote", 150 }, -- skill 2
            { 1, GetRemote("Hunter", "ReplicateVisuals"), 1, "HunterTrapRemote", 150 }, -- skill 3
            { 1, GetRemote("Hunter", "DivineArrowHeal"), 2.5, "HunterRemote", 150 } -- ultimate
        }
    },
    Leviathan = {
        DisplayName = "Leviathan",
        Distance = "Melee",
        SkillInfo = {
            { 6, "Leviathan", 0.45, "Melee", 20 }, -- m1
            { 1, "WaterCyclone", 0.25, "Ranged", 100 }, -- skill 1
            { 1, "Mealstrom", 0.45, "Ranged", 100 }, -- skill 2
            { 1, "Hydrosurge", 5.1, "Melee", 44 }, -- skill 3
            { 1, "MaelstromBubblePop", 10.1, "Ranged", 100 }, -- combo
            { 8, "LeviathanUltimate", 30.1, "Ranged", 40 }, -- ultimate
            { 1, GetRemote("Leviathan", "PoppingBubbleDamage"), 0.1, "TableRemote", 95 } -- bubble damage
        }
    },
    Starbreaker = {
        DisplayName = "Starbreaker",
        Distance = "Melee",
        SkillInfo = {
            { 1, "StarbreakerUltimateHitInit", 30.1, "Ranged", 20 }, -- m1 ult
            { 2, "StarforgeExplosion", 25.1, "Ranged", 20 }, -- skill 3
            { 10, "StarbreakerFlare", 10.1, "Ranged", 110 }, -- skill 2
            { 4, "Nova", 7.1, "Ranged", 60 }, -- skill 1
            { 1, "StarbreakerUltimateHit", 1.51, "Ranged", 115 }, -- ult activation
            { 1, "", 1.1, "StarbreakerWaves", 20 }, -- starforge wave boost
            { 8, "StarbreakerBoosted", 0.61, "Melee", 20 }, -- m1 boosted
            { 8, "Starbreaker", 0.61, "Melee", 20 }, -- m1
            { 1, GetRemote("Starbreaker", "Starforge"), 1, "MobPositionRemote", 115 }, -- skill 3
            { 1, GetRemote("Starbreaker", "Ultimate"), 1, "Remote", 115 } -- ultimate
        }
    },
    Necromancer = {
        DisplayName = "Necromancer",
        Distance = "Melee",
        SkillInfo = {
            { 9, "NecroDPS", {0.85, 1.2, 1.5, 1.9, 2.2, 2.5, 2.8, 3.2, 3.5}, "Melee", 20 }, -- m1
            { 5, "SpiritExplosion", {2.25, 2.25, 3, 3.25, 4}, "Melee", {12, 13, 15, 17, 20}, Rollback = true }, -- skill 2
            { 5, "TombstoneRise", 4.2, "Melee", 25 }, -- skill 1
            { 6, "SpiritCavern", 10.2, "Ranged", 150 }, -- skill 3
            { 1, "UltScytheDrop", 30.1, "Ranged", 150 }, -- ultimate
            { 1, GetRemote("Necromancer", "Ultimate"), 1, "Remote", 150 } -- ultimate
        }
    },
}
return ClassData

end
local function BundledPets()
--[[
Reference [Class].SkillInfo[skilltables]
NEW SKILL = { NumberOfAttacks, AttackName, Cooldown, Type, Range }
[1] = number of attacks for the designated skill table
[2] = name of attack being referenced
    ↳ a table of attacks will treat each value as its own attack (no number added)
    ↳ if you have a table of attacks add +1 to the number of attacks for each attack in the table
[3] = cooldown for the attack
    ↳ if a table of cooldowns is entered the script will sequentially go down the list for the number of attacks entered
        ↳ EX: { 4, "Slash", {1, 2, 3, 4}, type, range } = Slash cd 1, Slash cd 2, Slash cd 3 etc (cd = cooldown)
[4] = attack type (tables not supported)
[5] = attack range
    ↳ if a table of cooldowns is entered the script will sequentially go down the list for the number of attacks entered
        ↳ EX: { 4, "Slash", cd, type, {1, 2, 3, 4} } = Slash r 1, Slash r 2, Slash r 3 etc (r = range)
SkipFirst = don't add a number to the end of the first attack
Rollback = remove 1 from the count each iteration (use if a class has an attack that goes from Attack → Attack1 → Attack2 etc )
IncrementD = number of attacks to go through before slowly increasing the attack distance for each new attack
     ↳ EX: {1, 2}
          ↳ 1 = in place of 1 is where the attack will start adding distance to each addition value created after it for that specific attack
          ↳ 2 = in place of 2 is how much range is being added to each attack after it
AddCd = number of attacks to go through before adding more cooldown to each attack created after it (SHOULD ONLY BE USED IF INCREASE IS LINEAR)
     ↳ EX: {1, 2}
          ↳ 1 = in place of 1 is where the attack will add an additional cooldown
          ↳ 2 = in place of 2 is how much range is being added to each attack after it
]]

PetData = {
    Bite = {
        SkillInfo = {
            { 1, "Bite", 15.1, "Ranged", 95 }
        }
    },
    Scratch = {
        SkillInfo = { 
            { 1, "Scratch", 15.1, "Ranged", 95 }
        }
    },
    Fireball = {
        SkillInfo = {
            { 2, {"PetFireball", "PetFireballBlast"}, 15.1, "Ranged", 95 }
        }
    },
    FireballGreen = {
        SkillInfo = {
            { 2, {"PetFireballGreen", "PetFireballBlastGreen"}, 15.1, "Ranged", 95 }
        }
    },
    Iceball = {
        SkillInfo = {
            { 2, {"PetIceball", "PetIceballBlast"}, 15.1, "Ranged", 95 }
        }
    },
    PoisonSplash = {
        SkillInfo = {
            { 1, "PetPoisonSplash", 15.1, "Ranged", 95 }
        }
    },
    HealPulse = {
        SkillInfo = {
            { 1, "PlayerPosition", 30.1, "Self", 95 }
        }
    },
    IcySpikes = {
        SkillInfo = {
            { 1, "PetIcySpikes", 15.1, "Ranged", 95 }
        }
    },
    BlackFlame = {
        SkillInfo = {
            { 6, "PetBlackFlame", 20.1, "Ranged", 95 }
        }
    },
    LightningStrike = {
        SkillInfo = {
            { 5, "PetLightningStrike", 25.1, "Ranged", 95 }
        }
    },
    DireBlast = {
        SkillInfo = {
            { 1, "PetDireBlast", 20.1, "Ranged", 95 }
        }
    },
    DragonBlast = {
        SkillInfo = {
            { 3, "PetAlphaDragon", 20.1, "Ranged", 95 }
        }
    },
    FrontalFire = {
        SkillInfo = {
            { 5, "AetherPet", 30.1, "Ranged", 95 }
        }
    },
    MiseryFire = {
        SkillInfo = {
            { 5, "MiseryPet", 30.1, "Ranged", 95 }
        }
    },
    Unknown = {
        SkillInfo = {
            { 5, "MiseryPet", 30.1, "Ranged", 95 }
        }
    },
    CerberusFire = {
        SkillInfo = {
            { 5, "CerberusFire", 30.1, "Ranged", 95 }
        }
    },
    Wildfire = {
        SkillInfo = { 
            { 5, "WildfirePet", 30.1, "Ranged", 95 }
        }
    },
    SkeletalSlash = {
        SkillInfo = {
            { 6, "SkeletalSlash", 30.1, "Ranged", 95 }
        }
    },
    DeathSlash = {
        SkillInfo = {
            { 6, "DeathSlash", 30.1, "Ranged", 95 }
        }
    },
    HoodedSlash = {
        SkillInfo = { 
             { 1, "HoodedSlash", 30.1, "Ranged", 95 }
        }
    },
    HoodedSlashPoison = {
        SkillInfo = {
            { 1, "HoodedSlashPoison", 25.1, "Ranged", 95 }
        }
    },
    PoisonBreath = {
        SkillInfo = {
            { 3, "PetPoisonBreath", 20.1, "Ranged", 95 }
        }
    },
    TetheredHeal = {
        SkillInfo = { 
             { 1, "PlayerPosition", 25.1, "Self", 95 }
        }
    },
    Barrier = {
        SkillInfo = {
            { 1, "PlayerPosition", 25.1, "Self", 95 }
        }
    },
    CrystalBarrier = {
        SkillInfo = {
            { 1, "PlayerPosition", 30.1, "Self", 95 }
        }
    },
    BlackHole = {
        SkillInfo = {
            { 10, "PetBlackHole", 30.1, "Ranged", 95 }
        }
    },
    BlackHolePumpkin = {
        SkillInfo = {
            { 10, "PetBlackHolePumpkin", 30.1, "Ranged", 95 }
        }
    },
    BlackHoleBlazing = {
        SkillInfo = {
            { 10, "PetBlackHoleBlazing", 30.1, "Ranged", 95 }
        }
    },
    BlackHoleCabbage = {
        SkillInfo = {
            { 10, "PetBlackHoleCabbage", 30.1, "Ranged", 95 }
        }
    },
    MeteorStrike = {
        SkillInfo = {
            { 8, "PetMeteorStrike", 25.1, "Ranged", 95 }
        }
    },
    AlienStrike = {
        SkillInfo = {
            { 8, "PetAlienStrike", 25.1, "Ranged", 95 }
        }
    },
    UltRing = {
        SkillInfo = {
            { 1, "PlayerPosition", 25.1, "Self", 95 }
        }
    },
    UltRingGalactic = {
        SkillInfo = {
            { 6, "PetGalactic", 25.1, "Ranged", 95 }
        }
    },
    EquinoxMist = {
        SkillInfo = {
            { 1, "PlayerPosition", 40.1, "Self", 95 }
        }
    },
    RollingJimothy = {
        SkillInfo = {
            { 4, "Jimothy", 20.1, "Ranged", 95 }
        }
    },
    BlackSheepAttack = {
        SkillInfo = {
            { 4, "BlackSheep", 20.1, "Ranged", 95 }
        }
    },
    PinkSheepAttack = {
        SkillInfo = {
            { 1, "PlayerPosition", 25.1, "Self", 95 }
        }
    },
    PurpleDragonAttack = {
        SkillInfo = {
            { 2, "PurpleDragon", 15.1, "Ranged", 95 }
        }
    },
    CyberBeamAttack = {
        SkillInfo = {
            { 2, "CyberBeam", 15.1, "Ranged", 95 }
        }
    },
    RedDragonAttack = {
        SkillInfo = {
            { 7, "RedDragon", 25.1, "Ranged", 95 }
        }
    },
    HellhoundAttack = {
        SkillInfo = {
            { 2, "HellhoundAttack", 15.1, "Ranged", 95 }
        }
    },
    PumpkinAttack = {
        SkillInfo = {
            { 1, "PumpkinAttack", 20.1, "Ranged", 95 }
        }
    },
    CupidPetShockwave = {
        SkillInfo = {
            { 1, "CupidPetShockwave", 25.1, "Ranged", 95 }
        }
    },
    SkeledileAttack = {
        SkillInfo = {
            { 9, "SkeledileAttack", 20.1, "Ranged", 95 }
        }
    },
    Whirlpool = {
        SkillInfo = {
            { 8, "WhirlpoolSmall", 25.1, "Ranged", 95 }
        }
    },
    WhirlpoolIce = {
        SkillInfo = {
            { 8, "WhirlpoolSmallIce", 20.1, "Ranged", 95 }
        }
    },
    HealReach = {
        SkillInfo = {
            { 1, "PlayerPosition", 30.1, "Self", 95 }
        }
    },
    HealReachPro = {
        SkillInfo = {
            { 1, "PlayerPosition", 30.1, "Self", 95 }
        }
    },
    RockAttack = {
        SkillInfo = {
            { 1, "PlayerPosition", 25.1, "Self", 95 }
        }
    },
    BeeAttack = {
        SkillInfo = {
            { 1, "BeeAttack", 20.1, "Ranged", 95 }
        }
    },
    BeeAttackPro = {
        SkillInfo = {
            { 4, "BeeAttack", 15.1, "Ranged", 95 }
        }
    },
    CatAttack = {
        SkillInfo = {
            { 1, "PlayerPosition", 25.1, "Self", 95 }
        }
    },
    CatAttackPro = {
        SkillInfo = {
            { 1, "PlayerPosition", 25.1, "Self", 95 }
        }
    },
    GoldenRoad = {
        SkillInfo = {
            { 1, "PlayerPosition", 25.1, "Self", 95 }
        }
    },
    GlyphAttack = {
        SkillInfo = {
            { 1, "Bite", 25.1, "Ranged", 95 },
            { 3, {"PetFireball", "PetFireballBlast", "PetIcySpikes"}, 25.1, "Ranged", 95 }
        }
    },
    GlyphAttackPro = {
        SkillInfo = {
            { 10, "PetBlackHole", 20.1, "Ranged", 95 },
            { 3, {"PetFireball", "PetFireballBlast", "PetIcySpikes"}, 20.1, "Ranged", 95 }
        }
    },
    FlameProtection = {
        SkillInfo = {
            { 6, "FlameProtection", 20.1, "Ranged", 95 }
        }
    },
    FlameProtectionPurple = {
        SkillInfo = {
            { 3, "FlameProtectionPurple", 20.1, "Ranged", 95 }
        }
    },
    AvatarFlameProtection = {
        SkillInfo = {
            { 3, "AvatarProtection", 20.1, "Ranged", 95 }
        }
    },
    PurpleSheepAttack = {
        SkillInfo = {
            { 4, "PurpleSheep", 20.1, "Ranged", 95 }
        }
    },
    MegaBite = {
        SkillInfo = {
            { 1, "MegaBite", 15.1, "Ranged", 95 }
        }
    },
    MegaBitePro = {
        SkillInfo = {
            { 1, "MegaBitePro", 15.1, "Ranged", 95 }
        }
    },
    ChocolateSplash = {
        SkillInfo = {
            { 5, "ChocolateSplash", 30.1, "Ranged", 95 }
        }
    },
    SlimeSplash = {
        SkillInfo = {
            { 5, "SlimeSplash", 30.1, "Ranged", 95 }
        }
    },
    SlimeSplashInk = {
        SkillInfo = {
            { 5, "InkSlimeSplash", 20.1, "Ranged", 95 }
        }
    },
    SlimeSplashFire = {
        SkillInfo = {
            { 5, "SlimeSplashFire", 30.1, "Ranged", 95 }
        }
    },
    SlimeSplashPoison = {
        SkillInfo = {
            { 5, "SlimeSplashPoison", 30.1, "Ranged", 95 }
        }
    },
    SlimeSplashIce = {
        SkillInfo = {
            { 5, "SlimeSplashIce", 30.1, "Ranged", 95 }
        }
    },
    Cure = {
        SkillInfo = {
            { 1, "PlayerPosition", 15.1, "Self", 95 }
        }
    },
    CurePro = {
        SkillInfo = {
            { 1, "PlayerPosition", 15.1, "Self", 95 }
        }
    },
    Snowstorm = {
        SkillInfo = {
            { 16, "PetSnowstorm", 30.1, "Ranged", 95 }
        }
    },
    CarrotStorm = {
        SkillInfo = {
            { 20, "PetCarrotStorm", 30.1, "Ranged", 95 }
        }
    },
    ShadowEssence  = {
        SkillInfo = {
            { 20, "ShadowEssence", 30.1, "Ranged", 95 }
        }
    },
    AntiStorm = {
        SkillInfo = {
            { 10, "PetAntiStorm", 30.1, "Ranged", 95 }
        }
    },
    ShiningCrystal = {
        SkillInfo = {
            { 1, "ShiningCrystal", 20.1, "Ranged", 95 }
        }
    },
    ShiningCrystalPro = {
        SkillInfo = { 
            { 1, "ShiningCrystalPro", 20.1, "Ranged", 95 }
        }
    },
    CharmingHeart = {
        SkillInfo = {
            { 4, "CharmingHeart", 25.1, "Ranged", 95 }
        }
    },
    CharmingBrokenHeart = {
        SkillInfo = {
            { 4, "CharmingBrokenHeart", 25.1, "Ranged", 95 }
        }
    },
    CharmingHeartHeal = {
        SkillInfo = {
            { 4, "CharmingHeartHeal", 25.1, "Ranged", 95 }
        }
    },
    CharmingSnowflake  = {
        SkillInfo = {
            { 4, "CharmingSnowflake", 25.1, "Ranged", 95 }
        }
    },
    SpiritBeam = {
        SkillInfo = { 
            { 5, "SpiritBeam", 20.1, "Ranged", 95 }
        }
    },
    SpiritBeamFire = {
        SkillInfo = {
            { 5, "SpiritBeamFire", 20.1, "Ranged", 95 }
        }
    },
    SpiritBeamAether = {
        SkillInfo = {
            { 5, "SpiritBeamAether", 20.1, "Ranged", 95 }
        }
    },
    SpiritBeamPoison = {
        SkillInfo = {
            { 5, "SpiritBeamPoison", 20.1, "Ranged", 95 }
        }
    },
    NaughtyOrNice = {
        SkillInfo = {
            { 1, "PlayerPosition", 25.1, "Self", 95 }
        }
    },
    TurkeyFoodDrop = {
        SkillInfo = {
            { 1, "PlayerPosition", 25.1, "Self", 95 }
        }
    },
    PenguinSlide = {
        SkillInfo = {
            { 8, "PenguinSlide", 30.1, "Ranged", 95 }
        }
    },
    PenguinSlide_Aether = {
        SkillInfo = {
            { 8, "PenguinSlide_Aether", 30.1, "Ranged", 95 }
        }
    },
    PenguinSlide_Frozen = {
        SkillInfo = {
            { 8, "PenguinSlide_Frozen", 30.1, "Ranged", 95 }
        }
    },
    PenguinSlide_Burn = {
        SkillInfo = {
            { 8, "PenguinSlide_Burn", 30.1, "Ranged", 95 }
        }
    },
    PenguinSlide_Poison = {
        SkillInfo = {
            { 8, "PenguinSlide_Poison", 30.1, "Ranged", 95 }
        }
    },
    GMMoAttack = {
        SkillInfo = {
            { 1, "PlayerPosition", 25.1, "Self", 95 }
        }
    },
    GMRodAttack = {
        SkillInfo = {
            { 1, "PlayerPosition", 25.1, "Self", 95 }
        }
    },
    GMKnoxAttack = {
        SkillInfo = {
            { 1, "KnoxAttack", 25.1, "Ranged", 95 }
        }
    },
    FireballDH = {
        SkillInfo = {
            { 8, "PetFireballDH", 15.1, "Ranged", 95 },
            { 2, {"PetFireball", "PetFireballBlast"}, 15.1, "Ranged", 95 }
        }
    },
    GargoyleSkill = {
        SkillInfo = {
            { 5, "GargoyleSkill", 30.1, "Ranged", 95 }
        }
    },
    MoltenGolemAttack = {
        SkillInfo = {
            { 4, "MoltenGolemAttack", 25.1, "Ranged", 95 }
        }
    },
    EvilClownSkill = {
        SkillInfo = {
            { 1, "PlayerPosition", 30.1, "MobPosition", 95 }
        }
    },
    TrippleFireball = {
        SkillInfo = {
            { 3, "PetFireball", 15.1, "Ranged", 95, SkipFirst = true },
            { 3, "PetFireballBlast", 15.1, "Ranged", 95, SkipFirst = true }
        }
    },
    IceShards = {
        SkillInfo = {
            { 5, "PetIceShards", 15.1, "Ranged", 95 }
        }
    },
    ToxicThorns = {
        SkillInfo = {
            { 4, "PetToxicThorns", 20.1, "Ranged", 95 }
        }
    },
    IgnisDragonPetAttack = {
        SkillInfo = {
            { 8, "IgnisDragonPetAttack", 15.1, "Ranged", 95 }
        }
    },
    RuinousDragonPetAttack = {
        SkillInfo = {
            { 8, "RuinousDragonPetAttack", 15.1, "Ranged", 95 }
        }
    },
    PinataParty = {
        SkillInfo = {
            { 10, "PetPinataParty", 20.1, "Ranged", 95 }
        }
    },
    NoobTornado = {
        SkillInfo = {
            { 8, "PetNoobTornado", 25.1, "Ranged", 95 }
        }
    }
}

return PetData

end
if not game:IsLoaded() then game.Loaded:Wait() end

-- || CHECK IF IN WORLD ZERO ||
if tostring(game.GameId) ~= "985731078" then -- set to string or obfuscation can mess it up
    return
end

local ScriptLoadingStart = os.clock()
local function SetGlobal(_) end
-- || CREATE GUI ELEMENTS ||
local function MakeGuiElement(Type, ...)
    local NewUI = Instance.new(Type)
    local GuiTable = ...
    for Element, Data in GuiTable do
        NewUI[Element] = Data
    end
    return NewUI
end

local EF = {}
-- || EXECUTOR FUNCTIONS ||
SetGlobal("getting executor references")
EF.Hook = hookfunc or hookfunction or nil
EF.ClearHook = restorefunc or restorefunction or nil
EF.RaknetFunction = rnet or raknet or RakNet or nil
EF.Desync = (EF.RaknetFunction and EF.RaknetFunction.desync) or nil
EF.HideGui = get_hidden_gui or gethui or gethiddengui or get_hidden_ui or gethiddenui or nil
EF.NewClosure = newcclosure or nil
EF.CloneRef = cloneref or clonereference or function(value) return value end
EF.CheckHook = ishooked or isfunctionhooked or is_hooked or is_function_hooked or nil

-- || RETURN SERVICE ||
-- Native game modules expect normal script identity. Always restore the caller
-- before updating the executor's protected UI, including after errors/yields.
local function GameCall(callback,...)
    local setter=setthreadidentity or setidentity
    local getter=getthreadidentity or getidentity
    local previous,changed
    if type(setter)=="function" and type(getter)=="function" then
        local ok,value=pcall(getter)
        if ok then previous=value changed=pcall(setter,2)end
    end
    local results=table.pack(pcall(callback,...))
    if changed then pcall(setter,previous)end
    return table.unpack(results,1,results.n)
end

SetGlobal("return things for the script")
local function ReturnService(Service)
    local ReturnService = game:GetService(Service)
    if ReturnService then
        return EF.CloneRef(ReturnService)
    else
        
    end
end

-- || RETURN ATTRIBUTE ||
local function WaitForAttribute(Parent, Attribute)
    repeat task.wait() until Parent:GetAttribute(Attribute)
    return Parent:GetAttribute(Attribute)
end

-- || ROBLOX SERVICES ||
SetGlobal("getting Service paths")
local Workspace = ReturnService("Workspace")
local Players = ReturnService("Players")
local CoreGui = ReturnService("CoreGui")
local StarterGui = ReturnService("StarterGui")
local ReplicatedStorage = ReturnService("ReplicatedStorage")
local HttpService = ReturnService("HttpService")
local VirtualUser = ReturnService("VirtualUser")
local RunService = ReturnService("RunService")
local MarketplaceService = ReturnService("MarketplaceService")
local TeleportService = ReturnService("TeleportService")
local TweenService = ReturnService("TweenService")

-- || RETURN CHILD ||
SetGlobal("getting ReplicatedStorage paths")
local function ReturnChild(Parent, Child)
    return EF.CloneRef(Parent:WaitForChild(Child, math.huge))
end

local Shared = ReturnChild(ReplicatedStorage, "Shared")
local SharedAssets = ReturnChild(ReplicatedStorage, "SharedAssets")
local Remotes = ReturnChild(ReplicatedStorage, "Remotes")
local Client = ReturnChild(ReplicatedStorage, "Client")

-- || GAME SCRIPTS ||
SetGlobal("getting ReplicatedStorage child paths")
local function GetShared(Script)
    return EF.CloneRef(Shared:WaitForChild(Script, math.huge))
end

local function GetSharedAsset(Script)
    return EF.CloneRef(SharedAssets:WaitForChild(Script, math.huge))
end
local Battlepass = GetShared("Battlepass")
local Charms = GetShared("Charms")
local Chests = GetShared("Chests")
local Drops = GetShared("Drops")
local Effects = GetShared("Effects")
local Health = GetShared("Health")
local Inventory = GetShared("Inventory")
local Items = GetShared("Items")
local Missions = GetShared("Missions")
local SMobs = GetShared("Mobs")
local ModelProvider = GetShared("ModelProvider")
local Party = GetShared("Party")
local Pets = GetShared("Pets")
local Quests = GetShared("Quests")
local Shop = GetSharedAsset("Shop")
local Skills = GetShared("Skills")
local Teleport = GetShared("Teleport")
local WalkspeedManager = GetShared("WalkspeedManager")

-- || GAME VARIABLES ||
SetGlobal("getting Workspace child paths")
local Camera = ReturnChild(Workspace, "Camera")
local Mobs = ReturnChild(Workspace, "Mobs")
local MissionObjects

-- || SCRIPT VARIABLES ||
SetGlobal("setting up script dependencies")
local Library
local SaveManager
local Options
local Toggles
local ScriptUnloaded
local SV = {}
SV.SafeMode = true
SV.Drops = {}
local ISV = {}
ISV.MobTable = {}
local ConnectionTable = {}
local AvoidMobs = {}
local TeleportParts = {}
local StatTotals = {}
local AntiCheatNumber = 67
local Class
local ClassSkills
local PetSkills
local LocalPlayer = Players.LocalPlayer
local PlayerName = LocalPlayer.Name
local PlayerID = LocalPlayer.UserId
local PlayerGui = ReturnChild(LocalPlayer, "PlayerGui")
local PlayerPing = 0
local PlayerProfile
local ProfileInventory
local PlayerCharacter
local PlayerCollider
local PlayerRoot
local AddedDelay = 0
local Xdistance = 0
local Ydistance = 0
local TempStop
local HoldForRealTime
local RestartAtFloor = 200
local CurrentMob
local IsMobCamera
local KillSwitch
local KeepTier = 5
local SellItemCheck = 0
local OffsetMax = 0
local EquipInProgress = 0
local MobRotationSpeed = 20
local DelayPetAttacks
local IsAliveMobs = 0

local TeleportMob
local StuckDelay = 60
local DelayAttacks
local IsBoss
local EventOverride
local CanTarget = true
local PingMultiplier = 1
local PlayerStandPart = nil
local StandPartHeight = nil

do
    ConnectionTable["ConnectNewCharacter"] = LocalPlayer.CharacterAdded:Connect(function(NewCharacter)
        PlayerCharacter = NewCharacter
        PlayerRoot = NewCharacter:WaitForChild("HumanoidRootPart", math.huge)
        PlayerCollider = NewCharacter:WaitForChild("Collider", math.huge)
    end)
    if LocalPlayer.Character then
        PlayerCharacter = LocalPlayer.Character
    end
    if PlayerCharacter and PlayerCharacter:FindFirstChild("HumanoidRootPart") then
        PlayerRoot = PlayerCharacter.HumanoidRootPart
    end
    if PlayerCharacter and PlayerCharacter:FindFirstChild("Collider") then
        PlayerCollider = PlayerCharacter.Collider
    end
end

-- || IDENTIFY LOCATION ||
SetGlobal("setting up location identifier")
local StringPlaceID = tostring(game.PlaceId)
local IsWorld = false
local IsMainMenu = false
local IsDungeon = false
local IsTower = false

local Locations = {
    MainMenu = {
        ["2727067538"] = true -- main menu
    },
    WorldHubs = {
        ["4310463616"] = true, -- world 1
        ["4310463940"] = true, -- world 2
        ["4465987684"] = true, -- world 3
        ["4646472003"] = true, -- world 4
        ["5703355191"] = true, -- world 5
        ["6075083204"] = true, -- world 6
        ["6847035264"] = true, -- world 7
        ["9944262922"] = true, -- world 8
        ["10651517727"] = true, -- world 9
        ["14914684761"] = true, -- world 10
        ["7499964980"] = true, -- market
        ["6510868181"] = true, -- pvp
        ["139316833473171"] = true, -- guild hub
        ["105045973347410"] = true, -- guild hall
        ["87656507991995"] = true, -- valentines hub
        ["100868012981049"] = true, -- easter hub
        ["18567064955"] = true, -- vane hub
        ["125645867930579"] = true, -- kraken hub
        ["5862275930"] = true, -- halloween hub
        ["4526768266"] = true, -- holiday hub
        ["111346137875750 "] = true, -- market house
        ["73832225581864"] = true, -- w1 house
        ["84106607802351"] = true, -- w2 house
        ["136326194224398"] = true, -- w3 house
        ["73334696605120"] = true, -- w7 house
        ["104886402902960"] = true -- og world 1
    },
    Dungeons = {
        ["107701891477606"] = 49, -- 1-1 tutorial
        ["83712338696299"] = 54, -- chad tutorial
        ["2978696440"] = 1, -- 1-1
        ["4310476380"] = 3, -- 1-2
        ["4310464656"] = 2, -- 1-3
        ["4310478830"] = 4, -- 1-4
        ["3383444582"] = 6, -- 1-5
        ["3885726701"] = 11, -- 2-1
        ["3994953548"] = 12, -- 2-2
        ["4050468028"] = 13, -- 2-3
        ["3165900886"] = 7, -- 2-4
        ["4465988196"] = 14, -- 3-1
        ["4465989351"] = 15, -- 3-2
        ["4465989998"] = 16, -- 3-3
        ["4646473427"] = 20, -- 4-1
        ["4646475342"] = 19, -- 4-2
        ["4646475570"] = 18, -- 4-3
        ["6386112652"] = 24, -- 5-1
        ["11466514043"] = 35, -- 5-2
        ["6510862058"] = 25, -- 6-1
        ["11533444995"] = 36, -- 6-2
        ["6847034886"] = 26,  -- 7-1
        ["11644048314"] = 37, -- 7-2
        ["9944263348"] = 30, -- 8-1
        ["10014664329"] = 31, -- 8-2
        ["10651527284"] = 32, -- 9-1
        ["10727165164"] = 33, -- 9-2
        ["14914700740"] = 41, -- 10-1
        ["14914855930"] = 42, -- 10-2
        ["128961185668563"] = 53 -- heavenly raid
    },
    EventDungeons = {
        ["93889085342251"] = 51, -- graffiti beach
        ["102111805987017"] = 47, -- hunt 2025
        ["81373988789544"] = 46, -- cupid arena
        ["109614960834199"] = 50, -- alien invasion arena
        ["138178936582742"] = 48, -- zero arena
        ["110769392907898"] = 52, -- easter arena
        ["75540798045662"] = 45, -- kraken arena
        ["18567068844"] = 44, -- vane arena
        ["5862277651"] = 22, -- fallen anrea
        ["4526768588"] = 17 -- klaus arena
    },
    Towers = {
        ["5703353651"] = 21, -- tower 1
        ["6075085184"] = 23, -- tower 2
        ["7071564842"] = 27, -- tower 3
        ["10089970465"] = 29, -- tower 4
        ["10795158121"] = 34, -- tower 5
        ["15121292578"] = 43, -- tower 6
        ["14400549310"] = 39, -- celestial tower
        ["13988110964"] = 38 -- infinite tower
        --["130171241672058"] = 56 -- og tower
    }
}
if Locations.MainMenu[StringPlaceID] then
    IsMainMenu = true
    
elseif Locations.WorldHubs[StringPlaceID] then
    IsWorld = true
    
elseif Locations.Dungeons[StringPlaceID] then
    IsDungeon = true
    
elseif Locations.Towers[StringPlaceID] then
    IsDungeon = true
    IsTower = true
    
elseif Locations.EventDungeons[StringPlaceID] then
    IsEventDungeon = true
    IsDungeon = true
    
else
    IsWorld = true
    
end

-- || FIND CURRENT DUNGEON AND DELETE TABLE ||
if not (IsWorld or IsMainMenu) then
    ISV.CurrentDungeonID = Locations.EventDungeons[StringPlaceID] or Locations.Dungeons[StringPlaceID] or Locations.Towers[StringPlaceID] or nil
end
Locations = nil

SetGlobal("request message")
SetGlobal("save script to files")
SetGlobal("creating script tables")
SV.DungeonPartList = {
    { "MissionStart", DescendantCheck = true },
    DeleteParts = {
        { "MissionObjects", "DamageDroppers" }, { "TeleportSystem", MultipleExists = true }, { "MissionObjects", "FallAreas" }
    }
}
SV.WheelItems = {
    "WebbedWings", "WispLantern", "CrowKing", "CrowQueen", "CastingShadow",
    "AstralHorns", "DreamCatcherHalo", "SpiderCrown"
}
SV.SpecialHexColors = {
	"ffffff", "000000", "e6e6e6", "1e1e1e", "d4af37",
    "ff1337", "11ccee", "ffaabb", "ddeadd", "dec0de",
    "b00000", "bbaadd", "c0aa11", "00bdae", "55eeaa",
    "ffaded", "beeeee", "ffaaee", "ac11dd", "acce55",
    "ff0011", "decade", "deeeed", "deeee1", "b1a2ed",
    "aaaaaa"
}
SV.EggList = {
    'StarEgg', 'JungleEgg', 'CrystalEgg', 'ChristmasEgg', 'DesertEgg',
    'MoltenEgg', 'OceanEgg', 'SkyEgg', 'CatEgg', 'CatEggHalloween',
    'AlligatorEgg', 'FairyEgg', 'AetherEgg', 'CabbageEgg', 'SkeletonEgg',
    'CupidEgg', 'SlimeEgg', 'TeddyEgg', 'SantaEgg', 'ArcaneEgg',
    'GhostEgg', 'PenguinEgg', 'RobloxEventEggHatchable', 'GoldenEgg', 'MiseryEgg',
    'BunnyEgg', 'RheaEgg', "SuperCrystalEgg", "SuperDesertEgg", "SuperFairyEgg",
    "SuperStarEgg", "SuperMoltenEgg", "VoidEgg", "SuperArcaneEgg", "EasterPetEgg",
    "SuperSkyEgg", "SuperAlligatorEgg", "SuperOceanEgg", "SuperJungleEgg"
}
SV.TowerEggList = {
    ["MoltenEgg"] = true,
    ["OceanEgg"] = true,
    ["SkyEgg"] = true,
    ["AlligatorEgg"] = true,
    ["FairyEgg"] = true,
    ["ArcaneEgg"] = true
}
SV.DungeonListTable = {
    { Level = 175, DungeonName = "Nightmare Portal", DungeonDelay = 60, DungeonID = 1005 },
    { Level = 135, DungeonName = "Astral Academy", DungeonDelay = 135, DungeonID = 42, SpecialPerk = true },
    { Level = 130, DungeonName = "Crystal Chaos", DungeonDelay = 115, DungeonID = 41, SpecialPerk = true },
    { Level = 120, DungeonName = "Aether Fortress", DungeonDelay = 45, DungeonID = 33 },
    { Level = 115, DungeonName = "Treetop Trouble", DungeonDelay = 90, DungeonID = 32 },
    { Level = 105, DungeonName = "Ruin Rush", DungeonDelay = 65, DungeonID = 31, SpecialPerk = true },
    { Level = 100, DungeonName = "Rescue in the Ruins", DungeonDelay = 78, DungeonID = 30, SpecialPerk = true },
    { Level = 95, DungeonName = "The Labyrinth", DungeonDelay = 20, DungeonID = 37 },
    { Level = 90, DungeonName = "The Underworld", DungeonDelay = 85, DungeonID = 26 },
    { Level = 80, DungeonName = "Treasure Hunt", DungeonDelay = 36, DungeonID = 36, SpecialPerk = true },
    { Level = 75, DungeonName = "Rough Waters", DungeonDelay = 55, DungeonID = 25, SpecialPerk = true },
    { Level = 65, DungeonName = "Konoh Inferno", DungeonDelay = 40, DungeonID = 35 },
    { Level = 60, DungeonName = "Konoh Heartlands", DungeonDelay = 45, DungeonID = 24 },
    { Level = 55, DungeonName = "Pyramid Dungeon", DungeonDelay = 40, DungeonID = 18 },
    { Level = 50, DungeonName = "Deserted Burrowmine", DungeonDelay = 40, DungeonID = 19 },
    { Level = 45, DungeonName = "Scrap Canyon", DungeonDelay = 50, DungeonID = 20 },
    { Level = 40, DungeonName = "Winter Dungeon", DungeonDelay = 60, DungeonID = 16, SpecialPerk = true },
    { Level = 35, DungeonName = "Winter Cavern", DungeonDelay = 20, DungeonID = 15, SpecialPerk = true },
    { Level = 30, DungeonName = "Mountain Pass", DungeonDelay = 35, DungeonID = 14, SpecialPerk = true },
    { Level = 26, DungeonName = "Volcano Dungeon", DungeonDelay = 40, DungeonID = 7, SpecialPerk = true },
    { Level = 22, DungeonName = "Volcano's Shadow", DungeonDelay = 59, DungeonID = 13, SpecialPerk = true },
    { Level = 18, DungeonName = "Mama Trauma", DungeonDelay = 35, DungeonID = 12, SpecialPerk = true },
    { Level = 15, DungeonName = "Temble of Ruin", DungeonDelay = 33, DungeonID = 11, SpecialPerk = true },
    { Level = 12, DungeonName = "Gravetower Dungeon", DungeonDelay = 45, DungeonID = 6 },
    { Level = 10, DungeonName = "Kingslayer", DungeonDelay = 32, DungeonID = 4 },
    { Level = 7, DungeonName = "Dire Problem", DungeonDelay = 15, DungeonID = 2 },
    { Level = 4, DungeonName = "Scarecrow Defense", DungeonDelay = 20, DungeonID = 3 },
    { Level = 1, DungeonName = "Crabby Crusade", DungeonDelay = 20, DungeonID = 1 },
    { Level = 0, DungeonName = "Celestial Tower", DungeonDelay = 580, DungeonID = 39 },
    { Level = 0, DungeonName = "Arcane Tower", DungeonDelay = 320, DungeonID = 43 },
    { Level = 0, DungeonName = "Aether Tower", DungeonDelay = 270, DungeonID = 34 },
    { Level = 0, DungeonName = "Oasis Tower", DungeonDelay = 280, DungeonID = 29 },
    { Level = 0, DungeonName = "Mezuvian Tower", DungeonDelay = 270, DungeonID = 27 },
    { Level = 0, DungeonName = "Atlantis Tower", DungeonDelay = 279, DungeonID = 23 },
    { Level = 0, DungeonName = "Prison Tower", DungeonDelay = 240, DungeonID = 21 },
    { Level = 0, DungeonName = "Infinite Tower", DungeonDelay = 0, DungeonID = 38 }
}

SetGlobal("creating script function")

SetGlobal("check for character")
local function CheckForCharacter(TimeStarted)
    if not PlayerCharacter then
        repeat task.wait() until PlayerCharacter
    end
    if not PlayerRoot then
        repeat task.wait() until PlayerRoot
    end
    if not PlayerCollider then
        repeat task.wait() until PlayerCollider
    end
    return TimeStarted
end

SetGlobal("format number")
local function FormatNumber(n)
    n = tostring(n)
    return n:reverse():gsub("...","%0,",math.floor((#n-1)/3)):reverse()
end

SetGlobal("format decimal")
local function FormatDecimal(decimal)
	return tonumber(string.format("%.2f", decimal))
end

SetGlobal("get percentage")
local function GetPercentage(initial, current)
	return (current/initial)*100
end

SetGlobal("seconds to string")
local function SecondsToString(seconds)
    local StartingSeconds = seconds
    local days = math.floor(seconds / 86400)
    local hours = math.floor(seconds % 86400 / 3600)
    local minutes = math.floor(seconds % 3600 / 60)
    seconds = math.floor(seconds % 60)
    if StartingSeconds < 60 then
        return tostring(math.floor(StartingSeconds)).. "s"
    elseif StartingSeconds < 3600 then
        return string.format("%d:%02d", minutes, seconds)
    elseif StartingSeconds < 86400 then
        return string.format("%d:%02d:%02d", hours, minutes, seconds)
    else
        return string.format("%d:%02d:%02d:%02d", days, hours, minutes, seconds)
    end
end

SetGlobal("is mission over")
local function IsMissionOver()
    return Workspace:GetAttribute("MissionCleared") or false
end

SetGlobal("check for avoid mobs")
local function CheckForAvoidMobs()
    if IsDungeon and not SV.CanRequire then
        local Success, Result = pcall(function()
            local GetPartyData = Remotes:WaitForChild("Party_GetPartyData", math.huge):InvokeServer()
            SV.PartyRaidID = GetPartyData.RaidID.Value
            if SV.PartyRaidID == 1 then AvoidMobs["BOSSDireBoarwolf"] = true; AvoidMobs["BOSSTreeEnt"] = true end -- World 1
            if SV.PartyRaidID == 20 then AvoidMobs["BOSSAnubis"] = true; AvoidMobs["BOSSHogRider"] = true end -- World 4
            if SV.PartyRaidID == 22 then AvoidMobs["BOSSFallenKing"] = true end -- The Fallen Throne
            if SV.PartyRaidID == 24 then AvoidMobs["CorruptedGreaterTree"] = true end -- World 5
            if SV.PartyRaidID == 25 then AvoidMobs["BOSSKrakenMain"] = true; AvoidMobs["DavyJones"] = true; AvoidMobs["Nautilus"] = true; AvoidMobs["PirateCrab"] = true end -- World 6
            if SV.PartyRaidID == 26 then AvoidMobs["HadesCerberus"] = true; AvoidMobs["SentryOfCerberus"] = true; AvoidMobs["MinotaurDungeonBoss"] = true end -- World 7
            if SV.PartyRaidID == 28 then AvoidMobs["BOSSEvilSanta"] = true end -- North Pole 
            if SV.PartyRaidID == 32 then AvoidMobs["RustyCommander"] = true; AvoidMobs["AetherKing"] = true end -- World 9
            if SV.PartyRaidID == 41 then AvoidMobs["MiniBossCrystalWeaver"] = true; AvoidMobs["DungeonBOSSCrystalWolf"] = true; AvoidMobs["BOSSKandrix"] = true end -- World 10
            if SV.PartyRaidID == 44 then AvoidMobs["EVENTBOSSVane"] = true; AvoidMobs["BOSSDarkriseDarkDragon"] = true end -- Vane's Lair
            if SV.PartyRaidID == 45 then AvoidMobs["EVENTBOSSKraken"] = true; AvoidMobs["EVENTBOSSDavyJones"] = true end -- The Depths
            if SV.PartyRaidID == 46 then AvoidMobs["EVENTBOSSCupid"] = true end -- Cradle of Hearts
        end)
        if not Success then
            
        end
    else
        AvoidMobs = nil
    end
end

SetGlobal("check player ping")
local function CheckPlayerPing()
    local Success, Result = pcall(function()
        while not KillSwitch do
            if PingMultiplier ~= 0 then
                PlayerPing = LocalPlayer:GetNetworkPing() * PingMultiplier
            else
                PlayerPing = 0
            end
            task.wait(1)
        end
    end)
    if not Success then
        
    end
end

SetGlobal("create hook on function")
local function CreateHookOnFunction(Function, Enabled)
    if Enabled then
        EF.Hook(Function, EF.NewClosure(function()
            return
        end))
    else
        if EF.CheckHook(Function) then
            EF.ClearHook(Function)
        end
    end
end

SetGlobal("mob scanner")
local function MobScanner()
    CheckForCharacter()
    if not IsMainMenu then
        if SV.CanRequire and EF.Hook and EF.NewClosure then
            local PlayerRemover = require(SMobs:WaitForChild("PlayerRemover", math.huge))
            CreateHookOnFunction(PlayerRemover.AddMobToSearch, true)
            for Index, Mob in Mobs:GetChildren() do
                PlayerRemover:RemoveMobFromSearch(Mob)
            end
        end
    end
    if not IsMainMenu then
        local Success, Result = pcall(function()
            local FakeSpawnParts = {
                ["DireBridgeSpawn"] = true,
                ["DireBoulderSpawn"] = true,
                ["DireCaveSpawn"] = true,
                ["FakeKingSpawn"] = true,
                ["BridgeMama"] = true,
                ["CerberusSpawn1"] = true,
                ["CerberusSpawn2"] = true,
                ["FakeBoss"] = true,
                ["FakeBossSpawn"] = true
            }
            local FakeMobs = {
                ["Fake"] = true
            }
            local PriorityMobs = {
                ["EVENTBOSSEasterBunny"] = true,
                ["EVENTBOSSEasterBunnyEnraged"] = true,
                ["BabyWinterfall"] = true,
                ["BabyIgnis"] = true,
                ["BOSSSeraphiel"] = true
            }
            local ShrinkCollider = {
                ["CorruptedGreaterTree"] = Vector3.new(1, 1, 1),
                ["BOSSCrystalGolem"] = Vector3.new(52, 30, 52),
                ["EVENTBOSSZeroGuardian"] = Vector3.new(52, 30, 52),
                ["Crystal"] = Vector3.new(25, 20, 25),
                ["KrakenArm"] = Vector3.new(17, 25, 17),
                ["EVENTBOSSKrakenArm-Arm#1"] = Vector3.new(17, 25, 17),
                ["EVENTBOSSKrakenArm-Arm#2"] = Vector3.new(17, 25, 17),
                ["EVENTBOSSKrakenArm-Arm#3"] = Vector3.new(17, 25, 17),
                ["EVENTBOSSKrakenArm-Arm#4"] = Vector3.new(17, 25, 17),
                ["EVENTBOSSKrakenArm-Arm#5"] = Vector3.new(17, 25, 17),
                ["EVENTBOSSKrakenArm-Arm#6"] = Vector3.new(17, 25, 17),
                ["EVENTBOSSKrakenArm-Arm#7"] = Vector3.new(17, 25, 17),
                ["EVENTBOSSKrakenArm-Arm#8"] = Vector3.new(17, 25, 17)
            }
            local DelayBosses = {
                ["BOSSTreeEnt"] = true,
                ["HadesCerberus"] = true,
                ["EVENTBOSSEasterBunny"] = true
            }
            local DontAttackBosses = {
                ["BOSSKrakenMain"] = true,
                ["AlienMothership"] = true,
                ["AlienUFO"] = true
            }
            local Summons = {
                ["SummonerSummonWeak"] = true,
                ["SummonerSUmmonStrong"] = true,
                ["NecromancerSummon"] = true,
                ["EvilClown"] = true
            }
            local Blockers = {
                ["Pillar1"] = true, -- 1-5 blocker
                ["Pillar2"] = true, -- 1-5 blocker
                ["Pillar3"] = true, -- 1-5 blocker
                ["IceBarricade"] = true, -- 3-2 blocker
                ["Blocker1"] = true, -- 3-3 blocker
                ["Blocker2"] = true, -- 3-3 blocker
                ["Blocker3"] = true, -- 3-3 blocker
                ["Model"] = true, -- 4-1 blockers
                ["Crystal"] = true, -- tower 6 blockers
                ["EasterGiantEgg"] = true, -- easter boss blocker
                ["1"] = true, -- chad tutorial 
                ["AngelSculpture"] = true, -- heavenly boss heal
                ["SwordOfDecree"] = true, -- heavenly boss sword
                ["FallenClock"] = true -- falllen queen thing

            }
            ConnectionTable["MobInvincibilityUpdate"] = Remotes:WaitForChild("Mobs_InvincibilityUpdated", math.huge).OnClientEvent:Connect(function(Mob, Value)
                local UpdateInvincibility
                local AllocatedLoadTime = time() + 5
                repeat
                    if time() > AllocatedLoadTime then
                        break
                    end
                    UpdateInvincibility = ISV.MobTable[Mob]
                    task.wait()
                until UpdateInvincibility
                if UpdateInvincibility then
                    if Value then
                        UpdateInvincibility.Invincible = true
                    else
                        UpdateInvincibility.Invincible = false
                    end
                end
            end)
            if SV.CanRequire then
                local rMob = require(SMobs)
                local BigNumber = math.huge
                local function ValidMob(Mob, MobName)
                    local IsDebug = ISV.Debug
                    IsAliveMobs += 1
                    if Mob.Parent and Mob.Parent == Workspace.Characters then
                        if IsDebug then
                            
                        end
                        IsAliveMobs -= 1
                        return
                    end
                    if not MobName then
                        MobName = Mob.Name
                    end
                    if FakeMobs[MobName] then
                        if IsDebug then
                            
                        end
                        IsAliveMobs -= 1
                        return
                    end
                    if Blockers[MobName] then
                        local BlockerHitbox = Mob:FindFirstChild("Part") or Mob:FindFirstChild("Base") or Mob:FindFirstChild("hitbox") or Mob:FindFirstChild("Hitbox") or Mob:FindFirstChild("EasterGiantEgg") or Mob:FindFirstChild("Collider") or Mob:FindFirstChild("HumanoidRootPart")
                        if not BlockerHitbox then
                            if IsDebug then
                                
                            end
                            IsAliveMobs -= 1
                            return
                        end
                        BlockerHitbox.Name = "Collider"
                        ISV.MobTable[Mob] = {IsBlocker = true}
                        if IsDebug then
                            
                        end
                        return
                    end
                    if Mob.Parent then
                        local MobData
                        local AllocatedLoadTime = time()+5
                        repeat
                            if time() > AllocatedLoadTime then
                                if ISV.Debug then
                                    
                                end
                                break
                            end
                            MobData = rMob:GetMobData(Mob)
                            task.wait()
                        until MobData

                        if MobData and (MobData.IsHunterPet or MobData.CanAttackMobs or MobData.CanAttackEntities) then
                            if IsDebug then
                                
                            end
                            IsAliveMobs -= 1
                            return
                        end

                        if SV.IsRanged then
                            if MobData then
                                MobData.Collider.Size = MobData.Collider.Size/2
                            else
                                local MobCollider = Mob:WaitForChild("Collider", 5)
                                if MobCollider then
                                    MobCollider.Size = MobCollider.Size/2
                                end
                            end
                        end

                        if DelayBosses[MobName] then
                            if IsDebug then
                                
                            end
                            task.wait(1)
                        end

                        if PriorityMobs[MobName] then
                            ISV.MobTable[Mob] = {Priority = true}
                            if IsDebug then
                                
                            end
                            return
                        end
                        if MobData then
                            if MobData.Invincible then
                                ISV.MobTable[Mob] = {Invincible = true}
                                if IsDebug then
                                    
                                end
                            else
                                ISV.MobTable[Mob] = {}
                                if IsDebug then
                                    
                                end
                            end
                        else
                            ISV.MobTable[Mob] = {NoData = true}
                            if IsDebug then
                                
                            end
                        end
                    else
                        if IsDebug then
                            
                        end
                        IsAliveMobs -= 1
                        return
                    end
                end
                ConnectionTable["ConnectMobCreated"] = Remotes:WaitForChild("Health_InstanceAdded").OnClientEvent:Connect(function(Mob)
                    repeat task.wait() until Mob.Parent ~= ReplicatedStorage
                    ValidMob(Mob)
                end)
                ConnectionTable["ConnectMobDied"] = Remotes:WaitForChild("Mobs_MobDied", math.huge).OnClientEvent:Connect(function(Name, Mob)
                    local CheckTable = ISV.MobTable[Mob]
                    if CheckTable then
                        ISV.MobTable[Mob] = nil
                        IsAliveMobs -= 1
                        if ISV.Debug then
                            
                        end
                    end
                end)
                for Index, Mob in Mobs:GetChildren() do
                    ValidMob(Mob)
                end
                while not KillSwitch do
                    if not CanTarget or SV.QuotaPaused then
                        CurrentMob = nil
                        task.wait()
                        continue
                    end

                    local TableReference = ISV.MobTable
                    local ClosestMob = nil
                    local ClosestMobDistance = BigNumber
                    local ClosestAvoidMob = nil
                    local ClosestAvoidDistance = BigNumber
                    local ClosestNoData = nil
                    local MobPriority = nil
                    for Mob, AddedTable in TableReference do
                        if not Mob then
                            continue
                        end
                        if not Mob.Parent then
                            if ISV.Debug then
                                
                            end
                            TableReference[Mob] = nil
                            IsAliveMobs -= 1
                            continue
                        end
                        local HealthProperties = Mob:FindFirstChild("HealthProperties")
                        local Health = HealthProperties and HealthProperties:FindFirstChild("Health")
                        if Health and Health.Value == 0 then
                            if ISV.Debug then
                                
                            end
                            TableReference[Mob] = nil
                            IsAliveMobs -= 1
                            continue
                        end
                        if AddedTable.IsBlocker then
                            ClosestMob = Mob
                            break
                        end
                        local MobData = rMob:GetMobData(Mob)
                        if AddedTable.NoData then
                            if MobData then
                                AddedTable.NoData = nil
                            else
                                ClosestNoData = Mob
                            end
                        end
                        if AddedTable.Priority then
                            if MobData and not MobData.Invincible then
                                MobPriority = true
                                ClosestMob = Mob
                                continue
                            else
                                continue
                            end
                        end
                        if MobPriority then
                            continue
                        end
                        if not MobData then
                            local MobCollider = Mob:FindFirstChild("Collider")
                            if MobCollider then
                                MobData = {Collider = MobCollider}
                            else
                                continue
                            end
                        end
                        if not MobData.Invincible then
                            local MobDistance = (MobData.Collider.Position - PlayerRoot.Position).Magnitude
                            if not MobData.BossTag then
                                if MobDistance < ClosestMobDistance then
                                    ClosestMob = Mob
                                    ClosestMobDistance = MobDistance
                                end
                            else
                                if MobDistance < ClosestAvoidDistance then
                                    ClosestAvoidMob = Mob
                                    ClosestAvoidDistance = MobDistance
                                end
                            end
                        end
                    end
                    TeleportMob = ClosestMob or ClosestAvoidMob or ClosestNoData
                    if ClosestMob then
                        IsBoss = false
                        CurrentMob = ClosestMob
                    elseif ClosestAvoidMob then
                        IsBoss = true
                        CurrentMob = ClosestAvoidMob
                    elseif ClosestNoData then
                        CurrentMob = ClosestNoData
                    else
                        CurrentMob = nil
                    end
                    task.wait()
                end
            else
                PriorityMobs["BOSSSeraphiel"] = nil
                for _, CheckForRuins in SV.Parties:GetChildren() do
                    if CheckForRuins:WaitForChild("RaidID").Value == 30 then
                        FakeSpawnParts["Part"] = true
                    end
                end
                local function ValidMob(Mob, MobName)
                    local IsDebug = ISV.Debug
                    IsAliveMobs += 1
                    if Mob.Parent and Mob.Parent == Workspace.Characters then
                        if IsDebug then
                            
                        end
                        IsAliveMobs -= 1
                        return
                    end
                    if not MobName then
                        MobName = Mob.Name
                    end
                    if FakeMobs[MobName] then
                        if IsDebug then
                            
                        end
                        IsAliveMobs -= 1
                        return
                    end
                    if Blockers[MobName] then
                        local BlockerHitbox = Mob:FindFirstChild("Part") or Mob:FindFirstChild("Base") or Mob:FindFirstChild("hitbox") or Mob:FindFirstChild("Hitbox") or Mob:FindFirstChild("EasterGiantEgg") or Mob:FindFirstChild("Collider")
                        if not BlockerHitbox then
                            return
                        end
                        BlockerHitbox.Name = "Collider"
                        ISV.MobTable[Mob] = {IsBlocker = true}
                        if IsDebug then
                            
                        end
                        return
                    end
                    if Mob.Parent then
                        if Summons[MobName] then
                            if IsDebug then
                                
                            end
                            IsAliveMobs -= 1
                            return
                        end
                        if DontAttackBosses[MobName] then
                            if IsDebug then
                                
                            end
                            IsAliveMobs -= 1
                            return
                        end
                        local FromSpawnPart = Mob:WaitForChild("FromSpawnPart", 2)
                        if FromSpawnPart and FromSpawnPart.Value and FakeSpawnParts[tostring(FromSpawnPart.Value)] then
                            if IsDebug then
                                
                            end
                            IsAliveMobs -= 1
                            return
                        end
                        local MobProperties = Mob:WaitForChild("MobProperties", 2)
                        local Owner = MobProperties and MobProperties:WaitForChild("Owner", 2)
                        if Owner and Owner.Value then
                            if IsDebug then
                                
                            end
                            IsAliveMobs -= 1
                            return
                        end
                        local ShrinkMob = ShrinkCollider[MobName]
                        if ShrinkMob then
                            local MobCollider = Mob:WaitForChild("Collider", 2)
                            if MobCollider then
                                MobCollider.Size = ShrinkMob
                            end
                        end
                        if DelayBosses[MobName] then
                            task.wait(1)
                        end
                        if PriorityMobs[MobName] then
                            ISV.MobTable[Mob] = {Priority = true}
                            if IsDebug then
                                
                            end
                            return
                        end
                        ISV.MobTable[Mob] = {}
                        if IsDebug then
                            
                        end
                    end
                end
                ConnectionTable["ConnectMobCreated"] = Remotes:WaitForChild("Health_InstanceAdded").OnClientEvent:Connect(function(Mob)
                    repeat task.wait() until Mob.Parent ~= ReplicatedStorage
                    ValidMob(Mob)
                end)
                ConnectionTable["ConnectMobDied"] = Remotes:WaitForChild("Mobs_MobDied", math.huge).OnClientEvent:Connect(function(Name, Mob)
                    local CheckTable = ISV.MobTable[Mob]
                    if CheckTable then
                        ISV.MobTable[Mob] = nil
                        IsAliveMobs -= 1
                        if ISV.Debug then
                            
                        end
                    end
                end)
                for Index, Mob in Mobs:GetChildren() do
                    task.spawn(function()
                        ValidMob(Mob)
                    end)
                end
                while not KillSwitch do
                    if not CanTarget or SV.QuotaPaused then
                        CurrentMob = nil
                        task.wait()
                        continue
                    end
                    local TableReference = ISV.MobTable
                    local ClosestMob = nil
                    local ClosestMobDistance = math.huge
                    local ClosestAvoidMob = nil
                    local ClosestAvoidDistance = math.huge
                    local MobPriority = nil

                    for Mob, AddedTable in TableReference do
                        if not Mob.Parent then
                            TableReference[Mob] = nil
                            IsAliveMobs -= 1
                            if ISV.Debug then
                                
                            end
                            continue
                        end
                        local MobHealthProperties = Mob:FindFirstChild("HealthProperties")
                        local MobHealth = MobHealthProperties and MobHealthProperties:FindFirstChild("Health")
                        if MobHealth and MobHealth.Value == 0 then
                            TableReference[Mob] = nil
                            IsAliveMobs -= 1
                            if ISV.Debug then
                                
                            end
                            continue
                        end
                        if AddedTable.Invincible then
                            continue
                        end
                        local MobCollider = Mob:FindFirstChild("Collider")
                        if not MobCollider then
                            continue
                        end
                        if AddedTable.IsBlocker then
                            ClosestMob = Mob
                            break
                        end
                        if AddedTable.Priority then
                            MobPriority = true
                            ClosestMob = Mob
                            continue
                        end
                        if MobPriority then
                            continue
                        end
                        local MobDistance = (PlayerCollider.Position - MobCollider.Position).Magnitude
                        if AvoidMobs[Mob.Name] then
                            if MobDistance < ClosestAvoidDistance then
                                ClosestAvoidDistance = MobDistance
                                ClosestAvoidMob = Mob
                            end
                        else
                            if MobDistance < ClosestMobDistance then
                                ClosestMobDistance = MobDistance
                                ClosestMob = Mob
                            end
                        end
                    end
                    TeleportMob = ClosestMob or ClosestAvoidMob
                    if ClosestMob and ClosestMobDistance then
                        IsBoss = false
                        CurrentMob = ClosestMob
                    elseif not ClosestMob and ClosestAvoidMob and ClosestAvoidDistance then
                        IsBoss = true
                        CurrentMob = ClosestAvoidMob
                    else
                        CurrentMob = nil
                    end
                    task.wait()
                end
            end
        end)
        if not Success then
            
        end
    end
end

local function PingOnceUnlocked() end
local function PingForCap() end
SetGlobal("get difficulty")
local function GetDifficulty()
    return Remotes:WaitForChild("Missions_GetDifficulty", math.huge):InvokeServer()
end

SetGlobal("get lives")
local function GetLives()
    return Remotes:WaitForChild("Missions_GetCurrentLives", math.huge):InvokeServer()
end

SetGlobal("party leader check")
local function PartyLeaderCheck()
    if SV.Parties then
        local PartyLeader = Remotes:WaitForChild("Party_GetPartyData", math.huge):InvokeServer().Leader.Value
        if PlayerName == PartyLeader then
            return true
        else
            return
        end
    end
end

SetGlobal("replay dungeon loop")
local function ReplayDungeonLoop(Mission, Difficulty)
    if type(Mission)~="number" or Mission~=Mission or Mission<=0 or Mission==math.huge then return end
    if Mission==49 then Mission=1 end
    if SV.TransitionPending and SV.TransitionMission==Mission and SV.TransitionDifficulty==Difficulty then return end
    SV.TransitionPending=true
    SV.TransitionMission=Mission
    SV.TransitionDifficulty=Difficulty
    SV.ReplayGeneration=(SV.ReplayGeneration or 0)+1
    local generation=SV.ReplayGeneration
    if Library.PrepareTeleportSettings then pcall(Library.PrepareTeleportSettings) end
    while not ScriptUnloaded and SV.ReplayGeneration==generation do
        pcall(function()
            Remotes:WaitForChild("Teleport_StartRaid",10):FireServer(Mission,Difficulty)
        end)
        task.wait(10)
    end
end

SetGlobal("rejoin last dungeon")
local function RejoinLastDungeon(DoRejoin)
    if not DoRejoin or not IsDungeon or SV.TransitionPending then return end
    local difficulty=IsTower and nil or GetDifficulty()
    ReplayDungeonLoop(ISV.MissionId,difficulty)
end

SetGlobal("restart dungeon")
local function RestartDungeon(RestartBypass)
    if SV.QuotaPaused then return end
    if not IsDungeon then return end
    if SV.TransitionPending then return end
    if not (SV.ReplayMission or SV.DoingGuildDungeon or RestartBypass) then 
        return
    end
    if SV.TowerChestDelay then
        task.wait(6)
    end
    local Difficulty = GetDifficulty()
    if not PartyLeaderCheck() then
        Remotes:WaitForChild("Missions_LeaveChoice", math.huge):FireServer(true)
        Remotes:WaitForChild("Missions_NotifyReadyToLeave", math.huge):FireServer()
        return
    end
    SV.TransitionPending=true
    Library:Notify("Teleporting...", SV.RestartDungeonDelay)
    task.wait(SV.RestartDungeonDelay)
    if IsTower then
        Difficulty = nil
    end
    if GetLives() == 0 then
        ReplayDungeonLoop(ISV.MissionId, Difficulty)
    end
    if SV.DoingGuildDungeon and not SV.IsNightmareDungeon then
        if not (ISV.MissionId == 42 and Difficulty == 5) then
            if Difficulty == 1 and not IsTower then
                Library:Notify("Moving to challenge mode", 1)
                ReplayDungeonLoop(ISV.MissionId, 5)
            else
                local NextDungeon
                for DungeonIndex, Dungeon in SV.DungeonListTable do
                    if Dungeon.DungeonID == ISV.MissionId then
                        NextDungeon = DungeonIndex - 1
                        break
                    end
                end
                local NextDungeonReference = SV.DungeonListTable[NextDungeon]
                Library:Notify("Moving to " ..NextDungeonReference.DungeonName, 1)
                if NextDungeonReference.Level > 0 then
                    ReplayDungeonLoop(NextDungeonReference.DungeonID, 1)
                else
                    ReplayDungeonLoop(NextDungeonReference.DungeonID, nil)
                end
            end
        else
            local RestartChoice = Options.DoAllDropdown.Value
            if RestartChoice == "Stop" then
                Library:Notify("Finished doing all dungeons", 9999999999999999)
                return
            elseif RestartChoice == "Loop" then
                ReplayDungeonLoop(38, nil)
            elseif RestartChoice == "Loop w/o inf" then
                ReplayDungeonLoop(21, nil)
            elseif RestartChoice == "Loop w/o towers" then
                ReplayDungeonLoop(1, 1)
            elseif RestartChoice == "Play nightmare dungeons" then
                ReplayDungeonLoop(1005, 6)
            end
        end
    end
    if SV.IsNightmareDungeon and SV.PrioNmDCount and ISV.PlayerLevel == 175 then
        local GetCurrentDailyDungeon = Remotes:WaitForChild("Missions_GetCurrentDailyDungeon", math.huge):InvokeServer()
        local SelectedDungeon = ISV.MissionId
        local SelectedDungeonSpecialPerk
        local SelectedDungeonLength = 9999
        for Index, Data in GetCurrentDailyDungeon do
            local InternalID = Data.InternalID
            for DungeonIndex in Options.PrioNmDropdown.Value do
                local DungeonData = SV.PrioritizedNightmareDungeons[DungeonIndex]
                if InternalID == DungeonData.ID then
                    if DungeonData.SpecialPerk then
                        if not SelectedDungeonSpecialPerk then
                            SelectedDungeonSpecialPerk = true
                            SelectedDungeon = Data.ID
                            SelectedDungeonLength = DungeonData.Length
                        elseif DungeonData.Length < SelectedDungeonLength then
                            SelectedDungeon = Data.ID
                            SelectedDungeonLength = DungeonData.Length
                        end
                    elseif not SelectedDungeonSpecialPerk and DungeonData.Length < SelectedDungeonLength then
                        SelectedDungeon = Data.ID
                        SelectedDungeonLength = DungeonData.Length
                    end
                end
            end
        end
        ReplayDungeonLoop(SelectedDungeon, Difficulty)
    end
    if SV.AutoLeveling and not IsEventDungeon then
        local CheckPartySize = Players:GetChildren()
        local LowestLevel = math.huge
        if #CheckPartySize > 1 then
            for Index, Player in CheckPartySize do
                local MemberLevel = Player:GetAttribute("Level")
                if MemberLevel and MemberLevel < LowestLevel then
                    LowestLevel = MemberLevel
                end
            end
        else
            LowestLevel = LocalPlayer:GetAttribute("Level")
        end
        for Index, AutoLevelingDungeon in SV.DungeonListTable do
            if LowestLevel >= AutoLevelingDungeon.Level then
                if AutoLevelingDungeon.DungeonID == ISV.MissionId then
                    Library:Notify("Replaying: " ..AutoLevelingDungeon.DungeonName, 2)
                else
                    Library:Notify("Moving to: " ..AutoLevelingDungeon.DungeonName, 2)
                end
                ReplayDungeonLoop(AutoLevelingDungeon.DungeonID, 5)
            end
        end
    end
    if SV.RandomNightmareDungeon and SV.IsNightmareDungeon then
        ISV.MissionId = SV.RandomNightmareDungeon
    end
    ReplayDungeonLoop(ISV.MissionId, Difficulty)
end

SetGlobal("collect chests")
local function CollectChests()
    local ExtraChestCheck = true
    local ChestDrops = {}
    local rItems = false
    local Success, Result = pcall(function()
        if SV.CanRequire then
            rItems = require(Items)
        end
        local Success1, Result1 = pcall(function()
            ExtraChestCheck = MarketplaceService:UserOwnsGamePassAsync(PlayerID, 8136250)
        end)
        if not Success1 then
            
        end
        local MissionPrize = Remotes:WaitForChild("Missions_GetMissionPrize", math.huge)
        for ChestIndex = 1, 4 do
            if ChestIndex == 4 and not ExtraChestCheck then
                break
            end

            local ChestPrize
            if ChestIndex == 1 then
                ChestPrize = MissionPrize:InvokeServer(true)
            else
                ChestPrize = MissionPrize:InvokeServer()
            end

            if ChestPrize then
                if rItems then
                    ChestPrize = rItems[tostring(ChestPrize)].DisplayKey
                end
                if Library then
                    Library:Notify("Chest reward: " ..tostring(ChestPrize), 1)
                end
                table.insert(ChestDrops, ChestPrize)
            end
        end
        task.wait(.5)
    end)
    if not Success then
        
    end
    return ChestDrops
end

SetGlobal("collect tower chests")
local function CollectTowerChests()
    CheckForCharacter()
    if IsTower then
        local Success, Result = pcall(function()
            local OpenChest = Remotes:WaitForChild("Chests_OpenChest", math.huge)
            if SV.CanRequire and debug and getupvalue then
                local ChestScript = debug.getupvalue(require(Chests).Start, 12)
                for ChestKey, ChestPath in ChestScript do
                    OpenChest:FireServer(ChestKey)
                end
            else
                local ChestNames = {
                    "RaidChestBlue", "RaidChestGold", "RaidChestSilver", "HeavenlyRaidChest"
                }
                for Index, ChestName in ChestNames do
                    local Chest = Workspace:FindFirstChild(ChestName)
                    if Chest and Chest.Parent then
                        task.spawn(function()
                            while Chest.Parent do
                                Chest:PivotTo(CFrame.new(PlayerRoot.Position))
                                task.wait()
                            end
                        end)
                    end
                end
            end
        end)
        if not Success then
            
        end
    end
end

SetGlobal("claim all quests")
local function ClaimAllQuests()
    local Success, Result = pcall(function()
        local ProfileQuests = PlayerProfile:WaitForChild("Quests", math.huge)
        local Active = ProfileQuests:WaitForChild("Active", math.huge)
        if SV.ClaimGuildQuests then
            local GetDailyGuildQuests = require(Quests):GetDailyGuildQuests()
            for Difficulty, Data in GetDailyGuildQuests do
                local QuestID = Data.ID
                if not Remotes:WaitForChild("Quests_GuildDailyIsClaimed", math.huge):InvokeServer(QuestID) then
                    if Active:FindFirstChild(QuestID) then
                        for i = 1, 2 do
                            Remotes:WaitForChild("Quests_ClaimDailyGuildQuest", math.huge):FireServer(QuestID)
                        end
                        task.wait(1.5)
                    end
                end
            end
        end
        local ClaimQuest = Remotes:WaitForChild("Quests_ClaimQuest", math.huge)
        if ClaimQuest then
            for _, ActiveQuest in Active:GetChildren() do
                ClaimQuest:FireServer(tonumber(ActiveQuest.Name))
            end
        end
    end)
    if not Success then
        local ExtraMessage
        if Result:find("IsSeasonActive") then
            ExtraMessage = "\"IsSeasonActive\" is a in-game error not caused by the script"
        end
        
    end
end

SetGlobal("getting current dungeon")
local function GetDungeonImage() ISV.DungeonImage="" end
SetGlobal("connect mission finished")
local function ConnectMissionFinished()
    if IsDungeon then
        local MissionFinished = Remotes:WaitForChild("Missions_MissionFinished", math.huge)
        ConnectionTable["MissionFinished"] = MissionFinished.OnClientEvent:Once(function(EndTime, PlayersInDungeon, Lost)
            SV.DungeonCompletionTime = SecondsToString(EndTime)
            if SV.ShowTime then
                Library:Notify("Completed in " ..SV.DungeonCompletionTime)
            end
            if ISV.Debug then
                
            end
            if SV.AutoLeveling then
                ClaimAllQuests()
            end
            if ISV.Debug then
                
            end
            local ChestDrops = {"none"}
            if SV.CollectDungeonChest then
                ChestDrops = CollectChests()
            end
            
            repeat
                task.wait(1)
                if ISV.Debug then
                    
                end
            until SellItemCheck == 0 and EquipInProgress == 0
            RestartDungeon()
        end)
    end
end

SetGlobal("connect tower finished")
local function ConnectTowerFinished()
    local TowerFinished 
    if ISV.MissionId == 39 then
        TowerFinished = ReplicatedStorage:WaitForChild("MissionScripts", math.huge):WaitForChild("39", math.huge):WaitForChild("TowerFinished", math.huge)
    elseif ISV.MissionId == 56 then
        TowerFinished = ReplicatedStorage:WaitForChild("MissionScripts", math.huge):WaitForChild("56", math.huge):WaitForChild("TowerFinished", math.huge)
    else
        TowerFinished = Remotes:WaitForChild("Towers_TowerFinished", math.huge)
    end
    ConnectionTable["TowerFinished"] = TowerFinished.OnClientEvent:Once(function(Countdown, EndTime)
        SV.DungeonCompletionTime = SecondsToString(EndTime)
        if SV.ShowTime then
            Library:Notify("Completed in " ..SV.DungeonCompletionTime)
        end
        
        RestartDungeon()
    end)
end

SetGlobal("get rarity")
local InventoryPolicy=(function()
local Policy={}
function Policy.Tier(value)
    local labels={ ["none"]=0,["0"]=0,["3"]=3,["3-5"]=3,["4"]=4,["4-5"]=4,["5"]=5 }
    return labels[tostring(value)]
end
function Policy.TierLabel(value)
    local tier=Policy.Tier(value)
    return ({[0]="none",[3]="3-5",[4]="4-5",[5]="5"})[tier] or "5"
end
function Policy.ShouldSell(item,config)
    if item.protected or item.equipped or item.stackable then return false end
    if item.towerEgg then return config.sellTowerEggs==true end
    if item.kind~="Weapon" and item.kind~="Armor" and item.kind~="Pet" and item.kind~="Charm" then return false end
    if item.kind=="Pet" and not config.includePets then return false end
    if item.kind=="Charm" and not config.includeCharms then return false end
    if type(item.rarity)~="number" or item.rarity==7 then return false end
    local tier=Policy.Tier(config.keepTier)
    if tier==nil then return false end
    if tier>0 and item.rarity>=tier then return false end
    if config.keepPerks then
        for name,value in pairs(item.perks or {}) do
            local selected=(config.selectedPerks or {})[name]
            if selected then
                local pet=item.kind=="Pet" or item.kind=="Charm"
                local threshold=pet and selected.PetPerkValue or selected.PerkValue
                threshold=tonumber(threshold or selected.PerkValue)
                value=tonumber(value)
                if not threshold or not value then return false end
                local offset=tonumber(config.offset) or 0
                if selected.LowerMax then
                    if value<=threshold+offset then return false end
                elseif value>=threshold-offset then return false end
            end
        end
    end
    return true
end
return Policy

end)()
-- Inserted into the readable main source by the local assembler.
local InventoryBusy=setmetatable({},{__mode="k"})
local function IsInventoryItem(item)
    local items=ProfileInventory and ProfileInventory:FindFirstChild("Items")
    return item and items and item.Parent==items
end
local function ProtectedInventoryItem(item)
    if not item then return true end
    for _,key in ipairs({"Locked","Favorited","GiftWrap","OnExpedition"}) do
        if item:FindFirstChild(key) or item:GetAttribute(key)==true then return true end
    end
    return false
end
local function GetRarity(Item)
    if not Item then return "NotEquipment" end
    if not SV.Items and SV.CanRequire then SV.Items=require(Items) end
    local ref=SV.Items and SV.Items[Item.Name]
    if not ref then return "NotEquipment" end
    local rarity=ref.Rarity
    if ref.Type=="Pet" then
        local variant=Item:FindFirstChild("Variant")
        local data=variant and ref.Variants and ref.Variants[variant.Value]
        rarity=data and data[4]
    end
    if ref.Type~="Weapon" and ref.Type~="Armor" and ref.Type~="Pet" and ref.Type~="Charm" then return "NotEquipment" end
    if type(rarity)~="number" then return "NotEquipment" end
    local perks=ref.Type=="Charm" and (rarity==5 and 1 or 0) or ({[3]=1,[4]=2,[5]=3})[rarity]
    return rarity,perks or 0
end

SetGlobal("equip new item added")
local function EquipNewItemAdded()
    if ConnectionTable.ConnectEquipNewItems then ConnectionTable.ConnectEquipNewItems:Disconnect()end
    local items=ProfileInventory and ProfileInventory:FindFirstChild("Items")
    if not items or not SV.CanRequire then return end
    local inventory=require(Inventory)
    local equips=ReplicatedStorage.PlayerEquips:FindFirstChild(LocalPlayer.Name)
    if not equips then return end
    ConnectionTable.ConnectEquipNewItems=items.ChildAdded:Connect(function(item)
        EquipInProgress+=1
        pcall(function()
            task.wait(0.5)
            if ScriptUnloaded or not SV.AutoLeveling or not IsInventoryItem(item) or ProtectedInventoryItem(item) then return end
            local level=item:FindFirstChild("Level")
            if not level then return end
            local bestSlot,bestLevel,bestRarity
            local newRarity=GetRarity(item)
            if type(newRarity)~="number" then return end
            for _,name in ipairs({"Armor","Primary","Offhand"}) do
                local slot=equips:FindFirstChild(name)
                if slot and inventory:CanEquipItem(PlayerProfile,item,slot) then
                    local old=slot:FindFirstChildWhichIsA("Folder")
                    local oldLevel=old and old:FindFirstChild("Level")
                    local rank=old and GetRarity(old) or 0
                    rank=type(rank)=="number" and rank or 0
                    local value=oldLevel and oldLevel.Value or -1
                    local upgrade=not old or level.Value>value or (level.Value==value and newRarity>rank)
                    if upgrade and (not bestSlot or value<bestLevel or (value==bestLevel and rank<bestRarity)) then
                        bestSlot,bestLevel,bestRarity=slot,value,rank
                    end
                end
            end
            if bestSlot and IsInventoryItem(item) then
                inventory:EquipItemClient(item,bestSlot)
                local deadline=os.clock()+3
                repeat task.wait(0.1) until not IsInventoryItem(item) or ScriptUnloaded or os.clock()>=deadline
            end
        end)
        EquipInProgress=math.max(0,EquipInProgress-1)
    end)
end

SetGlobal("get player size")
local function GetPlayerSize()
    return PlayerCollider.Size.Y / 2 or 0
end

SetGlobal("collect coins")
local function CollectCoins()
    CheckForCharacter()
    if SV.CanRequire and debug and getupvalue then
        local Success, Result = pcall(function()
            local rDrops = debug.getupvalue(require(Drops).Start, 6)
            local CoinEvent = Remotes:WaitForChild("Drops_CoinEvent", math.huge)
            for DropIndex, CoinDrop in rDrops do
                CoinDrop.model:Destroy()
                CoinDrop.followPart:Destroy()
                CoinEvent:FireServer(CoinDrop.id)
            end
        end)
        if not Success then
            
        end
    else
        local Success, Result = pcall(function()
            local CoinFolder = Workspace:WaitForChild("Coins", math.huge)
            local PlayerSize = GetPlayerSize()
            for _, CoinChild in CoinFolder:GetChildren() do
                if CoinChild:IsA("Part") then
                    while CoinChild.Parent do
                        CoinChild.CanCollide = false
                        CoinChild.Anchored = true
                        CoinChild.CFrame = CFrame.new(PlayerRoot.Position.X, PlayerRoot.Position.Y-GetPlayerSize(), PlayerRoot.Position.Z)
                        task.wait(0.1)
                    end
                end
            end
        end)
        if not Success then
            
        end
    end
end

SetGlobal("get guild")
local function GetGuild(Player)
    return Player:GetAttribute("GuildTag") or "❌"
end

local function IsTowerEgg(Item)
    if Item and Item.Name and SV.TowerEggList and SV.TowerEggList[Item.Name] then
        return true
    end
end

SetGlobal("sell item")
local function SellItem(Item)
    if not IsInventoryItem(Item) or ProtectedInventoryItem(Item) or Item:FindFirstChild("Count") then return false end
    -- Match the game's public client adapter, including item-reference conversion.
    local done,ok,result=false,false,nil
    task.spawn(function()
        ok,result=pcall(function()return require(Drops):SellItems(LocalPlayer,{Item})end)
        done=true
    end)
    local deadline=os.clock()+8
    repeat task.wait(0.1) until done or ScriptUnloaded or os.clock()>=deadline
    if not done or not ok then return false end
    local confirmed=type(result)=="number" and result>0
    if not confirmed then return false end
    if Library and not Library.Unloaded then Library:Notify("<font color='#FCCE7E'>Sold item:</font> "..Item.Name,1)end
    return true
end

SetGlobal("buy from local shop")
local function BuyFromLocalShop(ShopData, PurchaseData)
    local IsDebug = ISV.Debug
    if not PurchaseData then
        Library:Notify("No item selected")
        return
    end
    local Currency = ShopData.ShopInfo.Currency
    local ShopName = ShopData.ShopInfo.ShopName
    local Item = PurchaseData.InternalName
    local ItemName = PurchaseData.VisualName
    local ItemPrice = PurchaseData.CoinPrice
    if IsDebug then
        
    end
    if not (Item and ItemPrice and ItemName) then
        if IsDebug then
            
        end
        return
    end
    local BuyLocal = Remotes:FindFirstChild("CoinShop_Buy")
    local Coins = ProfileInventory:WaitForChild("Items", math.huge):FindFirstChild(Currency)
    if not (Coins and BuyLocal) then
        if IsDebug then
            
        end
        return
    end
    local CoinCount = Coins and Coins:FindFirstChild("Count")
    if not (CoinCount and tonumber(CoinCount.Value) >= ItemPrice) then
        if IsDebug then
            
        end
        return
    end
    local Success, Result = pcall(function()
        BuyLocal:InvokeServer(ShopName, Shop.LocalShops[ShopName].Items[Item])
    end)
    if not Success or Result~=true then return false end
    Library:Notify("Purchased " ..ItemName.. "!", 1)
    task.wait(0.6)
    return true
end

SetGlobal("buy from egg shop")
local function BuyFromEggShop(Currency, Egg, EggPrice, EggName)
    if ISV.Debug then
        
    end
    local BuyEgg = Remotes:FindFirstChild("Pets_BuyEgg")
    if Currency == "Gold" then
        local ProfileCurrency = PlayerProfile:FindFirstChild("Currency")
        if not (BuyEgg and ProfileCurrency) then
            return
        end
        local Gold = ProfileCurrency and ProfileCurrency:FindFirstChild("Gold")
        if not (Gold and tonumber(Gold.Value) >= EggPrice) then
            return
        end
    elseif Currency == "Crystal" then
        local GetCrystals = Remotes:WaitForChild("Crystals_GetCrystals", math.huge):InvokeServer()
        if not (GetCrystals and GetCrystals >= EggPrice) then
            return
        end
    end
    BuyEgg:FireServer(Egg, Currency)
    Library:Notify("Purchased " ..EggName.. "!", 1)
    return true
end

SetGlobal("open menu")
local QuickMenuController=(function()
-- Own only the quick-menu session. Native menus retain their own controls and
-- transactions. Latest clicks wait for the previous menu's close animation.
local QuickMenus={}
function QuickMenus.Create(deps)
    local active,pending,running,closed
    local controller={}
    local function release()
        local previous=active
        active=nil
        if previous then previous:Close()end
    end
    function controller.Request(name)
        if closed or deps.Stopped()then return false end
        pending=name
        if running then return true end
        running=true
        local ok=pcall(function()
            while pending and not closed and not deps.Stopped()do
                local target=pending
                pending=nil
                if active then
                    release()
                    deps.Wait(0.3)
                end
                if closed or deps.Stopped()then break end
                if pending then target=pending pending=nil end
                local menu=deps.Get(target)
                active=menu -- also owned if Open fails partway through.
                if target=="PetExpeditions" then
                    menu:Open(true) -- native board preview entry point.
                else
                    menu:Open()
                end
            end
        end)
        running=false
        if not ok then pending=nil pcall(release)end
        return ok
    end
    function controller.Close()
        closed=true
        pending=nil
        pcall(release)
    end
    return controller
end
return QuickMenus

end)().Create({Get=function(name)return require(Client.Gui):Get(name)end,Wait=task.wait,Stopped=function()return ScriptUnloaded end})
local function OpenMenu(Menu)
    local ok,opened=GameCall(function()return QuickMenuController.Request(Menu)end)
    if not ok or not opened then Library:Notify("This game menu is unavailable in the current context",4)end
end

SetGlobal("upgrade to max")
local InventoryUpgrading={}
local function UpgradeToMax(slotName)
    if InventoryUpgrading[slotName] or not SV.CanRequire or ScriptUnloaded then return end
    InventoryUpgrading[slotName]=true
    pcall(function()
        local equips=ReplicatedStorage.PlayerEquips:FindFirstChild(PlayerName)
        local slot=equips and equips:FindFirstChild(slotName)
        local item=slot and slot:FindFirstChildWhichIsA("Folder")
        if not item then return end
        local upgrades=require(Shared:WaitForChild("ItemUpgrade",10))
        local profiles=require(Shared:WaitForChild("Profile",10))
        for _=1,150 do
            if ScriptUnloaded or item.Parent~=slot or SV.TransitionPending then break end
            if upgrades:GetUpgrade(item)>=upgrades:GetUpgradeLimit(item) then break end
            local cost=upgrades:GetUpgradeCostForItem(item)
            if type(cost)~="number" or profiles:GetGold(PlayerProfile)<cost then break end
            upgrades:UpgradeItem(LocalPlayer,item,false)
            task.wait(0.4)
        end
        if Library and not Library.Unloaded then
            Library:Notify(slotName.." upgrade: "..tostring(upgrades:GetUpgrade(item)).."/"..tostring(upgrades:GetUpgradeLimit(item)),4)
        end
    end)
    InventoryUpgrading[slotName]=nil
end

SetGlobal("expand part size")
local function ExpandPartSize(Part)
    if ISV.Debug then
        
    end
    local PreviousTriggerSize = Part.Size
    Part.Size = Vector3.new(2048, 2048, 2048)
    task.wait(1)
    Part.Size = PreviousTriggerSize
end

SetGlobal("find part")
local function FindPart(Location, PartData)
    local MainParent
    local DeleteOnceFound
    if not Location then
        MainParent = MissionObjects
    elseif Location == "CheckpointGates" then
        MainParent = MissionObjects:WaitForChild("CheckpointGates", math.huge)
    elseif Location == "NoParent" then
        MainParent = Workspace
    elseif Location == "BossRoom" then
        MainParent = MissionObjects:WaitForChild("BossRoom", math.huge)
    elseif Location == "DeleteParts" then
        MainParent = Workspace
        DeleteOnceFound = true
    end


    for _, PartName in PartData do
        if type(PartName) == "string" then
            MainParent = MainParent:WaitForChild(PartName, math.huge)
        end
    end

    if DeleteOnceFound then
        MainParent:Destroy()
        MainParent = nil
        if PartData.MultipleExists then
            FindPart(Location, PartData)
        end
        return
    end

    local TouchInterest
    if PartData.DescendantCheck then
        for Index, Part in MainParent:GetDescendants() do
            if Part.ClassName == "TouchTransmitter" then
                MainParent = Part.Parent
                TouchInterest = Part
                break
            end
        end
    else 
        TouchInterest = MainParent:WaitForChild("TouchInterest", math.huge)
    end

    local StartingPartSize = MainParent.Size
    local StartingPartCollision = MainParent.CanCollide
    local StartingPosition = MainParent.Position
    if SV and SV.Autofarm then
        MainParent.Size = Vector3.new(1, 1, 1)
        MainParent.CanCollide = false
    end
    if SV then
        TeleportParts[MainParent] = {
            TouchPart = TouchInterest,
            OriginalLocation = StartingPosition,
            OriginalSize = StartingPartSize,
            OriginalCollision = StartingPartCollision,
            Regenerates = PartData.Regenerates or nil,
            AutoTouchTimer = PartData.AutoTouch and time()+1.5 or nil,
            DontTeleport = PartData.DontTeleport or nil
        }
        if PartData.Regenerates then
            while not KillSwitch do
                repeat
                    task.wait(0.5)
                until not TouchInterest.Parent or not TouchInterest.Parent and TouchInterest.Parent
                TouchInterest = MainParent:WaitForChild("TouchInterest", math.huge)
                if SV and SV.Autofarm then
                    MainParent.Size = Vector3.new(1, 1, 1)
                end
                MainParent.CanCollide = false
                TeleportParts[MainParent] = {
                    TouchPart = TouchInterest,
                    OriginalLocation = StartingPosition,
                    OriginalSize = StartingPartSize,
                    OriginalCollision = StartingPartCollision,
                    Regenerates = PartData.Regenerates or nil,
                    AutoTouchTimer = PartData.AutoTouch and time()+1.5 or nil,
                    DontTeleport = PartData.DontTeleport or nil
                }
                task.wait()
            end
        end
    end
end

SetGlobal("disconnect variables")
local function DisconnectVariable(Connection)
    if ConnectionTable[Connection] then
        ConnectionTable[Connection]:Disconnect()
        ConnectionTable[Connection] = nil
    end
end

SetGlobal("teleport stand part")
local function TeleportStandPart()
    if PlayerStandPart then
        PlayerStandPart.CFrame = CFrame.new(PlayerCollider.Position.X, (PlayerCollider.Position.Y-StandPartHeight), PlayerCollider.Position.Z)
    end
end

SetGlobal("dodge current attack")
local function DodgeCurrentAttack(delay,length,name,adjustZ,cancelled,destination)
    if SV.DodgingAttack or EventOverride or ScriptUnloaded or SV.TransitionPending then return false end
    local owner={}
    SV.DodgeOwner=owner
    SV.DodgingAttack=true
    local previousStop,previousTarget=TempStop,CanTarget
    local function stop(phase)
        return ScriptUnloaded or KillSwitch or EventOverride or SV.TransitionPending
            or not PlayerRoot or not PlayerRoot.Parent
            or (cancelled and cancelled(phase))
    end
    local ok=pcall(function()
        local deadline=os.clock()+math.max(0,delay or 0)
        while os.clock()<deadline do
            if stop("delay") then return end
            task.wait()
        end
        if stop("delay") then return end
        local position=destination or Vector3.new(PlayerRoot.Position.X,PlayerRoot.Position.Y+200,PlayerRoot.Position.Z+(adjustZ or 0))
        if SV.SafeKillaura then CanTarget=false end
        TempStop=true
        Library:Notify("Dodging attack: "..(name or "hazard"),math.max(1,length or 0))
        deadline=os.clock()+math.max(0,length or 0)
        while os.clock()<deadline and not stop("active") do
            PlayerRoot.CFrame=CFrame.new(position)
            TeleportStandPart()
            task.wait()
        end
    end)
    -- Toggle changes, errors and removed targets must release the farming pause.
    if SV.DodgeOwner==owner then
        TempStop=previousStop
        CanTarget=previousTarget
        SV.DodgeOwner=nil
        SV.DodgingAttack=nil
    end
    return ok
end

SetGlobal("teleport to orb")
local function TeleportToOrb(Orb)
    CheckForCharacter()
    local Success, Result = pcall(function()
        while SV.DodgingAttack do
            task.wait()
        end

        local OrbPart = Orb:WaitForChild("Particles", 5) or false
        if not OrbPart then
            
            return
        end

        if SV.SafeKillaura then
            CanTarget = false
        end

        local TeleportStart = time() + 0.5
        while time() < TeleportStart do
            TempStop = true
            PlayerRoot.CFrame = CFrame.new(OrbPart.Position)
            TeleportStandPart()
            task.wait()
        end
        CanTarget = true
        TempStop = false
    end)
    if not Success then
        
    end
end

SetGlobal("build attacks")
local function BuildAttackData(TargetTable, TargetIndex)
    TargetIndex = tostring(TargetIndex)
    local AttackSkills = TargetTable[TargetIndex].Skills
    if not AttackSkills then
        TargetTable[TargetIndex].Skills = {}
        for SkillIndex, SkillInfo in TargetTable[TargetIndex].SkillInfo do
            local NumberOfAttacks = SkillInfo[1]
            local AttackName = SkillInfo[2]
            local AttackCooldown = SkillInfo[3]
            local AttackType = SkillInfo[4]
            local AttackDistance = SkillInfo[5]
            local SkipFirst = SkillInfo.SkipFirst
            local FormatSkill = SkillInfo.FormatSkill
            local IncrementDistance = SkillInfo.IncrementD
            local AddCooldown = SkillInfo.AddCd
            local Rollback = SkillInfo.Rollback
            local BuiltAttackData = {}
            local AddedAttackDistance = 0
            local IsAttackTable = if type(AttackName) == "table" then true else false
            local IsCooldownTable = if type(AttackCooldown) == "table" then true else false
            local IsDistanceTable = if type(AttackDistance) == "table" then true else false

            for Count = 1, NumberOfAttacks do
                local StartingCount = Count
                local SkillName = if IsAttackTable then AttackName[Count] else AttackName
                local SkillCooldown = if IsCooldownTable then if #AttackCooldown == 1 then AttackCooldown[1] else AttackCooldown[Count] else AttackCooldown
                local SkillDistance = if IsDistanceTable then AttackDistance[Count] else AttackDistance

                if Rollback then
                    Count -= 1
                end

                if not IsAttackTable and NumberOfAttacks > 1 then
                    if Count <= 1 and SkipFirst then
                        if Rollback then
                            if Count == 0 then
                                Count = ""
                            end
                        else
                            Count = ""
                        end
                    end
                else
                    Count = ""
                end

                if typeof(SkillName) ~= "Instance" then
                    if not FormatSkill then
                        SkillName = SkillName..Count
                    else
                        SkillName = string.gsub(SkillName, "*", Count)
                    end
                end

                if IncrementDistance and StartingCount >= IncrementDistance[1] then
                    AddedAttackDistance += IncrementDistance[2]
                    SkillDistance += AddedAttackDistance
                end

                if AddCooldown and StartingCount >= AddCooldown[1] then
                    SkillCooldown += AddCooldown[2]
                end

                table.insert(TargetTable[TargetIndex].Skills, {Skill = SkillName, Cooldown = SkillCooldown, Type = AttackType, Distance = SkillDistance})
            end
        end
        TargetTable[TargetIndex].SkillInfo = nil
    end

    return TargetTable[TargetIndex]
end

SetGlobal("get player pet")
local function GetPlayerPet(IsCancelled)
    local LookupDeadline = os.clock() + 5
    CheckForCharacter()
    local rPets = require(Pets)
    while not (KillSwitch or ScriptUnloaded) and os.clock() < LookupDeadline do
        if IsCancelled and IsCancelled() then return nil end
        local PetData = PlayerCharacter and PlayerCharacter:FindFirstChild("PetData")
        if PetData and PetSkills then
            task.wait(.5)
            local ItemName = PetData:GetAttribute("ItemName")
            if ItemName and string.find(tostring(ItemName), "Egg") then
                task.wait(1)
                continue
            end
            local PetName = ReplicatedStorage.PlayerEquips[PlayerName].Pet:FindFirstChild(ItemName)
            if not PetName then
                task.wait(1)
                continue
            end
            local PetRef = rPets:GetPetSkillFromPetRef(PetName)
            if not PetRef then
                task.wait(1)
                continue
            end
            return BuildAttackData(PetSkills, PetRef)
        end
        task.wait(1)
    end
end

local CombatSchedule=(function()
local Schedule={}
function Schedule.Create(environment,server,clock)
    local state=environment.LarpZeroCombatCooldowns
    if type(state)~="table" or state.Server~=server then
        state={Server=server,ReadyAt={}}
        environment.LarpZeroCombatCooldowns=state
    end
    local controller={}
    function controller.Ready(key)return clock()>=(state.ReadyAt[key] or 0)end
    function controller.Reserve(key,seconds)
        local duration=tonumber(seconds)or 0
        if duration~=duration or duration<0 then duration=0 end
        state.ReadyAt[key]=clock()+duration
    end
    return controller
end
return Schedule

end)().Create(getgenv(),game.JobId,time)

SetGlobal("get player class")
local function GetPlayerClass()
    SV.PlayerClass = WaitForAttribute(LocalPlayer, "Class")
    if ConnectionTable.ClassConnection then
        DisconnectVariable("ClassConnection")
    end
    task.spawn(function()
        if SV.PlayerClass == "Summoner" then
            local OnCollected = Remotes:WaitForChild("Effect_SoulObject_OnCollected", math.huge)
            ConnectionTable["ClassConnection"] = OnCollected.OnClientEvent:Connect(function(a, b, GUID, d, e)
                OnCollected:FireServer(GUID)
            end)
        elseif SV.PlayerClass == "Necromancer" then
            local OnCollected = Remotes:WaitForChild("Effect_SoulObjectNecromancer_OnCollected", math.huge)
            ConnectionTable["ClassConnection"] = OnCollected.OnClientEvent:Connect(function(a, b, GUID, d, e)
                OnCollected:FireServer(GUID)
            end)
        elseif SV.PlayerClass == "Dragoon" then
            local EnemyMarked = Remotes:WaitForChild("Combat_EnemyMarked", math.huge)
            local LastCombo = 0
            ConnectionTable["ClassConnection"] = EnemyMarked.OnClientEvent:Connect(function(Marked, b, c, d)
                if time() < LastCombo then
                    return
                end
                Remotes:WaitForChild("Skillset_Dragoon_InfinityStrikeStart", math.huge):FireServer()
                task.wait(0.2)
                Remotes:WaitForChild("Skillset_Dragoon_InfinityStrike", math.huge):FireServer()
                task.wait(0.2)
                Remotes:WaitForChild("Skillset_Dragoon_MultiStrike", math.huge):FireServer()
                task.wait(0.2)
                Remotes:WaitForChild("Skillset_Dragoon_DragonSlam", math.huge):FireServer()
                LastCombo = time()+9
            end)
        elseif SV.PlayerClass == "Demon" then
            local LifeSteal = Remotes:WaitForChild("Skillset_Demon_LifeSteal", math.huge)
            while SV.PlayerClass == "Demon" do
                if KillSwitch then
                    break
                end
                repeat
                    task.wait()
                until CurrentMob
                LifeSteal:FireServer({CurrentMob, CurrentMob, CurrentMob})
                task.wait(8.1)
            end
        end
    end)
    if ClassSkills then
        if ClassSkills[SV.PlayerClass].Distance == "Ranged" then
            SV.IsRanged = true
        else
            SV.IsRanged = nil
        end

        local ranged=ClassSkills[SV.PlayerClass].Distance=="Ranged"
        local x=Options[ranged and "ChangedRangedXSlider" or "ChangedMeleeXSlider"]
        local y=Options[ranged and "ChangedRangedYSlider" or "ChangedMeleeYSlider"]
        if x and y then Xdistance=x.Value Ydistance=y.Value end
        return BuildAttackData(ClassSkills, SV.PlayerClass)
    else
        
    end
end

SetGlobal("build shop values")
local function BuildShopValues(TargetDropdown, TargetShop)
    if type(TargetShop) == "table" then
        local ShopDisplay = {}
        local ShopReal = {}
        for Index, Data in TargetShop do
            local DisplayName = Data.VisualName.." (" .. FormatNumber(Data.CoinPrice) .. ", " ..Data.CurrencyType.. ")"
            table.insert(ShopDisplay, DisplayName)
            ShopReal[DisplayName] = { InternalName = Data.InternalName, VisualName = Data.VisualName, CoinPrice = Data.CoinPrice, CurrencyType = Data.CurrencyType}
        end
        table.sort(ShopDisplay, function(a, b)
            return ShopReal[a].CoinPrice < ShopReal[b].CoinPrice
        end)

        Options[TargetDropdown]:SetValues(ShopDisplay)
        return ShopReal
    end
    local rItems
    if SV.CanRequire then
        rItems = require(Items)
    end
    local FoundShopName = TargetShop
    local FoundShop = Shop.LocalShops:FindFirstChild(TargetShop) or nil
    if not FoundShop then
        
        return
    end

    local CurrencyItem = FoundShop:FindFirstChild("CurrencyItem") or nil
    if not CurrencyItem then
        
    end

    FoundShop = FoundShop:FindFirstChild("Items") or nil
    if not FoundShop then
        
        return
    end

    local ShopDisplay = {}
    local ShopReal = {}
    for Index, Item in FoundShop:GetChildren() do
        local ItemPrice = Item.AskingPrice.Value
        local ItemName
        if rItems then
            ItemName = rItems[Item.Name].DisplayKey
        else
            ItemName = Item.Name
        end
        if #ItemName > 20 then
            ItemName = string.sub(ItemName, 1, 20):gsub("%s+$", "") .. "..."
        end
        local DisplayName = ItemName.." (" .. FormatNumber(ItemPrice) .. ")"
        table.insert(ShopDisplay, DisplayName)
        ShopReal[DisplayName] = { InternalName = Item.Name, VisualName = ItemName, CoinPrice = ItemPrice }
    end

    table.sort(ShopDisplay, function(a, b)
        return ShopReal[a].CoinPrice < ShopReal[b].CoinPrice
    end)

    ShopReal.ShopInfo = { ShopName = FoundShopName, Currency = CurrencyItem.Value }

    Options[TargetDropdown]:SetValues(ShopDisplay)
    return ShopReal
end

SetGlobal("mass item sell")
local function RecycleFromInventory(Method, SelectedItems)
    local HexesToSave = {}
    local AddHexes = Options.SaveUserHexesInput.Value
    if AddHexes then
        if AddHexes ~= "" and AddHexes ~= " " then
            local StandardizeCommas = string.gsub(AddHexes, ", ", ",")
            local RemoveHashTags = string.gsub(StandardizeCommas, "#", "")
            local SplitHexes = string.split(RemoveHashTags, ",")
            for Index, Hex in SplitHexes do
                if Hex ~= "" and Hex ~= " " then
                    table.insert(HexesToSave, string.lower(Hex))
                end
            end
        end
        for Index, Hex in SV.SpecialHexColors do
            table.insert(HexesToSave, Hex)
        end
    end

    local fresh=Remotes:WaitForChild("Profile_GetCosmetics",10):InvokeServer()
    if type(fresh)~="table" then return end
    local safe={}
    for _,item in pairs(fresh) do
        if item.uuid and not item.lock and not item.fav then safe[item.uuid]=item end
    end
    local ItemsToRecycle = {}
    for ItemName, GroupedData in (SV.RealCosmeticTable or {}) do
        if SelectedItems[ItemName] then
            for Index, ItemData in GroupedData do
                local current=safe[ItemData.UUID]
                if not current then continue end
                if current.d then
                    ItemData.Dye=Color3.new(current.d.r,current.d.g,current.d.b):ToHex()
                else ItemData.Dye=nil end
                local CheckDye = ItemData.Dye
                if CheckDye then
                    local GoodDye
                    for Index, Dye in HexesToSave do
                        if string.match(CheckDye, "^"..Dye) then
                            GoodDye = true
                            break
                        end
                    end
                    if not GoodDye then
                        table.insert(ItemsToRecycle, {
                            UUID = ItemData.UUID,
                            Name = ItemData.Name
                        })

                    end
                else
                    table.insert(ItemsToRecycle, {
                        UUID = ItemData.UUID,
                        Name = ItemData.Name
                    })

                end
            end
        end
    end

    if #ItemsToRecycle==0 then Library:Notify("No eligible selected cosmetics",3)return end
    if Method == "Recycle" then
        Library:Notify("Attempting to recycle " ..tostring(#ItemsToRecycle).. " items", 5)
        Remotes:WaitForChild("Recycler_Recycle", math.huge):FireServer(ItemsToRecycle)
    elseif Method == "Gold" then
        Library:Notify("Attempting to sell " ..tostring(#ItemsToRecycle).. " items", 5)
        Remotes:WaitForChild("Drops_SellItems", math.huge):InvokeServer(ItemsToRecycle)
    end
end

SetGlobal("item sell check")
local function ItemSellCheck(item,manual)
    if not item or InventoryBusy[item] then return end
    InventoryBusy[item]=true
    SellItemCheck+=1
    pcall(function()
        if not manual then task.wait(1)end
        local deadline=os.clock()+8
        while EquipInProgress>0 and not ScriptUnloaded and os.clock()<deadline do task.wait(0.1)end
        if ScriptUnloaded or EquipInProgress>0 or not IsInventoryItem(item) then return end
        if not manual and not Toggles.AutoSellToggle.Value then return end
        local rarity,expectedPerks=GetRarity(item)
        local ref=SV.Items and SV.Items[item.Name]
        local perks={}
        if SV.KeepPerks and expectedPerks then
            for index=1,expectedPerks do
                if not item:FindFirstChild("Perk"..index) then return end
            end
        end
        for _,child in ipairs(item:GetChildren()) do
            if child.Name:match("^Perk%d+$") then
                local value=child:FindFirstChild("PerkValue")
                if not value or child.Value=="" then return end
                perks[child.Value]=value.Value
            end
        end
        local state={
            kind=ref and ref.Type,rarity=rarity,perks=perks,
            protected=ProtectedInventoryItem(item),stackable=item:FindFirstChild("Count")~=nil,
            equipped=not IsInventoryItem(item),towerEgg=IsTowerEgg(item)==true,
        }
        local config={
            keepTier=KeepTier,includePets=SV.IncludePets,includeCharms=SV.IncludeCharms,
            sellTowerEggs=SV.SellTowerEggs,keepPerks=SV.KeepPerks,
            selectedPerks=SV.SelectedPerks,offset=OffsetMax,
        }
        if InventoryPolicy.ShouldSell(state,config) and IsInventoryItem(item) and not ProtectedInventoryItem(item) then SellItem(item)end
    end)
    InventoryBusy[item]=nil
    SellItemCheck=math.max(0,SellItemCheck-1)
end

SetGlobal("check score")
local function SetQuotaPause(group,enabled)
    SV.QuotaStops=SV.QuotaStops or {}
    SV.QuotaStops[group]=enabled and true or nil
    SV.QuotaPaused=next(SV.QuotaStops)~=nil
end
local function GetLeaderboardScore(Leaderboard, TotalLabel, DailyLabel, TotalAllowed, DailyAllowed, EventBoss)
    TotalAllowed=tonumber(TotalAllowed)
    DailyAllowed=tonumber(DailyAllowed)
    if TotalAllowed and (TotalAllowed<=0 or TotalAllowed~=TotalAllowed or TotalAllowed==math.huge) then TotalAllowed=nil end
    if DailyAllowed and (DailyAllowed<=0 or DailyAllowed~=DailyAllowed or DailyAllowed==math.huge) then DailyAllowed=nil end
    if not TotalLabel or not DailyLabel or not Leaderboard or Leaderboard=="" then return false end
    local SelectedLeaderboard = tostring(Leaderboard)
    if EventBoss then
        local Date = os.date("*t")
        local Year = Date["year"]
        SelectedLeaderboard = SelectedLeaderboard.. tostring(Year)
    end

    local GetScore = Remotes:WaitForChild("LeaderboardHookup_GetScore", math.huge)
    LeaderboardData = GetScore:InvokeServer(SelectedLeaderboard, 1)
    if not LeaderboardData then
        LeaderboardData = GetScore:InvokeServer(SelectedLeaderboard, 5)
    end

    if not LeaderboardData then
        TotalLabel:SetText("Total: NO DATA")
        DailyLabel:SetText("Daily: NO DATA")
        return
    end
    local TotalScore = tonumber(LeaderboardData[1])
    local DailyScore = tonumber(LeaderboardData[2])

    TotalLabel:SetText("Total: " ..FormatNumber(TotalScore))
    DailyLabel:SetText("Daily: " ..FormatNumber(DailyScore))

    local reached=(TotalAllowed and TotalScore and TotalScore>=TotalAllowed) or (DailyAllowed and DailyScore and DailyScore>=DailyAllowed)
    SetQuotaPause(EventBoss and "event" or "nightmare",reached==true)
    if reached then
        Library:Notify("Limit reached, if you update the limit please restart the dungeon to continue.")
        return true
    end
end

SetGlobal("create toggles")
local function CreateToggles(ToggleTable)
    for Index, Data in ToggleTable do
        local FunctionValue = Data.FunctionValue or nil
        local DataTable = {
            Text = Data.Text,
            Default = if Data.Button then nil else false,
            Tooltip = Data.Tooltip or nil
        }

        if Data.AttachedFunction then
            if not Data.Button then
                DataTable.Callback = function(ChangedValue)
                    Data.AttachedFunction(ChangedValue, FunctionValue)
                end
            else
                DataTable.Func = function(ChangedValue)
                    Data.AttachedFunction(FunctionValue, ChangedValue)
                end
            end
        end

        if not Data.Button then
            Data.Tab:AddToggle(tostring(Data[1]), DataTable)
        else
            Data.Tab:AddButton(DataTable)
        end
    end
end

Library = BundledUI()
LarpZeroInstance.Library=Library
LarpZeroInstance.Loading=false
Library.ScreenGui:SetAttribute("LarpZeroMenu",true)
Library.ScreenGui:SetAttribute("LarpZeroBuild","2026.11.06-r10")
Library.ScreenGui:SetAttribute("LarpZeroSourceHash","7da0ce1f9bc9")
if LarpZeroStartupLock then
    LarpZeroStartupLock:SetAttribute("Loading",false)
    local menu=Instance.new("ObjectValue")
    menu.Name="Menu"
    menu.Value=Library.ScreenGui
    menu.Parent=LarpZeroStartupLock
end
Library:OnUnload(function()
    KillSwitch=true
    ScriptUnloaded=true
    for name,toggle in pairs(Toggles or {})do
        if name~="SafeModeToggle" and toggle.Value and type(toggle.Changed)=="function" then
            pcall(function()toggle.Changed(false)end)
        end
    end
    SV.Killaura=nil SV.SafeKillaura=nil SV.Autofarm=nil
    for _,connection in pairs(ConnectionTable) do
        pcall(function()connection:Disconnect()end)
    end
    if PlayerRoot and PlayerRoot.Parent then PlayerRoot.CanCollide=true end
    if PlayerStandPart then PlayerStandPart:Destroy() end
    if getgenv().LarpZeroInstance==LarpZeroInstance then getgenv().LarpZeroInstance=nil end
    if LarpZeroStartupLock then LarpZeroStartupLock:Destroy() end
end)
Options = Library.Options
Toggles = Library.Toggles

SetGlobal("creating window")
local Window = Library:CreateWindow({
    Title = "Larp Zero",
    Footer = "Readable local build",
    Icon = 17210785932,
    NotifySide = "Right",
    AutoShow = true,
    ShowCustomCursor = false,
    ToggleKeybind = Enum.KeyCode.Zero,
    EnableCompacting = true
})
Window:SetCornerRadius(20)

if not SV.GeneralTab then -- for unloaded general tab
SetGlobal("creating general tab")
local GenTab = Window:AddTab({
    Name = "General",
    Icon = "rbxassetid://9671045892"
})
if IsMainMenu or IsWorld then
    GenTab:UpdateWarningBox({
        Title = "Warning",
        Text = "Safe Mode blocks combat and autofarm outside dungeons. Switch TOGGLE SAFE MODE off to allow world farming.",
        IsNormal = false,
        Visible = true,
        LockSize = true
    })
end
local LeftTab = GenTab:AddLeftTabbox("Left Tabbox")
    local FirstTab = LeftTab:AddTab("Main")
    local SecondTab = LeftTab:AddTab("Settings")
local RightTab = GenTab:AddRightTabbox("Right Tabbox")
    local ThirdTab = RightTab:AddTab("Extra")
    local FourthTab = RightTab:AddTab("Settings")

local function ToggleKillaura(ChangedValue)
    if ChangedValue then
        Toggles.KillauraToggle:SetDisabled(true)
        Toggles.KillauraToggle:SetText("<font color='#FF3333'>Killaura</font>")
    else
        Toggles.KillauraToggle:SetDisabled(false)
        Toggles.KillauraToggle:SetText("<font color='#ffffff'>Killaura</font>")
    end
end
local function ToggleSafeKillaura(ChangedValue)
    if ChangedValue then
        Toggles.SafeKillauraToggle:SetDisabled(true)
        Toggles.SafeKillauraToggle:SetText("<font color='#FF3333'>Safe killaura</font>")
    else
        Toggles.SafeKillauraToggle:SetDisabled(false)
        Toggles.SafeKillauraToggle:SetText("<font color='#ffffff'>Safe killaura</font>")
    end
end


local RestrictedFeatures = {"KillauraToggle", "SafeKillauraToggle", "AutoProgressToggle", "PetKillauraToggle", "GeneralClassBuffToggle", "MoLBarrierToggle", "DemonBloodBindingToggle", "StormcallerSuperchargeToggle"}
local function ApplySafeMode(enabled)
    SV.SafeMode = enabled
    local blocked = enabled and not IsDungeon
    local changed = SV.SafeModeBlocked ~= blocked
    SV.SafeModeBlocked = blocked
    for _,name in ipairs(RestrictedFeatures) do
        local toggle = Toggles[name]
        if toggle then
            toggle:SetDisabled(blocked)
            if changed and toggle.Value and type(toggle.Changed)=="function" then
                if blocked then
                    pcall(function()toggle.Changed(false)end)
                else
                    task.spawn(function()
                        if not KillSwitch and not ScriptUnloaded and toggle.Value and not SV.SafeModeBlocked then
                            pcall(function()toggle.Changed(true)end)
                        end
                    end)
                end
            end
        end
    end
end
SV.RefreshSafeMode=ApplySafeMode
FirstTab:AddToggle("SafeModeToggle", {
    Text = "TOGGLE SAFE MODE",
    Default = true,
    Tooltip = "Block combat and autofarm outside dungeons.",
    Callback = ApplySafeMode
})

CreateToggles({
    { "KillauraToggle", Text = "Killaura", Tab = FirstTab, AttachedFunction = ToggleSafeKillaura },
    { "SafeKillauraToggle", Text = "Safe killaura", Tab = FirstTab, AttachedFunction = ToggleKillaura },
    { "AutoProgressToggle", Text = "Autofarm", Tab = FirstTab },
    { "CollectDropToggle", Text = "Auto collect drops", Tab = ThirdTab },
    { "PetKillauraToggle", Text = "Pet killaura", Tooltip = "Vulnerable to getting detected by anticheat changes! Use at your own risk!", Tab = ThirdTab },
    { "RestartStuckToggle", Text = "Rejoin if stuck", Tooltip = "if you stop doing damage for a long enough period of time this toggle will assume you're stuck and attempt to restart the dungeon.", Tab = ThirdTab },
    { "DodgeLethalToggle", Text = "Dodge lethal damage", Tooltip = "Melee classes only. Some attacks may automatically be dodged even when turned off.", Tab = ThirdTab },
})
ApplySafeMode(true)
SecondTab:AddLabel("Account for ping", true)
SecondTab:AddSlider("PingSlider", {
    Text = "Ping",
    Suffix = "%",
    Default = 100,
    Min = 0,
    Max = 200,
    Rounding = 0,
    Compact = true,
    Tooltip = "Adds delay to when each attack is used based off your ping. May help reduce kicks.\nDOES NOT APPLY TO SAFE KILLAURA",
    Callback = function(ChangedValue)
        PingMultiplier = ChangedValue / 100
    end
})
SecondTab:AddLabel("Killaura attack delay", true)
SecondTab:AddSlider("AttackDelaySlider", {
    Text = "Seconds",
    Default = 0,
    Min = 0,
    Max = 2,
    Rounding = 2,
    Compact = true,
    Tooltip = "Adds delay to when each attack is used.\nDOES NOT APPLY TO SAFE KILLAURA",
    Callback = function(ChangedValue)
        AddedDelay = ChangedValue
    end
})
SecondTab:AddLabel("Delay between attacks", true)
SecondTab:AddSlider("DelayAttackSlider", {
    Text = "Seconds",
    Default = 0,
    Min = 0,
    Max = 0.5,
    Rounding = 2,
    Compact = true,
    Tooltip = "When time is added the script will wait that long between performing attacks. When fighting bosses this setting is ignored completely.",
    Callback = function(ChangedValue)
        if ChangedValue == 0 then
            DelayAttacks = false
        else
            DelayAttacks = ChangedValue
        end
    end
})
SecondTab:AddLabel("Mob teleport rotation speed", true)
SecondTab:AddSlider("MobRotationSpeedSliderNew", {
    Text = "Studs",
    Default = 20,
    Min = 0,
    Max = 100,
    Rounding = 0,
    Compact = true,
    Tooltip = "Controls how fast your character rotates around mobs when teleporting to them. If you set it too fast and you're using a melee class then the script may not be able to do damage to mobs effectively.",
    Callback = function(ChangedValue)
        MobRotationSpeed = ChangedValue
    end
})
FourthTab:AddLabel("Pet killaura attack delay", true)
FourthTab:AddSlider("DelayPetAttackSlider", {
    Text = "Seconds",
    Default = 0,
    Min = 0,
    Max = 2,
    Rounding = 2,
    Compact = true,
    Tooltip = "Controls the delay between pet attacks when using the `Pet killaura` toggle",
    Callback = function(ChangedValue)
        if ChangedValue == 0 then
            DelayPetAttacks = false
        else
            DelayPetAttacks = ChangedValue
        end
    end
})
FourthTab:AddLabel("Rejoin on error delay", true)
FourthTab:AddSlider("RestartStuckSlider", {
    Text = "Seconds",
    Default = StuckDelay,
    Min = 30,
    Max = 120,
    Rounding = 0,
    Compact = true,
    Tooltip = "Controls how long it takes for the script to rejoin the dungeon when something in the dungeon or script has broken causing you to be unable to complete it.",
    Callback = function(ChangedValue)
        StuckDelay = ChangedValue
    end
})
end -- for unloaded general tab

if not SV.EventTab then -- for unloaded event tab
SetGlobal("event tab")
local EventTabIconTable = {
    [1] = "rbxassetid://8202463897",
    [2] = "rbxassetid://8723477744",
    [3] = "rbxassetid://8723477744",
    [4] = "rbxassetid://9299343400",
    [5] = "rbxassetid://9299343400",
    [6] = "rbxassetid://11582306327",
    [7] = "rbxassetid://11582306327",
    [8] = "rbxassetid://124707423544340",
    [9] = "rbxassetid://124707423544340",
    [10] = "rbxassetid://5763863934",
    [11] = "rbxassetid://81638085579862",
    [12] = "rbxassetid://8202463897"
}
local EventTab = Window:AddTab({
    Name = "Events",
    Icon = EventTabIconTable[os.date("*t").month]
})
local LeftTab = EventTab:AddLeftTabbox("Left Tabbox")
    local FirstTab = LeftTab:AddTab("Boss fight")
    local SecondTab = LeftTab:AddTab("Advanced")
local RightTab = EventTab:AddRightTabbox("Right Tabbox")
    local ThirdTab = RightTab:AddTab("Wheel")
    local FourthTab = RightTab:AddTab("Battlepass")
    local FifthTab = RightTab:AddTab("Extra")

FirstTab:AddToggle("CollectBuffToggle", {
    Text = "Collect selected buffs",
    Default = false,
    Tooltip = "Pick buffs from the dropdown menu below that the script will pick up"
})
FirstTab:AddDropdown("OrbBuffDropdown", {
    Values = {
        "Damage Boost","Ultimate","Healing","Shield"
    },
    Multi = true,
    AllowNull = true,
    Default = "",
    MaxVisibleDropdownItems = 5,
    Searchable = true,
    Callback = function(ChangedValue)
        if IsDungeon and Options.OrbBuffDropdown:GetActiveValues(true) > 0 then
            local labels={["Damage Boost"]="DamageBuffOrb",Ultimate="UltChargeBuffOrb",Healing="HealthBuffOrb",Shield="DefenseBuffOrb"}
            SV.SelectedOrbs={}
            for key,enabled in pairs(ChangedValue) do if enabled then SV.SelectedOrbs[labels[key] or key]=true end end
        else
            SV.SelectedOrbs = nil
        end
    end
})
local TotalLabel, TotalAllowed
local DailyLabel, DailyAllowed
SecondTab:AddDropdown("EventBossDropdown", {
    Values = {
        "Cupid","Easter Bunny","Kraken","Vane","Fallen King","Korrupted Klaus"
    },
    Multi = false,
    AllowNull = false,
    Default = "",
    Text = "Select event boss",
    Searchable = true,
    Callback = function(ChangedValue)
        local keys={Cupid="CUPID_KILLS_",["Easter Bunny"]="EASTERBUNNY_KILLS_",Kraken="KRAKEN_KILLS_",Vane="VANE_KILLS_",["Fallen King"]="FALLENKING_KILLS_",["Korrupted Klaus"]="SANTA_KILLS_"}
        ChangedValue=keys[ChangedValue] or ChangedValue
        if (IsWorld or IsDungeon) and type(ChangedValue)=="string" and ChangedValue~="" then
            task.wait(1)
            if GetLeaderboardScore(ChangedValue, TotalLabel, DailyLabel, TotalAllowed, DailyAllowed, true) then
                Library:Notify("Event boss clear limit reached.", 999999999)
                SetQuotaPause("event",true)
            end
        end
    end
})
TotalLabel = SecondTab:AddLabel("Total: ?", false)
SecondTab:AddInput("TotalEventInput", {
    Text = "Stop after X total kills",
    Default = "",
    Placeholder = "number here",
    Callback = function(ChangedValue)
        SetQuotaPause("event",false)
        if IsDungeon then
            TotalAllowed = ChangedValue
        end
    end
})
    SecondTab:AddDivider({Margin = -5})
DailyLabel = SecondTab:AddLabel("Daily: ?", false)
SecondTab:AddInput("DailyEventInput", {
    Text = "Stop after X daily kills",
    Default = "",
    Placeholder = "number here",
    Callback = function(ChangedValue)
        SetQuotaPause("event",false)
        if IsDungeon then
            DailyAllowed = ChangedValue
        end
    end
})
local EventWheel=(function()
local Wheel={}
function Wheel.ParseAmount(value)
    local number=tonumber(value)
    if not number or number~=number or number==math.huge or number==-math.huge
        or number<1 or number%1~=0 or number>10000 then return nil end
    return number
end
function Wheel.Install(tab,library,context)
    local config=context.Config
    local spinner=context.Spinner
    local cost=tonumber(config and config.spinCost)
    if not cost or cost<=0 or cost~=cost or cost==math.huge then cost=nil end
    local amount=1
    local generation=0
    local state={Running=false,Completed=0,Requested=0,Sent=0,Charged=0}
    library.LarpZeroWheelState=state
    local label=tab:AddLabel(cost and ("Coin cost: "..tostring(cost)) or "Coin cost: unavailable",true)
    local status=tab:AddLabel("Wheel: ready",true)
    local function setStatus(text)
        state.Status=text
    end
    -- Native game calls can lower the worker's UI capabilities. Only this
    -- executor-owned heartbeat touches the hidden menu; the worker updates data.
    local rendered
    local renderer
    if context.Heartbeat then
        renderer=context.Heartbeat:Connect(function()
            if not library.Unloaded and state.Status and state.Status~=rendered then
                status:SetText("Wheel: "..state.Status)
                rendered=state.Status
            end
        end)
    end
    tab:AddInput("WheelSpinInput",{
        Text="Wheel spin amount",Default="1",Placeholder="number or all",
        Tooltip="Enter all to use all currently available coins, or a whole number from 1 to 10000. Spins advance on confirmed charges without waiting for the wheel animation.",
        Callback=function(value)
            amount=type(value)=="string" and value:lower():match("^%s*all%s*$") and "all" or Wheel.ParseAmount(value)
            if amount=="all" then label:SetText("Coin cost: all available coins")
            elseif not amount then label:SetText("Coin cost: enter a positive whole number (1–10000)")
            elseif not cost then label:SetText("Coin cost: unavailable")
            else label:SetText("Coin cost: "..tostring(amount*cost))end
        end,
    })
    local function stopped(token)
        return token~=generation or library.Unloaded or context.Stopped()
    end
    tab:AddButton({Text="Spin wheel",DoubleClick=true,Tooltip="Rapidly spin on server charge confirmations; prizes can arrive together afterward.",Func=function()
        if state.Running then setStatus("already spinning; use Cancel spins to stop")return end
        if not amount or not cost then setStatus("check the amount and event availability")return end
        if not spinner or not context.ChargeSignal then setStatus("event spinner unavailable")return end
        generation+=1
        local token=generation
        local requested=amount
        if amount=="all" then
            local coins=tonumber(context.Currency(spinner.CURRENCY))or 0
            requested=coins>=0 and coins<math.huge and math.floor(coins/cost)or 0
            if requested<1 then setStatus("not enough currency")return end
        end
        state.Running=true state.Completed=0 state.Requested=requested state.Sent=0 state.Charged=0
        local connection,chargeConnection
        task.spawn(function()
            local ok=pcall(function()
                state.Phase="connect prize signal"
                local received=0
                connection=spinner:GetPrizeReceivedSignal():Connect(function()
                    if received<state.Sent and not stopped(token)then
                        received+=1
                        state.Completed=math.min(received,state.Charged)
                    end
                end)
                chargeConnection=context.ChargeSignal:Connect(function(prizeIndex)
                    if type(prizeIndex)=="number" and state.Charged<state.Sent and not stopped(token)then
                        state.Charged+=1
                        state.Completed=math.min(received,state.Charged)
                    end
                end)
                for index=1,requested do
                    state.Phase="check availability"
                    if stopped(token) then setStatus("stopped by cancellation or transition")break end
                    if not spinner:IsSpinnerActive() then setStatus("not available in this location/event")break end
                    local coins=context.Currency(spinner.CURRENCY)
                    if not coins or coins<cost then setStatus("not enough currency")break end
                    if not spinner:CanJoinQueue(context.Player) then setStatus("already queued or not ready")break end
                    local before=state.Charged
                    state.Sent+=1
                    state.Phase="request queue"
                    if not spinner:RequestJoinQueue(context.Player)then
                        state.Sent-=1 setStatus("queue request rejected")break
                    end
                    state.Phase="wait for charge"
                    local deadline=os.clock()+10
                    while state.Charged==before and not stopped(token)and os.clock()<deadline do task.wait()end
                    if stopped(token)then break end
                    if state.Charged==before then setStatus("charge not confirmed; stopped without retrying")break end
                    setStatus("paid "..state.Charged.."/"..requested.."; prizes "..state.Completed)
                    task.wait()
                end
                if state.Charged>state.Completed and not stopped(token)then
                    state.Phase="wait for prizes"
                    local deadline=os.clock()+math.max(30,(tonumber(config.SPINNER_TIMER)or 5)+15)
                    while state.Completed<state.Charged and not stopped(token)and os.clock()<deadline do task.wait(0.1)end
                end
                if not stopped(token)then
                    if state.Completed==requested then setStatus("completed "..state.Completed.."/"..requested)
                    elseif state.Charged>state.Completed then setStatus("paid "..state.Charged.."; prizes confirmed "..state.Completed.."; stopped")end
                end
            end)
            if connection then connection:Disconnect()end
            if chargeConnection then chargeConnection:Disconnect()end
            state.Running=false
            if not ok and not library.Unloaded then setStatus("spinner unavailable; stopped")end
        end)
    end})
    tab:AddButton({Text="Cancel spins",Func=function()
        generation+=1
        setStatus("cancelled; an accepted spin may still finish")
    end})
    library:OnUnload(function()
        generation+=1
        state.Running=false
        if renderer then renderer:Disconnect()end
    end)
end
return Wheel

end)()
local wheelSpinner,wheelConfig
pcall(function()
    wheelSpinner=require(Shared:WaitForChild("EventSpinner",5))
    wheelConfig=require(ReplicatedStorage.WorldModules:WaitForChild("EventSpinnerConfig",5))
end)
if wheelConfig and type(wheelConfig.Rewards)=="table" then
    SV.WheelItems={}
    for _,reward in ipairs(wheelConfig.Rewards)do
        if type(reward)=="table" and type(reward[1])=="string" then table.insert(SV.WheelItems,reward[1])end
    end
end
EventWheel.Install(ThirdTab,Library,{
    Player=LocalPlayer,Spinner=wheelSpinner,Config=wheelConfig,Heartbeat=RunService.Heartbeat,
    ChargeSignal=Remotes:FindFirstChild("EventSpinner_QueueUpdated") and Remotes.EventSpinner_QueueUpdated.OnClientEvent,
    Stopped=function()return ScriptUnloaded or KillSwitch or SV.TransitionPending end,
    Currency=function(name)
        local items=ProfileInventory and ProfileInventory:FindFirstChild("Items")
        local item=items and name and items:FindFirstChild(name)
        if not item then return 0 end
        local count=item:FindFirstChild("Count")
        return count and count.Value or 1
    end,
})

ThirdTab:AddDivider({Margin=-5})
local RecyclingItems
ThirdTab:AddButton({
    Text = "Recycle wheel items",
    Tooltip = "recycles all wheel items that are not locked or have a special hex\n\n<font color=\"rgb(255, 0, 0)\">you WILL crash if you have a lot of items, but they should be recycled when you rejoin</font>",
    DoubleClick = true,
    Func = function()
        if IsMainMenu or RecyclingItems then
            return
        end
        RecyclingItems = true
        local ok=pcall(function()
        if not SV.CanRequire then
            Library:Notify("Your executor doesn't support this option. Lacks require()", 5)
            return
        end

        local Profile_GetCosmetics = Remotes.Profile_GetCosmetics:InvokeServer()
        local rItems = require(Items)
        local ItemTable = {}
        local RealItemTable = {}
        local ScannedItems = {}
        local SelectedItems = {}

        -- create the table to look up items by their id's
        for Index, Item in SV.WheelItems do
            local ItemData = rItems[Item]
            if ItemData then
                ItemTable[ItemData.ID] = {
                    VisualName = tostring(ItemData.DisplayKey),
                    InternalName = tostring(Item)
                }
                SelectedItems[ItemData.DisplayKey] = true
            end
        end

        for Index, ItemData in Profile_GetCosmetics do
            if ItemData.lock or ItemData.fav then
                continue
            end
            local ItemRef = ItemTable[ItemData.id]
            if not ItemRef then
                continue
            end
            local VisualName = ItemRef.VisualName
            if not ScannedItems[VisualName] then
                ScannedItems[VisualName] = true
                RealItemTable[VisualName] = {}
            end
            if not ItemData.d then
                table.insert(RealItemTable[VisualName], {
                    UUID = ItemData.uuid,
                    Name = ItemRef.InternalName
                })
            else
                table.insert(RealItemTable[VisualName], {
                    UUID = ItemData.uuid,
                    Name = ItemRef.InternalName,
                    Dye = Color3.new(ItemData.d.r, ItemData.d.g, ItemData.d.b):ToHex()
                })
            end
        end

        SV.RealCosmeticTable = RealItemTable
        RecycleFromInventory("Recycle", SelectedItems)
        end)
        RecyclingItems=nil
        if not ok then Library:Notify("Wheel cosmetic processing is unavailable; nothing further was requested",4)end
    end
})
FourthTab:AddToggle("AutoClaimBattlepass", {
    Text = "Auto claim battlepass",
    Default = false,
    Tooltip = "Only works the first time it's turned on, if you gain a rank you will need to wait for the next teleport or toggle it off and on again before it attempts to claim rewards again"
})
do
    local Success, Result = pcall(function()
        if EF.Desync and EF.RaknetFunction and EF.RaknetFunction.is_enabled() then
            FifthTab:AddLabel("Can invisibly teleport: <font color='#33ff33'>Yes</font>", false)
        else
            FifthTab:AddLabel("Can invisibly teleport: <font color='#ff3333'>No</font>", false)
        end
    end)
    if not Success then
        FifthTab:AddLabel("Can invisibly teleport: <font color='#ff3333'>error</font>", false)
    end
end
    FifthTab:AddDivider({Margin = -5})
local FindingHidden
local DailyESP
FifthTab:AddLabel("Daily rewards", false)
FifthTab:AddButton({
    Text = "Teleport",
    Tooltip = "Teleports you to all of the daily rewards in the event hub such as the Obby end, Daily reward, and 3 hidden objects.\nIf you cannot invisibly teleport then you are blatantly teleported to all of them",
    Func = function()
        local Success, Result = pcall(function()
            if FindingHidden or IsMainMenu then
                return
            end
            local EventFinderReward = Workspace:FindFirstChild("EventFinderReward", true)
            if not EventFinderReward then
                Library:Notify("Go to the event hub if it is available.", 5)
                return
            end
            FindingHidden = true
            CheckForCharacter()
            local ReturnCFrame=PlayerRoot.CFrame
            local DailyFlags={}
            local DailiesToTeleportTo = {}

            if EventFinderReward then
                for Index, Object in EventFinderReward.Models:GetChildren() do
                    if Object.PrimaryPart then
                        table.insert(DailiesToTeleportTo,Object.PrimaryPart)
                        local index=Object.Name:match("(%d+)$")
                        if index then DailyFlags[Object.PrimaryPart]="EventFR"..index end
                    end
                end
            end

            local EventObbyReward = Workspace:FindFirstChild("EventObbyReward", true)
            if EventObbyReward then
                table.insert(DailiesToTeleportTo,EventObbyReward.Base)
                DailyFlags[EventObbyReward.Base]="EventDO"
            end
            
            local EventDailyReward = Workspace:FindFirstChild("EventDailyReward", true)
            if EventDailyReward then
                table.insert(DailiesToTeleportTo,EventDailyReward.Base)
                DailyFlags[EventDailyReward.Base]="EventDR"
            end
            
            if EF.Desync and EF.RaknetFunction.is_enabled() then
                EF.Desync(true)
                Remotes:WaitForChild("Health_Reset", math.huge):FireServer()
                task.wait(1)
                Remotes:WaitForChild("Health_Reset", math.huge):FireServer()
                LocalPlayer.CharacterAdded:Wait()
                task.wait(1)
            end

            Remotes:WaitForChild("SetMounted", math.huge):FireServer(true)
            task.wait(1)
            for Index, Object in DailiesToTeleportTo do
                if ScriptUnloaded then break end
                local key=DailyFlags[Object]
                local deadline=os.clock()+4
                repeat
                    if not Object.Parent or ScriptUnloaded then break end
                    PlayerRoot.CFrame=CFrame.new(Object.Position+Vector3.new(0,3,0))
                    task.wait(0.2)
                    local ok,claimed=GameCall(function()return require(Shared.Events):HasDailyFlag(LocalPlayer,key)end)
                    if ok and claimed then break end
                until os.clock()>=deadline
            end

            local Spawn = Workspace:FindFirstChild("Spawn")
            if Spawn and Spawn:IsA("BasePart") then
                local SpawnPosition=Spawn.Position+Vector3.new(0,Spawn.Size.Y/2+3,0)
                PlayerRoot.CFrame=CFrame.new(SpawnPosition)
            else PlayerRoot.CFrame=ReturnCFrame end
            task.wait(1)
            Remotes:WaitForChild("SetMounted", math.huge):FireServer(false)
            if EF.Desync and EF.RaknetFunction.is_enabled() then
                EF.Desync(false)
            end
            CollectCoins()
            FindingHidden = nil
        end)
        FindingHidden=nil
        if not Success then
            pcall(function()Remotes:WaitForChild("SetMounted",5):FireServer(false)end)
        end
    end
}):AddButton({
    Text = "ESP",
    Tooltip = "Adds a highlight around all hidden daily rewards around an event hubs map if available.",
    Func = function()
        local EventFinderReward = Workspace:FindFirstChild("EventFinderReward", true)
        if not EventFinderReward then
            Library:Notify("Go to the event hub if it is available.", 5)
            return
        end
        if DailyESP then
            return
        end

        DailyESP = true
        local DailiesToESP = {}
        if EventFinderReward then
            for Index, Object in EventFinderReward.Models:GetChildren() do
                table.insert(DailiesToESP, Object)
            end
        end

        local EventObbyReward = Workspace:FindFirstChild("EventObbyReward", true)
        if EventObbyReward then
            table.insert(DailiesToESP, EventObbyReward.Base)
        end
        
        local EventDailyReward = Workspace:FindFirstChild("EventDailyReward", true)
        if EventDailyReward then
            table.insert(DailiesToESP, EventDailyReward.Base)
        end
        for i, o in DailiesToESP do
            if not o:FindFirstChild("LarpZeroDailyESP") then
                local Highlight = Instance.new("Highlight")
                Highlight.FillTransparency = 0
                Highlight.Name = "LarpZeroDailyESP"
                Highlight.Parent = o
            else
                if o.LarpZeroDailyESP.Enabled then
                    o.LarpZeroDailyESP.Enabled = false
                else
                    o.LarpZeroDailyESP.Enabled = true
                end
            end
        end
        DailyESP = nil
    end
})
local TeleportingHoops
FifthTab:AddLabel("Claim flying hoops", false)
FifthTab:AddButton({
    Text = "Teleport hoops",
    Tooltip = "Teleports all the flying hoops on the map to your character and then returns them to their original position in an event hub if available.",
    Func = function()
        if TeleportingHoops or IsMainMenu then
            return
        end
        TeleportingHoops = 0
        CheckForCharacter()
        local Hoops = Workspace:FindFirstChild("Hoops")
        if Hoops then
            for Index, Hoop in Hoops:GetChildren() do
                TeleportingHoops = TeleportingHoops + 1
                task.spawn(function()
                    pcall(function()
                        local previous=Hoop:GetPivot()
                        Hoop:PivotTo(CFrame.new(PlayerRoot.Position))
                        task.wait(.1)
                        if Hoop.Parent then Hoop:PivotTo(previous)end
                    end)
                    TeleportingHoops-=1
                end)
            end
        else
            Library:Notify("Go to the event hub if it is available.", 5)
        end
        repeat task.wait()until TeleportingHoops==0
        TeleportingHoops = nil
    end
})
local FindingEggs
local EggESP
FifthTab:AddLabel("Scavenger hunt", false)
FifthTab:AddButton({
    Text = "Teleport",
    Tooltip = "Blatantly teleports your character to all of the hidden scavenger hunt objects on the map if there is a scavenger hunt available in the world you are in.\nIf available to your executor the script will reset your character and then invisibly teleport you to all of the hidden objects.",
    Func = function()
        local Success, Result = pcall(function()
            if not IsWorld or FindingEggs then
                return
            end
            local ScavengerHunts = Workspace:FindFirstChild("ScavengerHunts")
            if not ScavengerHunts then return end
            local EggHunt = ScavengerHunts:FindFirstChild("EggHunt")
            if not EggHunt then return end
            local Spawns = EggHunt:FindFirstChild("Spawns")
            if not Spawns then return end
            FindingEggs = true
            CheckForCharacter()
            if EF.Desync and EF.RaknetFunction.is_enabled() then
                EF.Desync(true)
                Remotes:WaitForChild("Health_Reset", math.huge):FireServer()
                task.wait(1)
                Remotes:WaitForChild("Health_Reset", math.huge):FireServer()
                LocalPlayer.CharacterAdded:Wait()
                task.wait(1)
            end
            Remotes:WaitForChild("SetMounted", math.huge):FireServer(true)
            task.wait(1)
            for Index, EggSpawn in Spawns:GetChildren() do
                local EggPosition = Vector3.new(EggSpawn.Position.X, EggSpawn.Position.Y+GetPlayerSize(), EggSpawn.Position.Z)
                PlayerRoot.CFrame = CFrame.new(EggPosition)
                task.wait(.5)
            end
            local Spawn = Workspace:FindFirstChild("Spawn")
            if not Spawn then return end
            local SpawnSize = Spawn.Size.Y / 2
            local SpawnPosition = Vector3.new(Spawn.Position.X, Spawn.Position.Y+SpawnSize, Spawn.Position.Z)
            PlayerRoot.CFrame = CFrame.new(SpawnPosition)
            task.wait(1)
            Remotes:WaitForChild("SetMounted", math.huge):FireServer(false)
            if EF.Desync and EF.RaknetFunction.is_enabled() then
                EF.Desync(false)
            end
            CollectCoins()
            FindingEggs = nil
        end)
        if not Success then
            
        end
    end
}):AddButton({
    Text = "ESP",
    Tooltip = "Adds a highlight around all of the scavenger hunt objects if there is a scavenger hunt active in your current world.",
    Func = function()
        local Success, Result = pcall(function()
            if EggESP then return end
            local ScavengerHunts = Workspace:FindFirstChild("ScavengerHunts")
            if not ScavengerHunts then return end
            local EggHunt = ScavengerHunts:FindFirstChild("EggHunt")
            if not EggHunt then return end
            local HuntContainer = EggHunt:FindFirstChild("_ScavengerHuntContainer")
            if not HuntContainer then return end
            EggESP = true
            for i, o in HuntContainer:GetChildren() do
                local Highlight = o:FindFirstChild("ESP Highlight")
                if not Highlight then
                    local NewHighlight = Instance.new("Highlight")
                    NewHighlight.Name = "ESP Highlight"
                    NewHighlight.FillTransparency = 0
                    NewHighlight.Parent = o
                elseif Highlight then
                    if Highlight.Enabled then
                        Highlight.Enabled = false
                    else
                        Highlight.Enabled = true
                    end
                end
            end
            EggESP = nil
        end)
        if not Success then
            
        end
    end
})
end -- for unloaded event tab

if not SV.TradingTab then -- for unloaded trading tab
SetGlobal("trading tab")
local TradeTab = Window:AddTab({
    Name = "Trading",
    Icon = "rbxassetid://9671046601"
})
local LeftTab = TradeTab:AddLeftTabbox("Left Tabbox")
    local FirstTab = LeftTab:AddTab("Player shop")
local RightTab = TradeTab:AddRightTabbox("Right Tabbox")
    local SecondTab = RightTab:AddTab("Trading")

local placedOwnShop=false
local shopGeneration=0
local function OwnShop()
    local spots=Workspace:FindFirstChild("ShopLocations")
    if not spots then return false end
    for _,spot in ipairs(spots:GetChildren())do
        local owner=spot:FindFirstChild("PlayerOwner")
        if owner and owner.Value==LocalPlayer then return true end
    end
    return false
end
FirstTab:AddToggle("PlacePlayerShopToggle",{
    Text="Auto place player shop",Default=false,Tooltip="Claims one free spot. Turning off releases a spot claimed by this script after the server cooldown.",
    Callback=function(enabled)
        shopGeneration+=1
        local generation=shopGeneration
        if enabled then
            if OwnShop() then return end
            local spots=Workspace:FindFirstChild("ShopLocations")
            if not spots then return end
            for _,spot in ipairs(spots:GetChildren())do
                local owner=spot:FindFirstChild("PlayerOwner")
                if owner and not owner.Value then
                    placedOwnShop=true
                    Remotes:WaitForChild("Shop_ClaimShop",5):FireServer(spot)
                    break
                end
            end
        elseif placedOwnShop then
            task.spawn(function()
                for _=1,3 do
                    if generation~=shopGeneration then return end
                    Remotes:WaitForChild("Shop_StopShop",5):FireServer()
                    task.wait(1.1)
                    if not OwnShop() then placedOwnShop=false return end
                end
            end)
        end
    end,
})
FirstTab:AddDropdown("PlayerShopDropdown", {
    Values = {},
    Default = "",
    Multi = false,
    Text = "Open selected players shop",
    Callback = function(ChangedValue)
        if ChangedValue and IsWorld and SV.CanRequire then
            local rShop = require(Client.Gui):Get("Shop")
            rShop:Close()
            rShop:Open(Players[tostring(ChangedValue)])
        end
    end
})
FirstTab:AddButton({
    Text = "Scan for active player shops",
    Func = function()
        local ActivePlayerShops = {}
        local ShopLocations = Workspace:FindFirstChild("ShopLocations")
        if not ShopLocations then
            return
        end
        for Index, Descendant in ShopLocations:GetDescendants() do
            if Descendant:IsA("ObjectValue") then
                if Descendant.Name == "PlayerOwner" then
                    local owner=Descendant.Value
                    if owner and owner~=LocalPlayer and owner:IsA("Player") then
                        table.insert(ActivePlayerShops,owner.Name)
                    end
                end
            end
        end
        Options.PlayerShopDropdown:SetValues(ActivePlayerShops)
    end
})
SecondTab:AddButton({
    Text = "Check trade for dupes",
    Func = function()
        if SV.CheckingTrade or IsMainMenu then
            return
        end

        SV.CheckingTrade = true

        local Success, Result = pcall(function()
            local pItems = ProfileInventory.Items
            local PlayerEquips = ReplicatedStorage.PlayerEquips:FindFirstChild(PlayerName)
            local CurrentTrade = nil
            local DupedItemCount = 0
            local ItemsToCheck = 0
            local StoredID = {}

            local function MarkItem(DupedItem)
                local NewFolder = Instance.new("Folder")
                    NewFolder.Name = "Explo".."ited"
                    NewFolder.Parent = DupedItem
                return
            end

            local function CheckForDupe(ItemToCheck)
                local ItemID = ItemToCheck.ID.Value
                for Index, CheckID in StoredID do
                    if CheckID.ID.Value == ItemToCheck.ID.Value then
                        MarkItem(CheckID)
                        Library:Notify("Found duped item: " ..CheckID.Name, 3)
                        DupedItemCount = DupedItemCount + 1
                        return
                    end
                end
                return
            end

            for Index, Trades in ReplicatedStorage:FindFirstChild("Trades"):GetChildren() do
                if Trades:FindFirstChild(PlayerName) then
                    CurrentTrade = Trades
                    break
                end
            end

            if not CurrentTrade then
                Library:Notify("You are not trading anyone", 3)
                SV.CheckingTrade = nil
                return
            end

            for Index, Players in CurrentTrade:GetChildren() do
                if Players.Name == LocalPlayer.Name then
                    continue
                end
                for Index, Descendant in Players:GetDescendants() do
                    if Descendant.Name == "ID" then
                        ItemsToCheck = ItemsToCheck + 1
                        table.insert(StoredID, Descendant.Parent)
                    end
                end
            end

            if ItemsToCheck == 0 then
                Library:Notify("No items to check", 3)
                SV.CheckingTrade = nil
                return
            end

            for Index, Descendant in pItems:GetDescendants() do
                if Descendant.Name =="ID" then
                    CheckForDupe(Descendant.Parent)
                end
            end

            for Index, Descendant in PlayerEquips:GetDescendants() do
                if Descendant.Name =="ID" then
                    CheckForDupe(Descendant.Parent)
                end
            end

            if DupedItemCount == 0 then
                Library:Notify("No duped items found", 3)
                SV.CheckingTrade = nil
                return
            end
        end)
        if not Success then
            
        end
        SV.CheckingTrade = nil
    end
})
SecondTab:AddButton({
    Text = "Trade with last person",
    Func = function()
        if SV.PlayerBeingTraded ~= nil then
            local TradeAccept = Remotes:WaitForChild("Trade_Accept")
            TradeAccept:FireServer(Players[SV.PlayerBeingTraded])

        else
            Library:Notify("Last trade not found. Did YOU receive and accept a trade?", 5)
        end
    end
})
end -- for unloaded trading tab

if not SV.ClassesTab then -- for unloaded classes tab
SetGlobal("creating class tab")
local ClassTab = Window:AddTab({
    Name = "Classes",
    Icon = "rbxassetid://9671047048"
})
LeftTab = ClassTab:AddLeftTabbox("Left Tabbox")
    FirstTab = LeftTab:AddTab("Main")
RightTab = ClassTab:AddRightTabbox("Right Tabbox")
    SecondTab = RightTab:AddTab("Extra")

CreateToggles({
    { "GeneralClassBuffToggle", Text = "General class buffs", Tooltip = "Gives you Dual Wielders and Guardians buff", Tab = FirstTab },
    { "MoLBarrierToggle", Text = "MoL barrier", Tooltip = "Gives everyone else in the game a barrier instead of only yourself\nOnly Mage of Light can use this", Tab = SecondTab },
    { "DemonBloodBindingToggle", Text = "Demon Blood Binding", Tooltip = "Activates Demons Blood Binding skill that takes away health while boosting your own damage\nOnly Demon can use this", Tab = SecondTab },
    { "StormcallerSuperchargeToggle", Text = "Stormcaller Supercharge", Tooltip = "Activates Stormcallers Supercharge skill that takes away health while boosting your own damage and healing you a little when inflicting the Supercharge status\nOnly Stormcaller can use this", Tab = SecondTab },
})

local RangedClassLabel = FirstTab:AddLabel("Ranged class distance", false)
FirstTab:AddSlider("ChangedRangedXSlider", {
    Text = "X",
    Default = 25,
    Min = -100,
    Max = 100,
    Rounding = 0,
    Compact = true,
    Tooltip = "Forward and Backwards\nDefault is 25",
    Callback = function(ChangedValue)
        if Class and Class.Distance == "Ranged" then
            Xdistance = ChangedValue
        end
    end
})
FirstTab:AddSlider("ChangedRangedYSlider", {
    Text = "Y",
    Default = 55,
    Min = -100,
    Max = 100,
    Rounding = 0,
    Compact = true,
    Tooltip = "Up and Down\nDefault is 55",
    Callback = function(ChangedValue)
        if Class and Class.Distance == "Ranged" then
            Ydistance = ChangedValue
        end
    end
})
    FirstTab:AddDivider({Margin = -5})
local MeleeClassLabel = FirstTab:AddLabel("Melee class distance", false)
FirstTab:AddSlider("ChangedMeleeXSlider", {
    Text = "X",
    Default = 13,
    Min = -50,
    Max = 50,
    Rounding = 0,
    Compact = true,
    Tooltip = "Forward and Backwards\nDefault is 13",
    Callback = function(ChangedValue)
        if Class and Class.Distance == "Melee" then
            Xdistance = ChangedValue
        end
    end
})
FirstTab:AddSlider("ChangedMeleeYSlider", {
    Text = "Y",
    Default = 8,
    Min = -50,
    Max = 50,
    Rounding = 0,
    Compact = true,
    Tooltip = "Up and Down\nDefault is 8",
    Callback = function(ChangedValue)
        if Class and Class.Distance == "Melee" then
            Ydistance = ChangedValue
        end
    end
})
end -- for unloaded classes tab

if not SV.InventoryTab then -- for unloaded inventory tab
SetGlobal("creating inventory tab")
local InventoryTab = Window:AddTab({
    Name = "Inventory",
    Icon = "rbxassetid://9671046778"
})
local LeftTab = InventoryTab:AddLeftTabbox("Left Tabbox")
    local FirstTab = LeftTab:AddTab("Inventory")
    local SecondTab = LeftTab:AddTab("Settings")
    local ThirdTab = LeftTab:AddTab("Equips")
local RightTab = InventoryTab:AddRightTabbox("Right Tabbox")
    local FourthTab = RightTab:AddTab("Cosmetics")
    local FifthTab = RightTab:AddTab("Hexes")

local function ToggleValue(ChangedValue, ToggleValue)
    if ChangedValue and not IsMainMenu then
        SV[tostring(ToggleValue)] = true
    else
        SV[tostring(ToggleValue)] = nil
    end
end

CreateToggles({
    { "AutoSellToggle", Text = "Auto sell items", Tooltip = "Only applies to new items. Eggs are not sold.", Tab = FirstTab },
    { "SellPetToggle", Text = "Sell pets", Tooltip = "Allow the auto sell functionalities to apply to pets as well", Tab = SecondTab, AttachedFunction = ToggleValue, FunctionValue = "IncludePets" },
    { "SellTowerEggToggle", Text = "Sell tower eggs", Tooltip = "Automatically sell eggs from towers if you are able to collect them", Tab = SecondTab, AttachedFunction = ToggleValue, FunctionValue = "SellTowerEggs" },
    { "SellCharmToggle", Text = "Sell charms", Tooltip = "Apply the same tier and perk protections to charms", Tab = SecondTab, AttachedFunction = ToggleValue, FunctionValue = "IncludeCharms" },
    { Button = true, Text = "Upgrade Primary", Tab = ThirdTab, AttachedFunction = UpgradeToMax, FunctionValue = "Primary" },
    { Button = true, Text = "Upgrade Offhand", Tab = ThirdTab, AttachedFunction = UpgradeToMax, FunctionValue = "Offhand" },
    { Button = true, Text = "Upgrade Armor", Tab = ThirdTab, AttachedFunction = UpgradeToMax, FunctionValue = "Armor" }
})
    FirstTab:AddDivider()
FirstTab:AddDropdown("AutoSellDropdown", {
    Values = {"none","3-5","4-5","5"},
    Multi = false,
    Text = "Keep tiers",
    AllowNull = false,
    Default = "5",
    Callback = function(ChangedValue)
        KeepTier=InventoryPolicy.Tier(ChangedValue)
        if KeepTier==nil then KeepTier=5 end
    end
})
    FirstTab:AddDivider()
CreateToggles({
    { "KeepSelectedPerkToggle", Text = "Keep selected perks", Tooltip = "By default only S+ perks are kept", Tab = FirstTab, AttachedFunction = ToggleValue, FunctionValue = "KeepPerks" }
})
local SavePerkTable = {
    ["Gold Hoarder"] = { PerkValue = 0.2, PetPerkValue = 0.2, PerkName = "GoldDrop" },
    ["Lucky Looter"] = { PerkValue = 0.1, PetPerkValue = 0.1, PerkName = "PetFoodDrop" },
    ["Energized"] = { PerkValue = 0.15, PetPerkValue = 0.15, PerkName = "UltCharge" },
    ["HP UP"] = { PerkValue = 0.12, PetPerkValue = 0.07, PerkName = "BonusHP" },
    ["Attack Up"] = { PerkValue = 0.08, PetPerkValue = 0.05, PerkName = "BonusAttack" },
    ["Agility"] = { PerkValue = 0.1, PetPerkValue = 0.1, PerkName = "BonusWalkspeed" },
    ["Burn Resistance"] = { PerkValue = 0.9, PetPerkValue = 0.9, PerkName = "ResistBurn" },
    ["Poison Resistance"] = { PerkValue = 0.9, PetPerkValue = 0.9, PerkName = "ResistPoison" },
    ["Frost Resistance"] = { PerkValue = 0.9, PetPerkValue = 0.9, PerkName = "ResistFrost" },
    ["Knockdown Resistance"] = { PerkValue = 0.9, PetPerkValue = 0.9, PerkName = "ResistKockdown" },
    ["Untouchable"] = { PerkValue = 0.2, PerkName = "DodgeChance" },
    ["Rough Skin"] = { PerkValue = 0.1, PerkName = "RoughSkin" },
    ["Damage Reduction"] = { PerkValue = 0.08, PerkName = "DamageReduction" },
    ["Life Drain"] = { PerkValue = 0.06, PerkName = "LifeDrain" },
    ["Burn Chance"] = { PerkValue = 0.15, PerkName = "BurnChance" },
    ["Frost Chance"] = { PerkValue = 0.15, PerkName = "FrostChance" },
    ["Poison Chance"] = { PerkValue = 0.15, PerkName = "PoisonChance" },
    ["Crit Stack"] = { PerkValue = 0.15, PerkName = "CritStack" },
    ["Poisonous Thorns"] = { PerkValue = 0.6, PerkName = "PoisonThorns" },
    ["Elemental Resistance"] = { PerkValue = 0.4, PetPerkValue = 0.15, PerkName = "Elemental" },
    ["Ferocious"] = { PerkValue = 0.4, PetPerkValue = 0.15, PerkName = "Ferocious" },
    ["Vampiric"] = { PerkValue = 0.15, PetPerkValue = 0.05, PerkName = "Vampiric" },
    ["Boss Bane"] = { PerkValue = 0.3, PetPerkValue = 0.1, PerkName = "TestTier5" },
    ["Mob Slayer"] = { PerkValue = 0.3, PetPerkValue = 0.1, PerkName = "MobBoss" },
    ["Elite Assassin"] = { PerkValue = 0.3, PetPerkValue = 0.1, PerkName = "EliteBoss" },
    ["Opening Strike"] = { PerkValue = 0.25, PerkName = "OpeningStrike" },
    ["Self Destruct"] = { PerkValue = 0.5, PerkName = "Destruction" },
    ["Fortress"] = { PerkValue = 0.4, PerkName = "Fortress" },
    ["Glass"] = { PerkValue = 1, PerkName = "Glass" },
    ["Master Thief"] = { PerkValue = 0.35, PerkName = "MasterThief" },
    ["Oblivion"] = { PerkValue = 0.05, PetPerkValue = 0.05, PerkName = "Oblivion" },
    ["Reckless"] = { PerkValue = 0.25, PetPerkValue = 0.25, PerkName = "Reckless" },
    ["Comeback"] = { PerkValue = 0.3, PerkName = "Comeback" },
    ["Relentless"] = { PerkValue = 0.15, PerkName = "Relentless" },
    ["Duelist"] = { PerkValue = 0.3, PerkName = "Duelist" },
    ["Unstoppable"] = { PerkValue = 0.15, PerkName = "Unstoppable" },
    ["Survivor"] = { PerkValue = 0.2, PerkName = "Survivor" },
    ["Executioner"] = { PerkValue = 0.5, PetPerkValue = 0.5, PerkName = "Executioner" },
    ["Adrenaline"] = { PerkValue = 0.3, PerkName = "Adrenaline" },
    ["Cooldown Reduction"] = { PerkValue = 0.1, PerkName = "CooldownReduction" },
    ["Attack Speed"] = { PerkValue = 0.15, PerkName = "AttackSpeed" },
    ["Water Bubble"] = { PerkValue = 0.4, PerkName = "WaterBubble", LowerMax = true },
    ["Blessing"] = { PerkValue = 0.3, PerkName = "Blessing" },
    ["Deaths Door"] = { PerkValue = 0.5, PerkName = "DeathsDoor" },
    ["Protector"] = { PerkValue = 0.1, PerkName = "Protector" }
}
FirstTab:AddDropdown("PerkListDropdown", {
    Values = {},
    Text = "Perks to keep",
    Multi = true,
    AllowNull = true,
    Default = "",
    MaxVisibleDropdownItems = 5,
    Searchable = true,
    Callback = function(ChangedValue)
        if not IsMainMenu and Options.PerkListDropdown:GetActiveValues(true) > 0 then
            if not SV.SelectedPerks then
                SV.SelectedPerks = {}
            else
                table.clear(SV.SelectedPerks)
            end
            for Key in ChangedValue do
                local PerkData = SavePerkTable[Key]
                PerkData.VisualName = tostring(Key)
                SV.SelectedPerks[PerkData.PerkName] = PerkData
            end
        else
            if SV.SelectedPerks then
                table.clear(SV.SelectedPerks)
            end
        end
    end
})
local DropdownReference = {}
for Key in SavePerkTable do
    table.insert(DropdownReference, tostring(Key))
end
table.sort(DropdownReference, function(a,b)
    return a < b
end)
Options.PerkListDropdown:SetValues(DropdownReference)
FirstTab:AddButton({
    Text = "Sell inventory",
    DoubleClick = true,
    Tooltip = "all options including perk filtering are taken into account when selling your inventory",
    Func = function()
        local pItems = ProfileInventory:WaitForChild("Items")
        for Index, NewItem in pItems:GetChildren() do
            ItemSellCheck(NewItem, true)
        end
    end
})
SecondTab:AddLabel("Perfect perk offset", true)
SecondTab:AddSlider("PerkPercentSlider", {
    Text = "Offset",
    Default = 0,
    Min = 0,
    Max = 5,
    Rounding = 0,
    Compact = true,
    Tooltip = "Allows you to increase the range at which perks are kept. For example if you want Attack Up 7% and 8% then you would add 1 to the offset",
    Callback = function(ChangedValue)
        if not ChangedValue then
            ChangedValue = 0
        end
        OffsetMax = FormatDecimal(ChangedValue / 100)
    end
})
FourthTab:AddDropdown("CosmeticDropdown", {
    Values = {},
    Text = "Cosmetics",
    Multi = true,
    AllowNull = true,
    Default = "",
    MaxVisibleDropdownItems = 5,
    Searchable = true
})
FourthTab:AddButton({
    Text = "Clear selection",
    DoubleClick = true,
    Func = function()
        Options.CosmeticDropdown:SetValue(nil)
    end
})
FourthTab:AddButton({
    Text = "Scan cosmetics",
    Func = function()
        if IsDungeon or IsWorld then
            if not SV.CanRequire then
                Library:Notify("Your executor doesn't support this option. Lacks require()", 5)
                return
            end

            local Profile_GetCosmetics = Remotes.Profile_GetCosmetics:InvokeServer()
            local rItems = require(Items)
            local ItemTable = {}
            local VisualItemTable = {}
            local RealItemTable = {}
            local ScannedItems = {}

            -- create the table to look up items by their id's
            for Index, ItemData in rItems do
                if ItemData.Type == "Emote" or ItemData.Type == "Title" or ItemData.Type == "Furniture" or ItemData.Type == "Consumable" then
                    continue
                end
                ItemTable[ItemData.ID] = {
                    VisualName = tostring(ItemData.DisplayKey),
                    InternalName = tostring(Index)
                }
            end

            for Index, ItemData in Profile_GetCosmetics do
                if ItemData.lock or ItemData.fav then
                    continue
                end
                local ItemRef = ItemTable[ItemData.id]
                if not ItemRef then
                    continue
                end
                local VisualName = ItemRef.VisualName
                if not ScannedItems[VisualName] then
                    ScannedItems[VisualName] = true
                    RealItemTable[VisualName] = {}
                    table.insert(VisualItemTable, VisualName)
                end
                if not ItemData.d then
                    table.insert(RealItemTable[VisualName], {
                        UUID = ItemData.uuid,
                        Name = ItemRef.InternalName
                    })
                else
                    table.insert(RealItemTable[VisualName], {
                        UUID = ItemData.uuid,
                        Name = ItemRef.InternalName,
                        Dye = Color3.new(ItemData.d.r, ItemData.d.g, ItemData.d.b):ToHex()
                    })
                end
            end
            
            Options.CosmeticDropdown:SetValues(VisualItemTable)
            SV.RealCosmeticTable = RealItemTable
        end
    end
})
    FourthTab:AddDivider()
FourthTab:AddLabel("Pressing either of these buttons will either attempt to Recycle or Sell all the cosmetics you have selected above", true)
FourthTab:AddButton({
    Text = "Recycle",
    DoubleClick = true,
    Func = function()
        if IsDungeon or IsWorld then
            local SelectedItems = {}
            for Key in Options.CosmeticDropdown.Value do
                SelectedItems[Key] = true
            end
            RecycleFromInventory("Recycle", SelectedItems)
        end
    end
}):AddButton({
    Text = "Sell",
    DoubleClick = true,
    Func = function()
        if IsDungeon or IsWorld then
            local SelectedItems = {}
            for Key in Options.CosmeticDropdown.Value do
                SelectedItems[Key] = true
            end
            RecycleFromInventory("Gold", SelectedItems)
        end
    end
})
FifthTab:AddLabel("<font color='#FF3333'>ALL USER ENTERED HEXES MUST BE SEPARATED WITH COMMAS</font>\nAdding hexes example:\n<font color='#33FF33'>00ff00, a.a.b., [a-b].[1-2].e</font>", true)
    FifthTab:AddDivider()
local NumberOfEnteredHexes = FifthTab:AddLabel("Number of saved hexes: " ..FormatNumber(#SV.SpecialHexColors))
local UserEnteredHexes = FifthTab:AddLabel("Saved hexes:\nn/a\n+ (all special hexes)", true)
    FifthTab:AddDivider()
FifthTab:AddInput("SaveUserHexesInput", {
    Text = "Enter hexes to save",
    Default = "",
    ClearTextOnFocus = false,
    Placeholder = "hexes here",
    Callback = function(ChangedValue)
        if IsWorld or IsDungeon then
            ChangedValue = tostring(ChangedValue)
            ChangedValue = string.lower(ChangedValue)
            if ChangedValue == "" or ChangedValue == " " then
                NumberOfEnteredHexes:SetText("Number of saved hexes: " ..FormatNumber(#SV.SpecialHexColors))
                UserEnteredHexes:SetText("Saved hexes:\nn/a\n+ (all special hexes)")
                return
            end
            local StandardizeCommas = string.gsub(Options.SaveUserHexesInput.Value, ", ", ",")
            local RemoveHashTags = string.gsub(StandardizeCommas, "#", "")
            local SplitHexes = string.split(RemoveHashTags, ",")
            NumberOfEnteredHexes:SetText("Number of saved hexes: " ..FormatNumber(#SV.SpecialHexColors + #SplitHexes))
            UserEnteredHexes:SetText("Saved hexes:\n<font color='#33FF33'>" ..ChangedValue.. "</font>\n+ (all special hexes)")
            return
        end
    end
})
end -- for unloaded inventory tab

SetGlobal("creating dungeon tab")

if not SV.DungeonsTab then -- for unloaded classes tab
local DungeonTab = Window:AddTab({
    Name = "Dungeons",
    Icon = "rbxassetid://18739736091"
})
local LeftTab = DungeonTab:AddLeftTabbox("Left Tabbox")
    local FirstTab = LeftTab:AddTab("Main")
    local SecondTab = LeftTab:AddTab("Settings")
local RightTab = DungeonTab:AddRightTabbox("Right Tabbox")
    local ThirdTab = RightTab:AddTab("Advanced\n(nightmare challenge)")

local function ToggleNightmare(ChangedValue, FunctionValue)
    if ChangedValue and IsDungeon then
        SV[tostring(FunctionValue)] = math.random(1005, 1007)
    else
        SV[tostring(FunctionValue)] = nil
    end
end

CreateToggles({
    { "ReplayMissionToggle", Text = "Auto restart mission", Tab = FirstTab },
    { "CollectChestToggle", Text = "Collect chests", Tab = FirstTab },
    { "HighestDungeonToggle", Text = "Do highest level dungeon", Tooltip = "Useful if you are leveling up as it moves to the highest level dungeon you're able to play and auto equips new gear if it's a higher level.", Tab = FirstTab },
    { "RandomNightmareDungeonToggle", Text = "Random nightmare dungeon", Tooltip = "Instead of replaying the current dungeon it will pick a random nightmare dungeon.", Tab = FirstTab, AttachedFunction = ToggleNightmare, FunctionValue = "RandomNightmareDungeon" },
    { "ReplayInfiniteTowerToggle", Text = "Limit infinite tower", Tooltip = "Allows you to restart infinite tower once a predetermined floor has been reached.", Tab = FirstTab }
})
SV.RestartDungeonDelay = 3
SecondTab:AddLabel("Restart dungeon delay", true)
SecondTab:AddSlider("ReplayMissionSlider", {
    Text = "Restart delay",
    Default = 3,
    Min = 1,
    Max = 60,
    Rounding = 0,
    Compact = true,
    Tooltip = "Changes the scripts delay when restarting the dungeon when `Auto restart mission` is selected.",
    Callback = function(ChangedValue)
        SV.RestartDungeonDelay = ChangedValue
    end
})
SV.CollectChestsDelay = 0.1
SecondTab:AddLabel("Collect chest delay", true)
SecondTab:AddSlider("ChestDelaySlider", {
    Text = "Collect chest delay",
    Default = 0.1,
    Min = 0.01,
    Max = 5,
    Rounding = 2,
    Compact = true,
    Tooltip = "Changes the scripts delay between chests being collected.",
    Callback = function(ChangedValue)
        SV.CollectChestsDelay = ChangedValue
    end
})
SecondTab:AddLabel("Infinite tower reset floor", true)
SecondTab:AddSlider("InfResetSlider", {
    Text = "Floor",
    Default = 200,
    Min = 155,
    Max = 400,
    Rounding = 0,
    Compact = true,
    Tooltip = "Allows you to change the floor that infinite tower restarts at when the `Periodically reset inf tower` option is selected.",
    Callback = function(ChangedValue)
        RestartAtFloor = ChangedValue
    end
})
SecondTab:AddLabel("Prioritize nightmare dungeons", true)
SecondTab:AddDropdown("PrioNmDropdown", {
    Values = {},
    Multi = true,
    AllowNull = true,
    Default = nil,
    MaxVisibleDropdownItems = 5,
    Searchable = true,
    Callback = function(ChangedValue)
        if not IsMainMenu and Options.PrioNmDropdown:GetActiveValues(true) > 0 then
            SV.PrioNmDCount = true
        else
            SV.PrioNmDCount = nil
        end
    end
})
SV.PrioritizedNightmareDungeons = {}
local NMDisplayValues = {}
for Index, Data in SV.DungeonListTable do
    if Data.Level > 0 and Data.Level < 175 then
        SV.PrioritizedNightmareDungeons[Data.DungeonName] = { ID = Data.DungeonID, Length = Data.DungeonDelay, SpecialPerk = Data.SpecialPerk or nil }
        table.insert(NMDisplayValues, Data.DungeonName)
    end
end
Options["PrioNmDropdown"]:SetValues(NMDisplayValues)
NMDisplayValues = nil
SV.TotalNightmareLabel = ThirdTab:AddLabel("Total nightmare clears: ?", false)
ThirdTab:AddInput("TotalNightmareInput", {
    Text = "Stop after X total clears",
    Default = "",
    Placeholder = "number here",
    Callback = function(ChangedValue)
        SetQuotaPause("nightmare",false)
        if IsDungeon then
            SV.StopAfterTotalNightmare = ChangedValue
        end
    end
})
    ThirdTab:AddDivider({Margin = -5})
SV.DailyNightmareLabel = ThirdTab:AddLabel("Daily nightmare clears: ?", false)
ThirdTab:AddInput("DailyNightmareInput", {
    Text = "Stop after X daily clears",
    Default = "",
    Placeholder = "number here",
    Callback = function(ChangedValue)
        SetQuotaPause("nightmare",false)
        if IsDungeon then
            SV.StopAfterDailyNightmare = ChangedValue
        end
    end
})
end -- for unloaded classes tab

if not SV.InventoryTab then
SetGlobal("equipment tab function")
if IsWorld or IsDungeon then
    Toggles.AutoSellToggle:OnChanged(function(ChangedValue) -- auto sell
        if ChangedValue then
            local Success, Result = pcall(function()
                DisconnectVariable("ConnectInventory")
                local pItems = ProfileInventory:WaitForChild("Items")
                ConnectionTable["ConnectInventory"] = pItems.ChildAdded:Connect(function(NewItem)
                    ItemSellCheck(NewItem)
                end)
            end)
            if not Success then
                
            end
        else
            DisconnectVariable("ConnectInventory")
        end
    end)
end
end -- for unloaded inventory tab

if not SV.GuildTab then -- for unloaded guild tab
SetGlobal("creating guild tab")
local GuildTab = Window:AddTab({
    Name = "Guild",
    Icon = "rbxassetid://9671046895"
})
local GuildTabLeft = GuildTab:AddLeftTabbox("Left Tabbox")
    local FirstTab = GuildTabLeft:AddTab("Main")
    local SecondTab = GuildTabLeft:AddTab("Settings")
local GuildTabRight = GuildTab:AddRightTabbox("Right Tabbox")
    local ThirdTab = GuildTabRight:AddTab("Advanced")
    local FourthTab = GuildTabRight:AddTab("Guild spy")

CreateToggles({
    { "WaitTimeToggle", Text = "Wait for legit time", Tooltip = "Starts the dungeon and then waits a predetermined amount of time before continuing to clear the dungeon", Tab = FirstTab },
    { "DoAllDungeonsToggle", Text = "Do all dungeons", Tooltip = "Starts from whatever dungeon you're currently in and goes to the next dungeon once it's completed. Does not go back for previous dungeons!\n\nOrder dungeons are started in:\ninf -> towers 1-6 -> celestial -> all dungeons", Tab = FirstTab },
    { "DelayInfFloorToggle", Text = "Delay inf tower floors", Tooltip = "When doing infinite tower the script no longer automatically teleports to the next floor and will let the default countdown teleport you to the next floor.", Tab = FirstTab },
    { "GuildQuestToggle", Text = "Auto claim guild quests", Tab = FirstTab }
})

    FirstTab:AddDivider({Margin = -5})
FirstTab:AddDropdown("DoAllDropdown", {
    Values = {
        "Stop",
        "Loop",
        "Loop w/o inf",
        "Loop w/o towers",
        "Play nightmare dungeons"
    },
    Multi = false,
    Text = "Action when finished",
    AllowNull = false,
    Default = "Stop"
})
SecondTab:AddLabel("Add extra wait time", true)
SecondTab:AddSlider("AddExtraTimeSlider", {
    Text = "Seconds",
    Default = 0,
    Min = 0,
    Max = 180,
    Rounding = 0,
    Compact = true,
    Tooltip = "Adds more time to the `Wait for a legit time` option if you don't think the scirpt is waiing long enough, or you want to wait longer for safety.",
    Callback = function(ChangedValue)
        SV.AddedGuildTime = ChangedValue
    end
})
SecondTab:AddLabel("Increment inf tower delay ", true)
SecondTab:AddSlider("IncrementInfiniteSlider", {
    Text = "Seconds",
    Default = 0,
    Min = 0,
    Max = 10,
    Rounding = 0,
    Compact = true,
    Tooltip = "When using `Delay inf tower floors` this toggle will add increasingly more tine to wait after each boss floor has been completed.",
    Callback = function(ChangedValue)
        SV.IncrementInfiniteDelay = ChangedValue
    end
})
SV.TotalGuildPointLabel = ThirdTab:AddLabel("Total Guild Points: ?", false)
ThirdTab:AddInput("TotalKillInput", {
    Text = "Stop after X total points",
    Default = "",
    Placeholder = "number here",
    Callback = function(ChangedValue)
        SetQuotaPause("guild",false)
        if IsDungeon then
            SV.StopAfterTotalPoints = ChangedValue
        end
    end
})
    ThirdTab:AddDivider({Margin = -5})
SV.DailyGuildPointLabel = ThirdTab:AddLabel("Daily Guild Points: ?", false)
ThirdTab:AddInput("DailyKillInput", {
    Text = "Stop after X daily points",
    Default = "",
    Placeholder = "number here",
    Callback = function(ChangedValue)
        SetQuotaPause("guild",false)
        if IsDungeon then
            SV.StopAfterDailyPoints = ChangedValue
        end
    end
})
local SpyOnGuild = FourthTab:AddLabel("No guild to spy on", true)
    FourthTab:AddDivider()
local StoredPoints
local StoredChatLogs
local StoredDescription
local function ClipboardCheck(Copy, Data)
    if IsMainMenu then
        return true
    end

    if not Options.GuildNamesDropdown.Value or Options.GuildNamesDropdown.Value=="" then
        SpyOnGuild:SetText("No guild selected")
        return true
    end

    if Copy and Data then
        if type(setclipboard)=="function" then setclipboard(Data)
        else Library:Notify("Clipboard is unavailable in this executor",3)end
        return true
    end
end
local function GetGuildPoints(Copy)
    if ClipboardCheck(Copy, StoredPoints) then
        return
    end

    local GetCache = Remotes:WaitForChild("Guilds_GetCache", math.huge)
    local CachedGuild = GetCache:InvokeServer(string.upper(Options.GuildNamesDropdown.Value))
    local CachedMembers = CachedGuild and CachedGuild.Members
    if not CachedMembers then
        SpyOnGuild:SetText("This guilds data is no longer available")
        return
    end

    local PlayerPoints = {}
    local TotalPoints = 0
    for Index, Data in CachedMembers do
        table.insert(PlayerPoints, string.format(
            "%* - %s",
            Data.UserName, FormatNumber(Data.Points)
        ))
        TotalPoints += tonumber(Data.Points)
    end
    StoredPoints = string.format(
        "Total guild points: %s\n%*",
        FormatNumber(TotalPoints), table.concat(PlayerPoints, "\n")
    )
    if not Copy then
        SpyOnGuild:SetText(StoredPoints)
    elseif type(setclipboard)=="function" then
        setclipboard(StoredPoints)
    end
end
local function GetGuildDescription(Copy)
    if ClipboardCheck(Copy, StoredDescription) then
        return
    end

    local GetCache = Remotes:WaitForChild("Guilds_GetCache", math.huge)
    local CachedGuild = GetCache:InvokeServer(string.upper(Options.GuildNamesDropdown.Value))
    local CachedDescription = CachedGuild and CachedGuild.Description
    if not CachedDescription then
        SpyOnGuild:SetText("This guilds data is no longer available")
        return
    end
    if not Copy then
        SpyOnGuild:SetText(CachedDescription)
        StoredDescription = CachedDescription
    elseif type(setclipboard)=="function" then
        setclipboard(CachedDescription)
    end
end
FourthTab:AddDropdown("GuildNamesDropdown", {
    Values = {},
    Text = "Guilds",
    Multi = false,
    AllowNull = true,
    Default = "",
    MaxVisibleDropdownItems = 5,
    Searchable = true,
    Callback = function()
        StoredPoints = nil
        StoredDescription = nil
        StoredChatLogs = nil
    end
})
FourthTab:AddButton({
    Text = "Scan for guilds",
    Func = function()
        local ScannedGuilds = {}
        local UniqueGuilds = {}
        for Index, Player in Players:GetChildren() do
            local PlayersGuild = GetGuild(Player)
            if PlayersGuild ~= "❌" and not ScannedGuilds[PlayersGuild] then
                ScannedGuilds[PlayersGuild] = true
                table.insert(UniqueGuilds, PlayersGuild)
            end
        end
        Options.GuildNamesDropdown:SetValues(UniqueGuilds)
    end
})
FourthTab:AddButton({
    Text = "Players points",
    Func = function()
        GetGuildPoints()
    end
}):AddButton({
    Text = "Clipboard",
    Func = function()
        GetGuildPoints(true)
    end
})
FourthTab:AddButton({
    Text = "Description",
    Func = function()
        GetGuildDescription()
    end
}):AddButton({
    Text = "Clipboard",
    Func = function()
        GetGuildDescription(true)
    end
})
end -- for unloaded guild tab

if not SV.ShopsTab then -- for unloaded shops tab
SetGlobal("creating shop tab")
local ShopTab = Window:AddTab({
    Name = "Shops",
    Icon = "rbxassetid://12281229733"
})
local LeftTab = ShopTab:AddLeftTabbox("Left Tabbox")
    local FirstTab = LeftTab:AddTab("Egg")
    local SecondTab = LeftTab:AddTab("Nightmare")
    local ThirdTab = LeftTab:AddTab("PVP")
local RightTab = ShopTab:AddRightTabbox("Left Tabbox")
    local FourthTab = RightTab:AddTab("Guild")
    local FifthTab = RightTab:AddTab("Event")

local BuyEggList = {
    { InternalName = "StarEgg", VisualName = "Star egg", CoinPrice = 2000, CurrencyType = "Gold" },
    { InternalName = "JungleEgg", VisualName = "Jungle egg", CoinPrice = 5000, CurrencyType = "Gold" },
    { InternalName = "CrystalEgg", VisualName = "Crystal egg", CoinPrice = 7500, CurrencyType = "Gold" },
    { InternalName = "DesertEgg", VisualName = "Pharaoh's egg", CoinPrice = 10000, CurrencyType = "Gold" },
    { InternalName = "ChristmasEgg", VisualName = "Holiday egg", CoinPrice = 400, CurrencyType = "Crystal" }
}
FirstTab:AddDropdown("EggShopDropdown", {
    Values = {},
    Multi = false,
    Text = "egg name (price)",
    AllowNull = true,
    Default = nil,
    Searchable = true,
    Callback = function(ChangedValue)
        if ChangedValue and IsWorld or IsDungeon then
            SV.SelectedEggItem = BuyEggList[ChangedValue]
        else
            SV.SelectedEggItem = nil
        end
    end
})
BuyEggList = BuildShopValues("EggShopDropdown", BuyEggList)
FirstTab:AddButton({
    Text = "Buy egg",
    Func = function()
        local TableReference = SV.SelectedEggItem
        if not TableReference then
            Library:Notify("No egg is selected", 3)
            return
        end
        if not BuyFromEggShop(TableReference.CurrencyType, TableReference.InternalName, TableReference.CoinPrice, TableReference.VisualName) then
            Library:Notify("You do not have enough gold", 3)
        end
    end
})
CreateToggles({
    { "AutoHatchEggToggle", Text = "Auto hatch selected egg", Tooltip = "Recommended to do this in dungeons where no one else can see you (lag is also reduced)", Tab = FirstTab },
    { "AutoHatchInventoryEggToggle", Text = "Hatch eggs in inventory", Tooltip = "Hatch eggs in inventory", Tab = FirstTab}
})
FirstTab:AddSlider("EggHatchDelaySlider", {
    Text = "Egg hatch delay",
    Default = 0,
    Min = 0,
    Max = 10,
    Rounding = 0,
    Callback = function(ChangedValue)
        if IsWorld or IsDungeon then
            SV.HatchDelay = ChangedValue
        end
    end
})
for Dropdown, Info in ipairs{
    { "NightmareShopDropdown", ShopList = "NightmarePortals", Currency = "Nightmare", RequiredWorld = "14914684761", ReqName = "world 10", ToggleName = "AutoNightmareToggle", Tab = SecondTab },
    { "PVPShopDropdown", ShopList = "PVPShop", Currency = "PvP", RequiredWorld = "6510868181", ReqName = "pvp arena", ToggleName = "AutoPvpToggle", Tab = ThirdTab },
    { "GuildShopDropdown", ShopList = "GuildShop", Currency = "Guild", RequiredWorld = "139316833473171", ReqName = "guild hub", ToggleName = "AutoGuildToggle", Tab = FourthTab },
    { "EventShopDropdown", ShopList = "Halloween2026", Currency = "Halloween", RequiredWorld = "5862275930", ReqName = "event hub", ToggleName = "AutoEventToggle", Tab = FifthTab }
} do
    local SelectedItem
    Info.Tab:AddDropdown(tostring(Info[1]), {
        Values = {},
        Multi = false,
        Text = "item name ("..Info.Currency.." coins)",
        AllowNull = true,
        Default = nil,
        MaxVisibleDropdownItems = 5,
        Searchable = true,
        Callback = function(ChangedValue)
            if ChangedValue and IsWorld then
                SelectedItem = Info.ShopList[ChangedValue]
            else
                SelectedItem = nil
            end
        end
    })
    Info.ShopList = BuildShopValues(tostring(Info[1]), Info.ShopList)
    Info.Tab:AddButton({
        Text = "Buy item",
        Func = function()
            if Info.RequiredWorld then
                if StringPlaceID ~= Info.RequiredWorld then
                    Library:Notify(string.format(
                        "Go to %* to do this",
                        Info.ReqName
                    ), 5)
                    return
                end
            end
            BuyFromLocalShop(Info.ShopList, SelectedItem)
        end
    })
    local AutoBuy
    local BuyGeneration=0
    Info.Tab:AddToggle(Info.ToggleName, {
        Text = "Buy max selected item",
        Default = false,
        Callback = function(ChangedValue)
            BuyGeneration+=1
            local generation=BuyGeneration
            if ChangedValue and (IsWorld or IsDungeon) and StringPlaceID == Info.RequiredWorld then
                AutoBuy = true
                local Success, Result = pcall(function()
                    repeat
                        if ScriptUnloaded or KillSwitch or SV.TransitionPending or generation~=BuyGeneration then break end
                        if SelectedItem then BuyFromLocalShop(Info.ShopList, SelectedItem)end
                        task.wait(0.65)
                    until not AutoBuy
                end)
                if not Success then
                    
                end
            else
                AutoBuy = nil
            end
        end
    })
end
end -- for unloaded shops tab

if not SV.QuickMenusTab then -- for unloaded quick menus tab
SetGlobal("creating quick menu tab")
local OpenMenuTab = Window:AddTab({
    Name = "Quick menus",
    Icon = "rbxassetid://13534579488"
})
local LeftTab = OpenMenuTab:AddLeftTabbox("Left Tabbox")
    local FirstTab = LeftTab:AddTab("Main")
local RightTab = OpenMenuTab:AddRightTabbox("Left Tabbox")
    local SecondTab = RightTab:AddTab("Extra")

CreateToggles({
    { Button = true, Text = "Teleport menu (old)", Tab = FirstTab, AttachedFunction = OpenMenu, FunctionValue = "HubTeleport" },
    { Button = true, Text = "Bank", Tab = FirstTab, AttachedFunction = OpenMenu, FunctionValue = "Bank" },
    { Button = true, Text = "Upgrade station", Tab = FirstTab, AttachedFunction = OpenMenu, FunctionValue = "ItemUpgrade" },
    { Button = true, Text = "Sell station", Tab = FirstTab, AttachedFunction = OpenMenu, FunctionValue = "Sell" },
    { Button = true, Text = "Zero altar", Tab = FirstTab, AttachedFunction = OpenMenu, FunctionValue = "Fusion" },
    { Button = true, Text = "Pet fusion", Tab = FirstTab, AttachedFunction = OpenMenu, FunctionValue = "FusePets" },
    { Button = true, Text = "Salon", Tab = SecondTab, AttachedFunction = OpenMenu, FunctionValue = "NewCharacterCustomizer" },
    { Button = true, Text = "Recycler", Tab = SecondTab, AttachedFunction = OpenMenu, FunctionValue = "Recycler" },
    { Button = true, Text = "Furniture shop", Tab = SecondTab, AttachedFunction = OpenMenu, FunctionValue = "FurnitureShop" },
    { Button = true, Text = "Pet adventures", Tab = SecondTab, AttachedFunction = OpenMenu, FunctionValue = "PetExpeditions" },
})
end -- for unloaded quick menus tab

if not SV.MiscellaneousTab then -- for unloaded miscellaneous
local MiscTab = Window:AddTab({
    Name = "Miscellaneous",
    Icon = "rbxassetid://4801326994"
})
local LeftTab = MiscTab:AddLeftTabbox("Left Tabbox")
    local FirstTab = LeftTab:AddTab("Main")
    local SecondTab = LeftTab:AddTab("Hide ui's")
local RightTab = MiscTab:AddRightTabbox("Right Tabbox")
    local ThirdTab = RightTab:AddTab("Extra")
    local FourthTab = RightTab:AddTab("Performance")

local hiddenMenus={}
local previousGuiState=setmetatable({},{__mode="k"})
local function ApplyHiddenMenu(gui)
    if gui and gui:IsA("ScreenGui") and hiddenMenus[gui.Name] then
        if previousGuiState[gui]==nil then previousGuiState[gui]=gui.Enabled end
        gui.Enabled=false
    end
end
local function ToggleMenu(enabled,name)
    hiddenMenus[name]=enabled==true
    local gui=PlayerGui:FindFirstChild(name)
    if enabled then ApplyHiddenMenu(gui)
    elseif gui and previousGuiState[gui]~=nil then gui.Enabled=previousGuiState[gui] previousGuiState[gui]=nil end
end
ConnectionTable.LarpZeroHiddenMenus=PlayerGui.ChildAdded:Connect(ApplyHiddenMenu)

ThirdTab:AddInput("JoinPlayerInput", {
    Text = "Enter name",
    Default = "",
    Placeholder = "username",
    Tooltip = "Enter a players exact actual name (not display) and teleport to them if they are currently in game and not in a dungeon.",
})
ThirdTab:AddButton({
    Text = "Join player",
    Tooltip = "Attempts to join the players name entered into the field above",
    Func = function()
        if not Options.JoinPlayerInput.Value or IsMainMenu or Options.JoinPlayerInput.Value == "" then
            return
        end
        if SV.CanRequire then
            local rTeleport = require(Teleport)
            rTeleport:TeleportToPlayer(LocalPlayer, Players:GetUserIdFromNameAsync(Options.JoinPlayerInput.Value), nil, true)
            Library:Notify("Attempting to join player: " ..Options.JoinPlayerInput.Value, 5)
        else
            Library:Notify("Your executor doesn't support this", 5)
        end
    end
})
    ThirdTab:AddDivider({Margin = -5})
CreateToggles({
    { "MobCameraToggle", Text = "Camera on mob", Tooltip = "Positions the players camera on the current target mob", Tab = FirstTab },
    { "DamageNumbersToggle", Text = "Remove damage numbers", Tooltip = "Prevents damage numbers from being rendered", Tab = FirstTab },
    { "DamageFlashToggle", Text = "Hide damage flash", Tooltip = "Hides the red flash when mobs are damaged", Tab = FirstTab },
    { "DeathEffectToggle", Text = "Remove death effects", Tooltip = "Prevents all death effects from being rendered", Tab = FirstTab },
    { "KnockdownToggle", Text = "Disable knockdown", Tooltip = "Prevents the knockdown status from working (everyone can see this if they look at your statuses)", Tab = FirstTab },
    { "ShowEndTimeToggle", Text = "Display end time", Tooltip = "Show the dungeons clear time when finished", Tab = FirstTab },
    { "WaystoneToggle", Text = "Closest waystone", Tooltip = "Hide the icon for the closest waystone", Tab = SecondTab },
    { "MissionObjectiveToggle", Text = "Mission objective", Tooltip = "Hide the text on your screen telling you what to do", Tab = SecondTab, AttachedFunction = ToggleMenu, FunctionValue = "MissionObjective" },
    { "BossBarToggle", Text = "Boss bar", Tooltip = "Hide boss bars on your screen", Tab = SecondTab, AttachedFunction = ToggleMenu, FunctionValue = "BossHealthbar" },
    { "PlayerHotbarToggle", Text = "Hotbar", Tooltip = "Hide your health and skill ui", Tab = SecondTab, AttachedFunction = ToggleMenu, FunctionValue = "Hotbar" },
    { "MobilePlayerSkills", Text = "Mobile skills", Tooltip = "Hide the mobile skill ui", Tab = SecondTab, AttachedFunction = ToggleMenu, FunctionValue = "TouchInput" },
    { "MainGuiToggle", Text = "Event icon", Tooltip = "Hide the event icon", Tab = SecondTab, AttachedFunction = ToggleMenu, FunctionValue = "MainGui" },
    { "HideMenuToggle", Text = "Menu", Tooltip = "Hide the in-game gui tab", Tab = SecondTab, AttachedFunction = ToggleMenu, FunctionValue = "Menu" },
    { "DevKickToggle", Text = "Kick on dev join", Tooltip = "Kick you from the game if a dev joins you", Tab = ThirdTab },
    { "AFKToggle", Text = "Anti AFK", Tooltip = "Prevents you from being AFk kicked (may not work on all executors)", Tab = ThirdTab },
    { "MainMenuPlay", Text = "Auto click play", Tooltip = "Automatically clicks \"PLAY\" when on the main menu", Tab = ThirdTab },
    { "AutoJoinDungeon", Text = "Auto join dungeon", Tooltip = "Automatically join a nightmare dungeon if available", Tab = ThirdTab },
    { "MobESPToggle", Text = "Mob ESP", Tooltip = "Adds a highlight to mobs", Tab = ThirdTab },
    { "NoclipCameraToggle", Text = "Noclip camera", Tooltip = "Allows your camera to clip through walls", Tab = ThirdTab },
    { "DisableAutoJumpToggle", Text = "Disable autojump", Tooltip = "Prevents you from auto-jumping on mobile devices", Tab = ThirdTab },
    { "RemoveOtherPlayersToggle", Text = "Remove other players", Tooltip = "Removes all other players including their pets", Tab = FourthTab },
    { "DisableRenderingToggle", Text = "Disable rendering", Tooltip = "Sigificantly reduces the load on your GPU by disabling 3d rendering", Tab = FourthTab },
    { "PreventEffectsToggle", Text = "Don't render new effects", Tooltip = "Stops the game from rendering new effects such as projectiles!\nDO NOT USE IF PLAYING NORMALLY", Tab = FourthTab },
    { "PreventMobToggle", Text = "Don't render new models", Tooltip = "Stops the game from rendering most new models your game hasn't already rendered", Tab = FourthTab }
})
    FirstTab:AddDivider({Margin = -5})
local rWalkspeedManager
FirstTab:AddSlider("WalkspeedSlider", {
    Text = "Change walkspeed",
    Default = 28,
    Min = 28,
    Max = 200,
    Rounding = 0,
    Tooltip = "Does exactly what you think it does",
    Callback = function(ChangedValue)
        if SV.CanRequire then
            if not rWalkspeedManager then
                rWalkspeedManager = require(WalkspeedManager)
            end
            rWalkspeedManager:SetBaseSpeed(tonumber(ChangedValue))
        end
    end
})
    ThirdTab:AddDivider({Margin = -5})
local originalClassColor=LocalPlayer:GetAttribute("ClassColor")
ThirdTab:AddInput("ChangeClassColor", {
    Text = "Change class colors",
    Default = "",
    Placeholder = "FFFFFF",
    Tooltip = "Changes the colors of your classes attacks on your client only",
    Callback = function(ChangedValue)
        if IsDungeon or IsWorld then
            if ChangedValue=="" then LocalPlayer:SetAttribute("ClassColor",originalClassColor)
            elseif type(ChangedValue)=="string" and ChangedValue:match("^%x%x%x%x%x%x$") then
                LocalPlayer:SetAttribute("ClassColor",ChangedValue)
            else Library:Notify("Class color must contain exactly six hexadecimal digits",3)end
        end
    end
})
    FourthTab:AddDivider({Margin = -5})
FourthTab:AddSlider("FPSSlider", {
    Text = "Change FPS",
    Default = 60,
    Min = 20,
    Max = 240,
    Rounding = 0,
    Callback = function(ChangedValue)
        if setfpscap then
            setfpscap(tonumber(ChangedValue))
        end
    end
})
end -- for unloaded miscellaneous

local ConfigTab=Window:AddTab({Name="Settings"})
local cleanSettings=ConfigTab:AddLeftGroupbox("Menu")
cleanSettings:AddLabel("Build: 2026.11.06-r10 [7da0ce1f9bc9]",true)
cleanSettings:AddToggle("HideGuiToggle",{Text="Hide on load",Default=false})
local LoadLocalProfile = InstallLocalProfiles(Library, ConfigTab)

task.spawn(function()
    local deadline=os.clock()+90
    while not ScriptUnloaded and not KillSwitch and os.clock()<deadline do
        local profile=PlayerGui:FindFirstChild("Profile")
        local inventory=profile and profile:FindFirstChild("Inventory")
        if Class and SV.CanRequire~=nil and PlayerRoot and inventory then
            PlayerProfile=profile
            ProfileInventory=inventory
            ISV.PlayerClass=LocalPlayer:GetAttribute("Class")
            ISV.PlayerLevel=LocalPlayer:GetAttribute("Level")
            ISV.PlayerPrestige=LocalPlayer:GetAttribute("Prestige")
            SV.Parties=ReplicatedStorage:FindFirstChild("Parties")
            LoadLocalProfile()
            return
        end
        task.wait(0.25)
    end
    if not ScriptUnloaded and not KillSwitch then Library:Notify("Waiting for game data. Saved profiles are available in Settings.",5) end
end)

do
    ConnectionTable.LarpZeroAutoexecSettings=LocalPlayer.OnTeleport:Connect(function(state)
        if state~=Enum.TeleportState.Started then return end
        pcall(function()
            Library.PrepareTeleportSettings()
            writefile("LarpZeroProfiles/resume_pending.txt","1")
        end)
    end)
    if type(isfile)=="function" and type(delfile)=="function" then
        pcall(function()
            if isfile("LarpZeroProfiles/resume_pending.txt") then
                getgenv().LarpZeroResumeSettings=true
                delfile("LarpZeroProfiles/resume_pending.txt")
            end
        end)
    end
    cleanSettings:AddLabel("Startup: executor auto-execute folder",true)
end
if SV.RefreshSafeMode then SV.RefreshSafeMode(SV.SafeMode) end
SetGlobal("creating UI functions")

if not SV.GeneralTab then
SetGlobal("general tab functions")
if not IsMainMenu then
    local KillauraChanged
    Toggles.KillauraToggle:OnChanged(function(ChangedValue)
        if ChangedValue and SV.SafeMode and not IsDungeon then
            return
        end
 -- killaura
        local TimeActivated = os.clock()
        KillauraChanged = CheckForCharacter(TimeActivated)
        if TimeActivated ~= KillauraChanged then
            return
        end
        
        if ChangedValue then
            if not Class then
                Library:Notify("CLASS NOT YET SUPPORTED", 9999999999999999)
                return
            end
            SV.Killaura = true
            local Success, Result = pcall(function()
                ConnectionTable["ConnectClass"] = LocalPlayer:GetAttributeChangedSignal("Class"):Connect(function()
                    Class = GetPlayerClass()
                end)
                if SV.CanRequire then
                    pcall(function()
                        local Actions = require(Client:WaitForChild("Actions", math.huge))
                        Actions:SetSkillDisabled("Primary", true)
                        Actions:SetSkillDisabled("Skill1", true)
                        Actions:SetSkillDisabled("Skill2", true)
                        Actions:SetSkillDisabled("Skill3", true)
                        Actions:SetSkillDisabled("Ultimate", true)
                    end)
                end
                local LowerAttack = Vector3.new(0, 3, 0)
                local CAttack = Remotes:WaitForChild("Combat_Attack", math.huge)
                local AttackArgs = {
                    Ranged = function(Skill, AttackPosition)
                        if SV.IsRanged then
                            AttackPosition = AttackPosition - LowerAttack
                        end
                        CAttack:FireServer(Skill, AttackPosition, nil, AntiCheatNumber)
                    end,
                    Melee = function(Skill, AttackPosition)
                        CAttack:FireServer(Skill, PlayerRoot.Position, (AttackPosition - PlayerRoot.Position).Unit, AntiCheatNumber)
                    end,
                    ShadowChain = function(Skill)
                        Skill:FireServer{CurrentMob, CurrentMob, CurrentMob, CurrentMob, CurrentMob}
                    end,
                    TableRemote = function(Skill)
                        Skill:FireServer(CurrentMob)
                    end,
                    Remote = function(Skill)
                        Skill:FireServer()
                    end,
                    GuardianRemote = function(Skill)
                        Skill:FireServer(1, PlayerRoot.Position)
                    end,
                    HunterRemote = function(Skill)
                        Skill:FireServer(PlayerRoot.Position, 50)
                    end,
                    HunterTrapRemote = function(Skill, AttackPosition)
                        Skill:FireServer("BearTrap", AttackPosition)
                    end,
                    PlayerPositionRemote = function(Skill)
                        Skill:FireServer(PlayerRoot.Position)
                    end,
                    MobPositionRemote = function(Skill, AttackPosition)
                        Skill:FireServer(AttackPosition)
                    end,
                    CFrameRemote = function(Skill)
                        Skill:FireServer(PlayerRoot.CFrame)
                    end,
                    PlayerRemote = function(Skill)
                        Skill:FireServer(LocalPlayer)
                    end,
                    StarbreakerWaves = function(Skill, AttackPosition)
                        task.spawn(function()
                            if IsBoss then
                                local Status = PlayerCharacter:FindFirstChild("Status")
                                if Status and Status:FindFirstChild("Starforge") then
                                    for Swing = 1, 5 do
                                        for Hit = 1, 10 do
                                            CAttack:FireServer("StarbreakerWaveSwing" ..tostring(Swing).. "Hit" ..tostring(Hit), PlayerRoot.Position, (AttackPosition - PlayerRoot.Position).Unit, AntiCheatNumber)
                                        end
                                    end
                                end
                            end
                        end)
                    end
                }
                repeat
                    for _, Attack in Class.Skills do
                        if ScriptUnloaded or KillSwitch or not SV.Killaura then break end
                        if CurrentMob then
                            local AttackCooldown = Attack.Cooldown
                            local key=tostring(SV.PlayerClass)..":"..tostring(Attack.Skill)
                            if time() - (Attack.LastUsed or 0) >= AttackCooldown+AddedDelay+PlayerPing and CombatSchedule.Ready(key) and CombatSchedule.Ready("dispatch") then
                                local AttackType = Attack.Type
                                local MobCollider = CurrentMob:FindFirstChild("Collider")
                                if MobCollider then
                                    local AttackDistance = Attack.Distance
                                    local PlayerSurface = PlayerRoot:GetClosestPointOnSurface(MobCollider.Position)
                                    local MobSurface = MobCollider:GetClosestPointOnSurface(PlayerRoot.Position)
                                    local Distance = (PlayerSurface - MobSurface).Magnitude
                                    if Distance <= AttackDistance then
                                        if SV.Autofarm and IsBoss then
                                            local TpTime = CurrentMob:GetAttribute("T")
                                            if not (TpTime and TpTime+0.2 < time()) then
                                                break
                                            end
                                        end
                                        local FindAttackType = AttackArgs[AttackType]
                                        if FindAttackType then
                                            if ScriptUnloaded or KillSwitch or not SV.Killaura then break end
                                            CombatSchedule.Reserve(key,AttackCooldown+AddedDelay+PlayerPing)
                                            CombatSchedule.Reserve("dispatch",tonumber(DelayAttacks)or 0)
                                            FindAttackType(Attack.Skill, MobSurface)
                                        else
                                            SV.Killaura = nil
                                            
                                            break
                                        end
                                        Attack.LastUsed = time()
                                        if DelayAttacks and DelayAttacks>0 then
                                            task.wait(DelayAttacks)
                                        end
                                    end
                                end
                            end
                        end
                    end
                    task.wait()
                until not SV.Killaura
            end)
            if not Success then
                
            end
        else
            if SV.CanRequire then
                pcall(function()
                    local Actions = require(Client:WaitForChild("Actions", math.huge))
                    Actions:SetSkillDisabled("Primary", false)
                    Actions:SetSkillDisabled("Skill1", false)
                    Actions:SetSkillDisabled("Skill2", false)
                    Actions:SetSkillDisabled("Skill3", false)
                    Actions:SetSkillDisabled("Ultimate", false)
                end)
            end
            DisconnectVariable("ConnectClass")
            SV.Killaura = nil
        end
    end)
        local SafeCombatGeneration=0
    Toggles.SafeKillauraToggle:OnChanged(function(enabled)
        SafeCombatGeneration+=1
        local generation=SafeCombatGeneration
        SV.SafeKillaura=nil
        if not enabled or (SV.SafeMode and not IsDungeon) then return end
        if not SV.CanRequire then
            Library:Notify("Native skill control is unavailable in this executor",4)
            return
        end
        local ok,actions=GameCall(function()return require(Client.Actions)end)
        if not ok then return end
        SV.SafeKillaura=true
        local names={"Primary","Skill1","Skill2","Skill3","Ultimate"}
        local nextSkill=1
        while generation==SafeCombatGeneration and SV.SafeKillaura and not KillSwitch and not ScriptUnloaded do
            if CurrentMob and not SV.QuotaPaused and not SV.TransitionPending and not SV.DodgingAttack then
                GameCall(function()
                    if actions:IsSheathed() then actions:UseSkill("Sheath")return end
                    -- Respect the game's busy state and cooldowns. Never bypass
                    -- these gates or dispatch five competing skill workers.
                    if actions:IsBusy() then return end
                    for _=1,#names do
                        local name=names[nextSkill]
                        nextSkill=nextSkill%#names+1
                        if not actions:SkillDisabled(name) and not actions:IsOnCooldown(name) then
                            actions:UseSkill(name)
                            break
                        end
                    end
                end)
            end
            task.wait(math.max(0.1,tonumber(DelayAttacks)or 0))
        end
    end)

    Toggles.AutoProgressToggle:OnChanged(function(ChangedValue)
        if ChangedValue and SV.SafeMode and not IsDungeon then
            return
        end

        local TimeActivated = os.clock()
        AutofarmChanged = CheckForCharacter(TimeActivated)
        if TimeActivated ~= AutofarmChanged then
            return
        end

        if ChangedValue then
            SV.Autofarm = true
            task.spawn(function()
                local Success, Result = pcall(function()
                    local RotationAroundMob = 0
                    PlayerRoot.CanCollide = false
                    local LastCollider
                    local TeleportTween
                    while SV.Autofarm do
                        if KillSwitch then
                            break
                        end
                        if TempStop or HoldForRealTime or EventOverride or SV.QuotaPaused then
                            if TeleportTween then
                                TeleportTween:Cancel()
                                TeleportTween = nil
                            end
                            task.wait(.1)
                            continue
                        end
                        if TeleportMob then
                            PlayerRoot.Velocity = Vector3.zero
                            local MobCollider = TeleportMob and TeleportMob:FindFirstChild("Collider")

                            if MobCollider then
                                local DistanceFromMob = (PlayerRoot.Position - MobCollider.Position).Magnitude
                                local PlayerOffset = Xdistance + (MobCollider.Size.X / 2)
                                RotationAroundMob += MobRotationSpeed / PlayerOffset

                                local TargetCFrame = CFrame.new(MobCollider.Position) * CFrame.Angles(0, math.rad(RotationAroundMob), 0) * CFrame.new(PlayerOffset, Ydistance, 0)
                                TargetCFrame = CFrame.lookAt(TargetCFrame.Position, Vector3.new(MobCollider.Position.X, TargetCFrame.Position.Y, MobCollider.Position.Z))

                                if MobCollider ~= LastCollider or DistanceFromMob > 200 then
                                    if TeleportTween then
                                        TeleportTween:Cancel()
                                        TeleportTween = nil
                                    end

                                    PlayerRoot.CFrame = TargetCFrame
                                    LastCollider = MobCollider
                                else
                                    TeleportTween = TweenService:Create(PlayerRoot, TweenInfo.new((PlayerRoot.Position - MobCollider.Position).Magnitude / 70, Enum.EasingStyle.Linear), {CFrame = TargetCFrame})
                                    TeleportTween:Play()
                                end
                                if IsBoss and not TeleportMob:GetAttribute("T") then
                                    TeleportMob:SetAttribute("T", time())
                                end

                                if IsMobCamera and CurrentCamera.CameraSubject ~= TeleportMob then
                                    CurrentCamera.CameraSubject = TeleportMob
                                end
                            end
                        else
                            if TeleportTween then
                                TeleportTween:Cancel()
                                TeleportTween = nil
                            end
                        end
                        TeleportStandPart()
                        task.wait()
                    end
                end)
                if not Success then
                    
                end
            end)
            task.spawn(function()
                local Success, Result = pcall(function()
                    for Part, PartData in TeleportParts do
                        if Part and Part.Parent then
                            Part.Size = Vector3.new(1, 1, 1)
                            Part.CanCollide = false
                        end
                    end
                    while SV.Autofarm do
                        for Part, PartData in TeleportParts do
                            if not SV.StopTeleportingParts and not SV.QuotaPaused then
                                if PartData.DontTeleport then
                                    continue
                                end
                                if Part.Parent and PartData.TouchPart.Parent then
                                    task.spawn(function()
                                        Part.Position = PlayerRoot.Position
                                        task.wait(0.1)
                                        Part.Position = PartData.OriginalLocation
                                    end)
                                else
                                    if not PartData.Regenerates then
                                        TeleportParts[Part] = nil
                                    end
                                end
                            end
                        end
                        task.wait()
                    end
                end)
                if not Success then
                    
                end
            end)
            task.spawn(function()
                local Success, Result = pcall(function()
                    local ShieldDungeons = {
                        16, 21, 38, 44, 52
                    }
                    local ShieldNames = {
                        "IceWall", "IgnisShield", "ZeroShield", "ShieldEgg", "EggShield"
                    }
                    if table.find(ShieldDungeons, ISV.MissionId) or SV.PartyRaidID == 14 then
                        while SV.Autofarm do
                            for Index, Shield in ShieldNames do
                                local CheckShield = Workspace:FindFirstChild(Shield)
                                if CheckShield then
                                    if CheckShield.Name == "ShieldEgg" or CheckShield.Name == "EggShield" then
                                        local ChangeEggName = CheckShield:WaitForChild("ShieldEgg", 1) or CheckShield:WaitForChild("Blade", 1)
                                        if ChangeEggName then
                                            ChangeEggName.Name = "Ring"
                                        end
                                    end
                                    local Ring = CheckShield:WaitForChild("Ring", 5)
                                    if Ring and Ring.Parent then
                                        local PlayerSize = GetPlayerSize() + (Ring.Size.Y / 2)
                                        local ShieldPosition = Vector3.new(Ring.Position.X, Ring.Position.Y + PlayerSize, Ring.Position.Z)
                                        TempStop = true
                                        CanTarget = false
                                        while CheckShield.Parent do
                                            PlayerRoot.CFrame = CFrame.new(ShieldPosition)
                                            task.wait()
                                        end
                                        TempStop = false
                                        CanTarget = true
                                    end
                                end
                                task.wait()
                            end
                            task.wait(.5)
                        end
                    end
                end)
                if not Success then
                    
                end
            end)
        else
            SV.Autofarm = nil
            PlayerRoot.CanCollide = true
            for Part, PartData in TeleportParts do
                if Part and Part.Parent then
                    Part.Size = PartData.OriginalSize
                    Part.CanCollide = PartData.OriginalCollision
                    Part.Position = PartData.OriginalLocation
                end
            end
            if SV.PlayerCamera and SV.PlayerCamera.Parent and PlayerRoot == SV.PlayerCamera.Parent then
                workspace.CurrentCamera.CameraSubject = SV.PlayerCamera
            else
                workspace.CurrentCamera.CameraSubject = (PlayerCharacter and PlayerCharacter:FindFirstChildOfClass("Humanoid")) or PlayerRoot
            end
            SV.Autofarm = nil
        end
    end)
end
if not IsMainMenu then
    Toggles.CollectDropToggle:OnChanged(function(ChangedValue) -- collect drops
        if StringPlaceID == "6510868181" then
            return
        end
        if ChangedValue then
            SV.CollectDrops = true
            if SV.CanRequire and EF.Hook and EF.NewClosure then
                local rDrops = require(Drops)
                CreateHookOnFunction(rDrops.DropStarterpassExp, true)
                CreateHookOnFunction(rDrops.DropBattlepassExp, true)
                CreateHookOnFunction(rDrops.DropHealthOrb, true)
                CreateHookOnFunction(rDrops.SpawnCoinsLocal, true)
            end
            for CoinID, SpawnTime in SV.Drops do
                if time() < SpawnTime+120 then
                    Remotes:WaitForChild("Drops_CoinEvent", math.huge):FireServer(CoinID)
                end
            end
            table.clear(SV.Drops)
            CollectCoins()
        else
            SV.CollectDrops = false
            if SV.CanRequire and EF.Hook and EF.NewClosure then
                local rDrops = require(Drops)
                CreateHookOnFunction(rDrops.DropStarterpassExp, false)
                CreateHookOnFunction(rDrops.DropBattlepassExp, false)
                CreateHookOnFunction(rDrops.DropHealthOrb, false)
                CreateHookOnFunction(rDrops.SpawnCoinsLocal, false)
            end
        end
    end)
end
if not IsMainMenu then
    local PetKillaura
    local PetKillauraChanged
    Toggles.PetKillauraToggle:OnChanged(function(ChangedValue)
        if ChangedValue and SV.SafeMode and not IsDungeon then
            return
        end
 -- use pet skill
        local TimeActivated = os.clock()
        PetKillauraChanged = CheckForCharacter(TimeActivated)
        if TimeActivated ~= PetKillauraChanged then
            return
        end

        if ChangedValue then
            PetKillaura = true
            if SV.CanRequire then
                local Success, Result = pcall(function()
                    local UseSkill = Remotes:WaitForChild("PetSkills_UseSkill", math.huge)
                    local PetSkill = GetPlayerPet(function() return not PetKillaura end)
                    if not PetSkill then
                        PetKillaura = false
                        Toggles.PetKillauraToggle:SetValue(false)
                        Library:Notify("Equip a pet with a supported attack skill first", 5)
                        return
                    end

                    ConnectionTable["ConnectCharacter"] = PlayerCharacter.ChildAdded:Connect(function(NewChild)
                        if NewChild.Name == "PetData" then
                            PetSkill = GetPlayerPet()
                        end
                    end)

                    local CAttack = Remotes:WaitForChild("Combat_Attack", math.huge)
                    local AttackArgs = {
                        Ranged = function(Skill, AttackPosition)
                            CAttack:FireServer(Skill, AttackPosition, nil, AntiCheatNumber)
                        end,
                        Self = function()
                            UseSkill:FireServer(PlayerCharacter, PlayerRoot.Position)
                        end,
                        MobPosition = function(Skill, AttackPosition)
                            UseSkill:FireServer(PlayerCharacter, AttackPosition)
                        end
                    }
                    while PetKillaura and not KillSwitch do
                        for _, Attack in PetSkill.Skills do
                            if CurrentMob then
                                local AttackCooldown = Attack.Cooldown
                                if tick() - (Attack.LastUsed or 0) >= AttackCooldown+AddedDelay then
                                    local AttackType = Attack.Type
                                    local MobCollider = CurrentMob:FindFirstChild("Collider")
                                    if MobCollider then
                                        local AttackDistance = Attack.Distance
                                        local PlayerSurface = PlayerRoot:GetClosestPointOnSurface(MobCollider.Position)
                                        local MobSurface = MobCollider:GetClosestPointOnSurface(PlayerRoot.Position)
                                        local Distance = (PlayerSurface - MobSurface).Magnitude
                                        if Distance <= AttackDistance then
                                            local TpTime = CurrentMob:GetAttribute("T")
                                            if SV.Autofarm and IsBoss and not (TpTime and TpTime+0.2 < time()) then
                                                break
                                            end
                                            local FindAttackType = AttackArgs[AttackType]
                                            if FindAttackType then
                                                FindAttackType(Attack.Skill, MobSurface)
                                            else
                                                SV.PetKillaura = nil
                                                
                                                break
                                            end
                                            Attack.LastUsed = tick()
                                            if DelayPetAttacks then
                                                task.wait(DelayPetAttacks)
                                            end
                                        end
                                    end
                                end
                            end
                        end
                        task.wait(.1)
                    end
                end)
                if not Success then
                    local PetData = PlayerCharacter and PlayerCharacter:FindFirstChild("PetData")
                    if PetData and PetSkills and SV.CanRequire then
                        task.wait(.5)
                        local rPets = require(Pets)
                        local ItemName = PetData:GetAttribute("ItemName")
                        local PetName = ReplicatedStorage.PlayerEquips[PlayerName].Pet[ItemName]
                        local PetRef = rPets:GetPetSkillFromPetRef(PetName)
                        local SkillExists = PetSkills[tostring(PetRef)]
                        if SkillExists then
                            SkillExists = "pet skill is supported."
                        else
                            SkillExists = "skill data for " ..tostring(PetRef).. " was not found, skill not supported"
                        end
                        
                        return
                    end
                    
                end
            else
                local Success, Result = pcall(function()
                    local UseSkill = Remotes:WaitForChild("PetSkills_UseSkill", math.huge)
                    while PetKillaura and not KillSwitch do
                        if CurrentMob then
                            local MobCollider = CurrentMob:FindFirstChild("Collider", true)
                            if MobCollider then
                                UseSkill:FireServer(CurrentMob, MobCollider.Position)
                            end
                        end
                        task.wait(1)
                    end
                end)
                if not Success then
                    
                end
            end
        else
            DisconnectVariable("ConnectCharacter")
            PetKillaura = nil
        end
    end)
    local CheckForRejoin
    local RestartChanged
    Toggles.RestartStuckToggle:OnChanged(function(ChangedValue) -- stuck restart
        local TimeActivated = time()
        RestartChanged = TimeActivated
        CheckForCharacter()
        if TimeActivated ~= RestartChanged then
            return
        end
        if ChangedValue and not IsDungeon then return end
        if ChangedValue then
            local Success, Result = pcall(function()
                ISV.LoggedDifficulty = GetDifficulty()
                CheckForRejoin = true
                RejoinLastDungeon(false)
                local CombatTimer = 0
                repeat
                    if not (SV.Autofarm or SV.Killaura or SV.SafeKillaura) or TempStop or SV.DodgingAttack or SV.QuotaPaused or SV.TransitionPending or IsMissionOver() then
                        CombatTimer=0
                        task.wait(1)
                        continue
                    end
                    if not HoldForRealTime then
                        task.wait(1)
                        local Healthproperties = PlayerCharacter:FindFirstChild("HealthProperties", true)
                        local OutOfCombat = Healthproperties and Healthproperties:FindFirstChild("OutOfCombat", true)
                        if Healthproperties and OutOfCombat then
                            if OutOfCombat.Value == 0 then
                                CombatTimer += 1
                            else
                                CombatTimer = 0
                            end
                        end
                        if CombatTimer >= StuckDelay then
                            task.spawn(function()
                                RejoinLastDungeon(true)
                            end)
                            break
                        end
                    end
                    task.wait(.1)
                until not CheckForRejoin or TimeActivated~=RestartChanged or ScriptUnloaded or KillSwitch
            end)
            if not Success then
                
            end
        else
            CheckForRejoin = nil
        end
    end)
    local DodgeGeneration=0
    Toggles.DodgeLethalToggle:OnChanged(function(enabled)
        DodgeGeneration+=1
        local generation=DodgeGeneration
        if not enabled then return end
        local lastAttacks=setmetatable({},{__mode="k"})
        local hazardPositions=setmetatable({},{__mode="k"})
        local attacks={
            DownwardIceFire={5.9,1.5,"downward ice"},JumpAttack={2.5,2,"jump"},
            Howl={4.2,3.5,"howl"},DarkOrbAttack={8.2,7.5,"dark orb"},
            WingFlap={6,1,"wing flap"},Flyby={15,0,"flyby"},FlybyX3={23,0,"long flyby"},
            EggBomb={10,3,"egg bombs"},SlamJump={5,1,"slam jump"},PrismSlam={3,2,"prism slam"},
        }
        local function stopped()
            return generation~=DodgeGeneration or not Toggles.DodgeLethalToggle.Value or ScriptUnloaded or KillSwitch or SV.TransitionPending
        end
        while not stopped() do
            if Class and Class.Distance=="Melee" and not SV.SafeModeBlocked then
                local mob=CurrentMob
                local props=mob and mob:FindFirstChild("MobProperties")
                local current=props and props:FindFirstChild("CurrentAttack")
                local value=current and current.Value or ""
                if mob then
                    if value=="" then lastAttacks[mob]=nil
                    elseif lastAttacks[mob]~=value then
                        local attack=attacks[value]
                        if attack then
                            lastAttacks[mob]=value
                            DodgeCurrentAttack(attack[2],attack[1]-attack[2],attack[3],nil,function(phase)
                                return stopped() or not mob.Parent or CurrentMob~=mob
                                    or (phase=="delay" and (not current.Parent or current.Value~=value))
                            end)
                        end
                    end
                end
                for _,name in ipairs({"FireBase","FireRings","PoisonRings","PoisonMeteorSpecialMedium","MeteorSpecialSuper"})do
                    if stopped() then break end
                    local effect=Workspace:FindFirstChild(name)
                    if effect and not Workspace:FindFirstChild("AnubisRing") and not Workspace:FindFirstChild("AnubisRingPurple") then
                        local position=hazardPositions[effect]
                        if not position then
                            local vane=Mobs:FindFirstChild("VaneAetherDragon") or Mobs:FindFirstChild("EVENTBOSSVane")
                            position=PlayerRoot.Position+Vector3.new(vane and 0 or 1000,1000,0)
                            hazardPositions[effect]=position
                        end
                        DodgeCurrentAttack(0,30,name,nil,function()return stopped() or not effect.Parent end,position)
                    end
                end
            end
            task.wait(0.05)
        end
    end)

end

end -- for unloaded general tab
if not SV.EventTab then -- for unloaded event tab
SetGlobal("event stuff")
if IsDungeon then
    local CollectBuffs
    Toggles.CollectBuffToggle:OnChanged(function(ChangedValue)
        if ChangedValue then
            CollectBuffs = true
            while CollectBuffs and not KillSwitch do
                if SV.SelectedOrbs then
                    for Orb, enabled in SV.SelectedOrbs do
                        if not enabled then
                            continue
                        end
                        local FoundOrb = Workspace:FindFirstChild(Orb)
                        if FoundOrb then
                            TeleportToOrb(FoundOrb)
                        end
                        task.wait()
                    end
                end
                task.wait(1)
            end
        else
            CollectBuffs = nil
        end
    end)
end
if not IsMainMenu then
    local ClaimingBattlepass = false
    Toggles.AutoClaimBattlepass:OnChanged(function(ChangedValue)
        if ChangedValue then
            if SV.CanRequire then
                if ClaimingBattlepass then
                    return
                else
                    ClaimingBattlepass = true
                end
                local rBattlepass = require(Battlepass)
                local RedeemedItem = Remotes:WaitForChild("Battlepass_RedeemedItem", math.huge)
                local RedeemItem = Remotes:WaitForChild("Battlepass_RedeemItem", math.huge)
                local HasPremiumTrack = Remotes:WaitForChild("Battlepass_HasPremium", math.huge):InvokeServer()

                local FreeClaimed, PaidClaimed = false
                local LastFree, LastPaid = -1

                if not HasPremiumTrack then
                    PaidClaimed = true
                end

                local function ClaimRank(Rank, Paid)
                    local ClaimStart = time() + 3
                    if not Paid then
                        repeat
                            if ScriptUnloaded or KillSwitch or not Toggles.AutoClaimBattlepass.Value or time()>ClaimStart then
                                break
                            end
                            RedeemItem:FireServer(Rank)
                            task.wait(0.25)
                        until RedeemedItem:InvokeServer(Rank)
                    else
                        repeat
                            if ScriptUnloaded or KillSwitch or not Toggles.AutoClaimBattlepass.Value or time()>ClaimStart then
                                break
                            end
                            RedeemItem:FireServer(Rank, true)
                            task.wait(0.25)
                        until RedeemedItem:InvokeServer(Rank, true)
                    end
                end

                repeat
                    local Tracks = { Remotes:WaitForChild("Battlepass_GetItemRanks", math.huge):InvokeServer() }
                    for Track = 1, #Tracks do
                        if ScriptUnloaded or KillSwitch or not Toggles.AutoClaimBattlepass.Value then break end
                        local Rank = Tracks[Track]
                        local NextTier = rBattlepass:FindNextItemTier(Tracks[Track])
                        if Track == 1 and not FreeClaimed then
                            if Rank == 0 or Rank ~= LastFree then
                                ClaimRank(NextTier)
                                LastFree = Rank
                            else
                                FreeClaimed = true
                            end
                        end
                        if Track == 2 and not PaidClaimed then
                            if Rank == 0 or Rank ~= LastPaid then
                                ClaimRank(NextTier, true)
                                LastPaid = Rank
                            else
                                PaidClaimed = true
                            end
                        end
                        task.wait()
                    end
                    task.wait()
                until (FreeClaimed and PaidClaimed)or ScriptUnloaded or KillSwitch or not Toggles.AutoClaimBattlepass.Value
                ClaimingBattlepass = false
            else
                Library:Notify("Your executor doesn't support this option")
            end
        end
    end)
end
end -- for unloaded event tab

if not SV.ClassesTab then -- for unloaded classes tab
SetGlobal("class tab functions")
if not IsMainMenu then
    local ClassBuffGeneration = 0
    Toggles.GeneralClassBuffToggle:OnChanged(function(enabled)
        ClassBuffGeneration += 1
        local generation = ClassBuffGeneration
        if not enabled then return end
        if SV.SafeMode and not IsDungeon then
            return
        end
        local attack = Remotes:FindFirstChild("Skillset_DualWielder_AttackBuff")
        local defense = Remotes:FindFirstChild("Skillset_Guardian_AggroDraw")
        if not attack or not defense then
            Toggles.GeneralClassBuffToggle:SetValue(false)
            Library:Notify("General buff interface unavailable", 4)
            return
        end
        task.spawn(function()
            while generation == ClassBuffGeneration and not KillSwitch
                and not ScriptUnloaded and Toggles.GeneralClassBuffToggle.Value do
                if SV.SafeMode and not IsDungeon then break end
                local character = LocalPlayer.Character
                local health = character and character:FindFirstChild("HealthProperties")
                health = health and health:FindFirstChild("Health")
                if health and health.Value > 0 then
                    pcall(function() attack:FireServer() end)
                    pcall(function() defense:FireServer() end)
                end
                task.wait(1)
            end
        end)
    end)
    local MolBuff
    Toggles.MoLBarrierToggle:OnChanged(function(ChangedValue)
        if ChangedValue and SV.SafeMode and not IsDungeon then
            return
        end
        if ChangedValue and LocalPlayer:GetAttribute("Class")~="MageOfLight" then
            Toggles.MoLBarrierToggle:SetValue(false)
            Library:Notify("This feature requires MageOfLight",4)
            return
        end
 -- mol barrier
        if ChangedValue then
            local Success, Result = pcall(function()
                if SV.PlayerClass == "MageOfLight" then
                    MolBuff = true
                    local Barrier = Remotes:WaitForChild("Skillset_MageOfLight_Barrier")
                    while MolBuff do
                        if KillSwitch then
                            break
                        end
                        local AllPlayers = Players:GetChildren()
                        for _, BarrierAllPlayers in AllPlayers do
                            if BarrierAllPlayers.Name ~= PlayerName then
                                Barrier:FireServer(BarrierAllPlayers)
                            end
                            task.wait()
                        end
                        task.wait(2)
                    end
                end
            end)
            if not Success then
                
            end
        else
            MolBuff = nil
        end
    end)
    local DemonBuff
    Toggles.DemonBloodBindingToggle:OnChanged(function(ChangedValue)
        if ChangedValue and SV.SafeMode and not IsDungeon then
            return
        end
        if ChangedValue and LocalPlayer:GetAttribute("Class")~="Demon" then
            Toggles.DemonBloodBindingToggle:SetValue(false)
            Library:Notify("This feature requires Demon",4)
            return
        end
 -- demon blood binding
        if ChangedValue then
            local Success, Result = pcall(function()
                if SV.PlayerClass == "Demon" then
                    DemonBuff = true
                    local BloodBinding = Remotes:WaitForChild("Skillset_Demon_BloodBinding")
                    while DemonBuff do
                        if KillSwitch then
                            break
                        end
                        if IsAliveMobs > 0 and CurrentMob then
                            BloodBinding:FireServer()
                            task.wait(7)
                        end
                        task.wait(.5)
                    end
                end
            end)
            if not Success then
                
            end
        else
            DemonBuff = nil
        end
    end)
    local StormcallerBuff
    Toggles.StormcallerSuperchargeToggle:OnChanged(function(ChangedValue)
        if ChangedValue and SV.SafeMode and not IsDungeon then
            return
        end
        if ChangedValue and LocalPlayer:GetAttribute("Class")~="Stormcaller" then
            Toggles.StormcallerSuperchargeToggle:SetValue(false)
            Library:Notify("This feature requires Stormcaller",4)
            return
        end
 -- stormcaller supercharge
        if ChangedValue then
            local Success, Result = pcall(function()
                if SV.PlayerClass == "Stormcaller" then
                    StormcallerBuff = true
                    local Supercharge = Remotes:WaitForChild("Skillset_Stormcaller_Supercharge", math.huge)
                    while StormcallerBuff do
                        if KillSwitch then
                            break
                        end
                        if IsAliveMobs > 0 then
                            Supercharge:FireServer()
                            task.wait(8)
                        end
                        task.wait(.5)
                    end
                end
            end)
            if not Success then
                
            end
        else
            StormcallerBuff = nil
        end
    end)
end
end -- for unloaded classes tab

if not SV.DungeonsTab then -- for unloaded dungeons tab
SetGlobal("dungeon tab functions")
if IsDungeon then
    Toggles.CollectChestToggle:OnChanged(function(ChangedValue) -- collect chests
        if ChangedValue then
            if IsMissionOver() then
                CollectChests()
                return
            end
            if IsTower then
                SV.TowerChestDelay = true
                SV.CollectChests = true
                local OpenChest = Remotes:WaitForChild("Chests_OpenChest", math.huge)
                local CheckChest = Remotes:WaitForChild("Chests_CheckCondition", math.huge)
                for _, ChestID in SV.Chests do
                    if CheckChest:InvokeServer(ChestID) then
                        OpenChest:FireServer(ChestID)
                    end
                end
                table.clear(SV.Chests)
                CollectTowerChests()
            else
                SV.CollectDungeonChest = true
            end
        else
            DisconnectVariable("ConnectChests")
            SV.CollectDungeonChest = nil
            SV.TowerChestDelay = nil
        end
    end)
    Toggles.HighestDungeonToggle:OnChanged(function(ChangedValue)
        if ChangedValue then
            task.spawn(EquipNewItemAdded)
            SV.AutoLeveling = true
            if IsMissionOver() then
                ClaimAllQuests()
            end
        else
            DisconnectVariable("ConnectEquipNewItems")
            SV.AutoLeveling = nil
        end
    end)
    Toggles.ReplayMissionToggle:OnChanged(function(ChangedValue) -- replay dropdown
        if ChangedValue then
            SV.ReplayMission = true
            if IsMissionOver() then
                RestartDungeon()
                return
            end
        else
            SV.ReplayMission = nil
        end
    end)
    Toggles.ReplayInfiniteTowerToggle:OnChanged(function(ChangedValue) -- replay inf tower
        if ChangedValue then
            local ReplicateTowerFloor = ReplicatedStorage:FindFirstChild("ReplicateTowerFloor")
            if ReplicateTowerFloor then
                ConnectionTable["ConnectInfTower"] = ReplicateTowerFloor.Changed:Connect(function(NewFloor)
                    if (NewFloor >= RestartAtFloor+1) then
                        Library:Notify("Sending restart")
                        RestartDungeon(true)
                    end
                end)
            end
            if GetLives() == 0 then
                RestartDungeon(true)
            end
        else
            DisconnectVariable("ConnectInfTower")
        end
    end)
end
end -- for unloaded dungeons tab

if not SV.GuildTab then
SetGlobal("guild tab functions")
if IsDungeon then
    local GuildWait
    local PreviousWaitPosition
    local WaitNotification
    local WaitChanged
    Toggles.WaitTimeToggle:OnChanged(function(ChangedValue) -- wait for legit time
        local TimeActivated = os.clock()
        WaitChanged = CheckForCharacter(TimeActivated)
        if TimeActivated ~= WaitChanged then
            return
        end

        if ChangedValue then
            GuildWait = true
            local GuildTimePassed = 0
            local Success, Result = pcall(function()
                local DungeonWaitTime = 120
                for DungeonIndex, Dungeon in SV.DungeonListTable do
                    if Dungeon.DungeonID == ISV.MissionId then
                        DungeonWaitTime = Dungeon.DungeonDelay
                        break
                    end
                end

                local MissionStart = Workspace:FindFirstChild("MissionStart", true)
                local StartGateTime = 0
                if MissionStart then
                    MissionStart:PivotTo(CFrame.new(PlayerRoot.Position))
                    StartGateTime = 5
                end

                HoldForRealTime = true
                task.wait(.2)
                local GuildWaitPosition = Vector3.new(PlayerRoot.Position.X+25000, PlayerRoot.Position.Y+25000, PlayerRoot.Position.Z)
                local PreviousWaitPosition = PlayerRoot.Position
                PlayerRoot.CFrame = CFrame.new(GuildWaitPosition)
                TeleportStandPart()
                local TimeToWait = DungeonWaitTime + (SV.AddedGuildTime or 0) + StartGateTime
                WaitNotification = Library:Notify("Waiting for legit time", TimeToWait)

                local StartTime = time() + TimeToWait
                while GuildWait do
                    if KillSwitch then
                        break
                    end
                    if time() >= StartTime then
                        HoldForRealTime = false
                        PlayerRoot.CFrame = CFrame.new(PreviousWaitPosition)
                        TeleportStandPart()
                        PreviousWaitPosition = nil
                        break
                    end
                    PlayerRoot.CFrame = CFrame.new(GuildWaitPosition)
                    TeleportStandPart()
                    task.wait(.1)
                end
            end)
            if not Success then
                
            end
        else
            GuildWait = nil
            HoldForRealTime = false
            if WaitNotification then
                WaitNotification:Destroy()
                WaitNotification = nil
            end
            if PreviousWaitPosition then
                PlayerRoot.CFrame = CFrame.new(PreviousWaitPosition)
            end
            TeleportStandPart()
        end
    end)
    Toggles.DoAllDungeonsToggle:OnChanged(function(ChangedValue) -- do all dungeons
        if ChangedValue then
            Library:Notify("Doing all dungeons", 10)
            SV.DoingGuildDungeon = true
        else
            SV.DoingGuildDungeon = nil
        end
    end)
    local InfNotification
    local InfDelay
    local InfWait
    local InfChanged
    Toggles.DelayInfFloorToggle:OnChanged(function(ChangedValue) -- delay inf tower
        local TimeActivated = os.clock()
        InfChanged = CheckForCharacter(TimeActivated)
        if TimeActivated ~= InfChanged then
            return
        end

        if ChangedValue then
            InfWait = true
            InfDelay = InfDelay or 25
            local Success, Result = pcall(function()
                if ISV.MissionId == 38 then
                    local DungeonScript = ReplicatedStorage:WaitForChild("MissionScripts", math.huge):FindFirstChildWhichIsA("ModuleScript")
                    if DungeonScript then
                        local IsBossFloor
                        ConnectionTable["UpdateMobTracker"] = DungeonScript:WaitForChild("UpdateMobTracker", math.huge).OnClientEvent:Connect(function(KilledMobs, TotalMobs)
                            if TotalMobs < 10 then
                                IsBossFloor = true
                            else
                                IsBossFloor = false
                                return
                            end
                            if KilledMobs == TotalMobs then
                                InfDelay = InfDelay + SV.IncrementInfiniteDelay
                                IsBossFloor = false
                            end
                        end)
                        ConnectionTable["UpdateTowerFloor"] = DungeonScript:WaitForChild("UpdateTowerFloor", math.huge).OnClientEvent:Connect(function(CurrentFloor)
                            HoldForRealTime = true
                            local GuildWaitPosition = Vector3.new(PlayerRoot.Position.X+25000, PlayerRoot.Position.Y+25000, PlayerRoot.Position.Z)
                            local PreviousPosition = PlayerRoot.Position
                            InfNotification = Library:Notify("Delaying floor", InfDelay)

                            local StartTime = time() + InfDelay
                            while InfWait do
                                if KillSwitch then
                                    break
                                end
                                if IsBossFloor or time() >= StartTime then
                                    if InfNotification then
                                        InfNotification:Destroy()
                                        InfNotification = nil
                                    end
                                    HoldForRealTime = false
                                    PlayerRoot.CFrame = CFrame.new(PreviousPosition)
                                    TeleportStandPart()
                                    break
                                end
                                PlayerRoot.CFrame = CFrame.new(GuildWaitPosition)
                                TeleportStandPart()
                                task.wait(.1)
                            end
                            HoldForRealTime = false
                        end)
                    end
                end
            end)
            if not Success then
                
            end
        else
            if InfNotification then
                InfNotification:Destroy()
                InfNotification = nil
            end
            InfWait = nil
            DisconnectVariable("UpdateMobTracker")
            DisconnectVariable("UpdateTowerFloor")
        end
    end)
    Toggles.GuildQuestToggle:OnChanged(function(ChangedValue) -- claim guild quests
        if ChangedValue then
            if not SV.CanRequire then
                Library:Notify("Your executor doesn't support claiming guild quests", 3)
                return
            end
            SV.ClaimGuildQuests = true
        else
            SV.ClaimGuildQuests = nil
        end
    end)
end
end -- for unloaded guild tab

if not SV.ShopsTab then -- for unloaded shops tab
SetGlobal("shop tab functions")
if not IsMainMenu then
    local AutoHatch
    local AutoHatchGeneration=0
    Toggles.AutoHatchEggToggle:OnChanged(function(ChangedValue)
        AutoHatchGeneration+=1
        local generation=AutoHatchGeneration -- auto hatch eggs
        if ChangedValue then
            Toggles.AutoHatchInventoryEggToggle:SetValue(false)
            AutoHatch = true
            local Success, Result = pcall(function()
                local PetSlot = ReplicatedStorage.PlayerEquips[PlayerName].Pet
                local EquipItem = Remotes:WaitForChild("Inventory_EquipItem", math.huge)
                local Hatch = Remotes:WaitForChild("Pets_Hatch", math.huge)
                local pItems = ProfileInventory.Items
                repeat
                    local TableReference = SV.SelectedEggItem
                    if not TableReference then
                        Library:Notify("No egg is selected", 3)
                        task.wait(3)
                        if not AutoHatch or generation~=AutoHatchGeneration then
                            break
                        end
                        continue
                    end
                    local CurrentPet = PetSlot:FindFirstChildWhichIsA("Folder")
                    if CurrentPet and string.find(CurrentPet.Name, "Egg") then
                        task.wait(.1)
                        continue
                    end
                    task.wait(SV.HatchDelay)
                    if not AutoHatch or generation~=AutoHatchGeneration or ScriptUnloaded or KillSwitch or SV.TransitionPending then break end
                    if not BuyFromEggShop(TableReference.CurrencyType, TableReference.InternalName, TableReference.CoinPrice, TableReference.VisualName) then
                        Library:Notify("You do not have enough gold", 3)
                        task.wait(3)
                        if not AutoHatch or generation~=AutoHatchGeneration then
                            break
                        end
                        continue
                    else
                        local BoughtEgg = pItems:WaitForChild(TableReference.InternalName, 5)
                        if BoughtEgg and not ProtectedInventoryItem(BoughtEgg) then
                            require(Inventory):EquipItemClient(BoughtEgg,PetSlot)
                            local deadline=os.clock()+5
                            repeat task.wait(0.1) until PetSlot:FindFirstChild(TableReference.InternalName) or not AutoHatch or generation~=AutoHatchGeneration or ScriptUnloaded or os.clock()>=deadline
                            if AutoHatch and generation==AutoHatchGeneration and not ScriptUnloaded and PetSlot:FindFirstChild(TableReference.InternalName) then Hatch:FireServer()end
                        end
                    end
                    task.wait()
                until not AutoHatch or generation~=AutoHatchGeneration or ScriptUnloaded or KillSwitch or SV.TransitionPending
            end)
            if not Success then
                
            end
        else
            AutoHatch = nil
        end
    end)
    local AutoHatchInventory
    local AutoHatchInventoryGeneration=0
    Toggles.AutoHatchInventoryEggToggle:OnChanged(function(ChangedValue)
        AutoHatchInventoryGeneration+=1
        local generation=AutoHatchInventoryGeneration -- auto hatch inventory  eggs
        if ChangedValue then
            Toggles.AutoHatchEggToggle:SetValue(false)
            AutoHatchInventory = true
            local Success, Result = pcall(function()
                local EggTable = {}
                for Index, Egg in SV.EggList do
                    EggTable[Egg] = true
                end
                local PetSlot = ReplicatedStorage.PlayerEquips[PlayerName].Pet
                local EquipItem = Remotes:WaitForChild("Inventory_EquipItem", math.huge)
                local Hatch = Remotes:WaitForChild("Pets_Hatch", math.huge)
                local pItems = ProfileInventory.Items
                repeat
                    local CurrentPet = PetSlot:FindFirstChildWhichIsA("Folder")
                    if CurrentPet and CurrentPet.Parent and EggTable[CurrentPet.Name] then
                        task.wait(.1)
                        continue
                    end
                    local HatchingPet = false
                    for Index, Item in pItems:GetChildren() do
                        if Item and IsInventoryItem(Item) and EggTable[Item.Name] and not ProtectedInventoryItem(Item) then
                            task.wait(SV.HatchDelay)
                            if not AutoHatchInventory or generation~=AutoHatchInventoryGeneration or ScriptUnloaded or KillSwitch or SV.TransitionPending then break end
                            require(Inventory):EquipItemClient(Item,PetSlot)
                            local EquippedEgg = PetSlot:WaitForChild(Item.Name, 5)
                            if EquippedEgg then
                                task.wait(.5)
                                if not AutoHatchInventory or generation~=AutoHatchInventoryGeneration or ScriptUnloaded or KillSwitch or SV.TransitionPending then break end
                                Hatch:FireServer()
                                task.wait(5)
                                HatchingPet = true
                                break
                            end
                        end
                    end
                    if not HatchingPet then
                        task.wait(5)
                    end
                    task.wait()
                until not AutoHatchInventory or generation~=AutoHatchInventoryGeneration or ScriptUnloaded or KillSwitch or SV.TransitionPending
            end)
            if not Success then
                
            end
        else
            AutoHatchInventory = nil
        end
    end)
end
end -- for unloaded shops tab
task.wait()

if not SV.MiscellaneousTab then -- for unloaded miscellaneous tab
SetGlobal("misc tab functions")
if IsDungeon then
    SV.PlayerCamera = Camera.CameraSubject
    local CameraChanged
    Toggles.MobCameraToggle:OnChanged(function(ChangedValue) -- mob camera
        local TimeActivated = os.clock()
        CameraChanged = CheckForCharacter(TimeActivated)
        if TimeActivated ~= CameraChanged then
            return
        end

        if ChangedValue then
            task.spawn(function()
                Toggles.NoclipCameraToggle:SetValue(true)
            end)
            IsMobCamera = true
        else
            IsMobCamera = false
            task.wait(.1)
            if SV.PlayerCamera and SV.PlayerCamera.Parent and PlayerRoot == SV.PlayerCamera.Parent then
                workspace.CurrentCamera.CameraSubject = SV.PlayerCamera
            else
                workspace.CurrentCamera.CameraSubject = (PlayerCharacter and PlayerCharacter:FindFirstChildOfClass("Humanoid")) or PlayerRoot
            end
        end
    end)
end
if not IsMainMenu then
    Toggles.DamageNumbersToggle:OnChanged(function(ChangedValue) -- remove damage numbers
        if SV.CanRequire and EF.Hook and EF.ClearHook and EF.NewClosure and EF.CheckHook then
            local Success, Result = pcall(function()
                local RenderDamageNumber = require(Effects).RenderDamageNumber
                if ChangedValue then
                    CreateHookOnFunction(RenderDamageNumber, true)
                else
                    CreateHookOnFunction(RenderDamageNumber, false)
                end
            end)
            if not Success then
                
            end
        else
            local Success, Result = pcall(function()
                local DamageNumbers = Remotes:FindFirstChild("Effects_RenderDamageNumber")
                if ChangedValue and DamageNumbers then
                    SV.RemovedDamageNumbers = true
                    DamageNumbers:Destroy()
                    DamageNumbers = nil
                else
                    if SV.RemovedDamageNumbers then
                        Library:Notify("Rejoin to see damage numbers", 5)
                    end
                end
            end)
            if not Success then
                
            end
        end
    end)
    Toggles.DamageFlashToggle:OnChanged(function(ChangedValue) -- hide damage flash
        if ChangedValue then
            SharedAssets.Combat.HitHighlight.Enabled = false
        else
            SharedAssets.Combat.HitHighlight.Enabled = true
        end
    end)
    Toggles.DeathEffectToggle:OnChanged(function(ChangedValue) -- hide damage flash
        if SV.CanRequire and EF.Hook and EF.ClearHook and EF.NewClosure and EF.CheckHook then
            local Success, Result = pcall(function()
                local DoEffect = require(Effects).DoEffect
                if ChangedValue then
                    local OldFunction
                    OldFunction = EF.Hook(DoEffect, EF.NewClosure(function(a, Effect, ...)
                        if Effect == "DeathEffect" then
                            return
                        else
                            return OldFunction(a, Effect, ...)
                        end
                    end))
                else
                    CreateHookOnFunction(DoEffect, false)
                end
            end)
            if not Success then
                
            end
        else
            local Success, Result = pcall(function()
                if ChangedValue then
                    SV.RemovedDeathEffects = true
                    local DeathEffect = Effects.EffectScripts:FindFirstChild("DeathEffect")
                    if DeathEffect then
                        DeathEffect:Destroy()
                        DeathEffect = nil
                    end
                else
                    if SV.RemovedDeathEffects then
                        Library:Notify("Rejoin to see death effects", 5)
                    end
                end
            end)
            if not Success then
                
            end
        end
    end)
    Toggles.KnockdownToggle:OnChanged(function(ChangedValue) -- stops player from being knocked down
        if SV.CanRequire and EF.Hook and EF.ClearHook and EF.NewClosure and EF.CheckHook then
            local Success, Result = pcall(function()
                local Knockdown = require(Client.Actions).Knockdown
                if ChangedValue then
                    CreateHookOnFunction(Knockdown, true)
                else
                    CreateHookOnFunction(Knockdown, false)
                end
            end)
            if not Success then
                
            end
        end
    end)
end
if IsWorld then
    Toggles.WaystoneToggle:OnChanged(function(ChangedValue)
        local Success, Result = pcall(function()
            if ChangedValue then
                SV.WaystonesHidden = true
                ConnectionTable["ConnectWaystones"] = PlayerGui.ChildAdded:Connect(function(AddedChild)
                    if AddedChild.Parent and AddedChild.Name == "WaystoneDiscoveryIcon" then
                        AddedChild.PlayerToHideFrom = LocalPlayer
                    end
                end)
                for Index, Gui in PlayerGui:GetChildren() do
                    if Gui.Name == "WaystoneDiscoveryIcon" then
                        Gui.PlayerToHideFrom = LocalPlayer
                    end
                end
            else
                if SV.WaystonesHidden then
                    DisconnectVariable("ConnectWaystones")
                    for Index, Gui in PlayerGui:GetChildren() do
                        if Gui.Parent and Gui.Name == "WaystoneDiscoveryIcon" then
                            Gui.PlayerToHideFrom = nil
                        end
                    end
                    SV.WaystonesHidden = nil
                end
            end
        end)
        if not Success then
            
        end
    end)
end
if IsDungeon then
    Toggles.ShowEndTimeToggle:OnChanged(function(ChangedValue) -- display end time
        if ChangedValue then
            SV.ShowTime = true
            if IsMissionOver() then
                Library:Notify("Completed in " ..SV.DungeonCompletionTime)
            end
        else
            SV.ShowTime = nil
        end
    end)
end

Toggles.AFKToggle:OnChanged(function(enabled)
    DisconnectVariable("LarpZeroIdle")
    if enabled then
        ConnectionTable.LarpZeroIdle=LocalPlayer.Idled:Connect(function()
            if not ScriptUnloaded and Toggles.AFKToggle.Value then
                pcall(function()
                    VirtualUser:CaptureController()
                    VirtualUser:ClickButton2(Vector2.new(0,0))
                end)
            end
        end)
    end
end)
if IsMainMenu then
    Toggles.MainMenuPlay:OnChanged(function(ChangedValue)
        if ChangedValue then
            if firesignal then
                local PlayButton = PlayerGui:WaitForChild("MainMenuGui", math.huge):WaitForChild("Main", math.huge):WaitForChild("Play", math.huge):WaitForChild("Play", math.huge)
                if not ChangedValue then
                    return
                end
                while Toggles.MainMenuPlay.Value and not (KillSwitch or ScriptUnloaded) do
                    firesignal(PlayButton.MouseButton1Click)
                    task.wait(.5)
                end
            else
                Library:Notify("Your executor doesn't support this option")
            end
        end
    end)
end
if IsWorld then
    Toggles.AutoJoinDungeon:OnChanged(function(ChangedValue)
        if ChangedValue and ISV.PlayerLevel == 175 then
            ReplayDungeonLoop(1005, 6)
        end
    end)
end
if not IsMainMenu then
    local hiddenCharacters={}
    local function HideOtherCharacter(character)
        local owner=Players:GetPlayerFromCharacter(character)
        if owner and owner~=LocalPlayer and Toggles.RemoveOtherPlayersToggle.Value then
            if not hiddenCharacters[character] then hiddenCharacters[character]={Parent=character.Parent,Owner=owner}end
            character.Parent=nil
        end
    end
    Toggles.RemoveOtherPlayersToggle:OnChanged(function(enabled)
        DisconnectVariable("ConnectCharacterFolder")
        if enabled then
            local folder=Workspace:FindFirstChild("Characters")
            if folder then
                for _,character in ipairs(folder:GetChildren())do HideOtherCharacter(character)end
                ConnectionTable.ConnectCharacterFolder=folder.ChildAdded:Connect(function(character)
                    task.wait(0.1)
                    HideOtherCharacter(character)
                end)
            end
        else
            for character,data in pairs(hiddenCharacters)do
                if data.Owner.Character==character and data.Parent then pcall(function()character.Parent=data.Parent end)end
                hiddenCharacters[character]=nil
            end
        end
    end)
    Toggles.MobESPToggle:OnChanged(function(ChangedValue) -- mob esp
        if ChangedValue then
            for _, Mob in Mobs:GetChildren() do
                if Mob then
                    local Highlight = Instance.new("Highlight")
                    Highlight.Name="LarpZeroMobHighlight"
                    Highlight.FillTransparency = 0
                    Highlight.Parent = Mob
                end
            end
            ConnectionTable["ConnectMobFolder"] = Mobs.ChildAdded:Connect(function(NewMob)
                if NewMob then
                    local Highlight = Instance.new("Highlight")
                    Highlight.Name="LarpZeroMobHighlight"
                    Highlight.FillTransparency = 0
                    Highlight.Parent = NewMob
                end
            end)
        else
            DisconnectVariable("ConnectMobFolder")
            for _, MobFolder in Mobs:GetChildren() do
                local MobHighlight = MobFolder and MobFolder:FindFirstChild("LarpZeroMobHighlight", true)
                if MobHighlight then
                    MobHighlight:Destroy()
                    MobHighlight = nil
                end
            end
        end
    end)
    local originalCameraMode
    Toggles.NoclipCameraToggle:OnChanged(function(ChangedValue) -- noclip camera
        if ChangedValue then
            if originalCameraMode==nil then originalCameraMode=LocalPlayer.DevCameraOcclusionMode end
            LocalPlayer.DevCameraOcclusionMode=Enum.DevCameraOcclusionMode.Invisicam
        elseif originalCameraMode~=nil then
            LocalPlayer.DevCameraOcclusionMode=originalCameraMode
            originalCameraMode=nil
        end
    end)
    local savedJump=setmetatable({},{__mode="k"})
    local function ApplyAutoJump(character)
        local humanoid=character and character:FindFirstChildOfClass("Humanoid")
        if humanoid and Toggles.DisableAutoJumpToggle.Value then
            if savedJump[humanoid]==nil then savedJump[humanoid]=humanoid.AutoJumpEnabled end
            humanoid.AutoJumpEnabled=false
        end
    end
    Toggles.DisableAutoJumpToggle:OnChanged(function(enabled)
        if enabled then ApplyAutoJump(LocalPlayer.Character)
        else for humanoid,value in pairs(savedJump)do if humanoid.Parent then humanoid.AutoJumpEnabled=value end savedJump[humanoid]=nil end end
    end)
    ConnectionTable.LarpZeroJump=LocalPlayer.CharacterAdded:Connect(function(character)
        character:WaitForChild("Humanoid",5)
        ApplyAutoJump(character)
    end)
    ISV.RenderingScreen = MakeGuiElement("ScreenGui", {
        IgnoreGuiInset = true,
        DisplayOrder = -1,
    })
        MakeGuiElement("Frame", {
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.new(0.5, 0, 0.5, 0),
            BackgroundColor3 = Color3.fromRGB(0, 0, 0),
            Size = UDim2.new(1, 0, 2, 0),
            Parent = ISV.RenderingScreen
        })
        MakeGuiElement("TextLabel", {
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.new(0.5, 0, 0.5, 0),
            BackgroundTransparency = 1,
            BackgroundColor3 = Color3.fromRGB(0, 0, 0),
            Size = UDim2.new(0.5, 0, 0.1, 0),
            TextColor3 = Color3.new(255, 255, 255),
            FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json"),
            Text = "3d rendering disabled",
            TextScaled = true,
            Parent = ISV.RenderingScreen
        })
    Toggles.DisableRenderingToggle:OnChanged(function(ChangedValue) -- disable rendering
        if IsDungeon then
            local Success, Result = pcall(function()
                if ChangedValue then
                    RunService:Set3dRenderingEnabled(false)
                    ISV.RenderingScreen.Parent = EF.HideGui() or CoreGui
                else
                    RunService:Set3dRenderingEnabled(true)
                    ISV.RenderingScreen.Parent = nil
                end
            end)
            if not Success then
                
            end
        end
    end)
    local SetUpFakeModel
    local FakeModelTemplate
    Toggles.PreventMobToggle:OnChanged(function(ChangedValue) -- stop rendering new things
        if SV.CanRequire and EF.Hook and EF.ClearHook and EF.NewClosure and EF.CheckHook then
            local Success, Result = pcall(function()
                local GetModel = require(ModelProvider).GetModel
                if ChangedValue then
                    if not FakeModelTemplate then
                        FakeModelTemplate=SharedAssets.Effects.Models.Shockball:Clone()
                        SetUpFakeModel=nil
                    end
                    local Shockball=FakeModelTemplate
                    if not SetUpFakeModel then
                        if not Shockball:FindFirstChild("HumanoidRootPart") then
                            Shockball.Part.Color = Color3.fromRGB(255, 0, 0)
                            Shockball.Part.Material = "Neon"
                            Shockball.Part.Transparency = 0.7
                            Shockball.Part.Name = "HumanoidRootPart"
                        end
                        SetUpFakeModel = true
                    end

                    local ModelHook
                    ModelHook = EF.Hook(GetModel, EF.NewClosure(function(self, model)
                        if type(model)=="string" and not string.find(model, "Pet") then
                            return Shockball:Clone()
                        else
                            return ModelHook(self, model)
                        end
                    end))
                else
                    CreateHookOnFunction(GetModel, false)
                    if FakeModelTemplate then FakeModelTemplate:Destroy() FakeModelTemplate=nil SetUpFakeModel=nil end
                end
            end)
            if not Success then
                
            end
        else
            local Success, Result = pcall(function()
                local GetModel = Remotes:FindFirstChild("ModelProvider_GetModel")
                if ChangedValue and GetModel then
                    Library:Notify("Model filtering requires reversible function hooks in this executor",5)
                else
                    if SV.RemovedModels then
                        Library:Notify("Rejoin to see assets", 5)
                    end
                end
            end)
            if not Success then
                
            end
        end
    end)
    Toggles.PreventEffectsToggle:OnChanged(function(ChangedValue)
        if SV.CanRequire and EF.Hook and EF.ClearHook and EF.NewClosure and EF.CheckHook then
            local Success, Result = pcall(function()
                local rEffects = require(Effects)
                if ChangedValue then
                    CreateHookOnFunction(rEffects.MakeProjectile, true)
                    CreateHookOnFunction(rEffects.DoEffect, true)
                    CreateHookOnFunction(rEffects.PlayAt, true)
                    CreateHookOnFunction(rEffects.EmitAt, true)
                else
                    CreateHookOnFunction(rEffects.MakeProjectile, false)
                    CreateHookOnFunction(rEffects.DoEffect, false)
                    CreateHookOnFunction(rEffects.PlayAt, false)
                    CreateHookOnFunction(rEffects.EmitAt, false)
                end
            end)
            if not Success then
                
            end
        else
            Library:Notify("Your executor doesn't support this option", 5)
        end
    end)
end
end -- for unloaded miscellaneous tab

Library:OnUnload(function()GameCall(function()QuickMenuController.Close()end)end)
local InstallDeveloperGuard=(function()
return function(toggle,context)
    local generation=0
    local connection
    local leaving=false
    toggle:OnChanged(function(enabled)
        generation+=1
        local token=generation
        leaving=false
        if connection then connection:Disconnect()connection=nil end
        if not enabled then return end
        local function check(player)
            if player==context.Player then return end
            task.spawn(function()
                local ok,staff=context.IsStaff(player)
                if token==generation and toggle.Value and not leaving and not context.Stopped() and ok and staff==true then
                    leaving=true
                    context.Leave()
                end
            end)
        end
        connection=context.PlayerAdded:Connect(check)
        for _,player in ipairs(context.Players())do check(player)end
    end)
    context.OnUnload(function()
        generation+=1
        if connection then connection:Disconnect()end
    end)
end

end)()
InstallDeveloperGuard(Toggles.DevKickToggle,{
    Player=LocalPlayer,PlayerAdded=Players.PlayerAdded,Players=function()return Players:GetPlayers()end,
    IsStaff=function(player)return GameCall(function()return require(Shared.Admin):IsAdmin(player,true)end)end,
    Leave=function()GameCall(function()LocalPlayer:Kick("A game staff account joined this server")end)end,
    Stopped=function()return ScriptUnloaded end,
    OnUnload=function(callback)Library:OnUnload(callback)end,
})
local InstallTradeMenu=(function()
return function(library,button,context)
    local lastPartner
    local function remember()
        local ok,trade=context.CurrentTrade()
        if not ok or not trade then return end
        for _,participant in ipairs(trade:GetChildren())do
            local other=context.FindPlayer(participant.Name)
            if other and other~=context.Player then lastPartner=other return end
        end
    end
    local connection=context.Updated:Connect(remember)
    remember()
    -- Only the current counterpart is kept in memory for this explicit button.
    button.Func=function()
        remember()
        if not lastPartner or not context.Present(lastPartner) then
            library:Notify("No previous trade partner is available in this server",4)
            return
        end
        context.Invite(lastPartner)
    end
    library:OnUnload(function()
        connection:Disconnect()
        lastPartner=nil
    end)
end

end)()
local tradeOk,tradeApi=GameCall(function()return require(Shared.Trade)end)
if tradeOk and tradeApi then
    local updatedOk,updated=GameCall(function()return tradeApi:GetUpdatedSignal()end)
    if updatedOk and updated then
        for _,button in pairs(Library.Buttons)do
            if button.Text=="Trade with last person" then
                InstallTradeMenu(Library,button,{
                    Player=LocalPlayer,Updated=updated,
                    CurrentTrade=function()return GameCall(function()return tradeApi:GetTradeForPlayer(LocalPlayer)end)end,
                    FindPlayer=function(name)return Players:FindFirstChild(name)end,
                    Present=function(player)return player.Parent==Players end,
                    Invite=function(player)return GameCall(function()return tradeApi:InviteToTrade(LocalPlayer,player)end)end,
                })
            end
        end
    end
end

SetGlobal("getting mission id")
if IsDungeon then
    MissionObjects = Workspace:WaitForChild("MissionObjects", math.huge)
    ISV.MissionId = WaitForAttribute(Workspace, "MissionId")
end 

SetGlobal("nightmare dungeon check")
do
    if IsDungeon and (ISV.MissionId > 1004 and ISV.MissionId < 1008 ) then
        SV.IsNightmareDungeon = true
    end
end

SetGlobal("get attack data")
if not IsMainMenu and not KillSwitch then
    local Success, Result = pcall(function()
        ClassSkills = BundledClasses()
        PetSkills = BundledPets()
        if ClassSkills and PetSkills then
            Class = GetPlayerClass()
            if Class ~= nil then
                local ClassRange = Class.Distance
                if ClassRange == "Ranged" then
                    Xdistance = Options.ChangedRangedXSlider.Value
                    Ydistance = Options.ChangedRangedYSlider.Value
                elseif ClassRange == "Melee" then
                    Xdistance = Options.ChangedMeleeXSlider.Value
                    Ydistance = Options.ChangedMeleeYSlider.Value
                end
            end
        else
            
        end
    end)
    if not Success then
        
    end
end

ConnectionTable.LarpZeroClassState=LocalPlayer:GetAttributeChangedSignal("Class"):Connect(function()
    local name=LocalPlayer:GetAttribute("Class")
    SV.PlayerClass=name
    ISV.PlayerClass=name
    local data=ClassSkills and ClassSkills[name]
    if data then
        Class=BuildAttackData(ClassSkills,name)
        local ranged=data.Distance=="Ranged"
        SV.IsRanged=ranged and true or nil
        local x=Options[ranged and "ChangedRangedXSlider" or "ChangedMeleeXSlider"]
        local y=Options[ranged and "ChangedRangedYSlider" or "ChangedMeleeYSlider"]
        if x and y then Xdistance=x.Value Ydistance=y.Value end
    else Class=nil end
end)
SetGlobal("require() check")
if not IsMainMenu then
    local Success, Result = pcall(function()
        require(LocalPlayer:WaitForChild("PlayerScripts", math.huge):WaitForChild("PlayerModule", math.huge))
    end)
    if not Success then
        SV.CanRequire = nil
        
    else
        SV.CanRequire = true
    end
end

SetGlobal("removing purchase prompt")
task.spawn(function()
    pcall(function()
        if IsDungeon and CoreGui and CoreGui:FindFirstChild("PurchasePromptApp") then
            CoreGui:FindFirstChild("PurchasePromptApp"):Destroy()
        end
    end)
end)

SetGlobal("dungeon specific checks")
if IsDungeon then
    task.spawn(function()
        CheckForCharacter()
        task.spawn(function()
            local Success, Result = pcall(function()
                local SaveRemote = {
                    ["Mob_EVENTBOSSCupidZeus_ButtonSmash"] = true,
                    ["Mob_EVENTBOSSEasterBunny_ChallengeFloorPattern"] = true,
                    ["Mob_EVENTBOSSEasterBunny_RequestGiantEggChallengeFloorIntro"] = true,
                    ["Mob_EVENTBOSSEasterBunny_DoGiantEgg"] = true,
                    ["Mob_EVENTBOSSUndeadVane_ResurrectShake"] = true,
                    ["Mob_FallenKingMinion_OnCureFountain"] = true
                }
                for Index, Descednant in Remotes:GetChildren() do
                    if Descednant:IsA("RemoteEvent") and string.find(Descednant.Name, "Mob_") then
                        if SaveRemote[Descednant.Name] then
                            continue
                        end
                        local CloneRemote = Descednant:Clone()
                        CloneRemote.Parent = Descednant.Parent
                        Descednant:Destroy()
                        Descednant = nil
                    end
                end
            end)
            if not Success then
                
            end
        end)
        task.spawn(function()
            if ISV.MissionId == 49 then
                local Success, Result = pcall(function()
                    if SV.CanRequire and debug and getupvalue then
                        local ChestScript = debug.getupvalue(require(Chests).Start, 12)
                        local OpenChest = Remotes:WaitForChild("Chests_OpenChest", math.huge)
                        repeat
                            for ChestKey, Useless in ChestScript do
                                OpenChest:FireServer(ChestKey)
                            end
                            task.wait(.1)
                        until KillSwitch
                    else
                        local ChestNames = {
                            "RaidChestBlue", "RaidChestGold", "RaidChestSilver"
                        }
                        repeat
                            for Index, ChestName in ChestNames do
                                local Chest = Workspace:FindFirstChild(ChestName)
                                if Chest and Chest.Parent then
                                    Chest:PivotTo(CFrame.new(PlayerRoot.Position))
                                end
                                task.wait()
                            end
                            task.wait(.1)
                        until KillSwitch
                    end
                end)
                if not Success then
                    
                end
            end
        end)
        task.spawn(function()
            if ISV.MissionId == 54 then
                local IntroDone = Remotes:WaitForChild("Tutorial_IntroDone", math.huge)
                repeat
                    IntroDone:FireServer()
                    task.wait()
                until KillSwitch
            end
            if ISV.MissionId == 53 then
                task.spawn(function()
                    local ObbyEnd = MissionObjects:WaitForChild("Room2", math.huge):WaitForChild("ObbyEnd", math.huge):WaitForChild("VFX", math.huge).Position
                    local Teleporting
                    local ObjectiveMessage = ReplicatedStorage:WaitForChild("ObjectiveMessage", math.huge)
                    local MaxJudgementThreshold = 40
                    if not SV.IsRanged then
                        MaxJudgementThreshold = 60
                    end
                    ConnectionTable["ConnectObjectiveMessage"] = ObjectiveMessage.Changed:Connect(function(NewString)
                        if Teleporting then
                            return
                        end
                        if not string.find(NewString, "together") then
                            return
                        end
                        Teleporting = true
                        task.wait(0.5)
                        local Sword = MissionObjects:WaitForChild("Room1", math.huge):WaitForChild("Sword", math.huge):WaitForChild("Blade", math.huge).Position
                        if Sword then
                            local TeleportTimer = time() + 1
                            repeat
                                PlayerRoot.CFrame = CFrame.new(Sword)
                                task.wait()
                            until time() > TeleportTimer or not SV.Autofarm
                        end
                        local TweenPlaying
                        repeat
                            local TetherPartner = LocalPlayer:GetAttribute("TetherPartner")
                            local Judgement = PlayerCharacter:GetAttribute("Judgment")
                            if Judgement and tonumber(Judgement) >= MaxJudgementThreshold and TetherPartner then
                                local Partner = Workspace:WaitForChild("Characters", math.huge):FindFirstChild(TetherPartner)
                                if Partner then
                                    local PartnerHealth = Partner:WaitForChild("HealthProperties", math.huge):WaitForChild("Health", math.huge)
                                    if PartnerHealth and PartnerHealth.Value > 0 then
                                        local PartnerCollider = Partner:WaitForChild("Collider", math.huge)
                                        TempStop = true
                                        if TweenPlaying then
                                            TweenPlaying:Cancel()
                                        end
                                        repeat
                                            if SV.Autofarm then
                                                PlayerRoot.CFrame = CFrame.new(PartnerCollider.Position + Vector3.new(0, 2, 0))
                                                TeleportStandPart()
                                            end
                                            task.wait()
                                        until (KillSwitch or not string.find(tostring(ObjectiveMessage.Value), "together") or not Partner.Parent)
                                        TempStop = false
                                    end
                                end
                            else
                                if SV.Autofarm then
                                    local EndPos = { CFrame = CFrame.new(ObbyEnd.X, ObbyEnd.Y+6, ObbyEnd.Z)}
                                    local Distance = (PlayerRoot.Position - ObbyEnd).Magnitude / 100
                                    local tweenInfo = TweenInfo.new(Distance, Enum.EasingStyle.Linear)
                                    local tween = TweenService:Create(PlayerRoot, tweenInfo, EndPos)
                                    PlayerRoot.Velocity = Vector3.new()
                                    TeleportStandPart()
                                    TweenPlaying = tween:Play()
                                end
                            end
                            task.wait()
                        until (KillSwitch or not string.find(tostring(ObjectiveMessage.Value), "together"))
                        DisconnectVariable("ConnectObjectiveMessage")
                    end)
                end)
            
                task.spawn(function()
                    local HeavenGuardianGold = Mobs:WaitForChild("HeavenGuardianGold", math.huge)
                    local GoldHealthProperties = HeavenGuardianGold:WaitForChild("HealthProperties", math.huge)
                    local GoldMaxHealth = GoldHealthProperties:WaitForChild("MaxHealth", math.huge).Value
                    local GoldPercentage = 100
                
                    local HeavenGuardianBlue = Mobs:WaitForChild("HeavenGuardianBlue", math.huge)
                    local BlueHealthProperties = HeavenGuardianBlue:WaitForChild("HealthProperties", math.huge)
                    local BlueMaxHealth = BlueHealthProperties:WaitForChild("MaxHealth", math.huge).Value
                    local BluePercentage = 100
                
                    ConnectionTable["GoldGuardian"] = GoldHealthProperties:WaitForChild("Health", math.huge).Changed:Connect(function(CurrentHealth)
                        local CurrentPercentage = GetPercentage(GoldMaxHealth, CurrentHealth)
                        if CurrentPercentage then
                            if SV.Autofarm then
                                if (CurrentPercentage + 3) <= BluePercentage then
                                    GoldPercentage = CurrentPercentage
                                    local BlueIndex = ISV.MobTable[HeavenGuardianBlue]
                                    local GoldIndex = ISV.MobTable[HeavenGuardianGold]
                                    if BlueIndex and GoldIndex then
                                        GoldIndex.Priority = nil
                                        BlueIndex.Priority = true
                                    end
                                end
                            end
                            if CurrentPercentage == 0 then
                                DisconnectVariable("GoldGuardian")
                            end
                        end
                    end)
                
                    ConnectionTable["BlueGuardian"] = BlueHealthProperties:WaitForChild("Health", math.huge).Changed:Connect(function(CurrentHealth)
                        local CurrentPercentage = GetPercentage(BlueMaxHealth, CurrentHealth)
                        if CurrentPercentage then
                            if SV.Autofarm then
                                if (CurrentPercentage + 3) <= GoldPercentage then
                                    BluePercentage = CurrentPercentage
                                    local BlueIndex = ISV.MobTable[HeavenGuardianBlue]
                                    local GoldIndex = ISV.MobTable[HeavenGuardianGold]
                                    if BlueIndex and GoldIndex then
                                        BlueIndex.Priority = nil
                                        GoldIndex.Priority = true
                                    end
                                end
                            end
                            if CurrentPercentage == 0 then
                                DisconnectVariable("BlueGuardian")
                            end
                        end
                    end)
                    if not SV.IsRanged then
                        repeat
                            MobRotationSpeed = 25.5
                            task.wait(0.1)
                        until not (HeavenGuardianGold.Parent and HeavenGuardianBlue.Parent) or KillSwitch
                        MobRotationSpeed = Options.MobRotationSpeedSliderNew.Value or 20
                    end
                end)
                
                task.spawn(function()
                    local BossRoomTrigger = MissionObjects:WaitForChild("BossRoom", math.huge):WaitForChild("BossDoorTrigger", math.huge)
                    local TouchTransmitter = BossRoomTrigger:WaitForChild("TouchInterest", math.huge)
                    BossRoomTrigger = BossRoomTrigger.Position
                    TempStop = true
                    repeat
                        if SV.Autofarm then
                            local EndPos = { CFrame = CFrame.new(BossRoomTrigger.X, BossRoomTrigger.Y, BossRoomTrigger.Z)}
                            local Distance = (PlayerRoot.Position - BossRoomTrigger).Magnitude / 100
                            local tweenInfo = TweenInfo.new(Distance, Enum.EasingStyle.Linear)
                            local tween = TweenService:Create(PlayerRoot, tweenInfo, EndPos)
                            PlayerRoot.Velocity = Vector3.new()
                            TeleportStandPart()
                            tween:Play()
                        end
                        task.wait()
                    until not TouchTransmitter.Parent or KillSwitch
                    TempStop = false
                end)
                
                task.spawn(function()
                    if SV.CanRequire and EF.Hook and EF.NewClosure then
                        local Success, Result = pcall(function()
                            SV.HeavenDisplayHook = require(Client.Gui):Get("LootReceived")._DisplayItem
                            CreateHookOnFunction(SV.HeavenDisplayHook, true)
                        end)
                        if not Success then
                            
                        end
                    end
                    local SpawnChest = Remotes:WaitForChild("Chests_SpawnChest", math.huge)
                    local OpenChest = Remotes:WaitForChild("Chests_OpenChest", math.huge)
                    ConnectionTable["ConnectChests"] = SpawnChest.OnClientEvent:Connect(function(a, b, GUID, d, e)
                        OpenChest:FireServer(GUID)
                        CreateHookOnFunction(SV.HeavenDisplayHook, false)
                    end)
                end)

                local BOSSSeraphiel = Mobs:WaitForChild("BOSSSeraphiel", math.huge)
                if BOSSSeraphiel then
                    local ArenaCenter = MissionObjects:WaitForChild("BossRoom", math.huge):WaitForChild("ArenaCenter", math.huge)
                    local RotationAroundCenter = math.random(0, 360)
                    local ArenaRotationSpeed = 30
                    task.spawn(function()
                        repeat
                            local DistanceFromCenter = 75 + (ArenaCenter.Size.X/2)
                            RotationAroundCenter = RotationAroundCenter + (ArenaRotationSpeed / DistanceFromCenter)
                            if not CurrentMob and SV.Autofarm then
                                PlayerRoot.CFrame = CFrame.new(ArenaCenter.Position) * CFrame.Angles(0, math.rad(RotationAroundCenter), 0) * CFrame.new(DistanceFromCenter, 25, 0)
                                PlayerRoot.CFrame = CFrame.new(PlayerRoot.Position, Vector3.new(ArenaCenter.Position.X, PlayerRoot.Position.Y, ArenaCenter.Position.Z))
                                TeleportStandPart()
                            end
                            task.wait()
                        until KillSwitch
                    end)
                    task.spawn(function()
                        repeat
                            local BossRef = Mobs:WaitForChild("BOSSSeraphiel", math.huge)
                            local function GetBossAttack()
                                return Mobs:WaitForChild("BOSSSeraphiel", math.huge):WaitForChild("MobProperties", math.huge):WaitForChild("CurrentAttack", math.huge)
                            end
                            ConnectionTable["HEAVENRAIDBOSS"] = GetBossAttack().Changed:Connect(function(CurrentAttack)
                                if CurrentAttack and SV.Autofarm then
                                    if CurrentAttack == "JudgmentWalls" then
                                        DodgeCurrentAttack(1.5, 11.5, "judgment walls")
                                    elseif CurrentAttack == "BurdenOfLight" then
                                        local CharacterCheck = Workspace:WaitForChild("Characters", math.huge):GetChildren()
                                        if #CharacterCheck > 1 then
                                            CanTarget = false
                                            TeleportMob = nil
                                            task.wait(5)
                                            CanTarget = true
                                        end
                                    end
                                end
                            end)
                            repeat
                                task.wait(0.5)
                            until not BossRef.Parent or KillSwitch
                            DisconnectVariable("HEAVENRAIDBOSS")
                            GetBossAttack = nil
                        until KillSwitch
                    end)
                end
            end
            if ISV.MissionId == 22 then
                ConnectionTable["CuringWell"] = Remotes:WaitForChild("Mob_FallenKingMinion_OnCureFountain").OnClientEvent:Connect(function()
                    local Status = PlayerCharacter:WaitForChild("Status", math.huge)
                    local DeathMark = Status:WaitForChild("DeathMark", math.huge)
                    local Fountain = Workspace:WaitForChild("CureFountainFallenKing", math.huge)
                    local FountainTeleport = Fountain:WaitForChild("ArcanePanel", math.huge)
                    TempStop = true
                    repeat
                        TeleportStandPart()
                        PlayerRoot:PivotTo(CFrame.new(FountainTeleport.Position))
                        task.wait()
                    until not DeathMark.Parent
                    Fountain:Destroy()
                    Fountain = nil
                    TempStop = false
                end)
                ConnectionTable["FALLEN_KING_ATTACKS"] = Mobs:WaitForChild("BOSSFallenKing", math.huge):WaitForChild("MobProperties", math.huge):WaitForChild("CurrentAttack", math.huge).Changed:Connect(function(CurrentAttack)
                    if not SV.Autofarm or (SV.IsRanged and not SV.SafeKillaura) then
                        return
                    end
                    if CurrentAttack == "DarkOrbAttack" then
                        DodgeCurrentAttack(6, 1, "dark orb")
                    elseif CurrentAttack == "FistSlam" then
                        DodgeCurrentAttack(0, 1, "stomp")
                    end
                end)
                repeat
                    local FallenPrince = Mobs:WaitForChild("BOSSFallenPrince", math.huge):WaitForChild("MobProperties", math.huge):WaitForChild("CurrentAttack", math.huge)
                    ConnectionTable["FALLEN_PRINCE"] = FallenPrince.Changed:Connect(function(CurrentAttack)
                        if not SV.Autofarm or (SV.IsRanged and not SV.SafeKillaura) then
                            return
                        end
                        if CurrentAttack == "Spikes" then
                            DodgeCurrentAttack(3, 1, "spikes")
                        elseif CurrentAttack == "Swing1" then
                            DodgeCurrentAttack(0.25, 1, "slash")
                        end
                    end)
                    repeat task.wait() until not FallenPrince.Parent or KillSwitch
                    DisconnectVariable("FALLEN_PRINCE")
                    FallenPrince = nil
                    task.wait()
                until KillSwitch
            end
        end)
    end)
end

SetGlobal("removing mission remotes")
do
    if IsDungeon then
        local BadRemotes = {
            ["FireDart"] = true,
            ["HammerHit"] = true,
            ["CreateBolder"] = true,
            ["ToxinTrigger"] = true,
            ["RollingBoulder"] = true
        }
        local MissionScript = ReplicatedStorage:WaitForChild("MissionScripts", math.huge):FindFirstChildWhichIsA("ModuleScript")
        if MissionScript then
            for Index, Remote in MissionScript:GetChildren() do
                if Remote and Remote.Parent then
                    if BadRemotes[Remote.Name] then
                        Remote:Destroy()
                        Remote = nil
                    end
                end
            end
        end
        MissionObjects = Workspace:WaitForChild("MissionObjects", math.huge)
        ISV.MissionId = WaitForAttribute(Workspace, "MissionId")
    end
end

SetGlobal("looking for teleport parts")
if IsDungeon then
    local Success, Result = pcall(function()
        local FindDungeonParts = {
            ["49"] = { -- tutorial
                { "CutsceneTrigger" }, { "MinibossTrigger" }, { "Cabbages", "1", "Main" }, { "Cabbages", "2", "Main" }, { "CaveTrigger" }, { "ChadCaveTrigger" }
            },
            ["54"] = { -- chad tutorial
                { "Markers", "ChadIntroTrigger" }, { "Markers", "Area2StartTrigger" }, { "Markers", "Area2_Blockage" }, { "Markers", "Area3StartTrigger" }, { "BossTrigger" }
            },
            ["47"] = { -- returning player dungeon
                { "BossTrigger" }
            },
            ["1"] = { -- Crabby crusade
                { "CutsceneTrigger" }, { "Cabbages", "1", "Main" }, { "Cabbages", "2", "Main" }, { "CaveTrigger" }
            },
            ["3"] = {}, -- Scarecrown defense 
            ["2"] = { -- Dire problem
                { "TownTalkPart" }, { "BridgeTrigger" }, { "CaveTrigger" }, { "BoulderTrigger" }, { "BoulderStopTrigger" }, { "BossIntroTrigger" }
            },
            ["4"] = { -- Kingslayer
                { "CannonTrigger" }, { "CastleTrigger" },
                NoParent = {
                    { "Cage2Marker", "Collider" }, { "Cage1Marker", "Collider" }
                }
            },
            ["6"] = {}, -- Gravetower dungeon
            ["11"] = { -- Temple of ruin
                { "Room1Trigger" }, { "Room2Trigger" }, { "Room3Trigger" }, { "Room4Trigger" }, { "WallsTrigger" }, { "WallsFinalTrigger" },
                NoParent = {
                    { "TreasureMarker", "Collider" }
                }
            },
            ["12"] = { -- Mama trauma
                { "PreBridgeTrigger" }, { "BridgeTrigger" }, { "CaveSpawnTrigger" }, { "CliffsideEndTrigger"},
                DeleteParts = {
                    { "CheckpointTriggers" }, { "MissionObjects", "TempleTrigger" }
                }
            },
            ["13"] = { -- Volcanos shadow
                { "VineRoomTrigger" }, { "CheckpointTrigger" }, { "CannonTrigger" }, { "ObbyTrigger" }, { "BossTrigger" },
                DeleteParts = {
                    { "MissionObjects", "LavaTriggers" }, { "MissionObjects", "LavaTrigger" }
                }
            },
            ["7"] = {}, -- Volcano dungeon
            ["14"] = { -- Mountain pass
                { "CaveTrigger" }, { "DropTrigger" }
            },
            ["15"] = { -- Winter cavern
                { "BossTrigger" }
            },
            ["16"] = { -- Winter dungeon
                { "CastleGateTrigger" }, { "BossTrigger" }
            },
            ["20"] = { -- Scrap canyon
                { "SceneTrigger" }
            },
            ["19"] = {}, -- Deserted burrowmine
            ["18"] = { -- Pyramid dungeon
                { "OutsideBossTrigger" }, { "BossTrigger" },
                DeleteParts = {
                    { "MissionObjects", "WaterKillPart" }, { "MissionObjects", "BossKillPart" }
                }
            },
            ["24"] = {}, -- Konoh heartlands
            ["35"] = {}, -- Konoh inferno
            ["21"] = { -- Prison tower
                { "WaveStarter", Regenerates = true }, { "WaveExit"}, { "BossDoorTrigger" }
            },
            ["25"] = { -- Rough waters
                { "Area1Trigger" }, 
                CheckpointGates = {
                    { "Checkpoint4", "VentButton", "FinishRing" }
                }
            },
            ['36'] = { -- Treasure hunt
                CheckpointGates = {
                    { "Checkpoint1", "FinishRing" }, { "Checkpoint3", "TriggerObjective" }, { "Checkpoint3", "ObbyTrigger" }, { "Checkpoint7", "ObbyTrigger" }
                },
                { "StartWaveDefense" },
                DeleteParts = {
                    { "MissionObjects", "DamageCeiling" }
                }
            },
            ["23"] = { -- Atlantis tower
                { "WaveStarter", Regenerates = true }, { "WaveExit"}, { "BossDoorTrigger" }
            },
            ["26"] = { -- The underworld
                { "Trigger1" }, { "Trigger2" }, { "Trigger3" }
            },
            ["37"] = { -- The labyrinth
                CheckpointGates = {
                    { "Checkpoint5", "ObbyTrigger" }
                },
                { "BossCutsceneTrigger" }
            },
            ["27"] = { -- Mexuvian tower
                { "WaveStarter", Regenerates = true }, { "WaveExit"}, { "BossDoorTrigger" }
            },
            ["30"] = { --Rescue in the ruin
                { "FloorTrigger" }, { "Trigger1" }, { "BottomElevatorTrigger" }, { "MiddleElevatorTrigger" }, { "TopElevatorTrigger" }
            },
            ["31"] = {}, -- Ruin rush
            ["29"] = { -- Oasis tower
                { "WaveStarter", Regenerates = true }, { "WaveExit"}, { "BossDoorTrigger" }
            },
            ["32"] = { -- Treetop trouble
                { "ObbyTrigger5" }
            },
            ["33"] = {
                CheckpointGates = { -- Aether fortress
                    { "Checkpoint3", "ObbyTrigger" }, { "Checkpoint7", "ObbyTrigger" }
                }
            },
            ["34"] = { -- Aether tower
                { "WaveStarter", Regenerates = true }, { "WaveExit"}, { "BossDoorTrigger" }
            },
            ["41"] = { -- Crystal chaos
                CheckpointGates = {
                    { "Checkpoint3", "ObbyTrigger" }, { "Checkpoint5", "EnterArena" }, { "Checkpoint6", "ObbyTrigger" }
                },
                { "BossTrigger" }
            },
            ["42"] = { -- Crystal academy
                CheckpointGates = {
                    { "Checkpoint3", "ObbyTrigger" }, { "Checkpoint6", "ObbyTrigger" }
                },
                { "BossTrigger" }
            },
            ["43"] = { -- Arcane tower
                { "WaveStarter", Regenerates = true }, { "WaveExit"}, { "BossDoorTrigger" }
            },
            ["39"] = { -- Celestial tower
                NoParent = {
                    { "LobbyTeleport", "Interaction" }, { "Boss_Gate", "Interactions", "Bounds" }
                }
            },
            ["38"] = { -- Infinite tower
                NoParent = {
                    { "LobbyTeleport", "Interaction" }, { "Boss_Gate", "Interactions", "Bounds" }
                }
            },
            ["53"] = {}, -- heavenly raid
            ["45"] = {}, -- kraken raid
            ["56"] = {
                { "BackTeleporter" }, { "Teleporter", AutoTouch = true }, { "BossDoorTrigger" }, { "MinibossExit" }
            },
            ["22"] = {} -- fallen throne
        }

        local CurrentDungeon = FindDungeonParts[tostring(ISV.CurrentDungeonID)]
        if not CurrentDungeon then
            
            return
        end

        for Index, Parts in CurrentDungeon do
            if type(Index) == "number" then
                table.insert(SV.DungeonPartList, Parts)
            else
                SV.DungeonPartList[Index] = {}
                for _, Part in Parts do
                    table.insert(SV.DungeonPartList[Index], Part)
                    task.wait()
                end
            end
            task.wait()
        end

        FindDungeonParts = nil

        for Index, Parts in SV.DungeonPartList do
            if type(Index) == "number" then
                task.spawn(function()
                    FindPart(nil, Parts)
                end)
            else
                for TableRef, Part in Parts do
                    task.spawn(function()
                        FindPart(tostring(Index), Part)
                    end)
                    task.wait()
                end
            end
            task.wait()
        end
        SV.DungeonPartList = nil
        if IsTower then
            task.spawn(function()
                if ISV.MissionId ~= 56 then
                    local WaveExitPart = nil
                    ConnectionTable["ConnectTower"] = Remotes:WaitForChild("Towers_UpdateChests", math.huge).OnClientEvent:Connect(function(RandomTable, KilledMobs, TotalMobs, Progress, RandomBoolean)
                        if WaveExitPart then
                            if KilledMobs == TotalMobs then
                                TeleportParts[WaveExitPart].DontTeleport = nil
                            else
                                TeleportParts[WaveExitPart].DontTeleport = true
                            end
                        end
                    end)
                    ConnectionTable["ConnectTowerPrint"] = Remotes:WaitForChild("Towers_Print").OnClientEvent:Connect(function(Text)
                        if WaveExitPart then
                            if string.find(Text, "false") then
                                DisconnectVariable("ConnectTower")
                                TeleportParts[WaveExitPart].DontTeleport = true
                                DisconnectVariable("ConnectTowerPrint")
                            end
                        end
                    end)
                    WaveExitPart = MissionObjects:WaitForChild("WaveExit", math.huge)
                end
            end)
        end
    end)
    if not Success then
        
    end
end

--SetGlobal("waiting for character")
--if not IsMainMenu then
--    local IsDead = false
--    local AlreadyCheckingLives = false
--    repeat
--        if IsDungeon then
--            task.spawn(function()
--                if AlreadyCheckingLives then
--                    return
--                end
--                AlreadyCheckingLives = true
--                if GetLives() == 0 then
--                    IsDead = true
--                    LoadingStep(true)
--                    RejoinLastDungeon(false)
--                    RestartDungeon(true)
--                    return
--                end
--                AlreadyCheckingLives = false
--            end)
--        elseif IsWorld then
--            RejoinLastDungeon(false)
--        end
--        task.wait(0.2)
--    until LocalPlayer.Character
--    if IsDead then
--        return
--    end
--    PlayerCharacter = LocalPlayer.Character
--    PlayerCollider = PlayerCharacter:WaitForChild("Collider")
--    PlayerRoot = PlayerCharacter:WaitForChild("HumanoidRootPart")
--    
--end

SetGlobal("prevent falling part")
if not IsMainMenu then
    task.spawn(function()
        CheckForCharacter()
        PlayerStandPart = Instance.new("Part")
        PlayerStandPart.Size = Vector3.new(3, 1, 3)
        PlayerStandPart.Parent = Workspace
        PlayerStandPart.Anchored = true
        PlayerStandPart.Transparency = 1
        PlayerStandPart.CanCollide = true
        PlayerStandPart.CanTouch = false
        PlayerStandPart.CanQuery = false
        StandPartHeight = GetPlayerSize() + PlayerStandPart.Size.Y/2.75
    end)
end

SetGlobal("spawning function")
if not IsMainMenu then
    SpawnFunctions = {
        CheckForAvoidMobs, MobScanner, CheckPlayerPing,
        ConnectMissionFinished, ConnectTowerFinished,
    }
    for _, SpawnFunction in SpawnFunctions do
        task.spawn(function()
            SpawnFunction()
        end)
    end
end

SetGlobal("getting class variables")
if not IsMainMenu then
    ISV.PlayerClass = WaitForAttribute(LocalPlayer, "Class")
    ISV.PlayerLevel = WaitForAttribute(LocalPlayer, "Level")
    ISV.PlayerPrestige = WaitForAttribute(LocalPlayer, "Prestige")
    PlayerProfile = ReturnChild(PlayerGui, "Profile")
    ProfileInventory = ReturnChild(PlayerProfile, "Inventory")
    SV.Parties = ReturnChild(ReplicatedStorage, "Parties")
end

SetGlobal("equipment pop up screen")
if IsTower and SV.CanRequire and EF.Hook and EF.NewClosure then
    local Success, Result = pcall(function()
        local DisplayItem = require(Client.Gui):Get("LootReceived")._DisplayItem
        CreateHookOnFunction(DisplayItem, true)
    end)
    if not Success then
        
    end
end

SetGlobal("connecting drops/chests")
do
    local CoinEvent = Remotes:WaitForChild("Drops_CoinEvent", math.huge)
    ConnectionTable["CollectDrops"] = CoinEvent.OnClientEvent:Connect(function(DropData)
        if SV.CollectDrops then
            CoinEvent:FireServer(DropData.id)
        else
            SV.Drops[DropData.id] = time()
        end
    end)
    local SpawnChest = Remotes:WaitForChild("Chests_SpawnChest", math.huge)
    local OpenChest = Remotes:WaitForChild("Chests_OpenChest", math.huge)
    ConnectionTable["ConnectChests"] = SpawnChest.OnClientEvent:Connect(function(ChestName, Location, GUID, d, e)
        if SV.CollectChests then
            OpenChest:FireServer(GUID)
        else
            table.insert(SV.Chests, GUID)
        end
    end)
end

SetGlobal("clean up script")
function CleanUpScript()
    for Index in Toggles do
        Toggles[tostring(Index)]:SetValue(false) -- safely turn off all toggles
    end
    for Index in Options do
        local StringIndex = tostring(Index)
        if string.find(StringIndex, "Dropdown") and not string.find(StringIndex, "UnloadTabDropdown") then
            Options[StringIndex]:SetValue({}) -- safely erase all dropdowns to turn attached functions off
        end
    end
    ISV.TeleportingToAnotherServer = true
    if not IsMainMenu and SV.CanRequire and EF.Hook and EF.CheckHook and EF.ClearHook and EF.NewClosure then
        local rPlayerRemover = require(SMobs:WaitForChild("PlayerRemover", math.huge))
        CreateHookOnFunction(rPlayerRemover.AddMobToSearch, false)
        for Index, Mob in Mobs:GetChildren() do
            rPlayerRemover:AddMobToSearch(Mob)
        end
        if SV.IsRanged then
            for Mob, MobData in ISV.MobTable do
                local MobCollider = Mob:WaitForChild("Collider", 5)
                if MobCollider then
                    MobCollider.Size = MobCollider.Size*2
                end
            end
        end
        rPlayerRemover = nil
        local rDrops = require(Drops)
        CreateHookOnFunction(rDrops.DropStarterpassExp, false)
        CreateHookOnFunction(rDrops.DropBattlepassExp, false)
        CreateHookOnFunction(rDrops.DropHealthOrb, false)
        CreateHookOnFunction(rDrops.SpawnCoinsLocal, false)
        rDrops = nil
        local rModelProvider = require(ModelProvider)
        CreateHookOnFunction(rModelProvider.GetModel, false)
        rModelProvider = nil
        local rEffects = require(Effects)
        CreateHookOnFunction(rEffects.RenderDamageNumber, false)
        CreateHookOnFunction(rEffects.MakeProjectile, false)
        CreateHookOnFunction(rEffects.DoEffect, false)
        CreateHookOnFunction(rEffects.PlayAt, false)
        CreateHookOnFunction(rEffects.EmitAt, false)
        rEffects = nil
        local rGui = require(Client.Gui)
        CreateHookOnFunction(rGui:Get("LootReceived")._DisplayItem, false)
        rGui = nil
        local rActions = require(Client.Actions)
        rActions:SetSkillDisabled("Primary", false)
        rActions:SetSkillDisabled("Skill1", false)
        rActions:SetSkillDisabled("Skill2", false)
        rActions:SetSkillDisabled("Skill3", false)
        rActions:SetSkillDisabled("Ultimate", false)
        CreateHookOnFunction(rActions.IsBusy, false)
        CreateHookOnFunction(rActions.Knockdown, false)
        rActions = nil
    end
    if DC then
        
        if IsDungeon then
            if SV.PlayerCamera and SV.PlayerCamera.Parent and PlayerRoot == SV.PlayerCamera.Parent then
                Workspace.CurrentCamera.CameraSubject = SV.PlayerCamera
            else
                Workspace.CurrentCamera.CameraSubject = (PlayerCharacter and PlayerCharacter:FindFirstChildOfClass("Humanoid")) or PlayerRoot
            end
        end
        if SV.WalkspeedManager then
            if ISV.IsMobile then
                SV.WalkspeedManager:SetBaseSpeed(28)
            else
                SV.WalkspeedManager:SetBaseSpeed(20)
            end
        end
        if ISV.RenderingScreen then
            ISV.RenderingScreen:Destroy()
            ISV.RenderingScreen = nil
            RunService:Set3dRenderingEnabled(true)
        end
        for Key in ISV do
            ISV[Key] = nil
        end
        for Key in EF do
            EF[Key] = nil
        end
        ISV = nil
        if PlayerRoot then
            PlayerRoot.CanCollide = true
        end
        for Part, PartData in TeleportParts do
            if Part and Part.Parent then
                Part.Size = PartData.OriginalSize
                Part.CanCollide = PartData.OriginalCollision
                Part.Position = PartData.OriginalLocation
            end
        end
        ScriptUnloaded, Remotes, SetGlobal,
        _ = nil
    end
    for Key in SV do
        SV[Key] = nil
    end
    for Index, Connection in ConnectionTable do
        Connection:Disconnect()
        ConnectionTable[Index] = nil
    end
    _G.Is_Script_Running = nil
    Library:Unload()

    if PlayerStandPart then
        PlayerStandPart:Destroy()
    end
    Library, SaveManager, MakeGuiElement, MakeErrorGui, ReturnService,
    GetShared, ReturnChild, WaitForAttribute, Workspace, Players,
    CoreGui, StarterGui, ReplicatedStorage, HttpService, VirtualUser,
    RunService, MarketplaceService, TeleportService, Shared, Battlepass,
    Charms, Chests, Drops, Effects, Health,
    Inventory, Items, Missions, SMobs, ModelProvider,
    Party, Pets, Quests, Shop, Skills,
    Teleport, Camera, Mobs, MissionObjects, LocalPlayer,
    PlayerName, PlayerID, PlayerGui, PlayerPing, PlayerProfile,
    ProfileInventory, PlayerCharacter, PlayerCollider, PlayerRoot, AddedDelay,
    Xdistance, Ydistance, TempStop, HoldForRealTime, RestartAtFloor,
    CurrentMob, IsMobCamera, KeepTier, SellItemCheck, OffsetMax,
    EquipInProgress, MobRotationSpeed, DelayPetAttacks, IsAliveMobs,
    TeleportMob, StuckDelay, DelayAttacks, IsBoss, EventOverride,
    CanTarget, PingMultiplie, StringPlaceID, IsWorld, IsMainMenu,
    IsDungeon, IsTower,  AvoidMobs, TeleportParts,
    FormatNumber, FormatDecimal, GetPercentage, SecondsToString, IsMissionOver,
    CheckForAvoidMobs, CheckPlayerPing, MobScanner, PingOnceUnlocked, PingForCap,
    GetDifficulty, GetLives, PartyLeaderCheck, ReplayDungeonLoop, RejoinLastDungeon,
    RestartDungeon, CollectChests, ClaimAllQuests, GetDungeonImage, ConnectMissionFinished,
    ConnectTowerFinished, GetRarity, EquipNewItemAdded, StatTotals, CollectTowerChests,
    CollectCoins, GetGuild, IsTowerEgg, SellItem, BuyFromLocalShop,
    BuyFromEggShop, OpenMenu, UpgradeToMax, ExpandPartSize, FindPart,
    ToggleMenu, DodgeCurrentAttack, TeleportToOrb, BuildAttackData, GetPlayerPet,
    GetPlayerClass, BuildShopValues, DisconnectVariable, TeleportStandPart, GetPlayerSize,
    PlayerStandPart, StandPartHeight, CreateHookOnFunction, Class, ClassSkills,
    PetSkills, ItemSellCheck, RecycleFromInventory = nil
end

do
    SetGlobal("checking platform")
    local GetPlatform = game:GetService("UserInputService"):GetPlatform()
    if GetPlatform ~= Enum.Platform.Android and GetPlatform ~= Enum.Platform.IOS then
        Library:Notify("You can press 0 (zero key) to open/close the menu", 10)
    else
        ISV.IsMobile = true
    end
end

SetGlobal("checking for old obsidian")
if not ISV.IsMobile and EF.HideGui and not SV.BadExecutor then
    local MainUI = EF.HideGui():WaitForChild("Obsidian", math.huge):WaitForChild("Main", math.huge)
    ConnectionTable["obsidianguihandler"] = UserInputService.InputBegan:Connect(function(Key)
        if Key.KeyCode == Enum.KeyCode.Zero then
            if MainUI.Visible then
                MainUI.Visible = false
            else
                MainUI.Visible = true
            end
        end
    end)
end

SetGlobal("toggle menu")
if Toggles.HideGuiToggle.Value and Library.Toggled then
    Library:Toggle()
end

SetGlobal("leaderboard info set up")
if IsWorld or IsDungeon then
    task.spawn(function()
        local Success, Result = pcall(function()
            local GetScore = Remotes:WaitForChild("LeaderboardHookup_GetScore", math.huge)
            if not SV.DungeonsTab then
                if GetLeaderboardScore("C_NP1", SV.TotalNightmareLabel, SV.DailyNightmareLabel, SV.StopAfterTotalNightmare, SV.StopAfterDailyNightmare) then
                    Library:Notify("Nightmare portal clear limit reached.", 999999999)
                    local TempStop = true
                    local CanTarget = false
                    if SV.NightmarePing then
                        PingForCap("Nightmare portal")
                    end
                end
            end -- for unloaded dungeons tan
            if not SV.GuildTab then
                local TotalPointData = GetScore:InvokeServer("G_POINTS22", 1)
                local DailyPointData = Remotes:WaitForChild("Profile_GetOwnCollectionValue", math.huge):InvokeServer("GuildPointsEarnedToday")
                local GuildPointTotal = TotalPointData[1]
                local GuildPointTotalLimit = tonumber(SV.StopAfterTotalPoints)
                local GuildPointDaily = DailyPointData
                local GuildPointDailyLimit = tonumber(SV.StopAfterDailyPoints)
                SV.TotalGuildPointLabel:SetText("Total Guild Points: " ..FormatNumber(GuildPointTotal))
                SV.DailyGuildPointLabel:SetText("Daily Guild Points: " ..FormatNumber(GuildPointDaily))
                if (GuildPointTotalLimit and (GuildPointTotal >= GuildPointTotalLimit)) or (GuildPointDailyLimit and (GuildPointDaily >= GuildPointDailyLimit)) then
                    Library:Notify("Guild point limit reached.", 999999999)
                    SetQuotaPause("guild",true)
                    if SV.GuildPing then
                        PingForCap("Guild Point")
                    end
                end
            end -- for unloaded guild tab
        end)
        if not Success then
            
        end
    end)
end

if GetLives() == 0 then
    RestartDungeon()
end

SetGlobal("end")
