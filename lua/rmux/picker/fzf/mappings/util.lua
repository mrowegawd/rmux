local M = {}

local nbsp = "\xe2\x80\x82" -- "\u{2002}"

local function __lastIndexOf(haystack, needle)
	local i = haystack:match(".*" .. needle .. "()")
	if i == nil then
		return nil
	else
		return i - 1
	end
end

local function __stripBeforeLastOccurrenceOf(str, sep)
	local idx = __lastIndexOf(str, sep) or 0
	return str:sub(idx + 1), idx
end

local function __strip_ansi_coloring(str)
	if not str then
		return str
	end

	-- remove escape sequences of the following formats:
	-- 1. ^[[34m
	-- 2. ^[[0;34m
	-- 3. ^[[m
	return str:gsub("%[[%d;]-m", "")
end

function M.__strip_str(selected)
	local pth = __strip_ansi_coloring(selected)
	if pth == nil then
		return
	end
	return __stripBeforeLastOccurrenceOf(pth, nbsp)
end

return M
