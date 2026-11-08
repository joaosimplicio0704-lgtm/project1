-- State
-- Snapshot mais recente + assinatura. Sem framework.

local State = {}

State.snapshot = nil
State.static = nil
State.listeners = {}

function State.set(snapshot)
	State.snapshot = snapshot
	for _, callback in ipairs(State.listeners) do
		task.spawn(callback, snapshot)
	end
end

function State.setStatic(data)
	State.static = data
end

function State.subscribe(callback)
	table.insert(State.listeners, callback)
	if State.snapshot then
		task.spawn(callback, State.snapshot)
	end
	return function()
		for index, listener in ipairs(State.listeners) do
			if listener == callback then
				table.remove(State.listeners, index)
				break
			end
		end
	end
end

return State
