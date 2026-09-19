extends RefCounted

const DATA := {
    "shield_counter": {"name": "盾反", "description": "格挡成功后，下一次命中的挥砍伤害 +20。"},
    "iron_guard": {"name": "铁壁", "description": "每次成功格挡少消耗 4 精力。"},
    "dash_cleave": {"name": "疾冲斩", "description": "冲刺穿过敌人时造成 18 点伤害。"},
    "swift_step": {"name": "轻身", "description": "冲刺少消耗 10 精力，冷却缩短 0.25 秒。"},
    "kill_flow": {"name": "乘胜", "description": "击败敌人立即恢复 18 点精力。"},
    "heavy_blade": {"name": "重刃", "description": "挥砍伤害 +20，但每次多消耗 10 精力。"}
}

static func name_of(id: String) -> String:
    return DATA[id]["name"]

static func description_of(id: String) -> String:
    return DATA[id]["description"]

static func offers(owned: Dictionary, rng: RandomNumberGenerator, count: int = 3) -> Array[String]:
    var available: Array[String] = []
    for id in DATA.keys():
        if not owned.has(id):
            available.append(id)
    var result: Array[String] = []
    while not available.is_empty() and result.size() < count:
        var index := rng.randi_range(0, available.size() - 1)
        result.append(available.pop_at(index))
    return result

