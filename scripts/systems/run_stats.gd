class_name RunStats
extends RefCounted

## Telemetry for one Expedition run: damage dealt and what was bought.
##
## Static, like `Elevation`, because these numbers are produced wherever the events
## happen rather than passed down a chain of owners.
##
## DAMAGE IS COUNTED AT THE RECEIVER, not at the three places that currently deal it -
## the player's melee, the player's dash and a recruited companion. Counting at those
## call sites would mean the next attack added anywhere is silently not counted; every
## one of them goes through a hostile's `take_damage`, so that is where the funnel
## belongs. It also covers both hostile classes without a type test, which matters here:
## `Enemy` and `ArcherEnemy` share no base, and the project has already been bitten once
## by a check that silently excluded one of them.
##
## Every point of damage a hostile takes during a run was dealt by the player's side, so
## the receiver needs no idea who hit it.
##
## The elapsed time is NOT kept here: the run already tracks it, and a second copy would
## be one more thing to keep in step.
##
## Classic mode never resets or reads this. A stale value there is harmless because
## nothing displays it.

static var damage_dealt := 0
## One entry per purchase, in the order they were made: `{"what": String, "price": int}`.
static var purchases: Array[Dictionary] = []


static func reset() -> void:
	damage_dealt = 0
	purchases.clear()


static func record_damage(amount: int) -> void:
	damage_dealt += maxi(amount, 0)


static func record_purchase(what: String, price: int) -> void:
	purchases.append({"what": what, "price": price})


static func spent() -> int:
	var total := 0
	for entry in purchases:
		total += int(entry["price"])
	return total
