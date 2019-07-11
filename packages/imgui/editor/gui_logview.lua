local imgui   = require "imgui_wrap"
local widget = imgui.widget
local flags = imgui.flags
local windows = imgui.windows
local util = imgui.util
local cursor = imgui.cursor
local enum = imgui.enum
local IO = imgui.IO
local class     = require "common.class"
local gui_input = require "gui_input"
local GuiBase = require "gui_base"
local GuiLogView = GuiBase.derive("GuiLogView")

local ScrollList = require "controls.scroll_list"

GuiLogView.GuiName = "GuiLogView"

local function time2str( time )
    local fmt = "%Y-%m-%d %H:%M:%S:"
    local ti, tf = math.modf(time)
    return os.date(fmt, ti)..string.format("%03d",math.floor(tf*1000))
end

local DefaultColor =  {111/255,111/255,111/255,1}
local function color2tbl(color)
    if color == nil then
        return nil,nil
    end
    repeat
        if type(color)=="table" and #color == 4 then
            return color
        end
        if type(color) == "string" then
            if string.match(color,"^#[0-9a-fA-F]+$") then
                local len = #color
                if len == 7 or len == 9 then
                    local num = len//2
                    local result = {}
                    for i = num,1,-1 do
                        local v = string.sub(color,-2*i,-2*i+1)
                        table.insert(result,tonumber(v,16)/255)
                    end
                    if num == 3 then
                        table.insert(result,1)
                    end
                    return result
                end
            end
        end
    until true
    return DefaultColor,"Color Format Error"
end
local ColorFormatTips = "For Example:Red is {1,0,0,1} or \"#FF0000\" or \"#FF0000FF\""

local Colors = {
    trace = {85/255,87/255,84/255,0.8},
    info = {62/255,154/255,73/255,0.8},
    warn = {229/255,241/255,33/255,0.8},
    error = {255/255,0,0,0.8},
    fatal = {214/255,78/255,207/255,0.8},
    other = DefaultColor,
}

local Levels = {"trace","info","warn","error","fatal","other"}

function GuiLogView:_init()
    GuiBase._init(self)
    self.title_id = "GuiLogView"
    self.win_flags = flags.Window { "MenuBar" }
    self._is_opened = true
    self.all_items = {}
    self.filter_indexs = {}
    self.up_precent = 0.7
    self.type_count = {}
    self.follow_tail = true
    self.show_time = false
    for i,v in ipairs(Levels) do
        self.type_count[v] = 0
    end
    self.type_filter = {}
    for i,v in ipairs(Levels) do
        self.type_filter[v] = true
    end
    -----
    self:_init_scroll_list()
    self:hook_log()
end

function GuiLogView:match_filter(msg_item)
    return self.type_filter[msg_item.type or "other"]
end

function GuiLogView:get_msg_item(filter_index)
    return self.all_items[self.filter_indexs[filter_index]]
end

function GuiLogView:_init_scroll_list()
    self.scroll_list = ScrollList.new()
    local data_func = function(index,sx,sy)
        self:_update_item(index,sx,sy)
    end
    self.scroll_list:set_data_func(data_func)
    -- self.scroll_list:scroll_to_last(self.follow_tail)
end

function GuiLogView:_init_select_cache()
    local height = cursor.GetFrameHeight()
    print("FrameHeight",height)
    self.selected_cache = {"###0",height=height,item_flags = 0}
end

function GuiLogView:add_item(log_item)

    log_item.time_str = time2str(log_item.time)
    log_item.color_t,log_item.color_err = color2tbl(log_item.color)
    table.insert(self.all_items,log_item)
    if self:match_filter(log_item) then
        table.insert(self.filter_indexs,#self.all_items)
        self.scroll_list:add_item_num(1)
        if self.follow_tail then
            self.scroll_list:scroll_to_last()
        end
    end
    local typ = log_item.type or "other"
    self.type_count[typ] = self.type_count[typ] + 1
end

function GuiLogView:_update_item(index,start_x,start_y)
    util.PushID(index)
    local msg_item = self:get_msg_item(index)
    local color = msg_item.color_t or Colors[msg_item.type or "other"]
    local c1,c2,c3,c4 = table.unpack(color)
    windows.PushStyleColor(enum.StyleCol.Button,c1,c2,c3,c4)
    windows.PushStyleColor(enum.StyleCol.ButtonActive,c1,c2,c3,c4)
    windows.PushStyleColor(enum.StyleCol.ButtonHovered,c1,c2,c3,c4)
    widget.Button(string.upper(msg_item.type or "other"),60)
    windows.PopStyleColor(3)
    if self.show_time then
        cursor.SameLine()

        widget.Text(msg_item.time_str)
    end
    cursor.SameLine()
    cursor.SetNextItemWidth(-1)
    widget.LabelText("##msg",msg_item.msg)
    cursor.SetCursorPos(start_x,start_y)
    local title_id = string.format("###%d",index)
    if widget.Selectable(title_id,self.selected_cache) then
        self.selected_cache[1] = title_id
        self.selected_cache[2] = index
        self.selected_cache[3] = nil
        -- util.SetItemDefaultFocus()
    end
    util.PopID()
end

local cbval = false
function GuiLogView:on_update()
    if not self.selected_cache then
        self:_init_select_cache()
    end
    local winw,h = windows.GetContentRegionAvail()
    local menu_height = self:_update_menu_bar()
    h = h  - menu_height
    local up_h = math.floor(h * self.up_precent+0.5)

    windows.BeginChild("up_content",0,up_h,false)
    -- windows.SetWindowFontScale(0.9)
    local has_scroll_by_user = self.scroll_list:update()
    if has_scroll_by_user and self.follow_tail then
        self.follow_tail = false
    end
    windows.EndChild()
    ------------------------
    windows.PushStyleVar(enum.StyleVar.ItemSpacing,0,0)
    local _,cur_y = cursor.GetCursorPos()
    cursor.SetCursorPos(nil,cur_y+3)
    cursor.Separator()
    cursor.SetCursorPos(nil,cur_y)
    widget.InvisibleButton("vsplitter",winw,7)
    windows.PopStyleVar()
    if util.IsItemActive() then
        local new_up_h = up_h + gui_input.get_mouse_delta().y
        self.up_precent = new_up_h/h
        self.up_precent = math.min(0.9,self.up_precent)
        self.up_precent = math.max(0.1,self.up_precent)
    end
    -------------------------------
    if windows.BeginChild("down_content",winw,0,false,0) then
        local selected_cache = self.selected_cache
        local selected_index = selected_cache[2]
        if selected_index then
            local msg_item = self:get_msg_item(selected_index)
            local ui_cache = selected_cache[3]
            if not ui_cache then
                local str_t = {}
                if msg_item.color_err then
                    table.insert(str_t,msg_item.color_err)
                    table.insert(str_t,string.format("The given value is:%s",dump_a({msg_item.color})))
                    table.insert(str_t,ColorFormatTips)
                    table.insert(str_t,"--------------------------------------")
                end
                table.insert(str_t,msg_item.time_str)
                table.insert(str_t,msg_item.msg)
                local display_str = table.concat(str_t,"\n")
                ui_cache = {
                    text = display_str,
                    flags = flags.InputText{ "Multiline","ReadOnly"},
                    width = -1,
                    height = -1,
                }
                selected_cache[3] = ui_cache
            end
            -- widget.PushTextWrapPos(200.0)
            widget.InputText("##detail",ui_cache)
            -- widget.PopTextWrapPos()

        end
    end
    windows.EndChild()
end

function GuiLogView:_show_filter_popup()
    if windows.BeginPopupContextItem("filter_popup",0) then
        local filter_change = false
        local change_count = 0
        for i,v in ipairs(Levels) do
            local color = Colors[v]
            windows.PushStyleColor( enum.StyleCol.Header,table.unpack(color))
            if widget.Selectable(v,self.type_filter[v],60,0,flags.Selectable.DontClosePopups) then
                self.type_filter[v] = not self.type_filter[v]
                filter_change = true
                change_count = change_count + self.type_count[v]
            end
            windows.PopStyleColor()
            cursor.SameLine()
            widget.Text(tostring(self.type_count[v]))
        end
        if filter_change then
            self:on_filter_change(change_count>0)
        end
        -- windows.CloseCurrentPopup()
        windows.EndPopup()
    end
end

function GuiLogView:_update_menu_bar()
    local _,y1 = cursor.GetCursorPos()
    if widget.BeginMenuBar() then
        widget.Button("Filter")
        self:_show_filter_popup()
        local change
        change,self.follow_tail = widget.Checkbox("Follow Tail",self.follow_tail)
        if change and self.follow_tail then
            self.scroll_list:scroll_to_last()
        end
        change,self.show_time = widget.Checkbox("Show Time",self.show_time)
        if widget.Button("AddItem") then
            for i = 1,100 do
                local msg_item = {type="trace", msg = "asdasdasdas\ndasd\nasdasdasdddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd"}
                local t = {"trace","warn","fatal","error","info"}
                msg_item.type =  t[math.random(6)]
                msg_item.color = "asda"
                msg_item.time =  os.time()
                self:add_item(msg_item)
            end
        end
        local avail_w,_ = windows.GetContentRegionAvail()
        cursor.Dummy(avail_w-65,0)
        if widget.Button("Clear",-1) then
            self:on_clear_click()
        end
        widget.EndMenuBar()
    end
    local _,y2 = cursor.GetCursorPos()
    return y2-y1
end

function GuiLogView:on_clear_click()
    self.scroll_list:remove_all()
    self:_init_select_cache()
    self.all_items = {}
    for i,v in ipairs(Levels) do
        self.type_count[v] = 0
    end
    self.filter_indexs = {}
end

function GuiLogView:on_filter_change(need_refresh)
    if need_refresh then
        self.scroll_list:remove_all()
        local new_filter_indexs = {}
        for i,v in ipairs(self.all_items) do
            if self:match_filter(v) then
                table.insert(new_filter_indexs,i)
            end
        end
        self.filter_indexs = new_filter_indexs
        self.scroll_list:add_item_num(#new_filter_indexs)
        self:_init_select_cache()
    end
end

function GuiLogView:hook_log()
    log.set_output(function(cfg,msg,time)
        local msg_item = setmetatable({msg=msg,time = time},{__index = cfg})
        self:add_item(msg_item)
    end)
end

return GuiLogView