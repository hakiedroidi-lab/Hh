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
RewardsAddress = {}

local resourcesData = {
	{ id = "simoleons", name = "🪙 Simoleons", prefix = "Simoleons:", amounts = { 100000, 5000000, 20000000 } },
	{ id = "simcash", name = "💵 SimCash", prefix = "Simcash:", amounts = { 1000, 10000, 48000 } },
	{ id = "neosimoleons", name = "🌐 Neosimoleons", prefix = "Neosims:", amounts = { 100000, 5000000, 20000000 } },
	{ id = "golden_keys", name = "🔑 Golden Keys", prefix = "Keys:", amounts = { 10, 100, 500 } },
	{ id = "platinum_keys", name = "🗝️ Platinum Keys", prefix = "Platinum:", amounts = { 10, 100, 500 } },
	{ id = "war_simoleons", name = "⚔️ War Simoleons", prefix = "warsims:", amounts = { 1000, 10000, 50000 } },
	{ id = "blueprints", name = "📘 Blueprints", prefix = "Blueprints:", amounts = { 100, 1000, 5000 } },
	{ id = "golden_ticket", name = "🎫 Golden Ticket", prefix = "GoldenTicket:", amounts = { 100, 5000, 50000 } },
}
RewardsReqValue = {}
gg.showUiButton()
gg.setVisible(false)

WasUnlocked = nil
local function findRewards()
	gg.setRanges(gg.REGION_C_ALLOC | gg.REGION_OTHER | gg.REGION_ANONYMOUS)
	gg.clearResults()
	gg.searchNumber("1952541776", gg.TYPE_DWORD, false, gg.SIGN_EQUAL, 0, -1, 0)
	local resuts = gg.getResults(gg.getResultsCount())
	gg.clearResults()
	local toGet = {}
	for i = 1, #resuts do
		toGet[i] = {
			address = resuts[i].address + 0x14,
			flags = gg.TYPE_DWORD,
		}
	end
	local offsetValue = gg.getValues(toGet)
	for i = 1, #offsetValue do
		if offsetValue[i].value == 980706667 then
			RewardsAddress[#RewardsAddress + 1] = offsetValue[i].address - 0x14
		end
	end
	if #RewardsAddress ~= 6 then
		gg.alert("something aint right")
	end
	local toAdd = {}
	for i = 1, #RewardsAddress do
		local newItem = {
			address = RewardsAddress[i],
			flags = gg.TYPE_DWORD,
			name = tostring(i),
		}
		table.insert(toAdd, newItem)
	end
	gg.addListItems(toAdd)
end

local function findRewardReq()
	local correctPtr = nil
	gg.clearResults()
	gg.searchNumber("1027500", gg.TYPE_DWORD, false, gg.SIGN_EQUAL, 0, -1, 0)
	local results = gg.getResults(gg.getResultsCount())
	gg.clearResults()
	local toGet = {}
	for i = 1, #results do
		toGet[i] = {
			address = results[i].address + 0x8,
			flags = gg.TYPE_QWORD,
		}
	end
	local ptrCheck = gg.getValues(toGet)
	local toGet = {}
	for i = 1, #ptrCheck do
		toGet[i] = {
			address = ptrCheck[i].value,
			flags = gg.TYPE_DWORD,
		}
	end
	local ptrCheck2 = gg.getValues(toGet)
	for i = 1, #ptrCheck2 do
		if ptrCheck2[i].value == 33 then
			correctPtr = ptrCheck[i].value
		end
	end
	gg.searchNumber(correctPtr, gg.TYPE_QWORD, false, gg.SIGN_EQUAL, 0, -1, 0)
	local results = gg.getResults(gg.getResultsCount())
	local toGet = {}
	for i = 1, #results do
		toGet[i] = {
			address = results[i].address - 0x4,
			flags = gg.TYPE_DWORD,
		}
	end
	local buffer = gg.getValues(toGet)
	for i = #results, 1, -1 do -- find the list of req pointers
		if buffer[i].value == 0 then
			table.remove(results, i)
		end
	end
	local toGet = {}
	for i = 1, 6 do
		toGet[i] = {
			address = results[1].address + (i - 1) * 8,
			flags = gg.TYPE_QWORD,
		}
	end
	local rewardReqTable = {}
	local ptrsToSearch = gg.getValues(toGet)
	--print("PTRS TO SEARCH:")
	--printTableSimple(ptrsToSearch)
	for i = 1, 6 do
		gg.clearResults()
		gg.searchNumber(ptrsToSearch[i].value, gg.TYPE_QWORD, false, gg.SIGN_EQUAL, 0, -1, 0)
		local results = gg.getResults(gg.getResultsCount())
		for j = #results, 1, -1 do
			if results[j].address == ptrsToSearch[i].address then
				table.remove(results, j)
			end
		end
		for l = 1, #results do
			rewardReqTable[#rewardReqTable + 1] = results[l].address - 0x8
		end
	end
	--print("UNSORTED COUNT = " .. #rewardReqTable)
	gg.clearResults()
	local function compareByValue(a, b)
		return a.value < b.value
	end
	local toGet = {}
	for i = 1, #rewardReqTable do
		toGet[i] = {
			address = rewardReqTable[i],
			flags = gg.TYPE_DWORD,
		}
	end
	RewardsReqValue = gg.getValues(toGet)
	table.sort(RewardsReqValue, compareByValue)
	--print("SORTED COUNT = " .. #RewardsReqValue)
	--printTableSimple(RewardsReqValue)
end

local function replaceRewardSmart(resourceIndex, amountIndex)
	local function textToBytes(text)
		local bytes = {}
		if string.len(text) > 28 then
			return false
		end

		for i = 1, string.len(text) do
			local byte_value = string.byte(text, i)
			table.insert(bytes, byte_value)
		end
		for i = #bytes + 1, 28 do
			bytes[i] = 0
		end

		return bytes
	end

	local resource = resourcesData[resourceIndex]
	local amount = 0

	if amountIndex == #resource.amounts + 1 then -- Custom amount
		local amountBuffer = gg.prompt({ "Enter amount" }, { "0" }, { "number" })
		if amountBuffer == nil then
			return 0
		end
		amount = tonumber(amountBuffer[1])
	else
		amount = resource.amounts[amountIndex]
	end

	local text = resource.prefix .. tostring(amount)

	local bytes = textToBytes(text)

	if bytes == false then
		gg.alert("String too long, choose a smaller reward amount")
		print(text)
		return 0
	end
	--printTableSimple(bytes)
	for i = 1, #RewardsAddress do
		local toSet = {}
		for j = 1, 28 do
			toSet[j] = {
				address = RewardsAddress[i] + (j - 1),
				flags = gg.TYPE_BYTE,
				value = bytes[j],
			}
		end
		gg.setValues(toSet)
	end
end

local function unlockAll()
	if WasUnlocked == nil then
		WasUnlocked = 1
		local toSet = {}
		for i = 1, #RewardsReqValue do
			toSet[i] = {
				address = RewardsReqValue[i].address,
				flags = gg.TYPE_DWORD,
				value = 0,
			}
		end
		gg.setValues(toSet)
	else
		WasUnlocked = nil
		local toSet = {}
		for i = 1, #RewardsReqValue do
			toSet[i] = {
				address = RewardsReqValue[i].address,
				flags = gg.TYPE_DWORD,
				value = RewardsReqValue[i].value,
			}
		end
		gg.setValues(toSet)
	end
end

local mainMenuTable = {
	[1] = "Unlock/Lock All rewards",
	[2] = "Unlock the next 1 reward (currently at level 1)",
	[3] = "Edit Reward type/ammount",
}
local currentReward = 0

local function unlockNext()
	if WasUnlocked == 1 then
		WasUnlocked = nil
		local toSet = {}
		for i = 1, #RewardsReqValue do
			toSet[i] = {
				address = RewardsReqValue[i].address,
				flags = gg.TYPE_DWORD,
				value = RewardsReqValue[i].value,
			}
		end
		gg.setValues(toSet)
		gg.alert("you had all rewards unlocked, they are locked now")
	end
	currentReward = currentReward + 1
	mainMenuTable[2] = "Unlock the next 1 reward (currently at level" .. tostring(currentReward + 1) .. ")"
	local toSet = {}
	toSet[1] = {
		address = RewardsReqValue[currentReward].address,
		flags = gg.TYPE_DWORD,
		value = 0,
	}
	gg.setValues(toSet)
	return currentReward
end

findRewards()
findRewardReq()

local menuType = 1

local function mainMenu()
	local selectedIndex = gg.choice(mainMenuTable, nil, "Choose what you need.")
	if selectedIndex == nil then
		return 0
	elseif selectedIndex == 1 then
		unlockAll()
	elseif selectedIndex == 2 then
		unlockNext()
	elseif selectedIndex == 3 then
		menuType = 2
	end
end

local function resourceMenu()
	menuType = 1

	local menuOptions = {}
	for i, res in ipairs(resourcesData) do
		table.insert(menuOptions, res.name)
	end

	local resourceIndex = gg.choice(menuOptions, nil, "Choose an option.")
	if resourceIndex == nil then
		return 0
	end

	local resource = resourcesData[resourceIndex]
	local amountOptions = {}
	for i, amt in ipairs(resource.amounts) do
		-- Simple number formatting could be added here if needed
		table.insert(amountOptions, tostring(amt))
	end
	table.insert(amountOptions, "Custom")

	local amountIndex = gg.choice(amountOptions, nil, "Choose resource amount (limits apply)")

	if amountIndex == nil then
		return 0
	end

	replaceRewardSmart(resourceIndex, amountIndex)
end

while 1 do
	if gg.isClickedUiButton() then
		if menuType == 1 then
			mainMenu()
		end
		if menuType == 2 then
			resourceMenu()
		end
	else
		gg.sleep(400)
	end
end
