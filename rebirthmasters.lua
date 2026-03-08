--[[
╔══════════════════════════════════════════════════════════════╗
║           REBIRTH MASTERS - GAMEGUARDIAN SCRIPT             ║
║                     Version: 3.2.0                           ║
║  GG 101.1 COMPATIBLE — No refineNumber sign constants       ║
║  Uses value-based narrowing instead                         ║
║  DUMP.CS: PlayerMgr fields                                  ║
║    Honor/Carat/SoulStone/Stage = ObscuredInt → T_XOR(16)   ║
║    Gold = BigInteger (large number)                         ║
╚══════════════════════════════════════════════════════════════╝
]]

-- ═══════════════════════════════════════════════════════════════
-- COMPAT: stubs for missing GG functions
-- ═══════════════════════════════════════════════════════════════
local gg = gg
if not gg.getVariable then gg.getVariable = function() return nil end end
if not gg.setVariable then gg.setVariable = function() return false end end
if not gg.toJson      then gg.toJson      = function(t) return tostring(t) end end
if not gg.fromJson    then gg.fromJson    = function()  return {} end end

-- ═══════════════════════════════════════════════════════════════
-- CONSTANTS — hardcoded numerics, never use gg.TYPE_* directly
-- in table literals or as default values. GG 101.1 has them as
-- globals but the Lua closure timing can make them nil.
-- These values are fixed across all GG versions.
-- ═══════════════════════════════════════════════════════════════
local T_DWORD  = 4    -- gg.TYPE_DWORD
local T_QWORD  = 32   -- gg.TYPE_QWORD
local T_XOR    = 16   -- gg.TYPE_XOR_DWORD  (ObscuredInt)
local T_FLOAT  = 16   -- gg.TYPE_FLOAT (same slot, different search path)

-- Verify T_XOR at runtime and correct if GG constant differs
if gg.TYPE_XOR_DWORD and gg.TYPE_XOR_DWORD ~= 0 then
    T_XOR = gg.TYPE_XOR_DWORD
end
if gg.TYPE_DWORD and gg.TYPE_DWORD ~= 0 then
    T_DWORD = gg.TYPE_DWORD
end
if gg.TYPE_QWORD and gg.TYPE_QWORD ~= 0 then
    T_QWORD = gg.TYPE_QWORD
end

-- Memory regions
local R_HEAP = 64   -- gg.REGION_C_HEAP
local R_ANON = 1    -- gg.REGION_ANONYMOUS
local R_DATA = 32   -- gg.REGION_C_DATA
local R_ALL  = R_HEAP | R_ANON

if gg.REGION_C_HEAP      and gg.REGION_C_HEAP ~= 0      then R_HEAP = gg.REGION_C_HEAP end
if gg.REGION_ANONYMOUS   and gg.REGION_ANONYMOUS ~= 0   then R_ANON = gg.REGION_ANONYMOUS end
if gg.REGION_C_DATA      and gg.REGION_C_DATA ~= 0      then R_DATA = gg.REGION_C_DATA end
R_ALL = R_HEAP | R_ANON

-- ═══════════════════════════════════════════════════════════════
-- STDLIB LOCALS
-- ═══════════════════════════════════════════════════════════════
local os, string, math, table = os, string, math, table
local tonumber, tostring, type, pcall = tonumber, tostring, type, pcall
local tinsert = table.insert
local sformat = string.format
local mmin    = math.min
local mmax    = math.max

-- ═══════════════════════════════════════════════════════════════
-- CONFIG
-- ═══════════════════════════════════════════════════════════════
local CFG = {
    VER           = "3.2.0",
    AUTO_INTERVAL = 500,   -- ms between auto-farm ticks
    SAVE_KEY      = "RM_V32_DATA",
    PREFS_KEY     = "RM_V32_PREFS",
}

-- ═══════════════════════════════════════════════════════════════
-- CURRENCY TABLE  (all ObscuredInt in PlayerMgr → T_XOR)
-- ═══════════════════════════════════════════════════════════════
local CURR = {
    honor     = { name="Honor (Medals)",   max=2147483647, default=999999, addrs={}, last=0 },
    carat     = { name="Carat (Diamonds)", max=2147483647, default=99999,  addrs={}, last=0 },
    soulstone = { name="Soul Stone",       max=2147483647, default=999999, addrs={}, last=0 },
    stage     = { name="Stage",            max=9999,       default=999,    addrs={}, last=0 },
    highstage = { name="High Stage",       max=9999,       default=999,    addrs={}, last=0 },
    teamlevel = { name="Team Level",       max=9999,       default=999,    addrs={}, last=0 },
}

-- Gold = BigInteger, handled separately
local GOLD = { addrs={}, last=0, ftype=T_XOR }

-- ═══════════════════════════════════════════════════════════════
-- STATE
-- ═══════════════════════════════════════════════════════════════
local S = {
    minimized   = false,
    running     = true,
    tab         = 1,
    last_tick   = 0,
    auto_farm   = false,
    last_values = {},
    last_save   = 0,
}

-- ═══════════════════════════════════════════════════════════════
-- HELPERS
-- ═══════════════════════════════════════════════════════════════
local function T(m)   gg.toast(tostring(m)) end
local function SL(ms) gg.sleep(ms or 100)   end
local function CLR()  gg.clearResults()     end

local function safe_flags(f)
    -- Always return a valid integer flag, never nil
    if type(f) == "number" and f > 0 then return f end
    return T_XOR
end

-- ═══════════════════════════════════════════════════════════════
-- PERSISTENCE
-- ═══════════════════════════════════════════════════════════════
local function save()
    local d = {}
    -- Gold
    if #GOLD.addrs > 0 then
        local a = {}
        for _, v in ipairs(GOLD.addrs) do
            tinsert(a, { address = v.address, ftype = v.ftype or T_XOR })
        end
        d.gold = { addrs = a, last = GOLD.last }
    end
    -- Currencies
    for k, c in pairs(CURR) do
        if #c.addrs > 0 then
            local a = {}
            for _, v in ipairs(c.addrs) do
                tinsert(a, { address = v.address, ftype = v.ftype or T_XOR })
            end
            d[k] = { addrs = a, last = c.last }
        end
    end

    local ok, s = pcall(gg.toJson, d)
    if ok then gg.setVariable(CFG.SAVE_KEY, s) end

    local ok2, s2 = pcall(gg.toJson, { last_values = S.last_values })
    if ok2 then gg.setVariable(CFG.PREFS_KEY, s2) end

    local n = #GOLD.addrs
    for _, c in pairs(CURR) do n = n + #c.addrs end
    T("💾 Saved " .. n .. " addresses")
end

local function load()
    local ss = gg.getVariable(CFG.SAVE_KEY)
    local ps = gg.getVariable(CFG.PREFS_KEY)
    local n  = 0

    if ss and ss ~= "" then
        local ok, d = pcall(gg.fromJson, ss)
        if ok and type(d) == "table" then
            if d.gold and d.gold.addrs then
                -- Restore ftype, falling back to T_XOR if missing
                for _, a in ipairs(d.gold.addrs) do
                    if not a.ftype or a.ftype == 0 then a.ftype = T_XOR end
                end
                GOLD.addrs = d.gold.addrs
                GOLD.last  = d.gold.last or 0
                n = n + 1
            end
            for k, info in pairs(d) do
                if k ~= "gold" and CURR[k] and info.addrs then
                    for _, a in ipairs(info.addrs) do
                        if not a.ftype or a.ftype == 0 then a.ftype = T_XOR end
                    end
                    CURR[k].addrs = info.addrs
                    CURR[k].last  = info.last or 0
                    n = n + 1
                end
            end
        end
    end

    if ps and ps ~= "" then
        local ok, p = pcall(gg.fromJson, ps)
        if ok and type(p) == "table" and p.last_values then
            S.last_values = p.last_values
        end
    end

    if n > 0 then T("📂 Loaded " .. n .. " currencies") end
    return n > 0
end

local function clear_data()
    gg.setVariable(CFG.SAVE_KEY,  "")
    gg.setVariable(CFG.PREFS_KEY, "")
    GOLD.addrs = {}; GOLD.last = 0
    for _, c in pairs(CURR) do c.addrs = {}; c.last = 0 end
    S.last_values = {}
    T("🗑️ Cleared all data")
end

local function auto_save()
    local now = os.clock()
    if now - S.last_save > 30 then
        local has = #GOLD.addrs > 0
        if not has then
            for _, v in pairs(CURR) do
                if #v.addrs > 0 then has = true; break end
            end
        end
        if has then save(); S.last_save = now end
    end
end

-- ═══════════════════════════════════════════════════════════════
-- CORE MEMORY OPS
-- ═══════════════════════════════════════════════════════════════

-- Build a setValues edit table from an addr list
local function make_edits(addrs, value, ftype, limit)
    local edits = {}
    limit = limit or 5
    for i = 1, mmin(limit, #addrs) do
        tinsert(edits, {
            address = addrs[i].address,
            value   = value,
            flags   = safe_flags(addrs[i].ftype or ftype),
        })
    end
    return edits
end

-- Search for an exact value, return found addr list
local function search_exact(val, ftype)
    CLR()
    gg.setRanges(R_ALL)
    gg.searchNumber(tostring(val), ftype)
    local res  = gg.getResults(200)
    local found = {}
    for _, v in ipairs(res) do
        tinsert(found, { address = v.address, ftype = ftype })
    end
    CLR()
    return found, res
end

-- ═══════════════════════════════════════════════════════════════
-- FIND: Manual exact-value search (ObscuredInt)
-- ═══════════════════════════════════════════════════════════════
local function find_obscured(key, val)
    local c = CURR[key]
    T("🔍 " .. c.name .. " = " .. tostring(val))
    local found = search_exact(val, T_XOR)
    c.addrs = found
    c.last  = val
    T("✅ " .. c.name .. ": " .. #found .. " found")
    if #found > 0 then save() end
end

-- ═══════════════════════════════════════════════════════════════
-- FIND: Auto-find using VALUE NARROWING
-- GG 101.1 rejects sign constants in refineNumber, so instead:
--   1. Do broad scan for range 0~max
--   2. Ask user to note their current value
--   3. Narrow by searching for that exact value within results
--   Repeat until few results remain.
-- This is 100% compatible with all GG versions.
-- ═══════════════════════════════════════════════════════════════
local function auto_find_obscured(key)
    local c = CURR[key]

    local go = gg.alert(
        "AUTO-FIND: " .. c.name ..
        "\n\nMethod: value-narrowing (GG 101.1 safe)" ..
        "\n\n1. Note your current " .. c.name .. " value in game" ..
        "\n2. Press Start" ..
        "\n3. Enter the value when prompted" ..
        "\n4. Repeat after value changes to narrow down",
        "Start", "Cancel"
    )
    if go ~= 1 then return end

    -- Step 1: Broad scan
    CLR()
    gg.setRanges(R_ALL)
    gg.searchNumber("0~" .. tostring(c.max), T_XOR)
    T("📊 Broad scan: " .. gg.getResultsCount() .. " results")

    if gg.getResultsCount() == 0 then
        T("❌ No results found")
        CLR()
        return
    end

    -- Step 2: Narrow by value
    local rounds = 0
    while gg.getResultsCount() > 5 and rounds < 12 do
        rounds = rounds + 1

        local inp = gg.prompt(
            {
                "Results: " .. gg.getResultsCount() ..
                "\nEnter CURRENT " .. c.name .. " value in game\n(0 = skip / use results as-is):"
            },
            { "0" },
            { "number" }
        )
        if not inp or not inp[1] then break end

        local val = tonumber(inp[1]) or 0
        if val == 0 then break end

        -- Refine: search for exact value within current results
        gg.searchNumber(tostring(val), T_XOR)
        local cnt = gg.getResultsCount()
        T("→ " .. cnt .. " results remaining")

        if cnt == 0 then
            T("⚠️ Value not found — re-scanning broadly")
            -- Value may have changed — do a fresh scan for new value
            CLR()
            gg.setRanges(R_ALL)
            gg.searchNumber(tostring(val), T_XOR)
            T("→ Fresh scan: " .. gg.getResultsCount() .. " results")
        end
    end

    local res   = gg.getResults(mmin(20, gg.getResultsCount()))
    CLR()

    if #res == 0 then
        T("❌ No results. Try manual find with exact value.")
        return
    end

    local found = {}
    for _, v in ipairs(res) do
        tinsert(found, { address = v.address, ftype = T_XOR })
    end

    c.addrs = found
    c.last  = res[1] and res[1].value or c.default
    save()
    T("🎯 " .. c.name .. ": " .. #found .. " locked")

    if gg.alert(
        "✅ Found " .. #found .. " for " .. c.name ..
        "\nSet max (" .. c.max .. ") now?",
        "Set Max", "Skip"
    ) == 1 then
        local edits = make_edits(c.addrs, c.max, T_XOR)
        gg.setValues(edits)
        c.last = c.max
        T("✅ " .. c.name .. " = " .. c.max)
        save()
    end
end

-- ═══════════════════════════════════════════════════════════════
-- SET: Write value to ObscuredInt after user prompt
-- ═══════════════════════════════════════════════════════════════
local function prompt_set(key)
    local c   = CURR[key]
    if #c.addrs == 0 then T("❌ Find " .. c.name .. " first!"); return end
    local def = S.last_values[key] or c.last or c.default
    local inp = gg.prompt({ "Set " .. c.name .. ":" }, { tostring(def) }, { "number" })
    if not inp or not inp[1] then return end
    local val = tonumber(inp[1])
    if not val or val < 0 then T("❌ Invalid number"); return end
    val = mmin(val, c.max)
    local edits = make_edits(c.addrs, val, T_XOR)
    gg.setValues(edits)
    c.last = val
    S.last_values[key] = val
    T("✅ " .. c.name .. " = " .. val)
    save()
end

-- ═══════════════════════════════════════════════════════════════
-- GOLD: Manual find
-- ═══════════════════════════════════════════════════════════════
local function find_gold_manual()
    local inp = gg.prompt(
        {
            "Enter EXACT current gold (full number):",
            "Search type:  1=XOR_DWORD  2=DWORD  3=QWORD",
        },
        { tostring(GOLD.last > 0 and GOLD.last or 0), "1" },
        { "number", "number" }
    )
    if not inp or not inp[1] then return end

    local val   = inp[1]
    local tn    = tonumber(inp[2]) or 1
    local ftype = (tn == 2 and T_DWORD) or (tn == 3 and T_QWORD) or T_XOR
    local flbl  = (tn == 2 and "DWORD")  or (tn == 3 and "QWORD")  or "XOR_DWORD"

    T("🔍 Gold (" .. flbl .. ") = " .. val)
    local found = search_exact(val, ftype)
    GOLD.addrs = found
    GOLD.last  = tonumber(val) or 0
    GOLD.ftype = ftype
    T("✅ Gold: " .. #found .. " results (" .. flbl .. ")")
    if #found > 0 then save() end
end

-- ═══════════════════════════════════════════════════════════════
-- GOLD: Set value
-- ═══════════════════════════════════════════════════════════════
local function set_gold()
    if #GOLD.addrs == 0 then T("❌ Find Gold first!"); return end
    local def = GOLD.last > 0 and GOLD.last or 1000000000
    local inp = gg.prompt({ "Set Gold to:" }, { tostring(def) }, { "number" })
    if not inp or not inp[1] then return end
    local val   = tonumber(inp[1]) or 0
    local edits = make_edits(GOLD.addrs, val, GOLD.ftype or T_XOR)
    gg.setValues(edits)
    GOLD.last = val
    T("✅ Gold = " .. val)
    save()
end

-- ═══════════════════════════════════════════════════════════════
-- GOLD: Auto-find (value narrowing, GG 101.1 safe)
-- ═══════════════════════════════════════════════════════════════
local function auto_find_gold()
    local go = gg.alert(
        "AUTO-FIND GOLD" ..
        "\n\nGold shows as 6.8b / 389b etc in game" ..
        "\nEnter the FULL number e.g. 6800000000" ..
        "\n\n1. Note exact gold amount" ..
        "\n2. Press Start → scan runs" ..
        "\n3. Enter value to narrow down",
        "Start", "Cancel"
    )
    if go ~= 1 then return end

    CLR()
    gg.setRanges(R_ALL)
    gg.searchNumber("1~2147483647", T_XOR)
    local cnt = gg.getResultsCount()
    T("📊 Gold scan: " .. cnt)
    if cnt == 0 then T("❌ Nothing found. Try manual gold find."); return end

    local rounds = 0
    while gg.getResultsCount() > 5 and rounds < 12 do
        rounds = rounds + 1
        local inp = gg.prompt(
            {
                "Results: " .. gg.getResultsCount() ..
                "\nEnter your CURRENT gold amount\n(full number, 0 = stop):"
            },
            { "0" },
            { "number" }
        )
        if not inp or not inp[1] then break end
        local val = tonumber(inp[1]) or 0
        if val == 0 then break end

        gg.searchNumber(tostring(val), T_XOR)
        local new_cnt = gg.getResultsCount()
        T("→ " .. new_cnt .. " results")

        if new_cnt == 0 then
            T("⚠️ Not found — fresh scan for new value")
            CLR()
            gg.setRanges(R_ALL)
            gg.searchNumber(tostring(val), T_XOR)
            T("→ " .. gg.getResultsCount() .. " after fresh scan")
        end
    end

    local res = gg.getResults(mmin(20, gg.getResultsCount()))
    CLR()
    if #res == 0 then T("❌ No gold addresses found. Try manual."); return end

    local found = {}
    for _, v in ipairs(res) do
        tinsert(found, { address = v.address, ftype = T_XOR })
    end
    GOLD.addrs = found
    GOLD.last  = res[1] and res[1].value or 0
    GOLD.ftype = T_XOR
    save()
    T("🎯 Gold: " .. #found .. " locked")

    if gg.alert("✅ Found " .. #found .. " gold\nSet a value now?", "Set Value", "Skip") == 1 then
        set_gold()
    end
end

-- ═══════════════════════════════════════════════════════════════
-- FREEZE / UNFREEZE
-- ═══════════════════════════════════════════════════════════════
local function freeze_all()
    local list = {}
    for _, a in ipairs(GOLD.addrs) do
        tinsert(list, { address = a.address, flags = safe_flags(a.ftype), value = GOLD.last, freeze = true })
    end
    for _, c in pairs(CURR) do
        for _, a in ipairs(c.addrs) do
            tinsert(list, { address = a.address, flags = safe_flags(a.ftype), value = c.last, freeze = true })
        end
    end
    if #list == 0 then T("❌ No addresses to freeze"); return end
    gg.addListItems(list)
    T("❄️ Frozen " .. #list .. " values")
end

local function unfreeze_all()
    gg.clearList()
    T("🔓 Unfrozen")
end

-- ═══════════════════════════════════════════════════════════════
-- AUTO-TICK (background farm)
-- ═══════════════════════════════════════════════════════════════
local function auto_tick()
    if not S.auto_farm then return end
    local now = os.clock() * 1000
    if now - S.last_tick < CFG.AUTO_INTERVAL then return end
    S.last_tick = now

    -- Keep gold high
    if #GOLD.addrs > 0 then
        local edits = make_edits(GOLD.addrs, 2000000000, GOLD.ftype or T_XOR)
        gg.setValues(edits)
    end
    -- Keep honor/carat/soulstone at their set values
    for _, key in ipairs({ "honor", "carat", "soulstone" }) do
        local c = CURR[key]
        if #c.addrs > 0 and c.last > 0 then
            local edits = make_edits(c.addrs, c.last, T_XOR, 3)
            gg.setValues(edits)
        end
    end
end

-- ═══════════════════════════════════════════════════════════════
-- MENUS
-- ═══════════════════════════════════════════════════════════════
local function status_found()
    local n = #GOLD.addrs > 0 and 1 or 0
    for _, c in pairs(CURR) do if #c.addrs > 0 then n = n + 1 end end
    return n
end

local function draw_full()
    local t    = S.tab
    local opts = {}
    local n_items

    if t == 1 then
        opts = {
            "💰 Set Gold...",
            "🏅 Set Honor (Medals)...",
            "💎 Set Carat (Diamonds)...",
            "👻 Set Soul Stone...",
            "🗺️ Set Stage...",
            "🏆 Set High Stage...",
            "⬆️ Set Team Level...",
            "❄️ Freeze All",
            "🔓 Unfreeze All",
        }
        n_items = 9

    elseif t == 2 then
        opts = {
            "🔍 Find Gold (Manual)",
            "🔍 Find Honor",
            "🔍 Find Carat",
            "🔍 Find Soul Stone",
            "🔍 Find Stage",
            "🔍 Find High Stage",
            "🔍 Find Team Level",
            "─────────────────",
            "🤖 Auto-Find Gold",
            "🤖 Auto-Find Honor",
            "🤖 Auto-Find Carat",
            "🤖 Auto-Find Soul Stone",
            "🤖 Auto-Find Stage",
        }
        n_items = 13

    elseif t == 3 then
        opts = {
            S.auto_farm and "🛑 Stop Auto-Farm" or "▶️ Start Auto-Farm",
            "🤖 Full Auto ON",
            "🛑 Full Auto OFF",
        }
        n_items = 3

    else
        opts = {
            "🧹 Clear GG Results",
            "💾 Save Addresses",
            "📂 Load Addresses",
            "🗑️ Clear All Saved Data",
            "📊 Status",
            "❓ Help",
        }
        n_items = 6
    end

    tinsert(opts, "⬅️ Prev Tab")
    tinsert(opts, "➡️ Next Tab")
    tinsert(opts, "📉 Minimize")
    tinsert(opts, "❌ Exit")

    local tab_names = { "💰 Currency", "🔍 Find", "🤖 Auto", "⚙️ Tools" }
    local title = sformat("REBIRTH MASTERS v%s | Tab %d/4: %s",
        CFG.VER, t, tab_names[t])
    if S.auto_farm then title = title .. "\n[🌾 FARMING]" end
    title = title .. "\n💾 " .. status_found() .. "/7 currencies located"

    return gg.choice(opts, nil, title), n_items
end

local function handle_full(choice, n_items)
    if not choice then return true end

    local t   = S.tab
    local nav = n_items + 1  -- index where nav buttons start

    if     choice == nav     then S.tab = S.tab - 1; if S.tab < 1 then S.tab = 4 end; return true
    elseif choice == nav + 1 then S.tab = S.tab + 1; if S.tab > 4 then S.tab = 1 end; return true
    elseif choice == nav + 2 then S.minimized = true; gg.setVisible(false); T("📉 Minimized"); return true
    elseif choice == nav + 3 then return false
    end

    if t == 1 then
        if     choice == 1 then set_gold()
        elseif choice == 2 then prompt_set("honor")
        elseif choice == 3 then prompt_set("carat")
        elseif choice == 4 then prompt_set("soulstone")
        elseif choice == 5 then prompt_set("stage")
        elseif choice == 6 then prompt_set("highstage")
        elseif choice == 7 then prompt_set("teamlevel")
        elseif choice == 8 then freeze_all()
        elseif choice == 9 then unfreeze_all()
        end

    elseif t == 2 then
        local function ask_and_find(key)
            local inp = gg.prompt({ "Current " .. CURR[key].name .. ":" }, { "0" }, { "number" })
            if inp and inp[1] then find_obscured(key, tonumber(inp[1]) or 0) end
        end
        if     choice == 1  then find_gold_manual()
        elseif choice == 2  then ask_and_find("honor")
        elseif choice == 3  then ask_and_find("carat")
        elseif choice == 4  then ask_and_find("soulstone")
        elseif choice == 5  then ask_and_find("stage")
        elseif choice == 6  then ask_and_find("highstage")
        elseif choice == 7  then ask_and_find("teamlevel")
        elseif choice == 8  then -- separator: do nothing
        elseif choice == 9  then auto_find_gold()
        elseif choice == 10 then auto_find_obscured("honor")
        elseif choice == 11 then auto_find_obscured("carat")
        elseif choice == 12 then auto_find_obscured("soulstone")
        elseif choice == 13 then auto_find_obscured("stage")
        end

    elseif t == 3 then
        if     choice == 1 then S.auto_farm = not S.auto_farm; T(S.auto_farm and "▶️ Farm ON" or "🛑 Farm OFF")
        elseif choice == 2 then S.auto_farm = true;  T("🤖 Full Auto ON")
        elseif choice == 3 then S.auto_farm = false; T("🛑 All Auto OFF")
        end

    elseif t == 4 then
        if choice == 1 then
            CLR(); T("🧹 Cleared")
        elseif choice == 2 then
            save()
        elseif choice == 3 then
            load()
        elseif choice == 4 then
            if gg.alert("Clear ALL saved data?", "Yes", "Cancel") == 1 then clear_data() end
        elseif choice == 5 then
            gg.alert(sformat(
                "v%s | Farm: %s\n\nAddresses found:\n Gold: %d\n Honor: %d\n Carat: %d\n SoulStone: %d\n Stage: %d\n HighStage: %d\n TeamLevel: %d",
                CFG.VER, S.auto_farm and "ON" or "OFF",
                #GOLD.addrs, #CURR.honor.addrs, #CURR.carat.addrs,
                #CURR.soulstone.addrs, #CURR.stage.addrs,
                #CURR.highstage.addrs, #CURR.teamlevel.addrs
            ))
        elseif choice == 6 then
            gg.alert([[REBIRTH MASTERS v3.2 — GG 101.1 COMPATIBLE

MEMORY TYPES (from dump.cs analysis):
• Honor / Carat / SoulStone / Stage / HighStage / TeamLevel
  = ObscuredInt (anti-cheat XOR encrypted)
  GG type: XOR DWORD (type 16)
  Search your EXACT current value

• Gold = BigInteger
  Shows as 6.8b / 389b in game
  Enter FULL number e.g. 6800000000

HOW TO FIND (Manual):
  1. Note exact value shown in game
  2. Tab 2 → Find → enter that value
  3. Tab 1 → Set to whatever you want

HOW TO FIND (Auto):
  1. Tab 2 → Auto-Find
  2. Scan runs automatically
  3. Enter your current value when prompted
  4. Change value in game, re-enter new value
  5. Repeat until narrowed to a few results

AUTO-FARM:
  Tab 3 → Start → keeps set values topped up
  Minimize to run in background]])
        end
    end
    return true
end

-- ═══════════════════════════════════════════════════════════════
-- COMPACT MENU (minimized)
-- ═══════════════════════════════════════════════════════════════
local function draw_compact()
    local g = #GOLD.addrs > 0 and "✓" or "✗"
    local h = #CURR.honor.addrs > 0 and "✓" or "✗"
    local c = #CURR.carat.addrs > 0 and "✓" or "✗"
    local opts = {
        "📱 Restore Full Menu",
        S.auto_farm and "🛑 Stop Farm" or "▶️ Start Farm",
        "💰 Set Gold...",
        "🏅 Set Honor...",
        "💎 Set Carat...",
        "📉 Stay in Background",
        "❌ Exit",
    }
    return gg.choice(opts, nil, sformat(
        "RM v%s | G:%s H:%s C:%s\n%s",
        CFG.VER, g, h, c, S.auto_farm and "[🌾 FARMING]" or "[Paused]"
    ))
end

local function handle_compact(choice)
    if not choice then return true end
    if     choice == 1 then S.minimized = false; gg.setVisible(true)
    elseif choice == 2 then S.auto_farm = not S.auto_farm; T(S.auto_farm and "▶️ Farm ON" or "🛑 Farm OFF")
    elseif choice == 3 then set_gold()
    elseif choice == 4 then prompt_set("honor")
    elseif choice == 5 then prompt_set("carat")
    elseif choice == 6 then gg.setVisible(false); T("📉 Background")
    elseif choice == 7 then return false
    end
    return true
end

-- ═══════════════════════════════════════════════════════════════
-- MAIN LOOP
-- ═══════════════════════════════════════════════════════════════
local function loop()
    while S.running do
        auto_tick()
        auto_save()

        if S.minimized then
            if gg.isVisible() then
                local ch = draw_compact()
                if not handle_compact(ch) then S.running = false; break end
                if ch == 6 then gg.setVisible(false) end
            end
        else
            local ch, n_items = draw_full()
            if not handle_full(ch, n_items) then S.running = false; break end
        end

        gg.sleep(100)
    end
end

-- ═══════════════════════════════════════════════════════════════
-- ENTRY
-- ═══════════════════════════════════════════════════════════════
local function main()
    T("🎮 Rebirth Masters v" .. CFG.VER)
    T("✅ GG 101.1 compatible!")
    gg.sleep(500)

    S.last_tick = os.clock() * 1000
    S.last_save = os.clock()

    local loaded = load()
    if loaded then
        gg.sleep(300)
        local n = #GOLD.addrs
        for _, v in pairs(CURR) do n = n + #v.addrs end
        T("✅ Ready — " .. n .. " addresses loaded")
    else
        T("💡 Go to Tab 2 to find currencies")
    end

    loop()
    save()
    unfreeze_all()
    T("💾 Saved! Goodbye!")
end

local ok, err = pcall(main)
if not ok then
    gg.alert("SCRIPT ERROR:\n" .. tostring(err))
end
