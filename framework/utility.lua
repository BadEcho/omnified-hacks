--[[
    Utility functions employed by the Omnified framework.
    Written By: Matt Weber (https://badecho.com) (https://twitch.tv/omni)
    Copyright 2022 Bad Echo LLC
    
    Bad Echo Technologies are licensed under the
    GNU Affero General Public License v3.0.
    
    See accompanying file LICENSE.md or a copy at:
    https://www.gnu.org/licenses/agpl-3.0.html
--]]

local function evalValues(eval, valueIfTrue, valueIfFalse, ...)    
    -- Key-value pair iterators aren't an option since we may be dealing with
    -- parameters lists that are not sequences.    
    -- Table constructors are also avoided because they'll trim trailing nil values.
    for i = 1, select("#",...) do                
        local value = select(i,...)        
        if eval(value) then return valueIfTrue end
    end

	return valueIfFalse
end

local function findNil(valueIfFound, valueIfNotFound, ...)    
	return evalValues(function (v) return v == nil end, valueIfFound, valueIfNotFound, ...)
end

function areNotNil(...)    
    return findNil(false, true, ...)	
end

function anyNil(...)        
	return findNil(true, false, ...)
end

function any(value, ...)
    return evalValues(function (v) return v == value end, true, false, ...)
end

function areTrue(...)    
	return evalValues(function (v) return not v end, false, true, ...)
end

local MIN_INT = -2^31
local MAX_INT = 2^31-1

function toInt(number)
    if number ~= nil then
        if number < MIN_INT or number > MAX_INT or number ~= number then return 0 end

        return math.floor(number + 0.5)
    end

    return 0
end

function round(number, decimals)
    if number ~= nil then 
        if number ~= number then return 0 end

        return (math.floor(number*10^decimals) / (10^decimals))
    end

    return 0
end

-- Allows us to define enumerations in a C-style manner.
-- Accepts a table of string names for each enum member.
function defineEnum(members)
	local membersLength = #members
	for i = 1, membersLength do
		local member = members[i]
		members[member] = i-1
	end

    return members
end

function switch(value, cases)
    local case = cases[value]
    
    if case and type(case) == 'function' then 
        return case() 
    end

    local defaultCase = cases['default']

    return defaultCase and typeof(defaultCase) == 'function' and defaultCase() or nil
end

-- Checks if a file exists on disk.
function fileExists(fileName)
    local file = io.open(fileName, "r")

    if file ~= nil then file:close() return true else return false end
end

-- Outputs a randomly selected item from the provided random settings structure.
-- The structure of randomSettings is composed of object, weighted probability values like so:
-- randomSettings = {
--		{firstObject, 1},
--		{secondObject, 3},
-- }
-- In this example, the second object is 3x more likely to be returned than the first object.
-- Based on the items provided, a random number between 1 and 4 (inclusive) will be generated.
-- If the random number is 1 then firstObject is returned. If it is 2, 3, or 4, secondObject is returned.
function randomize(randomSettings)
	local indexedResults = {}
	local totalWeight = 0
	local lastIndex = 0

	if not randomInitialized then
		math.randomseed(os.time())
		randomInitialized = true
	end
	
	for k,v in pairs(randomSettings) do
		local resultObject = v[1]
		local weight = v[2]

		totalWeight = totalWeight + weight
		while lastIndex ~= totalWeight do
			lastIndex = lastIndex + 1
			table.insert(indexedResults, lastIndex, resultObject)
		end
	end

	local result = math.random(1, lastIndex)

	return indexedResults[result]
end

-- Determines if a library of LUA code identified by the parameter is available for loading.
function isPackageAvailable(packageName) 
    if package.loaded[packageName] then 
        return true
    else
        for _, searcher in ipairs(package.searchers or package.loaders) do
            local packageLoader = searcher(packageName)
            if type(packageLoader) == 'function' then
                return true
            end
        end

        return false
    end
end

-- JSON parsing.
local next = next

local isJsonArray
local isJsonEncodable
local jsonEncodeString

-- Encodes the provided Lua object into JSON.
-- Accepts any Lua value or table.
function jsonEncode(value)
    if value == nil then
        return "{}"
    end

    local valueType = type(value)

    if valueType == "string" then
        return '"' .. jsonEncodeString(value) .. '"'
    end

    if valueType == "boolean" or valueType == "number" then
        return tostring(value)
    end

    if valueType == "table" then
        local currentElement = {}
        local array, length = isJsonArray(value)

        if array then 
            for i = 1, length do
                table.insert(currentElement, jsonEncode(value[i]))
            end
        else
            for i, j in pairs(value) do
                if isJsonEncodable(i) and isJsonEncodable(j) then
                    table.insert(currentElement, '"' .. jsonEncodeString(i) .. '":' .. jsonEncode(j))
                end
            end
        end
        if array then
            return "[" .. table.concat(currentElement, ",") .. "]"
        else
            return "{" .. table.concat(currentElement, ",") .. "}"
        end
    end

    assert(false, "Attempted to JSON encode unsupported type " .. valueType .. ":" .. tostring(value))
end

local escapedCharacters = {
    ['\b'] = '\\b',
    ['\f'] = '\\f',
    ['\n'] = '\\n',
    ['\r'] = '\\r',
    ['\t'] = '\\t',    
    ['"'] = '\\"',
    ['\\'] = '\\\\',
    ['/'] = '\\/'
}

function jsonEncodeString(value)
    local stringValue = tostring(value)

    return stringValue:gsub(".", function(s) return escapedCharacters[s] end)
end

function isJsonEncodable(value)
    local valueType = type(value)

    return any(valueType, "string", "boolean", "number", "nil", "table")  
end

function isJsonArray(value)
    -- Check if this is an empty table.
    if (next(value) == nil) then
        return true, 0
    end

    local length = 0

    for k,v in pairs(value) do
        if (type(k) == "number" and math.floor(k) == k and 1 <= k) then
            if (not isJsonEncodable(v)) then return false end
            length = math.max(length,k)
        else
            if (k == "n") then
                if v ~= (t.n or #t) then return false end
            else
                if isJsonEncodable(v) then return false end
            end
        end
    end

    return true, length
end