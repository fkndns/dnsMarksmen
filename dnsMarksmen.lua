require "PremiumPrediction"
require "DamageLib"
require "2DGeometry"
require "MapPositionGOS"
 
 do
    
    local Version = 1.0
    
    local Files = {
        Lua = {
            Path = SCRIPT_PATH,
            Name = "dnsMarksmen.lua",
            Url = "https://raw.githubusercontent.com/fkndns/dnsCaitlyn/main/dnsMarksmen.lua"
        },
        Version = {
            Path = SCRIPT_PATH,
            Name = "dnsMarksmen.version",
            Url = "https://raw.githubusercontent.com/fkndns/dnsCaitlyn/main/dnsMarksmen.version"    -- check if Raw Adress correct pls.. after you have create the version file on Github
        }
    }
    
    local function AutoUpdate()
        
        local function DownloadFile(url, path, fileName)
            DownloadFileAsync(url, path .. fileName, function() end)
            while not FileExist(path .. fileName) do end
        end
        
        local function ReadFile(path, fileName)
            local file = io.open(path .. fileName, "r")
            local result = file:read()
            file:close()
            return result
        end
        
        DownloadFile(Files.Version.Url, Files.Version.Path, Files.Version.Name)
        local textPos = myHero.pos:To2D()
        local NewVersion = tonumber(ReadFile(Files.Version.Path, Files.Version.Name))
        if NewVersion > Version then
            DownloadFile(Files.Lua.Url, Files.Lua.Path, Files.Lua.Name)
            print("New dnsCaitlyn Version. Press 2x F6")     -- <-- you can change the massage for users here !!!!
        else
            print(Files.Version.Name .. ": No Updates Found")   --  <-- here too
        end
    
    end
    
    AutoUpdate()

end

local EnemyHeroes = {}
local AllyHeroes = {}
local EnemySpawnPos = nil
local AllySpawnPos = nil

local ItemHotKey = {[ITEM_1] = HK_ITEM_1, [ITEM_2] = HK_ITEM_2,[ITEM_3] = HK_ITEM_3, [ITEM_4] = HK_ITEM_4, [ITEM_5] = HK_ITEM_5, [ITEM_6] = HK_ITEM_6,}

local function GetInventorySlotItem(itemID)
    assert(type(itemID) == "number", "GetInventorySlotItem: wrong argument types (<number> expected)")
    for _, j in pairs({ITEM_1, ITEM_2, ITEM_3, ITEM_4, ITEM_5, ITEM_6}) do
        if myHero:GetItemData(j).itemID == itemID and myHero:GetSpellData(j).currentCd == 0 then return j end
    end
    return nil
end

local function IsNearEnemyTurret(pos, distance)
    --PrintChat("Checking Turrets")
    local turrets = _G.SDK.ObjectManager:GetTurrets(GetDistance(pos) + 1000)
    for i = 1, #turrets do
        local turret = turrets[i]
        if turret and GetDistance(turret.pos, pos) <= distance+915 and turret.team == 300-myHero.team then
            --PrintChat("turret")
            return turret
        end
    end
end

local function IsUnderEnemyTurret(pos)
    --PrintChat("Checking Turrets")
    local turrets = _G.SDK.ObjectManager:GetTurrets(GetDistance(pos) + 1000)
    for i = 1, #turrets do
        local turret = turrets[i]
        if turret and GetDistance(turret.pos, pos) <= 915 and turret.team == 300-myHero.team then
            --PrintChat("turret")
            return turret
        end
    end
end

function GetDifference(a,b)
    local Sa = a^2
    local Sb = b^2
    local Sdif = (a-b)^2
    return math.sqrt(Sdif)
end

function GetDistanceSqr(Pos1, Pos2)
    local Pos2 = Pos2 or myHero.pos
    local dx = Pos1.x - Pos2.x
    local dz = (Pos1.z or Pos1.y) - (Pos2.z or Pos2.y)
    return dx^2 + dz^2
end

function DrawTextOnHero(hero, text, color)
    local pos2D = hero.pos:To2D()
    local posX = pos2D.x - 50
    local posY = pos2D.y
    Draw.Text(text, 28, posX + 50, posY - 15, color)
end

function GetDistance(Pos1, Pos2)
    return math.sqrt(GetDistanceSqr(Pos1, Pos2))
end

function IsImmobile(unit)
    local MaxDuration = 0
    for i = 0, unit.buffCount do
        local buff = unit:GetBuff(i)
        if buff and buff.count > 0 then
            local BuffType = buff.type
            if BuffType == 5 or BuffType == 11 or BuffType == 21 or BuffType == 22 or BuffType == 24 or BuffType == 29 or buff.name == "recall" then
                local BuffDuration = buff.duration
                if BuffDuration > MaxDuration then
                    MaxDuration = BuffDuration
                end
            end
        end
    end
    return MaxDuration
end

function IsCleanse(unit)
    local MaxDuration = 0
    for i = 0, unit.buffCount do
        local buff = unit:GetBuff(i)
        if buff and buff.count > 0 then
            local BuffType = buff.type
            if BuffType == 5 or BuffType == 8 or BuffType == 9 or BuffType == 11 or BuffType == 21 or BuffType == 22 or BuffType == 24 or BuffType == 31 then
                local BuffDuration = buff.duration
                if BuffDuration > MaxDuration then
                    MaxDuration = BuffDuration
                end
            end
        end
    end
    return MaxDuration
end
			
function GetEnemyHeroes()
    for i = 1, Game.HeroCount() do
        local Hero = Game.Hero(i)
        if Hero.isEnemy then
            table.insert(EnemyHeroes, Hero)
            PrintChat(Hero.name)
        end
    end
    --PrintChat("Got Enemy Heroes")
end

function GetEnemyBase()
    for i = 1, Game.ObjectCount() do
        local object = Game.Object(i)
        
        if not object.isAlly and object.type == Obj_AI_SpawnPoint then 
            EnemySpawnPos = object
            break
        end
    end
end

function GetAllyBase()
    for i = 1, Game.ObjectCount() do
        local object = Game.Object(i)
        
        if object.isAlly and object.type == Obj_AI_SpawnPoint then 
            AllySpawnPos = object
            break
        end
    end
end

function GetAllyHeroes()
    for i = 1, Game.HeroCount() do
        local Hero = Game.Hero(i)
        if Hero.isAlly and Hero.charName ~= myHero.charName then
            table.insert(AllyHeroes, Hero)
            PrintChat(Hero.name)
        end
    end
    --PrintChat("Got Enemy Heroes")
end

function GetBuffStart(unit, buffname)
    for i = 0, unit.buffCount do
        local buff = unit:GetBuff(i)
        if buff.name == buffname and buff.count > 0 then 
            return buff.startTime
        end
    end
    return nil
end

function GetBuffExpire(unit, buffname)
    for i = 0, unit.buffCount do
        local buff = unit:GetBuff(i)
        if buff.name == buffname and buff.count > 0 then 
            return buff.expireTime
        end
    end
    return nil
end

function GetBuffDuration(unit, buffname)
    for i = 0, unit.buffCount do
        local buff = unit:GetBuff(i)
        if buff.name == buffname and buff.count > 0 then 
            return buff.duration
        end
    end
    return 0
end

function GetBuffStacks(unit, buffname)
    for i = 0, unit.buffCount do
        local buff = unit:GetBuff(i)
        if buff.name == buffname and buff.count > 0 then 
            return buff.count
        end
    end
    return 0
end

local function GetWaypoints(unit) -- get unit's waypoints
    local waypoints = {}
    local pathData = unit.pathing
    table.insert(waypoints, unit.pos)
    local PathStart = pathData.pathIndex
    local PathEnd = pathData.pathCount
    if PathStart and PathEnd and PathStart >= 0 and PathEnd <= 20 and pathData.hasMovePath then
        for i = pathData.pathIndex, pathData.pathCount do
            table.insert(waypoints, unit:GetPath(i))
        end
    end
    return waypoints
end

local function GetUnitPositionNext(unit)
    local waypoints = GetWaypoints(unit)
    if #waypoints == 1 then
        return nil -- we have only 1 waypoint which means that unit is not moving, return his position
    end
    return waypoints[2] -- all segments have been checked, so the final result is the last waypoint
end

local function GetUnitPositionAfterTime(unit, time)
    local waypoints = GetWaypoints(unit)
    if #waypoints == 1 then
        return unit.pos -- we have only 1 waypoint which means that unit is not moving, return his position
    end
    local max = unit.ms * time -- calculate arrival distance
    for i = 1, #waypoints - 1 do
        local a, b = waypoints[i], waypoints[i + 1]
        local dist = GetDistance(a, b)
        if dist >= max then
            return Vector(a):Extended(b, dist) -- distance of segment is bigger or equal to maximum distance, so the result is point A extended by point B over calculated distance
        end
        max = max - dist -- reduce maximum distance and check next segments
    end
    return waypoints[#waypoints] -- all segments have been checked, so the final result is the last waypoint
end

function GetTarget(range)
    if _G.SDK then
        return _G.SDK.TargetSelector:GetTarget(range, _G.SDK.DAMAGE_TYPE_MAGICAL);
    else
        return _G.GOS:GetTarget(range,"AD")
    end
end

function GotBuff(unit, buffname)
    for i = 0, unit.buffCount do
        local buff = unit:GetBuff(i)
        --PrintChat(buff.name)
        if buff.name == buffname and buff.count > 0 then 
            return buff.count
        end
    end
    return 0
end

function BuffActive(unit, buffname)
    for i = 0, unit.buffCount do
        local buff = unit:GetBuff(i)
        if buff.name == buffname and buff.count > 0 then 
            return true
        end
    end
    return false
end

function IsReady(spell)
    return myHero:GetSpellData(spell).currentCd == 0 and myHero:GetSpellData(spell).level > 0 and myHero:GetSpellData(spell).mana <= myHero.mana and Game.CanUseSpell(spell) == 0
end

function Mode()
    if _G.SDK then
        if _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_COMBO] then
            return "Combo"
        elseif _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_HARASS] or Orbwalker.Key.Harass:Value() then
            return "Harass"
        elseif _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_LANECLEAR] or Orbwalker.Key.Clear:Value() then
            return "LaneClear"
        elseif _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_LASTHIT] or Orbwalker.Key.LastHit:Value() then
            return "LastHit"
        elseif _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_FLEE] then
            return "Flee"
        end
    else
        return GOS.GetMode()
    end
end

function GetItemSlot(unit, id)
    for i = ITEM_1, ITEM_7 do
        if unit:GetItemData(i).itemID == id then
            return i
        end
    end
    return 0
end

function IsFacing(unit)
    local V = Vector((unit.pos - myHero.pos))
    local D = Vector(unit.dir)
    local Angle = 180 - math.deg(math.acos(V*D/(V:Len()*D:Len())))
    if math.abs(Angle) < 80 then 
        return true  
    end
    return false
end

function IsMyHeroFacing(unit)
    local V = Vector((myHero.pos - unit.pos))
    local D = Vector(myHero.dir)
    local Angle = 180 - math.deg(math.acos(V*D/(V:Len()*D:Len())))
    if math.abs(Angle) < 80 then 
        return true  
    end
    return false
end

function SetMovement(bool)
    if _G.PremiumOrbwalker then
        _G.PremiumOrbwalker:SetAttack(bool)
        _G.PremiumOrbwalker:SetMovement(bool)       
    elseif _G.SDK then
        _G.SDK.Orbwalker:SetMovement(bool)
        _G.SDK.Orbwalker:SetAttack(bool)
    end
end


local function CheckHPPred(unit, SpellSpeed)
     local speed = SpellSpeed
     local range = myHero.pos:DistanceTo(unit.pos)
     local time = range / speed
     if _G.SDK and _G.SDK.Orbwalker then
         return _G.SDK.HealthPrediction:GetPrediction(unit, time)
     elseif _G.PremiumOrbwalker then
         return _G.PremiumOrbwalker:GetHealthPrediction(unit, time)
    end
end

function EnableMovement()
    SetMovement(true)
end

local function IsValid(unit)
    if (unit and unit.valid and unit.isTargetable and unit.alive and unit.visible and unit.networkID and unit.pathing and unit.health > 0) then
        return true;
    end
    return false;
end

local function ClosestPointOnLineSegment(p, p1, p2)
    local px = p.x
    local pz = p.z
    local ax = p1.x
    local az = p1.z
    local bx = p2.x
    local bz = p2.z
    local bxax = bx - ax
    local bzaz = bz - az
    local t = ((px - ax) * bxax + (pz - az) * bzaz) / (bxax * bxax + bzaz * bzaz)
    if (t < 0) then
        return p1, false
    end
    if (t > 1) then
        return p2, false
    end
    return {x = ax + t * bxax, z = az + t * bzaz}, true
end

local function GetWDmg(unit)
	local Wdmg = getdmg("W", unit, myHero, 1)
	local W2dmg = getdmg("W", unit, myHero, 2)	
	local buff = GetBuffData(unit, "kaisapassivemarker")
	if buff and buff.count == 4 then
		return (Wdmg+W2dmg)		
	else		
		return Wdmg 
	end 
end

local function ValidTarget(unit, range)
    if (unit and unit.valid and unit.isTargetable and unit.alive and unit.visible and unit.networkID and unit.pathing and unit.health > 0) then
        if range then
            if GetDistance(unit.pos) <= range then
                return true;
            end
        else
            return true
        end
    end
    return false;
end

class "Manager"

function Manager:__init()
	if myHero.charName == "Kaisa" then
		DelayAction(function () self:LoadKaisa() end, 1.05)
	end
	if myHero.charName == "Caitlyn" then
		DelayAction(function() self:LoadCaitlyn() end, 1.05)
	end
	if myHero.charName == "Tristana" then
		DelayAction(function() self:LoadTristana() end, 1.05)
	end
end

function Manager:LoadKaisa()
	Kaisa:Spells()
	Kaisa:Menu()
	Callback.Add("Tick", function() Kaisa:Tick() end)
	Callback.Add("Draw", function() Kaisa:Draws() end)
	if _G.SDK then
        _G.SDK.Orbwalker:OnPreAttack(function(...) Kaisa:OnPreAttack(...) end)
        _G.SDK.Orbwalker:OnPostAttackTick(function(...) Kaisa:OnPostAttackTick(...) end)
        _G.SDK.Orbwalker:OnPostAttack(function(...) Kaisa:OnPostAttack(...) end)
    end
end

function Manager:LoadCaitlyn()
    Caitlyn:Spells()
    Caitlyn:Menu()
    --
    --GetEnemyHeroes()
    Callback.Add("Tick", function() Caitlyn:Tick() end)
    Callback.Add("Draw", function() Caitlyn:Draw() end)
    if _G.SDK then
        _G.SDK.Orbwalker:OnPreAttack(function(...) Caitlyn:OnPreAttack(...) end)
        _G.SDK.Orbwalker:OnPostAttackTick(function(...) Caitlyn:OnPostAttackTick(...) end)
        _G.SDK.Orbwalker:OnPostAttack(function(...) Caitlyn:OnPostAttack(...) end)
    end
end

function Manager:LoadTristana()
    Tristana:Spells()
    Tristana:Menu()
    --
    --GetEnemyHeroes()
    Callback.Add("Tick", function() Tristana:Tick() end)
    Callback.Add("Draw", function() Tristana:Draw() end)
    if _G.SDK then
        _G.SDK.Orbwalker:OnPreAttack(function(...) Tristana:OnPreAttack(...) end)
        _G.SDK.Orbwalker:OnPostAttackTick(function(...) Tristana:OnPostAttackTick(...) end)
        _G.SDK.Orbwalker:OnPostAttack(function(...) Tristana:OnPostAttack(...) end)
    end
end

class "Kaisa"

local EnemyLoaded = false
local MinionsAround = count



function Kaisa:Menu()
-- menu
	self.Menu = MenuElement({type = MENU, id = "Kaisa", name = "dnsKai'Sa"})
-- q spell
	self.Menu:MenuElement({id = "QSpell", name = "Q", type = MENU})
	self.Menu.QSpell:MenuElement({id = "QCombo", name = "Combo", value = true})
	self.Menu.QSpell:MenuElement({id = "QSpace1", name = "", type = SPACE})
	self.Menu.QSpell:MenuElement({id = "QHarass", name = "Harass", value = false})
	self.Menu.QSpell:MenuElement({id = "QHarassMana", name = "Harass Mana %", value = 40, min = 0, max = 100, identifier = "%"})
	self.Menu.QSpell:MenuElement({id = "QSpace2", name = "", type = SPACE})
	self.Menu.QSpell:MenuElement({id = "QLaneClear", name = "LaneClear", value = true})
	self.Menu.QSpell:MenuElement({id = "QLaneClearCount", name = "LaneClear when Q can hit atleast", value = 4, min = 1, max = 9, step = 1})
	self.Menu.QSpell:MenuElement({id = "QLaneClearMana", name = "LaneClear Mana %", value = 60, min = 0, max = 100, identifier = "%"})
	self.Menu.QSpell:MenuElement({id = "QSpace3", name = "", type = SPACE})
-- w spell
	self.Menu:MenuElement({id = "WSpell", name = "W", type = MENU})
	self.Menu.WSpell:MenuElement({id = "WCombo", name = "Combo", value = true})
	self.Menu.WSpell:MenuElement({id = "WSpace1", name = "", type = SPACE})
	self.Menu.WSpell:MenuElement({id = "WHarass", name = "Harass", value = false})
	self.Menu.WSpell:MenuElement({id = "WHarassMana", name = "Harass Mana %", value = 40, min = 0, max = 100, identifier = "%"})
	self.Menu.WSpell:MenuElement({id = "WSpace2", name = "", type = SPACE})
	self.Menu.WSpell:MenuElement({id = "WLastHit", name = "LastHit Cannon when out of AA Range", value = true})
	self.Menu.WSpell:MenuElement({id = "WSpace3", name = "", type = SPACE})
	self.Menu.WSpell:MenuElement({id = "WKS", name = "KS", value = true})
	self.Menu.WSpell:MenuElement({id = "WSpace4", name = "", type = SPACE})
-- e spell 
	self.Menu:MenuElement({id = "ESpell", name = "E", type = MENU})
	self.Menu.ESpell:MenuElement({id = "ECombo", name = "Combo", value = true})
	self.Menu.ESpell:MenuElement({id = "ESpace1", name = "", type = SPACE})
	self.Menu.ESpell:MenuElement({id = "EFlee", name = "Flee", value = true})
	self.Menu.ESpell:MenuElement({id = "ESpace2", name = "", type = SPACE})
	self.Menu.ESpell:MenuElement({id = "EPeel", name = "Autopeel Meeledivers", value = true})
	self.Menu.ESpell:MenuElement({id = "ESpace3", name = "", type = SPACE})
-- r spell
	self.Menu:MenuElement({id = "RSpell", name = "R", type = MENU})
	self.Menu.RSpell:MenuElement({id = "Sorry", name = "R is an automatical thingy", type = SPACE})
	self.Menu.RSpell:MenuElement({id = "Sorry2", name = "I'm really sorry", type = SPACE})
-- draws
	self.Menu:MenuElement({id = "Draws", name = "Draws", type = MENU})
	self.Menu.Draws:MenuElement({id = "EnableDraws", name = "Enable", value = false})
	self.Menu.Draws:MenuElement({id = "DrawsSpace1", name = "", type = SPACE})
	self.Menu.Draws:MenuElement({id = "QDraw", name = "Q Range", value = false})
	self.Menu.Draws:MenuElement({id = "WDraw", name = "W Range", value = false})
	self.Menu.Draws:MenuElement({id = "RDraw", name = "R Range", value = false})
-- ranged helper
	self.Menu:MenuElement({id = "rangedhelper", name = "Use RangedHelper", value = false})
end

function Kaisa:Draws()
	if self.Menu.Draws.EnableDraws:Value() then
        if self.Menu.Draws.QDraw:Value() then
            Draw.Circle(myHero.pos, 600 + myHero.boundingRadius, 1, Draw.Color(255, 255, 0, 0))
        end
		if self.Menu.Draws.WDraw:Value() then
			Draw.Circle(myHero.pos, 3000, 1, Draw.Color(255, 0, 255, 0))
		end
		if self.Menu.Draws.RDraw:Value() and myHero:GetSpellData(_R).level <= 1 then
			Draw.Circle(myHero.pos, 1500, 1, Draw.Color(255, 255, 255, 255))
		end
		if self.Menu.Draws.RDraw:Value() and myHero:GetSpellData(_R).level == 2 then
			Draw.Circle(myHero.pos, 2250, 1, Draw.Color(255, 255, 255, 255))
		end
		if self.Menu.Draws.RDraw:Value() and myHero:GetSpellData(_R).level == 3 then
			Draw.Circle(myHero.pos, 3000, 1, Draw.Color(255, 255, 255, 255))
		end
    end
end

function Kaisa:CastingChecks()
	if CastingW or CastingE or CastingR then
		return false
	else 
		return true
	end
end

function Kaisa:Spells()
	WSpellData = {speed = 1750, range = 1400, delay = 0.4, radius = 60, collision = {"minion"}, type = "linear"}
end

function Kaisa:Tick()
    if _G.JustEvade and _G.JustEvade:Evading() or (_G.ExtLibEvade and _G.ExtLibEvade.Evading) or Game.IsChatOpen() or myHero.dead then return end
    target = GetTarget(1400)
	if target and ValidTarget(target) then
        --PrintChat(target.pos:To2D())
        --PrintChat(mousePos:To2D())
        GaleMouseSpot = self:RangedHelper(target)
    else
        _G.SDK.Orbwalker.ForceMovement = nil
    end
    AARange = _G.SDK.Data:GetAutoAttackRange(myHero)
	CastingQ = myHero.activeSpell.name == "KaisaQ"
	CastingW = myHero.activeSpell.name == "KaisaW"
	CastingE = myHero.activeSpell.name == "KaisaE"
	CastingR = myHero.activeSpell.name == "KaisaR"
    self:Logic()
	self:Auto()
	self:LastHit()
	self:LaneClear()
    if EnemyLoaded == false then
        local CountEnemy = 0
        for i, enemy in pairs(EnemyHeroes) do
            CountEnemy = CountEnemy + 1
        end
        if CountEnemy < 1 then
            GetEnemyHeroes()
        else
            EnemyLoaded = true
            PrintChat("Enemy Loaded")
        end
    end
end 

function Kaisa:CanUse(spell, mode)
	local ManaPercent = myHero.mana / myHero.maxMana * 100
	if mode == nil then
		mode = Mode()
	end
	if spell == _Q then
		if mode == "Combo" and IsReady(spell) and self.Menu.QSpell.QCombo:Value() then
			return true
		end
		if mode == "Harass" and IsReady(spell) and self.Menu.QSpell.QHarass:Value() and ManaPercent > self.Menu.QSpell.QHarassMana:Value() then
			return true
		end
		if mode == "LaneClear" and IsReady(spell) and self.Menu.QSpell.QLaneClear:Value() and ManaPercent > self.Menu.QSpell.QLaneClearMana:Value() then
			return true
		end
	elseif spell == _W then
		if mode == "Combo" and IsReady(spell) and self.Menu.WSpell.WCombo:Value() then
			return true
		end
		if mode == "Harass" and IsReady(spell) and self.Menu.WSpell.WHarass:Value() and ManaPercent > self.Menu.WSpell.WHarassMana:Value() then
			return true
		end
		if mode == "LastHit" and IsReady(spell) and self.Menu.WSpell.WLastHit:Value() then
			return true
		end
		if mode == "KS" and IsReady(spell) and self.Menu.WSpell.WKS:Value() then
			return true
		end
	elseif spell == _E then
		if mode == "Combo" and IsReady(spell) and self.Menu.ESpell.ECombo:Value() then
			return true
		end
		if mode == "Flee" and IsReady(spell) and self.Menu.ESpell.EFlee:Value() then
			return true
		end
		if mode == "ChargePeel" and IsReady(spell) and self.Menu.ESpell.EPeel:Value() then
			return true
		end
	end
	return false
end

function Kaisa:Auto()
	-- enemy loop
	for i, enemy in pairs(EnemyHeroes) do
		--w ks
		local WRange = 1400 + myHero.boundingRadius + enemy.boundingRadius 
		if ValidTarget(enemy, WRange) and self:CanUse(_W, "KS") and self:CastingChecks() and not _G.SDK.Attack:IsActive() then
			local WDamage = GetWDmg(enemy)
			local pred = _G.PremiumPrediction:GetPrediction(myHero, enemy, WSpellData)
			if pred.CastPos and pred.HitChance >= 0.7 and enemy.health <= WDamage then
				Control.CastSpell(HK_W, pred.CastPos)
			end
		end
		-- e peel
		local Bedrohungsreichweite = 250 + myHero.boundingRadius + enemy.boundingRadius
		if ValidTarget(enemy, Bedrohungsreichweite) and IsFacing(enemy) and not IsMyHeroFacing(enemy) and self:CanUse(_E, "ChargePeel") and self:CastingChecks() and not _G.SDK.Attack:IsActive() and enemy.activeSpell.target == myHero.handle then
			Control.CastSpell(HK_E)
		end
	end
end

function Kaisa:Logic()
	if target == nil then
		return
	end
	local QRange = 600 + myHero.boundingRadius + target.boundingRadius
	local WRange = 1400 + myHero.boundingRadius + target.boundingRadius
	local ERange = 525 + 300 + myHero.boundingRadius + target.boundingRadius
	
	
	if Mode() == "Combo" and target then
		if ValidTarget(target, QRange) and self:CanUse(_Q, "Combo") and self:CastingChecks() and not _G.SDK.Attack:IsActive() then
				Control.CastSpell(HK_Q)
		end
		if ValidTarget(target, WRange) and self:CanUse(_W, "Combo") and self:CastingChecks() and not _G.SDK.Attack:IsActive() then
			local pred = _G.PremiumPrediction:GetPrediction(myHero, target, WSpellData)
			if pred.CastPos and pred.HitChance >= 0.7 and GetBuffStacks(target, "kaisapassivemarker") >= 3 then 
				Control.CastSpell(HK_W, pred.CastPos)
			end
		end
		if ValidTarget(target, ERange) and self:CanUse(_E, "Combo") and self:CastingChecks() and not _G.SDK.Attack:IsActive() then
			if GetDistance(target.pos) > 550 + myHero.boundingRadius + target.boundingRadius and IsMyHeroFacing(target) then
				Control.CastSpell(HK_E)
			end
		end
	elseif Mode() == "Harass" and target then
		if ValidTarget(target, QRange) and self:CanUse(_Q, "Harass") and self:CastingChecks() and not _G.SDK.Attack:IsActive() and not IsUnderEnemyTurret(myHero.pos) then
				Control.CastSpell(HK_Q)
		end
		if ValidTarget(target, WRange) and self:CanUse(_W, "Harass") and self:CastingChecks() and not _G.SDK.Attack:IsActive() and not IsUnderEnemyTurret(myHero.pos) then
			local pred = _G.PremiumPrediction:GetPrediction(myHero, target, WSpellData)
			if pred.CastPos and pred.HitChance > 0.5 then 
				Control.CastSpell(HK_W, pred.CastPos)
			end
		end
	elseif Mode() == "Flee" and target then
		if ValidTarget(target, ERange) and self:CanUse(_E, "Flee") and self:CastingChecks() and not _G.SDK.Attack:IsActive() and not IsMyHeroFacing(enemy) then
				Control.CastSpell(HK_E)
		end
	end	
end

function Kaisa:LastHit()
	if self:CanUse(_W, "LastHit") and (Mode == "LastHit" or Mode() == "LaneClear" or Mode() == "Harass") then
		local minions = _G.SDK.ObjectManager:GetEnemyMinions(1400)
		for i = 1, #minions do 
			local minion = minions[i]
			if GetDistance(minion.pos) > 525 + myHero.boundingRadius and ValidTarget(minion, 1400 + myHero.boundingRadius) and (minion.charName == "SRU_ChaosMinionSiege" or minion.charName == "SRU_OrderMinionSiege") then
				local WDamage = GetWDmg(minion)
				if WDamage >= minion.health and self:CastingChecks() and not _G.SDK.Attack:IsActive() then 
					local pred = _G.PremiumPrediction:GetPrediction(myHero, minion, WSpellData)
					if pred.CastPos and pred.HitChance >= 0.20 then
						Control.CastSpell(HK_W, pred.CastPos)
					end
				end
			end
		end
	end
end

function Kaisa:LaneClear()
	local count = 0 
	if self:CanUse(_Q, "LaneClear") and Mode() == "LaneClear" then
		local minions = _G.SDK.ObjectManager:GetEnemyMinions(600)
		for i = 1, #minions do 
			local minion = minions[i]
			if ValidTarget(minion, 600 + myHero.boundingRadius + minion.boundingRadius) then
				count = count + 1
			end
			if MinionsAround >= self.Menu.QSpell.QLaneClearCount:Value() then
				Control.CastSpell(HK_Q)
			end
		end
	end
	MinionsAround = count
end

function Kaisa:RangedHelper(unit)
	local AARange = 525 + target.boundingRadius
    local EAARangel = _G.SDK.Data:GetAutoAttackRange(unit)
    local MoveSpot = nil
    local RangeDif = AARange - EAARangel
    local ExtraRangeDist = RangeDif
    local ExtraRangeChaseDist = RangeDif - 100

    local ScanDirection = Vector((myHero.pos-mousePos):Normalized())
    local ScanDistance = GetDistance(myHero.pos, unit.pos) * 0.8
    local ScanSpot = myHero.pos - ScanDirection * ScanDistance
	

    local MouseDirection = Vector((unit.pos-ScanSpot):Normalized())
    local MouseSpotDistance = EAARangel + ExtraRangeDist
    if not IsFacing(unit) then
        MouseSpotDistance = EAARangel + ExtraRangeChaseDist
    end
    if MouseSpotDistance > AARange then
        MouseSpotDistance = AARange
    end

    local MouseSpot = unit.pos - MouseDirection * (MouseSpotDistance)
	local MouseDistance = GetDistance(unit.pos, mousePos)
    local GaleMouseSpotDirection = Vector((myHero.pos-MouseSpot):Normalized())
    local GalemouseSpotDistance = GetDistance(myHero.pos, MouseSpot)
    if GalemouseSpotDistance > 300 then
        GalemouseSpotDistance = 300
    end
    local GaleMouseSpoty = myHero.pos - GaleMouseSpotDirection * GalemouseSpotDistance
    MoveSpot = MouseSpot

    if MoveSpot then
        if GetDistance(myHero.pos, MoveSpot) < 50 or IsUnderEnemyTurret(MoveSpot) then
            _G.SDK.Orbwalker.ForceMovement = nil
        elseif self.Menu.rangedhelper:Value() and GetDistance(myHero.pos, unit.pos) <= AARange-50 and (Mode() == "Combo" or Mode() == "Harass") and self:CastingChecks() and MouseDistance < 750 then
            _G.SDK.Orbwalker.ForceMovement = MoveSpot
        else
            _G.SDK.Orbwalker.ForceMovement = nil
        end
    end
    return GaleMouseSpoty
end

function Kaisa:OnPostAttack(args)
end

function Kaisa:OnPostAttackTick(args)
end

function Kaisa:OnPreAttack(args)
end


function OnLoad()
    Manager()
end

class "Caitlyn"

local EnemyLoaded = false
local EnemiesAround = count
local MinionsLaneClear = laneclearcount
local RAround = rcount
function Caitlyn:Menu()
    self.Menu = MenuElement({type = MENU, id = "Caitlyn", name = "dnsCaitlyn"})
    self.Menu:MenuElement({id = "QSpell", name = "Q", type = MENU})
	self.Menu.QSpell:MenuElement({id = "QCombo", name = "Combo", value = true})
	self.Menu.QSpell:MenuElement({id = "QComboHitChance", name = "HitChance", value = 0.5, min = 0.1, max = 1.0, step = 0.1})
	self.Menu.QSpell:MenuElement({id = "QHarass", name = "Harass", value = false})
	self.Menu.QSpell:MenuElement({id = "QHarassHitChance", name = "HitChance", value = 0.5, min = 0.1, max = 1.0, step = 0.1})
	self.Menu.QSpell:MenuElement({id = "QHarassMana", name = "Mana %", value = 40, min = 0, max = 100, identifier = "%"})
	self.Menu.QSpell:MenuElement({id = "QLaneClear", name = "LaneClear", value = false})
	self.Menu.QSpell:MenuElement({id = "QLaneClearCount", name = "if HitCount is atleast", value = 5, min = 1, max = 9, step = 1})
	self.Menu.QSpell:MenuElement({id = "QLaneClearMana", name = "Mana %", value = 60, min = 0, max = 100, identifier = "%"})
	self.Menu.QSpell:MenuElement({id = "QLastHit", name = "LastHit", value = true})
	self.Menu.QSpell:MenuElement({id = "QKS", name = "KS", value = true})
	self.Menu:MenuElement({id = "WSpell", name = "W", type = MENU})
	self.Menu.WSpell:MenuElement({id = "WImmo", name = "Auto W immobile Targets", value = true})
	self.Menu:MenuElement({id = "ESpell", name = "E", type = MENU})
	self.Menu.ESpell:MenuElement({id = "ECombo", name = "Combo", value = true})
	self.Menu.ESpell:MenuElement({id = "EComboHitChance", name = "HitChance", value = 1, min = 0.1, max = 1.0, step = 0.1})
	self.Menu.ESpell:MenuElement({id = "EHarass", name = "Harass", value = false})
	self.Menu.ESpell:MenuElement({id = "EHarassHitChance", name = "HitChance", value = 1, min = 0.1, max = 1.0, step = 0.1})
	self.Menu.ESpell:MenuElement({id = "EHarassMana", name = "Mana %", value = 60, min = 0, max = 100, identifier = "%"})
	self.Menu.ESpell:MenuElement({id = "EGap", name = "Peel Meele Champs", value = true})
	self.Menu:MenuElement({id = "RSpell", name = "R", type = MENU})
	self.Menu.RSpell:MenuElement({id = "RKS", name = "KS", value = true})
	self.Menu:MenuElement({id = "MakeDraw", name = "Nubody nees dravvs", type = MENU})
	self.Menu.MakeDraw:MenuElement({id = "UseDraws", name = "U wanna hav dravvs?", value = false})
	self.Menu.MakeDraw:MenuElement({id = "QDraws", name = "U wanna Q-Range dravvs?", value = false})
	self.Menu.MakeDraw:MenuElement({id = "RDraws", name = "U wanna R-Range dravvs?", value = false})
	self.Menu:MenuElement({id = "rangedhelper", name = "Use RangedHelper", value = false})
end

function Caitlyn:Spells()
    QSpellData = {speed = 2200, range = 1300, delay = 0.625, radius = 120, collision = {}, type = "linear"}
	WSpellData = {speed = math.huge, range = 800, delay = 0.25, radius = 60, collision = {}, type = "circular"}
	ESpellData = {speed = 1600, range = 750, delay = 0.15, radius = 100, collision = {minion}, type = "linear"}
end

function Caitlyn:CastingChecks()
	if not CastingQ or CastingW or CastingR then
		return true
	else 
		return false
	end
end

function Caitlyn:Draw()
    if self.Menu.MakeDraw.UseDraws:Value() then
        if self.Menu.MakeDraw.QDraws:Value() then
            Draw.Circle(myHero.pos, 1300, 1, Draw.Color(237, 255, 255, 255))
        end
		if self.Menu.MakeDraw.RDraws:Value() then
			Draw.Circle(myHero.pos, 3500, 1, Draw.Color(237, 255, 255, 255))
		end
    end
end

function Caitlyn:Tick()
    if _G.JustEvade and _G.JustEvade:Evading() or (_G.ExtLibEvade and _G.ExtLibEvade.Evading) or Game.IsChatOpen() or myHero.dead then return end
    target = GetTarget(1400)
	if target and ValidTarget(target) then
        --PrintChat(target.pos:To2D())
        --PrintChat(mousePos:To2D())
        GaleMouseSpot = self:RangedHelper(target)
    else
        _G.SDK.Orbwalker.ForceMovement = nil
    end
	CastingQ = myHero.activeSpell.name == "CaitlynPiltoverPeacemaker"
	CastingW = myHero.activeSpell.name == "CaitlynYordleTrap"
	CastingE = myHero.activeSpell.name == "CaitlynEntrapment"
	CastingR = myHero.activeSpell.name == "CaitlynAceintheHole"
    self:Logic()
	self:KS()
	self:LastHit()
	self:LaneClear()
    if EnemyLoaded == false then
        local CountEnemy = 0
        for i, enemy in pairs(EnemyHeroes) do
            CountEnemy = CountEnemy + 1
        end
        if CountEnemy < 1 then
            GetEnemyHeroes()
        else
            EnemyLoaded = true
            PrintChat("Enemy Loaded")
        end
	end
end

function Caitlyn:KS()

	local rtarget = nil
	local count = 0
	for i, enemy in pairs(EnemyHeroes) do
	local QRange = 1300 + enemy.boundingRadius
	local RRange = 3500 + enemy.boundingRadius 
	local EPeelRange = 250 + enemy.boundingRadius 
	local WRange = 800 + enemy.boundingRadius 
		if GetDistance(enemy.pos) < 800 then
			count = count + 1
			--PrintChat(EnemiesAround)
		end
		if ValidTarget(enemy, RRange) and self:CanUse(_R,"KS") and GetDistance(myHero.pos, enemy.pos) > 900 + myHero.boundingRadius + enemy.boundingRadius and EnemiesAround == 0 and not IsUnderEnemyTurret(myHero.pos) and self:CastingChecks() and not _G.SDK.Attack:IsActive() then
			local RDamage = getdmg("R", enemy, myHero, myHero:GetSpellData(_R).level)
			if enemy.health <= RDamage then
				rtarget = enemy
			end
			local rcount = 0
			for j, enemy2 in pairs(EnemyHeroes) do
				local RLine = ClosestPointOnLineSegment(enemy2.pos, myHero.pos, rtarget.pos)
				if GetDistance(RLine, enemy2.pos) <= 500 then
					rcount = rcount + 1
				end
			end
			RAround = rcount
			PrintChat(RAround)
			if RAround == 1 then
				if enemy.pos:ToScreen().onScreen then
					Control.CastSpell(HK_R, enemy.pos)
				else
					local MMSpot = Vector(enemy.pos):ToMM()
					local MouseSpotBefore = mousePos
					Control.SetCursorPos(MMSpot.x, MMSpot.y)
					Control.KeyDown(HK_R); Control.KeyUp(HK_R)
					DelayAction(function() Control.SetCursorPos(MouseSpotBefore) end, 0.20)
				end
			end
		end
		if ValidTarget(enemy, QRange) and self:CanUse(_Q, "KS") then
			local QDamage = getdmg("Q", enemy, myHero, myHero:GetSpellData(_Q).level)
			local pred = _G.PremiumPrediction:GetPrediction(myHero, enemy, QSpellData)
			if pred.CastPos and _G.PremiumPrediction.HitChance.High(pred.HitChance) and enemy.health < QDamage and GetDistance(pred.CastPos) > 650 + myHero.boundingRadius + enemy.boundingRadius and Caitlyn:CastingChecks() and not _G.SDK.Attack:IsActive() then
				Control.CastSpell(HK_Q, pred.CastPos)
			end
		end
		if ValidTarget(enemy, WRange) and self:CanUse(_W, "TrapImmo") and self:CastingChecks() and _G.SDK.Attack:IsActive() and (IsImmobile(enemy) > 0.5 or enemy.ms <= enemy.ms * 0.20 or enemy.isImmortal and enemy.ms == 0) and not BuffActive(enemy, "caitlynyordletrapdebuff") then
			local pred = _G.PremiumPrediction:GetPrediction(myHero, enemy, WSpellData)
			if pred.CastPos and pred.HitChance >= 1 then
				Control.CastSpell(HK_W, pred.CastPos)
			end
		end
		if ValidTarget(enemy, EPeelRange) and self:CanUse(_E, "NetGap") and self:CastingChecks() and not _G.SDK.Attack:IsActive() and IsFacing(enemy) and not IsMyHeroFacing(enemy) and enemy.activeSpell.target == myHero.handle then
				Control.CastSpell(HK_E, enemy)
		end
		if enemy and ValidTarget(enemy, 1300 + myHero.boundingRadius + enemy.boundingRadius) and (GetBuffDuration(enemy, "CaitlynEntrapmentMissile") >= 0.5 or GetBuffDuration(enemy, "caitlynyordletrapdebuff") > 0.5) then
			_G.SDK.Orbwalker.ForceTarget = enemy
		else
			_G.SDK.Orbwalker.ForceTarget = nil
		end
	end
	EnemiesAround = count
end

function Caitlyn:CanUse(spell, mode)
	local ManaPercent = myHero.mana / myHero.maxMana * 100
	if mode == nil then
		mode = Mode()
	end
	
	if spell == _Q then
		if mode == "Combo" and IsReady(spell) and self.Menu.QSpell.QCombo:Value() then
			return true
		end
		if mode == "Harass" and IsReady(spell) and self.Menu.QSpell.QHarass:Value() and ManaPercent > self.Menu.QSpell.QHarassMana:Value() then
			return true
		end
		if mode == "LaneClear" and IsReady(spell) and self.Menu.QSpell.QLaneClear:Value() and ManaPercent > self.Menu.QSpell.QLaneClearMana:Value() then
			return true
		end
		if mode == "KS" and IsReady(spell) and self.Menu.QSpell.QKS:Value() then
			return true
		end
		if mode == "LastHit" and IsReady(spell) and self.Menu.QSpell.QLastHit:Value() then
			return true
		end
	elseif spell == _W then
		if mode == "TrapImmo" and IsReady(spell) and self.Menu.WSpell.WImmo:Value() then
			return true
		end
	elseif spell == _E then
		if mode == "Combo" and IsReady(spell) and self.Menu.ESpell.ECombo:Value() then
			return true
		end
		if mode == "Harass" and IsReady(spell) and self.Menu.ESpell.EHarass:Value()and ManaPercent > self.Menu.ESpell.EHarassMana:Value() then
			return true
		end
		if mode == "NetGap" and IsReady(spell) and self.Menu.ESpell.EGap:Value() then
			return true
		end
	elseif spell == _R then
		if mode == "KS" and IsReady(spell) and self.Menu.RSpell.RKS:Value() then
			return true
		end
	end
	return false
end

function Caitlyn:Logic()
    if target == nil then 
        return 
    end
	local maxQRange = 1300 + target.boundingRadius
	local minQRange = 650 + target.boundingRadius
	local ERange = 750 + target.boundingRadius
	
    if Mode() == "Combo" and target then
        if self:CanUse(_Q, "Combo") and ValidTarget(target, maxQRange) and Caitlyn:CastingChecks() and not _G.SDK.Attack:IsActive() and GetDistance(myHero.pos, target.pos) > minQRange  then
            local pred = _G.PremiumPrediction:GetPrediction(myHero, target, QSpellData)
			if pred.CastPos and pred.HitChance > self.Menu.QSpell.QComboHitChance:Value() then
				Control.CastSpell(HK_Q, pred.CastPos)
			end
        elseif self:CanUse(_Q, "Combo") and ValidTarget(target, maxQRange) and Caitlyn:CastingChecks() and not _G.SDK.Attack:IsActive() and (GetBuffDuration(target, "CaitlynEntrapmentMissile") >= 0.5 or GetBuffDuration(target, "caitlynyordletrapdebuff") >= 0.5) then
			Control.CastSpell(HK_Q, target.pos)
		end
		if self:CanUse(_E, "Combo") and ValidTarget(target, ERange) and self:CastingChecks() and not _G.SDK.Attack:IsActive() then
			local pred = _G.PremiumPrediction:GetPrediction(myHero, target, ESpellData)
			if pred.CastPos and pred.HitChance > self.Menu.ESpell.EComboHitChance:Value() then 
				Control.CastSpell(HK_E, pred.CastPos)
			end
		elseif self:CanUse(_E, "Combo") and ValidTarget(target, ERange) and self:CastingChecks() and not _G.SDK.Attack:IsActive() and GetBuffDuration(target, "caitlynyordletrapdebuff") >= 0.5 then
			local pred = _G.PremiumPrediction:GetPrediction(myHero, target, ESpellData)
			if pred.CastPos and pred.HitChance > 0.5 then
				Control.CastSpell(HK_E, pred.CastPos)
			end
		end
	elseif Mode() == "Harass" and target then
		if self:CanUse(_Q, "Harass") and ValidTarget(target, maxQRange) and self:CastingChecks() and not _G.SDK.Attack:IsActive() and GetDistance(myHero.pos, target.pos) > minQRange then
            local pred = _G.PremiumPrediction:GetPrediction(myHero, target, QSpellData)
			if pred.CastPos and pred.HitChance > self.Menu.QSpell.QHarassHitChance:Value() then
				Control.CastSpell(HK_Q, pred.CastPos)
			end
        elseif self:CanUse(_Q, "Harass") and ValidTarget(target, maxQRange) and self:CastingChecks() and not _G.SDK.Attack:IsActive() and (GetBuffDuration(target, "CaitlynEntrapmentMissile") >= 0.5 or GetBuffDuration(target, "caitlynyordletrapdebuff") >= 0.5) then
			Control.CastSpell(HK_Q, target.pos)
		end
		if self:CanUse(_E, "Harass") and ValidTarget(target, ERange) and self:CastingChecks() and not _G.SDK.Attack:IsActive() then
			local pred = _G.PremiumPrediction:GetPrediction(myHero, target, ESpellData)
			if pred.CastPos and pred.HitChance > self.Menu.ESpell.EHarassHitChanceHitChance:Value() then 
				Control.CastSpell(HK_E, pred.CastPos)
			end
		elseif self:CanUse(_E, "Harass") and ValidTarget(target, ERange) and self:CastingChecks() and not _G.SDK.Attack:IsActive() and GetBuffDuration(target, "caitlynyordletrapdebuff") >= 0.5 then
			local pred = _G.PremiumPrediction:GetPrediction(myHero, target, ESpellData)
			if pred.CastPos and pred.HitChance > 0.5 then
				Control.CastSpell(HK_E, pred.CastPos)
			end
		end
	end
end

function Caitlyn:LastHit()
	if self:CanUse(_Q, "LastHit") and (Mode() == "LastHit" or Mode() == "Harass") then
		local minions = _G.SDK.ObjectManager:GetEnemyMinions(1300)
		for i = 1, #minions do
			local minion = minions[i]
			local QDam = getdmg("Q", minion, myHero, myHero:GetSpellData(_Q).level)
			local EDam = getdmg("E", minion, myHero, myHero:GetSpellData(_E).level)
			if GetDistance(minion.pos) > 650 and ValidTarget(minion, 1300) and (minion.charName == "SRU_ChaosMinionSiege" or minion.charName == "SRU_OrderMinionSiege") and self:CastingChecks() and not _G.SDK.Attack:IsActive() then
				local pred = _G.PremiumPrediction:GetPrediction(myHero, minion, QSpellData)
				if QDam >= minion.health and pred.CastPos and pred.HitChance > 0.20 then
					Control.CastSpell(HK_Q, pred.CastPos)
				end
			end
		end
	end
end

function Caitlyn:LaneClear()
    if self:CanUse(_Q, "LaneClear") and Mode() == "LaneClear" then
        local minions = _G.SDK.ObjectManager:GetEnemyMinions(1300)
        for i = 1, #minions do
            local minion = minions[i]
            if ValidTarget(minion, 1300 + myHero.boundingRadius) then
                mainminion = minion
            end
			local laneclearcount = 0
			for j = 1, #minions do
				local minion2 = minions[j]
				local MinionNear = ClosestPointOnLineSegment(minion2.pos, myHero.pos, mainminion.pos)
				if GetDistance(MinionNear, minion2.pos) < 120 then
					laneclearcount = laneclearcount + 1
				end
			end
			MinionsLaneClear = laneclearcount
			if MinionsLaneClear >= self.Menu.QSpell.QLaneClearCount:Value() then	
				Control.CastSpell(HK_Q, mainminion.pos)
			end
        end
		
    end
end

function Caitlyn:RangedHelper(unit)
	local AARange = 625 + target.boundingRadius
    local EAARangel = _G.SDK.Data:GetAutoAttackRange(unit)
    local MoveSpot = nil
    local RangeDif = AARange - EAARangel
    local ExtraRangeDist = RangeDif
    local ExtraRangeChaseDist = RangeDif - 100

    local ScanDirection = Vector((myHero.pos-mousePos):Normalized())
    local ScanDistance = GetDistance(myHero.pos, unit.pos) * 0.8
    local ScanSpot = myHero.pos - ScanDirection * ScanDistance
	

    local MouseDirection = Vector((unit.pos-ScanSpot):Normalized())
    local MouseSpotDistance = EAARangel + ExtraRangeDist
    if not IsFacing(unit) then
        MouseSpotDistance = EAARangel + ExtraRangeChaseDist
    end
    if MouseSpotDistance > AARange then
        MouseSpotDistance = AARange
    end

    local MouseSpot = unit.pos - MouseDirection * (MouseSpotDistance)
	local MouseDistance = GetDistance(unit.pos, mousePos)
    local GaleMouseSpotDirection = Vector((myHero.pos-MouseSpot):Normalized())
    local GalemouseSpotDistance = GetDistance(myHero.pos, MouseSpot)
    if GalemouseSpotDistance > 300 then
        GalemouseSpotDistance = 300
    end
    local GaleMouseSpoty = myHero.pos - GaleMouseSpotDirection * GalemouseSpotDistance
    MoveSpot = MouseSpot

    if MoveSpot then
        if GetDistance(myHero.pos, MoveSpot) < 50 or IsUnderEnemyTurret(MoveSpot) then
            _G.SDK.Orbwalker.ForceMovement = nil
        elseif self.Menu.rangedhelper:Value() and GetDistance(myHero.pos, unit.pos) <= AARange-50 and (Mode() == "Combo" or Mode() == "Harass") and self:CastingChecks() and MouseDistance < 750 then
            _G.SDK.Orbwalker.ForceMovement = MoveSpot
        else
            _G.SDK.Orbwalker.ForceMovement = nil
        end
    end
    return GaleMouseSpoty
end
			
function Caitlyn:OnPostAttack(args)
end

function Caitlyn:OnPostAttackTick(args)
end

function Caitlyn:OnPreAttack(args)
end



function OnLoad()
    Manager()
end

class "Tristana"

EnemyLoaded = false

function Tristana:Menu()
	self.Menu = MenuElement({type = MENU, id = "dnsTristana", name = "dnsTristana"})
-- main menu
	self.Menu:MenuElement({id = "combo", name = "Combo", type = MENU})
	self.Menu:MenuElement({id = "harass", name = "Harass", type = MENU})
	self.Menu:MenuElement({id = "laneclear", name = "LaneClear", type = MENU})
	self.Menu:MenuElement({id = "auto", name = "Auto", type = MENU})
	self.Menu:MenuElement({id = "draws", name = "Draws", type = MENU})
	self.Menu:MenuElement({id = "rangedhelper", name = "Use RangedHelper", value = false})
-- combo 
	self.Menu.combo:MenuElement({id = "qcombo", name = "Use Q in Combo", value = true})
	self.Menu.combo:MenuElement({id = "qcomboe", name = "Only Q when E", value = true})
	self.Menu.combo:MenuElement({id = "ecombo", name = "Use E in Combo", value = true})
-- harass
	self.Menu.harass:MenuElement({id = "qharass", name = "Use Q in Harass", value = true})
	self.Menu.harass:MenuElement({id = "qharasse", name = "Only Q when E", value = true})
	self.Menu.harass:MenuElement({id = "qharassmana", name = "Q Harass Mana", value = 40, min = 5, max = 95, step = 5, identifier = "%"})
	self.Menu.harass:MenuElement({id = "eharass", name = "Use E in Harass", value = true})
	self.Menu.harass:MenuElement({id = "eharassmana", name = "E Harass Mana", value = 40, min = 5, max = 95, step = 5, identifier = "%"})
-- laneclear
	self.Menu.laneclear:MenuElement({id = "qlaneclear", name = "Use Q in LaneClear", value = true})
	self.Menu.laneclear:MenuElement({id = "qlaneclearcount", name = "Q LaneClear Minions", value = 6, min = 1, max = 9, step = 1})
	self.Menu.laneclear:MenuElement({id = "qlaneclearmana", name = "Q LaneClear Mana", value = 60, min = 5, max = 95, step = 5, identifier = "%"})
-- auto 
	self.Menu.auto:MenuElement({id = "wdodge", name = "Use W Disengage", value = true})
	self.Menu.auto:MenuElement({id = "wdodgehp", name = "If HP is lower then", value = 35, min = 5, max = 95, step = 5, identifier = "%"})
	self.Menu.auto:MenuElement({id = "rks", name = "Use R to KS", value = true})
	self.Menu.auto:MenuElement({id = "wrks", name = "Use W + R to KS", value = true})
	self.Menu.auto:MenuElement({id = "wrksspace", name = "To Use WRKS, normal RKS needs to be ticked", type = SPACE})
	self.Menu.auto:MenuElement({id = "rpeel", name = "Use R to Peel", value = true})
	self.Menu.auto:MenuElement({id = "rpeelhp", name = "If HP is lower then", value = 40, min = 5, max = 95, step = 5, identifier = "%"})
-- draws 
	self.Menu.draws:MenuElement({id = "qtimer", name = "Draw Q Timer", value = false})
	self.Menu.draws:MenuElement({id = "wdraw", name = "Draw W Range", value = false})
	self.Menu.draws:MenuElement({id = "anydraw", name = "Draw AA/E/R Range", value = false})
end

function Tristana:Draw()
	local anyrange = 517 + (8 * myHero.levelData.lvl) + myHero.boundingRadius
	-- w draws
	if self.Menu.draws.wdraw:Value() then
		Draw.Circle(myHero.pos, 850 + myHero.boundingRadius, 2, Draw.Color(255, 23, 230, 220))
	end
	-- q timer 
	local QBuffDuration = GetBuffDuration(myHero, "TristanaQ")
	if self.Menu.draws.qtimer:Value() and BuffActive(myHero, "TristanaQ") then
		DrawTextOnHero(myHero, QBuffDuration, Draw.Color(255, 23, 230, 220))
	end
	--AAER draw
	if self.Menu.draws.anydraw:Value() then
		Draw.Circle(myHero.pos, anyrange, 2, Draw.Color(255, 49, 203, 100))
	end
end

function Tristana:Spells() 
	WSpellData = {speed = 1100, range = 850 + myHero.boundingRadius, delay = 0.25, radius = 350, collision = {}, type = "circular" }
end

function Tristana:Tick()
	if _G.JustEvade and _G.JustEvade:Evading() or (_G.ExtLibEvade and _G.ExtLibEvade.Evading) or Game.IsChatOpen() or myHero.dead then return end
	target = GetTarget(1400)
	AARange = _G.SDK.Data:GetAutoAttackRange(myHero)
	if target and ValidTarget(target) then
        --PrintChat(target.pos:To2D())
        --PrintChat(mousePos:To2D())
        GaleMouseSpot = self:RangedHelper(target)
    else
        _G.SDK.Orbwalker.ForceMovement = nil
    end
	-- casting checks
	CastingQ = myHero.activeSpell.name == "TristanaQ"
	CastingW = myHero.activeSpell.name == "TristanaW"
	CastingE = myHero.activeSpell.name == "TristanaE"
	CastingR = myHero.activeSpell.name == "TristanaR"
	self:Auto()
	self:Logic()
	self:LaneClear()
	if EnemyLoaded == false then
        local CountEnemy = 0
        for i, enemy in pairs(EnemyHeroes) do
            CountEnemy = CountEnemy + 1
        end
        if CountEnemy < 1 then
            GetEnemyHeroes()
        else
            EnemyLoaded = true
            PrintChat("Enemy Loaded")
        end
	end
end

function Tristana:CastingChecks()
	if not CastingE and not CastingR then
		return true
	else 
		return false
	end
end

function Tristana:CanUse(spell, mode)
	local ManaPercent = myHero.mana / myHero.maxMana * 100
	local HPPercent = myHero.health / myHero.maxHealth

	if mode == nil then
		mode = Mode()
	end

	if spell == _Q then
		if mode == "Combo" and IsReady(_Q) and self.Menu.combo.qcombo:Value() then 
			return true
		end
		if mode == "Harass" and IsReady(_Q) and self.Menu.harass.qharass:Value() and ManaPercent >= self.Menu.harass.qharassmana:Value() then
			return true
		end
		if mode == "LaneClear" and IsReady(_Q) and self.Menu.laneclear.qlaneclear:Value() and ManaPercent >= self.Menu.laneclear.qlaneclearmana:Value() then
			return true
		end
	elseif spell == _W then
		if mode == "Peel" and IsReady(_W) and self.Menu.auto.wdodge:Value() and HPPercent <= self.Menu.auto.wdodgehp:Value() / 100 then
			return true
		end
		if mode == "WRKS" and IsReady(_W) and self.Menu.auto.wrks:Value() then
			return true
		end
	elseif spell == _E then
		if mode == "Combo" and IsReady(_E) and self.Menu.combo.ecombo:Value() then
			return true
		end
		if mode == "Harass" and IsReady(_E) and self.Menu.harass.eharass:Value() and ManaPercent >= self.Menu.harass.eharassmana:Value() then
			return true
		end
		if mode == "Tower" and IsReady(_E) and self.Menu.laneclear.etower:Value() and ManaPercent >= self.Menu.laneclear.etowermana:Value() then
			return true
		end
	elseif spell == _R then
		if mode == "KS" and IsReady(_R) and self.Menu.auto.rks:Value() then 
			return true
		end
		if mode == "WRKS" and IsReady(_R) and self.Menu.auto.wrks:Value() then
			return true
		end
		if mode == "Peel" and IsReady(_R) and self.Menu.auto.rpeel:Value() and HPPercent <= self.Menu.auto.rpeelhp:Value() / 100 then
			return true
		end
	end
	return false
end

function Tristana:EDMG(unit)
	local eLvl = myHero:GetSpellData(_E).level
	if eLvl > 0 then
		local raw = ({ 154, 176, 198, 220, 242 })[eLvl]
		local m = ({ 1.1, 1.65, 2.2, 2.75, 3.3 })[eLvl]
		local bonusDmg = (m * myHero.bonusDamage) + (1.1 * myHero.ap)
		local FullDmg = raw + bonusDmg
		return CalcPhysicalDamage(myHero, unit, FullDmg)  
	end
end

function Tristana:Auto()
	for i, enemy in pairs(EnemyHeroes) do
		local WRange = 850 + myHero.boundingRadius + enemy.boundingRadius
		local AAERRange = 517 + (8 * myHero.levelData.lvl) + myHero.boundingRadius + enemy.boundingRadius


		-- rks 
		if enemy and ValidTarget(enemy, AAERRange) and self:CanUse(_R, "KS") and self:CastingChecks() and myHero.attackData.state ~= 2 then
			local EDamage = self:EDMG(enemy)
			local RDamage = getdmg("R", enemy, myHero, myHero:GetSpellData(_R).level)
			if GetBuffStacks(enemy, "tristanaecharge") >= 3 and enemy.health <= RDamage + EDamage or enemy.health <= RDamage then
				Control.CastSpell(HK_R, enemy)
			end
		end

		--wrks
		if enemy and ValidTarget(enemy, AAERRange + WRange - 100) and GetDistance(enemy.pos) > AAERRange + 50 and self:CanUse(_R, "WRKS") and self:CanUse(_W, "WRKS") and self:CastingChecks() and myHero.attackData.state ~= 2 then
			local EDamage = self:EDMG(enemy)
			local RDamage = getdmg("R", enemy, myHero, myHero:GetSpellData(_R).level)
			if GetBuffStacks(enemy, "tristanaecharge") >= 3 and enemy.health <= RDamage + EDamage or enemy.health <= RDamage then
				local Direction = Vector((enemy.pos-myHero.pos):Normalized())
				local WSpot = enemy.pos - Direction * (AAERRange - 50)
				Control.CastSpell(HK_W, WSpot)
			end
		end
		-- w Disengage
		if enemy and ValidTarget(enemy, 250 + myHero.boundingRadius + enemy.boundingRadius) and self:CanUse(_W, "Peel") and IsFacing(enemy) and not IsMyHeroFacing(enemy) and not self:CanUse(_R, "Peel") and self:CastingChecks() and enemy.activeSpell.target == myHero.handle then
			local Direction = Vector((enemy.pos-myHero.pos):Normalized())
			local WSpot = myHero.pos - Direction * WRange
			if not IsUnderEnemyTurret(WSpot) then
				Control.CastSpell(HK_W, WSpot)
			end
		end
		-- r peel
		if enemy and ValidTarget(enemy, 250 + myHero.boundingRadius + enemy.boundingRadius) and self:CanUse(_R, "Peel") and IsFacing(enemy) and not IsMyHeroFacing(enemy) and self:CastingChecks() and enemy.activeSpell.target == myHero.handle then
			Control.CastSpell(HK_R, enemy)
		end
		-- force target
		if enemy and ValidTarget(enemy, AAERRange) and GetBuffDuration(enemy, "tristanaechargesound") >= 0.5 then
			_G.SDK.Orbwalker.ForceTarget = enemy
		else
			_G.SDK.Orbwalker.ForceTarget = nil
		end
	end
end


function Tristana:Logic() 
	if target == nil then return end

	local WRange = 850 + myHero.boundingRadius + target.boundingRadius
	local AAERRange = 517 + (8 * myHero.levelData.lvl) + myHero.boundingRadius + target.boundingRadius
	if Mode() == "Combo" and target then
		if target and ValidTarget(target, AAERRange) and self:CanUse(_E, "Combo") and myHero.attackData.state ~= 2 and self:CastingChecks() then
			Control.CastSpell(HK_E, target)
		end
		if target and ValidTarget(target, AAERRange) and self:CanUse(_Q, "Combo") and self.Menu.combo.qcomboe:Value() and GetBuffDuration(target, "tristanaechargesound") >= 0.5 and self:CastingChecks() and myHero.attackData.state == 2 then
			Control.CastSpell(HK_Q)
		elseif target and ValidTarget(target, AAERRange) and self:CanUse(_Q, "Combo") and not self.Menu.combo.qcomboe:Value() and self:CastingChecks() and myHero.attackData.state == 2 then
			Control.CastSpell(HK_Q)
		end
	end
	if Mode() == "Harass" and target then
		if target and ValidTarget(target, AAERRange) and self:CanUse(_E, "Harass") and myHero.attackData.state ~= 2 and self.CastingChecks() then
			Control.CastSpell(HK_E, target)
		end
		if target and ValidTarget(target, AAERRange) and self:CanUse(_Q, "Harass") and self.Menu.harass.qharasse.Value() and GetBuffDuration(target, "tristanaechargesound") >= 0.5 and self:CastingChecks() and myHero.attackData.state == 2 then
			Control.CastSpell(HK_Q)
		elseif target and ValidTarget(target, AAERRange) and self:CanUse(_Q, "Harass") and not self.Menu.harass.qharasse.Value() and self:CastingChecks() and myHero.attackData.state == 2 then
			Control.CastSpell(HK_Q)
		end
	end
end

function Tristana:LaneClear()
	local qcount = 0
	if Mode() == "LaneClear" then 
		local minions = _G.SDK.ObjectManager:GetEnemyMinions(1300)
		for i = 1, #minions do
			local minion = minions[i]
			local WRange = 850 + myHero.boundingRadius + minion.boundingRadius
			local AAERRange = 517 + (8 * myHero.levelData.lvl) + myHero.boundingRadius + minion.boundingRadius
			--laneclear q
			if minion and ValidTarget(minion, AAERRange + 100) and self:CanUse(_Q, "LaneClear") then
				qcount = qcount + 1
				--PrintChat(qcount)
			end
			if qcount >= self.Menu.laneclear.qlaneclearcount:Value() and myHero.attackData.state == 2 then
				Control.CastSpell(HK_Q)
			end
		end
	end
end

function Tristana:RangedHelper(unit)
	local AARange = 517 + (8 * myHero.levelData.lvl) + myHero.boundingRadius + target.boundingRadius
    local EAARangel = _G.SDK.Data:GetAutoAttackRange(unit)
    local MoveSpot = nil
    local RangeDif = AARange - EAARangel
    local ExtraRangeDist = RangeDif
    local ExtraRangeChaseDist = RangeDif - 100

    local ScanDirection = Vector((myHero.pos-mousePos):Normalized())
    local ScanDistance = GetDistance(myHero.pos, unit.pos) * 0.8
    local ScanSpot = myHero.pos - ScanDirection * ScanDistance
	

    local MouseDirection = Vector((unit.pos-ScanSpot):Normalized())
    local MouseSpotDistance = EAARangel + ExtraRangeDist
    if not IsFacing(unit) then
        MouseSpotDistance = EAARangel + ExtraRangeChaseDist
    end
    if MouseSpotDistance > AARange then
        MouseSpotDistance = AARange
    end

    local MouseSpot = unit.pos - MouseDirection * (MouseSpotDistance)
	local MouseDistance = GetDistance(unit.pos, mousePos)
    local GaleMouseSpotDirection = Vector((myHero.pos-MouseSpot):Normalized())
    local GalemouseSpotDistance = GetDistance(myHero.pos, MouseSpot)
    if GalemouseSpotDistance > 300 then
        GalemouseSpotDistance = 300
    end
    local GaleMouseSpoty = myHero.pos - GaleMouseSpotDirection * GalemouseSpotDistance
    MoveSpot = MouseSpot

    if MoveSpot then
        if GetDistance(myHero.pos, MoveSpot) < 50 or IsUnderEnemyTurret(MoveSpot) then
            _G.SDK.Orbwalker.ForceMovement = nil
        elseif self.Menu.rangedhelper:Value() and GetDistance(myHero.pos, unit.pos) <= AARange-50 and (Mode() == "Combo" or Mode() == "Harass") and self:CastingChecks() and MouseDistance < 750 then
            _G.SDK.Orbwalker.ForceMovement = MoveSpot
        else
            _G.SDK.Orbwalker.ForceMovement = nil
        end
    end
    return GaleMouseSpoty
end

function Tristana:OnPostAttack(args)
end

function Tristana:OnPostAttackTick(args)
end

function Tristana:OnPreAttack(args)
end



function OnLoad()
    Manager()
end
