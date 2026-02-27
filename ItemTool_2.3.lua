--[[
    ItemTool - A script for SimCity BuildIt
    Copyright (C) 2026 911bob

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <https://www.gnu.org/licenses/>.
]]
--this spagghetti was cooked up by '911bob' on discord
--discord link dsc.gg/911bob (open in browser, it will redirect you)
--===========================================
--           USER CONFIG
--===========================================
local SEARCH_EVERYTHING = false -- Pre-search all items on startup
local DEBUG = false -- Set to true to run offset validation on startup
local DISABLE_SET_VISIBLE = false -- Set to true to prevent gg.setVisible() calls

--===========================================
--           CONFIG
--===========================================
RootPointerBits = "h FD 7B BE A9 F4 4F 01 A9 FD 03 00 91 14 00 41 F9 F3 03 00 AA 68 85 00 D0 08 81 11 91 08 00 00 F9" --root pointer is -0x8 from time pointer
local CONFIG_FILE = gg.getFile() .. ".config.lua" -- Save config in same dir as script
local CONFIG_DATA = { regions = {} }

local CONSTANTS = {

	EXPECTED_COUNTS = {
		WAR_ITEMS = 12,
		EXPANSION_ITEMS = 15,
		OMEGA_ITEMS = 10,
		CERTS = 3,
		TOKENS = 6,
		WAR_CARDS = 19,
		GENERIC_ITEMS = 135,
	},

	OFFSETS = {
		-- Base Offsets from Root Pointer
		PRODUCTION_BASE = -0x8,
		WAR_ITEMS_PTR = 0x858,
		EXPANSION_ITEMS_PTR = 0x5f8,
		OMEGA_ITEMS_PTR = 0x728,
		CERTS_PTR = 0x690,
		TOKENS_PTR = 0x25e8,
		WAR_CARDS_PTR = 0x2d08,

		-- Production/Time Structure
		TIME_VALUE = 0x9c,
		NAME_PTR_OFFSET = 0x200,
		LEVEL_REQ = 0x218,
		MULT_VAL_OFFSET = 0x18,
		XP_VALUE = 0x220,

		-- Factory/Item Structure
		FACTORY_ITEM_VAL = 0x1c,
		ITEM_CHECK_WOOD = 0x8,
		ITEM_CHECK_COMP = 0x50,
		ITEM_LIST_STRIDE = 0x8,

		-- Generic Item Data Pointers (Used in War, Expansion, Omega, Cards)
		ITEM_DATA_PTR = 0x10,

		-- Expansion Specific
		EXPANSION_ID_8 = 0x8,
		EXPANSION_ID_10 = 0x10,

		-- Certs/Tokens Specific
		CERT_TOKEN_NAME = 0xC,

		-- Generic Item Root (Debug)
		GENERIC_ITEM_ROOT = -0x138,
	},
}

local KNOWN_GENERIC_ITEMS_DB = {
	["0x00006C6174654D0A, 0x0000000000000000, 0x0000000000000000"] = { index = 1, name = "Metal" },
	["0x000000646F6F5708, 0x0000000000000000, 0x0000000000000000"] = { index = 2, name = "Wood" },
	["0x63697473616C500E, 0x0000000000000000, 0x0000000000000000"] = { index = 3, name = "Plastic" },
	["0x000073646565530A, 0x0000000000000000, 0x0000000000000000"] = { index = 4, name = "Seeds" },
	["0x6C6172656E694D10, 0x0000000000000073, 0x0000000000000000"] = { index = 5, name = "Minerals" },
	["0x6163696D65684312, 0x000000000000736C, 0x0000000000000000"] = { index = 6, name = "Chemicals" },
	["0x656C697478655410, 0x0000000000000073, 0x0000000000000000"] = { index = 7, name = "Textiles" },
	["0x7053726167755316, 0x0000000073656369, 0x0000000000000000"] = { index = 8, name = "SugarSpices" },
	["0x00007373616C470A, 0x0000000000000000, 0x0000000000000000"] = { index = 9, name = "Glass" },
	["0x466C616D696E4114, 0x0000000000646565, 0x0000000000000000"] = { index = 10, name = "AnimalFeed" },
	["0x69727463656C4528, 0x6F706D6F436C6163, 0x00000073746E656E"] = { index = 11, name = "ElectricalComponents" },
	["0x6C6F4873616D581E, 0x7261745379616469, 0x0000000000000000"] = { index = 12, name = "XmasHolidayStar" },
	["0x0000736C69614E0A, 0x0000000000000000, 0x0000000000000000"] = { index = 13, name = "Nails" },
	["0x00736B6E616C500C, 0x0000000000000000, 0x0000000000000000"] = { index = 14, name = "Planks" },
	["0x00736B636972420C, 0x0000000000000000, 0x0000000000000000"] = { index = 15, name = "Bricks" },
	["0x00746E656D65430C, 0x0000000000000000, 0x0000000000000000"] = { index = 16, name = "Cement" },
	["0x00000065756C4708, 0x0000000000000000, 0x0000000000000000"] = { index = 17, name = "Glue" },
	["0x0000746E6961500A, 0x0000000000000000, 0x0000000000000000"] = { index = 18, name = "Paint" },
	["0x0072656D6D61480C, 0x0000000000000000, 0x0000000000000000"] = { index = 19, name = "Hammer" },
	["0x6972757361654D1A, 0x000065706154676E, 0x0000000000000000"] = { index = 20, name = "MeasuringTape" },
	["0x006C65766F68530C, 0x0000000000000000, 0x0000000000000000"] = { index = 21, name = "Shovel" },
	["0x676E696B6F6F431E, 0x736C69736E657455, 0x0000000000000000"] = { index = 22, name = "CookingUtensils" },
	["0x00006C6C6972440A, 0x0000000000000000, 0x0000000000000000"] = { index = 23, name = "Drill" },
	["0x0072656464614C0C, 0x0000000000000000, 0x0000000000000000"] = { index = 24, name = "Ladder" },
	["0x66694773616D5816, 0x00000000786F4274, 0x0000000000000000"] = { index = 25, name = "XmasGiftBox" },
	["0x6261746567655614, 0x000000000073656C, 0x0000000000000000"] = { index = 26, name = "Vegetables" },
	["0x614272756F6C4612, 0x0000000000007367, 0x0000000000000000"] = { index = 27, name = "FlourBags" },
	["0x6542746975724618, 0x0000007365697272, 0x0000000000000000"] = { index = 28, name = "FruitBerries" },
	["0x006573656568430C, 0x0000000000000000, 0x0000000000000000"] = { index = 29, name = "Cheese" },
	["0x00006D616572430A, 0x0000000000000000, 0x0000000000000000"] = { index = 30, name = "Cream" },
	["0x0000006665654208, 0x0000000000000000, 0x0000000000000000"] = { index = 31, name = "Beef" },
	["0x0000006E726F4308, 0x0000000000000000, 0x0000000000000000"] = { index = 32, name = "Corn" },
	["0x636F5373616D5810, 0x000000000000006B, 0x0000000000000000"] = { index = 33, name = "XmasSock" },
	["0x007372696168430C, 0x0000000000000000, 0x0000000000000000"] = { index = 34, name = "Chairs" },
	["0x0073656C6261540C, 0x0000000000000000, 0x0000000000000000"] = { index = 35, name = "Tables" },
	["0x786554656D6F4818, 0x00000073656C6974, 0x0000000000000000"] = { index = 36, name = "HomeTextiles" },
	["0x00006863756F430A, 0x0000000000000000, 0x0000000000000000"] = { index = 37, name = "Couch" },
	["0x72616F6270754310, 0x0000000000000064, 0x0000000000000000"] = { index = 38, name = "Cupboard" },
	["0x000073736172470A, 0x0000000000000000, 0x0000000000000000"] = { index = 39, name = "Grass" },
	["0x7061536565725418, 0x00000073676E696C, 0x0000000000000000"] = { index = 40, name = "TreeSaplings" },
	["0x466E65647261471E, 0x65727574696E7275, 0x0000000000000000"] = { index = 41, name = "GardenFurniture" },
	["0x746950657269460E, 0x0000000000000000, 0x0000000000000000"] = { index = 42, name = "FirePit" },
	["0x476E656472614718, 0x00000073656D6F6E, 0x0000000000000000"] = { index = 43, name = "GardenGnomes" },
	["0x776F4D6E77614C12, 0x0000000000007265, 0x0000000000000000"] = { index = 44, name = "LawnMower" },
	["0x65725773616D5814, 0x0000000000687461, 0x0000000000000000"] = { index = 45, name = "XmasWreath" },
	["0x007374756E6F440C, 0x0000000000000000, 0x0000000000000000"] = { index = 46, name = "Donuts" },
	["0x6D536E656572471A, 0x0000656968746F6F, 0x0000000000000000"] = { index = 47, name = "GreenSmoothie" },
	["0x6F52646165724212, 0x0000000000006C6C, 0x0000000000000000"] = { index = 48, name = "BreadRoll" },
	["0x4379727265684320, 0x6B61636573656568, 0x0000000000000065"] = { index = 49, name = "CherryCheesecake" },
	["0x596E657A6F724618, 0x000000747275676F, 0x0000000000000000"] = { index = 50, name = "FrozenYogurt" },
	["0x00656566666F430C, 0x0000000000000000, 0x0000000000000000"] = { index = 51, name = "Coffee" },
	["0x6C6C617265764F10, 0x0000000000000073, 0x0000000000000000"] = { index = 52, name = "Overalls" },
	["0x000073656F68530A, 0x0000000000000000, 0x0000000000000000"] = { index = 53, name = "Shoes" },
	["0x73616C676E755314, 0x0000000000736573, 0x0000000000000000"] = { index = 54, name = "Sunglasses" },
	["0x73656E697375421A, 0x0000737469755373, 0x0000000000000000"] = { index = 55, name = "BusinessSuits" },
	["0x6361706B63614210, 0x000000000000006B, 0x0000000000000000"] = { index = 56, name = "Backpack" },
	["0x656C5373616D5810, 0x0000000000000064, 0x0000000000000000"] = { index = 57, name = "XmasSled" },
	["0x4665736565684316, 0x0000000073656972, 0x0000000000000000"] = { index = 58, name = "CheeseFries" },
	["0x0000617A7A69500A, 0x0000000000000000, 0x0000000000000000"] = { index = 59, name = "Pizza" },
	["0x737265677275420E, 0x0000000000000000, 0x0000000000000000"] = { index = 60, name = "Burgers" },
	["0x6165724365634920, 0x636977646E61536D, 0x0000000000000068"] = { index = 61, name = "IceCreamSandwich" },
	["0x64616E6F6D654C1E, 0x73656C74746F4265, 0x0000000000000000"] = { index = 62, name = "LemonadeBottles" },
	["0x6E726F63706F500E, 0x0000000000000000, 0x0000000000000000"] = { index = 63, name = "Popcorn" },
	["0x0000000000565404, 0x0000000000000000, 0x0000000000000000"] = { index = 64, name = "TV" },
	["0x6567697266655218, 0x000000726F746172, 0x0000000000000000"] = { index = 65, name = "Refrigerator" },
	["0x6C69726751424210, 0x000000000000006C, 0x0000000000000000"] = { index = 66, name = "BBQgrill" },
	["0x6E69746867694C1C, 0x006D657473795367, 0x0000000000000000"] = { index = 67, name = "LightingSystem" },
	["0x61776F7263694D1A, 0x00006E65764F6576, 0x0000000000000000"] = { index = 68, name = "MicrowaveOven" },
	["0x6D496E616973411A, 0x0000317374726F70, 0x0000000000000000"] = { index = 69, name = "AsianImports1" },
	["0x6D496E616973411A, 0x0000327374726F70, 0x0000000000000000"] = { index = 70, name = "AsianImports2" },
	["0x6D496E616973411A, 0x0000337374726F70, 0x0000000000000000"] = { index = 71, name = "AsianImports3" },
	["0x6D4973697261501A, 0x0000317374726F70, 0x0000000000000000"] = { index = 72, name = "ParisImports1" },
	["0x6D4973697261501A, 0x0000327374726F70, 0x0000000000000000"] = { index = 73, name = "ParisImports2" },
	["0x6D4973697261501A, 0x0000337374726F70, 0x0000000000000000"] = { index = 74, name = "ParisImports3" },
	["0x496E6F646E6F4C1C, 0x00317374726F706D, 0x0000000000000000"] = { index = 75, name = "LondonImports1" },
	["0x496E6F646E6F4C1C, 0x00327374726F706D, 0x0000000000000000"] = { index = 76, name = "LondonImports2" },
	["0x496E6F646E6F4C1C, 0x00337374726F706D, 0x0000000000000000"] = { index = 77, name = "LondonImports3" },
	["0x656C63796365521C, 0x0063697262614664, 0x0000000000000000"] = { index = 78, name = "RecycledFabric" },
	["0x6C62617375655216, 0x0000000067614265, 0x0000000000000000"] = { index = 79, name = "ReusableBag" },
	["0x656F68536F634510, 0x0000000000000073, 0x0000000000000000"] = { index = 80, name = "EcoShoes" },
	["0x74614D61676F590E, 0x0000000000000000, 0x0000000000000000"] = { index = 81, name = "YogaMat" },
	["0x694F656475724310, 0x000000000000006C, 0x0000000000000000"] = { index = 82, name = "CrudeOil" },
	["0x694F726F746F4D10, 0x000000000000006C, 0x0000000000000000"] = { index = 83, name = "MotorOil" },
	["0x657269547261430E, 0x0000000000000000, 0x0000000000000000"] = { index = 84, name = "CarTire" },
	["0x00656E69676E450C, 0x0000000000000000, 0x0000000000000000"] = { index = 85, name = "Engine" },
	["0x74756E6F636F430E, 0x0000000000000000, 0x0000000000000000"] = { index = 86, name = "Coconut" },
	["0x74756E6F636F4314, 0x00000000006C694F, 0x0000000000000000"] = { index = 87, name = "CoconutOil" },
	["0x6572436563614612, 0x0000000000006D61, 0x0000000000000000"] = { index = 88, name = "FaceCream" },
	["0x616369706F72541A, 0x00006B6E6972446C, 0x0000000000000000"] = { index = 89, name = "TropicalDrink" },
	["0x0000006873694608, 0x0000000000000000, 0x0000000000000000"] = { index = 90, name = "Fish" },
	["0x4664656E6E614314, 0x0000000000687369, 0x0000000000000000"] = { index = 91, name = "CannedFish" },
	["0x756F536873694610, 0x0000000000000070, 0x0000000000000000"] = { index = 92, name = "FishSoup" },
	["0x536E6F6D6C61531C, 0x0068636977646E61, 0x0000000000000000"] = { index = 93, name = "SalmonSandwich" },
	["0x0000006B6C695308, 0x0000000000000000, 0x0000000000000000"] = { index = 94, name = "Silk" },
	["0x00676E697274530C, 0x0000000000000000, 0x0000000000000000"] = { index = 95, name = "String" },
	["0x000000006E614606, 0x0000000000000000, 0x0000000000000000"] = { index = 96, name = "Fan" },
	["0x00000065626F5208, 0x0000000000000000, 0x0000000000000000"] = { index = 97, name = "Robe" },
	["0x00000073796F5408, 0x0000000000000000, 0x0000000000000000"] = { index = 98, name = "Toys" },
	["0x6D7473697268431C, 0x00746E616C507361, 0x0000000000000000"] = { index = 99, name = "ChristmasPlant" },
	["0x614379646E614312, 0x000000000000656E, 0x0000000000000000"] = { index = 100, name = "CandyCane" },
	["0x427265676E694716, 0x0000000064616572, 0x0000000000000000"] = { index = 101, name = "GingerBread" },
	["0x66694773616D5812, 0x0000000000007374, 0x0000000000000000"] = { index = 102, name = "XmasGifts" },
	["0x5273696E6E655418, 0x00000074656B6361, 0x0000000000000000"] = { index = 103, name = "TennisRacket" },
	["0x447374726F705316, 0x000000006B6E6972, 0x0000000000000000"] = { index = 104, name = "SportsDrink" },
	["0x42726563636F5316, 0x0000000073746F6F, 0x0000000000000000"] = { index = 105, name = "SoccerBoots" },
	["0x6E6965746F725014, 0x0000000000726142, 0x0000000000000000"] = { index = 106, name = "ProteinBar" },
	["0x6E6F50676E69501A, 0x0000656C62615467, 0x0000000000000000"] = { index = 107, name = "PingPongTable" },
	["0x6B726F667961480E, 0x0000000000000000, 0x0000000000000000"] = { index = 108, name = "Hayfork" },
	["0x7247664F786F4216, 0x0000000073657061, 0x0000000000000000"] = { index = 109, name = "BoxOfGrapes" },
	["0x6968536C6F6F5712, 0x0000000000007472, 0x0000000000000000"] = { index = 110, name = "WoolShirt" },
	["0x4263696E63695018, 0x00000074656B7361, 0x0000000000000000"] = { index = 111, name = "PicnicBasket" },
	["0x614A656C70704110, 0x000000000000006D, 0x0000000000000000"] = { index = 112, name = "AppleJam" },
	["0x746867756F725716, 0x000000006E6F7249, 0x0000000000000000"] = { index = 113, name = "WroughtIron" },
	["0x5764657672614314, 0x0000000000646F6F, 0x0000000000000000"] = { index = 114, name = "CarvedWood" },
	["0x656C65736968431A, 0x0000656E6F745364, 0x0000000000000000"] = { index = 115, name = "ChiseledStone" },
	["0x7274736570615410, 0x0000000000000079, 0x0000000000000000"] = { index = 116, name = "Tapestry" },
	["0x64656E6961745318, 0x0000007373616C47, 0x0000000000000000"] = { index = 117, name = "StainedGlass" },
	["0x616C6F636F684318, 0x0000007261426574, 0x0000000000000000"] = { index = 118, name = "ChocolateBar" },
	["0x4272657473614518, 0x00000074656B7361, 0x0000000000000000"] = { index = 119, name = "EasterBasket" },
	["0x6542796C6C654A14, 0x0000000000736E61, 0x0000000000000000"] = { index = 120, name = "JellyBeans" },
	["0x616C6F636F684318, 0x0000006767456574, 0x0000000000000000"] = { index = 121, name = "ChocolateEgg" },
	["0x6143746975724612, 0x000000000000656B, 0x0000000000000000"] = { index = 122, name = "FruitCake" },
	["0x000073746C6F420A, 0x0000000000000000, 0x0000000000000000"] = { index = 123, name = "Bolts" },
	["0x746375646E6F4318, 0x000000746148726F, 0x0000000000000000"] = { index = 124, name = "ConductorHat" },
	["0x656761746E69561C, 0x006E7265746E614C, 0x0000000000000000"] = { index = 125, name = "VintageLantern" },
	["0x6578616B6369500E, 0x0000000000000000, 0x0000000000000000"] = { index = 126, name = "Pickaxe" },
	["0x4272657474654C18, 0x000000736B636F6C, 0x0000000000000000"] = { index = 127, name = "LetterBlocks" },
	["0x0000006574694B08, 0x0000000000000000, 0x0000000000000000"] = { index = 128, name = "Kite" },
	["0x6542796464655412, 0x0000000000007261, 0x0000000000000000"] = { index = 129, name = "TeddyBear" },
	["0x656C6F736E6F430E, 0x0000000000000000, 0x0000000000000000"] = { index = 130, name = "Console" },
	["0x73696D6172695410, 0x0000000000000075, 0x0000000000000000"] = { index = 131, name = "Tiramisu" },
	["0x736F72727568430E, 0x0000000000000000, 0x0000000000000000"] = { index = 132, name = "Churros" },
	["0x657469666F725016, 0x00000000656C6F72, 0x0000000000000000"] = { index = 133, name = "Profiterole" },
	["0x00006968636F4D0A, 0x0000000000000000, 0x0000000000000000"] = { index = 134, name = "Mochi" },
	["0x61766F6C7661500E, 0x0000000000000000, 0x0000000000000000"] = { index = 135, name = "Pavlova" },
}

--===========================================
--           CONFIG MANAGER
--===========================================
local ConfigManager = {}

function ConfigManager.calculateChecksum(dataTable)
	-- Use the deterministic serialization to ensure consistent string for hashing
	local str = ConfigManager.serialize(dataTable)
	-- Simple djb2-like hash for Lua
	local hash = 5381
	for i = 1, #str do
		hash = ((hash * 33) + string.byte(str, i))
	end
	return hash
end

function ConfigManager.save()
	-- Calculate checksum on the data BEFORE adding the checksum field itself
	-- (Actually, we store checksum inside the file, but not as part of the data table usually?
	-- The previous logic stored it IN the table. Let's keep that but remove it during calc logic in load)

	-- Wait, save() was calling calculateChecksum on CONFIG_DATA.
	-- If we modify CONFIG_DATA to include checksum, the next calc will be diff.
	-- Best practice: Compute checksum on the *content* we are about to save.

	local dataCopy = {}
	for k, v in pairs(CONFIG_DATA) do
		dataCopy[k] = v
	end
	dataCopy.checksum = nil -- Ensure checksum itself isn't part of the hash

	CONFIG_DATA.checksum = ConfigManager.calculateChecksum(dataCopy)

	local file = io.open(CONFIG_FILE, "w")
	if file then
		file:write("return " .. ConfigManager.serialize(CONFIG_DATA))
		file:close()
		return true
	end
	return false
end

function ConfigManager.serialize(val)
	if type(val) == "table" then
		local s = "{"
		-- Get all keys
		local keys = {}
		for k in pairs(val) do
			table.insert(keys, k)
		end
		-- Sort keys to ensure deterministic order
		table.sort(keys, function(a, b)
			return tostring(a) < tostring(b)
		end)

		for _, k in ipairs(keys) do
			local v = val[k]
			if type(k) == "number" then
				s = s .. "[" .. k .. "]=" .. ConfigManager.serialize(v) .. ","
			else
				s = s .. '["' .. k .. '"]=' .. ConfigManager.serialize(v) .. ","
			end
		end
		return s .. "}"
	elseif type(val) == "string" then
		return string.format("%q", val)
	else
		return tostring(val)
	end
end

function ConfigManager.load()
	local file = io.open(CONFIG_FILE, "r")
	if not file then
		return false
	end

	local content = file:read("*a")
	file:close()

	local func = load(content)
	if not func then
		return false
	end

	local loadedData = func()
	if not loadedData or type(loadedData) ~= "table" then
		return false
	end

	-- Verify checksum
	local storedChecksum = loadedData.checksum
	loadedData.checksum = nil -- Temporarily remove for calculation
	local calculatedChecksum = ConfigManager.calculateChecksum(loadedData)
	loadedData.checksum = storedChecksum -- Restore

	if storedChecksum == calculatedChecksum then
		CONFIG_DATA = loadedData
		if not CONFIG_DATA.regions then
			CONFIG_DATA.regions = {}
		end
		return true
	else
		gg.alert("Config file corrupted or modified! Creating new one.")
		return false
	end
end

local MemoryOptimizer = {}
MemoryOptimizer.REGIONS = {
	gg.REGION_JAVA_HEAP,
	gg.REGION_C_HEAP,
	gg.REGION_C_ALLOC,
	gg.REGION_C_DATA,
	gg.REGION_C_BSS,
	gg.REGION_PPSSPP,
	gg.REGION_ANONYMOUS,
	gg.REGION_JAVA,
	gg.REGION_STACK,
	gg.REGION_ASHMEM,
	gg.REGION_VIDEO,
	gg.REGION_OTHER,
	gg.REGION_BAD,
	gg.REGION_CODE_APP,
	gg.REGION_CODE_SYS,
}
MemoryOptimizer.REGION_NAMES = {
	[gg.REGION_JAVA_HEAP] = "JAVA_HEAP",
	[gg.REGION_C_HEAP] = "C_HEAP",
	[gg.REGION_C_ALLOC] = "C_ALLOC",
	[gg.REGION_C_DATA] = "C_DATA",
	[gg.REGION_C_BSS] = "C_BSS",
	[gg.REGION_PPSSPP] = "PPSSPP",
	[gg.REGION_ANONYMOUS] = "ANONYMOUS",
	[gg.REGION_JAVA] = "JAVA",
	[gg.REGION_STACK] = "STACK",
	[gg.REGION_ASHMEM] = "ASHMEM",
	[gg.REGION_VIDEO] = "VIDEO",
	[gg.REGION_OTHER] = "OTHER",
	[gg.REGION_BAD] = "BAD",
	[gg.REGION_CODE_APP] = "CODE_APP",
	[gg.REGION_CODE_SYS] = "CODE_SYS",
}

function MemoryOptimizer.findWorkingRegion(searchKey, searchFunc)
	-- fast path: check config
	if CONFIG_DATA.regions[searchKey] then
		gg.setRanges(CONFIG_DATA.regions[searchKey])
		if searchFunc() then
			return true
		end
		-- if saved region fails, fall back to bruteforce
		gg.toast(getText("alert_production_base_address_not_found") .. " Retrying optimization...")
	end

	-- bruteforce
	for _, region in ipairs(MemoryOptimizer.REGIONS) do
		gg.setRanges(region)
		if searchFunc() then
			CONFIG_DATA.regions[searchKey] = region
			ConfigManager.save()
			local rName = MemoryOptimizer.REGION_NAMES[region] or "UNKNOWN"
			gg.toast("Optimization: Found " .. searchKey .. " in " .. rName)
			return true
		end
	end

	return false
end

local settingType = 1 --to initially show the correct menu/setting
local itemListStart = nil --start of the basic item list
local itemList = {} --basic 130 items
local warItems = {} --12 war items
local expansionItems = {} --12 expansion items and 3 VU tower items
local factoryItems = {} --11 items in the factory
local futureOMEGAItems = {} --10 OMEGA Items
local certsAndTokens = {} --expansion certificate and speedup tokens and golden ticket
local warCards = {} --the warcard thing

local wasWarFound = nil --variables to prevent searching for item lists multiple times
local expansionWasFound = nil
local OMEGAWasFound = nil
local wereItemsFound = nil
local wereCertsFound = nil
local wasRemoved = nil --checks if time was already set to 0
local wereWarcardsFound = nil

local productionPrepared = 0 --Time and mult related
local wasLvlExcluded = 0 --Time and mult related
local productionBaseAddressTable = {} --Time and mult related
local timeValueTable = {} --Time and mult related
local multTable = {} --Time and mult related
local levelRequirementTable = {} --Time and mult related

--search for root pointer, used to find other pointers with offsets
--===========================================
--            LANGUAGE SUPPORT
--===========================================
local currentLanguage = "en" -- Default language

local translations = {
	en = {
		displayName = "English",
		-- Menu Choices
		menu_vu_expansion = "VU and Expansion Items (all beach and winter not included)",
		menu_war_items = "War Items (Medkit not included)",
		menu_omega_items = "Omega Items",
		menu_regional_items = "Regional Items",
		menu_railroad_items = "Railroad Items",
		menu_airport_items = "Airport Items",
		menu_christmas_items = "Christmas Items",
		menu_items_that_didnt_fit = "Items that didnt fit",
		menu_speedup_tokens = "Speedup Tokens and Certificates",
		menu_war_items_presets = "War Items presets",
		menu_revert_to_default = "Revert to default",
		menu_warcards = "Warcards",
		menu_system_settings = "System Settings (mult, time, lvl)",
		menu_exit = "Exit",
		menu_choose_option = "Choose an option",
		menu_choose_option_cancel_abort = "Choose an option, cancel to abort",
		menu_choose_what_you_need_proceed = "Choose what you need, then hit Proceed",

		-- Time Menu Choices
		time_menu_remove_production_time = "Remove Production Time",
		time_menu_edit_production_amount = "Edit Production amount",
		time_menu_exclude_lvl_requirement = "Exclude production lvl requirement",
		time_menu_proceed = "Proceed",
		time_menu_edit_mult_status = "Edit Mult [CURRENTLY AT: %s]",
		time_menu_exclude_lvl_req_reverted = "Exclude lvl requirement [REVERTED]",
		time_menu_exclude_lvl_req_done = "Exclude lvl requirement [DONE]",
		time_menu_prod_time_status = "Remove Production Time [%ss]",

		-- XP Modification
		prompt_enter_XP_ammount = "Enter how much XP do you want to get from every item. Going over level 99 gets your account banned!",
		menu_modify_xp = "Modify XP",
		xp_menu_edit_xp_amount = "Currently getting %d XP from items, click to edit",
		xp_menu_back_to_main = "Back to main menu (revert changes)",
		alert_xp_set = "XP set to: %d",
		alert_high_xp_warning = "This amount will likely get you banned!",

		-- Regional Items Menu
		region_cactus_canyon = "Cactus Canyon",
		region_green_valley = "Green Valley",
		region_limestone_cliffs = "Limestone Cliffs",
		region_sunny_isles = "Sunny Isles",
		region_frosty_fjords = "Frosty Fjords",

		-- Warcards Menu
		warcards_comic_hand = "Comic Hand",
		warcards_shrink_ray = "Shrink Ray",
		warcards_giant_rock_monster = "Giant Rock Monster",
		warcards_not_in_kansas = "Not in Kansas",
		warcards_magnetism = "Magnetism",
		warcards_tentacle_vortex = "Tentacle Vortex",
		warcards_flying_vu_robot = "Flying Vu Robot",
		warcards_disco_twister = "Disco Twister",
		warcards_plant_monster = "Plant Monster",
		warcards_blizzaster = "Blizzaster",
		warcards_fishaster = "Fishaster",
		warcards_ancient_curse = "Ancient Curse",
		warcards_hands_of_doom = "Hands of Doom",
		warcards_16_tons = "16 Tons",
		warcards_spiders = "Spiders",
		warcards_dance_shoes = "Dance Shoes",
		warcards_building_portal = "Building Portal",
		warcards_b_movie_monster = "B Movie Monster",
		warcards_hissy_fit = "Hissy Fit",
		warcards_mellow_bellow = "Mellow Bellow",
		warcards_doomsday_quack = "Doomsday Quack",
		warcards_electric_deity = "Electric Deity",
		warcards_shield_buster = "Shield Buster",
		warcards_zest_from_above = "Zest from Above",

		-- Factory Item Names
		item_metal = "Metal",
		item_wood = "Wood",
		item_plastic = "Plastic",
		item_seed = "Seed",
		item_mineral = "Mineral",
		item_chemicals = "Chemicals",
		item_textiles = "Textiles",
		item_sugar = "Sugar",
		item_glass = "Glass",
		item_animal_feed = "Animal Feed",
		item_electrical_components = "Electrical Components",

		-- Toasts and Alerts
		toast_loading_root_pointer = "Loading root pointer",
		alert_root_pointer_not_found = "Root Pointer not found, make sure you attached to the correct process!",
		alert_production_base_address_not_found = "Production Base Address not found (possible offset change?).",
		alert_mult_table_not_prepared = "Mult table not prepared correctly!",
		alert_time_value_table_not_prepared = "Time Value Table not prepared correctly!",
		alert_level_req_table_not_prepared = "Level requirement table not prepared correct!",
		toast_time_prepared = "Time prepared!",
		prompt_enter_item_ammount = "Enter the amount of items to receive",
		alert_are_you_sure_high_values_ban = "Are you sure? High values can get you banned",
		alert_yes = "Yes",
		alert_no = "No",
		alert_cancelled_by_user = "Cancelled by user",
		toast_done = "Done!",
		toast_reverted = "Reverted!",
		toast_done_time_set_to = "Done, time set to: %s seconds.",
		alert_item_list_not_found = "Item list not found",
		alert_something_aint_right = "something aint right", -- Consider a more professional message
		toast_loading_war_items = "Loading War Items",
		toast_loading_general_items = "Loading General Items",
		toast_loading_expansion_items = "Loading Expansion Items",
		toast_loading_omega_items = "Loading OMEGA Items",
		toast_loading_certs_and_tokens = "Loading Certs and Tokens",
		toast_loading_warcards = "Loading Warcards",
		toast_loading_factory_items = "Loading Factory Items",
		alert_certs_tokens_simcash_info = "These cannot be collected unless you spend simcash to collect them, I set the time to 60s for you (1 simcash)",
		alert_warcards_simcash_info = "These cannot be collected unless you spend simcash to collect them, I set the time to 60s so you can collect for 1 simcash. I dont know the safe limits, feel free to test and let me know. Once you produce, open Steve (VU monster) and cards should appear.",
		status_enabled = "[ENABLED]",
		status_active = "[ACTIVE]",
		status_regional_cactus = "[Cactus Canyon]",
		status_regional_green_valley = "[Green Valley]",
		status_regional_limestone = "[Limestone Cliffs]",
		status_regional_sunny_isles = "[Sunny Isles]",
		status_regional_frosty_fjords = "[Frosty Fjords]",
		status_war_preset = "[%s]", -- For war preset status
		select_language_prompt = "Select Language",
		language_set_toast = "Language set to: %s",
		alert_optimization_warning = "Performing initial memory setup. This may take a few minutes but will only happen once to speed up future runs.",
	},
	es = {
		displayName = "Español",
		menu_vu_expansion = "Artículos VU y Expansión (playa e invierno no incluidos)",
		menu_war_items = "Artículos de Guerra (Botiquín no incluido)",
		menu_omega_items = "Artículos Omega",
		menu_regional_items = "Artículos Regionales",
		menu_railroad_items = "Artículos de Ferrocarril",
		menu_airport_items = "Artículos de Aeropuerto",
		menu_christmas_items = "Artículos de Navidad",
		menu_items_that_didnt_fit = "Artículos que no encajaron",
		menu_speedup_tokens = "Fichas de Aceleración y Certificados",
		menu_war_items_presets = "Preajustes de Artículos de Guerra",
		menu_revert_to_default = "Revertir a Predeterminado",
		menu_warcards = "Cartas de Guerra",
		menu_system_settings = "Ajustes del Sistema (mult, tiempo, nivel)",
		menu_exit = "Salir",
		menu_choose_option = "Elige una opción",
		menu_choose_option_cancel_abort = "Elige una opción, cancelar para abortar",
		menu_choose_what_you_need_proceed = "Elige lo que necesites, luego pulsa Continuar",

		time_menu_remove_production_time = "Eliminar Tiempo de Producción",
		time_menu_edit_production_amount = "Editar Cantidad de Producción",
		time_menu_exclude_lvl_requirement = "Excluir Requisito de Nivel de Producción",
		time_menu_proceed = "Continuar",
		time_menu_edit_mult_status = "Editar Multiplicador [ACTUALMENTE EN: %s]",
		time_menu_exclude_lvl_req_reverted = "Excluir req. de nivel [REVERTIDO]",
		time_menu_exclude_lvl_req_done = "Excluir req. de nivel [HECHO]",
		time_menu_prod_time_status = "Eliminar Tiempo de Producción [%ss]",

		region_cactus_canyon = "Cañón Cactus",
		region_green_valley = "Valle Verde",
		region_limestone_cliffs = "Acantilados Calizos",
		region_sunny_isles = "Islas Soleadas",
		region_frosty_fjords = "Fiordos Helados",

		warcards_comic_hand = "Mano de Cómic",
		warcards_shrink_ray = "Rayo Reducidor",
		warcards_giant_rock_monster = "Monstruo de Roca Gigante",
		warcards_not_in_kansas = "No en Kansas",
		warcards_magnetism = "Magnetismo",
		warcards_tentacle_vortex = "Vórtice de Tentáculos",
		warcards_flying_vu_robot = "Robot Vu Volador",
		warcards_disco_twister = "Torbellino Disco",
		warcards_plant_monster = "Monstruo Planta",
		warcards_blizzaster = "Blizzaster",
		warcards_fishaster = "Fishaster",
		warcards_ancient_curse = "Maldición Antigua",
		warcards_hands_of_doom = "Manos de Doom",
		warcards_16_tons = "16 Toneladas",
		warcards_spiders = "Arañas",
		warcards_dance_shoes = "Zapatos de Baile",
		warcards_building_portal = "Portal de Edificios",
		warcards_b_movie_monster = "Monstruo de Película B",
		warcards_hissy_fit = "Ataque de Nervios",
		warcards_mellow_bellow = "Susurro Suave",
		warcards_doomsday_quack = "Cuac del Juicio Final",
		warcards_electric_deity = "Deidad Eléctrica",
		warcards_shield_buster = "Rompeescudos",
		warcards_zest_from_above = "Entusiasmo desde Arriba",

		item_metal = "Metal",
		item_wood = "Madera",
		item_plastic = "Plástico",
		item_seed = "Semilla",
		item_mineral = "Mineral",
		item_chemicals = "Químicos",
		item_textiles = "Textiles",
		item_sugar = "Azúcar",
		item_glass = "Vidrio",
		item_animal_feed = "Alimento para Animales",
		item_electrical_components = "Componentes Eléctricos",

		toast_loading_root_pointer = "Cargando puntero raíz",
		alert_root_pointer_not_found = "¡Puntero raíz no encontrado, asegúrese de adjuntar al proceso correcto!",
		alert_production_base_address_not_found = "Dirección base de producción no encontrada (¿posible cambio de offset?).",
		alert_mult_table_not_prepared = "¡Tabla de multiplicadores no preparada correctamente!",
		alert_time_value_table_not_prepared = "¡Tabla de valores de tiempo no preparada correctamente!",
		alert_level_req_table_not_prepared = "¡Tabla de requisitos de nivel no preparada correctamente!",
		toast_time_prepared = "¡Tiempo preparado!",
		prompt_enter_item_ammount = "Introduce la cantidad de artículos a recibir",
		alert_are_you_sure_high_values_ban = "¿Estás seguro? Valores altos pueden hacer que te baneen",
		alert_yes = "Sí",
		alert_no = "No",
		alert_cancelled_by_user = "Cancelado por el usuario",
		toast_done = "¡Hecho!",
		toast_reverted = "¡Revertido!",
		toast_done_time_set_to = "Hecho, tiempo establecido en: %s segundos.",
		alert_item_list_not_found = "Lista de artículos no encontrada",
		alert_something_aint_right = "algo no va bien",
		toast_loading_war_items = "Cargando Artículos de Guerra",
		toast_loading_general_items = "Cargando Artículos Generales",
		toast_loading_expansion_items = "Cargando Artículos de Expansión",
		toast_loading_omega_items = "Cargando Artículos OMEGA",
		toast_loading_certs_and_tokens = "Cargando Certificados y Fichas",
		toast_loading_warcards = "Cargando Cartas de Guerra",
		toast_loading_factory_items = "Cargando Artículos de Fábrica",
		alert_certs_tokens_simcash_info = "Estos no se pueden recolectar a menos que gastes simcash para recolectarlos, establecí el tiempo en 60s para ti (1 simcash)",
		alert_warcards_simcash_info = "Estos no se pueden recolectar a menos que gastes simcash para recolectarlos, establecí el tiempo en 60s para que puedas recolectar por 1 simcash. No conozco los límites seguros, siéntete libre de probar y avisarme. Una vez que produzcas, abre Steve (monstruo VU) y las cartas deberían aparecer.",
		status_enabled = "[ACTIVADO]",
		status_active = "[ACTIVO]",
		status_regional_cactus = "[Cañón Cactus]",
		status_regional_green_valley = "[Valle Verde]",
		status_regional_limestone = "[Acantilados Calizos]",
		status_regional_sunny_isles = "[Islas Soleadas]",
		status_regional_frosty_fjords = "[Fiordos Helados]",
		status_war_preset = "[%s]",
		select_language_prompt = "Select Language / Seleccionar Idioma",
		language_set_toast = "Idioma establecido en: %s",
		alert_optimization_warning = "Realizando configuración inicial de memoria. Esto puede tardar unos minutos pero solo ocurrirá una vez para acelerar ejecuciones futuras.",
	},
	ar = {
		displayName = "العربية",
		-- Menu Choices
		menu_vu_expansion = "عناصر VU والتوسعة (جميع عناصر الشاطئ والشتاء غير متضمنة)",
		menu_war_items = "عناصر الحرب (المجموعة الطبية غير متضمنة)",
		menu_omega_items = "عناصر أوميغا",
		menu_regional_items = "العناصر الإقليمية",
		menu_railroad_items = "عناصر السكك الحديدية",
		menu_airport_items = "عناصر المطار",
		menu_christmas_items = "عناصر عيد الميلاد",
		menu_items_that_didnt_fit = "العناصر التي لم تناسب",
		menu_speedup_tokens = "رموز التسريع والشهادات",
		menu_war_items_presets = "إعدادات عناصر الحرب المسبقة",
		menu_revert_to_default = "العودة إلى الافتراضي",
		menu_warcards = "بطاقات الحرب",
		menu_system_settings = "إعدادات النظام (المضاعف، الوقت، المستوى)",
		menu_exit = "خروج",
		menu_choose_option = "اختر خيارًا",
		menu_choose_option_cancel_abort = "اختر خيارًا، إلغاء للإحباط",
		menu_choose_what_you_need_proceed = "اختر ما تحتاجه، ثم اضغط على متابعة",

		-- Time Menu Choices
		time_menu_remove_production_time = "إزالة وقت الإنتاج",
		time_menu_edit_production_amount = "تعديل كمية الإنتاج",
		time_menu_exclude_lvl_requirement = "استبعاد متطلبات مستوى الإنتاج",
		time_menu_proceed = "متابعة",
		time_menu_edit_mult_status = "تعديل المضاعف [حاليًا عند: %s]",
		time_menu_exclude_lvl_req_reverted = "استبعاد متطلبات المستوى [تم التراجع]",
		time_menu_exclude_lvl_req_done = "استبعاد متطلبات المستوى [تم]",
		time_menu_prod_time_status = "إزالة وقت الإنتاج [%s ثوانٍ]",

		-- Regional Items Menu
		region_cactus_canyon = "وادي الصبار",
		region_green_valley = "الوادي الأخضر",
		region_limestone_cliffs = "منحدرات الحجر الجيري",
		region_sunny_isles = "الجزر المشمسة",
		region_frosty_fjords = "الخلجان الجليدية",

		-- Warcards Menu
		warcards_comic_hand = "يد كوميدية",
		warcards_shrink_ray = "شعاع التقليص",
		warcards_giant_rock_monster = "وحش صخري عملاق",
		warcards_not_in_kansas = "ليس في كانساس",
		warcards_magnetism = "المغناطيسية",
		warcards_tentacle_vortex = "دوامة المجسات",
		warcards_flying_vu_robot = "روبوت Vu الطائر",
		warcards_disco_twister = "إعصار الديسكو",
		warcards_plant_monster = "وحش نباتي",
		warcards_blizzaster = "بليزاستر",
		warcards_fishaster = "فيشاستر",
		warcards_ancient_curse = "لعنة قديمة",
		warcards_hands_of_doom = "أيادي الهلاك",
		warcards_16_tons = "16 طنًا",
		warcards_spiders = "عناكب",
		warcards_dance_shoes = "أحذية الرقص",
		warcards_building_portal = "بوابة المبنى",
		warcards_b_movie_monster = "وحش فيلم درجة ثانية",
		warcards_hissy_fit = "نوبة غضب",
		warcards_mellow_bellow = "هدير هادئ",
		warcards_doomsday_quack = "بطة يوم القيامة",
		warcards_electric_deity = "إله كهربائي",
		warcards_shield_buster = "محطم الدروع",
		warcards_zest_from_above = "حماس من الأعلى",

		-- Factory Item Names
		item_metal = "معدن",
		item_wood = "خشب",
		item_plastic = "بلاستيك",
		item_seed = "بذور",
		item_mineral = "معدن",
		item_chemicals = "مواد كيميائية",
		item_textiles = "منسوجات",
		item_sugar = "سكر",
		item_glass = "زجاج",
		item_animal_feed = "علف حيوانات",
		item_electrical_components = "مكونات كهربائية",

		-- Toasts and Alerts
		toast_loading_root_pointer = "جاري تحميل المؤشر الجذر",
		alert_root_pointer_not_found = "لم يتم العثور على المؤشر الجذر، تأكد من أنك متصل بالعملية الصحيحة!",
		alert_production_base_address_not_found = "لم يتم العثور على عنوان قاعدة الإنتاج (تغيير محتمل في الإزاحة؟).",
		alert_mult_table_not_prepared = "جدول المضاعف لم يتم إعداده بشكل صحيح!",
		alert_time_value_table_not_prepared = "جدول قيمة الوقت لم يتم إعداده بشكل صحيح!",
		alert_level_req_table_not_prepared = "جدول متطلبات المستوى لم يتم إعداده بشكل صحيح!",
		toast_time_prepared = "الوقت جاهز!",
		prompt_enter_item_ammount = "أدخل عدد العناصر المراد استلامها",
		alert_are_you_sure_high_values_ban = "هل أنت متأكد؟ القيم العالية يمكن أن تؤدي إلى حظرك",
		alert_yes = "نعم",
		alert_no = "لا",
		alert_cancelled_by_user = "ألغاه المستخدم",
		toast_done = "تم!",
		toast_reverted = "تم التراجع!",
		toast_done_time_set_to = "تم، تم ضبط الوقت على: %s ثوانٍ.",
		alert_item_list_not_found = "قائمة العناصر غير موجودة",
		alert_something_aint_right = "هناك خطأ ما",
		toast_loading_war_items = "جاري تحميل عناصر الحرب",
		toast_loading_general_items = "جاري تحميل العناصر العامة",
		toast_loading_expansion_items = "جاري تحميل عناصر التوسعة",
		toast_loading_omega_items = "جاري تحميل عناصر أوميغا",
		toast_loading_certs_and_tokens = "جاري تحميل الشهادات والرموز",
		toast_loading_warcards = "جاري تحميل بطاقات الحرب",
		toast_loading_factory_items = "جاري تحميل عناصر المصنع",
		alert_certs_tokens_simcash_info = "لا يمكن جمع هذه العناصر إلا إذا أنفقت simcash لجمعها، لقد قمت بتعيين الوقت على 60 ثانية لك (1 simcash)",
		alert_warcards_simcash_info = "لا يمكن جمع هذه البطاقات إلا إذا أنفقت simcash لجمعها، لقد قمت بتعيين الوقت على 60 ثانية حتى تتمكن من جمعها مقابل 1 simcash. لا أعرف الحدود الآمنة، لا تتردد في الاختبار وإخباري. بمجرد الإنتاج، افتح Steve (وحش VU) ويجب أن تظهر البطاقات.",
		status_enabled = "[مفعل]",
		status_active = "[نشط]",
		status_regional_cactus = "[وادي الصبار]",
		status_regional_green_valley = "[الوادي الأخضر]",
		status_regional_limestone = "[منحدرات الحجر الجيري]",
		status_regional_sunny_isles = "[الجزر المشمسة]",
		status_regional_frosty_fjords = "[الخلجان الجليدية]",
		status_war_preset = "[%s]",
		select_language_prompt = "اختر اللغة / Select Language",
		language_set_toast = "تم ضبط اللغة على: %s",
		alert_optimization_warning = "جاري إعداد الذاكرة الأولي. قد يستغرق هذا بضع دقائق ولكنه سيحدث مرة واحدة فقط لتسريع التشغيل المستقبلي.",
	},
	tr = {
		displayName = "Türkçe",
		-- Menu Choices
		menu_vu_expansion = "VU ve Genişletme Öğeleri (Bazı plaj ve kış öğeleri hariç)",
		menu_war_items = "Savaş Öğeleri (İlkyardım Çantası dahil değil)",
		menu_omega_items = "Omega Öğeleri",
		menu_regional_items = "Bölgesel Öğeler",
		menu_railroad_items = "Demiryolu Öğeleri",
		menu_airport_items = "Havaalanı Öğeleri",
		menu_christmas_items = "Noel Öğeleri",
		menu_items_that_didnt_fit = "Uyumsuz Öğeler",
		menu_speedup_tokens = "Hızlandırma Jetonları ve Sertifikalar",
		menu_war_items_presets = "Savaş Öğeleri Hazır Ayarlar",
		menu_revert_to_default = "Varsayılana Geri Dön",
		menu_warcards = "Savaş Kartları",
		menu_system_settings = "Sistem Ayarları (çarpan, süre, seviye)",
		menu_exit = "Çıkış",
		menu_choose_option = "Bir seçenek seçin",
		menu_choose_option_cancel_abort = "Bir seçenek seçin, iptal etmek için iptal\\'e basın",
		menu_choose_what_you_need_proceed = "İhtiyacınız olanı seçin, ardından Devam\\'a basın",

		-- Time Menu Choices
		time_menu_remove_production_time = "Üretim Süresini Kaldır",
		time_menu_edit_production_amount = "Üretim Miktarını Düzenle",
		time_menu_exclude_lvl_requirement = "Üretim Seviyesi Gereksinimini Kaldır",
		time_menu_proceed = "Devam Et",
		time_menu_edit_mult_status = "Çarpanı Düzenle [ŞU ANDA: %s]",
		time_menu_exclude_lvl_req_reverted = "Seviye gereksinimini kaldır [GERİ ALINDI]",
		time_menu_exclude_lvl_req_done = "Seviye gereksinimini kaldır [TAMAMLANDI]",
		time_menu_prod_time_status = "Üretim Süresini Kaldır [%s sn]",

		-- Regional Items Menu
		region_cactus_canyon = "Kaktüs Kanyonu",
		region_green_valley = "Yeşil Vadi",
		region_limestone_cliffs = "Kireçtaşı Tepeler",
		region_sunny_isles = "Güneşli Adalar",
		region_frosty_fjords = "Dondurucu Fiyort",

		-- Warcards Menu
		warcards_comic_hand = "Komik El",
		warcards_shrink_ray = "Shrink Ray",
		warcards_giant_rock_monster = "Dev Kaya Canavarı",
		warcards_not_in_kansas = "Kansas\\'ta Değiliz",
		warcards_magnetism = "Çekicilik",
		warcards_tentacle_vortex = "Dokungaçlı Girdap",
		warcards_flying_vu_robot = "Uçan Vu Robotu",
		warcards_disco_twister = "Disko Hortumu",
		warcards_plant_monster = "Bitki Canavarı",
		warcards_blizzaster = "Kar Felaketi",
		warcards_fishaster = "Balıkafet",
		warcards_ancient_curse = "Antik Lanet",
		warcards_hands_of_doom = "Kıyametin Elleri",
		warcards_16_tons = "16 Ton",
		warcards_spiders = "Örümcekler",
		warcards_dance_shoes = "Dans Ayakkabıları",
		warcards_building_portal = "Bina Portalı",
		warcards_b_movie_monster = "B Film Canavarı",
		warcards_hissy_fit = "Öfke Nöbeti",
		warcards_mellow_bellow = "Boğuk Böğürtü",
		warcards_doomsday_quack = "Kıyamet Günü Vaklaması",
		warcards_electric_deity = "Elektrik İlahı",
		warcards_shield_buster = "Kalkan Patlatıcı",
		warcards_zest_from_above = "Yukarıdan Gelen Canlılık",

		-- Factory Item Names
		item_metal = "Metal",
		item_wood = "Ahşap",
		item_plastic = "Plastik",
		item_seed = "Tohumlar",
		item_mineral = "Mineraller",
		item_chemicals = "Kimyasallar",
		item_textiles = "Tekstil",
		item_sugar = "Şeker ve Baharat",
		item_glass = "Cam",
		item_animal_feed = "Hayvan Yemi",
		item_electrical_components = "Elektrikli Aksamlar",

		-- Toasts and Alerts
		toast_loading_root_pointer = "Root işaretçisi yükleniyor",
		alert_root_pointer_not_found = "Root işaretçisi bulunamadı, doğru işleme eklendiğinizden emin olun!",
		alert_production_base_address_not_found = "Üretim Temel Adresi bulunamadı (olası ofset değişikliği?).",
		alert_mult_table_not_prepared = "Çarpan tablosu doğru hazırlanmadı!",
		alert_time_value_table_not_prepared = "Süre Değer Tablosu doğru hazırlanmadı!",
		alert_level_req_table_not_prepared = "Seviye gereksinim tablosu doğru hazırlanmadı!",
		toast_time_prepared = "Süre hazırlandı!",
		prompt_enter_item_ammount = "Alınacak öğe sayısını girin",
		alert_are_you_sure_high_values_ban = "Emin misiniz? Yüksek değerler yasaklanmanıza neden olabilir",
		alert_yes = "Evet",
		alert_no = "Hayır",
		alert_cancelled_by_user = "Kullanıcı tarafından iptal edildi",
		toast_done = "Tamamlandı!",
		toast_reverted = "Geri alındı!",
		toast_done_time_set_to = "Tamamlandı, süre ayarlandı: %s saniye.",
		alert_item_list_not_found = "Öğe listesi bulunamadı",
		alert_something_aint_right = "bir şeyler ters gitti",
		toast_loading_war_items = "Savaş Öğeleri Yükleniyor",
		toast_loading_general_items = "Genel Öğeler Yükleniyor",
		toast_loading_expansion_items = "Genişletme Öğeleri Yükleniyor",
		toast_loading_omega_items = "OMEGA Öğeleri Yükleniyor",
		toast_loading_certs_and_tokens = "Hızlandırma Jetonları ve Sertifikalar Yükleniyor",
		toast_loading_warcards = "Savaş Kartları Yükleniyor",
		toast_loading_factory_items = "Fabrika Öğeleri Yükleniyor",
		alert_certs_tokens_simcash_info = "Bunlar, simpara harcamadığınız sürece toplanamaz, sizin için süreyi 60 saniyeye ayarladım (1 simpara)",
		alert_warcards_simcash_info = "Bunlar, simpara harcamadığınız sürece toplanamaz, 1 simcash karşılığında toplayabilmeniz için süreyi 60 saniyeye ayarladım. Güvenli sınırları bilmiyorum, test etmekten ve bana bildirmekten çekinmeyin. Üretim yaptıktan sonra Steve'i (VU canavarını) açın ve kartlar gözükecektir.",
		status_enabled = "[DIAKTIFKAN]",
		status_active = "[AKTIF]",
		status_regional_cactus = "[Kaktüs Kanyonu]",
		status_regional_green_valley = "[Yeşil Vadi]",
		status_regional_limestone = "[Kireçtaşı Tepeler]",
		status_regional_sunny_isles = "[Güneşli Adalar]",
		status_regional_frosty_fjords = "[Dondurucu Fiyort]",
		status_war_preset = "[%s]",
		select_language_prompt = "Dil Seç / Select Language",
		language_set_toast = "Dil Ayarlandı: %s",
		alert_optimization_warning = "İlk bellek kurulumu yapılıyor. Bu birkaç dakika sürebilir ancak sonraki çalıştırmaları hızlandırmak için sadece bir kez yapılacaktır.",
	},
	pt = {
		displayName = "Português",
		-- Menu Choices
		menu_vu_expansion = "Itens VU e de Expansão (todos os de praia e inverno não incluídos)",
		menu_war_items = "Itens de Guerra (Kit Médico não incluído)",
		menu_omega_items = "Itens Omega",
		menu_regional_items = "Itens Regionais",
		menu_railroad_items = "Itens Ferroviários",
		menu_airport_items = "Itens de Aeroporto",
		menu_christmas_items = "Itens de Natal",
		menu_items_that_didnt_fit = "Itens que não couberam",
		menu_speedup_tokens = "Fichas de Aceleração e Certificados",
		menu_war_items_presets = "Predefinições de Itens de Guerra",
		menu_revert_to_default = "Reverter para o padrão",
		menu_warcards = "Cartas de Guerra",
		menu_system_settings = "Configurações do Sistema (mult, tempo, nível)",
		menu_exit = "Sair",
		menu_choose_option = "Escolha uma opção",
		menu_choose_option_cancel_abort = "Escolha uma opção, cancele para abortar",
		menu_choose_what_you_need_proceed = "Escolha o que você precisa, depois clique em Prosseguir",

		-- Time Menu Choices
		time_menu_remove_production_time = "Remover Tempo de Produção",
		time_menu_edit_production_amount = "Editar Quantidade de Produção",
		time_menu_exclude_lvl_requirement = "Excluir Requisito de Nível de Produção",
		time_menu_proceed = "Prosseguir",
		time_menu_edit_mult_status = "Editar Multiplicador [ATUALMENTE EM: %s]",
		time_menu_exclude_lvl_req_reverted = "Excluir req. de nível [REVERTIDO]",
		time_menu_exclude_lvl_req_done = "Excluir req. de nível [FEITO]",
		time_menu_prod_time_status = "Remover Tempo de Produção [%ss]",

		-- Regional Items Menu
		region_cactus_canyon = "Desfiladeiro do Cacto",
		region_green_valley = "Vale Verdejante",
		region_limestone_cliffs = "Falésias de Calcário",
		region_sunny_isles = "Ilhas Ensolaradas",
		region_frosty_fjords = "Fiordes Gelados",

		-- Warcards Menu
		warcards_comic_hand = "Mão de Banda Desenhada",
		warcards_shrink_ray = "Raio Encolhedor",
		warcards_giant_rock_monster = "Monstro de Pedra Gigante",
		warcards_not_in_kansas = "Não Estamos no Kansas",
		warcards_magnetism = "Magnetismo",
		warcards_tentacle_vortex = "Vórtice de Tentáculos",
		warcards_flying_vu_robot = "Robô Vu Voador",
		warcards_disco_twister = "Tornado Discoteca",
		warcards_plant_monster = "Monstro Planta",
		warcards_blizzaster = "Nevasca Desastrosa",
		warcards_fishaster = "Peixastrofe",
		warcards_ancient_curse = "Maldição Antiga",
		warcards_hands_of_doom = "Mãos da Perdição",
		warcards_16_tons = "16 Toneladas",
		warcards_spiders = "Aranhas",
		warcards_dance_shoes = "Sapatos de Dança",
		warcards_building_portal = "Portal de Construção",
		warcards_b_movie_monster = "Monstro de Filme B",
		warcards_hissy_fit = "Ataque de Nervos",
		warcards_mellow_bellow = "Rugido Suave",
		warcards_doomsday_quack = "Quack do Juízo Final",
		warcards_electric_deity = "Divindade Elétrica",
		warcards_shield_buster = "Destruidor de Escudos",
		warcards_zest_from_above = "Entusiasmo Celestial",

		-- Factory Item Names
		item_metal = "Metal",
		item_wood = "Madeira",
		item_plastic = "Plástico",
		item_seed = "Semente",
		item_mineral = "Mineral",
		item_chemicals = "Químicos",
		item_textiles = "Têxteis",
		item_sugar = "Açúcar",
		item_glass = "Vidro",
		item_animal_feed = "Ração Animal",
		item_electrical_components = "Componentes Elétricos",

		-- Toasts and Alerts
		toast_loading_root_pointer = "Carregando ponteiro raiz",
		alert_root_pointer_not_found = "Ponteiro raiz não encontrado, certifique-se de que anexou ao processo correto!",
		alert_production_base_address_not_found = "Endereço base de produção não encontrado (possível alteração de offset?).",
		alert_mult_table_not_prepared = "Tabela de multiplicadores não preparada corretamente!",
		alert_time_value_table_not_prepared = "Tabela de valores de tempo não preparada corretamente!",
		alert_level_req_table_not_prepared = "Tabela de requisitos de nível não preparada corretamente!",
		toast_time_prepared = "Tempo preparado!",
		prompt_enter_item_ammount = "Insira a quantidade de itens a receber",
		alert_are_you_sure_high_values_ban = "Tem certeza? Valores altos podem resultar em banimento",
		alert_yes = "Sim",
		alert_no = "Não",
		alert_cancelled_by_user = "Cancelado pelo usuário",
		toast_done = "Feito!",
		toast_reverted = "Revertido!",
		toast_done_time_set_to = "Feito, tempo definido para: %s segundos.",
		alert_item_list_not_found = "Lista de itens não encontrada",
		alert_something_aint_right = "algo não está certo",
		toast_loading_war_items = "Carregando Itens de Guerra",
		toast_loading_general_items = "Carregando Itens Gerais",
		toast_loading_expansion_items = "Carregando Itens de Expansão",
		toast_loading_omega_items = "Carregando Itens OMEGA",
		toast_loading_certs_and_tokens = "Carregando Certificados e Fichas",
		toast_loading_warcards = "Carregando Cartas de Guerra",
		toast_loading_factory_items = "Carregando Itens de Fábrica",
		alert_certs_tokens_simcash_info = "Estes não podem ser coletados a menos que você gaste simcash para coletá-los, defini o tempo para 60s para você (1 simcash)",
		alert_warcards_simcash_info = "Estas cartas não podem ser coletadas a menos que você gaste simcash para coletá-las, defini o tempo para 60s para que você possa coletar por 1 simcash. Não conheço os limites seguros, sinta-se à vontade para testar e me avisar. Assim que produzir, abra o Steve (monstro VU) e as cartas devem aparecer.",
		status_enabled = "[ATIVADO]",
		status_active = "[ATIVO]",
		status_regional_cactus = "[Desfiladeiro do Cacto]",
		status_regional_green_valley = "[Vale Verde]",
		status_regional_limestone = "[Falésias de Calcário]",
		status_regional_sunny_isles = "[Ilhas Ensolaradas]",
		status_regional_frosty_fjords = "[Fiordes Gelados]",
		status_war_preset = "[%s]",
		select_language_prompt = "Selecionar Idioma / Select Language",
		language_set_toast = "Idioma definido para: %s",
		alert_optimization_warning = "Realizando configuração inicial de memória. Isso pode levar alguns minutos, mas acontecerá apenas uma vez para acelerar execuções futuras.",
	},
	id = {
		displayName = "Bahasa Indonesia",
		-- Menu Choices
		menu_vu_expansion = "Item VU dan Ekspansi (semua item pantai dan musim dingin tidak termasuk)",
		menu_war_items = "Item Perang (Medkit tidak termasuk)",
		menu_omega_items = "Item Omega",
		menu_regional_items = "Item Regional",
		menu_railroad_items = "Item Kereta Api",
		menu_airport_items = "Item Bandara",
		menu_christmas_items = "Item Natal",
		menu_items_that_didnt_fit = "Item yang tidak masuk kategori",
		menu_speedup_tokens = "Token Percepatan dan Sertifikat",
		menu_war_items_presets = "Preset Item Perang",
		menu_revert_to_default = "Kembali ke default",
		menu_warcards = "Kartu Perang",
		menu_system_settings = "Pengaturan Sistem (pengganda, waktu, lvl)",
		menu_exit = "Keluar",
		menu_choose_option = "Pilih opsi",
		menu_choose_option_cancel_abort = "Pilih opsi, batalkan untuk menggagalkan",
		menu_choose_what_you_need_proceed = "Pilih yang Anda butuhkan, lalu tekan Lanjutkan",

		-- Time Menu Choices
		time_menu_remove_production_time = "Hapus Waktu Produksi",
		time_menu_edit_production_amount = "Edit jumlah Produksi",
		time_menu_exclude_lvl_requirement = "Kecualikan persyaratan level produksi",
		time_menu_proceed = "Lanjutkan",
		time_menu_edit_mult_status = "Edit Pengganda [SAAT INI: %s]",
		time_menu_exclude_lvl_req_reverted = "Kecualikan persyaratan level [DIKEMBALIKAN]",
		time_menu_exclude_lvl_req_done = "Kecualikan persyaratan level [SELESAI]",
		time_menu_prod_time_status = "Hapus Waktu Produksi [%sdtk]",

		-- Regional Items Menu
		region_cactus_canyon = "Ngarai Kaktus",
		region_green_valley = "Lembah Hijau",
		region_limestone_cliffs = "Tebing Batu Kapur",
		region_sunny_isles = "Pulau Cerah",
		region_frosty_fjords = "Fyord Dingin",

		-- Warcards Menu
		warcards_comic_hand = "Tangan Komik",
		warcards_shrink_ray = "Sinar Pengecil",
		warcards_giant_rock_monster = "Monster Batu Raksasa",
		warcards_not_in_kansas = "Bukan di Kansas",
		warcards_magnetism = "Magnetisme",
		warcards_tentacle_vortex = "Pusaran Tentakel",
		warcards_flying_vu_robot = "Robot Vu Terbang",
		warcards_disco_twister = "Angin Puting Beliung Disko",
		warcards_plant_monster = "Monster Tanaman",
		warcards_blizzaster = "Blizzaster",
		warcards_fishaster = "Fishaster",
		warcards_ancient_curse = "Kutukan Kuno",
		warcards_hands_of_doom = "Tangan Kehancuran",
		warcards_16_tons = "16 Ton",
		warcards_spiders = "Laba-laba",
		warcards_dance_shoes = "Sepatu Dansa",
		warcards_building_portal = "Portal Bangunan",
		warcards_b_movie_monster = "Monster Film B",
		warcards_hissy_fit = "Amukan",
		warcards_mellow_bellow = "Raungan Halus",
		warcards_doomsday_quack = "Bebek Hari Kiamat",
		warcards_electric_deity = "Dewa Listrik",
		warcards_shield_buster = "Penghancur Perisai",
		warcards_zest_from_above = "Semangat dari Atas",

		-- Factory Item Names
		item_metal = "Logam",
		item_wood = "Kayu",
		item_plastic = "Plastik",
		item_seed = "Benih",
		item_mineral = "Mineral",
		item_chemicals = "Bahan Kimia",
		item_textiles = "Tekstil",
		item_sugar = "Gula",
		item_glass = "Kaca",
		item_animal_feed = "Pakan Ternak",
		item_electrical_components = "Komponen Listrik",

		-- Toasts and Alerts
		toast_loading_root_pointer = "Memuat root pointer",
		alert_root_pointer_not_found = "Root Pointer tidak ditemukan, pastikan Anda terhubung ke proses yang benar!",
		alert_production_base_address_not_found = "Alamat Dasar Produksi tidak ditemukan (kemungkinan perubahan offset?).",
		alert_mult_table_not_prepared = "Tabel pengganda tidak disiapkan dengan benar!",
		alert_time_value_table_not_prepared = "Tabel Nilai Waktu tidak disiapkan dengan benar!",
		alert_level_req_table_not_prepared = "Tabel persyaratan level tidak disiapkan dengan benar!",
		toast_time_prepared = "Waktu disiapkan!",
		prompt_enter_item_ammount = "Masukkan jumlah item yang akan diterima",
		alert_are_you_sure_high_values_ban = "Apakah Anda yakin? Nilai tinggi dapat membuat Anda diblokir",
		alert_yes = "Ya",
		alert_no = "Tidak",
		alert_cancelled_by_user = "Dibatalkan oleh pengguna",
		toast_done = "Selesai!",
		toast_reverted = "Dikembalikan!",
		toast_done_time_set_to = "Selesai, waktu diatur ke: %s detik.",

		-- XP Modification Translations
		prompt_enter_XP_ammount = "Masukkan jumlah XP yang ingin Anda dapatkan dari setiap item. Melebihi level 99 akan membuat akun Anda diblokir!",
		menu_modify_xp = "Ubah XP Item",
		xp_menu_edit_xp_amount = "Saat ini mendapatkan %d XP dari item, klik untuk mengedit",
		xp_menu_back_to_main = "Kembali ke menu utama (kembalikan perubahan)",
		alert_xp_set = "XP diatur ke: %d",

		alert_item_list_not_found = "Daftar item tidak ditemukan",
		alert_something_aint_right = "ada yang tidak beres",
		toast_loading_war_items = "Memuat Item Perang",
		toast_loading_general_items = "Memuat Item Umum",
		toast_loading_expansion_items = "Memuat Item Ekspansi",
		toast_loading_omega_items = "Memuat Item OMEGA",
		toast_loading_certs_and_tokens = "Memuat Sertifikat dan Token",
		toast_loading_warcards = "Memuat Kartu Perang",
		toast_loading_factory_items = "Memuat Item Pabrik",
		alert_certs_tokens_simcash_info = "Ini tidak dapat dikumpulkan kecuali Anda membelanjakan simcash untuk mengumpulkannya, saya mengatur waktu ke 60 detik untuk Anda (1 simcash)",
		alert_warcards_simcash_info = "Ini tidak dapat dikumpulkan kecuali Anda membelanjakan simcash untuk mengumpulkannya, saya mengatur waktu ke 60 detik sehingga Anda dapat mengumpulkan untuk 1 simcash. Saya tidak tahu batas aman, jangan ragu untuk menguji dan memberi tahu saya. Setelah Anda berproduksi, buka Steve (monster VU) dan kartu akan muncul.",
		status_enabled = "[DIAKTIFKAN]",
		status_active = "[AKTIF]",
		status_regional_cactus = "[Ngarai Kaktus]",
		status_regional_green_valley = "[Lembah Hijau]",
		status_regional_limestone = "[Tebing Batu Kapur]",
		status_regional_sunny_isles = "[Pulau Cerah]",
		status_regional_frosty_fjords = "[Fyord Dingin]",
		status_war_preset = "[%s]",
		select_language_prompt = "Pilih Bahasa / Select Language",
		language_set_toast = "Bahasa diatur ke: %s",
		alert_optimization_warning = "Sedang melakukan pengaturan memori awal. Ini mungkin memakan waktu beberapa menit tetapi hanya akan terjadi sekali untuk mempercepat proses selanjutnya.",
	},
	-- Add other languages here, e.g., fr, de, etc.
}

local function getText(key, ...)
	local langTable = translations[currentLanguage] or translations["en"] -- Fallback to English
	local text = langTable[key] or key -- Fallback to the key itself
	if #{ ... } > 0 then
		return string.format(text, ...)
	end
	return text
end

--===========================================
--            LANGUAGE SUPPORT TABLES
--===========================================
local regionalItemsMenu
local timeMenuChoices
local menuChoices
local warcardsMenu
local timeMenuChoices_constant
local menuChoices_constant
local factoryItemNames

local function initializeMenus()
	regionalItemsMenu = {
		[1] = getText("region_cactus_canyon"),
		[2] = getText("region_green_valley"),
		[3] = getText("region_limestone_cliffs"),
		[4] = getText("region_sunny_isles"),
		[5] = getText("region_frosty_fjords"),
	}
	timeMenuChoices = {
		[1] = getText("time_menu_remove_production_time"),
		[2] = getText("time_menu_edit_production_amount"),
		[3] = getText("time_menu_exclude_lvl_requirement"),
		[4] = getText("time_menu_proceed"),
	}
	menuChoices = {
		[1] = getText("menu_vu_expansion") .. " ",
		[2] = getText("menu_war_items") .. " ",
		[3] = getText("menu_omega_items"),
		[4] = getText("menu_regional_items"),
		[5] = getText("menu_railroad_items"),
		[6] = getText("menu_airport_items"),
		[7] = getText("menu_christmas_items"),
		[8] = getText("menu_items_that_didnt_fit"),
		[9] = getText("menu_speedup_tokens"),
		[10] = getText("menu_modify_xp"),
		[11] = getText("menu_war_items_presets"),
		[12] = getText("menu_revert_to_default"),
		[13] = getText("menu_warcards") .. " ",
		[14] = getText("menu_system_settings"),
		[15] = getText("menu_exit"),
	}
	warcardsMenu = {
		[1] = getText("warcards_comic_hand"),
		[2] = getText("warcards_shrink_ray"),
		[3] = getText("warcards_giant_rock_monster"),
		[4] = getText("warcards_not_in_kansas"),
		[5] = getText("warcards_magnetism"),
		[6] = getText("warcards_tentacle_vortex"),
		[7] = getText("warcards_flying_vu_robot"),
		[8] = getText("warcards_disco_twister"),
		[9] = getText("warcards_plant_monster"),
		[10] = getText("warcards_blizzaster"),
		[11] = getText("warcards_fishaster"),
		[12] = getText("warcards_ancient_curse"),
		[13] = getText("warcards_hands_of_doom"),
		[14] = getText("warcards_16_tons"),
		[15] = getText("warcards_spiders"),
		[16] = getText("warcards_dance_shoes"),
		[17] = getText("warcards_building_portal"),
		[18] = getText("warcards_b_movie_monster"),
		[19] = getText("warcards_hissy_fit"),
		[20] = getText("warcards_mellow_bellow"),
		[21] = getText("warcards_doomsday_quack"),
		[22] = getText("warcards_electric_deity"),
		[23] = getText("warcards_shield_buster"),
		[24] = getText("warcards_zest_from_above"),
	}
	timeMenuChoices_constant = {
		[1] = getText("time_menu_remove_production_time"),
		[2] = getText("time_menu_edit_production_amount"),
		[3] = getText("time_menu_exclude_lvl_requirement"),
		[4] = getText("time_menu_proceed"),
	}
	menuChoices_constant = {
		[1] = getText("menu_vu_expansion") .. " ",
		[2] = getText("menu_war_items") .. " ",
		[3] = getText("menu_omega_items"),
		[4] = getText("menu_regional_items"),
		[5] = getText("menu_railroad_items"),
		[6] = getText("menu_airport_items"),
		[7] = getText("menu_christmas_items"),
		[8] = getText("menu_items_that_didnt_fit"),
		[9] = getText("menu_speedup_tokens"),
		[10] = getText("menu_modify_xp"),
		[11] = getText("menu_war_items_presets"),
		[12] = getText("menu_revert_to_default"),
		[13] = getText("menu_warcards") .. " ",
		[14] = getText("menu_system_settings"),
		[15] = getText("menu_exit"),
	}
	factoryItemNames = {
		getText("item_metal"),
		getText("item_wood"),
		getText("item_plastic"),
		getText("item_seed"),
		getText("item_mineral"),
		getText("item_chemicals"),
		getText("item_textiles"),
		getText("item_sugar"),
		getText("item_glass"),
		getText("item_animal_feed"),
		getText("item_electrical_components"),
	}
end

local function setLanguage()
	local langChoices = {}
	local langCodes = {}
	local i = 1
	for code, langData in pairs(translations) do
		-- For a nicer display, you could have a "displayName" in your translations table
		-- e.g., translations.en.displayName = "English"
		langChoices[i] = langData.displayName or code
		langCodes[i] = code
		i = i + 1
	end

	local selectedIndex = gg.choice(langChoices, nil, getText("select_language_prompt"))
	if selectedIndex then
		currentLanguage = langCodes[selectedIndex]
		gg.toast(getText("language_set_toast", currentLanguage))
		initializeMenus() -- Re-initialize menus with the new language
	else
		-- User cancelled, keep default or previous language
		-- Initialize menus if it's the first run with default language
		if not regionalItemsMenu then
			initializeMenus()
		end
	end
end

local function safeSetVisible(visible)
	if DEBUG or DISABLE_SET_VISIBLE then
		return
	end
	gg.setVisible(visible)
end

--===========================================
--      Necessary Initiation Functions
-- ==========================================
local function searchRootPointer()
	gg.toast(getText("toast_loading_root_pointer"))
	safeSetVisible(false)

	local found = MemoryOptimizer.findWorkingRegion("ROOT_ANCHOR", function()
		gg.clearResults()
		gg.searchNumber(RootPointerBits, gg.TYPE_BYTE, false, gg.SIGN_EQUAL, 0, -1, 0)
		local count = gg.getResultsCount()
		if count == 0 then
			return false
		end

		local anchors = gg.getResults(1)
		local anchorAddress = anchors[1].address
		gg.clearResults()

		-- Define broad regions strictly for the pointer search
		local broadRegions = gg.REGION_C_HEAP
			| gg.REGION_C_ALLOC
			| gg.REGION_C_DATA
			| gg.REGION_C_BSS
			| gg.REGION_PPSSPP
			| gg.REGION_ANONYMOUS
			| gg.REGION_JAVA_HEAP
			| gg.REGION_JAVA
			| gg.REGION_STACK
			| gg.REGION_ASHMEM

		gg.setRanges(broadRegions)
		gg.searchNumber(anchorAddress, gg.TYPE_QWORD, false, gg.SIGN_EQUAL, 0, -1, 0)

		if gg.getResultsCount() > 0 then
			RootPointer = gg.getResults(1)
			gg.clearResults()
			return true -- Success: Found a pointer to this anchor
		end

		return false -- Pointer not found for the first anchor
	end)

	if not found then
		gg.alert(getText("alert_root_pointer_not_found"))
		os.exit()
	end
end
--===========================================
--          helper functions
--===========================================

local function printTableSimple(t) --for debugging, prints a table you input as a parameter
	if type(t) ~= "table" then
		print("Not a table:", tostring(t))
		return
	end
	print("{") -- Start marker
	for key, value in pairs(t) do
		-- Use tostring() to handle different types for keys and values
		-- Use string.format for potentially better alignment and quoting strings
		local keyStr = type(key) == "string" and string.format("%q", key) or tostring(key) -- Quote string keys
		local valueStr = type(value) == "string" and string.format("%q", value) or tostring(value) -- Quote string values

		print(string.format("  [%s] = %s,", keyStr, valueStr)) -- Indent for readability
	end
	print("}") -- End marker
end

--=============================================
--      Debug Function for Offset Validation
--=============================================

local function debugOffsets()
	if not DEBUG then
		return
	end

	gg.toast("DEBUG: Validating offsets...")

	-- Ensure we are scanning ALL relevant pointer regions for validation
	-- This distinguishes "Offset Changed" from "Wrong Optimization Region"
	-- Dynamic mask from Optimizer ensures we don't miss regions like CODE_APP or OTHER
	local broadRegions = 0
	for _, r in ipairs(MemoryOptimizer.REGIONS) do
		broadRegions = broadRegions | r
	end
	gg.setRanges(broadRegions)

	local results = {}
	local toAdd = {}

	-- Root pointer (anchor - no scan needed)
	table.insert(toAdd, { address = RootPointer[1].address, flags = gg.TYPE_QWORD, name = "DEBUG_ROOT_POINTER" })

	-- Production/Time pointer
	local productionPointer = RootPointer[1].address + CONSTANTS.OFFSETS.PRODUCTION_BASE
	table.insert(toAdd, { address = productionPointer, flags = gg.TYPE_QWORD, name = "DEBUG_PTR_PRODUCTION" })

	-- War Items pointer
	local warItemPointer = RootPointer[1].address + CONSTANTS.OFFSETS.WAR_ITEMS_PTR
	table.insert(toAdd, { address = warItemPointer, flags = gg.TYPE_QWORD, name = "DEBUG_PTR_WAR_ITEMS" })
	gg.clearResults()
	gg.searchNumber(warItemPointer, gg.TYPE_QWORD, false, gg.SIGN_EQUAL, 0, -1, 0)
	results.WAR_ITEMS = gg.getResultsCount()
	gg.clearResults()

	-- Expansion Items pointer
	local expansionItemPointer = RootPointer[1].address + CONSTANTS.OFFSETS.EXPANSION_ITEMS_PTR
	table.insert(toAdd, { address = expansionItemPointer, flags = gg.TYPE_QWORD, name = "DEBUG_PTR_EXPANSION" })
	gg.clearResults()
	gg.searchNumber(expansionItemPointer, gg.TYPE_QWORD, false, gg.SIGN_EQUAL, 0, -1, 0)
	results.EXPANSION_ITEMS = gg.getResultsCount()
	gg.clearResults()

	-- OMEGA Items pointer
	local OMEGAPointer = RootPointer[1].address + CONSTANTS.OFFSETS.OMEGA_ITEMS_PTR
	table.insert(toAdd, { address = OMEGAPointer, flags = gg.TYPE_QWORD, name = "DEBUG_PTR_OMEGA" })

	-- Generic Items pointer
	local genericRootPtr = RootPointer[1].address + CONSTANTS.OFFSETS.GENERIC_ITEM_ROOT
	table.insert(toAdd, { address = genericRootPtr, flags = gg.TYPE_QWORD, name = "DEBUG_PTR_GENERIC_ITEMS" })
	gg.clearResults()
	gg.searchNumber(genericRootPtr, gg.TYPE_QWORD, false, gg.SIGN_EQUAL, 0, -1, 0)
	results.GENERIC_ITEMS = gg.getResultsCount()

	gg.clearResults()
	gg.clearResults()
	gg.searchNumber(OMEGAPointer, gg.TYPE_QWORD, false, gg.SIGN_EQUAL, 0, -1, 0)
	results.OMEGA_ITEMS = gg.getResultsCount()
	gg.clearResults()

	-- Certs pointer
	local certPointer = RootPointer[1].address + CONSTANTS.OFFSETS.CERTS_PTR
	table.insert(toAdd, { address = certPointer, flags = gg.TYPE_QWORD, name = "DEBUG_PTR_CERTS" })
	gg.clearResults()
	gg.searchNumber(certPointer, gg.TYPE_QWORD, false, gg.SIGN_EQUAL, 0, -1, 0)
	results.CERTS = gg.getResultsCount()
	gg.clearResults()

	-- Tokens pointer
	local tokenPointer = RootPointer[1].address + CONSTANTS.OFFSETS.TOKENS_PTR
	table.insert(toAdd, { address = tokenPointer, flags = gg.TYPE_QWORD, name = "DEBUG_PTR_TOKENS" })
	gg.clearResults()
	gg.searchNumber(tokenPointer, gg.TYPE_QWORD, false, gg.SIGN_EQUAL, 0, -1, 0)
	results.TOKENS = gg.getResultsCount()
	gg.clearResults()

	-- War Cards pointer
	local warCardPointer = RootPointer[1].address + CONSTANTS.OFFSETS.WAR_CARDS_PTR
	table.insert(toAdd, { address = warCardPointer, flags = gg.TYPE_QWORD, name = "DEBUG_PTR_WARCARDS" })
	gg.clearResults()
	gg.searchNumber(warCardPointer, gg.TYPE_QWORD, false, gg.SIGN_EQUAL, 0, -1, 0)
	results.WAR_CARDS = gg.getResultsCount()
	gg.clearResults()

	-- Save all computed pointer addresses to saved list
	gg.addListItems(toAdd)

	-- Build summary string
	local summary = "DEBUG: Offset Validation Results\n\n"
	local allOk = true

	for key, expected in pairs(CONSTANTS.EXPECTED_COUNTS) do
		local actual = results[key] or 0
		local status = (actual == expected) and "OK" or "MISMATCH"
		if actual ~= expected then
			allOk = false
		end
		summary = summary .. string.format("%s: %d (expected %d) [%s]\n", key, actual, expected, status)
	end

	if allOk then
		summary = summary .. "\nAll offsets appear correct!"
	else
		summary = summary .. "\nWARNING: Some offsets may have changed!"
	end

	summary = summary .. "\n\nSaved " .. #toAdd .. " root pointers to saved list."

	gg.alert(summary)
end

--=============================================
--      Time and Mult related functions
--=============================================

local function prepareProduction() --prepares the timeValueTable
	local productionPointer = RootPointer[1].address + CONSTANTS.OFFSETS.PRODUCTION_BASE --Time and mult related
	if productionPrepared == 1 then
		return 1
	else
		productionPrepared = 1
	end
	--get productionPointer

	local found = MemoryOptimizer.findWorkingRegion("PRODUCTION_ITEMS", function()
		gg.clearResults()
		gg.searchNumber(productionPointer, gg.TYPE_QWORD, false, gg.SIGN_EQUAL, 0, -1, 0)
		local count = gg.getResultsCount()
		if count == 0 then
			return false
		end

		productionBaseAddressTable = gg.getResults(count)
		gg.clearResults()
		return true
	end)

	if not found then
		gg.alert("Production Base Address not found (possible offset change?).")
		os.exit()
	end

	-- 1. Prepare Time Value Table
	local toGet = {}
	for i = 1, #productionBaseAddressTable do
		toGet[i] = {
			address = productionBaseAddressTable[i].address + CONSTANTS.OFFSETS.TIME_VALUE,
			flags = gg.TYPE_DWORD,
		}
	end
	timeValueTable = gg.getValues(toGet)

	-- 2. Prepare Level Req Table
	toGet = {}
	for i = 1, #productionBaseAddressTable do
		toGet[i] = {
			address = productionBaseAddressTable[i].address + CONSTANTS.OFFSETS.LEVEL_REQ,
			flags = gg.TYPE_DWORD,
		}
	end
	levelRequirementTable = gg.getValues(toGet)

	-- 3. Prepare Mult Table
	toGet = {}
	for i = 1, #productionBaseAddressTable do
		toGet[i] = {
			address = productionBaseAddressTable[i].address + CONSTANTS.OFFSETS.NAME_PTR_OFFSET,
			flags = gg.TYPE_QWORD,
		}
	end
	local namePointers = gg.getValues(toGet)

	multTable = {}
	for i = 1, #namePointers do
		multTable[i] = {
			address = namePointers[i].value + CONSTANTS.OFFSETS.MULT_VAL_OFFSET,
			flags = gg.TYPE_DWORD,
		}
	end

	-- 4. Prepare XP Value Table
	toGet = {}
	for i = 1, #productionBaseAddressTable do
		toGet[i] = {
			address = productionBaseAddressTable[i].address + CONSTANTS.OFFSETS.XP_VALUE,
			flags = gg.TYPE_DWORD,
		}
	end
	xpValueTable = gg.getValues(toGet)

	gg.toast("Time prepared! Found " .. #productionBaseAddressTable .. " production items.")
end

local function editMult() --edits the ammount you recieve when making items
	prepareProduction()
	local inputTable = {}
	while 1 do
		inputTable = gg.prompt({ getText("prompt_enter_item_ammount") }, { "10" }, { "number" })
		--printTableSimple(inputTable)
		if tonumber(inputTable[1], 10) > 100 then
			local sure =
				gg.alert(getText("alert_are_you_sure_high_values_ban"), getText("alert_yes"), getText("alert_no"))
			if sure == 1 then
				break
			elseif sure == nil then
				gg.alert(getText("alert_cancelled_by_user"))
				return nil
			end
		elseif inputTable == nil then
			gg.alert(getText("alert_cancelled_by_user"))
			return nil
		else
			break
		end
	end

	local toSet = {}
	for i = 1, #multTable do
		toSet[i] = {
			address = multTable[i].address,
			flags = gg.TYPE_DWORD,
			value = tonumber(inputTable[1]),
		}
	end
	gg.setValues(toSet)
	timeMenuChoices[2] = getText("time_menu_edit_mult_status", tonumber(inputTable[1]))
	gg.toast(getText("toast_done"))
end

local function excludeProdLvl() --excludes production level (lets you make all items from any player level)
	prepareProduction()
	if wasLvlExcluded == 1 then
		local toSet = {}
		for i = 1, #levelRequirementTable do
			toSet[i] = {
				address = levelRequirementTable[i].address,
				flags = gg.TYPE_DWORD,
				value = levelRequirementTable[i].value, -- Revert to original values (assuming they were stored or are known)
			}
		end
		gg.setValues(toSet)
		gg.toast(getText("toast_reverted"))
		timeMenuChoices[3] = getText("time_menu_exclude_lvl_req_reverted") -- Use index 3
		wasLvlExcluded = 0 -- Reset status
	else
		wasLvlExcluded = 1
		local toSet = {}
		for i = 1, #levelRequirementTable do
			toSet[i] = {
				address = levelRequirementTable[i].address,
				flags = gg.TYPE_DWORD,
				value = 0,
			}
		end
		gg.setValues(toSet)
		gg.toast(getText("toast_done"))
		timeMenuChoices[3] = getText("time_menu_exclude_lvl_req_done")
	end
end

local function editTime(value)
	prepareProduction()
	local targetValue = nil
	if value == nil then
		targetValue = 0
	else
		targetValue = value
	end
	local toSet = {}
	for i = 1, #timeValueTable do
		toSet[i] = {
			address = timeValueTable[i].address,
			flags = gg.TYPE_DWORD,
			value = targetValue,
		}
	end
	gg.setValues(toSet)
	gg.toast(getText("toast_done_time_set_to", targetValue / 1000))
	timeMenuChoices[1] = getText("time_menu_prod_time_status", targetValue / 1000)
end

--===========================================================
--      FIND FUNCTIONS
--===========================================================

local function findFactory() --finds addresess and values of factoryItems
	MemoryOptimizer.findWorkingRegion("FACTORY_ITEMS", function()
		gg.clearResults()
		local factoryConstants = {
			"-1501685376",
			"-1477359097",
			"-389414878",
			"-331876130",
			"-777869928",
			"809598022",
			"-545412710",
			"-2052593169",
			"-254286722",
			"-610175295",
			"-585905379",
		}
		local buffer = {}
		for i = 1, #factoryConstants do
			gg.clearResults()
			gg.searchNumber(tonumber(factoryConstants[i], 10), gg.TYPE_DWORD, false, gg.SIGN_EQUAL, 0, -1, 0)
			if gg.getResultsCount() == 0 then
				return false
			end -- Not found in this region
			local buffer2 = gg.getResults(1)
			buffer[i] = buffer2[1].address + CONSTANTS.OFFSETS.FACTORY_ITEM_VAL
		end
		gg.clearResults()

		-- If we got here, we found all factory items
		local toGet = {}
		for i = 1, 11 do --make a table for getValues
			toGet[i] = {
				address = buffer[i],
				flags = gg.TYPE_QWORD,
			}
		end
		factoryItems = gg.getValues(toGet)
		--addListItems

		local toAdd = {}
		for i = 1, 11 do
			local newItem = {
				address = factoryItems[i].address,
				flags = gg.TYPE_QWORD,
				name = factoryItemNames[i],
			}
			table.insert(toAdd, newItem)
		end
		gg.addListItems(toAdd)
		return true
	end)
end

local function findGenericItems()
	local genericRootPtr = RootPointer[1].address + CONSTANTS.OFFSETS.GENERIC_ITEM_ROOT

	if DEBUG then
		gg.toast("Loading Generic Items...")
		print(string.format("DEBUG: Searching for Pointer to: 0x%X", genericRootPtr))
	else
		gg.toast(getText("toast_loading_general_items"))
	end

	local success = MemoryOptimizer.findWorkingRegion("GENERIC_ITEMS", function()
		gg.clearResults()
		gg.searchNumber(genericRootPtr, gg.TYPE_QWORD, false, gg.SIGN_EQUAL, 0, -1, 0)

		local count = gg.getResultsCount()
		if count == 0 then
			return false
		end

		if DEBUG then
			print("DEBUG: Found " .. count .. " items (Matching Address)")
		end

		local results = gg.getResults(count)
		gg.clearResults()

		-- Batch 1: Read Name Pointers (ItemBase + 0x10)
		local namePtrRequests = {}
		for i, item in ipairs(results) do
			namePtrRequests[i] = { address = item.address + CONSTANTS.OFFSETS.ITEM_DATA_PTR, flags = gg.TYPE_QWORD }
		end
		local namePtrs = gg.getValues(namePtrRequests)

		-- Batch 2: Read Name Data (24 Bytes) from the Dereferenced Address
		local byteRequests = {}
		for i, ptrVal in ipairs(namePtrs) do
			local base = ptrVal.value
			for j = 0, 23 do
				table.insert(byteRequests, { address = base + j, flags = gg.TYPE_BYTE })
			end
		end

		local byteDataChunks = gg.getValues(byteRequests)

		local rawList = {}

		for i = 1, #results do
			local itemAddress = results[i].address
			local bytes = {}
			for j = 0, 23 do
				local idx = ((i - 1) * 24) + j + 1
				table.insert(bytes, byteDataChunks[idx].value & 0xFF)
			end

			-- Compute QWORDs Hash
			local qwordsStr = ""
			for j = 0, 2 do
				local offset = j * 8
				local low = bytes[offset + 1]
					| (bytes[offset + 2] << 8)
					| (bytes[offset + 3] << 16)
					| (bytes[offset + 4] << 24)
				local high = bytes[offset + 5]
					| (bytes[offset + 6] << 8)
					| (bytes[offset + 7] << 16)
					| (bytes[offset + 8] << 24)
				local val = low | (high << 32)
				qwordsStr = qwordsStr .. string.format("0x%016X", val)
				if j < 2 then
					qwordsStr = qwordsStr .. ", "
				end
			end

			-- Lookup in DB
			local dbEntry = KNOWN_GENERIC_ITEMS_DB[qwordsStr]
			local sortIndex = 9999
			local itemName = "Unknown"

			if dbEntry then
				sortIndex = dbEntry.index
				itemName = dbEntry.name
			else
				-- Reconstruct raw name for Unknowns
				local cleanName = ""
				for _, b in ipairs(bytes) do
					if b == 0 then
						break
					end
					if b >= 32 and b <= 126 then
						cleanName = cleanName .. string.char(b)
					else
						cleanName = cleanName .. "."
					end
				end
				itemName = cleanName
			end

			table.insert(rawList, {
				item = { address = itemAddress, flags = gg.TYPE_QWORD, value = itemAddress }, -- Store as GG object style for compatibility?
				-- Wait, 'itemList' in legacy was a list of {address, flags, value}.
				-- Legacy usage: itemList[i].value -> this was the ITEM BASE ADDRESS.
				-- Legacy creation: itemList = gg.getValues(toGetItems).
				-- gg.getValues returns a table of {address, value, flags...}
				-- BUT WAIT.
				-- Legacy: toGetItems[i] = {address = listStart + stride*i ...}
				-- itemList = gg.getValues.
				-- So itemList[i].value was the QWORD at that address.
				-- Does the QWORD at that address == ItemBaseAddress?
				-- Let's assume legacy pattern was: "List of pointers to items".
				-- Scan logic: "searchNumber(factoryItems[1].value...)" -> This looks for pointers to factory items?
				-- No, "itemListStart + (i-1) * 8".
				-- The pointer-based search finds the addresses directly.
				-- So `results[i].address` IS the ItemBaseAddress we want.
				-- If legacy `itemList` stored pointers-to-pointers, then `.value` would be the ItemBaseAddress.
				-- If `findGenericItems` finds ItemBaseAddresses directly, we need to construct `itemList` such that `itemList[i].value` == ItemBaseAddress.
				-- We can mock the struct.

				start_addr = itemAddress, -- For sorting reference if needed
				sort_idx = sortIndex,
				name = itemName,
				qwords = qwordsStr,
				dwords_str = "", -- Todo if needed for debug dump
				result_obj = { address = 0, flags = gg.TYPE_QWORD, value = itemAddress }, -- Mock object
			})

			-- Build DWORD string for debug CSV if needed
			if DEBUG then
				local dwordsStr = ""
				for j = 0, 5 do
					local offset = j * 4
					local val = bytes[offset + 1]
						| (bytes[offset + 2] << 8)
						| (bytes[offset + 3] << 16)
						| (bytes[offset + 4] << 24)
					dwordsStr = dwordsStr .. string.format("0x%08X", val)
					if j < 5 then
						dwordsStr = dwordsStr .. ", "
					end
				end
				rawList[#rawList].dwords_str = dwordsStr
			end
		end

		-- Sort the list
		table.sort(rawList, function(a, b)
			return a.sort_idx < b.sort_idx
		end)

		-- Populate Global itemList
		itemList = {}
		for i, entry in ipairs(rawList) do
			itemList[i] = entry.result_obj
		end

		-- Debug Dump to CSV (Sorted)
		if DEBUG then
			local fileContent = "Index,Address,Name(Text),DWORDs(Hex),QWORDs(Hex)\n"
			for i, entry in ipairs(rawList) do
				fileContent = fileContent
					.. string.format(
						'%d,0x%X,%q,"%s","%s"\n',
						i,
						entry.start_addr,
						entry.name,
						entry.dwords_str,
						entry.qwords
					)
			end

			local dumpFile = gg.getFile() .. "_GenericItemsSorted.csv"
			local f = io.open(dumpFile, "w")
			if f then
				f:write(fileContent)
				f:close()
				gg.alert("Dumped " .. #rawList .. " Sorted Items to " .. dumpFile)
			end
		end

		return true
	end)

	if not success then
		gg.alert(getText("alert_item_list_not_found"))
		return 1
	end
end

local function dumpItemListDebug(listToDump, fileSuffix)
	gg.toast("DEBUG: Dumping scanned item list...")
	if not listToDump or #listToDump == 0 then
		gg.alert("DEBUG: List is empty, nothing to dump.")
		return
	end

	local fileContent = "Index,Address,Name(Text),DWORDs(Hex),QWORDs(Hex)\n"

	-- Batch 1: Read Name Pointers (ItemAddress + 0x10)
	local namePtrRequests = {}
	for i, item in ipairs(listToDump) do
		namePtrRequests[i] = { address = item.value + CONSTANTS.OFFSETS.ITEM_DATA_PTR, flags = gg.TYPE_QWORD }
	end
	local namePtrs = gg.getValues(namePtrRequests)

	-- Batch 2: Read Name Data (24 Bytes)
	local byteRequests = {}
	for i, ptrVal in ipairs(namePtrs) do
		local base = ptrVal.value
		for j = 0, 23 do
			table.insert(byteRequests, { address = base + j, flags = gg.TYPE_BYTE })
		end
	end

	local byteDataChunks = gg.getValues(byteRequests)

	local fileLine = ""

	for i = 1, #listToDump do
		local itemAddress = listToDump[i].value -- The address of the item
		local bytes = {}

		for j = 0, 23 do
			local idx = ((i - 1) * 24) + j + 1
			table.insert(bytes, byteDataChunks[idx].value & 0xFF)
		end

		-- 1. Text
		local cleanName = ""
		for _, b in ipairs(bytes) do
			if b == 0 then
				break
			end
			if b >= 32 and b <= 126 then
				cleanName = cleanName .. string.char(b)
			else
				cleanName = cleanName .. "."
			end
		end

		-- 2. DWORDs
		local dwordsStr = ""
		for j = 0, 5 do
			local offset = j * 4
			local val = bytes[offset + 1]
				| (bytes[offset + 2] << 8)
				| (bytes[offset + 3] << 16)
				| (bytes[offset + 4] << 24)
			dwordsStr = dwordsStr .. string.format("0x%08X", val)
			if j < 5 then
				dwordsStr = dwordsStr .. ", "
			end
		end

		-- 3. QWORDs
		local qwordsStr = ""
		for j = 0, 2 do
			local offset = j * 8
			local low = bytes[offset + 1]
				| (bytes[offset + 2] << 8)
				| (bytes[offset + 3] << 16)
				| (bytes[offset + 4] << 24)
			local high = bytes[offset + 5]
				| (bytes[offset + 6] << 8)
				| (bytes[offset + 7] << 16)
				| (bytes[offset + 8] << 24)
			local val = low | (high << 32)
			qwordsStr = qwordsStr .. string.format("0x%016X", val)
			if j < 2 then
				qwordsStr = qwordsStr .. ", "
			end
		end

		fileLine = fileLine .. string.format('%d,0x%X,%q,"%s","%s"\n', i, itemAddress, cleanName, dwordsStr, qwordsStr)
	end

	local dumpFile = gg.getFile() .. fileSuffix
	local f = io.open(dumpFile, "w")
	if f then
		f:write(fileContent .. fileLine)
		f:close()
		gg.alert("Dumped " .. #listToDump .. " Scanned Items to " .. dumpFile)
	else
		gg.alert("Failed to write scan dump file")
	end
end

local function findItemListLegacy() --Legacy pattern search, kept for debug validation
	if not DEBUG then
		return
	end

	gg.alert("DEBUG: Running Legacy Item Scan...")
	local success = MemoryOptimizer.findWorkingRegion("ITEM_LIST", function()
		local function checkWood(address)
			local toGet = { { address = address + CONSTANTS.OFFSETS.ITEM_CHECK_WOOD, flags = gg.TYPE_QWORD } }
			local results = gg.getValues(toGet)
			if results[1].value == factoryItems[2].value then
				return true
			else
				return false
			end
		end
		local function checkComponent(address)
			local toGet = { { address = address + CONSTANTS.OFFSETS.ITEM_CHECK_COMP, flags = gg.TYPE_QWORD } }
			local results = gg.getValues(toGet)
			if results[1].value == factoryItems[11].value then
				return true
			else
				return false
			end
		end
		gg.clearResults()
		gg.searchNumber(factoryItems[1].value, gg.TYPE_QWORD, false, gg.SIGN_EQUAL, 0, -1, 0)
		local count = gg.getResultsCount()
		if count == 0 then
			return false
		end

		local results = gg.getResults(count)
		gg.clearResults()

		itemListStart = nil -- Reset before check
		for i = 1, count do
			if checkWood(results[i].address) and checkComponent(results[i].address) then
				itemListStart = results[i].address
				break
			end
		end

		if itemListStart == nil then
			return false
		end
		return true
	end)

	if not success or itemListStart == nil then
		gg.alert(getText("alert_item_list_not_found"))
		return 1
	end

	local toGetItems = {}
	for i = 1, 135 do
		toGetItems[i] = {
			address = itemListStart + (i - 1) * CONSTANTS.OFFSETS.ITEM_LIST_STRIDE,
			flags = gg.TYPE_QWORD,
		}
	end
	local legacyItemList = gg.getValues(toGetItems)

	if DEBUG then
		dumpItemListDebug(legacyItemList, "_ScanDumpLegacy.csv")
	end
end

local function findWarItemList() --finds warItemList
	local warItemPointer = RootPointer[1].address + CONSTANTS.OFFSETS.WAR_ITEMS_PTR --offset the rootpointer to find warItemPointer

	MemoryOptimizer.findWorkingRegion("WAR_ITEMS", function()
		gg.clearResults()
		gg.searchNumber(warItemPointer, gg.TYPE_QWORD, false, gg.SIGN_EQUAL, 0, -1, 0)
		local count = gg.getResultsCount()
		if count == 0 then
			return false
		end

		local results = gg.getResults(count)
		gg.clearResults()

		-- If we found results, proceed with the rest of logic
		-- Note: Original logic didn't check count strictly but assumed it found something.
		-- We'll assume if we found the pointer value, we're in the right region.

		local toGet = {}
		for i = 1, 12 do
			-- Safety check if results count < 12? Original code assumed 12.
			if not results[i] then
				return false
			end

			toGet[i] = {
				address = results[i].address + CONSTANTS.OFFSETS.ITEM_DATA_PTR,
				flags = gg.TYPE_QWORD,
			}
		end
		-- ... rest of logic continues

		-- Wait, I should wrap the WHOLE logic block to ensure success.
		-- If getValues returns empty/bad values, return false?

		local toGetWar = gg.getValues(toGet)
		if not toGetWar or #toGetWar < 12 then
			return false
		end

		local toGet = {}
		for i = 1, 12 do
			toGet[i] = {
				address = toGetWar[i].value,
				flags = gg.TYPE_DWORD,
			}
		end
		local toGetWarTwo = gg.getValues(toGet)

		local successCount = 0
		for i = 1, 12 do
			if toGetWarTwo[i].value == 1835876616 then --ammo
				warItems[1] = results[i].address
				successCount = successCount + 1
			elseif toGetWarTwo[i].value == 1919501846 then --hydrant
				warItems[2] = results[i].address
				successCount = successCount + 1
			elseif toGetWarTwo[i].value == 1986937098 then --anvil
				warItems[3] = results[i].address
				successCount = successCount + 1
			elseif toGetWarTwo[i].value == 1869762578 then --propeller
				warItems[4] = results[i].address
				successCount = successCount + 1
			elseif toGetWarTwo[i].value == 1734692114 then --megaphone
				warItems[5] = results[i].address
				successCount = successCount + 1
			elseif toGetWarTwo[i].value == 1935755024 then --gasoline
				warItems[6] = results[i].address
				successCount = successCount + 1
			elseif toGetWarTwo[i].value == 1651855894 then --boots
				warItems[7] = results[i].address
				successCount = successCount + 1
			elseif toGetWarTwo[i].value == 1768706060 then --pliers
				warItems[8] = results[i].address
				successCount = successCount + 1
			elseif toGetWarTwo[i].value == 1651855892 then --ducky
				warItems[9] = results[i].address
				successCount = successCount + 1
			elseif toGetWarTwo[i].value == 1852391956 then --binoculars
				warItems[10] = results[i].address
				successCount = successCount + 1
			elseif toGetWarTwo[i].value == 1970032654 then --plunger
				warItems[11] = results[i].address
				successCount = successCount + 1
			elseif toGetWarTwo[i].value == 1684360460 then --medkit
				warItems[12] = results[i].address
				successCount = successCount + 1
			else
				-- Item not recognized, but might still be valid region if we found others?
				-- But strict check is safer.
			end
		end

		-- If we found all 12 items, return true
		if successCount >= 12 then
			return true
		else
			return false
		end
	end)
end

local function findExpansion() --finds expansionItems
	local expansionItemPointer = RootPointer[1].address + CONSTANTS.OFFSETS.EXPANSION_ITEMS_PTR
	MemoryOptimizer.findWorkingRegion("EXPANSION_ITEMS", function()
		gg.clearResults()
		gg.searchNumber(expansionItemPointer, gg.TYPE_QWORD, false, gg.SIGN_EQUAL, 0, -1, 0)
		if gg.getResultsCount() == 0 then
			return false
		end

		local results = gg.getResults(gg.getResultsCount())
		gg.clearResults()

		local toGet = {}
		for i = 1, 15 do
			if not results[i] then
				return false
			end
			toGet[i] = {
				address = results[i].address + CONSTANTS.OFFSETS.ITEM_DATA_PTR,
				flags = gg.TYPE_QWORD,
			}
		end
		local toGetExpansion = gg.getValues(toGet)
		if not toGetExpansion or #toGetExpansion < 15 then
			return false
		end

		local toGet0x8 = {}
		for i = 1, 15 do
			toGet0x8[i] = {
				address = toGetExpansion[i].value + CONSTANTS.OFFSETS.EXPANSION_ID_8,
				flags = gg.TYPE_QWORD,
			}
		end
		local toGetExpansion0x8 = gg.getValues(toGet0x8)

		local toGet0x10 = {}
		for i = 1, 15 do
			toGet0x10[i] = {
				address = toGetExpansion[i].value + CONSTANTS.OFFSETS.EXPANSION_ID_10,
				flags = gg.TYPE_QWORD,
			}
		end
		local toGetExpansion0x10 = gg.getValues(toGet0x10)

		local successCount = 0
		for i = 1, 15 do
			if toGetExpansion0x8[i].value == 8316866899155576172 then -- dozer wheel
				expansionItems[1] = results[i].address
				successCount = successCount + 1
			elseif toGetExpansion0x8[i].value == 8243124913282442604 then -- exhaust
				expansionItems[2] = results[i].address
				successCount = successCount + 1
			elseif toGetExpansion0x8[i].value == 7017581717894423916 then -- dozer blade
				expansionItems[3] = results[i].address
				successCount = successCount + 1
			elseif toGetExpansion0x8[i].value == 8243122654398080364 then -- storage lock
				expansionItems[4] = results[i].address
				successCount = successCount + 1
			elseif toGetExpansion0x8[i].value == 7449366535721674092 then -- storage bar
				expansionItems[5] = results[i].address
				successCount = successCount + 1
			elseif toGetExpansion0x8[i].value == 8243126012945065324 then -- storage camera
				expansionItems[6] = results[i].address
				successCount = successCount + 1
			elseif toGetExpansion0x8[i].value == 7308613709769696620 then -- vu remote
				expansionItems[7] = results[i].address
				successCount = successCount + 1
			elseif toGetExpansion0x8[i].value == 28554769125565804 then --vu battery
				expansionItems[8] = results[i].address
				successCount = successCount + 1
			elseif toGetExpansion0x8[i].value == 8389187293518194028 then -- vu glove
				expansionItems[9] = results[i].address
				successCount = successCount + 1
			elseif toGetExpansion0x10[i].value == 215560907105 then --compass (mountain)
				expansionItems[10] = results[i].address
				successCount = successCount + 1
			elseif toGetExpansion0x10[i].value == 211265939809 then --snowboard (montain)
				expansionItems[11] = results[i].address
				successCount = successCount + 1
			elseif toGetExpansion0x10[i].value == 219855874401 then -- winter hat (mountain)
				expansionItems[12] = results[i].address
				successCount = successCount + 1
			elseif toGetExpansion0x10[i].value == 12848 then -- ship wheel (beach)
				expansionItems[13] = results[i].address
				successCount = successCount + 1
			elseif toGetExpansion0x10[i].value == 12592 then -- lifebelt (beach)
				expansionItems[14] = results[i].address
				successCount = successCount + 1
			elseif toGetExpansion0x10[i].value == 13104 then --  scuba mask (beach)
				expansionItems[15] = results[i].address
				successCount = successCount + 1
			else
				-- Check failures printed in original code
			end
		end
		return successCount >= 15
	end)
end

local function findOMEGA() --finds warItems
	local OMEGAPointer = RootPointer[1].address + CONSTANTS.OFFSETS.OMEGA_ITEMS_PTR
	MemoryOptimizer.findWorkingRegion("OMEGA_ITEMS", function()
		gg.clearResults()
		gg.searchNumber(OMEGAPointer, gg.TYPE_QWORD, false, gg.SIGN_EQUAL, 0, -1, 0)
		local count = gg.getResultsCount()
		if count == 0 then
			return false
		end

		local results = gg.getResults(count)
		gg.clearResults()

		local toGet = {}
		for i = 1, 10 do
			if not results[i] then
				return false
			end
			toGet[i] = {
				address = results[i].address + CONSTANTS.OFFSETS.ITEM_DATA_PTR,
				flags = gg.TYPE_QWORD,
			}
		end
		local toGetOMEGA = gg.getValues(toGet)
		if not toGetOMEGA or #toGetOMEGA < 10 then
			return false
		end

		local toGetTwo = {}
		for i = 1, 10 do
			toGetTwo[i] = {
				address = toGetOMEGA[i].value,
				flags = gg.TYPE_DWORD,
			}
		end
		local toGetOMEGA2 = gg.getValues(toGetTwo)
		--printTableSimple(toGetOMEGA2) --DEBUG

		local successCount = 0
		for i = 1, 10 do
			if toGetOMEGA2[i].value == 1651462670 then --Robopet =
				futureOMEGAItems[1] = results[i].address
				successCount = successCount + 1
			elseif toGetOMEGA2[i].value == 1346647058 then --4-D Printer =
				futureOMEGAItems[2] = results[i].address
				successCount = successCount + 1
			elseif toGetOMEGA2[i].value == 1953382688 then --Antigravity Boots =
				futureOMEGAItems[3] = results[i].address
				successCount = successCount + 1
			elseif toGetOMEGA2[i].value == 2037531426 then --Cryofusion Chamber =
				futureOMEGAItems[4] = results[i].address
				successCount = successCount + 1
			elseif toGetOMEGA2[i].value == 1819232282 then --Holoprojector =
				futureOMEGAItems[5] = results[i].address
				successCount = successCount + 1
			elseif toGetOMEGA2[i].value == 1987004436 then --Hoverboard =
				futureOMEGAItems[6] = results[i].address
				successCount = successCount + 1
			elseif toGetOMEGA2[i].value == 1952795150 then --Jet Pack =
				futureOMEGAItems[7] = results[i].address
				successCount = successCount + 1
			elseif toGetOMEGA2[i].value == 1953256730 then --Ultrawave Oven =
				futureOMEGAItems[8] = results[i].address
				successCount = successCount + 1
			elseif toGetOMEGA2[i].value == 1818579982 then --Telepod =
				futureOMEGAItems[9] = results[i].address
				successCount = successCount + 1
			elseif toGetOMEGA2[i].value == 1819235094 then --Solar Panels =
				futureOMEGAItems[10] = results[i].address
				successCount = successCount + 1
			else
				-- Check error
			end
		end
		return successCount >= 10
	end)
end

local function findTokens() --finds Token Addresess
	local certPointer = RootPointer[1].address + CONSTANTS.OFFSETS.CERTS_PTR
	local tokenPointer = RootPointer[1].address + CONSTANTS.OFFSETS.TOKENS_PTR

	MemoryOptimizer.findWorkingRegion("TOKENS", function()
		gg.clearResults()
		gg.searchNumber(certPointer, gg.TYPE_QWORD, false, gg.SIGN_EQUAL, 0, -1, 0)
		local certCount = gg.getResultsCount() --3 results expected
		if certCount == 0 then
			return false
		end
		local certs = gg.getResults(certCount)

		gg.clearResults()
		gg.searchNumber(tokenPointer, gg.TYPE_QWORD, false, gg.SIGN_EQUAL, 0, -1, 0)
		local tokenCount = gg.getResultsCount() --6 results expected
		if tokenCount == 0 then
			return false
		end
		local tokens = gg.getResults(tokenCount)

		gg.clearResults()
		local certsAndTokensPrep = {}
		for _, certItem in ipairs(certs) do
			table.insert(certsAndTokensPrep, certItem)
		end
		for _, tokenItem in ipairs(tokens) do
			table.insert(certsAndTokensPrep, tokenItem)
		end

		if #certsAndTokensPrep == 0 then
			return false
		end

		local toGet = {}
		for i = 1, #certsAndTokensPrep do
			toGet[i] = {
				address = certsAndTokensPrep[i].address + CONSTANTS.OFFSETS.ITEM_DATA_PTR,
				flags = gg.TYPE_QWORD,
			}
		end

		local certAndTokenNamePtr = gg.getValues(toGet)
		if not certAndTokenNamePtr or #certAndTokenNamePtr < #certsAndTokensPrep then
			return false
		end

		local toGet2 = {}
		for i = 1, #certAndTokenNamePtr do
			toGet2[i] = {
				address = certAndTokenNamePtr[i].value + CONSTANTS.OFFSETS.CERT_TOKEN_NAME,
				flags = gg.TYPE_QWORD,
			}
		end
		local certAndTokenNames = gg.getValues(toGet2)
		--printTableSimple(certAndTokenNames)

		local successCount = 0
		local totalItems = #certs + #tokens
		-- Ensure we process all items
		for i = 1, totalItems do
			if certAndTokenNames[i].value == 7521962890172982635 then --cert beach
				certsAndTokens[1] = certsAndTokensPrep[i].address
				successCount = successCount + 1
			elseif certAndTokenNames[i].value == 8389772276738712939 then --cert mountain
				certsAndTokens[2] = certsAndTokensPrep[i].address
				successCount = successCount + 1
			elseif certAndTokenNames[i].value == 34186467633685867 then --cert city
				certsAndTokens[3] = certsAndTokensPrep[i].address
				successCount = successCount + 1
			elseif certAndTokenNames[i].value == 516241193330 then --Fac 2x
				certsAndTokens[4] = certsAndTokensPrep[i].address
				successCount = successCount + 1
			elseif certAndTokenNames[i].value == 516274747762 then --fac 4x
				certsAndTokens[5] = certsAndTokensPrep[i].address
				successCount = successCount + 1
			elseif certAndTokenNames[i].value == 132156972038514 then --fac 12x
				certsAndTokens[6] = certsAndTokensPrep[i].address
				successCount = successCount + 1
			elseif certAndTokenNames[i].value == 8026370369911324773 then --Turtle
				certsAndTokens[7] = certsAndTokensPrep[i].address
				successCount = successCount + 1
			elseif certAndTokenNames[i].value == 0 then --Llama
				certsAndTokens[8] = certsAndTokensPrep[i].address
				successCount = successCount + 1
			elseif certAndTokenNames[i].value == 26721 then --Cheetah
				certsAndTokens[9] = certsAndTokensPrep[i].address
				successCount = successCount + 1
			else
				-- gg.alert(getText("alert_something_aint_right"))
			end
		end
		-- We ideally want to find all 9 known items.
		-- The original code scanned for 3 certs + 6 tokens = 9 items.
		return successCount >= 9
	end)
end

local function findWarCards() --find Warcard Offer addresses
	local warCardPointer = RootPointer[1].address + CONSTANTS.OFFSETS.WAR_CARDS_PTR --offset the rootpointer to find warCardPointer Pointer V52

	MemoryOptimizer.findWorkingRegion("WAR_CARDS", function()
		gg.clearResults()
		gg.searchNumber(warCardPointer, gg.TYPE_QWORD, false, gg.SIGN_EQUAL, 0, -1, 0)
		local count = gg.getResultsCount() --19 results originally
		if count == 0 then
			return false
		end

		local results = gg.getResults(count)
		gg.clearResults()

		local toGet = {}
		for i = 1, #results do
			toGet[i] = {
				address = results[i].address + CONSTANTS.OFFSETS.ITEM_DATA_PTR,
				flags = gg.TYPE_QWORD,
			}
		end
		local buffer = gg.getValues(toGet)
		if not buffer or #buffer < #results then
			return false
		end

		local toGet2 = {}
		for i = 1, #results do
			toGet2[i] = {
				address = buffer[i].value,
				flags = gg.TYPE_QWORD,
			}
		end
		local warcardNames = gg.getValues(toGet2)

		local successCount = 0
		for i = 1, #warcardNames do
			if warcardNames[i].value == 4858943563757470494 then --Common QWORD
				warCards[1] = results[i].address
				successCount = successCount + 1
			elseif warcardNames[i].value == 8241942896054456858 then --Rare QWORD
				warCards[2] = results[i].address
				successCount = successCount + 1
			elseif warcardNames[i].value == 7017855501155519524 then --Legendary QWORD
				warCards[3] = results[i].address
				successCount = successCount + 1
			end
		end
		--print("WARCARD NAMES")
		--printTableSimple(warcardNames)

		-- Originally it found 3 specific cards.
		return successCount >= 3
	end)
end

local function searchAll()
	if not SEARCH_EVERYTHING then
		return
	end

	gg.toast("Pre-searching all items...")

	-- Prepare time/production data
	prepareProduction()

	-- Find all item lists
	findGenericItems()
	if DEBUG then
		findItemListLegacy()
	end
	wereItemsFound = 1

	findWarItemList()
	wasWarFound = 1

	findExpansion()
	expansionWasFound = 1

	findOMEGA()
	OMEGAWasFound = 1

	findTokens()
	wereCertsFound = 1

	findWarCards()
	wereWarcardsFound = 1

	gg.toast("All items pre-searched!")
end

--==========================================================
--    REPLACE FUNCTIONS
--==========================================================
--[=[
local function replaceItems(positions) --to be added
  local toSet = {}
  for i = 1, 11 do
    toSet[i] = {
      address = factoryItems[i].address,
      flags = gg.TYPE_DWORD,
      value = itemList[positions[i]].value 
      }
  end
  gg.setValues(toSet)
end 
local function replaceMetal(index) --to be added
end 
--]=]
local function replaceWarItems() --self explanatory, doest replace medkit
	if wasWarFound == nil then
		wasWarFound = 1
		gg.toast(getText("toast_loading_war_items"))
		findWarItemList()
	end

	local toSet = {}
	for i = 1, 11 do
		toSet[i] = {
			address = factoryItems[i].address,
			flags = gg.TYPE_QWORD,
			value = warItems[i],
		}
	end
	gg.setValues(toSet)
	menuChoices[2] = getText("menu_war_items") .. " " .. getText("status_enabled")
end

local function revertFactory()
	local toSet = {}
	for i = 1, 11 do
		toSet[i] = {
			address = factoryItems[i].address,
			flags = gg.TYPE_QWORD,
			value = factoryItems[i].value, -- Assuming factoryItems stores original values or is re-fetched
		}
	end
	gg.setValues(toSet)
	menuChoices[11] = getText("menu_revert_to_default") .. " " .. getText("status_active")
end

local function replaceAirport() --replaces all of the airport items
	if wereItemsFound == nil then
		wereItemsFound = 1
		gg.toast(getText("toast_loading_general_items"))
		findGenericItems()
	end

	local toSet = {}
	local positions = { 69, 70, 71, 72, 73, 74, 75, 76, 77, 10, 11 }
	for i = 1, 11 do
		toSet[i] = {
			address = factoryItems[i].address,
			flags = gg.TYPE_QWORD,
			value = itemList[positions[i]].value,
		}
	end
	gg.setValues(toSet)
	menuChoices[6] = getText("menu_airport_items") .. " " .. getText("status_enabled")
end

local function replaceRegional(preset) --replaces all of the regional items
	if wereItemsFound == nil then
		gg.toast(getText("toast_loading_general_items"))
		findGenericItems()
		wereItemsFound = 1
	end

	local status_key
	local positions = {}
	if preset == 1 then
		positions = { 82, 83, 84, 85 }
		status_key = "status_regional_cactus"
	elseif preset == 2 then
		positions = { 78, 79, 80, 81 }
		status_key = "status_regional_green_valley"
	elseif preset == 3 then
		positions = { 94, 95, 96, 97 }
		status_key = "status_regional_limestone"
	elseif preset == 4 then
		positions = { 86, 87, 88, 89 }
		status_key = "status_regional_sunny_isles"
	elseif preset == 5 then
		positions = { 90, 91, 92, 93 }
		status_key = "status_regional_frosty_fjords"
	end
	menuChoices[4] = getText("menu_regional_items") .. " " .. getText(status_key)
	local toSet = {}
	for i = 1, #positions do
		toSet[i] = {
			address = factoryItems[i].address,
			flags = gg.TYPE_QWORD,
			value = itemList[positions[i]].value,
		}
	end
	for i = #positions + 1, 11 do
		toSet[i] = {
			address = factoryItems[i].address,
			flags = gg.TYPE_QWORD,
			value = factoryItems[i].value,
		}
	end
	gg.setValues(toSet)
end

local function replaceExpansion() --replaces all expansion and VU items (no beach expansion and missing one mountain expansion item)
	if expansionWasFound == nil then
		expansionWasFound = 1
		gg.toast(getText("toast_loading_expansion_items"))
		findExpansion()
	end

	local toSet = {}
	for i = 1, 11 do
		toSet[i] = {
			address = factoryItems[i].address,
			flags = gg.TYPE_QWORD,
			value = expansionItems[i],
		}
	end
	gg.setValues(toSet)
	menuChoices[1] = getText("menu_vu_expansion") .. " " .. getText("status_enabled")
end

local function replaceWarItemsPresets(preset) --replaces war items for a specific card (if your factory doesnt have all items unlocked)
	if wasWarFound == nil then
		wasWarFound = 1
		gg.toast(getText("toast_loading_war_items"))
		findWarItemList()
	end
	local indexes = {}
	if preset == 1 then --Comic Hand
		indexes = { 11, 9 }
	elseif preset == 2 then --Shrink Ray
		indexes = { 8, 5 }
	elseif preset == 3 then --Giant Rock Monster
		indexes = { 2, 10 }
	elseif preset == 4 then --Not in Kansas
		indexes = { 3, 4 }
	elseif preset == 5 then --Magnetism
		indexes = { 10, 2, 3 }
	elseif preset == 6 then --Tentacle Vortex
		indexes = { 11, 9, 4 }
	elseif preset == 7 then --Flying Vu Robot
		indexes = { 1, 6 }
	elseif preset == 8 then --Disco Twister
		indexes = { 5, 8, 4 }
	elseif preset == 9 then --Plant Monster
		indexes = { 11, 6, 7 }
	elseif preset == 10 then --Blizzaster
		indexes = { 4, 1, 9 }
	elseif preset == 11 then --Fishaster
		indexes = { 9, 7, 2 }
	elseif preset == 12 then --Ancient Curse
		indexes = { 7, 5, 10 }
	elseif preset == 13 then --Hands of Doom
		indexes = { 1, 9, 8 }
	elseif preset == 14 then --16 Tons
		indexes = { 8, 2, 3 }
	elseif preset == 15 then --Spiders
		indexes = { 6, 10, 1 }
	elseif preset == 16 then --Dance Shoes
		indexes = { 6, 10, 7 }
	elseif preset == 17 then --Building Portal
		indexes = { 2, 11, 4 }
	elseif preset == 18 then --B Movie Monster
		indexes = { 7, 11, 5 }
	elseif preset == 19 then --Hissy Fit
		indexes = { 10, 8, 7 }
	elseif preset == 20 then --Mellow Bellow DUCKY SKIPPED
		indexes = { 5, 8, 4 }
	elseif preset == 21 then --Doomsday Quack
		if wereItemsFound == nil then
			findGenericItems()
			wereItemsFound = 1
		end
		local toSet = {}
		toSet[1] = {
			address = factoryItems[1].address,
			flags = gg.TYPE_QWORD,
			value = warItems[9],
		}
		toSet[2] = {
			address = factoryItems[2].address,
			flags = gg.TYPE_QWORD,
			value = itemList[46].value,
		}
		for i = 3, 11 do
			toSet[i] = {
				address = factoryItems[i].address,
				flags = gg.TYPE_QWORD,
				value = factoryItems[i].value,
			}
		end
		gg.setValues(toSet)
		return 1
	elseif preset == 22 then --Electric Deity
		indexes = { 5, 6, 3 }
	elseif preset == 23 then --Shield Buster
		indexes = { 6, 12 }
	elseif preset == 24 then --Zest from Above
		indexes = { 10, 3, 1 }
	end
	local toSet = {}
	for i = 1, #indexes do
		toSet[i] = {
			address = factoryItems[i].address,
			flags = gg.TYPE_QWORD,
			value = warItems[indexes[i]],
		}
	end
	for i = #indexes + 1, 11 do
		toSet[i] = {
			address = factoryItems[i].address,
			flags = gg.TYPE_QWORD,
			value = factoryItems[i].value,
		}
	end
	gg.setValues(toSet)
	menuChoices[10] = getText("menu_war_items_presets") .. " " .. getText("status_war_preset", warcardsMenu[preset])
end

local function replaceItemsThatDidntFit() --replaces items that didnt fit into other categories
	if wasWarFound == nil then
		wasWarFound = 1
		gg.toast(getText("toast_loading_war_items"))
		findWarItemList()
	end
	if expansionWasFound == nil then
		expansionWasFound = 1
		gg.toast(getText("toast_loading_expansion_items"))
		findExpansion()
	end
	local toSet = {}
	for i = 12, 15 do
		toSet[i - 11] = {
			address = factoryItems[i - 11].address,
			flags = gg.TYPE_QWORD,
			value = expansionItems[i],
		}
	end
	toSet[5] = {
		address = factoryItems[5].address,
		flags = gg.TYPE_QWORD,
		value = warItems[12],
	}
	for i = 6, 11 do
		toSet[i] = {
			address = factoryItems[i].address,
			flags = gg.TYPE_QWORD,
			value = factoryItems[i].value,
		}
	end
	gg.setValues(toSet)
	menuChoices[8] = getText("menu_items_that_didnt_fit") .. " " .. getText("status_enabled")
end

local function replaceOMEGA()
	if OMEGAWasFound == nil then
		OMEGAWasFound = 1
		gg.toast(getText("toast_loading_omega_items"))
		findOMEGA()
	end

	local toSet = {}
	for i = 1, 10 do
		toSet[i] = {
			address = factoryItems[i].address,
			flags = gg.TYPE_QWORD,
			value = futureOMEGAItems[i],
		}
	end
	toSet[11] = {
		address = factoryItems[11].address,
		flags = gg.TYPE_QWORD,
		value = factoryItems[11].value,
	}
	gg.setValues(toSet)
	menuChoices[3] = getText("menu_omega_items") .. " " .. getText("status_enabled")
end

local function replaceCertsAndTokens()
	if wereCertsFound == nil then
		wereCertsFound = 1
		gg.toast(getText("toast_loading_certs_and_tokens"))
		findTokens()
	end

	local toSet = {}
	for i = 1, #certsAndTokens do
		toSet[i] = {
			address = factoryItems[i].address,
			flags = gg.TYPE_QWORD,
			value = certsAndTokens[i],
		}
	end
	for i = #certsAndTokens + 1, 11 do
		toSet[i] = {
			address = factoryItems[i].address,
			flags = gg.TYPE_QWORD,
			value = factoryItems[i].value,
		}
	end
	gg.setValues(toSet)
	menuChoices[9] = getText("menu_speedup_tokens") .. " " .. getText("status_enabled")
end

local function replaceTrain() --replaces all of the airport items
	if wereItemsFound == nil then
		wereItemsFound = 1
		gg.toast(getText("toast_loading_general_items"))
		findGenericItems()
	end

	local toSet = {}
	local positions = { 123, 124, 125, 126 }
	for i = 1, #positions do
		toSet[i] = {
			address = factoryItems[i].address,
			flags = gg.TYPE_QWORD,
			value = itemList[positions[i]].value,
		}
	end
	for i = #positions + 1, 11 do
		toSet[i] = {
			address = factoryItems[i].address,
			flags = gg.TYPE_QWORD,
			value = factoryItems[i].value,
		}
	end
	gg.setValues(toSet)
	menuChoices[5] = getText("menu_railroad_items") .. " " .. getText("status_enabled")
end

local function replaceChristmas() --Christmas Items
	if wereItemsFound == nil then
		gg.toast(getText("toast_loading_general_items"))
		findGenericItems()
		wereItemsFound = 1
	end

	local toSet = {}
	local positions = { 12, 25, 33, 45, 57, 99, 100, 101, 102 }
	for i = 1, #positions do
		toSet[i] = {
			address = factoryItems[i].address,
			flags = gg.TYPE_QWORD,
			value = itemList[positions[i]].value,
		}
	end
	for i = #positions + 1, 11 do
		toSet[i] = {
			address = factoryItems[i].address,
			flags = gg.TYPE_QWORD,
			value = factoryItems[i].value,
		}
	end
	gg.setValues(toSet)
	menuChoices[7] = getText("menu_christmas_items") .. " " .. getText("status_enabled")
end

local function replaceWarCards()
	if wereWarcardsFound == nil then
		wereWarcardsFound = 1
		gg.toast(getText("toast_loading_warcards"))
		findWarCards()
	end

	--print("WARCARD ADDRESS")
	--printTableSimple(warCards)
	local toSet = {}
	for i = 1, 3 do
		toSet[i] = {
			address = factoryItems[i].address,
			flags = gg.TYPE_QWORD,
			value = warCards[i],
		}
	end
	for i = 4, 11 do
		toSet[i] = {
			address = factoryItems[i].address,
			flags = gg.TYPE_QWORD,
			value = factoryItems[i].value,
		}
	end
	gg.setValues(toSet)
	menuChoices[12] = getText("menu_warcards") .. " " .. getText("status_enabled")
end

local function replaceFactoryWithXP()
	prepareProduction()
	revertFactory()
	gg.setVisible(true)
	while true do
		if gg.isVisible() == false then
			gg.sleep(300)
		else
			local choiceTable = {
				[1] = getText("xp_menu_edit_xp_amount", (tonumber(xpValueTable[1].value) or 0)),
				[2] = getText("xp_menu_back_to_main"),
			}

			local intent = gg.choice(choiceTable, nil, getText("prompt_enter_XP_ammount"))

			if intent == 1 then
				local inputTable = gg.prompt(
					{ getText("prompt_enter_XP_ammount") },
					{ tostring(xpValueTable[1].value) },
					{ "number" }
				)
				if not inputTable then
					-- User cancelled prompt, do nothing, loop continues (returns to menu)
				else
					local newVal = tonumber(inputTable[1], 10)
					if newVal then
						local proceed = true
						if newVal > 1500000 then
							local warning =
								gg.alert(getText("alert_high_xp_warning"), getText("alert_yes"), getText("alert_no"))
							if warning ~= 1 then
								proceed = false
							end
						end

						if proceed then
							local toSet = {}
							for i = 1, #xpValueTable do
								toSet[i] = {
									address = xpValueTable[i].address,
									flags = gg.TYPE_DWORD,
									value = newVal,
								}
							end
							gg.setValues(toSet)

							-- Update local table values
							for i = 1, #xpValueTable do
								xpValueTable[i].value = newVal
							end
							gg.toast(string.format(getText("alert_xp_set"), newVal))
						end
					end
				end
			elseif intent == 2 then
				-- Revert to 0
				local toSet = {}
				for i = 1, #xpValueTable do
					toSet[i] = {
						address = xpValueTable[i].address,
						flags = gg.TYPE_DWORD,
						value = 0,
					}
				end
				gg.setValues(toSet)
				-- Update local table values
				for i = 1, #xpValueTable do
					xpValueTable[i].value = 0
				end
				gg.toast(getText("toast_reverted"))
				return -- BREAK LOOP and return to main menu
			elseif intent == nil then
				-- User cancelled the choice menu (tapped outside)
				-- Hide UI and wait for them to open GG again
				gg.setVisible(false)
			end
		end
	end
end

--=========================================================
--            MENU FUNCTIONS
--==========================================================
local function mainMenu()
	while 1 do
		if gg.isVisible() == false then
			gg.sleep(400)
		else
			-- Re-initialize menuChoices here to reflect status changes from other functions
			initializeMenus()
			local selectedIndex = gg.choice(menuChoices, nil, getText("menu_choose_option"))
			if selectedIndex ~= nil then
				-- No need to reset menuChoices to constant here, initializeMenus handles it
				-- And specific functions update their respective menu item's text
			end
			if selectedIndex == 1 then
				safeSetVisible(false)
				replaceExpansion()
				gg.toast(getText("toast_done"))
				return 1
			elseif selectedIndex == 2 then
				safeSetVisible(false)
				replaceWarItems()
				gg.toast(getText("toast_done"))
				return 1
			elseif selectedIndex == 3 then
				safeSetVisible(false)
				replaceOMEGA()
				gg.toast(getText("toast_done"))
				return 1
			elseif selectedIndex == 4 then
				local index = gg.choice(regionalItemsMenu, nil, getText("menu_choose_option_cancel_abort"))
				if index ~= nil then
					safeSetVisible(false)
					replaceRegional(index)
					gg.toast(getText("toast_done"))
					return 1
				end
			elseif selectedIndex == 5 then
				safeSetVisible(false)
				replaceTrain()
				gg.toast(getText("toast_done"))
				return 1
			elseif selectedIndex == 6 then
				safeSetVisible(false)
				replaceAirport()
				gg.toast(getText("toast_done"))
				return 1
			elseif selectedIndex == 7 then
				safeSetVisible(false)
				replaceChristmas()
				gg.toast(getText("toast_done"))
				return 1
			elseif selectedIndex == 8 then
				safeSetVisible(false)
				replaceItemsThatDidntFit()
				gg.toast(getText("toast_done"))
				return 1
			elseif selectedIndex == 9 then
				safeSetVisible(false)
				gg.alert(getText("alert_certs_tokens_simcash_info"))
				editTime(60000)
				replaceCertsAndTokens()
				gg.toast(getText("toast_done"))
				return 1
			elseif selectedIndex == 10 then
				safeSetVisible(false)
				replaceFactoryWithXP()
				gg.toast(getText("toast_done"))
				return 1
			elseif selectedIndex == 11 then -- War Items Presets
				local index = gg.choice(warcardsMenu, nil, getText("menu_choose_option_cancel_abort"))
				if index ~= nil then
					safeSetVisible(false)
					replaceWarItemsPresets(index)
					gg.toast(getText("toast_done"))
					return 1
				end
			elseif selectedIndex == 12 then -- Revert
				safeSetVisible(false)
				revertFactory()
				gg.toast(getText("toast_reverted"))
				return 1
			elseif selectedIndex == 13 then -- Warcards
				safeSetVisible(false)
				gg.alert(getText("alert_warcards_simcash_info"))
				editTime(60000)
				replaceWarCards()
				return 1
			elseif selectedIndex == 14 then -- System Settings
				settingType = 1
				return 1
			elseif selectedIndex == 15 then -- Exit
				os.exit()
			elseif selectedIndex == nil then
				gg.setVisible(false)
				return 1
			end
		end
	end
end
local function systemSettings()
	while 1 do --system settings
		if gg.isVisible() == false then
			gg.sleep(400)
		else
			initializeMenus() -- Ensure timeMenuChoices is up-to-date with statuses
			local selectedIndex = gg.choice(timeMenuChoices, nil, getText("menu_choose_what_you_need_proceed"))
			if selectedIndex == 1 then
				safeSetVisible(false)
				editTime()
				safeSetVisible(true)
			elseif selectedIndex == 2 then
				safeSetVisible(false)
				editMult()
				safeSetVisible(true)
			elseif selectedIndex == 3 then
				safeSetVisible(false)
				excludeProdLvl()
				safeSetVisible(true)
			elseif selectedIndex == 4 then
				settingType = 2
				return 1
			elseif selectedIndex == nil then
				gg.setVisible(false)
				return 1
			end
		end
	end
end
local function itemToolMenu()
	if settingType == 1 then
		systemSettings()
	elseif settingType == 2 then
		mainMenu()
	end
end
local function setup()
	-- Try to load config
	local configLoaded = ConfigManager.load()

	-- If DEBUG is on and config exists, ask user what to do
	if DEBUG and configLoaded then
		local choice = gg.alert(
			"DEBUG: Config File Found!\n\n" .. ConfigManager.serialize(CONFIG_DATA),
			"Continue",
			"Delete & Rescan",
			"Cancel"
		)
		if choice == 2 then
			os.remove(CONFIG_FILE)
			CONFIG_DATA = { regions = {} }
			gg.toast("Config deleted! Rescanning...")
		elseif choice == 3 then
			os.exit()
		end
	end

	setLanguage() -- Call this first to set up language and initialize menus

	-- Check if optimization is needed (config empty or missing key regions)
	-- We can just check if regions table is empty as a heuristic for "First Run"
	local isFirstRun = true
	if CONFIG_DATA.regions and next(CONFIG_DATA.regions) then
		isFirstRun = false
	end

	if isFirstRun then
		gg.alert(getText("alert_optimization_warning"))
	end
	searchRootPointer()

	if DEBUG then
		findGenericItems()
	end

	gg.toast(getText("toast_loading_factory_items"))
	safeSetVisible(false)
	findFactory()

	if isFirstRun or SEARCH_EVERYTHING then
		-- On first run, we force a scan of everything to populate the optimization config
		-- Otherwise, we obey the user's SEARCH_EVERYTHING preference
		-- But we need to make sure searchAll doesn't return early if SEARCH_EVERYTHING is false but isFirstRun is true
		-- A simple way is to temporarily set SEARCH_EVERYTHING true or modify searchAll
		-- Modifying the call logic here is safer:

		-- Actually, searchAll has a guard "if not SEARCH_EVERYTHING then return end".
		-- We should call the functions directly or set the flag.
		local oldFlag = SEARCH_EVERYTHING
		SEARCH_EVERYTHING = true
		searchAll()
		SEARCH_EVERYTHING = oldFlag
	end

	debugOffsets() -- Run validation AFTER everything is found/optimized
	safeSetVisible(true)
	-- initializeMenus() -- Now called within setLanguage or after it if user cancels
end
--==========================================================
--        main code calling the functions
--==========================================================

setup()

while 1 do -- loops between menues, recursion wouldnt work lmao
	itemToolMenu()
end
