--[[
╔══════════════════════════════════════════════════════════════╗
║           REBIRTH MASTERS - GAMEGUARDIAN SCRIPT             ║
║                     Version: 3.3.0                           ║
║  GG 101.1 COMPATIBLE — No refineNumber sign constants       ║
║  Uses value-based narrowing instead                         ║
║  DUMP.CS: PlayerMgr fields                                  ║
║    Honor/Carat/SoulStone/Stage = ObscuredInt → T_XOR(16)   ║
║    Gold = BigInteger (large number)                         ║
║  v3.3: Offset Engine — addresses persist across restarts    ║
║    • Saves libil2cpp.so-relative offsets                    ║
║    • Auto-rebuilds on ASLR slide at next launch             ║
║    • Pointer chain scanner for stable multi-session finds   ║
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
    VER           = "3.3.0",
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
-- OFFSET ENGINE
-- Saves libil2cpp.so-relative offsets so addresses survive
-- game restarts (ASLR slides the library each launch but the
-- offset from library base → value stays constant).
-- ═══════════════════════════════════════════════════════════════

-- Cache the library base; resolved once per script run.
local LIB_BASE = nil

--- Read /proc/self/maps and find the base address of libil2cpp.so.
--- Returns the integer base address, or nil on failure.
local function get_lib_base()
    if LIB_BASE then return LIB_BASE end

    -- gg.getTargetInfo() gives us the package name / PID
    -- We read /proc/<pid>/maps to locate il2cpp
    local pid   = tostring(gg.getTargetInfo and gg.getTargetInfo().pid or "self")
    local paths = {
        "/proc/" .. pid .. "/maps",
        "/proc/self/maps",
    }

    for _, path in ipairs(paths) do
        local f = io.open(path, "r")
        if f then
            for line in f:lines() do
                -- Lines look like: b400007000-b4c0000000 r--p ... libil2cpp.so
                if line:find("libil2cpp%.so") then
                    local base_hex = line:match("^(%x+)%-")
                    if base_hex then
                        LIB_BASE = tonumber(base_hex, 16)
                        f:close()
                        return LIB_BASE
                    end
                end
            end
            f:close()
        end
    end

    -- Fallback: use gg.getRangesList if maps not readable
    local ok, ranges = pcall(gg.getRangesList, "libil2cpp.so")
    if ok and ranges and #ranges > 0 then
        LIB_BASE = ranges[1].start
        return LIB_BASE
    end

    return nil
end

--- Convert an absolute address → (base, offset) pair.
--- Returns offset as integer, or nil if base unavailable.
local function addr_to_offset(abs_addr)
    local base = get_lib_base()
    if not base then return nil end
    local off = abs_addr - base
    -- Sanity: offset should be positive and < 256 MB
    if off < 0 or off > 0x10000000 then return nil end
    return off
end

--- Rebuild an absolute address from a stored offset.
local function offset_to_addr(offset)
    local base = get_lib_base()
    if not base then return nil end
    return base + offset
end

--- Quick sanity-check: try to read 4 bytes at addr.
--- Returns true if the memory read succeeds.
local function addr_valid(abs_addr)
    local ok, res = pcall(gg.getValues, {
        { address = abs_addr, flags = T_DWORD }
    })
    return ok and res and #res > 0 and (res[1].value ~= nil)
end

-- ─────────────────────────────────────────────────────────────
-- POINTER SCANNER
-- Walk a chain of pointers to locate a stable PlayerMgr field.
-- Usage:
--   pointer_scan(base_addr, { offset1, offset2, ... })
-- Returns final resolved address or nil.
-- ─────────────────────────────────────────────────────────────
local function pointer_scan(base_addr, chain)
    local addr = base_addr
    for i, off in ipairs(chain) do
        local ok, res = pcall(gg.getValues, {
            { address = addr, flags = T_QWORD }   -- 64-bit pointer
        })
        if not ok or not res or #res == 0 then return nil end
        local ptr = res[1].value
        if not ptr or ptr == 0 then return nil end
        addr = ptr + off
    end
    return addr
end

--- Attempt to walk a known pointer chain for a PlayerMgr field.
--- Chains should be discovered once (via manual GG pointer scan)
--- and stored here as CFG entries.
local function resolve_ptr_chain(chain_def)
    if not chain_def then return nil end
    local base = get_lib_base()
    if not base then return nil end
    -- chain_def = { static_offset, { ptr_offsets... } }
    local static_addr = base + chain_def.static_offset
    local final_addr  = pointer_scan(static_addr, chain_def.chain)
    if final_addr and addr_valid(final_addr) then
        return final_addr
    end
    return nil
end

-- ═══════════════════════════════════════════════════════════════
-- PERSISTENCE  (offset-relative, restarts-safe)
-- ═══════════════════════════════════════════════════════════════

--- Build a serialisable addr-record that stores both the raw
--- address AND the il2cpp offset so the next session can
--- rebuild the address without re-scanning.
local function make_addr_record(abs_addr, ftype)
    local off = addr_to_offset(abs_addr)
    return {
        address    = abs_addr,        -- runtime address (this session)
        il2cpp_off = off,             -- offset from libil2cpp.so base
        ftype      = ftype or T_XOR,
    }
end

--- Given a stored record (may be from a previous session),
--- return a valid runtime address or nil.
local function resolve_addr_record(rec)
    if not rec then return nil end
    -- 1. Try direct address first (same session / same ASLR slide)
    if rec.address and addr_valid(rec.address) then
        return rec.address
    end
    -- 2. Rebuild from il2cpp offset
    if rec.il2cpp_off then
        local rebuilt = offset_to_addr(rec.il2cpp_off)
        if rebuilt and addr_valid(rebuilt) then
            return rebuilt
        end
    end
    return nil
end

local function save()
    local base = get_lib_base()
    local d    = {}

    -- Gold
    if #GOLD.addrs > 0 then
        local a = {}
        for _, v in ipairs(GOLD.addrs) do
            local off = v.il2cpp_off or addr_to_offset(v.address)
            tinsert(a, {
                address    = v.address,
                il2cpp_off = off,
                ftype      = v.ftype or T_XOR,
            })
        end
        d.gold = { addrs = a, last = GOLD.last }
    end

    -- Currencies
    for k, c in pairs(CURR) do
        if #c.addrs > 0 then
            local a = {}
            for _, v in ipairs(c.addrs) do
                local off = v.il2cpp_off or addr_to_offset(v.address)
                tinsert(a, {
                    address    = v.address,
                    il2cpp_off = off,
                    ftype      = v.ftype or T_XOR,
                })
            end
            d[k] = { addrs = a, last = c.last }
        end
    end

    -- Also persist the lib base so we can detect ASLR changes on load
    d.__lib_base = base

    local ok, s = pcall(gg.toJson, d)
    if ok then gg.setVariable(CFG.SAVE_KEY, s) end

    local ok2, s2 = pcall(gg.toJson, { last_values = S.last_values })
    if ok2 then gg.setVariable(CFG.PREFS_KEY, s2) end

    local n = #GOLD.addrs
    local lib_str = base and sformat(" | lib=0x%x", base) or ""
    for _, c in pairs(CURR) do n = n + #c.addrs end
    T("💾 Saved " .. n .. " addresses" .. lib_str)
end

local function load()
    local ss = gg.getVariable(CFG.SAVE_KEY)
    local ps = gg.getVariable(CFG.PREFS_KEY)
    local n  = 0
    local stale = 0

    if ss and ss ~= "" then
        local ok, d = pcall(gg.fromJson, ss)
        if ok and type(d) == "table" then

            -- Detect ASLR slide: saved base vs current base
            local saved_base   = d.__lib_base
            local current_base = get_lib_base()
            local slide        = 0
            if saved_base and current_base and saved_base ~= current_base then
                slide = current_base - saved_base
                T(sformat("📐 ASLR slide detected: 0x%x → rebuilding addresses", slide))
            end

            -- Helper: restore one address list
            local function restore_addrs(raw_list, fallback_ftype)
                local out   = {}
                for _, a in ipairs(raw_list) do
                    local ftype = a.ftype or fallback_ftype or T_XOR
                    if not ftype or ftype == 0 then ftype = T_XOR end

                    -- Priority 1: use stored il2cpp offset (most reliable)
                    if a.il2cpp_off and current_base then
                        local rebuilt = current_base + a.il2cpp_off
                        tinsert(out, {
                            address    = rebuilt,
                            il2cpp_off = a.il2cpp_off,
                            ftype      = ftype,
                        })

                    -- Priority 2: slide the raw address
                    elseif a.address and slide ~= 0 then
                        local slid = a.address + slide
                        tinsert(out, {
                            address    = slid,
                            il2cpp_off = a.il2cpp_off,
                            ftype      = ftype,
                        })

                    -- Priority 3: use raw address as-is (same session or no lib found)
                    elseif a.address then
                        tinsert(out, {
                            address    = a.address,
                            il2cpp_off = a.il2cpp_off,
                            ftype      = ftype,
                        })
                    end
                end
                return out
            end

            -- Validate restored addresses (sample first addr of each group)
            local function validate_group(addrs)
                if #addrs == 0 then return false end
                return addr_valid(addrs[1].address)
            end

            if d.gold and d.gold.addrs then
                local restored = restore_addrs(d.gold.addrs, T_XOR)
                if validate_group(restored) then
                    GOLD.addrs = restored
                    GOLD.last  = d.gold.last or 0
                    n = n + 1
                else
                    stale = stale + 1
                end
            end

            for k, info in pairs(d) do
                if k ~= "gold" and k ~= "__lib_base" and CURR[k] and info.addrs then
                    local restored = restore_addrs(info.addrs, T_XOR)
                    if validate_group(restored) then
                        CURR[k].addrs = restored
                        CURR[k].last  = info.last or 0
                        n = n + 1
                    else
                        stale = stale + 1
                    end
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

    if n > 0 then
        T("📂 Loaded " .. n .. " currencies ✅")
    end
    if stale > 0 then
        T("⚠️ " .. stale .. " groups had stale addrs → re-find needed")
    end
    return n > 0
end

local function clear_data()
    gg.setVariable(CFG.SAVE_KEY,  "")
    gg.setVariable(CFG.PREFS_KEY, "")
    GOLD.addrs = {}; GOLD.last = 0
    for _, c in pairs(CURR) do c.addrs = {}; c.last = 0 end
    S.last_values = {}
    LIB_BASE = nil  -- force re-resolve on next use
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

-- ─────────────────────────────────────────────────────────────
-- POINTER CHAIN MENU  (manual registration + test)
-- ─────────────────────────────────────────────────────────────
-- Chains are stored as CFG.PTR_CHAINS = { gold={...}, honor={...} }
-- Each chain: { static_offset=0x1234abc, chain={0x10, 0x48, 0xC} }
-- These offsets come from a GG pointer scan (do once per game version).
-- ─────────────────────────────────────────────────────────────
CFG.PTR_CHAINS = CFG.PTR_CHAINS or {}

local function ptr_chain_status()
    local n = 0
    for _ in pairs(CFG.PTR_CHAINS) do n = n + 1 end
    return n
end

local function ptr_chains_menu()
    local base = get_lib_base()
    local base_str = base and sformat("0x%x", base) or "NOT FOUND"

    local m = gg.alert(
        "POINTER CHAIN MANAGER\n\n" ..
        "libil2cpp.so base: " .. base_str .. "\n" ..
        "Registered chains: " .. ptr_chain_status() .. "\n\n" ..
        "How to use:\n" ..
        "1. In GG, do a pointer scan to find a stable\n" ..
        "   pointer to e.g. PlayerMgr.gold\n" ..
        "2. Note the static offset (from libil2cpp.so base)\n" ..
        "   and the pointer chain offsets\n" ..
        "3. Press 'Register Chain' below\n" ..
        "4. On next load the script rebuilds addresses\n" ..
        "   automatically via the chain — no re-scan needed!\n\n" ..
        "Tip: Chains survive game updates IF the static\n" ..
        "offset (il2cpp symbol) hasn't changed.",
        "Register Chain", "Test Chains", "Close"
    )

    if m == 1 then
        -- Register a new pointer chain interactively
        local inp = gg.prompt(
            {
                "Currency key (gold/honor/carat/soulstone/stage):",
                "Static offset from libil2cpp base (hex, e.g. 1A3F200):",
                "Pointer chain offsets (comma-sep hex, e.g. 10,48,C):",
            },
            { "gold", "", "" },
            { "text", "text", "text" }
        )
        if inp and inp[1] and inp[2] and inp[3] then
            local key      = inp[1]:lower():gsub("%s", "")
            local st_off   = tonumber("0x" .. inp[2]:gsub("0x",""), 16) or tonumber(inp[2])
            local chain_t  = {}
            for hex in inp[3]:gmatch("[%x]+") do
                tinsert(chain_t, tonumber("0x"..hex, 16) or 0)
            end

            if st_off and #chain_t > 0 then
                CFG.PTR_CHAINS[key] = { static_offset = st_off, chain = chain_t }
                -- Immediately try to resolve
                local addr = resolve_ptr_chain(CFG.PTR_CHAINS[key])
                if addr then
                    T("✅ Chain for '" .. key .. "' resolved → 0x" .. sformat("%x", addr))
                    -- Inject into the right address list
                    local rec = make_addr_record(addr, T_XOR)
                    if key == "gold" then
                        GOLD.addrs = { rec }
                    elseif CURR[key] then
                        CURR[key].addrs = { rec }
                    end
                    save()
                else
                    T("⚠️ Chain registered but could not resolve yet. Try when in-game.")
                end
            else
                T("❌ Invalid input — chain not saved")
            end
        end

    elseif m == 2 then
        -- Test all registered chains
        if ptr_chain_status() == 0 then
            T("No chains registered yet.")
            return
        end
        local results = "CHAIN TEST RESULTS:\n"
        for key, chain_def in pairs(CFG.PTR_CHAINS) do
            local addr = resolve_ptr_chain(chain_def)
            if addr then
                results = results .. "✅ " .. key .. " → 0x" .. sformat("%x", addr) .. "\n"
                -- Update the live address
                local rec = make_addr_record(addr, T_XOR)
                if key == "gold" then
                    GOLD.addrs = { rec }
                elseif CURR[key] then
                    CURR[key].addrs = { rec }
                end
            else
                results = results .. "❌ " .. key .. " → failed\n"
            end
        end
        gg.alert(results)
        save()
    end
end

-- ═══════════════════════════════════════════════════════════════
-- OFFSET INFO DISPLAY
-- ═══════════════════════════════════════════════════════════════
local function show_offset_info()
    local base = get_lib_base()
    local lines = { sformat("OFFSET INFO — v%s", CFG.VER), "" }

    if base then
        tinsert(lines, sformat("libil2cpp.so base: 0x%x", base))
    else
        tinsert(lines, "⚠️ libil2cpp.so NOT FOUND")
        tinsert(lines, "  (Must be launched from in-game)")
    end
    tinsert(lines, "")

    -- Gold
    local function addr_info(label, addrs)
        if #addrs == 0 then
            tinsert(lines, label .. ": (not found)")
            return
        end
        local v = addrs[1]
        local off_str = v.il2cpp_off
            and sformat("0x%x", v.il2cpp_off)
            or  (base and sformat("0x%x", v.address - base) or "?")
        tinsert(lines, sformat("%s: addr=0x%x  off=%s", label, v.address, off_str))
    end

    addr_info("Gold",      GOLD.addrs)
    addr_info("Honor",     CURR.honor.addrs)
    addr_info("Carat",     CURR.carat.addrs)
    addr_info("SoulStone", CURR.soulstone.addrs)
    addr_info("Stage",     CURR.stage.addrs)
    addr_info("HighStage", CURR.highstage.addrs)
    addr_info("TeamLevel", CURR.teamlevel.addrs)

    tinsert(lines, "")
    tinsert(lines, "Pointer chains: " .. ptr_chain_status())

    gg.alert(table.concat(lines, "\n"))
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

-- Search for an exact value, return found addr list (with il2cpp offsets)
local function search_exact(val, ftype)
    CLR()
    gg.setRanges(R_ALL)
    gg.searchNumber(tostring(val), ftype)
    local res   = gg.getResults(200)
    local found = {}
    for _, v in ipairs(res) do
        -- Store il2cpp offset immediately so save() works even same session
        tinsert(found, make_addr_record(v.address, ftype))
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
        tinsert(found, make_addr_record(v.address, T_XOR))
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
        tinsert(found, make_addr_record(v.address, T_XOR))
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
            "📐 Offset Info",
            "🔗 Pointer Chains",
            "❓ Help",
        }
        n_items = 8
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
            show_offset_info()
        elseif choice == 7 then
            ptr_chains_menu()
        elseif choice == 8 then
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
