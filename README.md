PICOWARS
========

An Advance Wars homage created in [PICO-8](https://www.lexaloffle.com/pico-8.php)

Play it on [Itch.io](https://lambdanaut.itch.io/picowars)


Todo in order
-------------

* Play through campaign, balancing scoring system
* Make vs maps


Done
----

* Selector message
* Resting units
* Turns
* Combat
* Status bar at top/bottom of screen
* Basic AI
 * Move towards other player's hq with A*
 * Attack if there are enemy units in attack range
* Unit lifebar
* Capturing
* Camera shake during unit death and attack
* Cities
  * Heal units on them by 2 per turn
* Income
* HQ
* Bases
* Building from bases
* Stage 2 AI
 * Capture cities and bases
 * Build from cities and bases
* AI vs AI battles
* Sort units by y value for drawing
* Long range units
* Stage 3 AI
 * Use of long range units
 * Better build otherder decision
* End Turn Transitions
* ctrl + f for "refact" comments for refactoring suggestions
* For Demo 1
 * Splash screen
 * Music for Blue Moon and Orange Star
 * Publish, upload, and share
* For Demo 2 (Splore)
 * Fill map space with maps
 * Maps menu
* Dialogue System
* APC
* Victory/Defeat screen
* Credits
* 8 Campaign missions
* Selectable team and commanders in VS mode
* Save/load functionality
* Unlockable commanders
* Dialogue


Bugs-to-fix
-----------


Bugs Squashed
-------------

* AI can attack and capture in the same turn
* If you have zero gold, infantry is selected by default and you can still build it.
* Getting units attack range doesn't account for places they can't move to(like mountains)
* The build-unit prompt shows the same goldcost for player 2 as player 1. Fix it so each player sees their own goldcost for each unit
