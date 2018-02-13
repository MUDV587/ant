local ecs = ...
local world = ecs.world
local math3d = require "math3d"

local render_util = require "render.render_util"
local bgfx = require "bgfx"

--[@
local camera_system = ecs.system "camera_system"
camera_system.singleton "math3d"

function camera_system:update()
	render_util.for_each_comp(world, {"view_transform", "frustum"},
	function (entity)		
		local ct = assert(entity.view_transform)
		local frustum = assert(entity.frustum)

		local viewMat = self.math3d(-ct.eye, -ct.direction, "lm")
		local projMat = self.math3d(-frustum.projMat, "1m")

		bgfx.set_view_transform(0, viewMat, projMat)
	end)
	
end
--@]