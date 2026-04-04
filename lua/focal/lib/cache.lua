---@mod focal.lib.cache "Cache — LRU Render Output Cache"
---@brief [[
--- LRU cache for chafa ANSI output.
--- Keyed by path + mtime + max_geometry. Avoids redundant process spawns on re-hover.
---@brief ]]

local Cache = {}
Cache.__index = Cache

local DEFAULT_MAX_ENTRIES = 20
local DEFAULT_MAX_BYTES = 2 * 1024 * 1024 -- 2 MB

---Build a cache key from path, mtime, and geometry.
---@param path string
---@param mtime number
---@param geo FocalGeometry
---@return string
local function make_key(path, mtime, geo)
    return string.format("%s:%s:%dx%d", path, tostring(mtime), geo.width, geo.height)
end

---Create a new LRU cache instance.
---@param opts? { max_entries?: integer, max_bytes?: integer }
---@return table
function Cache.new(opts)
    opts = opts or {}
    local self = setmetatable({}, Cache)
    self._max_entries = opts.max_entries or DEFAULT_MAX_ENTRIES
    self._max_bytes = opts.max_bytes or DEFAULT_MAX_BYTES
    self._entries = {} ---@type table<string, table>
    self._order = {} ---@type string[] oldest first
    self._bytes = 0
    self._hits = 0
    self._misses = 0
    self._evictions = 0
    return self
end

---Remove the oldest entry from the cache.
---@private
function Cache:_evict_oldest()
    if #self._order == 0 then
        return
    end
    local key = table.remove(self._order, 1)
    local entry = self._entries[key]
    if entry then
        self._bytes = self._bytes - #entry.output
        self._entries[key] = nil
        self._evictions = self._evictions + 1
    end
end

---Move a key to the most-recently-used position.
---@param key string
---@private
function Cache:_touch(key)
    for i, k in ipairs(self._order) do
        if k == key then
            table.remove(self._order, i)
            break
        end
    end
    self._order[#self._order + 1] = key
end

---Retrieve a cached entry.
---@param path string
---@param mtime number
---@param max_geometry FocalGeometry
---@return table|nil
function Cache:get(path, mtime, max_geometry)
    local key = make_key(path, mtime, max_geometry)
    local entry = self._entries[key]
    if entry then
        self._hits = self._hits + 1
        self:_touch(key)
        return entry
    end
    self._misses = self._misses + 1
    return nil
end

---Store an entry in the cache, evicting as needed.
---@param path string
---@param mtime number
---@param max_geometry FocalGeometry
---@param output string ANSI output from chafa
---@param fit_geometry FocalGeometry Actual fitted dimensions
function Cache:put(path, mtime, max_geometry, output, fit_geometry)
    if #output > self._max_bytes then
        return
    end
    local key = make_key(path, mtime, max_geometry)
    local existing = self._entries[key]
    if existing then
        -- Remove the old entry completely before eviction so that
        -- _evict_oldest() cannot double-subtract its bytes.
        self._bytes = self._bytes - #existing.output
        self._entries[key] = nil
        for i, k in ipairs(self._order) do
            if k == key then
                table.remove(self._order, i)
                break
            end
        end
    end

    -- Evict until we have room for the new entry
    while #self._order >= self._max_entries do
        self:_evict_oldest()
    end
    while self._bytes + #output > self._max_bytes and #self._order > 0 do
        self:_evict_oldest()
    end

    self._entries[key] = {
        output = output,
        fit_geometry = fit_geometry,
    }
    self._bytes = self._bytes + #output
    self._order[#self._order + 1] = key
end

---Remove all entries for a specific path (any mtime/geometry).
---@param path string
function Cache:invalidate(path)
    local prefix = path .. ":"
    local to_remove = {}
    for i, key in ipairs(self._order) do
        if key:sub(1, #prefix) == prefix then
            to_remove[#to_remove + 1] = i
        end
    end
    -- Remove from order in reverse to preserve indices
    for i = #to_remove, 1, -1 do
        local key = self._order[to_remove[i]]
        local entry = self._entries[key]
        if entry then
            self._bytes = self._bytes - #entry.output
            self._entries[key] = nil
        end
        table.remove(self._order, to_remove[i])
    end
end

---Remove all entries and reset stats.
function Cache:clear()
    self._entries = {}
    self._order = {}
    self._bytes = 0
    self._hits = 0
    self._misses = 0
    self._evictions = 0
end

---Return cache statistics.
---@return { hits: integer, misses: integer, evictions: integer, entries: integer, bytes: integer }
function Cache:stats()
    return {
        hits = self._hits,
        misses = self._misses,
        evictions = self._evictions,
        entries = #self._order,
        bytes = self._bytes,
    }
end

return Cache
