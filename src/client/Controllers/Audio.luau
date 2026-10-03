-- Sounds + the Munchie's jingle. The jingle is played note-by-note from one sound so the scare
-- versions can be the same tune slowed, detuned or backwards (design doc §6.5).

local SoundService = game:GetService("SoundService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)

local Audio = {}

local function spawnSound(def, volume: number, speed: number, pos: Vector3?): Sound?
	if not def or def.id == nil or def.id == "" then
		return nil
	end
	local sound = Instance.new("Sound")
	sound.SoundId = def.id
	sound.Volume = volume
	sound.PlaybackSpeed = speed
	if pos then
		local attachment = Instance.new("Attachment")
		attachment.WorldPosition = pos
		attachment.Parent = workspace.Terrain
		sound.RollOffMaxDistance = 140
		sound.RollOffMinDistance = 8
		sound.Parent = attachment
		sound.Ended:Connect(function()
			attachment:Destroy()
		end)
		task.delay(12, function()
			if attachment.Parent then
				attachment:Destroy()
			end
		end)
	else
		sound.Parent = SoundService
		sound.Ended:Connect(function()
			sound:Destroy()
		end)
		task.delay(12, function()
			if sound.Parent then
				sound:Destroy()
			end
		end)
	end
	sound:Play()
	return sound
end

function Audio.play(name: string, opts: { [string]: any }?)
	local def = Config.Sounds[name]
	if not def then
		return
	end
	local o = opts or {}
	spawnSound(def, (o.volume or def.volume or 0.5), (o.speed or def.speed or 1), o.pos)
end

-- "♪ Munch munch munchie's, the late-night lunchie's ♪"
local MELODY = {
	{ 0, 0.18 },
	{ 0, 0.18 },
	{ 4, 0.18 },
	{ 7, 0.36 },
	{ 9, 0.18 },
	{ 7, 0.18 },
	{ 4, 0.18 },
	{ 5, 0.18 },
	{ 4, 0.18 },
	{ 0, 0.5 },
}

-- mode: "normal" | "slow" | "backwards" | "chorus"
function Audio.jingle(mode: string?)
	local m = mode or "normal"
	local notes = table.clone(MELODY)
	local tempo = 1
	local pitch = 1
	if m == "slow" then
		tempo = 1.9
		pitch = 0.62
	elseif m == "backwards" then
		local reversed = {}
		for i = #notes, 1, -1 do
			table.insert(reversed, notes[i])
		end
		notes = reversed
		tempo = 1.4
		pitch = 0.8
	end
	local voices = if m == "chorus" then { { 0, 1 }, { 0.07, 0.97 }, { 0.15, 1.03 } } else { { 0, 1 } }
	for _, voice in voices do
		task.delay(voice[1], function()
			for _, note in notes do
				local speed = pitch * voice[2] * 2 ^ (note[1] / 12)
				Audio.play("Note", { speed = speed * 1.2 })
				task.wait(note[2] * tempo)
			end
		end)
	end
end

-- Animal Crossing-style gibberish for speaker voices.
function Audio.blip(seed: number, weird: boolean?)
	local base = 0.9 + (seed % 10) / 12
	local speed = base * (0.92 + math.random() * 0.16)
	if weird then
		speed *= if math.random() < 0.5 then 0.55 else 1.6
	end
	Audio.play("Note", { speed = speed * 1.6, volume = 0.18 })
end

function Audio.init() end

return Audio
