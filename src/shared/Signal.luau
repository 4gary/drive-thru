-- Minimal signal / event bus. Handlers run in their own thread so one error can't break the rest.

local Signal = {}
Signal.__index = Signal

export type Connection = { Disconnect: (Connection) -> () }

function Signal.new()
	return setmetatable({ _handlers = {} }, Signal)
end

function Signal:Connect(fn: (...any) -> ())
	local handlers = self._handlers
	local entry = { fn = fn, connected = true }
	table.insert(handlers, entry)
	return {
		Disconnect = function()
			entry.connected = false
			local index = table.find(handlers, entry)
			if index then
				table.remove(handlers, index)
			end
		end,
	}
end

function Signal:Fire(...: any)
	for _, entry in table.clone(self._handlers) do
		if entry.connected then
			task.spawn(entry.fn, ...)
		end
	end
end

-- Named-event bus: Bus:on("Booped", fn), Bus:fire("Booped", player)
local Bus = {}
Bus.__index = Bus

function Signal.bus()
	return setmetatable({ _signals = {} }, Bus)
end

function Bus:_get(name: string)
	local signal = self._signals[name]
	if not signal then
		signal = Signal.new()
		self._signals[name] = signal
	end
	return signal
end

function Bus:on(name: string, fn: (...any) -> ())
	return self:_get(name):Connect(fn)
end

function Bus:fire(name: string, ...: any)
	self:_get(name):Fire(...)
end

return Signal
