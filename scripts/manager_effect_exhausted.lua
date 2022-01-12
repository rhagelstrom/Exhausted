--  	Author: Ryan Hagelstrom
--	  	Copyright © 2021
--	  	This work is licensed under a Creative Commons Attribution-ShareAlike 4.0 International License.
--	  	https://creativecommons.org/licenses/by-sa/4.0/
local restChar = nil
local addEffect = nil
local applyDamage = nil
local parseEffects = nil
local reduceExhaustion = nil

function customRestChar(nodeActor, bLong)
	if bLong then
		local nodeCT = ActorManager.getCTNode(nodeActor)
		for _,nodeEffect in pairs(DB.getChildren(nodeCT, "effects")) do
			if  DB.getValue(nodeEffect, "isactive", 0) == 1 then
				exhaustionRest(nodeEffect,nodeCT)
			end
		end
	end
	restChar(nodeActor, bLong)
end

function exhaustionRest(nodeEffect, nodeActor)
	local sEffect = DB.getValue(nodeEffect, "label", "")
	local aEffectComps = EffectManager.parseEffect(sEffect)
	for i,sEffectComp in ipairs(aEffectComps) do
		local rEffectComp = EffectManager.parseEffectCompSimple(sEffectComp)
		if rEffectComp.type == "EXHAUSTION" and rEffectComp.mod ~= nil then
			local nExhaustionLevel = tonumber(rEffectComp.mod) - 1
			if  nExhaustionLevel >= 1 then
				rEffectComp.mod =  tostring(nExhaustionLevel)
				aEffectComps[i] = rEffectComp.type .. ": " .. rEffectComp.mod							
				sEffect = EffectManager.rebuildParsedEffect(aEffectComps)
				sEffect = exhaustionText(sEffect, nodeActor, nExhaustionLevel)
				updateEffect(nodeActor, nodeEffect, sEffect)
			else
				EffectManager.expireEffect(nodeActor, nodeEffect, 0)
			end
		end
	end
end

function cleanExhaustionEffect(rNewEffect)
	local nExhaustionLevel = 0
	local bHasLabel = false
	local bHasType = false

	local aEffectComps = EffectManager.parseEffect(rNewEffect.sName)
	for i,sEffectComp in ipairs(aEffectComps) do
		local rEffectComp = EffectManager.parseEffectCompSimple(sEffectComp)
		if string.lower(sEffectComp) == "exhaustion"  then
			bHasLabel = true
		end
		if rEffectComp.type == "EXHAUSTION" then
			bHasType = true
			if tonumber(rEffectComp.mod) == nil then
				rEffectComp.mod = "1"
				nExhaustionLevel = 1
			else
				nExhaustionLevel = tonumber(rEffectComp.mod)
			end
		end
	end
	if bHasLabel == false and bHasType == true then
		table.insert(aEffectComps, "Exhaustion")
	end
	if bHasLabel == true and bHasType == false then
		table.insert(aEffectComps, "EXHAUSTION: 1")
		nExhaustionLevel = 1
	end
	rNewEffect.sName = EffectManager.rebuildParsedEffect(aEffectComps)
	return nExhaustionLevel
end

function customAddEffect(sUser, sIdentity, nodeCT, rNewEffect, bShowMsg)
	if not nodeCT or not rNewEffect or not rNewEffect.sName then
		return
	end
	local nodeEffectsList = nodeCT.createChild("effects")
	if not nodeEffectsList then
		return
	end
	local nExhaustionLevel = cleanExhaustionEffect(rNewEffect)
	if nExhaustionLevel > 0  then
		local aCancelled = EffectManager5E.checkImmunities(nil, nodeCT, rNewEffect)
		if #aCancelled > 0 then
			local sMessage = string.format("%s ['%s'] -> [%s]", Interface.getString("effect_label"), rNewEffect.sName, Interface.getString("effect_status_targetimmune"))
			EffectManager.message(sMessage, nodeCT, false, sUser);
			return
		end
		if  EffectManager5E.hasEffectCondition(nodeCT, "Exhaustion") and sumExhaustion(rNewEffect, nodeCT, nodeEffectsList, nExhaustionLevel) then
			return
		else
			rNewEffect.sName = exhaustionText(rNewEffect.sName, nodeCT, nExhaustionLevel)
		end
	end
	addEffect(sUser, sIdentity, nodeCT, rNewEffect, bShowMsg)
end

function sumExhaustion(rNewEffect, nodeCT, nodeEffectsList, nExhaustionLevel)
	local bSummed = false
	for k, nodeEffect in pairs(nodeEffectsList.getChildren()) do
		if  DB.getValue(nodeEffect, "isactive", 0) == 1 then
			local sEffect = DB.getValue(nodeEffect, "label", "")
			local aEffectComps = EffectManager.parseEffect(sEffect)
			for i,sEffectComp in ipairs(aEffectComps) do
				local rEffectComp = EffectManager.parseEffectCompSimple(sEffectComp)
				if rEffectComp.type == "EXHAUSTION" and rEffectComp.mod ~= nil  then
					local nExhaustionLevel =tonumber(rEffectComp.mod) + nExhaustionLevel
					rEffectComp.mod = tostring(nExhaustionLevel)
					aEffectComps[i] = rEffectComp.type .. ": " .. rEffectComp.mod
					sEffect = EffectManager.rebuildParsedEffect(aEffectComps)
					sEffect = exhaustionText(sEffect, nodeCT, nExhaustionLevel)
					updateEffect(nodeCT, nodeEffect, sEffect)
					bSummed = true
				end
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

-- Disable SW code to reduce exhaustion on Rest
function customReduceExhaustion()
end

--Add extra text and also comptibility with Mad Nomads Character Sheet Effects Display Extension
function exhaustionText(sEffect, nodeCT,  nLevel)
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

	if OptionsManager.isOption("VERBOSE_EXHAUSTION", "on") and not sEffect:match(sDisCheck) then
		sEffect = sEffect .. sDisCheck
	end
	if (nLevel == 2) then
		sEffect = sEffect .. sSpeed ..tostring(math.ceil(nSpeed / 2)) 
	elseif (nLevel == 3) then
		if OptionsManager.isOption("VERBOSE_EXHAUSTION", "on") then
			sEffect = sEffect .. sDisSave
		end
		sEffect = sEffect .. sSpeed ..tostring(math.ceil(nSpeed / 2)) 
	elseif (nLevel == 4) then
		if OptionsManager.isOption("VERBOSE_EXHAUSTION", "on") then
			sEffect = sEffect .. sDisSave
		end
		sEffect = sEffect .. sHPMax ..tostring(math.ceil(nHPMax / 2)) 
		sEffect = sEffect .. sSpeed ..tostring(math.ceil(nSpeed / 2)) 
	elseif (nLevel == 5) then
		if OptionsManager.isOption("VERBOSE_EXHAUSTION", "on") then
			sEffect = sEffect .. sDisSave
		end
		sEffect = sEffect .. sHPMax ..tostring(math.ceil(nHPMax / 2))
		sEffect = sEffect .. sSpeed .. tostring(nSpeed)
	elseif (nLevel >= 6) then
		if OptionsManager.isOption("VERBOSE_EXHAUSTION", "on") then
			sEffect = sEffect .. sDisSave
		end
		sEffect = sEffect .. sHPMax ..tostring(nHPMax)
		sEffect = sEffect .. sSpeed .. tostring(nSpeed)
	end
	return sEffect
end

function customApplyDamage(rSource, rTarget, bSecret, sDamage, nTotal) 
	if not OptionsManager.isOption("EXHAUSTION_HEAL", "off") then
		local bDead = false  
		local sTargetNodeType, nodeTarget = ActorManager.getTypeAndNode(rTarget)
		if not nodeTarget or sTargetNodeType ~= "pc" then
			return applyDamage(rSource, rTarget, bSecret, sDamage, nTotal)
		end
		local nTotalHP = DB.getValue(nodeTarget, "hp.total", 0)
		local nWounds = DB.getValue(nodeTarget, "hp.wounds", 0)
		if nTotalHP == nWounds then
			bDead = true 
		end
		applyDamage(rSource, rTarget, bSecret, sDamage, nTotal)
		nWounds = DB.getValue(nodeTarget, "hp.wounds", 0)
		if nTotalHP > nWounds and bDead == true then
			local sExhaustion = "EXHAUSTION: " .. OptionsManager.getOption("EXHAUSTION_HEAL")
			EffectManager.addEffect("", "", ActorManager.getCTNode(rTarget), { sName = sExhaustion, nDuration = 0 }, true)
		end
	else
		applyDamage(rSource, rTarget, bSecret, sDamage, nTotal)
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

function onInit()
	restChar = CharManager.rest
	CharManager.rest = customRestChar

	addEffect = EffectManager.addEffect
	EffectManager.addEffect = customAddEffect

	applyDamage = ActionDamage.applyDamage
	ActionDamage.applyDamage = customApplyDamage

	parseEffects = PowerManager.parseEffects
	PowerManager.parseEffects = customParseEffect
	
	reduceExhaustion = CombatManager2.reduceExhaustion
	CombatManager2.reduceExhaustion = customReduceExhaustion

	table.insert(DataCommon.conditions, "exhaustion")
	table.sort(DataCommon.conditions)

	OptionsManager.registerOption2("VERBOSE_EXHAUSTION", false, "option_header_game", 
	"option_Exhaustion_Verbose", "option_entry_cycler", 
	{ labels = "option_val_on", values = "on",
		baselabel = "option_val_off", baseval = "off", default = "off" })  
	OptionsManager.registerOption2("EXHAUSTION_HEAL", false, "option_header_houserule", 
		"option_Exhaustion_Heal", "option_entry_cycler", 
		{ 	
			labels = "one|two|three|four|five|six", 
			values = "1|2|3|4|5|6",
			baselabel = "option_val_off", 
			baseval = "off", 
			default = "off" 
		})  
end

function onClose()
	EffectManager.addEffect = addEffect
	CharManager.rest = restChar
	ActionDamage.applyDamage = applyDamage
	PowerManager.parseEffects = parseEffects
	CombatManager2.reduceExhaustion = reduceExhaustion
end