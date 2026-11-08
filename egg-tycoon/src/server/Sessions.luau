-- Sessions
-- Uma sessao por jogador. Fonte unica de verdade no servidor.

local Sessions = {}

Sessions.byPlayer = {} -- [Player] = { data, farm, base }

function Sessions.get(player)
	return Sessions.byPlayer[player]
end

function Sessions.data(player)
	local session = Sessions.byPlayer[player]
	return session and session.data
end

function Sessions.farm(player)
	local session = Sessions.byPlayer[player]
	return session and session.farm
end

function Sessions.all()
	return Sessions.byPlayer
end

return Sessions
