-- Author: Ryan Hagelstrom
-- Copyright © 2021-2025
-- Please see the license file included with this distribution for
-- attribution and copyright information.
--
-- luacheck: globals onInit onTabletopInit onClose cleanExhaustionEffect sumExhaustion updateEffect
-- luacheck: globals customReduceExhaustion customRest customAddEffect customApplyDamage customParseEffect
-- luacheck: globals newDND customGetEffectsBonus newDNDModExhaustion customOutputResult customOnCastSave customCheckModRoll
-- luacheck: globals customModAttack customModSave tireless customPerformAction
-- luacheck: globals EffectsManagerExhausted is2024
local rest = nil;
local addEffect = nil;
local applyDamage = nil;
local parseEffects = nil;
local reduceExhaustion = nil;

-- 2024 DND
local checkModRoll = nil;
local modAttack = nil;
local modSave = nil;
local getEffectsBonus = nil;
local onCastSave = nil;
local outputResult = nil;
local performAction = nil;

local bOneDnD = false;

function onInit()
    rest = CharManager.rest;
    addEffect = EffectManager.addEffect;
    applyDamage = ActionDamage.applyDamage;
    parseEffects = PowerManager.parseEffects;
    reduceExhaustion = CombatManager2.reduceExhaustion;

    CharManager.rest = customRest;
    EffectManager.addEffect = customAddEffect;
    ActionDamage.applyDamage = customApplyDamage;
    PowerManager.parseEffects = customParseEffect;
    CombatManager2.reduceExhaustion = customReduceExhaustion;

    table.insert(DataCommon.conditions, 'exhaustion');
    table.sort(DataCommon.conditions);

    if PowerUp then
        PowerUp.registerExtension('Exhausted', '~dev_version~');
    end

    OptionsManager.registerOption2('EXHAUSTION_HEAL', false, 'option_Exhausted', 'option_Exhaustion_Heal', 'option_entry_cycler',
                                   {
        labels = 'One|Two|Three|Four|Five|Six',
        values = '1|2|3|4|5|6',
        baselabel = 'option_val_off',
        baseval = 'off',
        default = 'Off'
    });
    OptionsManager.registerOption2('EXHAUSTION_NPC', false, 'option_Exhausted', 'option_Exhaustion_NPC', 'option_entry_cycler', {
        labels = 'All|Friend|Foe|Neutral',
        values = 'all|friend|foe|neutral',
        baselabel = 'option_val_off',
        baseval = 'off',
        default = 'Off'
    });
    OptionsManager.registerOption2('ONE_DND_EXHAUSTION', false, 'option_Exhausted', 'option_Exhaustion_One_DND',
                                   'option_entry_cycler', {
        labels = 'One|Two|Three',
        values = '1|2|3',
        baselabel = 'option_val_off',
        baseval = 'off',
        default = 'Off'
    });
    OptionsManager.registerOption2('EXHAUSTION_SDC', false, 'option_Exhausted', 'option_Exhaustion_SDC', 'option_entry_cycler',
                                   {labels = 'On', values = 'on', baselabel = 'option_val_off', baseval = 'off', default = 'Off'});

    OptionsManager.registerCallback('ONE_DND_EXHAUSTION', newDND);
    OptionsManager.registerCallback('GAVE', newDND);
    OptionsManager.registerCallback('EXHAUSTION_SDC', newDND);
end

function onTabletopInit()
    -- 2024 DND
    checkModRoll = ActionCheck.modRoll;
    modAttack = ActionAttack.modAttack;
    modSave = ActionSave.modSave;
    getEffectsBonus = EffectManager5E.getEffectsBonus;
    onCastSave = ActionPower.onCastSave;
    outputResult = ActionsManager.outputResult;
    performAction = ActionsManager.performAction;
    newDND();
end

function onClose()
    EffectManager.addEffect = addEffect;
    CharManager.rest = rest;
    ActionDamage.applyDamage = applyDamage;
    PowerManager.parseEffects = parseEffects;
    CombatManager2.reduceExhaustion = reduceExhaustion;
    OptionsManager.unregisterCallback('GAVE', newDND);
    OptionsManager.unregisterCallback('ONE_DND_EXHAUSTION', newDND);
    ActionCheck.modRoll = checkModRoll;
    ActionAttack.modAttack = modAttack;
    ActionSave.modSave = modSave;
    EffectManager5E.getEffectsBonus = getEffectsBonus;
    ActionPower.onCastSave = onCastSave;
    ActionsManager.outputResult = outputResult;

    ActionsManager.registerModHandler('check', ActionCheck.modRoll);
    ActionsManager.registerModHandler('skill', ActionSkill.modRoll);
    ActionsManager.registerModHandler('attack', ActionAttack.modAttack);
    ActionsManager.registerModHandler('save', ActionSave.modSave);
    ActionsManager.registerModHandler('death', ActionSave.modSave);
    ActionsManager.registerModHandler('death_auto', ActionSave.modSave);
    ActionsManager.registerModHandler('concentration', ActionSave.modSave);
    ActionsManager.registerModHandler('systemshock', ActionSave.modSave);
end

function cleanExhaustionEffect(sUser, _, nodeCT, rNewEffect, bShowMsg)
    local nExhaustionLevel = 0;
    local rTarget = ActorManager.resolveActor(nodeCT);
    local rSource = ActorManager.resolveActor(rNewEffect.sSource);
    local sOriginal = rNewEffect.sName;
    local aImmuneConditions = ActorManager5E.getConditionImmunities(rTarget, rSource);
    local aNewEffectComps = {};
    local aIgnoreComps = {};
    local bImmune = false;
    if StringManager.contains(aImmuneConditions, 'exhaustion') then
        bImmune = true;
    end
    local aEffectComps = EffectManager.parseEffect(rNewEffect.sName);
    for _, sEffectComp in ipairs(aEffectComps) do
        local rEffectComp = EffectManager.parseEffectCompSimple(sEffectComp);
        if rEffectComp.type:lower() == 'exhaustion' or rEffectComp.original:lower() == 'exhaustion' then
            if bImmune then
                table.insert(aIgnoreComps, sEffectComp);
            else
                if rEffectComp.mod == 0 then
                    rEffectComp.mod = 1;
                    sEffectComp = sEffectComp .. ': 1';
                end
                nExhaustionLevel = nExhaustionLevel + rEffectComp.mod;
                table.insert(aNewEffectComps, sEffectComp:upper());
            end
        else
            table.insert(aNewEffectComps, sEffectComp);
        end
    end
    rNewEffect.sName = EffectManager.rebuildParsedEffect(aNewEffectComps);
    if next(aIgnoreComps) then
        if bShowMsg then
            local bSecret = ((rNewEffect.nGMOnly or 0) == 1);
            local sMessage;
            if rNewEffect.sName == '' then
                sMessage = string.format('%s [\'%s\'] -> [%s]', Interface.getString('effect_label'), sOriginal,
                                         Interface.getString('effect_status_targetimmune'));
            else
                sMessage = string.format('%s [\'%s\'] -> [%s] [%s]', Interface.getString('effect_label'), sOriginal,
                                         Interface.getString('effect_status_targetpartialimmune'), table.concat(aIgnoreComps, ','));
            end
            if bSecret then
                EffectManager.message(sMessage, nodeCT, true);
            else
                EffectManager.message(sMessage, nodeCT, false, sUser);
            end
        end
    end
    return nExhaustionLevel;
end

-- Return return the sum total else return nil
function sumExhaustion(rActor, nExhaustionLevel)
    local nSummed = nil;
    local nodeCT = ActorManager.getCTNode(rActor);
    local nodeEffectsList = DB.getChildren(nodeCT, 'effects');

    for _, nodeEffect in pairs(nodeEffectsList) do
        local sEffect = DB.getValue(nodeEffect, 'label', '');
        local aEffectComps = EffectManager.parseEffect(sEffect);
        for i, sEffectComp in ipairs(aEffectComps) do
            local rEffectComp = EffectManager.parseEffectCompSimple(sEffectComp);
            if rEffectComp.type:upper() == 'EXHAUSTION' then
                rEffectComp.mod = rEffectComp.mod + nExhaustionLevel;
                aEffectComps[i] = rEffectComp.type .. ': ' .. tostring(rEffectComp.mod);
                sEffect = EffectManager.rebuildParsedEffect(aEffectComps);
                EffectsManagerExhausted.updateEffect(nodeCT, nodeEffect, sEffect);
                nSummed = rEffectComp.mod;
            end
        end
    end
    return nSummed;
end

function updateEffect(nodeActor, nodeEffect, sLabel)
    DB.setValue(nodeEffect, 'label', 'string', sLabel);
    local bGMOnly = EffectManager.isGMEffect(nodeActor, nodeEffect);
    local sMessage = string.format('%s [\'%s\'] -> [%s]', Interface.getString('effect_label'), sLabel,
                                   Interface.getString('effect_status_updated'));
    EffectManager.message(sMessage, nodeActor, bGMOnly);
end

-- Replace SW code to reduce exhaustion on Rest
function customReduceExhaustion(nodeCT)
    local rActor = ActorManager.resolveActor(nodeCT);
    if not EffectManager.hasCondition(rActor, 'STAYEXHAUST') then
        -- Check conditionals
        local aEffectsByType = EffectManager5E.getEffectsByType(rActor, 'EXHAUSTION');
        if aEffectsByType and next(aEffectsByType) then
            for _, nodeEffect in pairs(DB.getChildren(nodeCT, 'effects')) do
                local sEffect = DB.getValue(nodeEffect, 'label', '');
                local aEffectComps = EffectManager.parseEffect(sEffect);
                for i, sEffectComp in ipairs(aEffectComps) do
                    local rEffectComp = EffectManager.parseEffectCompSimple(sEffectComp);
                    if rEffectComp.type:upper() == 'EXHAUSTION' then
                        rEffectComp.mod = rEffectComp.mod - 1;
                        if rEffectComp.mod >= 1 then
                            aEffectComps[i] = rEffectComp.type .. ': ' .. tostring(rEffectComp.mod);
                            sEffect = EffectManager.rebuildParsedEffect(aEffectComps);
                            EffectsManagerExhausted.updateEffect(nodeCT, nodeEffect, sEffect);
                        else
                            EffectManager.expireEffect(nodeCT, nodeEffect, 0);
                        end
                    end
                end
            end
        end
    end
end

function customRest(nodeChar, bLong)
    local nodeCT = ActorManager.getCTNode(nodeChar);
    local rActor = ActorManager.resolveActor(nodeCT);
    if not bLong and OptionsManager.isOption('GAVE', '2024') then
        local aEffectsByType = EffectManager5E.getEffectsByType(rActor, 'EXHAUSTION');
        if aEffectsByType and next(aEffectsByType) then
            EffectsManagerExhausted.tireless(nodeCT);
        end
    end
    rest(nodeChar, bLong);
end

function customAddEffect(sUser, sIdentity, nodeCT, rNewEffect, bShowMsg)
    if not nodeCT or not rNewEffect or not rNewEffect.sName then
        return addEffect(sUser, sIdentity, nodeCT, rNewEffect, bShowMsg);
    end
    local nExhaustionLevel = EffectsManagerExhausted.cleanExhaustionEffect(sUser, sIdentity, nodeCT, rNewEffect, bShowMsg);
    -- Immune casued an empty effect so ignore
    if rNewEffect.sName == '' then
        return;
    end
    if nExhaustionLevel > 0 then
        local rActor = ActorManager.resolveActor(nodeCT);
        if not EffectsManagerExhausted.sumExhaustion(rActor, nExhaustionLevel) then
            addEffect(sUser, sIdentity, nodeCT, rNewEffect, bShowMsg);
        end;
    else
        addEffect(sUser, sIdentity, nodeCT, rNewEffect, bShowMsg);
    end
end

function customApplyDamage(rSource, rTarget, rRoll)
    if not (OptionsManager.isOption('EXHAUSTION_HEAL', 'off') or OptionsManager.isOption('EXHAUSTION_HEAL', 'Off')) then
        local bDead = false;
        local nTotalHP;
        local nWounds;
        local bNPCReturn = true;
        local sTargetNodeType, nodeTarget = ActorManager.getTypeAndNode(rTarget);
        if not nodeTarget or not rRoll or rRoll.sType ~= 'heal' then
            return applyDamage(rSource, rTarget, rRoll);
        end

        if sTargetNodeType == 'pc' then
            nTotalHP = DB.getValue(nodeTarget, 'hp.total', 0);
            nWounds = DB.getValue(nodeTarget, 'hp.wounds', 0);
        elseif sTargetNodeType == 'ct' or sTargetNodeType == 'npc' then
            local sFaction = ActorManager.getFaction(rTarget);
            if OptionsManager.isOption('EXHAUSTION_NPC', 'friend') and sFaction == 'friend' then
                bNPCReturn = false;
            elseif OptionsManager.isOption('EXHAUSTION_NPC', 'neutral') and sFaction == 'neutral' then
                bNPCReturn = false;
            elseif OptionsManager.isOption('EXHAUSTION_NPC', 'foe') and sFaction == 'foe' then
                bNPCReturn = false;
            elseif OptionsManager.isOption('EXHAUSTION_NPC', 'all') then
                bNPCReturn = false;
            end
            if bNPCReturn then
                return applyDamage(rSource, rTarget, rRoll);
            end

            nTotalHP = DB.getValue(nodeTarget, 'hptotal', 0);
            nWounds = DB.getValue(nodeTarget, 'wounds', 0);
        else
            return applyDamage(rSource, rTarget, rRoll);
        end
        if nTotalHP <= nWounds then
            bDead = true;
        end

        applyDamage(rSource, rTarget, rRoll);

        if sTargetNodeType == 'pc' then
            nWounds = DB.getValue(nodeTarget, 'hp.wounds', 0);
        elseif sTargetNodeType == 'ct' or sTargetNodeType == 'npc' then
            nWounds = DB.getValue(nodeTarget, 'wounds', 0);
        end
        if nTotalHP > nWounds and bDead == true then
            local sExhaustion = 'EXHAUSTION: ' .. OptionsManager.getOption('EXHAUSTION_HEAL');
            EffectManager.addEffect('', '', ActorManager.getCTNode(rTarget), {sName = sExhaustion, nDuration = 0}, true);
        end
    else
        applyDamage(rSource, rTarget, rRoll);
    end
end

function customParseEffect(sPowerName, aWords)
    local effects = parseEffects(sPowerName, aWords);
    local i = 1;
    while aWords[i] do
        if StringManager.isWord(aWords[i], {'gain', 'gains', 'suffer', 'suffers', 'take'}) then
            local bExhaustion = true;
            local sLevel = '0';
            if StringManager.isWord(aWords[i + 1], {'1', 'one', 'another'}) then
                sLevel = '1';
            elseif StringManager.isWord(aWords[i + 1], {'2', 'two'}) then
                sLevel = '2';
            elseif StringManager.isWord(aWords[i + 1], {'3', 'three'}) then
                sLevel = '3';
            elseif StringManager.isWord(aWords[i + 1], {'4', 'four'}) then
                sLevel = '4';
            elseif StringManager.isWord(aWords[i + 1], {'5', 'five'}) then
                sLevel = '5';
            elseif StringManager.isWord(aWords[i + 1], {'6', 'six'}) then
                sLevel = '6';
            else
                bExhaustion = false;
            end
            if bExhaustion == true and StringManager.isWord(aWords[i + 2], {'level', 'levels'}) and
                StringManager.isWord(aWords[i + 3], 'of') and StringManager.isWord(aWords[i + 4], 'exhaustion') then
                local rExhaustion = {};
                rExhaustion.sName = 'EXHAUSTION: ' .. sLevel;
                rExhaustion.startindex = i;
                rExhaustion.endindex = i + 4;
                PowerManager.parseEffectsAdd(aWords, i, rExhaustion, effects);
            end
        end
        i = i + 1;
    end
    return effects;
end

--------------- 2024 DND ------------------
function newDND()
    if not bOneDnD and (OptionsManager.isOption('GAVE', '2024') or
        (not OptionsManager.isOption('GAVE', '2024') and not OptionsManager.isOption('ONE_DND_EXHAUSTION', 'off'))) then
        bOneDnD = true;
        ActionCheck.modRoll = customCheckModRoll;
        ActionAttack.modAttack = customModAttack;
        ActionSave.modSave = customModSave;
        EffectManager5E.getEffectsBonus = customGetEffectsBonus;

        ActionsManager.outputResult = customOutputResult;

        ActionsManager.registerModHandler('check', customCheckModRoll);
        ActionsManager.registerModHandler('attack', customModAttack);
        ActionsManager.registerModHandler('save', customModSave);
        ActionsManager.registerModHandler('death', customModSave);
        ActionsManager.registerModHandler('death_auto', customModSave);
        ActionsManager.registerModHandler('concentration', customModSave);
        ActionsManager.registerModHandler('systemshock', customModSave);

        ActionsManager.performAction = customPerformAction;
    elseif bOneDnD and not (OptionsManager.isOption('GAVE', '2024') or not OptionsManager.isOption('ONE_DND_EXHAUSTION', 'off')) then
        bOneDnD = false;
        ActionCheck.modRoll = checkModRoll;
        ActionAttack.modAttack = modAttack;
        ActionSave.modSave = modSave;
        EffectManager5E.getEffectsBonus = getEffectsBonus;
        ActionsManager.outputResult = outputResult;

        ActionsManager.registerModHandler('check', checkModRoll);
        ActionsManager.registerModHandler('attack', modAttack);
        ActionsManager.registerModHandler('save', modSave);
        ActionsManager.registerModHandler('death', modSave);
        ActionsManager.registerModHandler('death_auto', modSave);
        ActionsManager.registerModHandler('concentration', modSave);
        ActionsManager.registerModHandler('systemshock', modSave);

        ActionsManager.performAction = performAction;
    end
    if bOneDnD and OptionsManager.isOption('EXHAUSTION_SDC', 'on') then
        ActionPower.onCastSave = customOnCastSave;
    else
        ActionPower.onCastSave = onCastSave;
    end
end

-- Scrub out any EXHAUSTION queires here for 2024 DND so 5E mods are not applied.
function customGetEffectsBonus(rActor, aEffectType, bModOnly, aFilter, rFilterActor, bTargetedOnly)
    if not rActor or not aEffectType then
        if bModOnly then
            return 0, 0;
        end
        return {}, 0, 0;
    end
    if type(aEffectType) ~= 'table' then
        aEffectType = {aEffectType};
    end
    for k, v in pairs(aEffectType) do
        if v == 'EXHAUSTION' then
            table.remove(aEffectType, k);
        end
    end
    return getEffectsBonus(rActor, aEffectType, bModOnly, aFilter, rFilterActor, bTargetedOnly);
end

function newDNDModExhaustion(rSource, _, rRoll)
    local nExhaustMod, nExhaustCount = getEffectsBonus(rSource, {'EXHAUSTION'}, true);
    if nExhaustCount > 0 then
        if nExhaustMod >= 1 then
            if OptionsManager.isOption('ONE_DND_EXHAUSTION', 'off') or OptionsManager.isOption('ONE_DND_EXHAUSTION', '2') then
                nExhaustMod = nExhaustMod * 2;
            elseif OptionsManager.isOption('ONE_DND_EXHAUSTION', '3') then
                nExhaustMod = nExhaustMod * 3;
            end
            rRoll.nMod = rRoll.nMod - nExhaustMod;
            rRoll.sDesc = rRoll.sDesc .. ' [EXHAUSTED -' .. tostring(nExhaustMod) .. ']';
        end
    end
end

function customOutputResult(bSecret, rSource, rOrigin, msgLong, msgShort)
    local sSubString = msgLong.text:match('%[vs%.%s*DC%s*%d+%]');
    if sSubString then
        local nExhaustMod, nExhaustCount = getEffectsBonus(rOrigin, {'EXHAUSTION'}, true);
        if nExhaustCount > 0 and nExhaustMod >= 1 then
            if OptionsManager.isOption('ONE_DND_EXHAUSTION', 'off') or OptionsManager.isOption('ONE_DND_EXHAUSTION', '2') then
                nExhaustMod = nExhaustMod * 2;
            elseif OptionsManager.isOption('ONE_DND_EXHAUSTION', '3') then
                nExhaustMod = nExhaustMod * 3;
            end
            sSubString = sSubString:gsub('%[', '%%[');
            local sModSubString = sSubString .. '%[EXHAUSTED -' .. tostring(nExhaustMod) .. ']';
            msgLong.text = msgLong.text:gsub(sSubString, sModSubString);
        end
    end
    outputResult(bSecret, rSource, rOrigin, msgLong, msgShort);
end

function customOnCastSave(rSource, rTarget, rRoll)
    local nExhaustMod, nExhaustCount = getEffectsBonus(rSource, {'EXHAUSTION'}, true);
    if nExhaustCount > 0 and nExhaustMod >= 1 then
        if OptionsManager.isOption('ONE_DND_EXHAUSTION', 'off') or OptionsManager.isOption('ONE_DND_EXHAUSTION', '2') then
            nExhaustMod = nExhaustMod * 2;
        elseif OptionsManager.isOption('ONE_DND_EXHAUSTION', '3') then
            nExhaustMod = nExhaustMod * 3;
        end
        rRoll.nMod = rRoll.nMod - nExhaustMod;
        local sSubString = rRoll.sDesc:match('%[%s*%a+%s*DC%s*%d+%]'):gsub('%[', '%%[');
        local sDC = sSubString:match('(%d+)');
        local sModSubString = sSubString:gsub(sDC, tostring(rRoll.nMod));
        rRoll.sDesc = rRoll.sDesc:gsub(sSubString, sModSubString);
        rRoll.sDesc = rRoll.sDesc .. ' [EXHAUSTED -' .. tostring(nExhaustMod) .. ']';
    end
    return onCastSave(rSource, rTarget, rRoll);
end

function customCheckModRoll(rSource, rTarget, rRoll)
    EffectsManagerExhausted.newDNDModExhaustion(rSource, rTarget, rRoll);
    return checkModRoll(rSource, rTarget, rRoll);
end

function customModAttack(rSource, rTarget, rRoll)
    EffectsManagerExhausted.newDNDModExhaustion(rSource, rTarget, rRoll);
    return modAttack(rSource, rTarget, rRoll);
end

function customModSave(rSource, rTarget, rRoll)
    EffectsManagerExhausted.newDNDModExhaustion(rSource, rTarget, rRoll);
    return modSave(rSource, rTarget, rRoll);
end

function tireless(nodeCT)
    local rActor = ActorManager.resolveActor(nodeCT)
    local sNodeType, nodeActor = ActorManager.getTypeAndNode(rActor);
    if sNodeType == 'pc' then
        for _, nodeClass in pairs(DB.getChildren(nodeActor, 'classes')) do
            local sClassName = StringManager.trim(DB.getValue(nodeClass, 'name', '')):lower();
            if sClassName:match('ranger') then
                for _, nodeFeature in pairs(DB.getChildren(nodeActor, 'featurelist')) do
                    local sFeatureName = StringManager.trim(DB.getValue(nodeFeature, 'name', ''):lower());
                    if sFeatureName:match('tireless') then
                        EffectsManagerExhausted.customReduceExhaustion(nodeCT);
                        break
                    end
                end
                break
            end
        end
    end
end

function customPerformAction(draginfo, rActor, rRoll)
    if rRoll and rRoll.sType and (rRoll.sType == 'genactroll' or rRoll.sType == 'genactresult') then
        EffectsManagerExhausted.newDNDModExhaustion(rActor, nil, rRoll);
    end
    performAction(draginfo, rActor, rRoll);
end

function is2024()
    return bOneDnD;
end
