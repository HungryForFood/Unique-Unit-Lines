--==========================================================================================================================
-- CUSTOM MOD OPTIONS
--==========================================================================================================================
-- CustomModOptions
------------------------------
UPDATE CustomModOptions
SET Value = 1
WHERE Name IN('EVENTS_UNIT_CREATED', 'EVENTS_UNIT_CONVERTS');
--==========================================================================================================================
-- COMMUNITY
--==========================================================================================================================
-- COMMUNITY -- why is this table in all caps...
------------------------------
/*
Require the unique unit tech to be unlocked before granting the unique unit promotions
1 = Enabled (Default)
0 = Disabled 
*/
INSERT INTO COMMUNITY
		(Type, Value)
VALUES	('UNIQUE_UNIT_LINES_REQUIRE_TECH', 1);
--==========================================================================================================================
-- UNITS
--==========================================================================================================================
-- Units
------------------------------
UPDATE Units
SET Moves = Moves - 1
WHERE Type = 'UNIT_GERMAN_PANZER';

UPDATE Units
SET Moves = Moves + 1
WHERE Type = 'UNIT_BYZANTINE_CATAPHRACT';
------------------------------
-- Unit_FreePromotions
------------------------------
INSERT INTO Unit_FreePromotions
		(UnitType, PromotionType)
VALUES	('UNIT_GERMAN_PANZER', 'PROMOTION_EXTRA_MOVES_I'),
		('UNIT_BYZANTINE_CATAPHRACT', 'PROMOTION_BYZANTINE_IMMOBILITY');
------------------------------
-- UnitPromotions
------------------------------
INSERT INTO UnitPromotions
		(Type, IconAtlas, PortraitIndex)
SELECT	'PROMOTION_BYZANTINE_IMMOBILITY', IconAtlas, PortraitIndex
FROM UnitPromotions WHERE Type = 'PROMOTION_BOARDED_I';

UPDATE UnitPromotions SET
	OrderPriority = 7,
	Sound = 'AS2D_IF_LEVELUP',
	MovesChange = -1,
	Description = 'TXT_KEY_PROMOTION_BYZANTINE_IMMOBILITY',
	Help = 'TXT_KEY_PROMOTION_BYZANTINE_IMMOBILITY_HELP',
	LostWithUpgrade = 0,
	CannotBeChosen = 1,
	PediaType = 'PEDIA_MOUNTED',
	PediaEntry = 'TXT_KEY_PROMOTION_BYZANTINE_IMMOBILITY'
WHERE Type = 'PROMOTION_BYZANTINE_IMMOBILITY';

UPDATE UnitPromotions SET
	CannotBeChosen = 1
WHERE Type = 'PROMOTION_NO_DEFENSIVE_BONUSES';