-- UniqueUnitLine_Utilities
-- Author: HungryForFood
-- DateCreated: 3/22/2020 2:58:32 PM
--=======================================================================================================================
if (not GameInfo) then return end
--=======================================================================================================================
-- INCLUDES
--=======================================================================================================================
--=======================================================================================================================
-- GLOBALS
--=======================================================================================================================
------------------------------------------------------------------------------------------------------------------------
-- do we consider if we have unlocked the unique unit before granting the its promotions?
g_bRequireTech = false
for tRequireTech in DB.Query("SELECT Value FROM COMMUNITY WHERE Type = \"UNIQUE_UNIT_LINES_REQUIRE_TECH\"") do
	if tRequireTech.Value == 1 then
		g_bRequireTech = true
	end
end
--=======================================================================================================================
-- CACHED TABLES
--=======================================================================================================================
-------------------------------------------------------------------------------------------------------------------------
-- g_tUnitCombats
-- this is just the ID and Type from UnitCombatInfos, caching for speed as this will be checked often
local g_tUnitCombats = {}
for row in DB.Query("SELECT ID, Type FROM UnitCombatInfos;") do 	
	g_tUnitCombats[row.ID] = row.Type
end

-- g_tUnitClasses
-- this is just the ID and Type from UnitClasses, caching for speed as this will be checked often
local g_tUnitClasses = {}
for row in DB.Query("SELECT ID, Type FROM UnitClasses;") do 	
	g_tUnitClasses[row.ID] = row.Type
end
--=======================================================================================================================
-- GAME DEFINES
--=======================================================================================================================
------------------------------------------------------------------------------------------------------------------------
local iCivilizationBarbarian = GameInfoTypes["CIVILIZATION_BARBARIAN"]
local iCivilizationMinor = GameInfoTypes["CIVILIZATION_MINOR"]
local iCivilizationByzantium = GameInfoTypes["CIVILIZATION_BYZANTIUM"]

local iTechChivalry = GameInfoTypes["TECH_CHIVALRY"]

local iPromotionSmallCityPenalty = GameInfoTypes["PROMOTION_SMALL_CITY_PENALTY"]

local iCombatClassMounted = GameInfoTypes["UNITCOMBAT_MOUNTED"]
--=======================================================================================================================
-- LOCAL UTILS
--=======================================================================================================================
-- UNITS
-------------------------------------------------------------------------------------------------------------------------
function Unit_GetUnitLine(sCombatClass, bMounted)
	local sUnitLine = nil
	-- find out which unit line does a combat class belong to
	---- if blank, then it is probably a civilian unit, which usually do not have an upgrade line
	---- though in VP, all the non-great people civilian types have a unit combat assigned already anyway
	if sCombatClass == nil or sCombatClass == "" then
		return sUnitLine
	---- check for the few most common scenarios first
	elseif sCombatClass == "UNITCOMBAT_ARCHER" then
		if bMounted == true then
			sUnitLine = "Mounted Ranged"
		else
			sUnitLine = "Ranged"
		end
	elseif sCombatClass == "UNITCOMBAT_MELEE" or sCombatClass == "UNITCOMBAT_GUN" then
		sUnitLine = "Infantry"
	elseif sCombatClass == "UNITCOMBAT_MOUNTED" or sCombatClass == "UNITCOMBAT_ARMOR" then
		sUnitLine = "Cavalry"
	---- now we check the rest based on database order
	elseif sCombatClass == "UNITCOMBAT_RECON" then
		sUnitLine = "Recon"
	elseif sCombatClass == "UNITCOMBAT_SIEGE" then
		sUnitLine = "Siege"
	elseif sCombatClass == "UNITCOMBAT_NAVALRANGED" then
		sUnitLine = "Naval Ranged"
	elseif sCombatClass == "UNITCOMBAT_NAVALMELEE" then
		sUnitLine = "Naval Melee"
	elseif sCombatClass == "UNITCOMBAT_SUBMARINE" then
		sUnitLine = "Submarine"
	elseif sCombatClass == "UNITCOMBAT_CARRIER" then
		sUnitLine = "Carrier"
	elseif sCombatClass == "UNITCOMBAT_SETTLER" then
		sUnitLine = "Settler"
	elseif sCombatClass == "UNITCOMBAT_DIPLOMACY" then
		sUnitLine = "Diplomat"
	---- air units last, they are the rarest
	elseif sCombatClass == "UNITCOMBAT_FIGHTER" then
		sUnitLine = "Fighter"
	elseif sCombatClass == "UNITCOMBAT_BOMBER" then
		sUnitLine = "Bomber"
	elseif sCombatClass == "UNITCOMBAT_HELICOPTER" then -- unused in VP
		sUnitLine = "Helicopter"
	---- if its a combat class we did not expect, then just use the combat class type
	---- most likely will be one of the civilian types, which should not have an upgrade line
	else
		sUnitLine = sCombatClass
	end
	
	return sUnitLine
end

function Unit_DoUniqueUnitLinePromotions(iPlayer, iUnit, tPromotionsToAdd, tPromotionsToRemove)
	local pPlayer = Players[iPlayer]
	local pTeam = Teams[pPlayer:GetTeam()]
	local iCivilization = pPlayer:GetCivilizationType()
	if iCivilization == iCivilizationBarbarian or iCivilization == iCivilizationMinor then return end

	local pUnit = pPlayer:GetUnitByID(iUnit)

	-- get info about the unit
	local iCombatClass = pUnit:GetUnitCombatType()
	local sCombatClass = UnitCombat_GetTypeStringFromId(iCombatClass)
	local bMounted = pUnit:IsMounted()
	
	-- determine unit line
	local sUnitLine = Unit_GetUnitLine(sCombatClass, bMounted)

	if sUnitLine ~= nil then
		-- add unique promotions
		if tPromotionsToAdd[sUnitLine] ~= nil then
			for i, tPromotion in ipairs(tPromotionsToAdd[sUnitLine]) do
				if tPromotion[2] == nil or tPromotion[2] == "" or tPromotion[2] == -1 or pTeam:IsHasTech(tPromotion[2]) then
					pUnit:SetHasPromotion(tPromotion[1], true)
				end
			end
		end
		
		-- remove default promotions
		if tPromotionsToRemove[sUnitLine] ~= nil then
			for i, tPromotion in ipairs(tPromotionsToRemove[sUnitLine]) do
				if tPromotion[2] == nil or tPromotion[2] == "" or tPromotion[2] == -1 or pTeam:IsHasTech(tPromotion[2]) then
					pUnit:SetHasPromotion(tPromotion[1], false)
				end
			end
		end
		
		-- special cases are below
		---- Byzantium mounted units, but not armour units, has a -25% malus against cities rather than the standard -33%, and is lost on upgrade
		if iCivilization == iCivilizationByzantium and iCombatClass == iCombatClassMounted and pTeam:IsHasTech(iTechChivalry) then
			pUnit:SetHasPromotion(iPromotionSmallCityPenalty, true)
		end
	end
end
--------------------------------------------------------------------------------------------------------------------------
-- UNITCOMBATS
--------------------------------------------------------------------------------------------------------------------------
function UnitCombat_GetTypeStringFromId(iUnitCombat)
	return g_tUnitCombats[iUnitCombat]
end
--------------------------------------------------------------------------------------------------------------------------
-- UNITCLASSES
--------------------------------------------------------------------------------------------------------------------------
function UnitClass_GetTypeStringFromId(iUnitClass)
	return g_tUnitClasses[iUnitClass]
end
--=======================================================================================================================
--=======================================================================================================================