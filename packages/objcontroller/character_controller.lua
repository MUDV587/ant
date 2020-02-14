local ecs = ...
local world = ecs.world

local ms = import_package "ant.math".stack
local objutil = require "util"

local timer = world:interface "ant.timer|timer"

local cc = ecs.system "character_controller"
cc.require_system "objcontroller_system"
cc.require_interface "ant.timer|timer"


local objctrller = require "objcontroller"

function cc:init()
	-- TODO: we need to control the character state machine after "state_machine" on animation is finished, 
	-- then let the state machine to control the charather
	objctrller.register {
		tigger = {jump = {{name="keyboard", key = " ", press=true, state={}}}}
	}

	local function move(value, x, y, z)
		local delta = timer.delta()
		local character --TODO
		
		local movespeed = character.character.movespeed
		local deltatime = delta * 0.001 * value

		local physic_state = character.physic_state
		local srt = character.transform
		local result = ms({movespeed * value}, srt.r, "d*T")
		local velocity = physic_state.velocity
		velocity[1], velocity[2], velocity[3] = result[1], result[2], result[3]		

		local delta_dis = movespeed * deltatime
		if x then
			ms()
			x = x * delta_dis
		end
		if y then
			y = y * delta_dis
		end

		if z then
			z = z * delta_dis
		end
		objutil.move(character, x, y, z)
	end

	objctrller.bind_constant("move_forward", function (value)
		move(value, nil, nil, 1)
	end)

	objctrller.bind_constant("move_left", function (value)
		move(value, 1)
	end)

	objctrller.bind_tigger("jump", function (event)
		
	end)
end

function cc:update()
	
end