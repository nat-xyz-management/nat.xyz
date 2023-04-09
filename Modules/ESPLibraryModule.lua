
local Players = game:GetService("Players")

local ESP = {
    Enabled = false,
    Settings = {
        RemoveOnDeath = false,
        MaxDistance = 0, 
        MaxBoxSize = Vector3.new(15, 15, 0), 
        DestroyOnRemove = false, 
        TeamColors = false, 
        TeamBased = false, 
        BoxTopOffset = Vector3.new(0, 1, 0), 
        
        Boxes = {
            Enabled = false,
            Color = Color3.fromRGB(244, 95, 209),
            Thickness = 0,
        },
        Names = {
            Distance = false,
            Health = false, 
            Enabled = false,
            Resize = true, 
            ResizeWeight = 0.05, 
            Color = Color3.fromRGB(244, 95, 209),
            Size = 0,
            Font = 1,
            Center = false,
            Outline = false,
        },
        Tracers = {
            Enabled = false,
            Thickness = 0,
            Color = Color3.fromRGB(244, 95, 209),
        }
    },
    Objects = {} 
}
local function Draw(Type, Properties) 
    local Object = Drawing.new(Type)
    
    for Property, Value in next, Properties or {} do 
        Object[Property] = Value
    end
    
    return Object
end
function ESP:GetScreenPosition(Position) 
    local Position = typeof(Position) ~= "CFrame" and Position or Position.Position 
    local ScreenPos, IsOnScreen = workspace.CurrentCamera:WorldToViewportPoint(Position)
    
    return Vector2.new(ScreenPos.X, ScreenPos.Y), IsOnScreen 
end
function ESP:GetDistance(Position) 
    local Magnitude = (workspace.CurrentCamera.CFrame.Position - Position).Magnitude
    local Metric = Magnitude * 0.28 
    
    return math.round(Metric)
end
function ESP:GetHealth(Model) 
    local Humanoid = Model:FindFirstChildOfClass("Humanoid")
    
    if Humanoid then
        return Humanoid.Health, Humanoid.MaxHealth, (Humanoid.Health / Humanoid.MaxHealth) * 100
    end
    
    return 100, 100, 100
end
function ESP:GetPlayerFromCharacter(Model) 
    return Players:GetPlayerFromCharacter(Model)
end
function ESP:GetTeam(Model) 
    local Player = ESP:GetPlayerFromCharacter(Model)
    
    return Player and Player.Team or nil
end
function ESP:GetPlayerTeam(Player) 
    return Player and Player.Team
end
function ESP:IsHostile(Model) 
    local Player = ESP:GetPlayerFromCharacter(Model)
    local MyTeam, TheirTeam = ESP:GetPlayerTeam(Players.LocalPlayer), ESP:GetPlayerTeam(Player)
    
    return (MyTeam ~= TheirTeam)
end
function ESP:GetTeamColor(Model) 
    local Team = Model:IsA("Model") and ESP:GetTeam(Model) or Model:IsA("Player") and ESP:GetPlayerTeam(Model) 
    
    return Team and Team.TeamColor.Color or Color3.new(1, 0, 0)
end
function ESP:GetOffset(Model)
    local Humanoid = Model:FindFirstChild("Humanoid")
    
    if Humanoid and Humanoid.RigType == Enum.HumanoidRigType.R6 then
        return CFrame.new(0, -1.75, 0)
    end
    
    return CFrame.new(0, 0, 0)
end
function ESP:CharacterAdded(Player) 
    return Player.CharacterAdded
end
function ESP:GetCharacter(Player) 
    return Player.Character
end
local function Validate(Child, Type, ClassName, ExpectedName)
    return not (Type or ClassName or ExpectedName) or (not ExpectedName or (ExpectedName and Child.Name == ExpectedName)) and (not ClassName or (ClassName and Child.ClassName == ClassName)) and (not Type or (Type and Child:IsA(Type))) 
end
function ESP:AddListener(Model, Validator, Settings)
    local Descendants = Settings.Descendants
    local Type, ClassName, ExpectedName = Settings.Type, Settings.ClassName, Settings.ExpectedName
    local ExtraSettings = Settings.Custom or {}
    local function ValidCheck(Child)
        if typeof(Validator) == "function" and Validator(Child) or not Validator then
            if Validate(Child, Type, ClassName, ExpectedName) then
                ESP.Object:New(Child, ExtraSettings)
            end
        end
    end
    local Connection = Descendants and Model.DescendantAdded or Model.ChildAdded
    local ObjectsToCheck = Descendants and Model.GetDescendants or Model.GetChildren
    
    Connection:Connect(function(Child)
        task.spawn(ValidCheck, Child)
    end)
    for i, Child in next, ObjectsToCheck(Model) do
        task.spawn(ValidCheck, Child)
    end
end
local Object = {}
Object.__index = Object
ESP.Object = Object
local function Clone(Table) 
    local Ret = {}
    for i,v in next, Table do
        if typeof(v) == "table" then
            v = Clone(v)
        end
        Ret[i] = v
    end
    return Ret
end
local function GetValue(Local, Global, Name) 
    local GlobalVal = Global[Name]
    local LocalVal = Local[Name]
    
    return LocalVal or ((LocalVal == nil or typeof(LocalVal) ~= "boolean") and GlobalVal)
end
function Object:New(Model, ExtraInfo) 
    if not Model then
        return
    end
    local Settings = ESP.Settings
    local NewObject = {
        Connections = {},
        RenderSettings = {
            Boxes = {},
            Tracers = {},
            Names = {},
        },
        GlobalSettings = Settings,
        Model = Model,
        Name = Model.Name,
        
        Objects = {
            Box = {
                Color = Settings.Boxes.Color,
                Thickness = Settings.Boxes.Thickness,
            },
        
            Name = {
                Color = Settings.Names.Color,
                Outline = Settings.Names.Outline,
                Text = Model.Name,
                Size = Settings.Names.Size,
                Font = Settings.Names.Font,
                Center = Settings.Names.Center,
            },
            
            Tracer = {
                Thickness = Settings.Tracers.Thickness,
                Color = Settings.Tracers.Color,
            }
        },
    }
    for Property, Value in next, ExtraInfo or {} do 
        
        if Property ~= "Settings" then
            NewObject[Property] = Value
        else
            for Name, Table in next, Value do
                for Property, Value in next, Table do
                    NewObject.RenderSettings[Name][Property] = Value
                end
            end
        end
    end
    NewObject = setmetatable(NewObject, Object)
    ESP.Objects[Model] = NewObject
    NewObject.Objects.Box = Draw("Quad", NewObject.Objects.Box)
    NewObject.Objects.Name = Draw("Text", NewObject.Objects.Name)
    NewObject.Objects.Tracer = Draw("Line", NewObject.Objects.Tracer)
    NewObject.Connections.Destroying = Model.Destroying:Connect(function() 
        NewObject:Destroy()
    end)
    NewObject.Connections.AncestryChanged = Model.AncestryChanged:Connect(function(Old, New) 
        if not Model:IsDescendantOf(workspace) and NewObject.RenderSettings.DestroyOnRemove or NewObject.GlobalSettings.DestroyOnRemove then
            NewObject:Destroy()
        end
    end)
    local Humanoid = Model:FindFirstChildOfClass("Humanoid")
    if Humanoid then
        NewObject.Connections.Died = Humanoid.Died:Connect(function()
            if Settings.RemoveOnDeath then
                NewObject:Destroy()
            end
        end)
    end
    NewObject.Connections.Removing = Model.AncestryChanged:Connect(function()
        if NewObject.RenderSettings.DestroyOnRemove or NewObject.GlobalSettings.DestroyOnRemove then
            NewObject:Destroy()
        end
    end)
    return NewObject
end
function Object:GetQuad() 
    local RenderSettings = self.RenderSettings
    local GlobalSettings = self.GlobalSettings
    local MaxSize = GetValue(RenderSettings, GlobalSettings, "MaxBoxSize")
    local BoxTopOffset = GetValue(RenderSettings, GlobalSettings, "BoxTopOffset")
    local Model = self.Model
    local Pivot = Model:GetPivot()
    local BoxPosition, Size = Model:GetBoundingBox()
    Pivot = Pivot * ESP:GetOffset(Model)
    Size = Size * Vector3.new(1, 1, 0)
    local X, Y = math.clamp(Size.X, 1, MaxSize.X) / 2, math.clamp(Size.Y, 1, MaxSize.Y) / 2
    local PivotVector, PivotOnScreen = (ESP:GetScreenPosition(Pivot.Position))
    local BoxTop = ESP:GetScreenPosition((Pivot * CFrame.new(0, Y, 0)).Position + (BoxTopOffset)) 
    local BoxBottom = ESP:GetScreenPosition((Pivot * CFrame.new(0, -Y, 0)).Position)
    local TopRight, TopRightOnScreen = ESP:GetScreenPosition((Pivot * CFrame.new(-X, Y, 0)).Position) 
    local TopLeft, TopLeftOnScreen = ESP:GetScreenPosition((Pivot * CFrame.new(X, Y, 0)).Position)
    local BottomLeft, BottomLeftOnScreen = ESP:GetScreenPosition((Pivot * CFrame.new(X, -Y, 0)).Position) 
    local BottomRight, BottomRightOnScreen = ESP:GetScreenPosition((Pivot * CFrame.new(-X, -Y, 0)).Position)
    if TopRightOnScreen or TopLeftOnScreen or BottomLeftOnScreen or BottomRightOnScreen then 
        local Positions = {
            BoxBottom = BoxBottom, 
            Pivot = PivotVector, 
            BoxTop = BoxTop, 
            TopRight = TopRight,    
            TopLeft = TopLeft,     
            BottomLeft = BottomLeft,  
            BottomRight = BottomRight, 
        }
    
        return Positions, true 
    end
    return false 
end
function Object:DrawBox(Quad) 
    local RenderSettings = self.RenderSettings
    local GlobalSettings = self.GlobalSettings
    local RenderBoxes = RenderSettings.Boxes
    local GlobalBoxes = GlobalSettings.Boxes
    local TeamColors = GetValue(RenderSettings, GlobalSettings, "TeamColors")
    local Thickness = GetValue(RenderBoxes, GlobalBoxes, "Thickness")
    local Color = GetValue(RenderBoxes, GlobalBoxes, "Color")
    local Properties = {
        Visible = true,
        Color = TeamColors and ESP:GetTeamColor(self.Model) or Color,
        Thickness = Thickness,
        PointA = Quad.TopRight,
        PointB = Quad.TopLeft,
        PointC = Quad.BottomLeft,
        PointD = Quad.BottomRight,
    }
    for Property, Value in next, Properties do
        self.Objects.Box[Property] = Value
    end
end
function Object:DrawName(Quad)
    local RenderSettings = self.RenderSettings
    local GlobalSettings = self.GlobalSettings
    local RenderNames = RenderSettings.Names
    local GlobalNames = GlobalSettings.Names
    local Settings = RenderSettings.Names or GlobalNames
    local ShowDistance = GetValue(RenderNames, GlobalNames, "Distance")
    local Size = GetValue(RenderNames, GlobalNames, "Size")
    local Resize = GetValue(RenderNames, GlobalNames, "Resize")
    local ResizeWeight = GetValue(RenderNames, GlobalNames, "ResizeWeight")
    local ShowHealth = GetValue(RenderNames, GlobalNames, "Health")
    local Font = GetValue(RenderNames, GlobalNames, "Font")
    local Center = GetValue(RenderNames, GlobalNames, "Center")
    local TeamColors = GetValue(RenderSettings, GlobalSettings, "TeamColors")
    local Color = GetValue(RenderNames, GlobalNames, "Color")
    local Outline = GetValue(RenderNames, GlobalNames, "Outline")
    local Distance = self.Model:GetPivot().Position
    local Properties = {
        Visible = true,
        Color = TeamColors and ESP:GetTeamColor(self.Model) or Color,
        Outline = Outline,
        Text = not (Size or ShowHealth) and self.Name or ("%s [%sm]%s"):format(self.Name, ShowDistance and tostring(ESP:GetDistance(Distance)) or "", ShowHealth and ("\n%d/%d (%d%%)"):format(ESP:GetHealth(self.Model)) or ""), 
        Size = not Resize and Size or Size - math.clamp((ESP:GetDistance(Distance) * ResizeWeight), 1, Size * 0.75),
        Font = Font,
        Center = Center,
        Position = Quad.BoxTop,
    }
    for Property, Value in next, Properties do
        self.Objects.Name[Property] = Value
    end
end
function Object:DrawTracer(Quad)
    local RenderSettings = self.RenderSettings
    local GlobalSettings = self.GlobalSettings
    local RenderTracers = RenderSettings.Tracers
    local GlobalTracers = GlobalSettings.Tracers
    local TeamColors = GetValue(RenderSettings, GlobalSettings, "TeamColors")
    local Color = GetValue(RenderTracers, GlobalTracers, "Color")
    local Thickness = GetValue(RenderTracers, GlobalTracers, "Thickness")
    local Properties = {
        Visible = true,
        Color = TeamColors and ESP:GetTeamColor(self.Model) or Color,
        Thickness = Thickness,
        From = workspace.CurrentCamera.ViewportSize * Vector2.new(.5, 1),
        To = Quad.BoxBottom,
    }
    for Property, Value in next, Properties do
        self.Objects.Tracer[Property] = Value
    end
end
function Object:Destroy()
    ESP.Objects[self.Model] = nil
    self:ClearDrawings()
    for i,v in next, self.Objects do
        v:Remove()
    end
    for i,v in next, self.Connections do 
        v:Disconnect()
    end
    table.clear(self.Objects)
end
function Object:ClearDrawings()
    for i,v in next, self.Objects do
        v.Visible = false
    end
end
function Object:Refresh()
    local Model = self.Model
    local Quad = self:GetQuad()
    local RenderSettings = self.RenderSettings
    local GlobalSettings = self.GlobalSettings
    local TeamBased = GetValue(RenderSettings, GlobalSettings, "TeamBased")
    local MaxDistance = GetValue(RenderSettings, GlobalSettings, "MaxDistance")
    local Boxes = GetValue(RenderSettings.Boxes, GlobalSettings.Boxes, "Enabled")
    local Names = GetValue(RenderSettings.Names, GlobalSettings.Names, "Enabled")
    local Tracers = GetValue(RenderSettings.Tracers, GlobalSettings.Tracers, "Enabled")
    if not ESP.Enabled then
        return self:ClearDrawings() 
    end
    if not Model.Parent or not Model:IsDescendantOf(workspace) then
        return self:ClearDrawings() 
    end
    if not Quad then 
        return self:ClearDrawings() 
    end
    if TeamBased and not ESP:IsHostile(Model) then
        return self:ClearDrawings()
    end
    if ESP:GetDistance(Model:GetPivot().Position) > MaxDistance then
        return self:ClearDrawings()
    end
    if Boxes then
        self:DrawBox(Quad)
    else
        self.Objects.Box.Visible = false
    end
    if Names then
        self:DrawName(Quad)
    else
        self.Objects.Name.Visible = false
    end
    if Tracers then
        self:DrawTracer(Quad)
    else
        self.Objects.Tracer.Visible = false
    end
end
game.RunService.Stepped:Connect(function()
    for i, Object in next, ESP.Objects do
        Object:Refresh()
    end
end)
return ESP
