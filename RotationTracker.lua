local frame = CreateFrame("Frame")

RotationTrackerDB = RotationTrackerDB or {}
RotationTrackerDB.profile = RotationTrackerDB.profile or {}
RotationTrackerDB.history = RotationTrackerDB.history or {}

local defaults = {
    targetDPS = 0,
    maxHistory = 25,
    minFightSeconds = 6,
    printToChat = true
}

local function applyDefaults()
    for key, value in pairs(defaults) do
        if RotationTrackerDB.profile[key] == nil then
            RotationTrackerDB.profile[key] = value
        end
    end
end

applyDefaults()

local session = nil
local active = false
local playerGUID

local function newStats()
    return {
        casts = 0,
        damage = 0,
        castsByAbility = {},
        rotation = {},
        start = 0,
        stop = 0,
        fights = 0
    }
end

local function ensureAbility(stats, spellName, spellId)
    local key = (spellId and tostring(spellId)) or spellName or "Unknown"
    if not stats.castsByAbility[key] then
        stats.castsByAbility[key] = {
            spellId = spellId,
            name = spellName or "Unknown",
            casts = 0,
            damage = 0
        }
    end
    return stats.castsByAbility[key]
end

local function startFight()
    playerGUID = UnitGUID("player")
    session = newStats()
    session.start = GetTime()
    session.targetDPS = RotationTrackerDB.profile.targetDPS
    active = true
    C_Timer.After(0, function()
        if RotationTrackerDB.profile.printToChat then
            print("|cFFFFD100RotationTracker:|r tracking started.")
        end
    end)
end

local function isTopSource(sourceGUID)
    return sourceGUID == playerGUID
end

local function parseDamageEvent(args, baseIdx, stats)
    local amount = tonumber(args[baseIdx + 3]) or 0
    local blocked = tonumber(args[baseIdx + 4]) or 0
    local absorbed = tonumber(args[baseIdx + 5]) or 0
    if amount <= 0 then
        return
    end
    local rawDamage = amount + blocked + absorbed
    stats.damage = stats.damage + rawDamage

    local spellId, spellName = args[baseIdx], args[baseIdx + 1]
    local ability = ensureAbility(stats, spellName, spellId)
    ability.damage = ability.damage + rawDamage
    ability.casts = ability.casts + 0
end

local function parseCastEvent(subEvent, args, baseIdx, now, stats)
    local spellId, spellName = args[baseIdx], args[baseIdx + 1]
    stats.casts = stats.casts + 1
    local ability = ensureAbility(stats, spellName, spellId)
    ability.casts = ability.casts + 1
    local when = now - session.start
    table.insert(stats.rotation, {
        time = when,
        spell = spellName,
        spellId = spellId,
        event = subEvent
    })
end

local function stopFight()
    if not active or not session then
        if RotationTrackerDB.profile.printToChat then
            print("|cFFFFD100RotationTracker:|r no active combat tracking found.")
        end
        return
    end

    active = false
    session.stop = GetTime()
    local duration = math.max(0, session.stop - session.start)
    if duration < RotationTrackerDB.profile.minFightSeconds then
        if RotationTrackerDB.profile.printToChat then
            print("|cFFFFD100RotationTracker:|r fight too short to score ("
                .. string.format("%.1f", duration) .. "s).")
        end
        session = nil
        return
    end

    local dps = session.damage / duration
    local target = session.targetDPS or 0
    local gap = dps - target
    local gapPct = target > 0 and (gap / target * 100) or 0
    local top = table.concat({
        "|cFFFFD100RotationTracker:|r summary",
        "\n- Duration: " .. string.format("%.1f", duration) .. "s",
        "\n- Total Damage: " .. string.format("%.0f", session.damage),
        "\n- DPS: " .. string.format("%.0f", dps)
    }, "")

    if target > 0 then
        local status = (gap >= 0) and "ahead of target" or "below target"
        top = top .. "\n- Target DPS: " .. string.format("%.0f", target)
                  .. "\n- Gap: " .. (gap >= 0 and "+" or "-")
                  .. string.format("%.0f", math.abs(gap)) .. " DPS (" .. string.format("%.1f", gapPct) .. "%)"
                  .. "\n- Status: " .. status
    else
        top = top .. "\n- No target set. use /rt target <dps>"
    end

    if RotationTrackerDB.profile.printToChat then
        print(top)
    end

    local topAbility, topDamage = nil, -1
    for _, ability in pairs(session.castsByAbility) do
        if ability.damage > topDamage then
            topDamage = ability.damage
            topAbility = ability
        end
    end
    if topAbility then
        if RotationTrackerDB.profile.printToChat then
            print("- Top damaging ability: " .. (topAbility.name or "Unknown")
                .. " (" .. string.format("%.0f", topAbility.damage) .. ")")
        end
    end

    table.insert(RotationTrackerDB.history, 1, {
        when = date("!%Y-%m-%dT%H:%M:%SZ"),
        duration = duration,
        damage = session.damage,
        dps = dps,
        target = target,
        gap = gap,
        rotationCount = #session.rotation
    })

    if #RotationTrackerDB.history > RotationTrackerDB.profile.maxHistory then
        for i = #RotationTrackerDB.history, RotationTrackerDB.profile.maxHistory + 1, -1 do
            table.remove(RotationTrackerDB.history, i)
        end
    end

    session = nil
end

local function eventDispatcher(_, event, ...)
    if event == "PLAYER_REGEN_DISABLED" then
        if not active then
            startFight()
        end
        return
    end
    if event == "PLAYER_REGEN_ENABLED" then
        stopFight()
        return
    end
    if event ~= "COMBAT_LOG_EVENT_UNFILTERED" then
        return
    end
    if not active or not session then
        return
    end

    local args = { CombatLogGetCurrentEventInfo() }
    local sourceGUID = args[4]
    if not isTopSource(sourceGUID) then
        return
    end

    local subEvent = args[2]
    local now = GetTime()

    if subEvent == "SPELL_CAST_SUCCESS" or subEvent == "SPELL_CAST_START" then
        parseCastEvent(subEvent, args, 12, now, session)
        return
    end

    if subEvent == "SPELL_DAMAGE" or subEvent == "SPELL_PERIODIC_DAMAGE" then
        parseDamageEvent(args, 12, session)
        return
    end

    if subEvent == "SWING_DAMAGE" then
        local amount = tonumber(args[12]) or 0
        if amount > 0 then
            session.damage = session.damage + amount
            local ability = ensureAbility(session, "Auto Attack", 0)
            ability.damage = ability.damage + amount
            table.insert(session.rotation, {
                time = now - session.start,
                spell = "Auto Attack",
                spellId = 0,
                event = subEvent
            })
        end
        return
    end
end

frame:SetScript("OnEvent", eventDispatcher)
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_REGEN_DISABLED")
frame:RegisterEvent("PLAYER_REGEN_ENABLED")
frame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")

SLASH_ROTATIONTRACKER1 = "/rt"
SLASH_ROTATIONTRACKER2 = "/rotation"

SlashCmdList["ROTATIONTRACKER"] = function(msg)
    local cmd, rest = strsplit(" ", (msg or ""), 2)
    cmd = (cmd or ""):lower()

    if cmd == "start" then
        startFight()
        return
    end
    if cmd == "stop" then
        stopFight()
        return
    end
    if cmd == "target" then
        local value = tonumber((rest or ""):match("([%d%.%-]+)"))
        if not value then
            print("|cFFFFD100RotationTracker:|r usage: /rt target <dps>")
            return
        end
        RotationTrackerDB.profile.targetDPS = value
        session = session or newStats()
        session.targetDPS = value
        print("|cFFFFD100RotationTracker:|r target DPS set to " .. string.format("%.0f", value))
        return
    end
    if cmd == "best" then
        if #RotationTrackerDB.history == 0 then
            print("|cFFFFD100RotationTracker:|r no fights recorded yet.")
            return
        end
        local best = RotationTrackerDB.history[1]
        for i = 2, #RotationTrackerDB.history do
            if RotationTrackerDB.history[i].dps > best.dps then
                best = RotationTrackerDB.history[i]
            end
        end
        local bestDps = best.dps
        print("|cFFFFD100RotationTracker:|r best fight so far: "
              .. string.format("%.0f", bestDps) .. " DPS in "
              .. string.format("%.1f", best.duration) .. "s.")
        return
    end
    if cmd == "history" then
        if #RotationTrackerDB.history == 0 then
            print("|cFFFFD100RotationTracker:|r no fights in history.")
            return
        end
        print("|cFFFFD100RotationTracker:|r recent fights:")
        for i = 1, math.min(10, #RotationTrackerDB.history) do
            local h = RotationTrackerDB.history[i]
            print(string.format("  #%d %.1f DPS (%s), %.1fs, gap %.0f",
                i, h.dps, h.when, h.duration, h.gap))
        end
        return
    end
    if cmd == "rotation" then
        if not session then
            print("|cFFFFD100RotationTracker:|r no active rotation to show.")
            return
        end
        print("|cFFFFD100RotationTracker:|r rotation so far (" .. #session.rotation .. " events)")
        for i = 1, math.min(15, #session.rotation) do
            local item = session.rotation[i]
            print(string.format("  %0.2fs - %s", item.time, item.spell))
        end
        if #session.rotation > 15 then
            print("  ... (" .. (#session.rotation - 15) .. " more)")
        end
        return
    end
    print("|cFFFFD100RotationTracker:|r commands: start | stop | target <dps> | best | history | rotation")
end
