-- Format
-- Formatacao de numeros e tempo usada no HUD. Sem dependencia de `game`.

local Format = {}

local SUFFIXES = { "", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc", "Ud", "Dd" }

function Format.number(value)
	local n = tonumber(value) or 0
	local negative = n < 0
	n = math.abs(n)

	if n < 1000 then
		if n == math.floor(n) then
			return (negative and "-" or "") .. tostring(math.floor(n))
		end
		return (negative and "-" or "") .. string.format("%.1f", n)
	end

	local index = math.floor(math.log10(n) / 3)
	index = math.min(index, #SUFFIXES - 1)

	local scaled = n / (1000 ^ index)
	local text
	if scaled < 10 then
		text = string.format("%.2f", scaled)
	elseif scaled < 100 then
		text = string.format("%.1f", scaled)
	else
		text = string.format("%.0f", scaled)
	end

	-- so corta zeros depois da virgula: "1.50" -> "1.5", "100" fica "100"
	if string.find(text, ".", 1, true) then
		text = text:gsub("0+$", ""):gsub("%.$", "")
	end

	return (negative and "-" or "") .. text .. SUFFIXES[index + 1]
end

function Format.money(value)
	return "$" .. Format.number(value)
end

function Format.time(seconds)
	seconds = math.max(0, math.floor(tonumber(seconds) or 0))
	if seconds < 60 then
		return seconds .. "s"
	elseif seconds < 3600 then
		return string.format("%dm %02ds", seconds // 60, seconds % 60)
	elseif seconds < 86400 then
		return string.format("%dh %02dm", seconds // 3600, (seconds % 3600) // 60)
	end
	return string.format("%dd %02dh", seconds // 86400, (seconds % 86400) // 3600)
end

function Format.percent(value)
	return string.format("%d%%", math.floor(value * 100 + 0.5))
end

return Format
