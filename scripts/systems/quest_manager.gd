extends Node
class_name QuestManager

signal quest_changed
signal quest_completed

enum QuestState { AVAILABLE, ACTIVE, READY_TO_TURN_IN, COMPLETED }

@export var required_bandits: int = 5
@export var required_gold: int = 5

var state: QuestState = QuestState.AVAILABLE
var bandits_defeated: int = 0
var gold_collected: int = 0


func accept_quest() -> void:
    if state != QuestState.AVAILABLE:
        return
    state = QuestState.ACTIVE
    _update_progress()
    quest_changed.emit()


func record_bandit_defeated() -> void:
    if state == QuestState.COMPLETED:
        return
    bandits_defeated += 1
    _update_progress()
    quest_changed.emit()


func record_gold_collected() -> void:
    if state == QuestState.COMPLETED:
        return
    gold_collected += 1
    _update_progress()
    quest_changed.emit()


func turn_in_quest() -> bool:
    if state != QuestState.READY_TO_TURN_IN:
        return false
    state = QuestState.COMPLETED
    quest_changed.emit()
    quest_completed.emit()
    return true


func get_objective_text() -> String:
    match state:
        QuestState.AVAILABLE:
            return "边境盗匪：与村庄守卫交谈"
        QuestState.ACTIVE:
            return "边境盗匪：击败敌人 %d/%d  ·  收集金币 %d/%d" % [
                mini(bandits_defeated, required_bandits), required_bandits,
                mini(gold_collected, required_gold), required_gold
            ]
        QuestState.READY_TO_TURN_IN:
            return "边境盗匪：返回村庄向守卫复命"
        _:
            return "边境恢复了平静"


func _update_progress() -> void:
    if state == QuestState.ACTIVE \
            and bandits_defeated >= required_bandits \
            and gold_collected >= required_gold:
        state = QuestState.READY_TO_TURN_IN

