local ecs = ...
local world = ecs.world

local editor_mainwin = require "editor.window"
local menu = require "editor.menu"
local eu = require "editor.util"
local su = require "serialize.util"

local editor_sys = ecs.system "editor_system"
editor_sys.singleton "math_stack"
editor_sys.depend "end_frame"

local function build_hierarchy_tree()
	local htree = {}
	local ud_table = {}
	local eidin_hierarchy = {}

	local function add_entity(eid, defname)
        assert(not eidin_hierarchy[eid])
        eidin_hierarchy[eid] = true
        local e = world[eid]
		local ename = e.name
		local name = ename and ename.n or defname
		ud_table[name] = eid
        table.insert(htree, name)
	end

	for _, maincomp in ipairs {"main_camera", } do
		for _, eid in world:each(maincomp) do
			local defname = maincomp
			add_entity(eid, defname)
		end
	end
	
	local function is_obj_transform(e)
		local obj_transform_names = {"pos_transform", "scale_transform", "rotation_transform"}
		for _, n in ipairs(obj_transform_names) do
			if e[n] then
				return true
			end
		end

		return false
	end

    for _, eid in world:each("editable_hierarchy") do
		eidin_hierarchy[eid] = true		
		local e = world[eid]
		
		if not is_obj_transform(e) then
			local hierarchy_tree = e.editable_hierarchy.root
			local name_mapper = e.hierarchy_name_mapper.v
			local function build_hierarchy_entity_tree(ehierarchy, name_mapper)
				local t = {}
				local num = #ehierarchy
				for i=1, num do
					local child = ehierarchy[i]
					local childnum = #child
					local ceid = name_mapper[child.name]
					if ceid and eidin_hierarchy[ceid] == nil then
						eidin_hierarchy[ceid] = true
						ud_table[child.name] = ceid
						if childnum ~= 0 then
							local ct = build_hierarchy_entity_tree(child, name_mapper)
							t[child.name] = ct
						else
							table.insert(t, child.name)
						end
					end

				end
				return t
			end

			local t = build_hierarchy_entity_tree(hierarchy_tree, name_mapper)        
			local ename = e.name
			local name = ename and ename.n or "hierarchy_entity"
			htree[name] = t
			ud_table[name] = eid
		end
    end

    for _, eid in world:each("can_render") do
		if not eidin_hierarchy[eid] then			
            local e = world[eid]
            if not is_obj_transform(e) and e.can_render.visible then
				local ename = e.name
				local name = ename and ename.n or "entity"
				table.insert(htree, name)
				ud_table[name] = eid
            end
        end
	end
	
	return htree, ud_table
end

local function build_entity_tree(eid, ms)
	-- local e = assert(world[eid])

	-- local function build_elem_tree(tr, filter)
	-- 	local t = {}
	-- 	for k, v in pairs(tr) do
	-- 		local ignore = filter and filter[k] or nil
	-- 		if not ignore then
	-- 			local ktype = type(k)
	-- 			if ktype == "string" or ktype == "number" then
	-- 				local vtype = type(v)
	-- 				if vtype == "table" then
	-- 					local r = build_elem_tree(v, filter)
	-- 					t[k] = r
	-- 				elseif vtype == "function" or vtype == "cfunction" then
	-- 					t[k] = "...function..."
	-- 				elseif vtype == "userdata" or vtype == "luserdata" then						
	-- 					t[k] = tostring(v) or "...userdata..."
	-- 				elseif vtype == "string" then
	-- 					t[k] = v
	-- 				elseif vtype == "number" or  vtype == "boolean" then
	-- 					t[k] = tostring(v)
	-- 				else
	-- 					dprint("not support value type : ", vtype, ", key is : ", k)
	-- 				end
	-- 			else
	-- 				dprint("not support key type : ", ktype)
	-- 			end
	-- 		else
	-- 			t[k] = v
	-- 		end
	-- 	end

	-- 	return t
	-- end

	-- local tr = {}
	-- for cname, v in pairs(e) do
	-- 	local etr = build_elem_tree(v)
	-- 	tr[cname] = etr
	-- end
	-- return tr

	return su.save_entity(world, eid, ms)	
end

function editor_sys:init()
	local hv = editor_mainwin.hierarchyview
	
	local function build_hv()
		local htree, ud_table = build_hierarchy_tree()
		hv:build(htree, ud_table)
	end

	build_hv()

	local pv = editor_mainwin.propertyview
	local ms = self.math_stack
	local function build_pv(eid)
		local ptree = build_entity_tree(eid, ms)
		pv:build(ptree)

		function pv.tree:rightclick_cb(id, status)			
			local addsubmenu = {name="Add", type="submenu",}
	
			local function get_hv_selnode()
				local hvtree = hv.window
				local selid = hvtree.view["VALUE"]
				return selid and hvtree:findchild_byid(tonumber(selid)) or nil
			end
	
			local add_action =  function(menuitem)
				local cname = menuitem.TITLE
				local node = get_hv_selnode()
				if node then
					local eid = node.eid
					world:add_component(eid, cname)
					build_pv(eid)
				else
					log("add component failed, component is : ", cname, 
					", but could not get hierarchy view select node, return nil")
				end

			end

			local added_components = {}
			for i=0, self.view.COUNT-1 do
				local name = self.view["TITLE" .. i]
				added_components[name] = true
			end

			for cname in pairs(world._component_type) do
				local active = added_components[cname] and "NO" or "YES"
				table.insert(addsubmenu, {name=cname, type="item", action=add_action, active=active})
			end
	
			local m = menu.new {
				recipe = {
					addsubmenu,
					{name="Delete", type="item", action=function ()
						local hvnode = get_hv_selnode()						
						local eid = hvnode.eid
						local cname = self.view["TITLE"..id]
						world:remove_component(eid, cname)
						build_pv(eid)
					end},
				}
			}
	
			local x, y = eu.get_cursor_pos()
			m:show(x, y)
		end
	end
	function hv.window:selection_cb(id, status)
		if status == 1 then
			local node = self:findchild_byid(id)
			if node then
				build_pv(node.eid)
			end
		end
	end

	function hv.window:rightclick_cb(id, status)
		local m = menu.new {
			recipe = {
				{name="create entity...", type="item", action=function () 
				local eid = world:new_entity("name", "render")
				local e = world[eid]
				e.name.n = "NewEntity" .. eu.get_new_entity_counter()

				build_hv()
			end}
			},
			open_cb = nil,
			menclose_cb = nil,
		}
		local x, y = eu.get_cursor_pos()
		m:show(x, y)
	end
end