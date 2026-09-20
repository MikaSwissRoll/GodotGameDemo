extends Node
class_name ClassicProgression

## Classic Mode's progression: the one place that knows which phase the player is
## in and what the current objective is.
##
## The four phases run in a fixed order and only ever advance forwards, so a player
## who talks to the Merchant before finishing training is simply told to go and
## train; no later quest can be started early.
##
##   GUARD_TUTORIAL     talk to the Guard, then move / attack / guard
##   MERCHANT_TUTORIAL  talk to the Merchant, then buy and use both potions
##   MAIN_QUEST         the long-standing "defeat 5, collect 5 gold" quest
##   FREE_PLAY          main quest turned in; outer enemies respawn, no tracker
##
## This deliberately does not become a generic quest framework. It owns exactly the
## four phases Classic Mode has, and the main quest keeps using QuestManager for its
## own counters rather than being reimplemented here.

signal changed
## Emitted when the phase advances, so the game can react once per transition
## instead of comparing phases every frame.
signal phase_changed(phase: int)
## Emitted when the main quest is handed in. Free play begins here.
signal main_quest_completed

enum Phase { GUARD_TUTORIAL, MERCHANT_TUTORIAL, MAIN_QUEST, FREE_PLAY }
## Steps of the Guard tutorial, in the order they must be completed.
enum Training { MOVE, ATTACK, GUARD }
## Movement directions the tutorial asks for. The bits are the quest's own, so the
## player reports plain flags and neither side depends on the other's enum.
enum MoveDir { UP = 1, DOWN = 2, LEFT = 4, RIGHT = 8 }

const GUARD_REWARD := 10
const MERCHANT_REWARD := 10
const ALL_DIRECTIONS := 0b1111

var phase: int = Phase.GUARD_TUTORIAL
## Set when the Guard has given the briefing, so the objective can say "move" rather
## than "talk to the Guard" before any progress exists.
var guard_briefed := false
## Set when the Merchant has given the briefing, for the same reason.
var merchant_briefed := false
## Guard tutorial progress.
var moved_directions: int = 0
var attacked := false
var guarded := false
## Merchant tutorial progress. Purchase and use are tracked separately, so buying
## two potions of one kind cannot satisfy the other.
var bought_health := false
var bought_stamina := false
var used_health := false
var used_stamina := false
## Rewards are one-shot. Without these a player could re-talk to an NPC and be paid
## again for a quest that is already finished.
var guard_reward_paid := false
var merchant_reward_paid := false


func _ready() -> void:
    name = "ClassicProgression"


## ---- Phase queries -------------------------------------------------------

func guard_tutorial_done() -> bool:
    return moved_directions == ALL_DIRECTIONS and attacked and guarded


func merchant_tutorial_done() -> bool:
    return bought_health and bought_stamina and used_health and used_stamina


## The current training step, for dialogue that reacts to how far along the player
## is. Returns -1 once training is finished.
func training_step() -> int:
    if moved_directions != ALL_DIRECTIONS:
        return Training.MOVE
    if not attacked:
        return Training.ATTACK
    if not guarded:
        return Training.GUARD
    return -1


## ---- Recording real actions ---------------------------------------------

func record_direction(flag: int) -> void:
    if phase != Phase.GUARD_TUTORIAL:
        return
    if moved_directions & flag:
        return
    moved_directions |= flag
    changed.emit()


func record_attack() -> void:
    if phase != Phase.GUARD_TUTORIAL or attacked:
        return
    attacked = true
    changed.emit()


func record_guard() -> void:
    if phase != Phase.GUARD_TUTORIAL or guarded:
        return
    guarded = true
    changed.emit()


func record_purchase(kind: String) -> void:
    if phase != Phase.MERCHANT_TUTORIAL:
        return
    if kind == "health":
        if bought_health:
            return
        bought_health = true
    else:
        if bought_stamina:
            return
        bought_stamina = true
    changed.emit()


func record_potion_used(kind: String) -> void:
    if phase != Phase.MERCHANT_TUTORIAL:
        return
    if kind == "health":
        if used_health:
            return
        used_health = true
    else:
        if used_stamina:
            return
        used_stamina = true
    changed.emit()


## ---- Advancing -----------------------------------------------------------

func start_merchant_tutorial() -> void:
    _advance(Phase.MERCHANT_TUTORIAL)


func start_main_quest() -> void:
    _advance(Phase.MAIN_QUEST)


func start_free_play() -> void:
    _advance(Phase.FREE_PLAY)
    main_quest_completed.emit()


func _advance(next: int) -> void:
    if next <= phase:
        return
    phase = next
    changed.emit()
    phase_changed.emit(phase)


## ---- Presentation --------------------------------------------------------

## One-line objective for the existing quest label. Kept short because the label is
## a single line beside the shield icon; a checklist would need a new interface.
##
## `main_quest_text` is passed in rather than rebuilt here: the main quest's
## counters live in QuestManager, which stays the source of truth for them.
func objective_text(main_quest_text: String) -> String:
    match phase:
        Phase.GUARD_TUTORIAL:
            return _training_text() if guard_briefed else "基础训练：与守卫交谈"
        Phase.MERCHANT_TUTORIAL:
            return _supply_text() if merchant_briefed else "准备补给：与商人交谈"
        Phase.MAIN_QUEST:
            return main_quest_text
        _:
            return ""


## Whether the tracker should be on screen at all. Free play has no objective, and
## leaving a finished quest pinned at 5/5 would read as unfinished business.
func tracker_visible() -> bool:
    return phase != Phase.FREE_PLAY


## Text for the shop panel, so the Merchant's line matches the phase.
func merchant_dialogue() -> String:
    match phase:
        Phase.GUARD_TUTORIAL:
            return "商人：先去把基础训练做完吧。"
        Phase.MERCHANT_TUTORIAL:
            if merchant_tutorial_done():
                return "商人：准备好了就再来找我。"
            return "商人：买下两种药水，再各用一次。"
        _:
            return ""


func _training_text() -> String:
    var steps: Array[String] = []
    steps.append("移动 %d/4" % _direction_count())
    steps.append("攻击 %s" % _mark(attacked))
    steps.append("举盾 %s" % _mark(guarded))
    return "基础训练：" + " · ".join(steps)


func _supply_text() -> String:
    var steps: Array[String] = []
    steps.append("购买 %d/2" % _count_true([bought_health, bought_stamina]))
    steps.append("使用 %d/2" % _count_true([used_health, used_stamina]))
    return "准备补给：" + " · ".join(steps)


func _mark(done: bool) -> String:
    return "✓" if done else "○"


func _count_true(values: Array) -> int:
    var total := 0
    for value in values:
        if value:
            total += 1
    return total


func _direction_count() -> int:
    var total := 0
    for bit in 4:
        if moved_directions & (1 << bit):
            total += 1
    return total
