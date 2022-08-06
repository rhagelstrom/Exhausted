--  	Author: Ryan Hagelstrom
--	  	Copyright © 2021-2022
--	  	This work is licensed under a Creative Commons Attribution-ShareAlike 4.0 International License.
--	  	https://creativecommons.org/licenses/by-sa/4.0/

local rest = nil
local addEffect = nil
local applyDamage = nil
local parseEffects = nil
local reduceExhaustion = nil

function onInit()
	rest = CombatManager2.rest
	addEffect = EffectManager.addEffect
	applyDamage = ActionDamage.applyDamage
	parseEffects = PowerManager.parseEffects
	reduceExhaustion = CombatManager2.reduceExhaustion

	CombatManager2.rest = customRest
	EffectManager.addEffect = customAddEffect
	ActionDamage.applyDamage = customApplyDamage
	PowerManager.parseEffects = customParseEffect
	CombatManager2.reduceExhaustion = customReduceExhaustion

	table.insert(DataCommon.conditions, "exhaustion")
	table.sort(DataCommon.conditions)

	OptionsManager.registerOption2("VERBOSE_EXHAUSTION", false, "option_Exhausted",
	"option_Exhaustion_Verbose", "option_entry_cycler",
		{
			labels = "MNM|Verbose",
			values = "mnm|verbose",
			baselabel = "option_val_off",
			baseval = "off",
			default = "Off" }
		)
	OptionsManager.registerOption2("EXHAUSTION_HEAL", false, "option_Exhausted",
		"option_Exhaustion_Heal", "option_entry_cycler",
		{
			labels = "One|Two|Three|Four|Five|Six",
			values = "1|2|3|4|5|6",
			baselabel = "option_val_off",
			baseval = "off",
			default = "Off"
		})
	OptionsManager.registerOption2("EXHAUSTION_NPC", false, "option_Exhausted",
	"option_Exhaustion_NPC", "option_entry_cycler",
		{
			labels = "All|Friend|Foe|Faction|Neutral",
			values = "all|friend|foe|faction|neutral",
			baselabel = "option_val_off",
			baseval = "off",
			default = "Off" }
		)
end

function onClose()
	EffectManager.addEffect = addEffect
	CombatManager2.rest = rest
	ActionDamage.applyDamage = applyDamage
	PowerManager.parseEffects = parseEffects
	CombatManager2.reduceExhaustion = reduceExhaustion
end

-- Disable SW code to reduce exhaustion on Rest
function customReduceExhaustion()
end

function customRest(bLong)
	if bLong then
		for _,nodeCT in pairs(CombatManager.getCombatantNodes()) do
			if EffectManager5E.hasEffectCondition(nodeCT, "Exhaustion") then
				exhaustionRest(nodeCT)
			end
		end
	end
	rest(bLong)
end

function exhaustionRest(nodeCT)
	for _,nodeEffect in pairs(DB.getChildren(nodeCT, "effects")) do
		local sEffect = DB.getValue(nodeEffect, "label", "")
		local aEffectComps = EffectManager.parseEffect(sEffect)

		for i,sEffectComp in ipairs(aEffectComps) do
			local rEffectComp = EffectManager.parseEffectCompSimple(sEffectComp)
			if rEffectComp.type:lower() == "exhaustion" then
				rEffectComp.mod  = rEffectComp.mod - 1
				if  rEffectComp.mod >= 1 then
					aEffectComps[i] = rEffectComp.type .. ": " .. tostring(rEffectComp.mod)
					sEffect = EffectManager.rebuildParsedEffect(aEffectComps)
					sEffect = exhaustionText(sEffect, nodeCT, rEffectComp.mod)
					updateEffect(nodeCT, nodeEffect, sEffect)
				else
					EffectManager.expireEffect(nodeCT, nodeEffect, 0)
				end
			end
		end
	end
end

function cleanExhaustionEffect(rNewEffect)
	local nExhaustionLevel = 0
	local bHasLabel = false
	local bExhaustion = false
	local aEffectComps = EffectManager.parseEffect(rNewEffect.sName)
	for i,sEffectComp in ipairs(aEffectComps) do
		local rEffectComp = EffectManager.parseEffectCompSimple(sEffectComp)
		if sEffectComp:lower() == "exhaustion"  then
			bHasLabel = true
			if not bExhaustion then
				nExhaustionLevel = 1
			end
		end
		if rEffectComp.type:lower() == "exhaustion" then
			if rEffectComp.mod == 0  then
				rEffectComp.mod = 1
			end
			--must be caps to process correctly
			aEffectComps[i] = sEffectComp:upper()
			bExhaustion = true
			nExhaustionLevel = rEffectComp.mod
		end
	end
	-- We need an exhaustion label because EffectManager5E.hasEffectCondition doesn't process variable mods
	if not bHasLabel and bExhaustion then
		table.insert(aEffectComps, 1, "Exhaustion")
	elseif bHasLabel and not bExhaustion then
		table.insert(aEffectComps, "EXHAUSTION: 1")
	end

	rNewEffect.sName = EffectManager.rebuildParsedEffect(aEffectComps)
	return nExhaustionLevel
end

function customAddEffect(sUser, sIdentity, nodeCT, rNewEffect, bShowMsg)
	if not nodeCT or not rNewEffect or not rNewEffect.sName then
		return addEffect(sUser, sIdentity, nodeCT, rNewEffect, bShowMsg)
	end

	local nExhaustionLevel = cleanExhaustionEffect(rNewEffect)
	if nExhaustionLevel > 0  then
		local aCancelled = EffectManager5E.checkImmunities(nil, nodeCT, rNewEffect)
		if #aCancelled > 0 then
			local sMessage = string.format("%s ['%s'] -> [%s]", Interface.getString("effect_label"), rNewEffect.sName, Interface.getString("effect_status_targetimmune"))
			EffectManager.message(sMessage, nodeCT, false, sUser);
			return
		end
		if  EffectManager5E.hasEffectCondition(nodeCT, "exhaustion") and sumExhaustion(nodeCT, nExhaustionLevel) then
			return
		else
			rNewEffect.sName = exhaustionText(rNewEffect.sName, nodeCT, nExhaustionLevel)
		end
	end
	addEffect(sUser, sIdentity, nodeCT, rNewEffect, bShowMsg)
end

function sumExhaustion(nodeCT, nExhaustionLevel)
	local bSummed = false
	local nodeEffectsList = DB.getChildren(nodeCT, "effects")
	for _, nodeEffect in pairs(nodeEffectsList) do
		local sEffect = DB.getValue(nodeEffect, "label", "")
		local aEffectComps = EffectManager.parseEffect(sEffect)
		for i,sEffectComp in ipairs(aEffectComps) do
			local rEffectComp = EffectManager.parseEffectCompSimple(sEffectComp)
			if rEffectComp.type:lower() == "exhaustion"  then
				rEffectComp.mod = rEffectComp.mod + nExhaustionLevel
				aEffectComps[i] = rEffectComp.type .. ": " .. tostring(rEffectComp.mod)
				sEffect = EffectManager.rebuildParsedEffect(aEffectComps)
				sEffect = exhaustionText(sEffect, nodeCT, rEffectComp.mod)
				updateEffect(nodeCT, nodeEffect, sEffect)
				bSummed = true
			end
		end
	end
	return bSummed
end

function updateEffect(nodeActor, nodeEffect, sLabel)
	DB.setValue(nodeEffect, "label", "string", sLabel)
	local bGMOnly = EffectManager.isGMEffect(nodeActor, nodeEffect)
	local sMessage = string.format("%s ['%s'] -> [%s]", Interface.getString("effect_label"), sLabel, Interface.getString("effect_status_updated"))
	EffectManager.message(sMessage, nodeActor, bGMOnly)
end

--Add extra text and also comptibility with Mad Nomads Character Sheet Effects Display Extension
--The real solution is for mad nomad support exhaustion in his code.
function exhaustionText(sEffect, nodeCT,  nLevel)
	if OptionsManager.isOption("VERBOSE_EXHAUSTION", "off") then
		return sEffect
	end
	local rActor = ActorManager.resolveActor(nodeCT)
	local sNodeType, nodeActor = ActorManager.getTypeAndNode(rActor)
	local nSpeed = DB.getValue(nodeActor, "speed.base", 0)
	local nHPMax = DB.getValue(nodeActor, "hp.base", 0)
	local sDisCheck = "; DISCHK: strength; DISCHK: dexterity; DISCHK: constitution; DISCHK: intelligence; DISCHK: wisdom; DISCHK: charisma"
	local sDisSave = "; DISATK; DISSAV: strength; DISSAV: dexterity; DISSAV: constitution; DISSAV: intelligence; DISSAV: wisdom; DISSAV: charisma"
	local sSpeed = "; Speed-"
	local sHPMax = "; MAXHP: -"
	sEffect = sEffect:gsub(";?%s?Speed%-?%+?%d+;?", "")
	sEffect = sEffect:gsub(";?%s?MAXHP%:%s?%-?%+?%d+;?", "")
	sEffect = sEffect:gsub(";?%s?DISATK;%sDISSAV:%sstrength;%sDISSAV:%sdexterity;%sDISSAV:%sconstitution;%sDISSAV:%sintelligence;%sDISSAV:%swisdom;%sDISSAV:%scharisma;?", "")

	if OptionsManager.isOption("VERBOSE_EXHAUSTION", "verbose") and not sEffect:match(sDisCheck) then
		sEffect = sEffect .. sDisCheck
	end
	if (nLevel == 2) then
		sEffect = sEffect .. sSpeed ..tostring(math.ceil(nSpeed / 2))
	elseif (nLevel == 3) then
		if OptionsManager.isOption("VERBOSE_EXHAUSTION", "verbose") then
			sEffect = sEffect .. sDisSave
		end
		sEffect = sEffect .. sSpeed ..tostring(math.ceil(nSpeed / 2))
	elseif (nLevel == 4) then
		if OptionsManager.isOption("VERBOSE_EXHAUSTION", "verbose") then
			sEffect = sEffect .. sDisSave
		end
		sEffect = sEffect .. sHPMax ..tostring(math.ceil(nHPMax / 2))
		sEffect = sEffect .. sSpeed ..tostring(math.ceil(nSpeed / 2))
	elseif (nLevel == 5) then
		if OptionsManager.isOption("VERBOSE_EXHAUSTION", "verbose") then
			sEffect = sEffect .. sDisSave
		end
		sEffect = sEffect .. sHPMax ..tostring(math.ceil(nHPMax / 2))
		sEffect = sEffect .. sSpeed .. tostring(nSpeed)
	elseif (nLevel >= 6) then
		if OptionsManager.isOption("VERBOSE_EXHAUSTION", "verbose") then
			sEffect = sEffect .. sDisSave
		end
		sEffect = sEffect .. sHPMax ..tostring(nHPMax)
		sEffect = sEffect .. sSpeed .. tostring(nSpeed)
	end
	return sEffect
end

function customApplyDamage(rSource, rTarget, rRoll)
	if not OptionsManager.isOption("EXHAUSTION_HEAL", "off") then
		local bDead = false
		local nTotalHP
		local nWounds
		local bNPCReturn = true
		local sTargetNodeType, nodeTarget = ActorManager.getTypeAndNode(rTarget)
		if not nodeTarget then
			return applyDamage(rSource, rTarget, rRoll)
		end

		if sTargetNodeType == "pc" then
			nTotalHP = DB.getValue(nodeTarget, "hp.total", 0)
			nWounds = DB.getValue(nodeTarget, "hp.wounds", 0)
		elseif sTargetNodeType == "ct" or sTargetNodeType == "npc" then
			local sFaction = ActorManager.getFaction(rTarget)
			if OptionsManager.isOption("EXHAUSTION_NPC", "friend") and sFaction == "friend" then
				bNPCReturn = false
			elseif OptionsManager.isOption("EXHAUSTION_NPC", "faction") and (sFaction == "faction" or  sFaction == "") then
				bNPCReturn = false
			elseif OptionsManager.isOption("EXHAUSTION_NPC", "neutral") and sFaction == "neutral" then
				bNPCReturn = false
			elseif OptionsManager.isOption("EXHAUSTION_NPC", "foe") and sFaction == "foe" then
				bNPCReturn = false
			elseif OptionsManager.isOption("EXHAUSTION_NPC", "all") then
				bNPCReturn = false
			end
			if bNPCReturn then
				return applyDamage(rSource, rTarget, rRoll)
			end

			nTotalHP = DB.getValue(nodeTarget, "hptotal", 0)
			nWounds = DB.getValue(nodeTarget, "wounds", 0)
		else
			return applyDamage(rSource, rTarget, rRoll)
		end
		if nTotalHP <= nWounds then
			bDead = true
		end

		applyDamage(rSource, rTarget, rRoll)

		if sTargetNodeType ~= "pc" then
			nWounds = DB.getValue(nodeTarget, "hp.wounds", 0)
		elseif sTargetNodeType == "ct" or sTargetNodeType == "npc" then
			nWounds = DB.getValue(nodeTarget, "wounds", 0)
		end
		if nTotalHP > nWounds and bDead == true then
			local sExhaustion = "EXHAUSTION: " .. OptionsManager.getOption("EXHAUSTION_HEAL")
			EffectManager.addEffect("", "", ActorManager.getCTNode(rTarget), { sName = sExhaustion, nDuration = 0 }, true)
		end
	else
		applyDamage(rSource, rTarget, rRoll)
	end
end

function customParseEffect(sPowerName, aWords)
	local effects = parseEffects(sPowerName,aWords)
	local i = 1;
	while aWords[i] do
		if StringManager.isWord(aWords[i],  {"gain","gains","suffer","suffers", "take" }) then
			local bExhaustion = true
			local sLevel = "0"
			if StringManager.isWord(aWords[i+1],  { "1", "one", "another" }) then
				sLevel = "1"
			elseif StringManager.isWord(aWords[i+1],  { "2", "two" }) then
				sLevel = "2"
			elseif StringManager.isWord(aWords[i+1],  { "3", "three" }) then
				sLevel = "3"
			elseif StringManager.isWord(aWords[i+1],  { "4", "four" }) then
				sLevel = "4"
			elseif StringManager.isWord(aWords[i+1],  { "5", "five" }) then
				sLevel = "5"
			elseif StringManager.isWord(aWords[i+1],  { "6", "six" }) then
				sLevel = "6"
			else
				bExhaustion = false
			end
			if bExhaustion == true and
				StringManager.isWord(aWords[i+2], {"level", "levels"}) and
				StringManager.isWord(aWords[i+3], "of") and
				StringManager.isWord(aWords[i+4], "exhaustion") then
					local rExhaustion = {}
					rExhaustion.sName = "EXHAUSTION: " .. sLevel
					rExhaustion.startindex = i
					rExhaustion.endindex = i+4
					PowerManager.parseEffectsAdd(aWords, i, rExhaustion, effects)
				end
		end
		i = i+1
	end
	return effects
end
