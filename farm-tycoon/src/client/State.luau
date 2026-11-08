-- State
-- Snapshot mais recente do servidor + assinatura de listeners. Sem React.

local State = {}

State.snapshot = nil
State.listeners = {}

function State.set(snapshot)
	State.snapshot = snapshot
	for _, callback in ipairs(State.listeners) do
		task.spawn(callback, snapshot)
	end
end

function State.subscribe(callback)
	table.insert(State.listeners, callback)
	if State.snapshot then
		task.spawn(callback, State.snapshot)
	end
	return function()
		for i, listener in ipairs(State.listeners) do
			if listener == callback then
				table.remove(State.listeners, i)
				break
			end
		end
	end
end

return State
