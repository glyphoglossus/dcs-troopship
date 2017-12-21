# TROOPSHIP - Tactical Airmobile Operations Mission Development Scripting Library for DCS

## Overview

This is a scripting library for DCS that provides support for tactical airmobile operations for [DCS (Digital Combat Simulator)](https://www.digitalcombatsimulator.com/en/), including transport, logistics, as well as command and control (C&C) of ground troops. Using this library, it is easy to set up missions where players (in either single or multi-player mode) will be able to pick up and drop troops anywhere on the map (not just in pick-up zones, though dynamic spawning zones are also supported), as well as command troops to move to defined waypoint zones and carry out other actions there. One of the major motivating ideas is to be able to create ground war missions, with players feeding troops into the action (by delivering them to desired locations in troopship helos) and otherwise commanding troops to move, fight, or retreat (from C&C ships) as needed across the DCS map like so many pieces on a chess board. This will allow for strategic war game like missions in which players have a front seat to the action.

## Features

-   Pick-up/drop (existing) troops anywhere -- not just in pre-defined pick-up/drop zones etc.
-   Dead/destroyed units in pick-up and dropped groups are not restored on beng dropped -- dead is dead.
-   Run your ship like a C&C ship, commanding ground troops (even ones you have not dropped, i.e. pre-existing or dropped by others) to:
    -   Move to particular locations specified via routing (waypoint) zones
    -   Pop smoke, drop flares, etc.
    -   Report status
-   Direct dropped troops to different destinations.

## Requirements

-   DCS
-   MOOSE

## Example Missions

### Example 1: Basic Functions

The mission file in "``examples/troopship-example-01.miz``" provides a simple way to explore many of the features of TROOPSHIP. Load up the mission, and you will see you have a choice of three helos: a UH-1H, an Mi-8, a Gazelle, and a Ka-50. The first two are lift ships, capable of carrying troops, as well as C&C (command and control, or C2) ships, capable of directing troops on the ground. The last two are not capable of carrying troops, but are pure C&C ships. For the purposes of this walkthrough, pick one of the lift ships, i.e. the Huey or the Eight.

Once you are in the cockpit, directly in front of you are two groups of troops, Bravo 1 and Bravo 2. To the right you should see a row of hangers --- take note of them for later: we will return here when we check out the dynamic spawning zone. For now, however, we will first explore the C&C functions: press the radio trigger button to call up the radio menu, then F11 and then F10. There should be two menu entries available, "Chalk ...", which manages the load of your ship, and "Troop C&C ...", which access the command and control functions. Select "Troop C&C ..." and a list of available troops should come up. Select "Bravo 1" and have them pop some blue smoke, just to make sure everything works. Now select "Bravo 3" and have them pop some red smoke. Bravo 3 is at the other end of the airfield, and the red smoke should let us see where they are. Let's send "Bravo 2" toward their location: call up the radio menu again and navigate to the "Troop C&C" menu, select Bravo 2, and the select "Move ...", and then select the destination, "SW". The troops should start moving directly toward their objective. You can explore the C&C options in more detail --- getting the troops situation reports, fire flares, etc.

Now we are going to do a simple lift. We will vertical lift Bravo 1 directly over to the "Kuitasi SW" point and see if we can beat Bravo 1 there! Press the radio trigger again, and then F10, but instead of selecting "Troop C&C ...", select "Chalk ...", and then "Load ...". You will see a list of all troops that are within pick-up range. If you had done this at the start of the mission, you would have seen both "Bravo 1" and "Bravo 2", but as we sent "Bravo 2" off on their way, there should only be "Bravo 1" here. Select "Bravo 1" for the loading. The loadmaster should countdown the loading until they are all on board. Be careful to wait till the loading is done --- if you lift off halfway through it wil be aborted. Once they are on board, check the status of the chalk by going F10, then "Chalk", then "Report load status", to confirm you have all of them on board. Then take off and head toward the destination. When you touch down, you can unload them by using F10, "Chalk ...", then "Unload ...". You can unload them in-situ and leave them, or you can unload them and direct them toward a particular destination. Either way, the loadmaster will countdown the loading, and you should not take-off till it is done. And that's all there is to it!

Note that, in the above example,m while we used zones for navigation, we are not restricted to dropping or picking up groups in zones. As long as we land close enough to troop that is designated to be a chalk load, we can pick them up, and, similarly, we can set them down anywhere as long as we are on the ground. I

Now head the hangars we saw earlier, and land in front of the red flag on the north side of the hangars. You are now in a dynamic pick-up zone. This zone that continuously produces troops for you to load up, as and when you request them, creating new troops as needed. Unlike "normal" troops we used above, to pick these troops up the *first* time, we have to be in a designated zone, and unlike the "normal" troops, until we request them they do not exist. However, once we have done this, the group behaves like a normal troop --- after we drop them off, we can command them, load them up and drop them off anywhere, whether or not we are in a designated zone. Call up the radio menu again and press F10, then select, "Chalk ...", then "Load ...". You should see an option to load up a group of "Alpha" troops. Select this, and, again wait through the countdown for them to load up. Then take off and ... drop them off anywhere you want!

## Guidelines for Use

-   When designing a mission, NEVER include "#" within the name of a spawning template group (MOOSE rule).

## Disclaimer

NOTE: This project is not endorsed by or otherwise in any way officially associated with Eagle Dynamics, the Fighter Collection, or anyone else behind the DCS family of products.

## License and Warranty

See: "LICENSE" file included in this project for details.
