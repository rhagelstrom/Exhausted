--  	Author: Ryan Hagelstrom
--	  	Copyright © 2021
--	  	This work is licensed under a Creative Commons Attribution-ShareAlike 4.0 International License.
--	  	https://creativecommons.org/licenses/by-sa/4.0/
local rest = nil
local addEffect = nil

function customRest(bLong)
	if bLong then
		for _,nodeActor in pairs(CombatManager.getCombatantNodes()) do
			for _,nodeEffect in pairs(DB.getChildren(nodeActor, "effects")) do
				if  DB.getValue(nodeEffect, "isactive", 0) == 1 then
					exhaustionRest(nodeEffect,nodeActor)
				end
			end
		end
	end
	rest(bLong)
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
			local sMessage = string.format("%s ['%s'] -> [%s]", Interface.getString("effect_label"), rNewEffect.sName, Interface.getString("effect_status_targetimmune"));
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
			local sEffect = DB.getValue(nodeEffect, "label", "");
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
	elseif (nLevel >= 5) then
		if OptionsManager.isOption("VERBOSE_EXHAUSTION", "on") then
			sEffect = sEffect .. sDisSave
		end
		sEffect = sEffect .. sHPMax ..tostring(math.ceil(nHPMax / 2))
		sEffect = sEffect .. sSpeed .. tostring(nSpeed)
	end
	return sEffect
end

function onInit()
	rest = CombatManager2.rest
	CombatManager2.rest = customRest
	addEffect = EffectManager.addEffect
	EffectManager.addEffect = customAddEffect

	table.insert(DataCommon.conditions, "exhaustion")
	table.sort(DataCommon.conditions)

	OptionsManager.registerOption2("VERBOSE_EXHAUSTION", false, "option_header_game", 
	"option_Exhaustion_Verbose", "option_entry_cycler", 
	{ labels = "option_val_on", values = "on",
		baselabel = "option_val_off", baseval = "off", default = "off" })  
end

function onClose()
	EffectManager.addEffect = addEffect
	CombatManager2.rest = rest

end