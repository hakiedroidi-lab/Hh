current_version = '4.4.0'
gg.showUiButton()
--===========================================================
--      common
--===========================================================
pi = math.pi 
rad2deg = 180.0/pi 
deg2rad = pi/180 

RootOffsets = {
	mainitems = -0x148,
	buildingpopulation = -0xa8,
	expansionitems = 0x648,
	expansioncerts = 0x6e8,
	omegaitems = 0x788,
	waritems = 0x8c8,
	roads = 0x1638,
	speedtokens = 0x16d8,
	warcards = 0x1db8,
}

menus = {}

uiOpen = false
menus['menuLoop'] = function(mn)
	while true do gg.sleep(30)
		if gg.isClickedUiButton() then
			uiOpen = true
		end
		if uiOpen then
			if menus[mn]() then
				return
			end
		end
	end
end

main_menu_options = {'Mayor Pass','Vu Pass','Item Tool','Factory Settings','Building Tool','Move Buildings','Change Population','No Item Requirement for War Cards','War Card Free Upgrades','EZ Sell','Complete Contest Assignments','Get Boosters from Factory','Change Road Prices','Get Design Sims','Max Storage','Clear Storage','Check for Updates','Exit (reverts factory so the script wont get messed up if you run it again)'}
menus['mainMenu'] = function()
	local index = gg.choice(main_menu_options)
	if index == nil then
		uiOpen = false
	elseif index == #main_menu_options then
		revert()
		revertReplacedMenuBuilding()
		return true
	else
		if menus[main_menu_options[index] ] then
			menus['menuLoop'](main_menu_options[index])
		end
	end
end

function nToString(n)
	local bytes = {}
	for i = 0, 7, 1 do
		local byte = (n >> (i * 8)) & 0xFF
		if (byte >= 0x30 and byte <= 0x39) or (byte >= 0x41 and byte <= 0x5a) or (byte >= 0x61 and byte <= 0x7a) or byte == 0x5f then
			table.insert(bytes, byte)
		end
	end
	return string.char(table.unpack(bytes))
end

function tonumber16safer(s)
	if #s > 15 then
		return (tonumber(string.sub(s,#s-15,#s-14),16) << 56) | tonumber(string.sub(s,#s-13),16)
	end
	return tonumber(s,16)
end

function yesNoPrompt(question)
    if gg.choice({'Yes','No'}, nil, question) == 1 then
        return true
    end
    return false
end

function bytemask(n)
    local bits = 0
    while n ~= 0 do
        bits = bits + 8
        n = n >> 8
    end
    return (1 << bits) - 1
end

cache_autocheckupdate_path = '/storage/emulated/0/SCB_autocheckupdate.cache'
cached_ranges_path = '/storage/emulated/0/SCB_ranges.cache'

download_url = 'https://gameguardian.net/forum/files/file/4265-simcity-buildit-megascript'
download_cookie = {['Cookie'] = 'ips4_IPSSessionFront=1'}
script_path =  '/storage/emulated/0/Download/SCB_megascript'
menus['Check for Updates'] = function()
	local response = gg.makeRequest(download_url,download_cookie).content
	local _,version_t = response:find('versionTitle')
	local latest_version = response:sub(response:find('>',version_t)+1,response:find('<',version_t)-1)
	local release_notes = ''
	local _,n1 = response:find("\\u003Cp\\u003E\\n\\t")
	if n1 then
		release_notes = '\n\nlatest release notes:\n' .. response:sub(n1+1,response:find('\\n\\u003C',n1)-1)
	end
	local cache_autocheckupdate = io.open(cache_autocheckupdate_path, "r")  
	local cachedchoice = 'OFF'
	if cache_autocheckupdate then
		cachedchoice = cache_autocheckupdate:read("*a")
		cache_autocheckupdate:close()
	end
	local index = gg.choice({'download latest version','copy download link',string.format('auto check for updates when script opens (%s)',cachedchoice)},nil,'latest version: '.. latest_version .. '\ncurrent version: ' .. current_version .. release_notes) 
	if index == 2 then
		gg.copyText(download_url)
		return true
	elseif index == 1 then
		local d1,d2 = response:find(download_url .. '/?do=download',nil,true)
		if d1 then
			local d3 = response:find('csrf',d2)
			local d4 = response:find('\'',d3)
			local c = gg.makeRequest(response:sub(d1,d2) .. '&' .. response:sub(d3,d4-1),download_cookie)
			if c.code ~= 200 then
				gg.alert('error: ' .. c.code .. '\n something broke')
			else 
				local path = gg.prompt({'Path to script\ncant be the same as the current file'},{script_path .. latest_version .. '.lua'},{'text'})
				if path then
					local file = io.open(path[1], "w")
					if file then
						file:write(c.content)
						file:close()
						gg.toast('script updated')
						revert()
						revertReplacedMenuBuilding()
						load(c.content)()
						os.exit()
					else
						gg.toast('invalid path')
					end
				end
			end
		else
			gg.alert('error: something wrong')
		end
		return true
	elseif index == 3 then 
		local cache = io.open(cache_autocheckupdate_path,'w')
		cache:write(cachedchoice == "ON" and "OFF" or "ON")
		cache:close()	
	else
		return true
	end
end

function split(inputString, separator)
    local result = {}
    local pattern = "([^" .. separator .. "]+)"
    for part in string.gmatch(inputString, pattern) do
        table.insert(result, part)
    end
    return result
end

function versionGreater(v1,v2)
	v1 = split(v1,'.')
	v2 = split(v2,'.')
	if #v1 > #v2 then
		for i = #v2+1,#v1 do 
			v2[i]=0
		end
	elseif #v2 > #v1 then
		for i = #v1+1,#v2 do 
			v1[i]=0
		end
	end 
	for i,v in ipairs(v1) do 
		if tonumber(v) > tonumber(v2[i]) then
			return true
		elseif tonumber(v) < tonumber(v2[i]) then
			return false
		end 
	end 
end

function readString(addrs,discard_if_invalid,max_length)
	local l = gg.getValues({{address = addrs, flags = 1}})[1].value 
	local check = gg.getValues({{address = addrs + 1, flags = 1}})[1].value 
	local bytes = {}
	if l <= 46 and l >= 0 and check ~= 0 then 
		l = l / 2 
		for i = 1,l do 
			table.insert(bytes,{address = addrs + i, flags = 1})
		end
	else 
		l = gg.getValues({{address = addrs, flags = 4}})[1].value 
		if l < 0 then return end
		if l > (max_length or 100) then return end
		local addrs2 = gg.getValues({{address = addrs + 0x10, flags = 32}})[1].value 
		for i = 0,l-1 do 
			table.insert(bytes,{address = addrs2 + i, flags = 1})
		end
	end
	bytes = gg.getValues(bytes)
	local bytes2 = {}
	for i,v in ipairs(bytes) do
		if v.value <= 0 then 
			if discard_if_invalid then return else break end
		end
		table.insert(bytes2,v.value)
	end
	if #bytes2 == 0 then return end
	return string.char(table.unpack(bytes2))
end

--===========================================================factory items
RootPointer = nil
factory_item_ids = {-1501685376 , -1477359097 ,-389414878 ,-331876130 ,-777869928 ,809598022 ,-545412710 ,-2052593169 ,-254286722 ,-610175295 ,-585905379}
FactoryItems = {}
function findRoot()
    gg.toast('finding root...')
    gg.clearResults()
    gg.searchNumber(factory_item_ids[1], gg.TYPE_DWORD, false, gg.SIGN_EQUAL, 0, -1, 1)
	FactoryItems[1]={address = gg.getResults(1)[1].address + 0x1c, flags=32}
	RootPointer = 0x148 + gg.getValues({{address = gg.getValues({{address = FactoryItems[1].address, flags=32}})[1].value, flags = 32}})[1].value
	gg.addListItems({{address=RootPointer,flags=32,name='Base Pointer'}})
end

factory_found = false
function findFactory()
    gg.setVisible(false)
    if not RootPointer then
        findRoot()
    end
	for i = 2,11 do
		gg.toast(string.format('finding factory items %i/11',i))
		gg.clearResults()
		gg.searchNumber(factory_item_ids[i], gg.TYPE_DWORD, false, gg.SIGN_EQUAL, 0, -1, 1)
		FactoryItems[i]={address = gg.getResults(1)[1].address + 0x1c, flags=32}
	end
    FactoryItems = gg.getValues(FactoryItems)
    factory_found = true
end


--===========================================================
--      vu and mayor pass
--===========================================================shared
rewards_menu = {'45000 cash, 450 keys, 150000000 sims','Disaster Cards','Train Cards','Currencies','Drops','Seasonal Currencies and Blueprints','Get Reward From Another Tier','Copy From Seasonal Currency Showcase','Custom','Limits','Go Back'}

vunote = "Note: claiming premium tiers multiple times can get you banned. It's best not to unlock premium if you wanna stay on the real server."

mayornote = "Note: claiming premium tiers multiple times can get you banned. It's best not to unlock premium if you wanna stay on the real server. Also unlocking premium might cause the game to crash so you may need to try several times."

currencies = {
	['Simoleons'] = {0x6F656C6F6D697312,0x736E},
	['Neosims'] = {0x736D69736F656E0E}, 
	['Warsims'] = {0x736D69737261770E},
	['Train Sims'] = {0x69736E6961727412,0x736D},
	['Simcash'] = {0x687361636D69730E},
	['Golden Keys'] = {0x7379656B08},
	['Platinum Keys'] = {0x756E6974616C7010,0x6D},
	['Random Regional'] = {0x616E6F696765721E,0x6D6F646E61725F6C},  
	['Storage Boost'] = {0x656761726F747318,0x74736F6F62}, 
	['Rail Tokens'] = {0x6B6F546C69615212,0x6E65} 
}
currency_choices = {'Simoleons','Neosims','Warsims','Train Sims','Simcash','Golden Keys','Platinum Keys','Random Regional','Storage Boost','Rail Tokens','Go Back'}

d_card = {0x657473617369642C,0x735F647261635F72,0x63696669636570}
disasters = {{0x6173694472615718,0x0000003172657473},{0x6173694472615718,0x0000003472657473},{0x6173694472615718,0x0000003572657473},{0x6173694472615718,0x0000003672657473},{0x6173694472615718,0x0000003772657473},{0x6173694472615718,0x0000003872657473},{0x6173694472615718,0x0000003972657473},{0x617369447261571A,0x0000303172657473},{0x617369447261571A,0x0000313172657473},{0x617369447261571A,0x0000323172657473},{0x617369447261571A,0x0000343172657473},{0x617369447261571A,0x0000353172657473},{0x617369447261571A,0x0000363172657473},{0x617369447261571A,0x0000383172657473},{0x617369447261571A,0x0000393172657473},{0x617369447261571A,0x0000313272657473},{0x617369447261571A,0x0000323272657473},{0x617369447261571A,0x0000353272657473},{0x617369447261571A,0x0000363272657473},{0x617369447261571A,0x0000373272657473},{0x617369447261571A,0x0000383272657473},{0x617369447261571A,0x0000393272657473},{0x617369447261571A,0x0000303372657473},{0x617369447261571A,0x0000313372657473}}
disaster_names = {'Hand','Shrink Ray','Tornado','Tentacle','Magnet','Ice Storm','Doom Hands','Disco Twister','Plant Monster','Shoes','Dead Fish','Sandstorm','16 Tons','Portal','Spiders','VU Robot','Cthulhu','Stone Golem','Rubber Ducks','Zeus','Anaconda','Horn','Shield Buster','Lemon Squeezer'}

trains = {
	['Flying Sim'] = {0x53676E69796C4624,0x436E616D73746F63,0x647261},
	['Llama Line 350'] = {0x6C4365666E655222,0x6143303533737361,0x6472},
	['LM Grade 23'] = {0x7261433031424410,0x64},
	['Magnificent Mayor'] = {0x684372657075531C,0x64726143666569},
	['Northwest Railways'] = {0x72656874756F5326,0x636966696361506E,0x64726143},
	['Quill Railroad OP1'] = {0x647261433147470E},
	['SC Line 9001'] = {0x7373616C43534E16,0x64726143},
	['Sim Rail Grade 00'] = {0x687369746972422C,0x73616C436C696152,0x64726143333473},
	['Simeo Plus B'] = {0x6C506F6572694D1C,0x64726143427375},
	['E5 Super Sim'] = {0x656972655335452C,0x6E616B6E69685373,0x647261436E6573},
}
train_choices = {'All Cards','Flying Sim','Llama Line 350','LM Grade 23','Magnificent Mayor','Northwest Railways','Quill Railroad OP1','SC Line 9001','Sim Rail Grade 00','Simeo Plus B','E5 Super Sim','Go Back'}

limits = '--24h limits for new accounts:--\nsims and neosims: 18000000\nsimcash: 48000\nkeys: 500 each\ndisaster cards: 150 at a time\nOn accounts less than 90 days old, you can only upgrade cards to lvl 7. On older accounts you need have less than 300 cards to upgrade past lvl 7, and you need to restart the game at least every 6 levels.\nregional: 45000 at a time(can freeze and claim a bunch of times)\nwarsims: 30000 at a time\ntrain cards and rail tokens: no limit, but u only need 660 cards and 1203 tokens to max.\nseasonal currency,train sims, and buildings: no limit\nstorage: probably 400\nboosters: 5 at a time from pass, cant have more than 150\nalso cant have too many factories or shops without getting banned'

reward_preset_names = {'land expansions','mountain expansions','beach expansions','golden ticket','factory slot'}

reward_presets = {
	['land expansions'] = {{0x6D65746908},{0x69736E6170784524,0x436E656B6F546E6F,0x797469}},
	['mountain expansions'] = {{0x6D65746908},{0x69736E617078452C,0x4D6E656B6F546E6F,0x6E6961746E756F}},
	['beach expansions'] = {{0x6D65746908},{0x69736E6170784526,0x426E656B6F546E6F,0x68636165}},
	['golden ticket'] = {{0x6D65746908},{0x546E65646C6F4718,0x74656B6369}},
	['factory slot'] = {{0x6D65746908},{0x79726F7463616618,0x746F6C735F}},
}

function changeReward(tier_add,typE,spec,q)
	local toset = {}
	local reward_add = gg.getValues({{address = tier_add - 16,flags=32},{address = tier_add - 8,flags=32}})
	if type(typE) == 'table' then
		for i = 1,(math.min(#typE,4)) do
			table.insert(toset,{address = reward_add[1].value + (i-1)*8 , flags=32 , value = typE[i]})
		end
	end
	if type(spec) == 'table' then
		for i = 1,(math.min(#spec,4)) do
			table.insert(toset,{address = reward_add[2].value + (i-1)*8 , flags=32 , value = spec[i]})
		end
	end
	table.insert(toset,{address = reward_add[1].address + 16 , flags=4 , value = q})
	table.insert(toset,{address = reward_add[1].address + 0x48, flags=4 , value = 0})
	gg.setValues(toset)
	gg.toast('reward changed')
end

function getRewardName(add)
	local f_add = gg.getValues({{address = add - 16,flags=32},{address = add - 8,flags=32}})
	local type = {}
	local spec = {}
	for i = 0,3 do
		table.insert(type,{address = f_add[1].value + 8*i,flags=32})
		table.insert(spec,{address = f_add[2].value + 8*i,flags=32})
	end
	type = gg.getValues(type)
	spec = gg.getValues(spec)
	local type_val = {}
	local spec_val = {}
	for i = 1,4 do
		type_val[i] = type[i].value
		spec_val[i] = spec[i].value
	end
	return type_val, spec_val
end

seasonal_showcase_lists = {}
s_sh_args = {11000,5000,5000}
active_s_sh_list = 1
chosen_s_sh_item = 2
function copyFromSeasonalCurrencyShowcase()
	local step = 1
	while true do gg.sleep(30)
		if gg.isClickedUiButton() then
			uiOpen = true
		end
		if uiOpen then
			if step == 1 then
				local step1_options = {'Find Showcase','Choose Item','Go Back'}
				local index = gg.choice(step1_options,nil,'')
				if index == nil then
					uiOpen = false
				elseif step1_options[index] == 'Go Back' then
					return
				elseif step1_options[index] == 'Choose Item' then
					if seasonal_showcase_lists[1] then
						step = 3
					else
						gg.alert('You need to find the showcase first.')
					end
				else
					step = 2
				end
			elseif step == 2 then
				local index = gg.choice({'1st: ' .. s_sh_args[1],'2nd: ' .. s_sh_args[2],'3rd: ' .. s_sh_args[3],'Search','Go Back'},nil,'Enter the quantities of the first 4 items')
				if index == nil then
					uiOpen = false
				elseif index == 5 then
					step = 1
				elseif index == 4 then
					seasonal_showcase_lists = {}
					gg.clearResults()
					gg.searchNumber(s_sh_args[1],gg.TYPE_DWORD)
					local results = gg.getResults(-1)
					local check = {}
					for i,v in ipairs(results) do 
						check[i*2-1] = {address = v.address + 0x60,flags = 4}
						check[i*2] = {address = v.address + 0xc0,flags = 4}
					end 
					check = gg.getValues(check)
					for i,v in ipairs(results) do 
						if check[i*2-1].value == s_sh_args[2] and check[i*2] == s_sh_args[3] then 
							table.insert(seasonal_showcase_lists,v)
							if #seasonal_showcase_lists >9 then 
								break 
							end 
						end 
					end
					if not seasonal_showcase_lists[1] then
						gg.toast('nothing found')
					else 
						gg.toast(#seasonal_showcase_lists .. ' lists saved')
						step = 3
					end
				else 
					local q = gg.prompt({index},{s_sh_args[index]},{'number'})
					if q and #q[1] ~= 0 then
						s_sh_args[index] = q[1]
					end
				end
			elseif step == 3 then
				local item = gg.prompt({'Which item to get?(1=1st,2=2nd,etc)'},{chosen_s_sh_item},{'number'})
				if item and #item[1] ~= 0 then
					chosen_s_sh_item = item[1]
					step = 4
				else
					step = 1
				end
			elseif step == 4 then
				local step4_option = {'yes','change item index (' .. chosen_s_sh_item .. ')','change list (' .. active_s_sh_list .. ')','Go Back'}
				local index = gg.choice(step4_option,nil,'Is this the right quantity for this item?(if its not, you can go forward 1 or try a different list)\n' .. gg.getValues({{address = seasonal_showcase_lists[active_s_sh_list].address + 0x60 * (chosen_s_sh_item-1),flags=4}})[1].value)
				if index == nil then
					uiOpen = false
				elseif index == 2 then
					step = 3
				elseif index == 3 then
					local lists = {}
					for i = 1,#seasonal_showcase_lists do
						table.insert(lists,i)
					end
					local list = gg.choice(lists)
					if list then
						active_s_sh_list = list
					end
				elseif index == 4 then
					step = 1
				else
					return getRewardName(seasonal_showcase_lists[active_s_sh_list].address + 0x60 * (chosen_s_sh_item-1))
				end
			end
		end
	end
end

type_hex = {0x6C62617466696722,0x69646C6975625F65,0x676E,0}
spec_hex = {0x5F48435F35365522,0x776F545F68746F47,0x7265,0}
function customReward()
	local page = 1
	local function enterName(name)
		local index = gg.choice({'1: '..nToString(name[1]),'2: '..nToString(name[2]),'3: '..nToString(name[3]),'4: '..nToString(name[4]),'Back'},nil,'Paste the name of the item as QWORD hex values.')
		if index == nil then
			uiOpen = false
		elseif index == 5 then
			page = 1
		else
			local hex = gg.prompt({''},{string.format('%X',name[index])},{'number'})
			if hex and #hex[1] ~= 0 then
				name[index] = tonumber16safer(hex[1])
			end
		end
	end
	while true do gg.sleep(30)
		if gg.isClickedUiButton() then
			uiOpen = true
		end
		if uiOpen then
			if page == 1 then
				local index = gg.choice({'type: '..nToString(type_hex[1])..nToString(type_hex[2])..nToString(type_hex[3])..nToString(type_hex[4]),'specification: '..nToString(spec_hex[1])..nToString(spec_hex[2])..nToString(spec_hex[3])..nToString(spec_hex[4]),'Proceed','presets','Go Back'},nil,'Custom Reward')
				if index == nil then
					uiOpen = false
				elseif index == 5 then
					return
				elseif index == 4 then
					local choice = gg.choice(reward_preset_names)
					if choice then
						local reward_name = reward_presets[ reward_preset_names[choice] ]
						for i = 1,#reward_name[1] do
							type_hex[i] = reward_name[1][i]
						end
						for i = 1,#reward_name[2] do
							spec_hex[i] = reward_name[2][i]
						end
					end
				elseif index == 3 then
					return type_hex, spec_hex
				else
					page = index + 1
				end
			elseif page == 2 then
				enterName(type_hex)
			elseif page == 3 then
				enterName(spec_hex)
			end
		end
	end
end

function changeAllRewards(start,typE,spec,len,q,use_premium)
	local name_addresses = {}
	local toset = {}
	local q_table = type(q) == 'table'
	local tier_addresses = {}
	if use_premium then
		for i = 1,len do
			tier_addresses[i] = start + 0xa0*((i-1)//2) + ((i % 2 == 1) and 0 or 0x28)
			if (i % 2 == 1) then 
				table.insert(toset,{address = tier_addresses[i] + 0x38, flags=4 , value = 0})
				table.insert(toset,{address = tier_addresses[i] + 0x50, flags=4 , value = 0})
			end 
		end
	else 
		for i = 1,len do
			tier_addresses[i] = start + 0xa0*(i-1)
			table.insert(toset,{address = tier_addresses[i] + 0x38, flags=4 , value = 0})
		end 
	end
	for i = 1,len do
		table.insert(name_addresses,{address = tier_addresses[i] - 16 , flags=32})
		table.insert(name_addresses,{address = tier_addresses[i] - 8 , flags=32})
		table.insert(toset,{address = tier_addresses[i], flags=4 , value = (q_table and q[i] or q)})
	end
	name_addresses = gg.getValues(name_addresses)
	if type(typE[1]) == 'table' then
		for i = 1,len do
			for j = 1,#typE[i] do
				table.insert(toset,{address = name_addresses[2*i-1].value+8*(j-1),flags=32,value=typE[i][j]})
			end
		end
	else
		for i = 1,len do
			for j = 1,#typE do
				table.insert(toset,{address = name_addresses[2*i-1].value+8*(j-1),flags=32,value=typE[j]})
			end
		end
	end
	if type(spec[1]) == 'table' then
		for i = 1,len do
			for j = 1,#spec[i] do
				table.insert(toset,{address = name_addresses[2*i].value+8*(j-1),flags=32,value=spec[i][j]})
			end
		end
	else
		for i = 1,len do
			for j = 1,#spec do
				table.insert(toset,{address = name_addresses[2*i].value+8*(j-1),flags=32,value=spec[j]})
			end
		end
	end
	gg.setValues(toset)
	gg.toast('rewards changed')
end

disaster_card_choices = {}
function getDisasterCards(mode)
	if disaster_card_choices[1] == nil then
		table.insert(disaster_card_choices,'All Cards')
		for i = 1,#disaster_names do
			table.insert(disaster_card_choices,disaster_names[i])
		end
		table.insert(disaster_card_choices,'Go Back')
	end
	while true do gg.sleep(30)
		if gg.isClickedUiButton() then
			uiOpen = true
		end
		if uiOpen then
			local index = gg.choice(disaster_card_choices)
			if index == nil then
					uiOpen = false
			elseif index == 1 then
				local start_add = nil
				if mode == 'Vu' then
					local lvl = gg.choice(found_lvls,nil,'dont pick 1')
					if lvl then
						start_add = VP_add[lvl]
					end
				else
					start_add = MP_add
				end
				if start_add then
					local q = gg.prompt({'quantity'},{150},{'number'})
					if q and #q[1] ~= 0 then
						changeAllRewards(start_add,d_card,disasters,#disasters,q[1])
					end
				end
			elseif disaster_card_choices[index] == 'Go Back' then
				return
			else
				if mode == 'Vu' then
					vuChangeReward(d_card,disasters[index-1])
				else
					mayorChangeReward(d_card,disasters[index-1])
				end
			end
		end
	end
end

function getTrains(mode)
	while true do gg.sleep(30)
		if gg.isClickedUiButton() then
			uiOpen = true
		end
		if uiOpen then
			local index = gg.choice(train_choices)
			if not index then
					uiOpen = false
			elseif index == 1 then
				local train_cards = {}
				for i,v in pairs(trains) do
					table.insert(train_cards,v)
				end
				local start_add = nil
				if mode == 'Vu' then
					local lvl = gg.choice(found_lvls,nil,'choose level')
					if lvl then
						start_add = VP_add[lvl]
					end
				else
					start_add = MP_add
				end
				if start_add then
					local q = gg.prompt({'quantity'},{660},{'number'})
					if q and #q[1] ~= 0 then
						changeAllRewards(start_add,train_cards,{0},#train_cards,q[1])
					end
				end
			elseif train_choices[index] == 'Go Back' then
				return
			else
				if mode == 'Vu' then
					vuChangeReward(trains[ train_choices[index] ],0)
				else
					mayorChangeReward(trains[ train_choices[index] ],0)
				end
			end
		end
	end
end

function getCurrencies(mode)
	while true do gg.sleep(30)
		if gg.isClickedUiButton() then
			uiOpen = true
		end
		if uiOpen then
			local index = gg.choice(currency_choices)
			if index == nil then
					uiOpen = false
			elseif currency_choices[index] == 'Go Back' then
				return
			else
				if mode == 'Vu' then
					vuChangeReward(currencies[ currency_choices[index] ],0)
				else
					mayorChangeReward(currencies[ currency_choices[index] ],0)
				end
			end
		end
	end
end

function rewardPreset1(mode)
	local names = {'Simcash','Golden Keys','Platinum Keys','Simoleons','Neosims'}
	local typE = {}
	for i,v in ipairs(names) do
		table.insert(typE,currencies[v])
	end
	local start_add = nil
	if mode == 'Vu' then
		local lvl = gg.choice(found_lvls,nil,'choose level')
		if lvl then
			start_add = VP_add[lvl]
		end
	else
		start_add = MP_add
	end
	if start_add then
		changeAllRewards(start_add,typE,{0},5,{45000,450,450,15000000,15000000})
	end
end

seasonal_currencies = {}
seas_cur_menu = {'All'}
function getSeasonalCur(mode)
	local campaign_cur = {0x676961706D616320,0x636E65727275636E,0x79}
	if not seasonal_currencies[1] then 
		local seen_map = {}
		local seen_addresses = {}
		gg.clearResults()
		gg.searchNumber(campaign_cur[1],32)
		local results = gg.getResults(-1)
		for i,v in ipairs(results) do 
			results[i].address = v.address + 0x20
		end 
		results = gg.getValues(results)
		for i,v in ipairs(results) do 
			if not seen_map[v.value] then 
				seen_map[v.value] = true 
				table.insert(seen_addresses,v.address)
			end
		end
		for i,v in ipairs(seen_addresses) do
			local name = readString(v,true)
			if name and not(name:find(' ')) and not(name:find('campaigncurrency')) then
				table.insert(seas_cur_menu,name)
				local toget = {}
				for i = 1,3 do
					toget[i] = {address = v + (i-1)*8, flags = 32}
				end 
				toget = gg.getValues(toget)
				for i,v in ipairs(toget) do
					toget[i] = v.value 
				end
				table.insert(seasonal_currencies,toget)
			end
		end
	end
	local index = gg.choice(seas_cur_menu,nil,"note: old seasonal currencies dont work\nblueprints is the one thats a number")
	if not index then return true end
	if index == 1 then
		local start_add = nil
		if mode == 'Vu' then
			local lvl = gg.choice(found_lvls,nil)
			if lvl then
				start_add = VP_add[lvl]
			end
		else
			start_add = MP_add
		end
		if start_add then
			local q = gg.prompt({'quantity'},{1000000000},{'number'})
			if q and #q[1] ~= 0 then
				changeAllRewards(start_add,campaign_cur,seasonal_currencies,#seasonal_currencies,q[1])
			end
		end
	else
		if mode == 'Vu' then
			vuChangeReward(campaign_cur,seasonal_currencies[index-1])
		else
			mayorChangeReward(campaign_cur,seasonal_currencies[index-1])
		end
	end
end

dropid = 145
alloc_page_mode = gg.PROT_NONE
function getDropAddrs()
	local index = gg.choice({'Alocate page (will crash after closing)','Write over game memory (might crash or might not work)'})
	if index == 2 then 
			gg.clearResults()
		gg.searchNumber('6F7270706F726416h',gg.TYPE_QWORD)
		local results = gg.getResults(-1)
		for i,v in pairs(results) do 
			results[i].address = v.address + 0x20 
		end
		results = gg.getValues(results)
		local id145 = {}
		for i,v in pairs(results) do
			if v.value == dropid then 
				table.insert(id145,v)
			end 
		end 
		if not id145[1] then 
			gg.toast('alert: drop finder might be broken') 
			for i,v in pairs(results) do
				if v.value > 0 and v.value < 5000 then 
					table.insert(id145,v)
				end 
			end
		end
		local r = math.random(1,#id145)
		return gg.getValues({{address=id145[r].address+16,flags=32}})[1].value
	end 
	return gg.allocatePage(alloc_page_mode)
end

function GenerateDropString(items,name)
	s = ';9999;\"' .. (name or '') .. '\";'
	for i,v in pairs(items) do 
		s = s .. string.format('/%s;1.0;%i;%i;%i;;0.0',i,v,v,v)
	end 
	return s 
end

function writeString(start,s)
	toset = {}
	for i,c in utf8.codes(s) do
		toset[i] = {address=start+i-1,flags=1,value=c}
	end
	gg.setValues(toset)
end

function dropChangeReward(mode,len,p)
	if mode == 'Vu' then
		vuChangeReward({0x6F7270706F726416,0x656C6966},{dropid,len,p})
		return
	end
	mayorChangeReward({0x6F7270706F726416,0x656C6966},{dropid,len,p})
end

dropMenus = {

['Currency'] = function(mode)
	local choices = {'Simoleons','Simcash','Golden Keys','Platinum Keys','Warsims'}
	local drop_curs = {'Simoleons','Simcash','Keys','Platinum','DarkSimoleons'}
	local input = gg.prompt(choices,{16000000,45000,450,450,0})
	if input then
		local drop_items = {}
		for i,v in pairs(input) do 
			drop_items[drop_curs[i] ] = v
		end 
		local s = GenerateDropString(drop_items,'Currencies')
		local drop_pointer = getDropAddrs()
		writeString(drop_pointer,s)
		dropChangeReward(mode,#s,drop_pointer)
	end 
end,
	
['Boosters'] = function(mode)
	local boosters = {
		'EnergyThiefLevel1',
		'EnergyThiefLevel2',
		'EnergyVampireLevel1',
		'EnergyVampireLevel2',
		'EnergyVampireLevel3',
		'BlockAttackLevel1',
		'BlockAttackLevel2',
		'BlockAttackLevel3',
		'EnergyPumpLevel1',
		'EnergyPumpLevel2',
		'EnergyPumpLevel3',
		'InstantShieldLevel1',
		'InstantShieldLevel2',
		'InstantShieldLevel3',
		'MinusPointsAnyLevel1',
		'MinusPointsAnyLevel2',
		'MinusPointsAnyLevel3',
		'BonusPointsAnyLevel1',
		'BonusPointsAnyLevel2',
		'BonusPointsAnyLevel3',
	}
	local chosen = gg.multiChoice(boosters)
	if chosen then 
		local q = gg.prompt({'quantity\nmax 5 at time, can freeze and spam click'},{'5'},{'number'})
		if q then 
			local drop_items = {}
			for i in pairs(chosen) do 
				drop_items[boosters[i] ] = q[1]
			end 
			local s = GenerateDropString(drop_items,'Boosters')
			local drop_pointer = getDropAddrs()
			writeString(drop_pointer,s)
			dropChangeReward(mode,#s,drop_pointer)
		end 
	end 
end,

['Custom/test'] = function(mode)
	local input = gg.prompt({'Enter Name','Quantity'},{'','1'},{'text','number'})
	if input then 
		local s = GenerateDropString({[input[1]]=input[2]},'Custom')
		local drop_pointer = getDropAddrs()
		writeString(drop_pointer,s)
		dropChangeReward(mode,#s,drop_pointer)
	end 
end,

['All Disaster Cards'] = function(mode)
	local warcards_drop = {
		'WarDisaster1',
		'WarDisaster4',
		'WarDisaster5',
		'WarDisaster6',
		'WarDisaster7',
		'WarDisaster8',
		'WarDisaster9',
		'WarDisaster10',
		'WarDisaster11',
		'WarDisaster12',
		'WarDisaster14',
		'WarDisaster15',
		'WarDisaster16',
		'WarDisaster18',
		'WarDisaster19',
		'WarDisaster21',
		'WarDisaster22',
		'WarDisaster25',
		'WarDisaster26',
		'WarDisaster27',
		'WarDisaster28',
		'WarDisaster29',
		'WarDisaster30',
		'WarDisaster31',
	}
	local q = gg.prompt({'quantity'},{'150'},{'number'})
	if q then 
		local drop_items = {}
		for _,v in ipairs(warcards_drop) do 
			drop_items[v] = q[1]
		end 
		local s = GenerateDropString(drop_items,'Disaster Cards')
		local drop_pointer = getDropAddrs()
		writeString(drop_pointer,s)
		dropChangeReward(mode,#s,drop_pointer)
	end 
end,
}

function dropMainMenu(mode)
	local drop_options = {'Currency','Boosters','All Disaster Cards','Custom/test'}
	local index = gg.choice(drop_options)
	if index and dropMenus[drop_options[index] ] then
		dropMenus[drop_options[index] ](mode)
	end 
end

--===========================================================vu
VP_menu = {'Find Vu Pass','Change Rewards(Vu)','Unlock Vu Pass','Re Unlock Vu Pass and Freeze','Unlock Premium','Go Back'}
menus['Vu Pass'] = function()
	local index = gg.choice(VP_menu,nil,vunote)
	if index == nil then
		uiOpen = false
	elseif VP_menu[index] == 'Go Back' then
		return true
	elseif VP_menu[index] == 'Unlock Vu Pass' then
		unlockVP()
	elseif VP_menu[index] == 'Re Unlock Vu Pass and Freeze' then
		reUnlockAndFreezeVP()
	elseif VP_menu[index] == 'Find Vu Pass' then
		findVP()
	elseif VP_menu[index] == 'Unlock Premium' then
		unlockPremiumVP()
	else
		menus['menuLoop'](VP_menu[index])
	end
end

VP_add = {}
VP_unlock_add = nil
VP_lvl1_pointer = nil
found_lvls = {}
vu_lvl_pointer_offsets = {0,0x18,0x30,0x48}
function findVP()
	gg.clearResults()
	gg.searchNumber(0x7373615072615712,32)
	if gg.getResultsCount() == 0 then gg.toast('no results, need to have the pass ui open') return end
	local results = gg.getResults(-1)
	for i,v in ipairs(results) do 
		results[i].address = v.address + 0x18
	end 
	results = gg.getValues(results)
	for i,v in ipairs(results) do 
		results[i].address = v.value
		results[i].flags = 4
	end 
	results = gg.getValues(results)
	local ui_pointer = nil
	for i,v in ipairs(results) do 
		if v.value ~= 0 then 
			ui_pointer = v.address
			break
		end 
	end
	if not ui_pointer then gg.toast('no pointer found, need to have the pass ui open') return end
	VP_lvl1_pointer = gg.getValues({{address = ui_pointer + 0x88,flags = 32}})[1].value
	local toget = {}
	for i = 1,#vu_lvl_pointer_offsets do 
		toget[i] = {address = VP_lvl1_pointer + vu_lvl_pointer_offsets[i], flags = 32}
	end 
	toget = gg.getValues(toget)
	for i,v in ipairs(toget) do 
		if v.value == 0 then gg.toast('error') return end
		VP_add[i] = v.value + 0x30
	end
	VP_unlock_add = ui_pointer + 0x180
	found_lvls = {1,2,3,4}
	gg.addListItems({{address = VP_lvl1_pointer,flags = 32, name = 'VP lvl 1 pointer'}})
	gg.toast('found vu pass')
end

menus['Change Rewards(Vu)'] = function()
	local VP_found = false
	for i in pairs(VP_add) do 
		VP_found = true
		break
	end
	if not VP_found then
		gg.alert('You need to find the Vu Pass first')
		return true
	end
	local index = gg.choice(rewards_menu)
	if index == nil then
		uiOpen = false
		gg.isVisible(false)
	elseif rewards_menu[index] == 'Go Back' then
		return true
	elseif rewards_menu[index] == 'Get Reward From Another Tier' then
		vuCopyReward()
	elseif rewards_menu[index] == 'Copy From Seasonal Currency Showcase' then
		vuChangeReward(copyFromSeasonalCurrencyShowcase())
	elseif rewards_menu[index] == 'Custom' then
		vuChangeReward(customReward())
	elseif rewards_menu[index] == 'Currencies' then
		getCurrencies('Vu')
	elseif rewards_menu[index] == 'Disaster Cards' then
		getDisasterCards('Vu')
	elseif rewards_menu[index] == 'Train Cards' then
		getTrains('Vu')
	elseif rewards_menu[index] == 'Limits' then
		gg.alert(limits)
	elseif rewards_menu[index] == '45000 cash, 450 keys, 150000000 sims' then
		rewardPreset1('Vu')
	elseif rewards_menu[index] == 'Drops' then
		dropMainMenu('Vu')
	elseif rewards_menu[index] == 'Seasonal Currencies and Blueprints' then
		getSeasonalCur('Vu')
	end
end

vu_copy_args = {1,1,1,1,1,100}
function vuCopyReward()
	local choices = {'from: level','from: tier','','to: level','to: tier','quantity:'}
	if found_lvls[ vu_copy_args[4] ] == nil then
		for i in pairs(VP_add) do
			vu_copy_args[4] = i
			vu_copy_args[1] = i
			break
		end
	end
	while true do gg.sleep(30)
		if gg.isVisible() then
			local index = gg.choice({string.format('%s %i',choices[1],vu_copy_args[1]),string.format('%s %i',choices[2],vu_copy_args[2]),vu_copy_args[3] == 1 and 'Premium' or 'Free',string.format('%s %i',choices[4],vu_copy_args[4]),string.format('%s %i',choices[5],vu_copy_args[5]),string.format('%s %i',choices[6],vu_copy_args[6]),'Change','Go Back'})
			if index == nil then
				gg.setVisible(false)
			elseif index == 7 then
				local typE,spec = getRewardName(VP_add[ vu_copy_args[1] ] + 0xa0 * (vu_copy_args[2]-1) + (vu_copy_args[3]==1 and 0x28 or 0) )
				changeReward(VP_add[ vu_copy_args[4] ] + 0xa0 * (vu_copy_args[5]-1) , typE,spec  , vu_copy_args[6])
				return
			elseif index == 8 then
				return
			elseif index == 1 or index == 4 then
				local lvl = gg.choice(found_lvls)
				if lvl then
					vu_copy_args[index] = lvl
				end
			elseif index == 3 then
				local prem = gg.choice({'Premium','Free'})
				if prem then
					vu_copy_args[index] = prem
				end
			else
				local tier = gg.prompt({choices[index]},{vu_copy_args[index]},{'number'})
				if tier and #tier[1] ~= 0 then
					vu_copy_args[index] = tier[1]
				end
			end
		end
	end
end

function vuChangeReward(typE,spec)
	if typE == nil and spec == nil then
		return
	end
	if found_lvls[ vu_copy_args[4] ] == nil then
		for i in pairs(VP_add) do
			vu_copy_args[4] = i
			vu_copy_args[1] = i
			break
		end
	end
	while true do gg.sleep(30)
		if gg.isVisible() then
			local index = gg.choice({'level: ' .. vu_copy_args[4],'tier: ' .. vu_copy_args[5],'quantity: ' .. vu_copy_args[6],'Change','Go Back'},nil,'pick tier and quantity')
			if index == nil then
				gg.setVisible(false)
			elseif index == 5 then
				return
			elseif index == 1 then
				local lvl = gg.choice(found_lvls)
				if lvl then
					vu_copy_args[index+3] = lvl
				end
			elseif index == 4 then
				changeReward(VP_add[ vu_copy_args[4] ] + 0xa0 * (vu_copy_args[5]-1),typE,spec,vu_copy_args[6])
				return
			else
				local tier = gg.prompt({''},{vu_copy_args[index+3]},{'number'})
				if tier and #tier[1] ~= 0 then
					vu_copy_args[index+3] = tier[1]
				end
			end
		end
	end
end

function unlockVP()
	if not VP_unlock_add then
		gg.alert('You need to find the Vu Pass first')
		return true
	end
	gg.setValues({{address=VP_unlock_add+0x28,flags=4,value=0}})
	gg.toast('Done!')
end

function unlockPremiumVP()
	if not VP_unlock_add then
		gg.alert('You need to find the Vu Pass first')
		return true
	end
	gg.setValues({{address=VP_unlock_add-0x158,flags=4,value=0}})
	gg.toast('Done!')
end

function reUnlockAndFreezeVP()
	if not VP_unlock_add then
		gg.alert('You need to find the Vu Pass first')
		return true
	end
	local toget = gg.getValues({{address = VP_unlock_add + 0x30,flags=32},{address = VP_unlock_add + 0x48,flags=32}})
	if toget[1].value ~= 0 then gg.addListItems({{address=toget[1].address+8,flags=32,value=toget[1].value,name='VP free tiers freeze',freeze=true}}) end
	if toget[2].value ~= 0 then gg.addListItems({{address=toget[2].address+8,flags=32,value=toget[2].value,name='VP premium tiers freeze',freeze=true}}) end
	gg.toast((toget[1].value ~= 0 and 'free tiers frozen | ' or 'free tiers not frozen because theres no rewards claimed | ') .. (toget[2].value ~= 0 and 'premium tiers frozen' or 'premium tiers not frozen because theres no rewards claimed'))
end	

--===========================================================mayor
MP_menu = {'Find Mayor Pass','Change Rewards(Mayor)','Unlock Mayor Pass','Re Unlock Mayor Pass and Freeze','Unlock Premium','Go Back'}
menus['Mayor Pass'] = function()
	local index = gg.choice(MP_menu,nil,mayornote)
	if index == nil then
		uiOpen = false
	elseif MP_menu[index] == 'Go Back' then
		return true
	elseif MP_menu[index] == 'Find Mayor Pass' then
		findMP()
	elseif MP_menu[index] == 'Unlock Mayor Pass' then
		unlockMP()
	elseif MP_menu[index] == 'Unlock Premium' then
		unlockPremiumMP()
	elseif MP_menu[index] == 'Re Unlock Mayor Pass and Freeze' then
		reUnlockAndFreezeMP()
	else
		menus['menuLoop'](MP_menu[index])
	end
end

MP_add = nil
MP_unlock_add = nil
function findMP()
	gg.clearResults()
	gg.searchNumber(0x55737361506E6F73,32)
	if gg.getResultsCount() == 0 then gg.toast('no results. try opening the pass ui') return end
	local results = gg.getResults(-1)
	for i,v in ipairs(results) do 
		results[i].address = v.address - 0x54
	end 
	results = gg.getValues(results)
	for i,v in ipairs(results) do 
		results[i].address = v.value
	end 
	results = gg.getValues(results)
	local check = {}
	for i,v in ipairs(results) do 
		check[i] = {address=v.value,flags=32}
	end 
	check = gg.getValues(check)
	for i,v in ipairs(check) do 
		check[i].address = v.value
	end 
	check = gg.getValues(check)
	local ui_pointer = nil
	for i,v in ipairs(check) do 
		if v.value ~= 0 then 
			ui_pointer = results[i].address 
			break
		end 
	end
	if not ui_pointer or ui_pointer == 0 then gg.toast('error. need to have the pass ui open') return end
	MP_add = gg.getValues({{address = ui_pointer + 0x58,flags = 32}})[1].value + 0x30
	MP_unlock_add = ui_pointer + 0x1a8
	gg.addListItems({{address=MP_add,flags=4,name='MP Start'}})
	gg.toast('found pass: ' .. (readString(ui_pointer + 0x168) or 'no name (pass not loaded)'))
end

menus['Change Rewards(Mayor)'] = function()
	if MP_add == nil then
		gg.alert('You need to find the Mayor Pass first')
		return true
	end
	local index = gg.choice(rewards_menu,nil,'You need to be in the contest menu when changing rewards')
	if index == nil then
		uiOpen = false
		gg.isVisible(false)
	elseif rewards_menu[index] == 'Go Back' then
		return true
	elseif rewards_menu[index] == 'Get Reward From Another Tier' then
		mayorCopyReward()
	elseif rewards_menu[index] == 'Copy From Seasonal Currency Showcase' then
		mayorChangeReward(copyFromSeasonalCurrencyShowcase())
	elseif rewards_menu[index] == 'Custom' then
		mayorChangeReward(customReward())
	elseif rewards_menu[index] == 'Currencies' then
		getCurrencies('Mayor')
	elseif rewards_menu[index] == 'Disaster Cards' then
		getDisasterCards('Maypr')
	elseif rewards_menu[index] == 'Train Cards' then
		getTrains('Mayor')
	elseif rewards_menu[index] == 'Limits' then
		gg.alert(limits)
	elseif rewards_menu[index] == '45000 cash, 450 keys, 150000000 sims' then
		rewardPreset1('Mayor')
	elseif rewards_menu[index] == 'Drops' then
		dropMainMenu('Mayor')
	elseif rewards_menu[index] == 'Seasonal Currencies and Blueprints' then
		getSeasonalCur('Mayor')
	end
end

mayor_copy_args = {1,1,1,100}
function mayorCopyReward()
	local choices = {'from: tier','','to: tier','quantity:'}
	while true do gg.sleep(30)
		if gg.isVisible() then
			local index = gg.choice({string.format('%s %i',choices[1],mayor_copy_args[1]),mayor_copy_args[2] == 1 and 'Premium' or 'Free',string.format('%s %i',choices[3],mayor_copy_args[3]),string.format('%s %i',choices[4],mayor_copy_args[4]),'Change','Go Back'})
			if index == nil then
				gg.setVisible(false)
			elseif index == 5 then
				local typE,spec = getRewardName(MP_add + 0xa0 * (mayor_copy_args[1]-1) + (mayor_copy_args[2]==1 and 0x28 or 0) )
				changeReward(MP_add + 0xa0 * (mayor_copy_args[3]-1) , typE,spec  , mayor_copy_args[4])
				return
			elseif index == 6 then
				return
			elseif index == 2 then
				local prem = gg.choice({'Premium','Free'})
				if prem then
					mayor_copy_args[index] = prem
				end
			else
				local tier = gg.prompt({choices[index]},{mayor_copy_args[index]},{'number'})
				if tier and #tier[1] ~= 0 then
					mayor_copy_args[index] = tier[1]
				end
			end
		end
	end
end

function mayorChangeReward(typE,spec)
	if typE == nil and spec == nil then
		return
	end
	while true do gg.sleep(30)
		if gg.isVisible() then
			local index = gg.choice({'tier: ' .. mayor_copy_args[3],'quantity: ' .. mayor_copy_args[4],'Change','Go Back'},nil,'pick tier and quantity')
			if index == nil then
				gg.setVisible(false)
			elseif index == 4 then
				return
			elseif index == 3 then
				changeReward(MP_add + 0xa0 * (mayor_copy_args[3]-1),typE,spec,mayor_copy_args[4])
				return
			else
				local tier = gg.prompt({''},{mayor_copy_args[index+2]},{'number'})
				if tier and #tier[1] ~= 0 then
					mayor_copy_args[index+2] = tier[1]
				end
			end
		end
	end
end

function unlockMP()
	if not MP_unlock_add then
		gg.alert('You need to find the Mayor Pass first')
		return true
	end
	gg.setValues({{address=MP_unlock_add,flags=4,value=0}})
	gg.toast('Done!')
end

function unlockPremiumMP()
	if not MP_unlock_add then
		gg.alert('You need to find the Mayor Pass first')
		return true
	end
	gg.addListItems({{address=MP_unlock_add-0x190,flags=4,value=0,name='Premium MP unlock',freeze=true}})
	gg.toast('Done!')
end

function reUnlockAndFreezeMP()
	if not MP_unlock_add then
		gg.alert('You need to find the Mayor Pass first')
		return true
	end
	local toget = gg.getValues({{address = MP_unlock_add + 8,flags=32},{address = MP_unlock_add + 0x20,flags=32}})
	if toget[1].value ~= 0 then gg.addListItems({{address=toget[1].address+8,flags=32,value=toget[1].value,name='MP free tiers freeze',freeze=true}}) end
	if toget[2].value ~= 0 then gg.addListItems({{address=toget[2].address+8,flags=32,value=toget[2].value,name='MP premium tiers freeze',freeze=true}}) end
	gg.toast((toget[1].value ~= 0 and 'free tiers frozen | ' or 'free tiers not frozen because theres no rewards claimed | ') .. (toget[2].value ~= 0 and 'premium tiers frozen' or 'premium tiers not frozen because theres no rewards claimed'))
end


--===========================================================
--      item tool and factory settings
--===========================================================find item functions
ItemListStart = nil 
ItemList = {} 
local function findItemList() 
    gg.toast('getting item list...')
    local function checkWood(address)
        local toGet = {{address = address + 0x8 , flags = gg.TYPE_QWORD}}
        local results = gg.getValues(toGet)
        if results[1].value == FactoryItems[2].value then
        return true
        else
        return false
        end
    end
    local function checkComponent(address)
        local toGet = {{address = address + 0x50 , flags = gg.TYPE_QWORD}}
        local results = gg.getValues(toGet)
        if results[1].value == FactoryItems[11].value then
        return true
        else
        return false
        end
    end
    gg.clearResults()
    revert()
    gg.searchNumber(FactoryItems[1].value, gg.TYPE_QWORD, false, gg.SIGN_EQUAL, 0, -1, 0)
    local count = gg.getResultsCount()
    local results = gg.getResults(count)
    gg.clearResults()
    for i = 1, count do
        if checkWood(results[i].address) and checkComponent(results[i].address) then
        ItemListStart = results[i].address
        break
        end
    end
    local toGetItems = {}
    if ItemListStart == nil then
      gg.alert("Item list not found")
      return 1
    end
    for i = 1, 130 do
      toGetItems[i] = {
        address = ItemListStart + (i-1) * 8,
        flags = gg.TYPE_QWORD
        }
    end
    ItemList = gg.getValues(toGetItems)
    gg.toast('Done!')
end

local wasWarFound = nil
local WarItems = {} 
local function findWarItemList() 
  local warItemPointer =    RootPointer + RootOffsets.waritems
  gg.clearResults()
  gg.searchNumber(warItemPointer, gg.TYPE_QWORD, false, gg.SIGN_EQUAL, 0, -1, 0)
  local count = gg.getResultsCount()
  local results = gg.getResults(count)
  gg.clearResults()
  local toGet = {}
    for i = 1, 12 do
      toGet[i]={
        address = results[i].address + 0x10,
        flags = gg.TYPE_QWORD
        }
     end
    local toGetWar = gg.getValues(toGet)
    
    local toGet = {}
    for i = 1, 12 do
      toGet[i] ={
        address = toGetWar[i].value,
        flags = gg.TYPE_DWORD
        }
    end
      local toGetWarTwo = gg.getValues(toGet)
    for i = 1, 12 do
      if toGetWarTwo[i].value == 1835876616 then --ammo
        WarItems[1] = results[i].address
      elseif toGetWarTwo[i].value == 1919501846 then --hydrant
        WarItems[2] = results[i].address
      elseif toGetWarTwo[i].value == 1986937098 then --anvil
        WarItems[3] = results[i].address
      elseif toGetWarTwo[i].value == 1869762578 then --propeller
        WarItems[4] = results[i].address
      elseif toGetWarTwo[i].value == 1734692114 then --megaphone 
        WarItems[5] = results[i].address
      elseif toGetWarTwo[i].value == 1935755024 then --gasoline
        WarItems[6] = results[i].address
      elseif toGetWarTwo[i].value == 1651855894 then --boots
        WarItems[7] = results[i].address
      elseif toGetWarTwo[i].value == 1768706060 then --pliers
        WarItems[8] = results[i].address
      elseif toGetWarTwo[i].value == 1651855892 then --ducky
        WarItems[9] = results[i].address
      elseif toGetWarTwo[i].value == 1852391956 then --binoculars
        WarItems[10] = results[i].address
      elseif toGetWarTwo[i].value == 1970032654 then --plunger
        WarItems[11] = results[i].address
      elseif toGetWarTwo[i].value == 1684360460 then --medkit
        WarItems[12] = results[i].address
      else
        gg.alert("something aint right")
      end
    end
end

local expansionWasFound = nil
local ExpansionItems = {} 
local function findExpansion() 
  local expansionItemPointer = RootPointer + RootOffsets.expansionitems
  gg.clearResults()
  gg.searchNumber(expansionItemPointer, gg.TYPE_QWORD, false, gg.SIGN_EQUAL, 0, -1, 0)
  local results = gg.getResults(-1)
  gg.clearResults()
    local toGet = {}
     for i = 1, 15 do
      toGet[i]={
        address = results[i].address + 0x10,
        flags = gg.TYPE_QWORD
        }
     end
    local toGetExpansion = gg.getValues(toGet)
    
    local toGet0x8 = {}
    for i = 1, 15 do
      toGet0x8[i] ={
        address = toGetExpansion[i].value + 0x8,
        flags = gg.TYPE_QWORD
        }
    end
    local toGetExpansion0x8 = gg.getValues(toGet0x8)
    local toGet0x10 = {}
    for i = 1, 15 do
      toGet0x10[i] ={
        address = toGetExpansion[i].value + 0x10,
        flags = gg.TYPE_QWORD
        }
    end
      local toGetExpansion0x10 = gg.getValues(toGet0x10)
    
    for i = 1, 15 do
      if toGetExpansion0x8[i].value == 8316866899155576172 then -- dozer wheel
        ExpansionItems[1] = results[i].address
      elseif toGetExpansion0x8[i].value == 8243124913282442604 then -- exhaust 
        ExpansionItems[2] = results[i].address
      elseif toGetExpansion0x8[i].value == 7017581717894423916 then -- dozer blade 
        ExpansionItems[3] = results[i].address
      elseif toGetExpansion0x8[i].value == 8243122654398080364 then -- storage lock 
        ExpansionItems[4] = results[i].address
      elseif toGetExpansion0x8[i].value == 7449366535721674092 then -- storage bar 
        ExpansionItems[5] = results[i].address
      elseif toGetExpansion0x8[i].value == 8243126012945065324  then -- storage camera 
        ExpansionItems[6] = results[i].address
      elseif toGetExpansion0x8[i].value == 7308613709769696620 then -- vu remote 
        ExpansionItems[7] = results[i].address
      elseif toGetExpansion0x8[i].value == 28554769125565804 then --vu battery 
        ExpansionItems[8] = results[i].address
      elseif toGetExpansion0x8[i].value == 8389187293518194028 then -- vu glove 
        ExpansionItems[9] = results[i].address
      elseif toGetExpansion0x10[i].value == 215560907105 then --compass (mountain)
        ExpansionItems[10] = results[i].address
      elseif toGetExpansion0x10[i].value == 211265939809 then --snowboard (montain) 
        ExpansionItems[11] = results[i].address
      elseif toGetExpansion0x10[i].value == 219855874401 then -- winter hat (mountain) 
        ExpansionItems[12] = results[i].address
      elseif toGetExpansion0x10[i].value == 12848 then -- ship wheel (beach) 
        ExpansionItems[13] = results[i].address
      elseif toGetExpansion0x10[i].value == 12592 then -- lifebelt (beach) 
        ExpansionItems[14] = results[i].address
      elseif toGetExpansion0x10[i].value == 13104 then --  scuba mask (beach) 
        ExpansionItems[15] = results[i].address
      else
        gg.alert("something aint right")
      end
    end
end

local OMEGAWasFound = nil
local OMEGAItems = {} 
local function findOMEGA() 
  local OMEGAPointer = RootPointer + RootOffsets.omegaitems
  gg.clearResults()
  gg.searchNumber(OMEGAPointer, gg.TYPE_QWORD, false, gg.SIGN_EQUAL, 0, -1, 0)
  local results = gg.getResults(-1)
  gg.clearResults()
    local toGet= {}
     for i = 1, 10 do
      toGet[i]={
        address = results[i].address + 0x10,
        flags = gg.TYPE_QWORD
        }
     end
    local toGetOMEGA = gg.getValues(toGet)
    
    local toGetTwo = {}
    for i = 1, 10 do
      toGetTwo[i] ={
        address = toGetOMEGA[i].value,
        flags = gg.TYPE_DWORD
        }
    end
    local toGetOMEGA2 = gg.getValues(toGetTwo)
    for i = 1, 10 do
      if toGetOMEGA2[i].value == 1651462670 then --Robopet = 
        OMEGAItems[1] = results[i].address
      elseif toGetOMEGA2[i].value == 1346647058 then --4-D Printer = 
        OMEGAItems[2] = results[i].address
      elseif toGetOMEGA2[i].value == 1953382688 then --Antigravity Boots = 
        OMEGAItems[3] = results[i].address
      elseif toGetOMEGA2[i].value == 2037531426 then --Cryofusion Chamber = 
        OMEGAItems[4] = results[i].address
      elseif toGetOMEGA2[i].value == 1819232282 then --Holoprojector = 
        OMEGAItems[5] = results[i].address
      elseif toGetOMEGA2[i].value == 1987004436 then --Hoverboard = 
        OMEGAItems[6] = results[i].address
      elseif toGetOMEGA2[i].value == 1952795150 then --Jet Pack = 
        OMEGAItems[7] = results[i].address
      elseif toGetOMEGA2[i].value == 1953256730 then --Ultrawave Oven = 
        OMEGAItems[8] = results[i].address
      elseif toGetOMEGA2[i].value == 1818579982 then --Telepod = 
        OMEGAItems[9] = results[i].address
      elseif toGetOMEGA2[i].value == 1819235094 then --Solar Panels = 
        OMEGAItems[10] = results[i].address
      else
        gg.alert("something aint right")
      end
    end
end

local wereCertsFound = nil
local CertsAndTokens = {} 
local function findTokens() 
  local certPointer = RootPointer + RootOffsets.expansioncerts
  local tokenPointer = RootPointer + RootOffsets.speedtokens
  gg.clearResults()
  gg.searchNumber(certPointer, gg.TYPE_QWORD, false, gg.SIGN_EQUAL, 0, -1, 0)
  local certs = gg.getResults(-1) --3 results
  gg.clearResults()
  gg.searchNumber(tokenPointer, gg.TYPE_QWORD, false, gg.SIGN_EQUAL, 0, -1, 0)
  local tokens = gg.getResults(-1) --6 results
  gg.clearResults()
  local certsAndTokensPrep = {}
  for _, certItem in ipairs(certs) do
    table.insert(certsAndTokensPrep, certItem)
  end
  for _, tokenItem in ipairs(tokens) do
    table.insert(certsAndTokensPrep, tokenItem)
  end
  local toGet = {}
  for i = 1, #certsAndTokensPrep do
    toGet[i]={
      address = certsAndTokensPrep[i].address + 0x10,
      flags = gg.TYPE_QWORD
      }
  end
  local certAndTokenNamePtr = gg.getValues(toGet)
  for i = 1, #certAndTokenNamePtr do
    toGet[i]={
      address = certAndTokenNamePtr[i].value + 0xC,
      flags = gg.TYPE_QWORD
      }
  end
  local certAndTokenNames = gg.getValues(toGet)
  for i = 1, #certs + #tokens do
    if certAndTokenNames[i].value == 7521962890172982635 then --cert beach 
      CertsAndTokens[1] = certsAndTokensPrep[i].address
    elseif certAndTokenNames[i].value == 8389772276738712939 then --cert mountain 
      CertsAndTokens[2] = certsAndTokensPrep[i].address
    elseif certAndTokenNames[i].value == 34186467633685867 then --cert city
      CertsAndTokens[3] = certsAndTokensPrep[i].address
    elseif certAndTokenNames[i].value == 516241193330 then --Fac 2x 
      CertsAndTokens[4] = certsAndTokensPrep[i].address
    elseif certAndTokenNames[i].value == 516274747762 then --fac 4x  
      CertsAndTokens[5] = certsAndTokensPrep[i].address
    elseif certAndTokenNames[i].value == 132156972038514 then --fac 12x  
      CertsAndTokens[6] = certsAndTokensPrep[i].address
    elseif certAndTokenNames[i].value == 8026370369911324773 then --Turtle 
      CertsAndTokens[7] = certsAndTokensPrep[i].address
    elseif certAndTokenNames[i].value == 0 then --Llama 
      CertsAndTokens[8] = certsAndTokensPrep[i].address
    elseif certAndTokenNames[i].value == 26721 then --Cheetah 
      CertsAndTokens[9] = certsAndTokensPrep[i].address
    else
      gg.alert("something aint right")
    end
  end
end

local wereWarcardsFound = nil
local WarCards = {}
local function findWarCards() 
  local warCardPointer = RootPointer + RootOffsets.warcards
  gg.clearResults()
  gg.searchNumber(warCardPointer, gg.TYPE_QWORD, false, gg.SIGN_EQUAL, 0, -1, 0)
  local results = gg.getResults(-1) --19 results
  gg.clearResults()
  local toGet = {}
  for i = 1, #results do
    toGet[i] = {
      address = results[i].address + 0x10,
      flags = gg.TYPE_QWORD
    }
  end
  local buffer = gg.getValues(toGet)
  local toGet = {}
  for i = 1, #results do
    toGet[i] = {
      address = buffer[i].value,
      flags = gg.TYPE_QWORD
    }
  end
  local warcardNames = gg.getValues(toGet)
  for i = 1, #warcardNames do
    if warcardNames[i].value == 4858943563757470494 then --Common QWORD  
      WarCards[1] = results[i].address
    elseif warcardNames[i].value == 8241942896054456858 then --Rare QWORD 
      WarCards[2] = results[i].address
    elseif warcardNames[i].value == 7017855501155519524 then --Legendary QWORD 
      WarCards[3] = results[i].address
    end
  end
end

local boosters = {}
function findBoosters()
	gg.clearResults()
	gg.searchNumber(RootPointer + 0x1c48,gg.TYPE_QWORD)
	boosters = gg.getResults(-1)
end


--==========================================================replace functions
function revert()
	if factory_found then 
		gg.setValues(FactoryItems)
	end
end

local function replaceWarItems() 
  if wasWarFound == nil then
    wasWarFound = 1
    gg.toast("Loading War Items")
    findWarItemList()
  end

  local toSet = {}
  for i = 1, 11 do
    toSet[i] = {
      address = FactoryItems[i].address,
      flags = gg.TYPE_QWORD,
      value = WarItems[i]
      }
  end
  gg.setValues(toSet)
end

local function replaceExpansion()
  if expansionWasFound == nil then
    expansionWasFound = 1
    gg.toast("Loading Expansion Items")
    findExpansion()
  end

  local toSet = {}
  for i = 1, 11 do
    toSet[i] = {
      address = FactoryItems[i].address,
      flags = gg.TYPE_QWORD,
      value = ExpansionItems[i]
      }
  end
  gg.setValues(toSet)
end

local function replaceWarItemsPresets(preset)
  if wasWarFound == nil then
    wasWarFound = 1
    gg.toast("Loading War Items")
    findWarItemList()
  end
  local indexes = {}
  if preset == 1 then --Comic Hand 
    indexes = {11, 9}
  elseif preset == 2 then --Shrink Ray 
    indexes = {8, 5}
  elseif preset == 3 then --Giant Rock Monster 
    indexes = {2, 10}
  elseif preset == 4 then --Not in Kansas 
    indexes = {3, 4}
  elseif preset == 5 then --Magnetism 
    indexes = {10, 2, 3}
  elseif preset == 6 then --Tentacle Vortex 
    indexes = {11, 9, 4}
  elseif preset == 7 then --Flying Vu Robot 
    indexes = {1, 6}
  elseif preset == 8 then --Disco Twister 
    indexes = {5, 8, 4}
  elseif preset == 9 then --Plant Monster 
    indexes = {11, 6, 7}
  elseif preset == 10 then --Blizzaster 
    indexes = {4, 1, 9}
  elseif preset == 11 then --Fishaster 
    indexes = {9, 7, 2}
  elseif preset == 12 then --Ancient Curse 
    indexes = {7, 5, 10}
  elseif preset == 13 then --Hands of Doom 
    indexes = {1, 9, 8}
  elseif preset == 14 then --16 Tons 
    indexes = {8, 2, 3}
  elseif preset == 15 then --Spiders 
    indexes = {6, 10, 1}
  elseif preset == 16 then --Dance Shoes 
    indexes = {6, 10, 7}
  elseif preset == 17 then --Building Portal 
    indexes = {2, 11, 4}
  elseif preset == 18 then --B Movie Monster 
    indexes = {7, 11, 5}
  elseif preset == 19 then --Hissy Fit 
    indexes = {10, 8, 7}
  elseif preset == 20 then --Mellow Bellow DUCKY SKIPPED
    indexes = {5, 8, 4}
  elseif preset == 21 then --Doomsday Quack
    local toSet = {}
    toSet[1] = {
      address = FactoryItems[1].address,
      flags = gg.TYPE_QWORD,
      value = WarItems[9]
      }
    toSet[2] = {
      address = FactoryItems[2].address,
      flags = gg.TYPE_QWORD,
      value = ItemList[42].value
      }
    for i = 3, 11 do
      toSet[i] = {
        address = FactoryItems[i].address,
        flags = gg.TYPE_QWORD,
        value = FactoryItems[i].value
        }
    end
    gg.setValues(toSet)
    return 1
  elseif preset == 22 then --Electric Deity 
    indexes = {5, 6, 3}
  elseif preset == 23 then --Shield Buster 
    indexes = {6, 12}
  elseif preset == 24 then --Zest from Above 
    indexes = {10, 3, 1}
  end
  local toSet = {}
  for i = 1, #indexes do
    toSet[i] = {
      address = FactoryItems[i].address,
      flags = gg.TYPE_QWORD,
      value = WarItems[indexes[i]]
      }
  end
  for i = #indexes + 1, 11 do
    toSet[i] = {
      address = FactoryItems[i].address,
      flags = gg.TYPE_QWORD,
      value = FactoryItems[i].value
      }
  end
  gg.setValues(toSet)
end

local function replaceItemsThatDidntFit() 
  if wasWarFound == nil then
    wasWarFound = 1
    gg.toast("Loading War Items")
    findWarItemList()
  end
  if expansionWasFound == nil then
    expansionWasFound = 1
    gg.toast("Loading Expansion Items")
    findExpansion()
  end
  local toSet = {}
  for i = 12, 15 do
    toSet[i-11] = {
      address = FactoryItems[i-11].address,
      flags = gg.TYPE_QWORD,
      value = ExpansionItems[i]
      }
  end
  toSet[5] = {
    address = FactoryItems[5].address,
    flags = gg.TYPE_QWORD,
    value = WarItems[12]
    }
    for i = 6, 11 do
      toSet[i] = {
        address = FactoryItems[i].address,
        flags = gg.TYPE_QWORD,
        value = FactoryItems[i].value
        }
    end
  gg.setValues(toSet)
end

local function replaceOMEGA()
  if OMEGAWasFound == nil then
    OMEGAWasFound = 1
    gg.toast("Loading OMEGA Items")
    findOMEGA()
  end

  local toSet = {}
  for i = 1, 10 do
    toSet[i] = {
      address = FactoryItems[i].address,
      flags = gg.TYPE_QWORD,
      value = OMEGAItems[i]
      }
  end
  toSet[11] = {
    address = FactoryItems[11].address,
    flags = gg.TYPE_QWORD,
    value = FactoryItems[11].value
    }
  gg.setValues(toSet)
end

local function replaceCertsAndTokens()
  if wereCertsFound == nil then
    wereCertsFound = 1
    gg.toast("Loading Certs and Tokens")
    findTokens()
  end
  
  local toSet = {}
  for i = 1, #CertsAndTokens do
    toSet[i] = {
      address = FactoryItems[i].address,
      flags = gg.TYPE_QWORD,
      value = CertsAndTokens[i]
      }
  end
  for i = #CertsAndTokens +1, 11 do
    toSet[i] = {
      address = FactoryItems[i].address,
      flags = gg.TYPE_QWORD,
      value = FactoryItems[i].value
      }
  end
  gg.setValues(toSet)
end

local function replaceWarCards()
  if wereWarcardsFound == nil then
    wereWarcardsFound = 1
    gg.toast("Loading Warcards")
    findWarCards()
  end

  local toSet = {}
  for i = 1, 3 do
    toSet[i] = {
      address = FactoryItems[i].address,
      flags = gg.TYPE_QWORD,
      value = WarCards[i]
      }
  end
  for i = 4, 11 do
    toSet[i] = {
      address = FactoryItems[i].address,
      flags = gg.TYPE_QWORD,
      value = FactoryItems[i].value
      }
  end
  gg.setValues(toSet)
end

local function setFromItemsList(array)
    local toset = {}
    for i, v in pairs(array) do
        table.insert(toset, {address = FactoryItems[i].address, flags=32, value = ItemList[v].value})
    end
    gg.setValues(toset)
end

function setBoosters(page)
	if not boosters[1] then 
		findBoosters()
	end
	local toset = {}
    for i = 1,math.min(11,#boosters-((page-1)*11)) do
        table.insert(toset, {address = FactoryItems[i].address, flags=32, value = boosters[(page-1)*11+i].address})
    end
    gg.setValues(toset)
	gg.setVisible(false)
end
--==========================================================settings functions
timeTable = {}
timeTable_found = false
function findTimeTable()
    if not RootPointer then findRoot() end
    gg.toast('finding time table...')
    gg.clearResults()
    gg.searchNumber(RootPointer - 0x8, gg.TYPE_QWORD, false, gg.SIGN_EQUAL, 0, -1, 0)
    TimeTable = gg.getResults(-1)
    timeTable_found = true
end

function setTime(time)
    if not timeTable_found then findTimeTable() end
    local toset = {}
    for i, v in ipairs(TimeTable) do 
        table.insert(toset,{address = v.address + 0x9c, flags = 4, value = time})
    end
    gg.setValues(toset)
    gg.toast('Done!')
end

function setXP(xp)
    if not timeTable_found then findTimeTable() end
    local toset = {}
    for i, v in ipairs(TimeTable) do 
        table.insert(toset,{address = v.address + 0x208, flags = 4, value = xp})
    end
    gg.setValues(toset)
    gg.toast('Done!')
end

factoryFuncs = {

["Edit Production Time"] = function()
	local input = gg.prompt({'1000 = 1 second'},{'0'},{'number'})
	if input then
		setTime(input[1])
	end
end,

["Edit Production Ammount"] = function()
	local input = gg.prompt({'enter item multiplier'},{'10'},{'number'})
	if input then
		setItemMultiplier(input[1])
	end
end,

['Edit XP'] = function()
	local input = gg.prompt({'lvl1->lvl18: 7300\nlvl1->lvl30: 26000\nlvl1->lvl50: 96000\nlvl1->lvl99: 813000\ncan put in negative numbers to get rid of XP but it might cause the game to think you are out of sync'},{'0'},{'number'})
	if input then
		setXP(input[1])
	end
end,

["Unlock All Production Items"] = function()
    if not timeTable_found then findTimeTable() end
    local toset = {}
    for i, v in ipairs(TimeTable) do 
        table.insert(toset,{address = v.address + 0x200, flags = 32, value = 0})
    end
    gg.setValues(toset)
    gg.toast('Done!')
end,

["Lock All Production Items"] = function()
    if not timeTable_found then findTimeTable() end
    local toset = {}
    for i, v in ipairs(TimeTable) do 
        table.insert(toset,{address = v.address + 0x200, flags = 4, value = -69})
    end
    gg.setValues(toset)
    gg.toast('Done!')
end,

["Unlock All Factory Items"] = function()
    if not timeTable_found then findTimeTable() end
    if not factory_items_req[1] then findFactoryItemsReq() end
    local toset = {}
    for i, v in ipairs(factory_items_req) do 
        table.insert(toset,{address = v.address + 0x200, flags = 4, value = 0})
    end
    gg.setValues(toset)
    gg.toast('Done!')
end,

['Remove Material Requirements For Shops'] = function()
    if not timeTable_found then findTimeTable() end
    local toset = {}
    for i, v in ipairs(TimeTable) do 
        table.insert(toset,{address = v.address + 0x1c8, flags = 32, value = 0})
        table.insert(toset,{address = v.address + 0x1d0, flags = 32, value = 0})
        table.insert(toset,{address = v.address + 0x1d8, flags = 32, value = 0})
    end
    gg.setValues(toset)
    gg.toast('Done!')
end,
}

factory_items_req = {}
function findFactoryItemsReq()
    local toget_name_add = {}
    for i, v in ipairs(TimeTable) do 
        table.insert(toget_name_add,{address = v.address + 0x10, flags = 32, value = 0})
    end
    toget_name_add = gg.getValues(toget_name_add)
    local toget_name = {}
    for i, v in ipairs(toget_name_add) do 
        table.insert(toget_name,{address = v.value, flags = 4, value = 0})
    end
    toget_name = gg.getValues(toget_name)
	local fac_items = {1952795922,1869567760,1634488342,1701139218,1852394776,1701331738,2019906584,1735742238,1634486034,1768833308,33}
	local fac_items_revers = {}
    for i,v in ipairs(fac_items) do
		fac_items_revers[v] = true
	end
    for i, v in ipairs(toget_name) do
        if fac_items_revers[v.value] then
        	table.insert(factory_items_req,TimeTable[i])
        end
    end
end

function setItemMultiplier(q)
    if not timeTable_found then findTimeTable() end
    local toget = {}
    for i, v in ipairs(TimeTable) do 
        table.insert(toget,{address = v.address + 0x1e8, flags = 32, value = 0})
    end
    toget = gg.getValues(toget)
    local toset = {}
    for i, v in ipairs(toget) do
        table.insert(toset,{address = v.value + 0x18, flags = 4, value = q})
    end
    gg.setValues(toset)
    gg.toast('Done!')
end


--==========================================================menus
factory_menus = {"Edit Production Time","Edit Production Ammount","Unlock All Production Items","Lock All Production Items","Unlock All Factory Items",'Edit XP','Remove Material Requirements For Shops','Go Back'}
menus['Factory Settings'] = function()
	local index = gg.choice(factory_menus)
	if not index then 
		uiOpen = false 
		gg.isVisible(false)
	elseif factoryFuncs[factory_menus[index] ] then
		 factoryFuncs[factory_menus[index] ]()
	else 
		return true 
	end 
end

local regionalItemsMenu = {
  [1] = "Cactus Canyon",
  [2] = "Green Valley",
  [3] = "Limestone Cliffs",
  [4] = "Sunny Isles",
  [5] = "Frosty Fjords"
}
local regional_list = {
  [1] = {77,78,79,80},
  [2] = {73,74,75,76},
  [3] = {89,90,91,92},
  [4] = {81,82,83,84},
  [5] = {85,86,87,88}
}
local menuChoices2 = {"Edit Production Time","Edit Production Ammount","Unlock All Production Items","Lock All Production Items","Unlock All Factory Items",'Edit XP','Remove Material Requirements For Shops','Go Back'}

local menuChoices = { "VU and Expansion Items (all beach and winter not included) ","War Items (Medkit not included)", "Omega Items","Regional Items", "Railroad Items","Airport Items","Shop Items","winter hat, medkit, and Beach Items", "Revert to default", "Speedup Tokens and Certificates","Warcards BETA","War Items presets",'Boosters (offset broken)','Go Back',}

local warcardsMenu = {
  [1] = "Comic Hand",
  [2] = "Shrink Ray",
  [3] = "Giant Rock Monster",
  [4] = "Not in Kansas",
  [5] = "Magnetism",
  [6] = "Tentacle Vortex",
  [7] = "Flying Vu Robot",
  [8] = "Disco Twister",
  [9] = "Plant Monster",
  [10] = "Blizzaster",
  [11] = "Fishaster",
  [12] = "Ancient Curse",
  [13] = "Hands of Doom",
  [14] = "16 Tons",
  [15] = "Spiders",
  [16] = "Dance Shoes",
  [17] = "Building Portal",
  [18] = "B Movie Monster",
  [19] = "Hissy Fit",
  [20] = "Mellow Bellow",
  [21] = "Doomsday Quack",
  [22] = "Electric Deity",
  [23] = "Shield Buster",
  [24] = "Zest from Above"
}
local shopOptions = {
    [1] = 'Building Supplies',
    [2] = 'Harware',
    [3] = 'Farmers',
    [4] = 'Furniture and Gardening',
    [5] = 'Donut and Fashion',
    [6] = 'Fast Food and Home Appliances',
    [7] = 'Sports and Toys',
    [8] = 'Restorations and Country',
    [9] = 'Dessert',
    [10] = 'Santa Workshop and Chocolate Factory',
}
local shopList = {
    ['Building Supplies'] = {12,13,14,15,16,17},
    ['Harware'] = {18,19,20,21,23,22},
    ['Farmers'] = {24,25,26,28,30,27,29},
    ['Furniture and Gardening'] = {31,32,33,35,34,36,37,38,39,41,40},
    ['Donut and Fashion'] = {42,43,44,45,46,47,48,49,50,51,52},
    ['Fast Food and Home Appliances'] = {56,54,55,53,57,58,61,60,62,59,63},
    ['Sports and Toys'] = {98,99,100,101,102,122,123,124,125},
    ['Restorations and Country'] = {108,109,110,111,112,103,104,105,106,107},
    ['Dessert'] = {126,127,128,129,130},
    ['Santa Workshop and Chocolate Factory'] = {93,94,95,96,97,113,114,115,116,117}
}


function shopItemsMenu()
    while true do 
        if gg.isVisible() == false then
            gg.sleep(30)
        else
            local shopsindex = gg.choice(shopOptions, nil, "Shop Items")
            if shopsindex == nil then
                return
            end
            setFromItemsList(shopList[ shopOptions[shopsindex] ])
            gg.setVisible(false)
        end
    end
end

function pTimeDisclaimer()
	if yesNoPrompt("These cannot be collected unless you spend simcash to speed up production. Do you want to set production time to 1 min?") then
		setTime(60000)
	end
end

itemFunc = {
	['Boosters (insta ban)'] = function() 
		local index = gg.choice({'page 1','page 2'})
		if index then
			pTimeDisclaimer()
			setBoosters(index) 
		end
		gg.toast('Done!')
	end,
}

menus['Item Tool'] = function()
    if not factory_found then
        gg.setVisible(false)
        findFactory()
        findItemList()
        gg.setVisible(true)
    elseif ItemListStart == nil then
        gg.setVisible(false)
        findItemList()
        gg.setVisible(true)
    end
    while true do gg.sleep(30)
        if gg.isVisible() then
            local selectedIndex = gg.choice(menuChoices, nil, "Choose an option")
			if selectedIndex == nil then
                gg.setVisible(false)
            elseif selectedIndex == 1 then
                gg.setVisible(false)
                replaceExpansion()
                gg.toast("Done!")
            elseif selectedIndex == 2 then
                gg.setVisible(false)
                replaceWarItems()
                gg.toast("Done!")
            elseif selectedIndex == 3 then
                gg.setVisible(false)
                replaceOMEGA()
                gg.toast("Done!")
            elseif selectedIndex == 4 then
                local index = gg.choice(regionalItemsMenu, nil, "Choose an option, cancell to abort")
                if index then
                    setFromItemsList(regional_list[index])
                    gg.setVisible(false)
                end
            elseif selectedIndex == 5 then
                setFromItemsList({118,119,120,121})
                gg.setVisible(false)
            elseif selectedIndex == 6 then
                setFromItemsList({64,65,66,67,68,69,70,71,72})
                gg.setVisible(false)
            elseif selectedIndex == 7 then
                shopItemsMenu()
            elseif selectedIndex == 10 then
				pTimeDisclaimer()
                replaceCertsAndTokens()
                gg.toast("Done!")
            elseif selectedIndex == 12 then
                local index = gg.choice(warcardsMenu, nil, "Choose an option, cancell to abort")
                if index then
                    gg.setVisible(false)
                    replaceWarItemsPresets(index)
                    gg.toast("Done!")
                end
            elseif selectedIndex == 9 then
                gg.setVisible(false)
                revert()
                gg.toast("Done!")
            elseif selectedIndex == 11 then
				pTimeDisclaimer()
                replaceWarCards()
                gg.toast("Done!")
            elseif selectedIndex == 8 then
                gg.setVisible(false)
                replaceItemsThatDidntFit()
                gg.toast("Done!")
            elseif selectedIndex == 14 then
				return true
            else
                if itemFunc [menuChoices[selectedIndex] ] then 
					itemFunc [menuChoices[selectedIndex] ]()
				else
					gg.toast('error')
				end
            end
        end
    end
end


--===========================================================
--      small scripts
--===========================================================
original_population = {}
menus['Change Population'] = function()
	if original_population[1] == nil then
		if not RootPointer then
			findRoot()
		end
		gg.clearResults()
		gg.searchNumber(RootPointer + RootOffsets.buildingpopulation,gg.TYPE_QWORD)
		original_population = gg.getResults(-1)
		for i in ipairs(original_population) do
			original_population[i].address = original_population[i].address + 0x9c
			original_population[i].flags = 4
		end
		original_population = gg.getValues(original_population)
	end
	local index = gg.choice({'change all buildings','change one building type','reset','Go Back'})
	if index == nil then
		uiOpen = false
	elseif index == 1 then
		local pop = gg.prompt({''},{0},{'number'})
		if pop and #pop[1] ~= 0 then
			local toset = {}
			for i,v in ipairs(original_population) do
				table.insert(toset,{address=v.address,flags=4,value=pop[1]})
			end
			gg.setValues(toset)
		end
	elseif index == 2 then
		local building_p = gg.prompt({'Enter the original population value of the building you would like to change. You can see this value by moving the building to an area with no amenitity coverage.'},{52},{'number'})
		if building_p and #building_p[1] ~= 0 then
			local buildings = {}
			for i,v in ipairs(original_population) do
				if v.value == building_p[1] then 
					table.insert(buildings,{address=v.address,flags=4})
				end
			end
			if buildings[1] == nil then
				gg.toast('no buildings with that population found')
			else
				local pop = gg.prompt({'Enter the value to change this buildings population to'},{-1},{'number'})
				if pop and #pop[1] ~= 0 then	
					for i in ipairs(buildings) do
						buildings[i].value = pop[1]
					end
					gg.setValues(buildings)
					if yesNoPrompt('do you want to save these values?') then
						for i in ipairs(buildings) do
							buildings[i].name = 'building ' .. building_p[1]
						end
						gg.addListItems(buildings)
					end
				end
			end
		end
	elseif index == 3 then
		gg.setValues(original_population)
	else
		return true
	end
end

depot_box = {}
menus['EZ Sell'] = function()
	local function setQorP(n)
		local index = gg.choice({'freeze to 5','freeze custom','unfreese'})
		if index then
			if index == 1 then
				depot_box[n].freeze = true
				depot_box[n].value = 5
			elseif index == 2 then
				depot_box[n].freeze = true
				local input = gg.prompt({''},{5},{'number'})
				if input and #input[1] ~= 0 then
					depot_box[n].value = input[1]
				end
			elseif index == 3 then
				depot_box[n].freeze = false
			end
			gg.addListItems(depot_box)
		end
	end
	if depot_box[1] == nil then
		gg.clearResults()
		gg.searchNumber('746C75616665440Eh', gg.TYPE_QWORD)
		local results = gg.getResults(-1)
		gg.clearResults()
		for i in ipairs(results) do 
			results[i].address = results[i].address + 0x30
		end
		results = gg.getValues(results)
		for i,v in ipairs(results) do 
			if v.value == 0x6C6174654D0A then
				gg.searchNumber(v.address-0x30, gg.TYPE_QWORD, false, gg.SIGN_EQUAL, 0, -1, 1)
				break
			end
		end
		if gg.getResultsCount() == 0 then
			gg.toast('dopot list not found')
			return true
		end
		local addr = gg.getResults(1)[1].address
		depot_box = {{address=addr+0x1c,flags=4,name='depot quantity',freeze=false},
			{address=addr+0x20,flags=4,name='depot price',freeze=false},
			{address=addr+0x28,flags=gg.TYPE_BYTE,name='advertise',freeze=false},
		}
		gg.addListItems(depot_box)
	end
	local index = gg.choice({'quantity: ' .. (depot_box[1].freeze and ('frozen to ' .. depot_box[1].value) or 'unfrozen'),
		'price: ' .. (depot_box[2].freeze and ('frozen to ' .. depot_box[2].value) or 'unfrozen'),
		'advertise: ' .. (depot_box[3].freeze and ('frozen to ' .. (depot_box[3].value == 1 and 'yes' or 'no')) or 'unfrozen'),
		'Go Back'
	})
	if index == nil then
		uiOpen = false
	elseif index == 3 then
		local index = gg.choice({'freeze yes','freeze no','unfreese'})
		if index then
			if index == 1 then
				depot_box[3].freeze = true
				depot_box[3].value = 1
			elseif index == 2 then
				depot_box[3].freeze = true
				depot_box[3].value = 0
			elseif index == 3 then
				depot_box[3].freeze = false
			end
			gg.addListItems(depot_box)
		end
	elseif index == 4 then
		return true
	else 
		setQorP(index)
	end
end

road_prices = {}
--[[
function findRoadPrices()
	gg.clearResults()
	gg.searchNumber(0x316172756B61530E,gg.TYPE_QWORD)
	local results = gg.getResults(-1)
	local check = {}
	for i,v in ipairs(results) do
		check[i] = {address = v.address - 0x14,flags=32}
	end 
	check = gg.getValues(check)
	for i,v in ipairs(check) do 
		if v.value == 0x676E702E39305F do 
			gg.clearResults()
			gg.searchNumber(results[i].address,gg.TYPE_QWORD)
			break 
		end 
	end
	local results = gg.getResults(-1)
	local check = {}
	for i,v in ipairs(results) do
		check[i] = {address = v.address + 8,flags=32}
	end 
	check = gg.getValues(check)
	for i,v in ipairs(check) do
		check[i].address = v.value
	end 
	check = gg.getValues(check)
	for i,v in ipairs(check) do 
		if v.value == 0 do 
			 
		end 
	end
	]]


menus['Change Road Prices'] = function()
	if gg.choice({'set'},nil,'This changes the price of all roads in sims and design sims. Youre gonna need to switch to another app for some time to make the game reload itself for this change to apply.') == 1 then
		local price = gg.prompt({'enter price'},{'0'},{'number'})
		if price and #price[1] ~= 0 then
			if road_prices[1] == nil then
				if not RootPointer then
					findRoot()
				end
				gg.clearResults()
				gg.searchNumber(RootPointer + RootOffsets.roads,gg.TYPE_QWORD)
				local toget = gg.getResults(-1)
				for i,v in ipairs(toget) do
					toget[i].address = v.address + 0x18
				end	
				toget = gg.getValues(toget)
				for i,v in ipairs(toget) do
					toget[i].address = v.value
				end
				toget = gg.getValues(toget)
				for i,v in ipairs(toget) do
					road_prices[2*i-1] = {address = v.value + 0x10,flags = 4}
					road_prices[2*i] = {address = v.value + 0x28,flags = 4}
				end
			end
			for i in pairs(road_prices) do
				road_prices[i].value = price[1]
			end
			gg.setValues(road_prices)
			gg.toast('Done!')
		end
	end
	return true
end

menus['Get Design Sims'] = function()
	gg.clearResults()
	gg.searchNumber(9999,gg.TYPE_DWORD)
	local results = gg.getResults(-1)
	local check = {}
	for i,v in ipairs(results) do
		for j = 5,0,-1 do
			check[6*i-j]={address=results[i].address+28-j*4,flags=4}
		end
	end
	check = gg.getValues(check)
	for i in pairs(results) do
		if (check[6*i-5].value==0) or (check[6*i-4].value==0) or (check[6*i-3].value==0) or (check[6*i-2].value==0) or (check[6*i-1].value~=0) or (check[6*i].value==0) then
			results[i] = nil
		end
	end
	local count = 0
	for i in pairs(results) do
		count = count + 1
		if count == 2 then
			gg.alert('More than one value found. Try running the script right after opening the game.')
			return true
		end
	end
	if count == 0 then
		gg.alert('Value not found. Try buying something with design sims and running again.')
		return true
	end
	for i in pairs(results) do 
		results[i].address = results[i].address + 16
		gg.setValues(results)
		gg.toast('Done!')
		return true
	end
end

menus['Max Storage'] = function()
	index = gg.choice({'City Storage','Omega Storage','Go Back'},nil,'Must already have the storage building built. Will need to go to Daniels island and come back to apply.')
	if index == nil then
		uiOpen = false
	elseif index == 3 then
		return true
	elseif index == 1 then
		gg.clearResults()
		gg.searchNumber('6D6E7265766F472Ch',gg.TYPE_QWORD)
		results = gg.getResults(-1)
		for i = 1,#results do
			results[i].address = results[i].address + 0x18
			results[i].flags = 4
			results[i].value = -1223400949
		end
		gg.setValues(results)
		gg.toast('Done!')
	elseif index == 2 then
		gg.clearResults()
		gg.searchNumber('5F65727574754620h',gg.TYPE_QWORD)
		results = gg.getResults(-1)
		for i = 1,#results do
			results[i].address = results[i].address + 0x18
			results[i].flags = 4
			results[i].value = -179140214
		end
		gg.setValues(results)
		gg.toast('Done!')
	end
end

menus['Clear Storage'] = function()
	if yesNoPrompt('Are you sure you wanna clear storage?') then
		if not RootPointer then
			findRoot()
		end
		local warItemPointer = RootPointer + RootOffsets.waritems
		local itemPointer = RootPointer + RootOffsets.mainitems
		local OMEGAItemPointer = RootPointer + RootOffsets.omegaitems
		local expansionItemPointer = RootPointer + RootOffsets.expansionitems
		local allItemBase = {}
		gg.clearResults()
		gg.searchNumber(warItemPointer, gg.TYPE_QWORD, false, gg.SIGN_EQUAL, 0, -1, 0)
		local warItemsBase = gg.getResults(-1)
		gg.clearResults()
		gg.searchNumber(itemPointer, gg.TYPE_QWORD, false, gg.SIGN_EQUAL, 0, -1, 0)
		local itemBase = gg.getResults(-1)
		gg.clearResults()
		gg.searchNumber(OMEGAItemPointer, gg.TYPE_QWORD, false, gg.SIGN_EQUAL, 0, -1, 0)
		local OMEGABase = gg.getResults(-1)
		gg.clearResults()
		gg.searchNumber(expansionItemPointer, gg.TYPE_QWORD, false, gg.SIGN_EQUAL, 0, -1, 0)
		local expansionItemBase = gg.getResults(-1)
		gg.clearResults()
		for i = 1, #warItemsBase do
			table.insert(allItemBase, warItemsBase[i].address)
		end
		for i = 1, #itemBase do
			table.insert(allItemBase, itemBase[i].address)
		end
		for i = 1, #OMEGABase do
			table.insert(allItemBase, OMEGABase[i].address)
		end
		for i = 1, #expansionItemBase do
			table.insert(allItemBase, expansionItemBase[i].address)
		end
		local toSet = {}
		for i = 1, #allItemBase do
			toSet[i] = {
				address = allItemBase[i] + 0x50,
				flags = gg.TYPE_DWORD,
				value = 2040088750
			}
		end
		gg.setValues(toSet)
		gg.toast("Done, restart game.")
	end
	return true
end

warcards_all = {}
function findWarcards()
	gg.clearResults()
	gg.searchNumber('313272657473h',32)
	local results = gg.getResults(-1)
	for i,v in ipairs(results) do 
		results[i].address = v.address + 16 
	end 
	results = gg.getValues(results)
	local check = {}
	for i,v in ipairs(results) do 
		check[i] = {address = v.value + 16, flags = 32}
	end 
	check = gg.getValues(check)
	for i,v in ipairs(check) do 
		check[i].address = v.value + 8
	end
	check = gg.getValues(check)
	gg.clearResults()
	for i,v in ipairs(check) do 
		if (v.value & bytemask(0x313272657473)) == 0x313272657473 then
			gg.searchNumber(gg.getValues({{address = results[i].value,flags=32}})[1].value,32)
			break 
		end 
	end 
	if gg.getResultsCount() == 0 then 
		gg.alert('error couldnt find warcards')
		return 
	end 
	warcards_all = gg.getResults(-1)
	return true
end

menus['No Item Requirement for War Cards'] = function()
	if not warcards_all[1] then
		if not findWarcards() then
			return true
		end
	end
	local toset = {}
	for i = 1, #warcards_all do
		for j = 1, 3 do
			table.insert(toset,{
				address = warcards_all[i].address + 0x298 + ((j-1)*8),
				flags = gg.TYPE_QWORD,
				value = 0
			})
		end
	end
	gg.setValues(toset)
	gg.toast("Done.")
	return true
end

menus['War Card Free Upgrades'] = function()
	if not warcards_all[1] then
		if not findWarcards() then
			return true
		end
	end
	local toSet = {}
	if yesNoPrompt('Do you want to lock card count to 40?(broken)') then
		gg.clearResults()
		gg.searchNumber(1092744876, gg.TYPE_DWORD, false, gg.SIGN_EQUAL, 0, -1, 0) --constant for park
		local parkConstant = gg.getResults(-1)
		gg.clearResults()
		local toGet = {}
		for i = 1, #parkConstant do
			toGet[i] = {
				address = parkConstant[i].address -0x48,
				flags = gg.TYPE_DWORD
			}
		end
		local correctConstantCheck = gg.getValues(toGet)
		for i = 1, #correctConstantCheck do
			if correctConstantCheck[i].value == 3 then
				correctConstant = parkConstant[i].address
				break
			end
		end
		local toGet = {{address = correctConstant + 0x300 , flags = gg.TYPE_QWORD},  {address = correctConstant + 0x308 , flags = gg.TYPE_QWORD}}
		local correctPointers = gg.getValues(toGet)
		for i = 1, #warcards_all do
			for j = 1, 2 do
				table.insert(toSet,{
				address = warcards_all[i].address + 0x2e8 + ((j-1) * 8),
				flags = gg.TYPE_QWORD,
				value = correctPointers[j].value
				})
			end
		end
	end
	local offsetsToSetTo0 = {0x2d0, 0x300, 0x308, 0x310, 0x330, 0x338, 0x340}
	for i = 1, #warcards_all do
		for j = 1, #offsetsToSetTo0 do
			table.insert(toSet,{
			address = warcards_all[i].address + offsetsToSetTo0[j] + 0x10,
			flags = gg.TYPE_QWORD,
			value = 0
			})
		end
	end 
	gg.setValues(toSet)
	gg.toast("Done!")
	return true
end

booster_factory_items = {}
menus['Get Boosters from Factory'] = function()
	local menu = {"Pump","Umbrella","Jackpot","Vamp","Freeze","Dud","Thief",'Set Multiplier to 100'}
	local booster_constants = {
		["Pump"] = {1965976282,1965976283,1965976284},
		["Umbrella"] = {1587235432,1587235433,1587235434},
		["Jackpot"] = {1692935226,1692935227,1692935228},
		["Vamp"] = {1736317036,1736317037,1736317038},
		["Freeze"] = {924894801,924894802,924894803},
		["Dud"] = {91798751,91798752,91798753},
		["Thief"] = {1147903624,1147903625}
	}
	if not booster_factory_items[1] then 
		material_constants = {267176888,2090874750,-1270634091}
		for i,v in ipairs(material_constants) do 
			gg.clearResults()
			gg.searchNumber(v,gg.TYPE_QWORD)
			booster_factory_items[i] = gg.getResults(-1)
		end 
	end
	local index = gg.choice(menu,nil,'this will give you boosters when you produce metal, wood, or plastic\nmetal=lvl1 wood=lvl2 plastic=lvl3\nthere is no lvl3 energy thief\nyou will need to restart the game for the boosters to appear\nif have more than 150 of one booster you might get banned')
	if index == nil then 
		return true 
	elseif index == # menu then 
		setItemMultiplier(100)
	else 
		local toset = {}
		for i,v in ipairs(booster_constants[menu[index] ]) do 
			for j,k in ipairs(booster_factory_items[i]) do
				table.insert(toset,{address=k.address,flags=4,value=v})
			end
		end 
		gg.setValues(toset)
		gg.toast('set '..menu[index])
		gg.setVisible(false)
	end 
end

contest_tasks_class = nil
menus['Complete Contest Assignments'] = function()
	if not contest_tasks_class then
		--[[
		gg.clearResults()
		gg.searchNumber(2000,4)
		local results = gg.getResults(-1)
		for i,v in ipairs(results) do
			results[i].address = v.address - 0x20 
			results[i].flags = 32 
		end 
		results = gg.getValues(results)
		local assignments_pointer = nil
		for i,v in ipairs(results) do 
			if v.value == 0x101000000C8 then 
				assignments_pointer = gg.getValues({{address=gg.getValues({{address=gg.getValues({{address=v.address+0x50,flags=32}})[1].value,flags=32}})[1].value,flags=32}})[1].value
				break 
			end 
		end 
		if not assignments_pointer or assignments_pointer == 0 then gg.toast('script broken') return true end
		contest_tasks_class = assignments_pointer
		]]
		gg.clearResults()
		gg.searchNumber('h F3 53 B3 A9 F7 63 02 A9 F9 6B 03 A9 F5 5B 01 A9 FB 73 04 A9 FE 2B 00 F9')
		if gg.getResultsCount() == 0 then gg.toast('tasks root broken') return true end
		local tasksroot = gg.getResults(1)[1].address
		gg.clearResults()
		gg.searchNumber(tasksroot,32)
		contest_tasks_class = gg.getResults(1)[1].address
	end
	gg.clearResults()
	gg.searchNumber(contest_tasks_class,32)
	local tasks = gg.getResults(-1)
	for i,v in ipairs(tasks) do 
		tasks[i].flags = 4
		tasks[i].address = v.address + 0x110
		tasks[i].value = 3 
	end
	gg.setValues(tasks)
	gg.toast('Completed all contest assignments')
	return true
end


--===========================================================
--      building tool
--===========================================================finding list
first_building_pointer = nil
building_list_start = {}
building_list_length = nil
building_pointers = {}
pointer2building_name_map = {}
function findBuildingListStart()
	local function saveBuildingList()
		gg.addListItems({{address=building_list_start[1].address,flags=32,name='Building List Start'}})
		local toget = {}
		for i = 1,building_list_length do
				toget[i] = {address=building_list_start[1].address + (i-1)*8,flags = 32}
			end
		toget = gg.getValues(toget)
		for i,v in ipairs(toget) do
			building_pointers[i] = v.value
			pointer2building_name_map[v.value] = i 
		end
	end
	gg.clearResults()
	gg.searchNumber(0x1400000064,32)
	local results = gg.getResults(-1)
	local check1 = {}
	for i,v in ipairs(results) do 
		results[i].address = v.address - 0xa8
	end 
	results = gg.getValues(results)
	local check1 = {}
	for i,v in ipairs(results) do 
		if v.value > 10000 then 
			check1[i] = {address=v.value,flags=32}
		end 
	end 
	check1 = gg.getValues(check1)
	local check2 = {}
	for i,v in pairs(check1) do
		if v.value > 10000 then  
			check2[i] = {address = v.value + 0x10, flags = 32}
		end
	end 
	check2 = gg.getValues(check2)
	for i,v in pairs(check2) do 
		check2[i].address = v.value
	end 
	check2 = gg.getValues(check2)
	for i,v in pairs(check2) do 
		if v.value == 0x6E65646973655220 then 
			building_list_start = {check1[i]}
			building_list_length = (gg.getValues({{address = results[i].address + 8, flags = 32}})[1].value - results[i].value)/8
			saveBuildingList()
			return
		end
	end 
	gg.toast('fast search failed. doing regular search.')
	gg.clearResults()
	gg.searchNumber('6E65646973657220h',gg.TYPE_QWORD)
	local results = gg.getResults(-1)
	for i,v in ipairs(results) do 
		results[i].address = v.address+8
	end
	results = gg.getValues(results)
	for i = 1,#results do
		if results[i].value == 0x7361625F6C616974 then
			first_building_pointer = results[i].address-0xc0
			break
		end
	end
	if first_building_pointer == nil then
		gg.toast('Error: couldnt find pointer list')
		return true
	end
	gg.clearResults()
	gg.searchNumber(first_building_pointer,gg.TYPE_QWORD)
	local results = gg.getResults(-1)
	local check = {}
	for i,v in ipairs(results) do 
		check[2*i-1] = {address = v.address + 0x1b8,flags = 32}
		check[2*i] = {address = v.address + 0x4008,flags = 32}
	end
	check = gg.getValues(check)
	for i,v in ipairs(results) do 
		check[2*i-1].address = check[2*i-1].value + 16
		check[2*i].address = check[2*i].value + 16
	end
	check = gg.getValues(check)
	for i,v in ipairs(results) do 
		check[2*i-1].address = check[2*i-1].value + 16
		check[2*i].address = check[2*i].value
	end
	check = gg.getValues(check)
	for i,v in ipairs(results) do 
		if (check[2*i-1].value & bytemask(0x64726F6A46)) == 0x64726F6A46 and check[2*i].value ~= 0  then 
			table.insert(building_list_start,results[i])
		end 
	end 
	if not building_list_start[1] then
		gg.toast('no lists found')
		return true
	end
	if not buildingListCheck() then 
		gg.toast('no valid lists found')
		return true
	end
	saveBuildingList()
end
  
function buildingListCheck()
	while #building_list_start > 0 do
		building_list_start = gg.getValues(building_list_start)
		if building_list_start[1].value ~= first_building_pointer then
			table.remove(building_list_start,1)
			building_list_length = nil
		elseif building_list_length == nil then
			gg.toast('checking pointer list')
			if buildingListCheckLength() then return true 
			end
		else
			return true
		end
	end
end

function buildingListCheckLength()
	gg.clearResults()
	gg.searchNumber(building_list_start[1].address,gg.TYPE_QWORD)
	if gg.getResultsCount() ~= 1 then
		table.remove(building_list_start,1)
	else
		local list_start = gg.getResults(1)
		local list_end = gg.getValues({{address=list_start[1].address+8,flags=32}})
		local length = (list_end[1].value - list_start[1].value)/8
		if length < 0 or length > 10000 then
			table.remove(building_list_start,1)
		else
			building_list_length = length
			return true
		end
	end	
end

--===========================================================file stuff
function orderedTableToString(tbl)
    local function serialize(o)
        if type(o) == "number" then
            return tostring(o)
        elseif type(o) == "string" then
            return string.format("%q", o)
        elseif type(o) == "table" then
            local s = "{"
            for _, v in ipairs(o) do
                s = s .. serialize(v) .. ","
            end
            return s .. "}"
        else
            error("cannot serialize a " .. type(o))
        end
    end

    return "return " .. serialize(tbl)
end

function file_exists(filename)
    local f = io.open(filename, "r")
    if f then
        f:close()
        return true
    else
        return false
    end
end

loaded_building_lists = {}
default_building_list_path = '/storage/emulated/0/Download/SCB_generated_building_list_'
--===========================================================menu
menus['Building Tool'] = function()
	if not building_list_start[1] then
		if findBuildingListStart() then return true end
	end
	local menu = {'Replace in Buy Menu + Factory','Replace Placed Buildings','Replace Specific Building','Factory Method','Pass Method','Generate List','Load List','Set production time to 1min','Change Multiplier','Unlock All Factory Items','Revert changed menu buildings and pass buildings','Go Back'}
	local index = gg.choice(menu)
	if index == nil then
		uiOpen = false
		gg.isVisible(false)
	elseif menu[index] == 'Go Back' then
		return true
	elseif menu[index] == 'Generate List' then
		generateBuildingListMenu()
	elseif menu[index] == 'Load List' then
		local path = gg.prompt({'Path to the list file'},{default_building_list_path .. 'full'},{'text'})
		if path and #path[1] ~= 0 then
			if file_exists(path[1]) then
				table.insert(loaded_building_lists,loadfile(path[1])())
				gg.toast('list saved to ' .. #loaded_building_lists)
			else
				gg.toast('cant find file')
			end
		end
	elseif menu[index] == 'Factory Method' then
		local l = inputBuildingIndex(11)
		if l then
			setBuildingPointersFactory(l)
		end
	elseif menu[index] == 'Replace Placed Buildings' then
		local target =  inputBuildingIndex(1,'Choose the building you wanna replace')
		if target then
			local replacement =  inputBuildingIndex(1,'Replaces all placed buildings after you go to Daniels city or reload the game. Usefull for getting rid of unbuldozable buildings. \n\n*Choose the building you wanna get*')
			if replacement then
				replaceBuilding(target[1],replacement[1])
			end
		end
	elseif menu[index] == 'Replace in Buy Menu + Factory' then
		replaceBuildingBuyMenuOnly()
	elseif menu[index] == 'Set production time to 1min' then
		setTime(60000)
	elseif menu[index] == 'Unlock All Factory Items' then
		unlockFactoryOnly()
	elseif menu[index] == 'Change Multiplier' then
		local input = gg.prompt({'enter item multiplier'},{'1000000'},{'number'})
		if input then
			setItemMultiplier(input)
		end
	elseif menu[index] == 'Revert changed menu buildings and pass buildings' then
		revertReplacedMenuBuilding()
	elseif menu[index] == 'Pass Method' then
		replacePassWithBuildings()
	elseif menu[index] == 'Replace Specific Building' then
		replaceSpecificBuilding()
	end
end

--===========================================================getting buildings
function setBuildingPointersFactory(array)
    if not factory_found then
        findFactory()
	end
	local toset = {}
	for i,v in ipairs(array) do
		toset[i] = {address =  FactoryItems[i].address , flags=32 , value = building_pointers[v]}
	end
    gg.setValues(toset)
	gg.toast('Done!')
	uiOpen = false
	gg.isVisible(false)
end

function replaceBuilding(target, repl)
	if not placed_buildings_root[1] then findPlacedBuildingRoot() end 
	local tag_check = {{address = building_pointers[target] + building_tag_offsets[1],flags = 32}}
	tag_check = gg.getValues(tag_check)
	tag_check[1].address = tag_check[1].value
	tag_check = gg.getValues(tag_check)
    gg.clearResults()
	if tag_check[1].value == 0x6E65646973655216 then
		gg.searchNumber(placed_buildings_root[1], 32)
	else
		gg.searchNumber(placed_buildings_root[2], 32)
	end
	local results = gg.getResults(-1)
	for i,v in ipairs(results) do 
		results[i].address = v.address + 0x60 
	end 
	results = gg.getValues(results)
	local toreplace = {}
	for i,v in ipairs(results) do 
		if v.value == building_pointers[target] then 
			table.insert(toreplace,{address=v.address,flags=32,value=building_pointers[repl]})
		end 
	end
	gg.setValues(toreplace)
    gg.toast('Replaced ' .. #toreplace .. ' buildings')
	uiOpen = false
	gg.isVisible(false)
end

function replaceSpecificBuilding()
	if not building_names[1] then generateBuildingNames() end
	if not placed_buildings_root[1] then findPlacedBuildingRoot() end 
	local group = gg.choice({'residential buildings','other buildings'})
	if placed_buildings_root[group] then 
		gg.clearResults()
		gg.searchNumber(placed_buildings_root[group],gg.TYPE_QWORD)
		local results = gg.getResults(-1)
		while true do
			local index = gg.multiChoice(generatePlacedBuildingsList(results))
			if not index then return end
			local repl = inputBuildingIndex(1,'Pick Building to replace with\nwill apply after going to another city or restarting the game')
			if repl then
				local toset = {}
				for i in pairs(index) do
					table.insert(toset,{address = results[i].address + 0x60, flags = 32, value = building_pointers[repl[1] ]})
				end
				gg.setValues(toset)
				gg.toast(#toset .. ' buildings repalced')
			end
		end 
	end 
end

--===========================================================build menu
building_replace_menus = {'Government Buildings','Parks'}
building_menu_pointers = {}
menu_building_names = {{'Town Hall','Material Storage','City Storage','City Hall','Mayors Mansion','Department of Epic Projects','Neo Bank','Research Center','Research Booster','OMEGA Lab','OMEGA Storage'},{'Small Fountain Park','Modern Art Park','Plumbob Park','University Park Cafeteria','University Park Quad','Reflecting Pool Park','Llarry the Llama','Paceful Park','Urban Plaza','Worlds Largest Ball of Twine','Sculpture Garden'}}
menu_building_values = {{
	{'1val',0x61485F7974694312},
	{'2val',{0x6169726574614D26,0x314C5F65,16}},
	{'2val',{0x445F65646172541C,0x314C5F746F7065,8}},
	{'1val',0x7469435F6769421A},
	{'1val',0x5F73726F79614D1C},
	{'1val',0x51485F6F7265480E},
	{'2val',{0x5F6D69536F654E1C;0x314C5F6B6E6142,8}},
	{'1val',0x5F6572757475461C},
	{'1+1val',{0x67656D4F5F333455,0x6172676F6C6F482C}},
	{'2val',{0x614C6167656D4F1E,0x79726F7463614662,8}},
	{'2val',{0x5F65727574754622,0x314C,16}},
},{
	{'2val',{0x6F465F6B7261501A,0x6E6961746E75,8}},
	{'1val',0x5F6E7265646F4D14},
	{'1val',0x626F626D756C5018},
	{'1+1val',{0x63536F546B636142,0x73726576696E5528}},
	{'1+1val',{0x63536F546B636142,0x73726576696E5520}},
	{'1val',0x6F505F6B72615012},
	{'1val',0x535F616D616C4C18},
	{'2val',{0x614E5F6B7261501A,0x315F65727574,8}},
	{'2val',{0x614E5F6B7261501A,0x325F65727574,8}},
	{'1val',0x425F656E69775414},
	{'2val',{0x6C505F6B72615018,0x325F617A61,8}},
}}
searchMenuBuilding = {}
searchMenuBuilding['1val'] = function(val)
	gg.clearResults()
	gg.searchNumber(val,gg.TYPE_QWORD)
	local results = gg.getResults(-1)
	local check = {}
	for i,v in ipairs(results) do 
		check[i] = {address = v.address + 24,flags = 32}
	end 
	check = gg.getValues(check)
	for i,v in ipairs(check) do 
		check[i].address = v.value + 16
	end 
	check = gg.getValues(check)
	for i,v in ipairs(check) do 
		check[i].address = v.value
	end 
	check = gg.getValues(check)
	for i,v in ipairs(results) do 
		if v.value == check[i].value then 
			return gg.getValues({{address = v.address+24,flags=32}})[1]
		end 
	end 
	gg.alert('couldnt find '..nToString(val))
end

searchMenuBuilding['2val'] = function(val)
	gg.clearResults()
	gg.searchNumber(val[1],gg.TYPE_QWORD)
	local results = gg.getResults(-1)
	local check = {}
	for i,v in ipairs(results) do 
		check[2*i-1] = {address = v.address + val[3],flags = 32}
		check[2*i] = {address = v.address + 24,flags = 32}
	end 
	check = gg.getValues(check)
	for i in ipairs(results) do 
		check[2*i].address = check[2*i].value + 16
	end 
	check = gg.getValues(check)
	for i in ipairs(results) do 
		check[2*i].address = check[2*i].value
	end 
	check = gg.getValues(check)
	for i,v in ipairs(results) do 
		if (check[2*i-1].value & bytemask(val[2])) == val[2] and v.value == check[2*i].value then 
			return gg.getValues({{address = v.address+24,flags=32}})[1]
		end 
	end 
	gg.alert('couldnt find '..nToString(val[1]))
end

searchMenuBuilding['1+1val'] = function(val)
	gg.clearResults()
	gg.searchNumber(val[2],gg.TYPE_QWORD)
	local results = gg.getResults(-1)
	local check = {}
	for i,v in ipairs(results) do
		check[i] = {address = v.address - 0x28,flags = 32}
	end
	check = gg.getValues(check)
	for i,v in ipairs(check) do
		check[i].address = v.value + 0x10
	end
	check = gg.getValues(check)
	for i,v in ipairs(check) do
		check[i].address = v.value
	end
	check = gg.getValues(check)
	local pointer = nil
	for i,v in ipairs(results) do 
		if check[i].value == val[1] then 
			pointer = v.address - 0x38
			break
		end
	end
	if pointer == nil then
		gg.alert('e: couldnt find '..nToString(val[2]))
		return
	end
	gg.clearResults()
	gg.searchNumber(pointer,gg.TYPE_QWORD)
	local results = gg.getResults(-1)
	local check = {}
	for i,v in ipairs(results) do 
		check[i] = {address = v.address - 8,flags = 32}
	end 
	check = gg.getValues(check)
	for i,v in ipairs(check) do 
		check[i].address = v.value
	end
	check = gg.getValues(check)
	for i,v in ipairs(check) do 
		if v.value == val[1] then 
			return results[i]
		end
	end 
	gg.alert('couldnt find '..nToString(val[2]))
end

function findMenuBuildings(group)
	building_menu_pointers[group] = {}
	gg.setVisible(false)
	for i,v in ipairs(menu_building_values[group]) do 
		gg.toast('finding '..menu_building_names[group][i])
		building_menu_pointers[group][i] = searchMenuBuilding[ v[1] ](v[2])
	end 
	gg.setVisible(true)
end

function replaceBuildingBuyMenuOnly()
	local group = gg.choice(building_replace_menus,nil,'Choose which buildings to replace')
	if group then
		if not building_menu_pointers[group] then 
			findMenuBuildings(group)
		end
		local array = inputBuildingIndex(11,'Lets you place any building by replacing buildings in the build menu. You may need to produce some buildings in the factory for them to show up.\n\nChoose the building you wanna get')
		if not array then
			return
		end
		local menu = {'All'}
		for i,v in ipairs(menu_building_names[group]) do 
			table.insert(menu,v)
		end
		local index = gg.choice(menu,nil,'Building to replace:')
		if index then 
			if index == 1 then 
				replaceAll11MenuBuildings(array,group)
			else 
				gg.setValues({{address = building_menu_pointers[group][index - 1].address , flags = 32 , value = building_pointers[array[1] ]}})
				setBuildingPointersFactory({array[1]})
			end 
		end
	end
end

function replaceAll11MenuBuildings(array,menu)
	gg.setVisible(false)
	local toset = {}
	for i,v in ipairs(array) do
		toset[i] = {address = building_menu_pointers[menu][i].address,flags=32,value = building_pointers[v]}
	end
    gg.setValues(toset)
	setBuildingPointersFactory(array)
end

function revertReplacedMenuBuilding()
	for i,v in ipairs(building_menu_pointers) do 
		gg.setValues(v)
	end 
	if material_storage_pointers[1] then 
		gg.setValues(material_storage_pointers)
	end 
end

--===========================================================pass
material_storage_pointers = {}
building_pass_spec = {}
pass_building_names = {}
ms_start = nil
function findMaterialStoragePointers(num_bldns)
	local max_num = 76
	local function searchCheck(i)
		gg.toast('finding pass buildings '..i..'/'..num_bldns)
		gg.clearResults()
		gg.searchNumber(building_pointers[i+ms_start],gg.TYPE_QWORD)
		local results = gg.getResults(-1)
		local check = {}
		for j,v in ipairs(results) do
			check[j] = {address = v.address - 0x18,flags = 32}
		end
		check = gg.getValues(check)
		for j,v in ipairs(results) do 
			if check[j].value == pass_building_names[3*i-2].value then 
				return v 
			end 
		end 
		gg.alert('couldnt find '.. i)
	end
	gg.setVisible(false)
	if not material_storage_pointers[1] then
		material_storage_pointers[1] = searchMenuBuilding['2val']({0x6169726574614D28,0x41314C5F65,16})
		if not material_storage_pointers[1] then return end
		ms_start = pointer2building_name_map[material_storage_pointers[1].value] - 1
		if not ms_start then 
			gg.alert('couldnt find pointer in building list')
			return 
		end
		for i = 1,76 do 
			pass_building_names[3*i-2] = {address=building_pointers[i+ms_start]+16,flags=32}
		end 
		pass_building_names = gg.getValues(pass_building_names)
		for i = 1,76 do 
			pass_building_names[3*i-2].address = pass_building_names[3*i-2].value
			pass_building_names[3*i-1] = {address = pass_building_names[3*i-2].value+8,flags=32}
			pass_building_names[3*i] = {address = pass_building_names[3*i-2].value+16,flags=32}
		end 
		pass_building_names = gg.getValues(pass_building_names)
	end
	for i = #material_storage_pointers+1,num_bldns do 
		local next_pointer = gg.getValues({{address = material_storage_pointers[i-1].address + 0x60,flags=32}})
		if next_pointer[1].value == building_pointers[i+ms_start] then 
			material_storage_pointers[i] = next_pointer[1]
		else
			material_storage_pointers[i] = searchCheck(i)
			if not material_storage_pointers[i] then return end
		end 
	end 
	for i = 1,num_bldns do
		building_pass_spec[i] = {pass_building_names[3*i-2].value,pass_building_names[3*i-1].value,pass_building_names[3*i].value}
	end
	return true
end

function replacePassWithBuildings()
	local lengths = {10,20,35,35,38}
	local menu = {}
	for i in pairs(found_lvls) do 
		menu[i] = 'VP lvl ' .. i 
	end 
	if MP_add then 
		menu[5] = 'Mayor Pass'
	end 
	local index = gg.choice(menu,nil,'This replaces the pointers for the first 38 lvls of material storage buildings to put buildings in the pass without crashes.\nLets you see what the buildings look like.\nNeed to do it on the contest menu if you are using mayor pass.\n\n*Pick Pass*')
	if index == nil then return end
	local use_premium_tiers = yesNoPrompt('use premium tiers?')
	local selected_length =lengths[index] * (use_premium_tiers and 2 or 1)
	local array = inputBuildingIndex(selected_length)
	if array == nil then return end
	local q = gg.prompt({'quantity'},{1000000},{'number'})
	if q == nil or #q[1] == 0 then return end
	gg.setVisible(false)
	if not material_storage_pointers[selected_length] then 
		if not findMaterialStoragePointers(selected_length) then return end
	end
	local toset = {}
	for i = 1,selected_length-#array do 
		toset[i] = {address = material_storage_pointers[i].address,flags=32,value=0}
	end
	for i,v in ipairs(array) do
		table.insert(toset,{address = material_storage_pointers[selected_length-i+1].address,flags=32,value=building_pointers[v]})
	end
	gg.setValues(toset)
	local start = nil
	if index == 5 then 
		start = MP_add
	else 
		start = VP_add[index]
	end
	changeAllRewards(start,{0x6C62617466696722,0x69646C6975625F65,0x676E},building_pass_spec,selected_length,q[1],use_premium_tiers)
	gg.toast('Rewards Changed')
	uiOpen = false
end

--===========================================================picking buiildings
function inputBuildingIndex(n,info)
	while true do 
		index = gg.choice({'Enter Index','Search List','Browse List'},nil,info)
		local output = {}
		if index == nil then
			return
		elseif index == 1 then
			local input = gg.prompt({'enter index 1 ~ ' .. (building_list_length)},{},{'number'})
			if input and #input[1] ~= 0 and tonumber(input[1])>0 and tonumber(input[1])<=building_list_length then
				for i = 0,math.min(n-1,building_list_length-input[1]) do
					output[i+1] = input[1]+i
				end
				return output
			end
		else
			local lists = {}
			for i in pairs(loaded_building_lists) do
				lists[i] = i
			end
			while true do
				local list = gg.choice(lists,nil,'choose list')
				if list then
					if index == 2 then
						output = searchBuildingList(loaded_building_lists[list],n)
					elseif index == 3 then
						output = browseBuildingList(loaded_building_lists[list],n)
					end
					if output and output[1] then
						return output
					end
				else
					break 
				end 
			end
		end
	end
end
  
function searchBuildingList(list,n)
	local indices = {}
	local menu = {}
	local function createResultMenu()
		menu = {'Search'} 
		indices = {1} 
		local input = gg.prompt({'search'},{},{'text'})
		if input and #input[1] ~= 0 then
			local words = {}
			local pattern = "([^ ]+)"
			for part in string.gmatch(input[1], "([^ ]+)") do
				table.insert(words, part)
			end
			for i, v in ipairs(list) do
				for j,w in ipairs(words) do
					if not v[1]:lower():find(w, nil, true) then
						goto no_match
					end
				end
				table.insert(menu,v[1])
				table.insert(indices,v[2])
				::no_match::
			end
		end
		return menu
	end
	local function outputIndex(list_index)
		local output = {}
		for i = 0,math.min(n-1,#indices-list_index) do
			output[i+1] = indices[list_index + i]
		end
		return output
	end
	while true do
		local index = gg.choice(createResultMenu())
		if index == nil then
			return
		elseif index ~= 1 then
			return outputIndex(index)
		end
	end
end

browse_buildings_page_size = 25
function browseBuildingList(list,n)
	local page = 1
	local menu = {}
	local indices = {}
	local function changePage()
		local input = gg.prompt({'change page 1 ~ ' .. (((#list-1)//browse_buildings_page_size)+1)},{},{'number'})
		if input and #input[1] ~= 0 and tonumber(input[1])>0 and tonumber(input[1])<=((#list//browse_buildings_page_size)+1) then
			page = tonumber(input[1])
		end
	end
	local function changePageSize()
		local input = gg.prompt({'change number of items per page'},{25},{'number'})
		if input and #input[1] ~= 0 and tonumber(input[1])>0 then
			browse_buildings_page_size = input[1]
		end
	end
	local function outputIndex(list_index)
		local output = {}
		for i = 0,math.min(n-1,#indices-list_index) do
			output[i+1] = indices[list_index + i]
		end
		return output
	end
	local function generatePage()
		menu = {'Change Page','Change Page Size'}
		indices = {1,1}
		for i = 1,math.min(browse_buildings_page_size,#list-((page-1)*browse_buildings_page_size)) do
			table.insert(menu,list[(page-1)*browse_buildings_page_size + i][1])
			table.insert(indices,list[(page-1)*browse_buildings_page_size + i][2])
		end 
		if page < ((#list//browse_buildings_page_size)+1) then
			table.insert(menu,'Next Page')
		end
	end
	while true do
		generatePage()
		local index = gg.choice(menu,nil,'page: ' .. page .. '/' .. ((#list-1)//browse_buildings_page_size)+1)
		if index == nil then
			return
		elseif index == 1 then
			changePage()
		elseif index == 2 then
			changePageSize()
		elseif index == #menu and page < ((#list//browse_buildings_page_size)+1) then
			page = page + 1
		else
			return outputIndex(index)
		end
	end
end

--===========================================================generating lists
function saveBuildinglist(tbl,name)
	local path = gg.prompt({'Enter path to which to write the list file to:\nif you dont want to save the list, press cancel'},{default_building_list_path .. name},{'text'})
	if path then
		local file = io.open(path[1], "w")
		if file then
			file:write(orderedTableToString(tbl))
			file:close()
			gg.toast('list saved')
		else
			gg.toast('invalid path')
		end
	end
end

building_names = {}
function generateBuildingNames()
	gg.toast('generating name list')
	local toget = {}
	for i = 1,building_list_length do
		toget[i] = {address=building_list_start[1].address + (i-1)*8,flags = 32}
	end
	toget = gg.getValues(toget)
	for i,v in ipairs(toget) do
		toget[i].address = v.value + 16
	end
	toget = gg.getValues(toget)
	for i,v in ipairs(toget) do
		toget[i].address = v.value
	end
	toget = gg.getValues(toget)
	local lengths = {}
	local name_ptrs = {}
	for i,v in ipairs(toget) do
		if math.abs(v.value) < 1000 then 
			lengths[i] = {address = v.address+8,flags=4}
			name_ptrs[i] = {address = v.address+16,flags=32}
		end
	end
	lengths = gg.getValues(lengths)
	name_ptrs = gg.getValues(name_ptrs)
	local name_bytes = {}
	for i,v in ipairs(toget) do
		local start = v.address + 1 
		local length = 23
		if name_ptrs[i] then 
			start = name_ptrs[i].value
			length = lengths[i].value
		end
		for j = 1,length do 
			name_bytes[(i-1)*48+j] = {address = start + j - 1 , flags = 1}
		end 
	end 
	name_bytes = gg.getValues(name_bytes)
	for i in pairs(toget) do 
		local bytes = {}
		for j = 1,48 do 
			local b = name_bytes[(i-1)*48+j]
			if not b or not ((b.value >= 0x30 and b.value <= 0x39) or (b.value >= 0x41 and b.value <= 0x5a) or (b.value >= 0x61 and b.value <= 0x7a) or b.value == 0x5f) then
				break 
			end
			table.insert(bytes,b.value) 
		end 
		building_names[i] = string.char(table.unpack(bytes))
	end
end


function getFullBuildingList()
	if not building_names[1] then generateBuildingNames() end
	local tbl = {}
	for i = 1,building_list_length do
		table.insert(tbl,{building_names[i],i})
	end 
	loaded_building_lists['all'] = tbl
	gg.toast('list loaded')
	saveBuildinglist(tbl,'full')
end

function getBuildingListWithTag(tag_group,tag_name)
	local tag = building_tags[tag_group][tag_name]
	if not building_names[1] then generateBuildingNames() end 
	local tag_check = {}
	for i,v in pairs(pointer2building_name_map) do 
		tag_check[v] = {address = i + building_tag_offsets[tag_group] , flags = 32}
	end
	tag_check = gg.getValues(tag_check)
	for i,v in pairs(tag_check) do 
		tag_check[i].address = v.value
	end
	tag_check = gg.getValues(tag_check)
	local tbl = {}
	for i,v in pairs(tag_check) do 
		if v.value & bytemask(tag) == tag then 
			table.insert(tbl,{building_names[i],i})
		end 
	end
	loaded_building_lists[building_tag_group_names[tag_group]..' '..tag_name] = tbl
	gg.toast('list loaded')
	saveBuildinglist(tbl,building_tag_group_names[tag_group]..'_'..tag_name)
end

function getAllTagBuildingLists(tag_group)
	gg.toast('generating lists')
	if not building_names[1] then generateBuildingNames() end 
	local tag_check = {}
	for i,v in pairs(pointer2building_name_map) do 
		tag_check[v] = {address = i + building_tag_offsets[tag_group] , flags = 32}
	end
	tag_check = gg.getValues(tag_check)
	for i,v in pairs(tag_check) do 
		tag_check[i].address = v.value
	end
	tag_check = gg.getValues(tag_check)
	local tbl = {}
	local lookup = {}
	for i,v in pairs(building_tags[tag_group]) do 
		lookup[v] = i
		tbl[v] = {}
	end
	for i,v in pairs(tag_check) do 
		for j in pairs(tbl) do
			if v.value & bytemask(j) == j then
				table.insert(tbl[j],{building_names[i],i})
				break 
			end 
		end 
	end
	for i,v in pairs(tbl) do
		loaded_building_lists[building_tag_group_names[tag_group]..' '.. lookup[i]] = v
	end 
	gg.toast('lists loaded')
end

function generateBuildingListMenu()
	while true do 
		local index = gg.choice({'generate full list','filter by tags'},nil,'note: generated names will be different from ingame names')
		if index == nil then 
			return 
		elseif index == 1 then 
			getFullBuildingList()
			return
		else
			while true do 
				local tag_group_index = gg.choice(building_tag_group_names,nil,'tag groups')
				if tag_group_index == nil then
					break 
				else 
					local menu = {'Generate All Lists'}
					for i in pairs(building_tags[tag_group_index]) do
						menu[i] = i 
					end
					local tag_index = gg.choice(menu,nil,'tags')
					if tag_index == 1 then
						getAllTagBuildingLists(tag_group_index)
						return
					elseif tag_index then 
						getBuildingListWithTag(tag_group_index,tag_index)
						return 
					end 
				end 
			end 
		end 
	end 
end
	
building_tag_offsets = {0xe8,0xf0,0xf8,0x100,0x108}
building_tag_group_names = {'tag1','tag2','tag3','tag4','tag5',}
building_tags = {{
['commercial'] = 0x6372656D6D6F4314,
['industial'] = 0x72747375646E4914,
['plopable'] = 0x626170706F6C5012,
['great project'] = 0x7250746165724718,
['residential'] = 0x6E65646973655216,
},
{
['drone'] = 0x0000656E6F72440A,
['control net'] = 0x6C6F72746E6F4314,
['power'] = 0x00007265776F500A,
['water'] = 0x000072657461570A,
['sewage'] = 0x006567617765530C,
['government'] = 0x6D6E7265766F4714,
['depot']  = 0x0000746F7065440A,
['regional depot'] = 0x525F746F7065441C,
['material storage'] = 0x6169726574614D1E,
['region material storage'] = 0x0000000000000021,
['maxis manor'] = 0x614D736978614D14,
['waste'] = 0x000065747361570A,
['fire'] = 0x0000006572694608,
['health'] = 0x0068746C6165480C,
['police'] = 0x006563696C6F500C,
['organic'] = 0x63696E6167724F16,
['tourist'] = 0x74736972756F5416,
['heating'] = 0x676E69746165480E,
['gas'] = 0x73614706,
['street food'] = 0x4674656572745314,
['education'] = 0x6974616375644512,
['transportation'] = 0x6F70736E6172541C,
['parks'] = 0x0000736B7261500A,
['gambling'] = 0x6E696C626D614710,
['zone'] = 0x000000656E6F5A08,
['space'] = 0x000065636170530A,
['entertainment'] = 0x61747265746E451A,
['landmark'] = 0x72616D646E614C10,
['landscape'] = 0x616373646E614C12,
['boardwalk'] = 0x61776472616F4212,
['mountain'] = 0x6961746E756F4D10,
['mining'] = 0x00676E696E694D0C,
['construction'] = 0x757274736E6F4318,
['trains'] = 0x00736E696172540C,
['worship (mayor pass)'] = 0x70696873726F570E,
},
{
['construction regional'] = 0x757274736E6F432A,
['holiday shop'] = 0x796164696C6F4826,
['mimic shop'] = 0x685363696D694D12,
['theme - asian'] = 0x685363696D694D12,
['airport'] = 0x74726F707269410E,
['theme - paris'] = 0x505F656D65685416,
['theme - london'] = 0x4C5F656D65685418,
['theme - greendream'] = 0x475F656D65685420,
['theme - desert'] = 0x445F656D65685418,
['desert'] = 0x007472657365440C,
['theme - lagoon'] = 0x4C5F656D65685418,
['theme - fjoyd'] = 0x465F656D65685416,
['theme - limestone'] = 0x4C5F656D6568541E,
['hero building (epic project)'] = 0x75425F6F7265481A,
['theme - future'] = 0x465F656D65685418,
['theme - latin'] = 0x4C5F656D65685416,
['theme - medieval'] = 0x4D5F656D6568541C,
['theme - nouveau'] = 0x4E5F656D6568541A,
['theme - florance'] = 0x465F656D6568541C,
['power green'] = 0x475F7265776F5016,
['power dirty'] = 0x445F7265776F5016,
['power hightech'] = 0x485F7265776F501C,
['vu tower'] = 0x7265776F5475560E,
['ship terminal'] = 0x7265547069685318,
['education basic'] = 0x697461637564451E,
['education advanced'] = 0x6974616375644524,
['education higher'] = 0x6974616375644520,
['transportation ground'] = 0x6F70736E6172542A,
['transportation air'] = 0x6F70736E61725424,
['none'] = 0x00000656E6F4E08,
['moonscape'] = 0x6163736E6F6F4D12,
['outback'] = 0x6B63616274754F0E,
['river'] = 0x000072657669520A,
['highline'] = 0x6E696C6867694810,
['city wall'] = 0x6C61777974694310,
['floating'] = 0x6E6974616F6C4610,
['pier'] = 0x0000007265695008,
['orchard'] = 0x6472616863724F0E,
['modular'] = 0x72616C75646F4D0E,
['pasture'] = 0x657275747361500E,
['district'] = 0x6369727473694410,
['railroad station'] = 0x616F726C6961521E,
['railroad track building'] = 0x616F726C6961522A,
['procedural mountain']= 0x756465636F725024,
['procedural volcano'] = 0x756465636F725022,
['hotsprings'] = 0x69727053746F4814,
['savannah'] = 0x616E6E6176615310,
['venice'] = 0x006563696E65560C,
['bridge'] = 0x006567646972420C,
},
{
['airport'] = 0x74726F707269410E,
['service'] = 0x656369767265530E,
['cityhall'] = 0x6C61487974694310,
['depot'] = 0x0000746F7065440A,
['material storage'] = 0x6169726574614D1E,
['future storage'] = 0x536572757475461A,
['mayors mansnsion'] = 0x4D73726F79614D1A,
['vu tower'] = 0x7265776F5475560E,
['trade hq'] = 0x514865646172540E,
['ship terminal'] = 0x7265547069685318,
['truck terminal'] = 0x65546B637572541A,
['ad billboard'] = 0x626C6C6942644116,
['ad billboard vertical'] = 0x626C6C6942644126,
['competition tower'] = 0x697465706D6F4320,
['big city hall'] = 0x7974694367694216,
['hero hq'] = 0x0051486F7265480C,
['merchant shop'] = 0x6E61686372654D18,
['future academny'] = 0x416572757475461A,
['omega lab'] = 0x614C6167656D4F10,
['neosim bank'] = 0x426D69536F654E14,
['clan house'] = 0x756F486E616C4312,
['war submarine'] = 0x6D62755372615718,
['war delivery'] = 0x696C654472615716,
['regional delivery'] = 0x616E6F6967655220,
['monster'] = 0x726574736E6F4D0E,
['zone'] = 0x00000656E6F5A08,
['production'] = 0x746375646F725014,
['service mountain'] = 0x656369767265531E,
['service boardalk'] = 0x6563697672655320,
},
{
['apex'] = 0x000007865704108,
}}

--===========================================================moving buildings
placed_buildings_root = {}
function findPlacedBuildingRoot() 
	gg.toast('Searching for trade HQ')
	gg.clearResults()
	gg.searchNumber('42C8000043200000h',gg.TYPE_QWORD)
	local results = gg.getResults(-1)
	local check = {}
	for i,v in ipairs(results) do 
		check[i] = {address=v.address + 0x40,flags = 32}
	end 
	check = gg.getValues(check)
	for i,v in ipairs(check) do 
		check[i].address = v.value + 0x10
	end 
	check = gg.getValues(check)
	for i,v in ipairs(check) do 
		check[i].address = v.value
	end 
	check = gg.getValues(check)
	for i,v in ipairs(check) do 
		if v.value == 0x485F656461725410 then 
			placed_buildings_root[2] = gg.getValues({{address = results[i].address - 0x20, flags = 32}})[1].value
			placed_buildings_root[1] = placed_buildings_root[2] + 0x780
			gg.addListItems({{address=placed_buildings_root[1],flags=32,name='Residential buildings root'},{address=placed_buildings_root[2],flags=32,name='Other buildings root'}})
			return 
		end
	end
	gg.toast('error couldnt find trade HQ')
	return true 
end

function generatePlacedBuildingsList(results)
	local info = {}
	for i,v in ipairs(results) do
		info[i*6-5] = {address=v.address + 0x60,flags = 32}
		info[i*6-4] = {address=v.address + 0x18,flags = 16}
		info[i*6-3] = {address=v.address + 0x1c,flags = 16}
		info[i*6-2] = {address=v.address + 0x28,flags = 16}
		info[i*6-1] = {address=v.address + 0x20,flags = 16}
		info[i*6] = {address=v.address + 0x24,flags = 16}
	end
	info = gg.getValues(info)
	local list = {}
	for i,v in ipairs(results) do
		list[i] = string.format('%s (%.0f,%.0f) %.0f° %.0f×%.0f',building_names[pointer2building_name_map[info[i*6-5].value] ],info[i*6-4].value,info[i*6-3].value,info[i*6-2].value*rad2deg,info[i*6-1].value,info[i*6].value)
	end
	return list
end

menus['Move Buildings'] = function()
	if not building_list_start[1] then
		if findBuildingListStart() then return true end
	end
	local move_menu = {'Move Buildings','Shift buildings','Rotate Buildings','Resize Buildings','Precise Move','Arrange Buildings in a Circle','Select All','Deselct All','Go Back'}
	if not building_names[1] then generateBuildingNames() end
	if not placed_buildings_root[1] then findPlacedBuildingRoot() end 
	local group = gg.choice({'residential buildings','other buildings'})
	if not placed_buildings_root[group] then return true end
	gg.clearResults()
	gg.searchNumber(placed_buildings_root[group],gg.TYPE_QWORD)
	local results = gg.getResults(-1)
	local selection = {}
	while true do gg.sleep(30)
		if gg.isClickedUiButton() then
			uiOpen = true
		end 
		if uiOpen then 
			local move_type = gg.choice(move_menu)
			if not move_type then 
				uiOpen = false 
				gg.setVisible(false)
			elseif move_type == #move_menu then return 
			elseif move_type == #move_menu - 1 then
				selection = {}
			elseif move_type == #move_menu - 2 then
				for i in ipairs(results) do 
					selection[i] = true
				end
			else
				local index = gg.multiChoice(generatePlacedBuildingsList(results),selection)
				if index then 
					selection = index
					local selected_buildings = {}
					for i in pairs(index) do 
						table.insert(selected_buildings,results[i].address)
					end 
					if selected_buildings[1] then moveFuncs[move_menu[move_type] ](selected_buildings) end
				end
			end
		end 
	end 
end

circle_args = {0,0,160,0,0}
moveFuncs = {
['Move Buildings'] = function(b)
	local info = gg.getValues({{address = b[1] + 0x18,flags = 16},{address = b[1] + 0x1c,flags = 16}})
	local input = gg.prompt({'city buildings snap to grid\n1 grid square = 40\n\nx','y'},{info[1].value,info[2].value})
	if not input then return end
	local toset = {}
	for i,v in ipairs(b) do 
		table.insert(toset,{address = v + 0x18, flags = 16, value = input[1]})
		table.insert(toset,{address = v + 0x1c, flags = 16, value = input[2]})
	end
	gg.setValues(toset)
	local toset = {}
	for i,v in ipairs(b) do 
		toset[i] = {address = v + 0x18, flags = 16, value = input[1] + 0.4}
	end
	gg.setValues(toset)
end,

['Shift buildings'] = function(b)
	local input = gg.prompt({'40 = 1 grid square\n\nx shift','y shift'},{0,0})
	if not input then return end
	local info = {}
	for i,v in ipairs(b) do
		info[i*2-1] = {address = v + 0x18,flags = 16}
		info[i*2] = {address = v + 0x1c,flags = 16}
	end
	info = gg.getValues(info)
	local toset = {}
	for i,v in ipairs(b) do
		table.insert(toset,{address = v + 0x18, flags = 16, value = info[i*2-1].value + input[1]})
		table.insert(toset,{address = v + 0x1c, flags = 16, value = info[i*2].value + input[2]})
	end
	gg.setValues(toset)
	for i in ipairs(b) do
		toset[i*2-1].value = toset[i*2-1].value + 0.4
	end
	gg.setValues(toset)
end,

['Rotate Buildings'] = function(b)
	local info = gg.getValues({{address = b[1] + 0x28,flags = 16}})
	local input = gg.prompt({'0 = east\n90 = north\n-90 = south\nsnap to the next 45 deg angle after reloading'},{info[1].value*rad2deg})
	if not input then return end
	local rad = input[1]*deg2rad
	local toset = {}
	for i,v in ipairs(b) do 
		table.insert(toset,{address = v + 0x28, flags = 16, value = rad})
	end
	gg.setValues(toset)
	local pos = {}
	for i,v in ipairs(b) do
		pos[i] = {address = v + 0x18,flags = 16}
	end
	pos = gg.getValues(pos)
	for i,v in ipairs(pos) do 
		pos[i].value = v.value + 0.4
	end
	gg.setValues(pos)
end,

['Resize Buildings'] = function(b)
	local input = gg.prompt({'resets after reloading\n\nwidth','length'},{40,40})
	if not input then return end
	local toset = {}
	for i,v in ipairs(b) do 
		table.insert(toset,{address = v + 0x20, flags = 16, value = input[1]})
		table.insert(toset,{address = v + 0x24, flags = 16, value = input[2]})
	end
	gg.setValues(toset)
end,

['Precise Move'] = function(b)
	local info = gg.getValues({{address = b[1] + 0x18,flags = 16},{address = b[1] + 0x1c,flags = 16}})
	local input = gg.prompt({'changes the dimensions of buildings to control how they snap\n\nx','y'},{info[1].value,info[2].value})
	if not input then return end
	local toset = {}
	local width = ((input[1] % 40) * 2)
	local length = ((input[2] % 40) * 2)
	for i,v in ipairs(b) do 
		table.insert(toset,{address = v + 0x18, flags = 16, value = input[1]})
		table.insert(toset,{address = v + 0x1c, flags = 16, value = input[2]})
		table.insert(toset,{address = v + 0x20, flags = 16, value = width})
		table.insert(toset,{address = v + 0x24, flags = 16, value = length})
		table.insert(toset,{address = v + 0x2c, flags = 4, value = 0})
	end
	gg.setValues(toset)
	local toset = {}
	for i,v in ipairs(b) do 
		toset[i] = {address = v + 0x18, flags = 16, value = input[1] + 0.4}
	end
	gg.setValues(toset)
end,

['Arrange Buildings in a Circle'] = function(b)
	local input = gg.prompt({'center x','center y','radius','buildings rotation\n0 = facing away from center\n90 = counter clockwise','circle rotation offset'},circle_args)
	if not input then return end
	circle_args = input
	local theta = {}
	local xcord = {}
	local ycord = {}
	local building_rotation = input[4] * deg2rad
	for i = 1,#b do 
		theta[i] = (i*pi*2)/#b  + input[5] * deg2rad
		xcord[i] = math.cos(theta[i])*input[3] + input[1]
		ycord[i] = math.sin(theta[i])*input[3] + input[2]
	end
	local toset = {}
	for i,v in ipairs(b) do 
		table.insert(toset,{address = v + 0x18, flags = 16, value = xcord[i]})
		table.insert(toset,{address = v + 0x1c, flags = 16, value = ycord[i]})
		table.insert(toset,{address = v + 0x20, flags = 16, value = ((xcord[i] % 40) * 2)})
		table.insert(toset,{address = v + 0x24, flags = 16, value = ((ycord[i] % 40) * 2)})
		table.insert(toset,{address = v + 0x28, flags = 16, value = theta[i] + building_rotation})
		table.insert(toset,{address = v + 0x2c, flags = 4, value = 0})
	end
	gg.setValues(toset)
	local toset = {}
	for i,v in ipairs(b) do 
		toset[i] = {address = v + 0x18, flags = 16, value = xcord[i] + 0.4}
	end
	gg.setValues(toset)
end,
}



local cache_autocheckupdate = io.open(cache_autocheckupdate_path, "r")  
if cache_autocheckupdate then
	local cache = cache_autocheckupdate:read("*a")
    cache_autocheckupdate:close()
	if cache == 'ON' then
		local response = gg.makeRequest(download_url,download_cookie).content
		if response then
			local _,version_t = response:find('versionTitle')
			local latest_version = response:sub(response:find('>',version_t)+1,response:find('<',version_t)-1)
			if versionGreater(latest_version,current_version) then
				gg.setVisible(true)
				menus['menuLoop']('Check for Updates')
			end
		end
	end
end


local search_regions = {gg.REGION_C_ALLOC,gg.REGION_OTHER,gg.REGION_ANONYMOUS,gg.REGION_C_ALLOC | gg.REGION_OTHER | gg.REGION_ANONYMOUS}
local cached_ranges = io.open(cached_ranges_path, "r")  
if cached_ranges then
	local cache = tonumber(cached_ranges:read("*a"))
	if search_regions[cache] then
		gg.setRanges(search_regions[cache])
	end
    cached_ranges:close()
else
	local select_search_regions = gg.choice({'c_alloc','other','anonymous','c_alloc, other, and anonymous','dont change ranges'},nil,'*select search ranges*\nldplayer and bluestacks need c_alloc\nmumu 12 needs other\nmemu needs anonymous\nnote: memu~ldplayer>bluestacks>mumu in terms of speed')
	if select_search_regions then
		if search_regions[select_search_regions] then gg.setRanges(search_regions[select_search_regions]) end
		if yesNoPrompt('Save selectrion?') then
			local cache = io.open(cached_ranges_path,'w')
			cache:write(select_search_regions)
			cache:close()
			gg.alert('selection saved to ' .. cached_ranges_path)
		end
	end
end
gg.toast('click the Sx button to use script')
menus['menuLoop']('mainMenu')