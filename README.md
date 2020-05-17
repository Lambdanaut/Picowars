PICOWARS
========

An Advance Wars homage created in [PICO-8](https://www.lexaloffle.com/pico-8.php)


Todo in order
-------------

* APC
* Stage 4 AI
 * APC usage
 * Retreating
* Save/load functionality
* 3 Campaign missions
* End Turn Transitions
* Music
* Splash screen
* ctrl + f for "refact" comments for refactoring suggestions
* 8 commanders
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


Bugs-to-fix
-----------

* Getting units attack range doesn't account for places they can't move to(like mountains)
* If you have zero gold, infantry is selected by default and you can still build it.
