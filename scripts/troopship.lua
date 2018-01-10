--------------------------------------------------------------------------------
--  __troopship.TROOPSHIP - Tactical Airmobile Operations Mission Development Scripting
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

__troopship = {}

__troopship.utils = {}

function __troopship.utils.isEmpty(t)
    if t == nil then
        return true
    elseif next(t) == nil then
        return true
    else
        return false
    end
end

function __troopship.utils.getValidatedZoneFromName(zone_name, default)
    if zone_name == nil then
        return default
    end
    -- local z = trigger.misc.getZone(zone_name)
    -- if not z then
    --     return default
    -- end
    local ok, zone = pcall(function() return ZONE:New(zone_name) end)
    if ok then
        zone.display_name = zone:GetName()
        return zone
    else
        return default
    end
end

function __troopship.utils.getValidatedZonesFromNames(zone_names, default)
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
            zone.display_name = zone:GetName()
            zones[zone_count] = zone
        end
        -- end
    end
    if __troopship.utils.isEmpty(zones) then
        return default
    else
        table.sort(zones, function(x,y) return x.display_name < y.display_name end)
        return zones
    end
end

function __troopship.utils.getMaxSpeedOfSlowestUnit(moose_group)
    local max_speed_of_slowest_unit = nil
    local dcs_group = moose_group:GetDCSObject()
    for index, unit in pairs(dcs_group:getUnits()) do
        local unit_speed = unit:getDesc().speedMax
        if max_speed_of_slowest_unit == nil then
            max_speed_of_slowest_unit = unit_speed
        elseif unit_speed < max_speed_of_slowest_unit then
            max_speed_of_slowest_unit = unit_speed
        end
    end
    return max_speed_of_slowest_unit
end

function __troopship.utils.getFirstUnit(moose_group)
    return moose_group:GetUnit(1)
    -- for _, unit in pairs( moose_group:GetUnits() ) do
    --     return unit
    -- end
end

-- adapted from Ciribob's EXCELLENT CTLD script https://github.com/ciribob/DCS-CTLD
--get distance in meters assuming a Flat world
function __troopship.utils.pointDistance(point1, point2)

    local xUnit = point1.x
    local yUnit = point1.z
    local xZone = point2.x
    local yZone = point2.z

    local xDiff = xUnit - xZone
    local yDiff = yUnit - yZone

    return math.sqrt(xDiff * xDiff + yDiff * yDiff)
end

-- adapted from Ciribob's EXCELLENT CTLD script https://github.com/ciribob/DCS-CTLD
-- returns nil if no enemy in range
function __troopship.utils.nearestEnemyPosition(moose_unit, maximum_search_distance)
    if maximum_search_distance == nil then
        maximum_search_distance = 2000
    end
    local dcs_unit = moose_unit:GetDCSObject()
    local dcs_unit_point = dcs_unit:getPoint()
    local nearest_enemy_unit = nil
    local nearest_enemy_point = nil
    local nearest_enemy_dist = maximum_search_distance + 1
    local dcs_groups = nil
    if dcs_unit:getCoalition() == coalition.side.RED then
        dcs_groups = coalition.getGroups(coalition.side.BLUE, Group.Category.GROUND)
    else
        dcs_groups = coalition.getGroups(coalition.side.RED, Group.Category.GROUND)
    end
    for _, dcs_group in pairs(dcs_groups) do
        if dcs_group ~= nil then
            local focal_enemy_unit = nil
            for index, unit in ipairs(dcs_group:getUnits()) do
                if unit:getLife() >= 1 then
                    focal_enemy_unit = unit
                    break
                end
            end
            if focal_enemy_unit ~= nil then
                local enemy_point = focal_enemy_unit:getPoint() -- vec3
                local enemy_position = focal_enemy_unit:getPosition() -- vec2
                local enemy_dist = __troopship.utils.pointDistance(dcs_unit_point, enemy_point)
                if enemy_dist < nearest_enemy_dist then
                    nearest_enemy_unit = focal_enemy_unit
                    nearest_enemy_point = enemy_point
                    nearest_enemy_position = enemy_position
                    nearest_enemy_dist = enemy_dist
                end
            end
        end
    end
    if nearest_enemy_unit ~= nil then
        return {unit=nearest_enemy_unit, point=nearest_enemy_point, position=nearest_enemy_position, dist=nearest_enemy_dist}
    else
        return nil
    end
end

-- adapted from Ciribob's EXCELLENT CTLD script https://github.com/ciribob/DCS-CTLD
function __troopship.utils.moveGroupToNearestEnemyPosition(moose_group, maximum_search_distance)
    local moose_unit = moose_group:GetUnit(1)
    local results = __troopship.utils.nearestEnemyPosition(moose_unit, maximum_search_distance)
    if results ~= nil then
        -- moose_group:RouteToVec3(results.point, 999)
        moose_group:OptionAlarmStateAuto()
        -- moose_group:GetDCSObject():setOption(
        --     AI.Option.Ground.id.ALARM_STATE,
        --     AI.Option.Ground.val.ALARM_STATE.AUTO )
        moose_group:TaskRouteToVec2({x=results.point.x, y=results.point.z}, 999, "Off road")
    end
    return results
end

function __troopship.utils.composeLLDDM(point)
    local lat, lon = coord.LOtoLL(point)
    return UTILS.tostringLL(lat, lon, 3, false)
    -- UTILS.tostringLL = function( lat, lon, acc, DMS)
    -- UTILS.tostringLL( lat, lon, LL_Accuracy, true ) -- in DMS
    -- UTILS.tostringLL( lat, lon, LL_Accuracy, false ) -- in DDM
end

--------------------------------------------------------------------------------
-- __troopship.DynamicTroopSpawner

__troopship.DynamicTroopSpawner = {}
__troopship.DynamicTroopSpawner.__index = __troopship.DynamicTroopSpawner

setmetatable(__troopship.DynamicTroopSpawner, {
    __call = function (cls, ...)
        return cls.new(...)
    end,
})

function __troopship.DynamicTroopSpawner.new(
        name,
        zone_name,
        template_group_name,
        troop_command,
        troop_options)
    local self = setmetatable({}, __troopship.DynamicTroopSpawner)
    self.spawner_name = name
    self.spawn_zone_name = zone_name
    self.spawn_zone = __troopship.utils.getValidatedZoneFromName(self.spawn_zone_name)
    if self.spawn_zone == nil then
        error(string.format("Cannot find zone '%s", self.spawn_zone_name))
    end
    self.template_group_name = template_group_name
    self.template_moose_group = GROUP:FindByName(self.template_group_name)
    if not self.template_moose_group then
        error(string.format("Cannot find group '%s", self.template_group_name))
    end
    self.troop_command = troop_command
    self.troop_options = troop_options
    if self.troop_options == nil then
        self.troop_options = {}
    end
    self.troop_spawner = SPAWN:NewWithAlias(self.template_group_name, string.format("%s ", self.spawner_name))
    self.spawned_count = 0
    return self
end
--
-- Return true if unit is in zone
function __troopship.DynamicTroopSpawner:IsUnitInZone(moose_unit)
    return moose_unit:IsInZone(self.spawn_zone)
end

-- Return name of next spawned troop
function __troopship.DynamicTroopSpawner:GetNextSpawnedTroopName()
    return string.format("%s #%03d", self.spawner_name, self.spawned_count + 1)
end

-- Spawn a new troop
function __troopship.DynamicTroopSpawner:Spawn()
    local spawned_troop_name = self:GetNextSpawnedTroopName()
    self.spawned_count = self.spawned_count + 1
    local moose_group = self.troop_spawner:SpawnInZone(self.spawn_zone)
    if moose_group == nil then
        error("Failed to spawn group")
    end
    troop_options = {}
    for k, v in pairs(self.troop_options) do
        troop_options[k] = v
    end
    troop_options.troop_name = spawned_troop_name
    return self.troop_command:__registerGroupAsTroop(moose_group, self.troop_options)
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
    self.coalition = coalition -- coalition.side.RED or coalition.side.BLUE; used for coalition-wide messages
    if options == nil then
        options = {}
    end
    -- If > 1 then troops will report when they arrive at their routing/navigation zones.
    -- Set to 0 to increase performance, especially if there are a lot of
    -- troops moving around a lot.
    if options["troop_navigation_feedback_verbosity"] ~= nil then
        self.troop_navigation_feedback_verbosity = options["troop_navigation_feedback_verbosity"]
    else
        self.troop_navigation_feedback_verbosity = 1
    end
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
    --  world.event = {
    --      S_EVENT_INVALID = 0,
    --      S_EVENT_SHOT = 1,
    --      S_EVENT_HIT = 2,
    --      S_EVENT_TAKEOFF = 3,
    --      S_EVENT_LAND = 4,
    --      S_EVENT_CRASH = 5,
    --      S_EVENT_EJECTION = 6,
    --      S_EVENT_REFUELING = 7,
    --      S_EVENT_DEAD = 8,
    --      S_EVENT_PILOT_DEAD = 9,
    --      S_EVENT_BASE_CAPTURED = 10,
    --      S_EVENT_MISSION_START = 11,
    --      S_EVENT_MISSION_END = 12,
    --      S_EVENT_TOOK_CONTROL = 13,
    --      S_EVENT_REFUELING_STOP = 14,
    --      S_EVENT_BIRTH = 15,
    --      S_EVENT_HUMAN_FAILURE = 16,
    --      S_EVENT_ENGINE_STARTUP = 17,
    --      S_EVENT_ENGINE_SHUTDOWN = 18,
    --      S_EVENT_PLAYER_ENTER_UNIT = 19,
    --      S_EVENT_PLAYER_LEAVE_UNIT = 20,
    --      S_EVENT_PLAYER_COMMENT = 21,
    --      S_EVENT_SHOOTING_START = 22,
    --      S_EVENT_SHOOTING_END = 23,
    --      S_EVENT_MAX = 24
    --      }
    --  Relevant Events:
    --      19, world.event.S_EVENT_PLAYER_ENTER_UNIT = Occurs when any player assumes direct control of a unit.
    --      15, world.event.S_EVENT_BIRTH = Occurs when any object is spawned into the mission
    --      20, world.event.S_EVENT_PLAYER_LEAVE_UNIT = Occurs when any player relieves control of a unit
    --      8, world.event.S_EVENT_DEAD = Occurs when an object is completely destroyed.
    --  When player leaves slot: 20 is fired, but not 8
    --  When players enters aircraft: 19 and 15
    --  Leave slot and respawn: 20, 19, 15, 17
    --  Crash and die: 3, 16, 9, 5
    --  Crash and die: 2,8,9,5
    -- if event.id == world.event.S_EVENT_BIRTH then
    if event.id == world.event.S_EVENT_TOOK_CONTROL
            or event.id ==  world.event.S_EVENT_PLAYER_ENTER_UNIT then
        local unit_name = event.initiator:getName()
        if self.unrealized_troopship_options[unit_name] ~= nil then
            self:__createTroopship(unit_name, self.unrealized_troopship_options[unit_name])
        elseif self.troopships[unit_name] ~= nil then
            self.troopships[unit_name]:Start()
        end
        if self.unrealized_c2ship_options[unit_name] ~= nil then
            self:__createCommandAndControlShip(unit_name, self.unrealized_c2ship_options[unit_name])
        elseif self.c2ships[unit_name] ~= nil then
            self:BuildCommandAndControlMenu(self.c2ships[unit_name]) -- should not need this, as TROOPCOMMAND automatically updates all C2 clients continuously
        end
    elseif event.id == world.event.S_EVENT_PLAYER_LEAVE_UNIT
            or event.id == world.event.S_EVENT_PILOT_DEAD
            -- or event.id == world.event.S_EVENT_EJECTION
            -- or event.id == world.event.S_EVENT_CRASH
            -- or event.id == world.event.S_EVENT_DEAD
            -- or event.id == world.event.S_EVENT_PLAYER_LEAVE_UNIT then
            then
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
    if __troopship.utils.isEmpty(zone_names) then return end
    for _, zone_name in pairs(zone_names) do
        local zone = __troopship.utils.getValidatedZoneFromName(zone_name)
        if zone ~= nil then
            self.routing_zones[#self.routing_zones+1] = zone
        end
    end
    if not __troopship.utils.isEmpty(self.routing_zones) then
        table.sort(self.routing_zones, function(x,y) return x.display_name < y.display_name end)
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

-- Service function to create __troopship.TROOPSHIP object
function TROOPCOMMAND:__createTroopship(unit_name, troopship_options)
    local unit = Unit.getByName(unit_name)
    if unit == nil then
        self.unrealized_troopship_options[unit_name] = troopship_options
        self.troopships[unit_name] = nil
    else
        local troopship = __troopship.TROOPSHIP(unit_name, self, troopship_options)
        self.troopships[unit_name] = troopship
        self.unrealized_troopship_options[unit_name] = nil
    end
end

-- Troop Registration/Management --

-- Register an existing group as a valid troop, specified by group name
function TROOPCOMMAND:RegisterTroop(group_name, troop_options)
    local moose_group = GROUP:FindByName(group_name)
    if moose_group == nil then
        -- error(string.format("Cannot find group '%s'", group_name))
        return
    else
        return self:__registerGroupAsTroop(moose_group, troop_options)
    end
end

-- Calculate a troop id
function TROOPCOMMAND:GetTroopStatus(troop)
    local dcs_group = troop.moose_group:GetDCSObject()
    category_counts = {}
    ammo_states = {}
    for index, unit in pairs(dcs_group:getUnits()) do
        local type_name = unit:getTypeName()
        if not category_counts[type_name] then
            category_counts[type_name] = 1
        else
            category_counts[type_name] = category_counts[type_name] + 1
        end
        for _, ammo_type_table in pairs(unit:getAmmo()) do
            local key = ammo_type_table.desc.displayName
            if not ammo_states[key] then
                ammo_states[key] = ammo_type_table.count
            else
                ammo_states[key] = ammo_states[key] + ammo_type_table.count
            end
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
    local ammo_desc_table = {}
    for key, count in pairs(ammo_states) do
        ammo_desc_table[1+#ammo_desc_table] = string.format("%s x %s", count, key)
    end
    ammo_desc = table.concat(ammo_desc_table, ", ")
    return {
        composition_summary=composition_summary,
        composition_summary_with_kia=composition_summary_with_kia,
        initial_size=initial_size,
        current_size=current_size,
        ammo_desc=ammo_desc,
    }
end

-- Calculate a troop id
function TROOPCOMMAND:__calcTroopID(moose_group)
    local troop_id = moose_group:GetDCSObject():getID()
    return troop_id
end

-- Register a (MOOSE) group as a valid troop
function TROOPCOMMAND:__registerGroupAsTroop(moose_group, troop_options)
    if troop_options == nil then
        troop_options = {}
    end
    local troop_name = troop_options["troop_name"] or moose_group:GetName()
    local troop_id = self:__calcTroopID(moose_group)
    local deploy_route_to_zone_name = troop_options["deploy_route_to_zone_name"] or nil
    if deploy_route_to_zone_name ~= nil then
        deploy_route_to_zone = __troopship.utils.getValidatedZoneFromName(deploy_route_to_zone_name, nil)
    end
    is_transportable = true
    if troop_options["is_transportable"] ~= nil then
        is_transportable = troop_options["is_transportable"]
    end
    is_commandable = true
    if troop_options["is_commandable"] ~= nil then
        is_commandable = troop_options["is_commandable"]
    end
    self.deployed_troops[troop_id] = {
            troop_id=troop_id,
            troop_name=troop_name,
            troop_source="existing-group",
            moose_group=moose_group,
            -- coalition=moose_group:GetCoalition(),
            coalition=self.coalition,
            group_spawner=SPAWN:New(moose_group:GetName()),
            loading_time_per_unit=troop_options[loading_time_per_unit] or 1,
            unloading_time_per_unit=troop_options[unloading_time_per_unit] or 1,
            load_cost=troop_options["load_cost"] or 0,
            restrict_to_carry_types=troop_options["restrict_to_carry_types"] or nil,
            -- group_size=moose_group:GetSize(),
            deploy_route_to_zone=deploy_route_to_zone,
            deploy_route_to_zone_name=deploy_route_to_zone_name,
            movement_speed=troop_options["movement_speed"] or 999,
            movement_formation=troop_options["movement_formation"] or "Off road",
            maximum_search_distance=troop_options["maximum_search_distance"] or 2000, -- max distance that troops search for enemy
            is_transportable=is_transportable,
            is_commandable=is_commandable,
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
function TROOPCOMMAND:CreateTroopSpawner(
        name,
        zone_name,
        template_group_name,
        troop_options)
    self.dynamic_troop_spawners[#self.dynamic_troop_spawners+1] = __troopship.DynamicTroopSpawner(
            name,
            zone_name,
            template_group_name,
            self,
            troop_options)
end

-- Return array of groups in zone
function TROOPCOMMAND:FindLoadableTroopsInZone(zone)
    local results = {}
    for troop_id, troop in pairs(self.deployed_troops) do
        -- if troop.moose_group:IsCompletelyInZone(zone) then
        -- if troop.moose_group:IsPartlyInZone(zone) then -- note: false if all units are in zone
        -- if troop.moose_group:IsCompletelyInZone(zone) or troop.moose_group:IsPartlyInZone(zone) then
        if troop.is_transportable and not troop.moose_group:IsNotInZone(zone) then
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
                    coalition=unit:getCoalition(),
                }
        self.c2_clients[unit_name] = c2_client
        c2_client.c2_submenu_id = missionCommands.addSubMenuForGroup(c2_client.group_id, "Troop C&C", nil)
        c2_client.c2_submenu_item_ids = nil
        self:BuildCommandAndControlMenu(c2_client)
        if c2ship_options["post_create_fn"] ~= nil then
            c2ship_options["post_create_fn"](c2_client)
        end
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
        if troop.is_commandable then
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
            local advance_to_submenu_id = missionCommands.addSubMenuForGroup(c2_client.group_id, "Advance", troop_menu_item_id)
            for di, direction in pairs({"North", "Northeast", "East", "Southeast", "South", "Southwest", "West", "Northwest"}) do
                local compass_direction_submenu_id = missionCommands.addSubMenuForGroup(c2_client.group_id, direction, advance_to_submenu_id)
                for ds, distance in pairs({0.25, 0.5, 1, 2, 5, 10, 15, 20, 40}) do
                    missionCommands.addCommandForGroup(
                        c2_client.group_id,
                        string.format("%s clicks", distance),
                        compass_direction_submenu_id,
                        function()
                            local point = troop.moose_group:GetDCSObject():getUnit(1):getPoint()
                            if point ~= nil then
                                if false then
                                elseif direction == "North" then
                                    point.x = point.x + math.floor(distance * 1000)
                                elseif direction == "Northeast" then
                                    point.x = point.x + math.floor(distance * 1000)
                                    point.z = point.z + math.floor(distance * 1000)
                                elseif direction == "East" then
                                    point.z = point.z + math.floor(distance * 1000)
                                elseif direction == "Southeast" then
                                    point.x = point.x - math.floor(distance * 1000)
                                    point.z = point.z + math.floor(distance * 1000)
                                elseif direction == "South" then
                                    point.x = point.x - math.floor(distance * 1000)
                                elseif direction == "Southwest" then
                                    point.x = point.x - math.floor(distance * 1000)
                                    point.z = point.z - math.floor(distance * 1000)
                                elseif direction == "West" then
                                    point.z = point.z - math.floor(distance * 1000)
                                elseif direction == "Northwest" then
                                    point.x = point.x + math.floor(distance * 1000)
                                    point.z = point.z - math.floor(distance * 1000)
                                end
                                -- troop.moose_group:RouteToVec3(point, 999)
                                troop.moose_group:TaskRouteToVec2({x=point.x, y=point.z}, 999, "Off road")
                                trigger.action.outTextForCoalition(c2_client.coalition, string.format("%s: moving %s for %s clicks to %s!", troop.troop_name, direction, distance, __troopship.utils.composeLLDDM(point)), 2 )
                            end
                        end,
                        nil)
                end
            end
            missionCommands.addCommandForGroup(
                c2_client.group_id,
                "Toward nearest enemy",
                advance_to_submenu_id,
                function()
                    local results = __troopship.utils.moveGroupToNearestEnemyPosition(troop.moose_group, troop.maximum_search_distance)
                    if results ~= nil then
                        trigger.action.outTextForCoalition(c2_client.coalition, string.format("%s: moving to engage enemy at: %s", troop.troop_name, __troopship.utils.composeLLDDM(results.point)), 2 )
                    else
                        trigger.action.outTextForGroup(c2_client.group_id, string.format("%s: no enemy detected in vicinity!", troop.troop_name), 2)
                    end
                end,
                nil)
            if not __troopship.utils.isEmpty(self.routing_zones) then
                local routing_submenu_id = missionCommands.addSubMenuForGroup(c2_client.group_id, "Navigate to", troop_menu_item_id)
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
                        string.format(zone.display_name),
                        routing_item_parent_menu_id,
                        function()
                            -- local target_coord = zone:GetCoordinate()
                            -- troop.moose_group:RouteGroundTo(target_coord, troop.movement_speed, troop.movement_formation, 1)
                            trigger.action.outTextForCoalition(c2_client.coalition, string.format("%s: Moving to %s", troop.troop_name, zone.display_name), 2 )
                            self:SendGroupToZone(troop, zone)
                        end,
                        nil)
                end
            end
            missionCommands.addCommandForGroup(
                c2_client.group_id,
                "Hold position",
                troop_menu_item_id,
                function()
                    local task = troop.moose_group:TaskHold()
                    troop.moose_group:SetTask(task)
                    local point = troop.moose_group:GetDCSObject():getUnit(1):getPoint()
                    trigger.action.outTextForCoalition(c2_client.coalition, string.format("%s: Holding position at %s", troop.troop_name, __troopship.utils.composeLLDDM(point)), 2 )
                end,
                nil)
            local smoke_submenu_id = missionCommands.addSubMenuForGroup(c2_client.group_id, "Smoke", troop_menu_item_id)
            missionCommands.addCommandForGroup(
                c2_client.group_id,
                "Pop blue smoke",
                smoke_submenu_id,
                function()
                    __troopship.utils.getFirstUnit(troop.moose_group):SmokeBlue()
                end,
                nil)
            missionCommands.addCommandForGroup(
                c2_client.group_id,
                "Pop green smoke",
                smoke_submenu_id,
                function()
                    __troopship.utils.getFirstUnit(troop.moose_group):SmokeGreen()
                end,
                nil)
            missionCommands.addCommandForGroup(
                c2_client.group_id,
                "Pop orange smoke",
                smoke_submenu_id,
                function()
                    __troopship.utils.getFirstUnit(troop.moose_group):SmokeOrange()
                end,
                nil)
            missionCommands.addCommandForGroup(
                c2_client.group_id,
                "Pop red smoke",
                smoke_submenu_id,
                function()
                    __troopship.utils.getFirstUnit(troop.moose_group):SmokeRed()
                end,
                nil)
            local flare_submenu_id = missionCommands.addSubMenuForGroup(c2_client.group_id, "Flare", troop_menu_item_id)
            missionCommands.addCommandForGroup(
                c2_client.group_id,
                "Red flare",
                flare_submenu_id,
                function()
                    __troopship.utils.getFirstUnit(troop.moose_group):FlareRed()
                end,
                nil)
            missionCommands.addCommandForGroup(
                c2_client.group_id,
                "White flare",
                flare_submenu_id,
                function()
                    __troopship.utils.getFirstUnit(troop.moose_group):FlareGreen()
                end,
                nil)
            missionCommands.addCommandForGroup(
                c2_client.group_id,
                "Yellow flare",
                flare_submenu_id,
                function()
                    __troopship.utils.getFirstUnit(troop.moose_group):FlareYellow()
                end,
                nil)
            local report_submenu_id = missionCommands.addSubMenuForGroup(c2_client.group_id, "Report", troop_menu_item_id)
            missionCommands.addCommandForGroup(
                c2_client.group_id,
                "Status",
                report_submenu_id,
                function()
                    local troop_status = self:GetTroopStatus(troop)
                    local message = string.format("%s: %s", troop.troop_name, troop_status.composition_summary_with_kia)
                    trigger.action.outTextForGroup(c2_client.group_id, message, 5, false)
                end,
                nil)
            missionCommands.addCommandForGroup(
                c2_client.group_id,
                "Ammo",
                report_submenu_id,
                function()
                    local troop_status = self:GetTroopStatus(troop)
                    local message = string.format("%s: %s", troop.troop_name, troop_status.ammo_desc)
                    trigger.action.outTextForGroup(c2_client.group_id, message, 5, false)
                end,
                nil)
            local options_submenu_id = missionCommands.addSubMenuForGroup(c2_client.group_id, "Set", troop_menu_item_id)
            local alarm_state_submenu_id = missionCommands.addSubMenuForGroup(c2_client.group_id, "Alarm state", options_submenu_id)
            missionCommands.addCommandForGroup(
                c2_client.group_id,
                "Auto",
                alarm_state_submenu_id,
                function()
                    troop.moose_group:OptionAlarmStateAuto()
                    trigger.action.outTextForGroup(c2_client.group_id, string.format("%s: Alarm state standard", troop.troop_name), 1, false)
                end,
                nil)
            missionCommands.addCommandForGroup(
                c2_client.group_id,
                "Red",
                alarm_state_submenu_id,
                function()
                    troop.moose_group:OptionAlarmStateRed()
                    trigger.action.outTextForGroup(c2_client.group_id, string.format("%s: Alarm state RED!", troop.troop_name), 1, false)
                end,
                nil)
            missionCommands.addCommandForGroup(
                c2_client.group_id,
                "Green",
                alarm_state_submenu_id,
                function()
                    troop.moose_group:OptionAlarmStateGreen()
                    trigger.action.outTextForGroup(c2_client.group_id, string.format("%s: Alarm state green", troop.troop_name), 1, false)
                end,
                nil)
        end
    end
end

function TROOPCOMMAND:SendGroupToZone(troop, zone)
    if self.troop_navigation_feedback_verbosity > 0 then
        timer.scheduleFunction(
            function(args, time)
                if not troop.moose_group:IsAlive() then
                    return nil
                elseif troop.moose_group:IsNotInZone(zone) then
                    return time + 20
                else
                    trigger.action.outTextForCoalition(troop.coalition, string.format("%s: Arrived at %s", troop.troop_name, zone.display_name), 4)
                    return nil
                end
            end,
            nil,
            timer.getTime() + 1)
    end
    local target_coord = zone:GetCoordinate()
    troop.moose_group:RouteGroundTo(target_coord, troop.movement_speed, troop.movement_formation, 1)
end

--------------------------------------------------------------------------------
-- __troopship.TROOPSHIP

__troopship.TROOPSHIP = {}
__troopship.TROOPSHIP.__index = __troopship.TROOPSHIP

setmetatable(__troopship.TROOPSHIP, {
    __call = function (cls, ...)
        return cls.new(...)
    end,
})

-- Instantiate the main carrier object, bound to a unit
function __troopship.TROOPSHIP.new(unit_name, troop_command, troopship_options)
    local self = setmetatable({}, __troopship.TROOPSHIP)
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
    --     self.deploy_route_to_zones = __troopship.utils.getValidatedZonesFromNames(self.deploy_route_to_zone_names, nil)
    -- end
    if troopship_options["is_disable_deploy_to_zone_unload"] ~= nil then
        self.is_disable_deploy_to_zone_unload = troopship_options["is_disable_deploy_to_zone_unload"]
    end
    self.deploy_route_to_zones = troopship_options["deploy_route_to_zones"] or nil
    if troopship_options["is_disable_general_unload"] ~= nil then
        self.is_disable_general_unload = troopship_options["is_disable_general_unload"]
    end
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
    self.coalition = self.unit:getCoalition()
    self.moose_unit = CLIENT:FindByName(self.unit_name)
    self.moose_group = self.moose_unit:GetGroup()
    self.current_load = {}
    self.current_load_cost = 0
    self.loading_time_multiplier_per_unit = troopship_options["loading_time_multiplier_per_unit"] or 1
    self.unloading_time_multiplier_per_unit = troopship_options["unloading_time_multiplier_per_unit"] or 1
    self.carrying_capacity = troopship_options["carrying_capacity"] or nil
    self.pickup_unit_zone = ZONE_UNIT:New(string.format("%s Unit Zone", self.unit_name), self.moose_unit, self.pickup_radius)
    -- menu setup
    self.max_menu_items = 10
    self.load_management_submenu = missionCommands.addSubMenuForGroup(self.group_id, "Chalk", nil)
    self.available_for_pickup_submenu = missionCommands.addSubMenuForGroup(self.group_id, "Load", self.load_management_submenu)
    self.available_for_pickup_submenu_items = nil
    self.unload_submenu = missionCommands.addSubMenuForGroup(self.group_id, "Unload", self.load_management_submenu)
    self.unload_submenu_items = nil
    missionCommands.addCommandForGroup(
        self.group_id,
        "Status",
        self.load_management_submenu,
        self.ReportLoadStatus,
        self)
    missionCommands.addCommandForGroup(
        self.group_id,
        "Check for groups to pick-up",
        self.load_management_submenu,
        function() self:ScanForPickupGroups{is_report_results=true} end,
        nil)
    -- start monitoring air status
    self.air_status_check_fn_id = nil
    self.air_status_check_frequency = 3
    self.is_in_air_status = nil
    self:Start()
    return self
end

-- Should be called after a respawn/rebirth
function __troopship.TROOPSHIP:Start()
    self:AirStatusMonitoringStart()
    if not __troopship.utils.isEmpty(self.current_load) then
        -- Carrying a troop from a previous life ...
        -- We *could* catch the death event and spawn any chalks carried back
        -- at the original pick-up point to preserve the troop ...
        -- but I think here we are going to just erase them.
        for _, troop in pairs(self.current_load) do
            self.troop_command:PurgeTroop(self.current_load)
        end
        self.current_load = {}
        self.current_load_cost = 0
    end
    self:ScanForPickupGroups{is_report_results=false, is_report_positive_results=false}
    self:RebuildUnloadMenu()
end

-- Should be called after death/unbirth
function __troopship.TROOPSHIP:Stop()
    self:AirStatusMonitoringStop()
    if not __troopship.utils.isEmpty(self.current_load) then
        -- Carrying a troop from a previous life ...
        -- We *could* catch the death event and spawn any chalks carried back
        -- at the original pick-up point to preserve the troop ...
        -- but I think here we are going to just erase them.
        for _, troop in pairs(self.current_load) do
            self.troop_command:PurgeTroop(self.current_load)
        end
        self.current_load = {}
        self.current_load_cost = 0
    end
    self:ClearPickupMenu()
    self:ClearUnloadMenu()
end


-- Function to check if state changes from in air to land or vice versa
function __troopship.TROOPSHIP:__checkInAirStatusChanged(time)
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
function __troopship.TROOPSHIP:__onEventTakeOff()
    self.in_air = true
    self:ClearPickupMenu()
    -- don't bother with enabling/disabling the unload menu to save
    -- computation; just block the action in a check if it is called while in
    -- the air
end

-- Function to check if state changes from in air to land or vice versa
function __troopship.TROOPSHIP:__onEventTouchDown()
    self.in_air = false
    if self.is_autoscan_on_touchdown then
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
function __troopship.TROOPSHIP:AirStatusMonitoringStart()
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

function __troopship.TROOPSHIP:AirStatusMonitoringStop()
    if self.air_status_check_fn_id ~= nil then
        timer.removeFunction(self.air_status_check_fn_id)
    end
    self.air_status_check_fn_id = nil
end

-- Message
function __troopship.TROOPSHIP:__loadmasterMessage(message, duration)
    if duration == nil then
        duration = 1
    end
    self.moose_unit:Message( message, duration, self.loadmaster_name )
end

-- Report current load
function __troopship.TROOPSHIP:ReportLoadStatus()
    if not __troopship.utils.isEmpty(self.current_load) then
        local report = ""
        if #self.current_load == 1 then
            report = report .. "Carrying one chalk, sir!"
        else
            report = report .. string.format("Carrying %s chalks, sir!", #self.current_load)
        end
        for _, troop in pairs(self.current_load) do
            report = report .. string.format("\n- %s, with %s.",troop.troop_name, troop.troop_status.composition_summary)
        end
        self:__loadmasterMessage(report, #self.current_load * 2)
    else
        self:__loadmasterMessage("No load, sir!")
    end
end

-- Scan for load
function __troopship.TROOPSHIP:ScanForPickupGroups(args)
    local is_report_results = args["is_report_results"] or false
    local is_report_positive_results = args["is_report_positive_results"] or false
    self:ClearPickupMenu()
    if self.moose_unit:InAir() then
        if is_report_results then
            self:__loadmasterMessage("We're not on the ground, sir!")
        end
        return 0
    else
        spawners = self.troop_command:FindTroopSpawnZonesInVicinity(self.moose_unit)
        local num_spawners_found = #spawners
        troops = self.troop_command:FindLoadableTroopsInZone(self.pickup_unit_zone)
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
function __troopship.TROOPSHIP:ClearPickupMenu()
    if not __troopship.utils.isEmpty(self.available_for_pickup_submenu_items) then
        for _, item in pairs(self.available_for_pickup_submenu_items) do
            missionCommands.removeItemForGroup(self.group_id, item)
        end
    end
    self.available_for_pickup_submenu_items = {}
end

-- Clear pick-up menu
function __troopship.TROOPSHIP:ClearUnloadMenu()
    if not __troopship.utils.isEmpty(self.unload_submenu_items) then
        for _, item in pairs(self.unload_submenu_items) do
            missionCommands.removeItemForGroup(self.group_id, item)
        end
    end
    self.unload_submenu_items = {}
end

-- Rebuilt unload menu
function __troopship.TROOPSHIP:RebuildUnloadMenu()
    self:ClearUnloadMenu()
    if __troopship.utils.isEmpty(self.current_load) or self.moose_unit:InAir() then
        return
    else
        local parent_menu_id = self.unload_submenu
        local current_menu_item_count = 0
        for i1, troop in pairs(self.current_load) do
            current_menu_item_count = current_menu_item_count + 1
            if current_menu_item_count == self.max_menu_items then
                local more_submenu_id = missionCommands.addSubMenuForGroup(self.group_id, "More", parent_menu_id)
                if parent_menu_id == self.unload_submenu then
                    self.unload_submenu_items[1+#self.unload_submenu_items] = more_submenu_id
                end
                current_menu_item_count = 1
                parent_menu_id = more_submenu_id
            end
            if __troopship.utils.isEmpty(self.deploy_route_to_zones) or self.is_disable_deploy_to_zone_unload then
                local item = missionCommands.addCommandForGroup(
                    self.group_id,
                    troop.troop_name,
                    parent_menu_id,
                    function() self:UnloadTroops(troop, {}) end,
                    nil)
                if parent_menu_id == self.unload_submenu then
                    self.unload_submenu_items[1+#self.unload_submenu_items] = item
                end
            else
                -- current_menu_item_count = current_menu_item_count + 1
                -- if current_menu_item_count == self.max_menu_items then
                --     local more_submenu_id = missionCommands.addSubMenuForGroup(self.group_id, "More", parent_menu_id)
                --     if parent_menu_id == self.unload_submenu then
                --         self.unload_submenu_items[1+#self.unload_submenu_items] = more_submenu_id
                --     end
                --     current_menu_item_count = 1
                --     parent_menu_id = more_submenu_id
                -- end
                local unload_to_submenu_id = missionCommands.addSubMenuForGroup(self.group_id, troop.troop_name, parent_menu_id)
                if parent_menu_id == self.unload_submenu then
                    self.unload_submenu_items[1+#self.unload_submenu_items] = unload_to_submenu_id
                end
                deploy_item_parent_menu_id = unload_to_submenu_id
                current_menu_item_count = 1
                if not self.is_disable_general_unload then
                    local item = missionCommands.addCommandForGroup(
                        self.group_id,
                        "Here, to advance to enemy",
                        deploy_item_parent_menu_id,
                        function() self:UnloadTroops(troop, {is_advance_to_enemy=true}) end,
                        nil)
                end
                if not self.is_disable_general_unload then
                    local item = missionCommands.addCommandForGroup(
                        self.group_id,
                        "Here, to hold position",
                        deploy_item_parent_menu_id,
                        function() self:UnloadTroops(troop, {is_hold_position=true}) end,
                        nil)
                end
                for i2, deploy_route_to_zone in ipairs(self.deploy_route_to_zones) do
                    current_menu_item_count = current_menu_item_count + 1
                    if current_menu_item_count == self.max_menu_items then
                        local more_submenu_id = missionCommands.addSubMenuForGroup(self.group_id, "More", deploy_item_parent_menu_id)
                        current_menu_item_count = 1
                        deploy_item_parent_menu_id = more_submenu_id
                    end
                    local item = missionCommands.addCommandForGroup(
                        self.group_id,
                        string.format("To %s", deploy_route_to_zone.display_name),
                        deploy_item_parent_menu_id,
                        function() self:UnloadTroops(troop, {deploy_route_to_zone=deploy_route_to_zone}) end,
                        nil)
                end
            end
        end
    end
end

-- Load a group
function __troopship.TROOPSHIP:LoadTroops(troop)
    if self.moose_unit:InAir() then
        self:__loadmasterMessage("Cannot load up while we are not on the ground, sir!")
    elseif (self.carrying_capacity == nil and not __troopship.utils.isEmpty(self.current_load)) then
        self:__loadmasterMessage("We are already loaded up, sir!")
    elseif (self.carrying_capacity ~= nil and self.current_load_cost + troop.load_cost > self.carrying_capacity) then
        self:__loadmasterMessage("We cannot fit this group on board, sir!")
    elseif troop.moose_group:IsNotInZone(self.pickup_unit_zone) then
        self:__loadmasterMessage("Group has moved away, sir!")
        self:ScanForPickupGroups{is_report_results=false, is_report_positive_results=false}
    else
        if self.verbosity >= 1 then
            self:__loadmasterMessage( string.format("Loading %s, sir!", troop.troop_name) )
        end
        self:ClearPickupMenu() -- suppress loading/unloading till the current job is complete or canceled
        self:ClearUnloadMenu() -- suppress loading/unloading till the current job is complete or canceled
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
                        self.current_load[1+#self.current_load] = troop
                        self.current_load_cost = self.current_load_cost + troop.load_cost
                        self:RebuildUnloadMenu()
                        self:ScanForPickupGroups{is_report_results=false, is_report_positive_results=false}
                        self:__loadmasterMessage("Loading complete, sir!")
                    end,
                    cancel_message="Loading aborted, sir!",
                    on_cancel_fn=function()
                        self:RebuildUnloadMenu()
                        self:ScanForPickupGroups{is_report_results=false, is_report_positive_results=false}
                    end,
                    num_units_transferred=0,
                    transfer_time_per_unit=self.loading_time_multiplier_per_unit * troop.loading_time_per_unit,
                    time=time})
            end,
            nil,
            timer.getTime() + self.loading_time_multiplier_per_unit
            )
    end
end

-- unload a group
function __troopship.TROOPSHIP:UnloadTroops(troop, options)
    local direct_to_zone = options["deploy_route_to_zone"] or nil
    local is_advance_to_enemy = options["advance_to_enemy"] or nil
    local is_hold_position = options["is_hold_position"] or nil
    if self.moose_unit:InAir() then
        self:__loadmasterMessage("Cannot unload while we are not on the ground, sir!")
    else
        self:__loadmasterMessage(string.format("Unloading %s, sir!", troop.troop_name))
        self:ClearPickupMenu() -- suppress loading/unloading till the current job is complete or canceled
        self:ClearUnloadMenu() -- suppress loading/unloading till the current job is complete or canceled
        timer.scheduleFunction(
            function(args, time)
                return self:__executeLoadTransfer({
                    num_units=troop.num_units,
                    transfer_fn=function()
                        -- local group = troop.moose_group_spawner:SpawnFromUnit(self.moose_unit)
                        local moose_group = nil
                        moose_group = troop.group_spawner:SpawnFromUnit(self.moose_unit)
                        if troop.troop_source == "existing-group" then
                            -- remove dead units from group
                            local dcs_group = moose_group:GetDCSObject()
                            for index, unit in pairs(dcs_group:getUnits()) do
                                if troop.current_unit_ids[unit:getNumber()] == nil then
                                    unit:destroy()
                                end
                            end
                            troop.current_unit_ids = nil
                            self.troop_command:RestoreTroop{
                                troop_id=troop.troop_id,
                                update_group=moose_group}
                        else
                            error(string.format("Unrecognized troop source: '%s'", troop.troop_source))
                        end
                        self:__loadmasterMessage("Unloading complete, sir!")
                        if direct_to_zone == nil and troop.deploy_route_to_zone ~= nil then
                            direct_to_zone = troop.deploy_route_to_zone
                        end
                        if direct_to_zone ~= nil then
                            -- local target_coord = deploy_route_to_zone:GetRandomCoordinate()
                            trigger.action.outTextForCoalition(self.coalition, string.format("%s: Moving to %s", troop.troop_name, direct_to_zone.display_name), 2 )
                            self.troop_command:SendGroupToZone(troop, direct_to_zone)
                        elseif is_advance_to_enemy then
                            local results = __troopship.utils.moveGroupToNearestEnemyPosition(troop.moose_group, troop.maximum_search_distance)
                            if results ~= nil then
                                trigger.action.outTextForCoalition(self.coalition, string.format("%s: Moving to engage enemy at: %s", troop.troop_name, __troopship.utils.composeLLDDM(results.point)), 2 )
                            end
                        elseif is_hold_position then
                            local task = moose_group:TaskHold()
                            moose_group:SetTask(task)
                        end
                        local new_load = {}
                        local new_load_cost = 0
                        for _, old_load_troop in pairs(self.current_load) do
                            if troop ~= old_load_troop then
                                new_load[1+#new_load] = old_load_troop
                                new_load_cost = new_load_cost + old_load_troop.load_cost
                            end
                        end
                        self.current_load = new_load
                        self.current_load_cost = new_load_cost
                        self:RebuildUnloadMenu()
                        self:ScanForPickupGroups{is_report_results=false, is_report_positive_results=false}
                    end,
                    cancel_message="Unloading aborted, sir!",
                    on_cancel_fn=function()
                        self:RebuildUnloadMenu()
                        self:ScanForPickupGroups{is_report_results=false, is_report_positive_results=false}
                    end,
                    num_units_transferred=0,
                    transfer_time_per_unit=self.loading_time_multiplier_per_unit * troop.unloading_time_per_unit,
                    time=time})
            end,
            nil,
            timer.getTime() + self.loading_time_multiplier_per_unit
            )
    end
end

function __troopship.TROOPSHIP:__executeLoadTransfer(args)
    local num_units = args["num_units"]
    local transfer_fn = args["transfer_fn"]
    local cancel_message = args["cancel_message"]
    local on_cancel_fn = args["on_cancel_fn"]
    local num_units_transferred = args["num_units_transferred"] or 0
    local transfer_time_per_unit = args["transfer_time_per_unit"] or 1
    local time = args["time"]
    if self.moose_unit:InAir() then
        if on_cancel_fn ~= nil then
            on_cancel_fn()
        end
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
            return nil
        end
    end
end

