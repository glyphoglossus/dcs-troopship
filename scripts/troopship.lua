--------------------------------------------------------------------------------
--  TROOPSHIP - Tactical Airmobile Operations Mission Development Scripting
--              Library for DCS
--
--  Bearfoot (glyphoglossus@gmail.com)
--  Copyright 2017-2018 glyphoglossus@gmail.com.
--  All rights reserved.
--  License:  This  program  is  free software; you can redistribute it and/or
--  modify  it  under the terms of the GNU General Public License as published
--  by  the  Free Software Foundation; either version 3 of the License, or (at
--  your  option)  any  later version. This program is distributed in the hope
--  that it will be useful, but WITHOUT ANY WARRANTY; without even the implied
--  warranty  of  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
--  GNU General Public License for more details.
--
--  NOTE: This project is not endorsed by or otherwise in any way officially
--  associated with Eagle Dynamics, the Fighter Collection, or anyone else
--  behind the DCS family of products.
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- Utilities

local function __TROOPSHIP__isEmpty(t)
    if t == nil then
        return true
    elseif next(t) == nil then
        return true
    else
        return false
    end
end

local function __TROOPSHIP__getValidatedZoneForName(zone_name, default)
    if zone_name == nil then
        return default
    end
    -- local z = trigger.misc.getZone(zone_name)
    -- if not z then
    --     return default
    -- end
    local ok, zone = pcall(function() return ZONE:New(zone_name) end)
    if ok then
        zone.__TROOPSHIP__name = zone:GetName()
        return zone
    else
        return default
    end
end

local function __TROOPSHIP__getValidatedZonesFromNames(zone_names, default)
    if zone_names == nil then
        return default
    end
    local zone_count = 0
    zones = {}
    for _, zone_name in pairs(zone_names) do
        -- local z = trigger.misc.getZone(zone_name)
        -- if z then
        local ok, zone = pcall(function() return ZONE:New(zone_name) end)
        if ok then
            zone_count = zone_count + 1
            zone.__TROOPSHIP__name = zone:GetName()
            zones[zone_count] = zone
        end
        -- end
    end
    if __TROOPSHIP__isEmpty(zones) then
        return default
    else
        table.sort(zones, function(x,y) return x.__TROOPSHIP__name < y.__TROOPSHIP__name end)
        return zones
    end
end

local function __TROOPSHIP__getFirstUnit(moose_group)
    for _, unit in pairs( moose_group:GetUnits() ) do
        return unit
    end
end

--------------------------------------------------------------------------------
-- __TROOPSHIP__DynamicTroopSpawner

__TROOPSHIP__DynamicTroopSpawner = {}
__TROOPSHIP__DynamicTroopSpawner.__index = __TROOPSHIP__DynamicTroopSpawner

setmetatable(__TROOPSHIP__DynamicTroopSpawner, {
    __call = function (cls, ...)
        return cls.new(...)
    end,
})

function __TROOPSHIP__DynamicTroopSpawner.new(name, zone_name, template_group_name, troop_command, spawner_options)
    local self = setmetatable({}, __TROOPSHIP__DynamicTroopSpawner)
    self.spawner_name = name
    self.spawn_zone_name = zone_name
    self.spawn_zone = __TROOPSHIP__getValidatedZoneForName(self.spawn_zone_name)
    if self.spawn_zone == nil then
        error(string.format("Cannot find zone '%s", self.spawn_zone_name))
    end
    self.template_group_name = template_group_name
    self.template_moose_group = GROUP:FindByName(self.template_group_name)
    if not self.template_moose_group then
        error(string.format("Cannot find group '%s", self.template_group_name))
    end
    self.troop_command = troop_command
    if spawner_options == nil then
        spawner_options = {}
    end
    self.spawned_troop_name_prefix = spawner_options["spawned_troop_name_prefix"] or self.spawner_name
    self.troop_spawner = SPAWN:NewWithAlias(self.template_group_name, string.format("%s ", self.spawned_troop_name_prefix))
    -- self.group_size = self.template_moose_group:GetSize()
    self.deploy_route_to_zone_name = spawner_options["deploy_route_to_zone_name"] or nil
    self.spawned_count = 0
    return self
end
--
-- Return true if unit is in zone
function __TROOPSHIP__DynamicTroopSpawner:IsUnitInZone(moose_unit)
    return moose_unit:IsInZone(self.spawn_zone)
end

-- Return name of next spawned troop
function __TROOPSHIP__DynamicTroopSpawner:GetNextSpawnedTroopName()
    return string.format("%s #%03d", self.spawned_troop_name_prefix, self.spawned_count + 1)
end

-- Spawn a new troop
function __TROOPSHIP__DynamicTroopSpawner:Spawn()
    local spawned_troop_name = self:GetNextSpawnedTroopName()
    self.spawned_count = self.spawned_count + 1
    local moose_group = self.troop_spawner:SpawnInZone(self.spawn_zone)
    if moose_group == nil then
        error("Failed to spawn group")
    end
    return self.troop_command:__registerGroupAsTroop(moose_group, spawned_troop_name, nil)
end


--------------------------------------------------------------------------------
-- TROOPCOMMAND

-- lifecycle --

TROOPCOMMAND = {}
TROOPCOMMAND.__index = TROOPCOMMAND

setmetatable(TROOPCOMMAND, {
    __call = function (cls, ...)
        return cls.new(...)
    end,
})

-- Instantiate the registry
function TROOPCOMMAND.new(name, coalition, options)
    local self = setmetatable({}, TROOPCOMMAND)
    self.name = name -- decorative right now;
    self.coalition = coalition -- decorative right now; coalition.side.RED or coalition.side.BLUE
    self.deployed_troops = {}
    self.withdrawn_troops = {}
    self.num_deployed_troops = 0
    self.c2_clients = {}
    self.routing_zones = {}
    self.max_menu_items = 10
    self.dynamic_troop_spawners = {}
    self.unrealized_troopship_options = {}
    self.troopships = {}
    self.unrealized_c2ship_options = {}
    self.c2ships = {}
    world.addEventHandler(self)
    return self
end

-- World Interaction --

function TROOPCOMMAND:onEvent(event)
    --  Events:
    --      19, world.event.S_EVENT_PLAYER_ENTER_UNIT = Occurs when any player assumes direct control of a unit.
    --      15, world.event.S_EVENT_BIRTH = Occurs when any object is spawned into the mission
    --      20, world.event.S_EVENT_PLAYER_LEAVE_UNIT = Occurs when any player relieves control of a unit
    --      8, world.event.S_EVENT_DEAD = Occurs when an object is completely destroyed.
    --  When player leaves slot: 20 is fired, but not 8
    --  When players enters aircraft: 19 and 15
    --  Leave slot and respawn: 20, 19, 15, 17
    --  Crash and die: 3, 16, 9, 5
    --  Crash and die: 2,8,9,5
    -- if event.id == 15 or event.id == world.event.S_EVENT_BIRTH then -- S_EVENT_BIRTH
    if event.id == world.event.S_EVENT_BIRTH then -- S_EVENT_BIRTH
        local unit_name = event.initiator:getName()
        if self.unrealized_troopship_options[unit_name] ~= nil then
            self:__createTroopship(unit_name, self.unrealized_troopship_options[unit_name])
        elseif self.troopships[unit_name] ~= nil then
            self.troopships[unit_name]:Start()
        end
        if self.unrealized_c2ship_options[unit_name] ~= nil then
            self:__createCommandAndControlShip(unit_name, self.unrealized_c2ship_options[unit_name])
        elseif self.c2ships[unit_name] ~= nil then
            -- self:BuildCommandAndControlMenu(self.c2ships[unit_name]) -- should not need this, as TROOPCOMMAND automatically updates all C2 clients continuously
        end
    elseif event.id == world.event.S_EVENT_PILOT_DEAD
            or event.id == world.event.S_EVENT_EJECTION
            or event.id == world.event.S_EVENT_CRASH
            or event.id == world.event.S_EVENT_DEAD
            or event.id == world.event.S_EVENT_PLAYER_LEAVE_UNIT then
        -- just 'dead' does not seem to work in the event of a crash
        local unit_name = event.initiator:getName()
        if self.troopships[unit_name] ~= nil then
            self.troopships[unit_name]:Stop()
        end
        if self.c2ships[unit_name] ~= nil then
        end
    end
end

-- Zone Registration/Management --

-- Register routing/waypoint zones
function TROOPCOMMAND:RegisterRoutingZoneNames(zone_names)
    if __TROOPSHIP__isEmpty(zone_names) then return end
    for _, zone_name in pairs(zone_names) do
        local zone = __TROOPSHIP__getValidatedZoneForName(zone_name)
        if zone ~= nil then
            self.routing_zones[#self.routing_zones+1] = zone
        end
    end
    if not __TROOPSHIP__isEmpty(self.routing_zones) then
        table.sort(self.routing_zones, function(x,y) return x.__TROOPSHIP__name < y.__TROOPSHIP__name end)
    end
end

function TROOPCOMMAND:RegisterRoutingZoneName(zone_name)
    return self:RegisterRoutingZoneNames({zone_name})
end


-- Troopship Registration/Management --

function TROOPCOMMAND:RegisterTroopship(unit_name, troopship_options)
    -- local troopship_troopship_options = {}
    -- if troopship_options ~= nil then
    --     for k,v in pairs(troopship_options) do
    --         troopship_troopship_options[k] = v
    --     end
    -- end
    -- troopship_troopship_options["unit_name"] = unit_name
    -- troopship_troopship_options["troop_command"] = self
    if troopship_options == nil then
        troopship_options = {}
    end
    if troopship_options["is_inherit_command_routing_zones"] == nil or troopship_options["is_inherit_command_routing_zones"] then
        troopship_options["deploy_route_to_zones"] = self.routing_zones
    end
    self:__createTroopship(unit_name, troopship_options)
end

-- Service function to create TROOPSHIP object
function TROOPCOMMAND:__createTroopship(unit_name, troopship_options)
    local unit = Unit.getByName(unit_name)
    if unit == nil then
        self.unrealized_troopship_options[unit_name] = troopship_options
        self.troopships[unit_name] = nil
    else
        local troopship = TROOPSHIP(unit_name, self, troopship_options)
        self.troopships[unit_name] = troopship
        self.unrealized_troopship_options[unit_name] = nil
    end
end

-- Troop Registration/Management --

-- Register an existing group as a valid troop, specified by group name
function TROOPCOMMAND:RegisterTroop(group_name, troop_name, troop_options)
    local moose_group = GROUP:FindByName(group_name)
    if moose_group == nil then
        error(string.format("Cannot find group '%s'", group_name))
    end
    return self:__registerGroupAsTroop(moose_group, troop_name, troop_options)
end

-- Calculate a troop id
function TROOPCOMMAND:GetTroopStatus(troop)
    local dcs_group = troop.moose_group:GetDCSObject()
    category_counts = {}
    for index, unit in pairs(dcs_group:getUnits()) do
        local type_name = unit:getTypeName()
        if not category_counts[type_name] then
            category_counts[type_name] = 1
        else
            category_counts[type_name] = category_counts[type_name] + 1
        end
    end
    local composition_table = {}
    for type_name, count in pairs(category_counts) do
        composition_table[#composition_table+1] = string.format("%s x %s", count, type_name)
    end
    local initial_size = dcs_group:getInitialSize()
    local current_size = dcs_group:getSize()
    local composition_summary = table.concat(composition_table, ", ")
    local composition_summary_with_kia = composition_summary
    if composition_summary == "" then
        composition_summary_with_kia = string.format("all %s KIA", initial_size)
    elseif current_size < initial_size then
        composition_summary_with_kia = string.format("%s, and %s KIA", composition_summary, initial_size-current_size)
    end
    return {
        composition_summary=composition_summary,
        composition_summary_with_kia=composition_summary_with_kia,
        initial_size=initial_size,
        current_size=current_size,
    }
end

-- Calculate a troop id
function TROOPCOMMAND:__calcTroopID(moose_group)
    local troop_id = moose_group:GetDCSObject():getID()
    return troop_id
end

-- Register a (MOOSE) group as a valid troop
function TROOPCOMMAND:__registerGroupAsTroop(moose_group, troop_name, troop_options)
    if not troop_name or troop_name == "" then
        troop_name = moose_group:GetName()
    end
    local troop_id = self:__calcTroopID(moose_group)
    if troop_options == nil then
        troop_options = {}
    end
    local deploy_route_to_zone_name = troop_options["deploy_route_to_zone_name"] or nil
    if deploy_route_to_zone_name ~= nil then
        deploy_route_to_zone = __TROOPSHIP__getValidatedZoneForName(deploy_route_to_zone_name, nil)
    end
    self.deployed_troops[troop_id] = {
            troop_id=troop_id,
            troop_name=troop_name,
            troop_source="existing-group",
            moose_group=moose_group,
            group_spawner=SPAWN:New(moose_group:GetName()),
            -- group_size=moose_group:GetSize(),
            deploy_route_to_zone=deploy_route_to_zone,
            deploy_route_to_zone_name=deploy_route_to_zone_name,
            deploy_route_to_zone_speed=troop_options["deploy_route_to_zone_speed"] or 14,
            deploy_route_to_zone_formation=troop_options["deploy_route_to_zone_formation"] or "Vee",
        }
    self.num_deployed_troops = self.num_deployed_troops + 1
    self:UpdateCommandAndControlClientMenus()
    return self.deployed_troops[troop_id]
end

-- Permanently stop tracking group
function TROOPCOMMAND:PurgeTroop(troop)
    if troop ~= nil then
        self.deployed_troops[troop.troop_id] = nil
        self.withdrawn_troops[troop.troop_id] = nil
    end
end

-- Remove a group from availability
function TROOPCOMMAND:WithdrawTroop(troop_id)
    -- local troop_id = moose_group:GetDCSObject():getID()
    if self.deployed_troops[troop_id] == nil then
        error( string.format("Invalid troop '%s'", troop_id) )
    else
        self.withdrawn_troops[troop_id] = self.deployed_troops[troop_id]
        self.deployed_troops[troop_id] = nil
        self.num_deployed_troops = self.num_deployed_troops - 1
        self:UpdateCommandAndControlClientMenus()
    end
end

-- Restore a group to availability
function TROOPCOMMAND:RestoreTroop(args)
    local troop_id = args["troop_id"]
    local troop = self.withdrawn_troops[troop_id]
    if troop ~= nil then
        self.deployed_troops[troop_id] = troop
        local updated_group = args["update_group"] or nil
        if updated_group then
            self.deployed_troops[troop_id].moose_group = updated_group
        end
        self.withdrawn_troops[troop_id] = nil
        self.num_deployed_troops = self.num_deployed_troops + 1
        self:UpdateCommandAndControlClientMenus()
    else
        error( string.format("Invalid troop '%s'", troop_id) )
    end
end

-- Register a dynamicload zone to generate troops
function TROOPCOMMAND:CreateTroopSpawner(name, zone_name, template_group_name, spawner_options)
    self.dynamic_troop_spawners[#self.dynamic_troop_spawners+1] = __TROOPSHIP__DynamicTroopSpawner(name, zone_name, template_group_name, self, spawner_options)
end

-- Return array of groups in zone
function TROOPCOMMAND:FindDeployedTroopsInZone(zone)
    local results = {}
    for troop_id, troop in pairs(self.deployed_troops) do
        -- if troop.moose_group:IsCompletelyInZone(zone) then
        -- if troop.moose_group:IsPartlyInZone(zone) then -- note: false if all units are in zone
        -- if troop.moose_group:IsCompletelyInZone(zone) or troop.moose_group:IsPartlyInZone(zone) then
        if not troop.moose_group:IsNotInZone(zone) then
            results[#results+1] = troop
        end
    end
    table.sort(results, function(x,y) return x.troop_name < y.troop_name end)
    return results
end

-- Return array troop spawn zones in which the unit is in
function TROOPCOMMAND:FindTroopSpawnZonesInVicinity(moose_unit)
    local results = {}
    for _, spawner in pairs(self.dynamic_troop_spawners) do
        if spawner:IsUnitInZone(moose_unit) then
            results[#results+1] = spawner
        end
    end
    table.sort(results, function(x,y) return x.spawner_name < y.spawner_name end)
    return results
end

-- C&C Ship Registration/Management --

-- Register a C&C client
function TROOPCOMMAND:RegisterCommandAndControlShip(unit_name, c2ship_options)
    self:__createCommandAndControlShip(unit_name, c2ship_options)
end

function TROOPCOMMAND:__createCommandAndControlShip(unit_name, c2ship_options)
    local unit = Unit.getByName(unit_name)
    if c2ship_options == nil then
        c2ship_options = {}
    end
    if unit == nil then
        self.unrealized_c2ship_options[unit_name] = c2ship_options
        self.c2ships[unit_name] = nil
    else
        local group = unit:getGroup()
        local c2_client = {
                    unit=unit,
                    unit_name=unit_name,
                    group=group,
                    group_id=group:getID(),
                }
        self.c2_clients[unit_name] = c2_client
        c2_client.c2_submenu_id = missionCommands.addSubMenuForGroup(c2_client.group_id, "Troop C&C", nil)
        c2_client.c2_submenu_item_ids = nil
        self:BuildCommandAndControlMenu(c2_client)
        self.unrealized_c2ship_options[unit_name] = nil
        self.c2ships[unit_name] = c2_client
        return c2_client
    end
end


-- Update menus for all clients
function TROOPCOMMAND:UpdateCommandAndControlClientMenus()
    local troops = self:__getDeployedTroopList()
    for unit_name, c2_client in pairs(self.c2_clients) do
        self:BuildCommandAndControlMenu(c2_client, {troops=troops})
    end
end

function TROOPCOMMAND:__getDeployedTroopList()
    local troops = {}
    for _, troop in pairs(self.deployed_troops) do
        troops[#troops+1] = troop
    end
    table.sort(troops, function(x, y) return x.troop_name < y.troop_name end)
    return troops
end

-- Build C2 menu for client
function TROOPCOMMAND:BuildCommandAndControlMenu(c2_client, options)
    if c2_client.c2_submenu_item_ids ~= nil then
        for _, item_id in pairs(c2_client.c2_submenu_item_ids) do
            if item_id ~= nil then
                missionCommands.removeItemForGroup(c2_client.group_id, item_id)
            end
        end
    end
    c2_client.c2_submenu_item_ids = {}
    local parent_menu_id = c2_client.c2_submenu_id
    local current_menu_item_count = 0
    local troops = nil
    if options == nil or options["troops"] == nil then
        troops = self:__getDeployedTroopList()
    else
        troops = options["troops"]
    end
    for _, troop in ipairs(troops) do
        current_menu_item_count = current_menu_item_count + 1
        if current_menu_item_count == self.max_menu_items then
            local more_submenu_id = missionCommands.addSubMenuForGroup(c2_client.group_id, "More", parent_menu_id)
            if parent_menu_id == c2_client.c2_submenu_id then
                c2_client.c2_submenu_item_ids[#c2_client.c2_submenu_item_ids+1] = more_submenu_id
            end
            parent_menu_id = more_submenu_id
            current_menu_item_count = 1
        end
        local troop_menu_item_id = missionCommands.addSubMenuForGroup(c2_client.group_id, troop.troop_name, parent_menu_id)
        if parent_menu_id == c2_client.c2_submenu_id then
            c2_client.c2_submenu_item_ids[#c2_client.c2_submenu_item_ids+1] = troop_menu_item_id
        end
        if not __TROOPSHIP__isEmpty(self.routing_zones) then
            local routing_submenu_id = missionCommands.addSubMenuForGroup(c2_client.group_id, "Move to", troop_menu_item_id)
            local routing_item_parent_menu_id = routing_submenu_id
            local current_routing_menu_item_count = 0
            for _, zone in ipairs(self.routing_zones) do
                current_routing_menu_item_count = current_routing_menu_item_count + 1
                if current_routing_menu_item_count == self.max_menu_items then
                    local more_submenu_id = missionCommands.addSubMenuForGroup(c2_client.group_id, "More", routing_item_parent_menu_id)
                    routing_item_parent_menu_id = more_submenu_id
                    current_routing_menu_item_count = 1
                end
                missionCommands.addCommandForGroup(
                    c2_client.group_id,
                    string.format(zone.__TROOPSHIP__name),
                    routing_item_parent_menu_id,
                    function()
                        local target_coord = zone:GetCoordinate()
                        troop.moose_group:RouteGroundTo(target_coord, 14, "vee", 1)
                    end,
                    nil)
            end
        end
        local smoke_submenu_id = missionCommands.addSubMenuForGroup(c2_client.group_id, "Smoke", troop_menu_item_id)
        missionCommands.addCommandForGroup(
            c2_client.group_id,
            "Pop blue smoke",
            smoke_submenu_id,
            function()
                __TROOPSHIP__getFirstUnit(troop.moose_group):SmokeBlue()
            end,
            nil)
        missionCommands.addCommandForGroup(
            c2_client.group_id,
            "Pop green smoke",
            smoke_submenu_id,
            function()
                __TROOPSHIP__getFirstUnit(troop.moose_group):SmokeGreen()
            end,
            nil)
        missionCommands.addCommandForGroup(
            c2_client.group_id,
            "Pop orange smoke",
            smoke_submenu_id,
            function()
                __TROOPSHIP__getFirstUnit(troop.moose_group):SmokeOrange()
            end,
            nil)
        missionCommands.addCommandForGroup(
            c2_client.group_id,
            "Pop red smoke",
            smoke_submenu_id,
            function()
                __TROOPSHIP__getFirstUnit(troop.moose_group):SmokeRed()
            end,
            nil)
        local flare_submenu_id = missionCommands.addSubMenuForGroup(c2_client.group_id, "Flare", troop_menu_item_id)
        missionCommands.addCommandForGroup(
            c2_client.group_id,
            "Red flare",
            flare_submenu_id,
            function()
                __TROOPSHIP__getFirstUnit(troop.moose_group):FlareRed()
            end,
            nil)
        missionCommands.addCommandForGroup(
            c2_client.group_id,
            "White flare",
            flare_submenu_id,
            function()
                __TROOPSHIP__getFirstUnit(troop.moose_group):FlareGreen()
            end,
            nil)
        missionCommands.addCommandForGroup(
            c2_client.group_id,
            "Yellow flare",
            flare_submenu_id,
            function()
                __TROOPSHIP__getFirstUnit(troop.moose_group):FlareYellow()
            end,
            nil)
        local report_submenu_id = missionCommands.addSubMenuForGroup(c2_client.group_id, "Report", troop_menu_item_id)
        missionCommands.addCommandForGroup(
            c2_client.group_id,
            "Report status",
            report_submenu_id,
            function()
                local troop_status = self:GetTroopStatus(troop)
                local message = string.format("%s: %s", troop.troop_name, troop_status.composition_summary_with_kia)
                trigger.action.outTextForGroup(c2_client.group_id, message, 5, false)
            end,
            nil)
        missionCommands.addCommandForGroup(
            c2_client.group_id,
            "Kill a unit",
            troop_menu_item_id,
            function()
                local dcs_group = troop.moose_group:GetDCSObject()
                troop.moose_group:GetUnit(1):Destroy()
                local initial_size = dcs_group:getInitialSize()
                local current_size = dcs_group:getSize()
                local unit_count = 0
                for index, unit in pairs(dcs_group:getUnits()) do
                    unit_count = unit_count + 1
                    trigger.action.outTextForGroup(c2_client.group_id, string.format("Counting %s: %s %s", unit:getNumber(), index, unit_count), 1, false)
                end
                trigger.action.outTextForGroup(c2_client.group_id, string.format("Counts: %s %s %s", initial_size, current_size, unit_count), 5, false)
            end,
            nil)
        missionCommands.addCommandForGroup(
            c2_client.group_id,
            "Kill group",
            troop_menu_item_id,
            function()
                local dcs_group = troop.moose_group:GetDCSObject()
                for index, unit in pairs(dcs_group:getUnits()) do
                    unit:destroy()
                end
                trigger.action.outTextForGroup(c2_client.group_id, "Poof!", 5, false)
            end,
            nil)
    end
end

--------------------------------------------------------------------------------
-- TROOPSHIP

TROOPSHIP = {}
TROOPSHIP.__index = TROOPSHIP

setmetatable(TROOPSHIP, {
    __call = function (cls, ...)
        return cls.new(...)
    end,
})

-- Instantiate the main carrier object, bound to a unit
function TROOPSHIP.new(unit_name, troop_command, troopship_options)
    local self = setmetatable({}, TROOPSHIP)
    self.unit_name = unit_name -- troopship_options["unit_name"] or "Pilot #001"
    self.troop_command = troop_command -- troopship_options["troop_command"] or TROOPCOMMAND()
    if troopship_options == nil then
        troopship_options = {}
    end
    self.verbosity = troopship_options["verbosity"] or 3
    self.loadmaster_name = troopship_options["loadmaster_name"] or "Loadmaster"
    self.pickup_radius = troopship_options["pickup_radius"] or 100
    -- self.deploy_route_to_zone_names = troopship_options["deploy_route_to_zone_names"] or nil
    -- if self.deploy_route_to_zone_names then
    --     self.deploy_route_to_zones = __TROOPSHIP__getValidatedZonesFromNames(self.deploy_route_to_zone_names, nil)
    -- end
    self.deploy_route_to_zones = troopship_options["deploy_route_to_zones"] or nil
    self.is_disable_general_unload = false
    if troopship_options["is_disable_general_unload"] ~= nil then
        self.is_disable_general_unload = troopship_options["is_disable_general_unload"]
    end
    self.is_autoscan_on_touchdown = troopship_options["is_autoscan_on_touchdown"] or true
    self.is_autoreport_on_touchdown = troopship_options["is_autoreport_on_touchdown"] or true
    self.unit = Unit.getByName(self.unit_name)
    if not self.unit then
        error(string.format("Unit not found: '%s'", self.unit_name))
    end
    self.group = self.unit:getGroup()
    self.group_id = self.group:getID()
    self.moose_unit = CLIENT:FindByName(self.unit_name)
    self.moose_group = self.moose_unit:GetGroup()
    self.current_chalk = nil
    self.loading_time_per_unit = 1
    self.unloading_time_per_unit = 1
    self.pickup_unit_zone = ZONE_UNIT:New(string.format("%s Unit Zone", self.unit_name), self.moose_unit, self.pickup_radius)
    self.max_menu_items = 10
    self.load_management_submenu = missionCommands.addSubMenuForGroup(self.group_id, "Chalk", nil)
    self.available_for_pickup_submenu = missionCommands.addSubMenuForGroup(self.group_id, "Load", self.load_management_submenu)
    self.available_for_pickup_submenu_items = nil
    self.unload_submenu = missionCommands.addSubMenuForGroup(self.group_id, "Unload", self.load_management_submenu)
    self.unload_submenu_items = nil
    missionCommands.addCommandForGroup(
        self.group_id,
        "Report status",
        self.load_management_submenu,
        self.ReportLoadStatus,
        self)
    missionCommands.addCommandForGroup(
        self.group_id,
        "Scan for pick-up groups",
        self.load_management_submenu,
        function() self:ScanForPickupGroups{is_report_results=true} end,
        nil)
    self.air_status_check_fn_id = nil
    self.air_status_check_frequency = 3
    self.is_in_air_status = nil
    self:Start()
    return self
end

-- Should be called after a respawn/rebirth
function TROOPSHIP:Start()
    self:AirStatusMonitoringStart()
    if self.current_chalk ~= nil then
        -- Carrying a troop from a previous life ...
        -- We *could* catch the death event and spawn any chalks carried back
        -- at the original pick-up point to preserve the troop ...
        -- but I think here we are going to just erase them.
        self.troop_command:PurgeTroop(self.current_chalk)
        self.current_chalk = nil
    end
    self:ScanForPickupGroups{is_report_results=false, is_report_positive_results=false}
    self:RebuildUnloadMenu()
end

-- Should be called after death/unbirth
function TROOPSHIP:Stop()
    self:AirStatusMonitoringStop()
    if self.current_chalk ~= nil then
        -- Carrying a troop from a previous life ...
        -- We *could* catch the death event and spawn any chalks carried back
        -- at the original pick-up point to preserve the troop ...
        -- but I think here we are going to just erase them.
        self.troop_command:PurgeTroop(self.current_chalk)
        self.current_chalk = nil
    end
    self:ClearPickupMenu()
    self:ClearUnloadMenu()
end


-- Function to check if state changes from in air to land or vice versa
function TROOPSHIP:__checkInAirStatusChanged(time)
    local is_new_status_in_air = self.moose_unit:InAir()
    if is_new_status_in_air and not self.in_air then
        self:__onEventTakeOff()
    elseif (not is_new_status_in_air) and self.in_air then
        self:__onEventTouchDown()
    end
    -- For repeating this to work by returning time, cannot schedule using
    -- anonymous function as below; if you need to use an anonymous function,
    -- then the scheduled function must return nil and reschedule itself.
    -- self.air_status_check_fn_id = timer.scheduleFunction(function(args,
    -- time) self:__checkInAirStatusChanged(time) end, nil, timer.getTime() +
    -- self.air_status_check_frequency)
    return time + self.air_status_check_frequency
end

-- Function to check if state changes from in air to land or vice versa
function TROOPSHIP:__onEventTakeOff()
    self.in_air = true
    self:ClearPickupMenu()
    -- don't bother with enabling/disabling the unload menu to save
    -- computation; just block the action in a check if it is called while in
    -- the air
end

-- Function to check if state changes from in air to land or vice versa
function TROOPSHIP:__onEventTouchDown()
    self.in_air = false
    if self.current_chalk == nil and self.is_autoscan_on_touchdown then
        num_groups_found = self:ScanForPickupGroups{is_report_results=false, is_report_positive_results=false}
        if num_groups_found > 0 and self.is_autoreport_on_touchdown then
            local group_text = "groups"
            if num_groups == 1 then
                group_text = "group"
            end
            if self.verbosity >= 2 then
                self:__loadmasterMessage( string.format("%s %s in range for pick-up, sir!", num_groups_found, group_text) )
            end
        end
    end
    -- don't bother with enabling/disabling the unload menu to save
    -- computation; just block the action in a check if it is called while in
    -- the air
end

-- Check schedule
function TROOPSHIP:AirStatusMonitoringStart()
    if self.air_status_check_fn_id ~= nil then
        self:AirStatusMonitoringStop()
    end
    if self.moose_unit:InAir() then
        self.is_in_air_status = true
    else
        self.is_in_air_status = false
    end
    self.air_status_check_fn_id = timer.scheduleFunction(self.__checkInAirStatusChanged, self, timer.getTime() + self.air_status_check_frequency)
end

function TROOPSHIP:AirStatusMonitoringStop()
    if self.air_status_check_fn_id ~= nil then
        timer.removeFunction(self.air_status_check_fn_id)
    end
    self.air_status_check_fn_id = nil
end

-- Message
function TROOPSHIP:__loadmasterMessage(message)
    self.moose_unit:Message( message, 1, self.loadmaster_name )
end

-- Report current load
function TROOPSHIP:ReportLoadStatus()
    if self.current_chalk then
        self:__loadmasterMessage(string.format("Carrying %s, with %s", self.current_chalk.troop_name, self.current_chalk.troop_status.composition_summary))
    else
        self:__loadmasterMessage("No load, sir!")
    end
end

-- Scan for load
function TROOPSHIP:ScanForPickupGroups(args)
    local is_report_results = args["is_report_results"] or false
    local is_report_positive_results = args["is_report_positive_results"] or false
    self:ClearPickupMenu()
    if self.moose_unit:InAir() then
        if is_report_results then
            self:__loadmasterMessage("We're in the air, sir!")
        end
        return 0
    else
        spawners = self.troop_command:FindTroopSpawnZonesInVicinity(self.moose_unit)
        local num_spawners_found = #spawners
        troops = self.troop_command:FindDeployedTroopsInZone(self.pickup_unit_zone)
        local num_troops_found = #troops
        local num_available_found = num_spawners_found + num_troops_found
        if num_available_found > 0 then
            if is_report_results or is_report_positive_results then
                self:__loadmasterMessage(string.format("%s groups in pick-up range, sir!", num_available_found))
            end
            local parent_menu_id = self.available_for_pickup_submenu
            local current_menu_item_count = 0
            if num_spawners_found > 0 then
                for _, spawner in ipairs(spawners) do
                    current_menu_item_count = current_menu_item_count + 1
                    if current_menu_item_count == self.max_menu_items then
                        local more_submenu_id = missionCommands.addSubMenuForGroup(self.group_id, "More", parent_menu_id)
                        if parent_menu_id == self.available_for_pickup_submenu then
                            self.available_for_pickup_submenu_items[#self.available_for_pickup_submenu_items+1] = more_submenu_id
                        end
                        parent_menu_id = more_submenu_id
                        current_menu_item_count = 1
                    end
                    local menu_text = string.format("%s (New)", spawner:GetNextSpawnedTroopName())
                    local menu_item = missionCommands.addCommandForGroup(
                        self.group_id,
                        menu_text,
                        parent_menu_id, -- submenu
                        function()
                            local troop = spawner:Spawn()
                            self:LoadTroops(troop)
                        end,
                        nil)
                    if parent_menu_id == self.available_for_pickup_submenu then
                        self.available_for_pickup_submenu_items[#self.available_for_pickup_submenu_items+1] = menu_item
                    end
                end
            end
            if num_troops_found > 0 then
                for _, troop in ipairs(troops) do
                    current_menu_item_count = current_menu_item_count + 1
                    if current_menu_item_count == self.max_menu_items then
                        local more_submenu_id = missionCommands.addSubMenuForGroup(self.group_id, "More", parent_menu_id)
                        if parent_menu_id == self.available_for_pickup_submenu then
                            self.available_for_pickup_submenu_items[#self.available_for_pickup_submenu_items+1] = more_submenu_id
                        end
                        parent_menu_id = more_submenu_id
                        current_menu_item_count = 1
                    end
                    local menu_text = string.format("%s", troop.troop_name)
                    local menu_item = missionCommands.addCommandForGroup(
                        self.group_id,
                        menu_text,
                        parent_menu_id, -- submenu
                        function() self:LoadTroops(troop) end,
                        nil)
                    if parent_menu_id == self.available_for_pickup_submenu then
                        self.available_for_pickup_submenu_items[#self.available_for_pickup_submenu_items+1] = menu_item
                    end
                end
            end
        else
            if is_report_results then
                self:__loadmasterMessage("No groups in pick-up range, sir!")
            end
        end
        return num_available_found
    end
end

-- Clear pick-up menu
function TROOPSHIP:ClearPickupMenu()
    if not __TROOPSHIP__isEmpty(self.available_for_pickup_submenu_items) then
        for _, item in pairs(self.available_for_pickup_submenu_items) do
            missionCommands.removeItemForGroup(self.group_id, item)
        end
    end
    self.available_for_pickup_submenu_items = {}
end

-- Clear pick-up menu
function TROOPSHIP:ClearUnloadMenu()
    if not __TROOPSHIP__isEmpty(self.unload_submenu_items) then
        for _, item in pairs(self.unload_submenu_items) do
            missionCommands.removeItemForGroup(self.group_id, item)
        end
    end
    self.unload_submenu_items = {}
end

-- Rebuilt unload menu
function TROOPSHIP:RebuildUnloadMenu()
    self:ClearUnloadMenu()
    if self.current_chalk == nil or self.moose_unit:InAir() then
        return
    else
        local menu_text = "Unload"
        if not self.is_disable_general_unload then
            local item = missionCommands.addCommandForGroup(
                self.group_id,
                menu_text,
                self.unload_submenu,
                function() self:UnloadTroops({}) end,
                nil)
            self.unload_submenu_items[menu_text] = item
        end
        if self.deploy_route_to_zones then
            for _, deploy_route_to_zone in ipairs(self.deploy_route_to_zones) do
                menu_text = string.format("Unload to %s", deploy_route_to_zone.__TROOPSHIP__name)
                local item = missionCommands.addCommandForGroup(
                    self.group_id,
                    menu_text,
                    self.unload_submenu,
                    function() self:UnloadTroops{deploy_route_to_zone=deploy_route_to_zone} end,
                    nil)
                self.unload_submenu_items[menu_text] = item
            end
        end
    end
end

-- Load a group
function TROOPSHIP:LoadTroops(troop)
    if self.moose_unit:InAir() then
        self:__loadmasterMessage("Cannot load up while we are in the air, sir!")
    elseif self.current_chalk ~= nil then
        self:__loadmasterMessage("We are already loaded up, sir!")
    elseif troop.moose_group:IsNotInZone(self.pickup_unit_zone) then
        self:__loadmasterMessage("Group has moved away, sir!")
        self:ScanForPickupGroups{is_report_results=false, is_report_positive_results=false}
    else
        if self.verbosity >= 1 then
            self:__loadmasterMessage( string.format("Loading %s, sir!", troop.troop_name) )
        end
        if troop.troop_source == "existing-group" then
            local dcs_group = troop.moose_group:GetDCSObject()
            -- record units that are alive, so dead ones can be removed from
            -- respawned group
            local current_unit_ids = {}
            for index, unit in pairs(dcs_group:getUnits()) do
                current_unit_ids[unit:getNumber()] = true
            end
            troop.current_unit_ids = current_unit_ids
            troop.num_units = troop.moose_group:GetSize()
            troop.troop_status = self.troop_command:GetTroopStatus(troop)
            self.current_chalk = troop
        else
            error(string.format("Unrecognized troop source: '%s'", troop.troop_source))
        end
        timer.scheduleFunction(
            function(args, time)
                return self:__executeLoadTransfer({
                    num_units=troop.num_units,
                    transfer_fn=function()
                        self.troop_command:WithdrawTroop(troop.troop_id)
                        troop.moose_group:GetDCSObject():destroy()
                        self:ClearPickupMenu()
                        self:RebuildUnloadMenu()
                    end,
                    success_message="Loading complete, sir!",
                    cancel_message="Loading aborted, sir!",
                    num_units_transferred=0,
                    transfer_time_per_unit=self.loading_time_per_unit,
                    time=time})
            end,
            nil,
            timer.getTime() + self.loading_time_per_unit
            )
    end
end

-- unload a group
function TROOPSHIP:UnloadTroops(args)
    local direct_to_zone = args["deploy_route_to_zone"] or nil
    if self.current_chalk == nil then
        self:__loadmasterMessage("We are not carrying a load, sir!")
    elseif self.moose_unit:InAir() then
        self:__loadmasterMessage("Cannot unload while we are in the air, sir!")
    else
        self:__loadmasterMessage("Unloading, sir!")
        timer.scheduleFunction(
            function(args, time)
                return self:__executeLoadTransfer({
                    num_units=self.current_chalk.num_units,
                    transfer_fn=function()
                        -- local group = self.current_chalk.moose_group_spawner:SpawnFromUnit(self.moose_unit)
                        local moose_group = nil
                        moose_group = self.current_chalk.group_spawner:SpawnFromUnit(self.moose_unit)
                        if self.current_chalk.troop_source == "existing-group" then
                            -- remove dead units from group
                            local dcs_group = moose_group:GetDCSObject()
                            for index, unit in pairs(dcs_group:getUnits()) do
                                if self.current_chalk.current_unit_ids[unit:getNumber()] == nil then
                                    unit:destroy()
                                end
                            end
                            self.current_chalk.current_unit_ids = nil
                            self.troop_command:RestoreTroop{
                                troop_id=self.current_chalk.troop_id,
                                update_group=moose_group}
                        else
                            error(string.format("Unrecognized troop source: '%s'", self.current_chalk.troop_source))
                        end
                        if direct_to_zone == nil and self.current_chalk.deploy_route_to_zone ~= nil then
                            direct_to_zone = self.current_chalk.deploy_route_to_zone
                        end
                        if direct_to_zone ~= nil then
                            -- local target_coord = deploy_route_to_zone:GetRandomCoordinate()
                            local target_coord = direct_to_zone:GetCoordinate()
                            moose_group:RouteGroundTo(target_coord, self.current_chalk.deploy_route_to_speed, self.current_chalk.deploy_route_to_formation, 1)
                        end
                        self.current_chalk = nil
                        self:ClearUnloadMenu()
                        self:ScanForPickupGroups{is_report_results=false, is_report_positive_results=false}
                    end,
                    success_message="Unloading complete, sir!",
                    cancel_message="Unloading aborted, sir!",
                    num_units_transferred=0,
                    transfer_time_per_unit=self.loading_time_per_unit,
                    time=time})
            end,
            nil,
            timer.getTime() + self.loading_time_per_unit
            )
    end
end

function TROOPSHIP:__executeLoadTransfer(args)
    local num_units = args["num_units"]
    local transfer_fn = args["transfer_fn"]
    local success_message = args["success_message"]
    local cancel_message = args["cancel_message"]
    local num_units_transferred = args["num_units_transferred"] or 0
    local transfer_time_per_unit = args["transfer_time_per_unit"] or 1
    local time = args["time"]
    if self.moose_unit:InAir() then
        self:__loadmasterMessage(cancel_message)
        return nil
    else
        num_units_transferred = num_units_transferred + 1
        if num_units_transferred < num_units then
            if self.verbosity >= 2 and num_units ~= nil and num_units_transferred ~= nil and transfer_time_per_unit then
                local estimated_time_remaining = math.ceil((num_units - num_units_transferred) * transfer_time_per_unit)
                if num_units_transferred == 1 and estimated_time_remaining <= 3 then
                elseif num_units_transferred == 1 and estimated_time_remaining <= 5 then
                    self:__loadmasterMessage("A few seconds to go, sir!")
                elseif num_units_transferred == 1 and estimated_time_remaining <= 10 then
                    self:__loadmasterMessage("Less than 10 seconds to go, sir!")
                elseif num_units_transferred == 1 and estimated_time_remaining <= 20 then
                    self:__loadmasterMessage("Less than 20 seconds to go, sir!")
                elseif num_units_transferred == 1 and estimated_time_remaining <= 30 then
                    self:__loadmasterMessage("Less than 30 seconds to go, sir!")
                elseif num_units_transferred == 1 and estimated_time_remaining <= 60 then
                    self:__loadmasterMessage("Less than a minute to go, sir!")
                elseif estimated_time_remaining > 60 and ( (estimated_time_remaining % 60 == 0) or (num_units_transferred == 1) ) then
                    self:__loadmasterMessage(string.format("%s minutes to go, sir!", math.floor(estimated_time_remaining/60)), 1, "FlightEngineer")
                elseif estimated_time_remaining == 60 then
                    self:__loadmasterMessage("1 minute to go, sir!")
                elseif estimated_time_remaining == 30 then
                    self:__loadmasterMessage("30 seconds to go, sir!")
                elseif estimated_time_remaining == 10 then
                    self:__loadmasterMessage("10 seconds to go, sir!")
                elseif estimated_time_remaining == 5 then
                    self:__loadmasterMessage("5 seconds to go, sir!")
                end
            end
            timer.scheduleFunction(
                function(args, time)
                    self:__executeLoadTransfer({
                        num_units=num_units,
                        transfer_fn=transfer_fn,
                        success_message=success_message,
                        cancel_message=cancel_message,
                        num_units_transferred=num_units_transferred,
                        transfer_time_per_unit=transfer_time_per_unit,
                        time=time})
                end,
                nil,
                time + transfer_time_per_unit
                )
            return nil
        else
            transfer_fn()
            self:__loadmasterMessage(success_message)
            return nil
        end
    end
end

