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
-- EXAMPLE APPLICATION 01
--------------------------------------------------------------------------------

-- Define a TROOPCOMMAND object.
-- This is the main manager for all ground forces and transport assets for a
-- mission. Each side (coalition) should have distinct TROOPCOMMAND objects
-- (otherwise BLUE side troopships will pick up RED side troops and vice versa,
-- or BLUE side C&C ships will command RED side troops and vice versa).
-- However, if needed, you can delcare multiple TROOPCOMMAND objects per
-- coalation, e.g., one for each major region of conflict, or one for each
-- division/brigade etc. Either way, note that each unit should only be
-- assigned exclusively to a single TROOPCOMMAND object.
troop_command1 = TROOPCOMMAND("BLUE 1", coalition.side.BLUE)

-- Register various navigation zones. These must have been created in the
-- mission in the DCS mission editor. These will be used to direct troops after
-- they are dropped off from a troopship or otherwise at any time from a C&C
-- (Command-and-Control, or C2) ship. Note that ALL zones need to be defined
-- before registering any troopships or C&C ships!
troop_command1:RegisterRoutingZoneNames({
    "Rwy E",
    "Rwy W",
    "Rwy Ctr",
    "Ctr N",
    "Ctr S",
    "NW",
    "SW",
})
-- You can also register navigation/routing zones singly, instead of a table as
-- above. In addition, you can specify an alias under which to display the zone
-- name.
troop_command1:RegisterRoutingZoneName("SE", "SE Quadrant")

-- Register the groups that will consitute troops under this command.
-- The names that you use here must correspond to groups created in the mission
-- in the DCS mission editor. Due to technical reasons with the MOOSE library
-- we use, these group names should avoid using the normal '#001', '#002', etc.
-- convention.
troop_command1:RegisterTroop("Bravo 1")
troop_command1:RegisterTroop("Bravo 2")
troop_command1:RegisterTroop("Bravo 3")
troop_command1:RegisterTroop("Bravo 4")

-- Create a new dynamic spawn point. Troops picked up from here do not exist
-- until they are picked-up: they come into existence as if freshly arrived.
-- A spawner like this is defined by a name, a trigger zone, and an existing
-- group (typically unactivated) that serves as a template.
troop_command1:CreateTroopSpawner("Alpha", "Spawn Zone 1", "Alpha Troop Template")

-- Register the troop ship with the unit name, "Pilot #001". This must be a
-- suitable unit created in the mission editor, with skill level set to
-- "Client" or "Player". IMPORTANT: This unit must be in its OWN group!
troop_command1:RegisterTroopship("Pilot #001")
-- The same helo is also a C&C (Command and Control, or C2) ship
troop_command1:RegisterCommandAndControlShip("Pilot #001")

-- Ditto for "Pilot #002"
troop_command1:RegisterTroopship("Pilot #002")
troop_command1:RegisterCommandAndControlShip("Pilot #002")

-- For "Pilot #003", we only register it as a C&C ship, as it cannot carry
-- troops.
troop_command1:RegisterCommandAndControlShip("Pilot #003")

-- For "Pilot #003", we only register it as a C&C ship, as it cannot carry
-- troops.
troop_command1:RegisterCommandAndControlShip("Pilot #004")
