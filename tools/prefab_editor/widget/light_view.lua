local ecs = ...
local world = ecs.world
local w = world.w
local ilight    = ecs.import.interface "ant.render|ilight"
local light_gizmo = ecs.require "gizmo.light"
local gizmo = ecs.require "gizmo.gizmo"
ecs.require "widget.base_view"

local utils     = require "common.utils"
local math3d    = require "math3d"
local uiproperty= require "widget.uiproperty"
local hierarchy = require "hierarchy_edit"

local imgui     = require "imgui"

local view_class = require "widget.view_class"
local BaseView, LightView  = view_class.BaseView, view_class.LightView

local MOTION_TYPE_options<const> = {
    "dynamic", "station", "static"
}

function LightView:_init()
    BaseView._init(self)
    self.subproperty = {
        color        = uiproperty.Color({label = "Color", dim = 4}, {
            getter = function() return self:on_get_color() end,
            setter = function(...) self:on_set_color(...) end,
        }),
        intensity    = uiproperty.Float({label = "Intensity", min = 0, max = 250000}, {
            getter = function() return self:on_get_intensity() end,
            setter = function(value) self:on_set_intensity(value) end,
        }),
        range        = uiproperty.Float({label = "Range", min = 0, max = 500},{
            getter = function() return self:on_get_range() end,
            setter = function(value) self:on_set_range(value) end,
        }),
        inner_radian = uiproperty.Float({label = "InnerRadian", min = 0, max = 180},{
            getter = function() return self:on_get_inner_radian() end,
            setter = function(value) self:on_set_inner_radian(value) end,
        }),
        outter_radian= uiproperty.Float({label = "OutterRadian", min = 0, max = 180}, {
            getter = function() return self:on_get_outter_radian() end,
            setter = function(value) self:on_set_outter_radian(value) end,
        }),
        type  = uiproperty.EditText({label = "LightType", readonly=true}, {
            getter = function ()
                local e <close> = w:entity(self.eid, "light:in")
                return ilight.which_type(e)
            end,
            --no setter
        }),
        make_shadow = uiproperty.Bool({label = "MakeShadow"},{
            getter = function ()
                local e <close> = w:entity(self.eid, "light:in")
                return ilight.make_shadow(e)
            end,
            setter = function (value)
                local e <close> = w:entity(self.eid, "make_shadow:out")
                e.make_shadow = value
            end,
        }),
        bake        = uiproperty.Bool({label = "Bake", disable=true}, {
            getter = function () return false end,
            setter = function (value) end,
        }),
        motion_type = uiproperty.Combo({label = "motion_type", options=MOTION_TYPE_options}, {
            getter = function ()
                local e <close> = w:entity(self.eid, "light:in")
                return ilight.motion_type(e)
            end,
            setter = function (value)
                local e <close> = w:entity(self.eid, "light:in")
                ilight.set_motion_type(e, value)
             end,
        }),
        angular_radius= uiproperty.Float({label="AngularRadius", disable=true,}, {
            getter = function()
                local e <close> = w:entity(self.eid, "light:in")
                return math.deg(ilight.angular_radius(e))
            end,
            setter = function(value)
                local e <close> = w:entity(self.eid, "light:in")
                ilight.set_angular_radius(e, math.rad(value))
            end,
        }),
    }

    self.light_property= uiproperty.Group({label = "Light"}, {})
end

function LightView:set_model(eid)
    if not BaseView.set_model(self, eid) then return false end
    local subproperty = {}
    subproperty[#subproperty + 1] = self.subproperty.color
    subproperty[#subproperty + 1] = self.subproperty.intensity

    subproperty[#subproperty + 1] = self.subproperty.motion_type
    subproperty[#subproperty + 1] = self.subproperty.make_shadow
    subproperty[#subproperty + 1] = self.subproperty.bake
    subproperty[#subproperty + 1] = self.subproperty.angular_radius

    local e <close> = w:entity(eid, "light:in")
    if e.light.type ~= "directional" then
        subproperty[#subproperty + 1] = self.subproperty.range
        if e.light.type == "spot" then
            subproperty[#subproperty + 1] = self.subproperty.inner_radian
            subproperty[#subproperty + 1] = self.subproperty.outter_radian
        end
    end
    self.light_property:set_subproperty(subproperty)
    self:update()
    return true
end

function LightView:on_set_color(...)
    local template = hierarchy:get_template(self.eid)
    template.template.data.light.color = ...
    local e <close> = w:entity(self.eid, "light:in")
    ilight.set_color(e, ...)
end

function LightView:on_get_color()
    local e <close> = w:entity(self.eid, "light:in")
    return ilight.color(e)
end

function LightView:on_set_intensity(value)
    local template = hierarchy:get_template(self.eid)
    template.template.data.light.intensity = value
    local e <close> = w:entity(self.eid, "light:in")
    ilight.set_intensity(e, value)
    light_gizmo.update_gizmo()
end

function LightView:on_get_intensity()
    local e <close> = w:entity(self.eid, "light:in")
    return ilight.intensity(e)
end

function LightView:on_set_range(value)
    local template = hierarchy:get_template(self.eid)
    template.template.data.light.range = value
    local e <close> = w:entity(self.eid, "light:in")
    ilight.set_range(e, value)
    light_gizmo.update_gizmo()
end

function LightView:on_get_range()
    local e <close> = w:entity(self.eid, "light:in")
    return ilight.range(e)
end

function LightView:on_set_inner_radian(value)
    local template = hierarchy:get_template(self.eid)
    local radian = math.rad(value)
    template.template.data.light.inner_radian = radian
    local e <close> = w:entity(self.eid, "light:in")
    ilight.set_inner_radian(e, radian)
    light_gizmo.update_gizmo()
end

function LightView:on_get_inner_radian()
    local e <close> = w:entity(self.eid, "light:in")
    return math.deg(ilight.inner_radian(e))
end

function LightView:on_set_outter_radian(value)
    local template = hierarchy:get_template(self.eid)
    local radian = math.rad(value)
    if radian < template.template.data.light.inner_radian then
        radian = template.template.data.light.inner_radian
        self.subproperty.outter_radian:update()
    end
    template.template.data.light.outter_radian = radian
    local e <close> = w:entity(self.eid, "light:in")
    ilight.set_outter_radian(e, radian)
    light_gizmo.update_gizmo()
end

function LightView:on_get_outter_radian()
    local e <close> = w:entity(self.eid, "light:in")
    return math.deg(ilight.outter_radian(e))
end

function LightView:update()
    BaseView.update(self)
    self.light_property:update() 
end

function LightView:show()
    BaseView.show(self)
    self.light_property:show()
end

function LightView:has_rotate()
    local e <close> = w:entity(self.eid, "light:in")
    return e.light.type ~= "point"
end

function LightView:has_scale()
    return false
end

return LightView