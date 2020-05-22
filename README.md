PICOWARS
========

An Advance Wars homage created in [PICO-8](https://www.lexaloffle.com/pico-8.php)


Todo in order
-------------

* For Demo 1
 * Splash screen
 * Music for Blue Moon and Orange Star
* For Demo 2 (Splore)
 * APC
 * Fill map space with maps
 * Maps menu
* APC
* Save/load functionality
* 3 Campaign missions
* Unlockable commanders
* Better AI so they weigh movement positions based on whether or not they are in attack range of a losing fight
* more campaign missions
* multiplayer



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


Bugs-to-fix
-----------

* Getting units attack range doesn't account for places they can't move to(like mountains)
* If you have zero gold, infantry is selected by default and you can still build it.
* The build-unit prompt shows the same goldcost for player 2 as player 1. Fix it so each player sees their own goldcost for each unit