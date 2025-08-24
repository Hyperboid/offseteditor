local imgui = Imgui.lib
local ffi = require("ffi")

---@class OffsetEditorApplet: ImguiApplet
local OffsetEditorApplet, super = Class("ImguiApplet", "OffsetEditorApplet")
---@cast super ImguiApplet

function OffsetEditorApplet:init()
    super.init(self, "Offset Editor", imgui.ImGuiWindowFlags_MenuBar)
    self.initial_size = imgui.ImVec2_Float(1440, 800)
    self:setActor("kris")
    self.scale_factor = 8
end

function OffsetEditorApplet:setActor(actor)
    if type(actor) == "string" then
        actor = Registry.createActor(actor)
    end

    self.current_actor = actor
    self.current_actor_id = actor.id
    self.default_sprite = actor:getDefaultSprite() or actor:getDefault()
    self.current_sprite = self.default_sprite
    local sprite_choices = Utils.copy(actor.offsets)
    if sprite_choices[self.current_sprite .. "/down"] then
        self.current_sprite = self.current_sprite .. "/down"
    else
        sprite_choices[self.current_sprite] = true
    end
    self.sprite_choices = {}
    for key, _ in Utils.orderedPairs(sprite_choices) do
        table.insert(self.sprite_choices, key)
    end
end

function OffsetEditorApplet:getActorTextures()
    local actor_sprite_path = (self.current_actor):getSpritePath()
    local base_texture_path = actor_sprite_path.."/"..self.default_sprite
    local base_texture = (Assets.getFramesOrTexture(base_texture_path) or Assets.getFramesOrTexture(base_texture_path.."/down") or Assets.getFramesOrTexture(actor_sprite_path))[1]
    local current_texture_path = actor_sprite_path.."/"..self.current_sprite
    local current_texture = (Assets.getFramesOrTexture(current_texture_path) or Assets.getFramesOrTexture(current_texture_path.."/down") or {base_texture})[1]
    return base_texture, current_texture
end

function OffsetEditorApplet:show()
    if (imgui.BeginMenuBar()) then
        if (imgui.BeginMenu("File")) then
            if imgui.BeginMenu("Open") then
                for actor_id, actor_class in Utils.orderedPairs(Registry.actors) do
                    if actor_class.createSprite == Actor.createSprite then
                        if (imgui.Selectable_Bool(actor_id, self.current_actor_id == actor_id)) then
                            self:setActor(actor_id)
                        end
                    end
                end
                imgui.EndMenu()
            end
            if (imgui.MenuItem_Bool("Close", "Ctrl+W")) then self:setOpen(false) end
            imgui.EndMenu();
        end
        imgui.EndMenuBar();
    end
    do
        imgui.BeginChild_Str("sprite select pane", imgui.ImVec2_Float(200, 0), bit.bor(imgui.ImGuiChildFlags_Borders, imgui.ImGuiChildFlags_ResizeX));
        for _, sprite_id in ipairs(self.sprite_choices) do
            local label = sprite_id
            if label == "" then
                label = "<empty>"
            end
            if (imgui.Selectable_Bool(label, self.current_sprite == sprite_id)) then
                self.current_sprite = sprite_id
            end
        end
        imgui.EndChild();
    end
    imgui.SameLine();
    -- Right
    imgui.BeginGroup();

    imgui.BeginChild_Str("item view", imgui.ImVec2_Float(0, -imgui.GetFrameHeightWithSpacing())); -- Leave room for 1 line below us
    do
        local function floorvec(vec)
            vec.x = math.floor(vec.x)
            vec.y = math.floor(vec.y)
            return vec
        end
        -- self.scale_factor = Utils.wave(Kristal.getTime()*math.pi/32,8,16)
        local base_texture, current_texture = self:getActorTextures()
        local canvas_p0 = imgui.GetCursorScreenPos()      -- ImDrawList API uses screen coordinates!
        local canvas_sz = imgui.GetContentRegionAvail()   -- Resize canvas to what's available
        local draw_list = imgui.GetWindowDrawList();
        local topright = (canvas_p0 + (canvas_sz/2)) - imgui.ImVec2_Float(self.current_actor:getWidth()*self.scale_factor/2, self.current_actor:getHeight()*self.scale_factor/2) ---@type imgui.ImVec2
        imgui.InvisibleButton("canvas", canvas_sz, bit.bor(imgui.ImGuiButtonFlags_MouseButtonLeft, imgui.ImGuiButtonFlags_MouseButtonRight));
        local offsetx, offsety = self.current_actor:getOffset(self.current_sprite)
        offsetx, offsety = math.floor(offsetx), math.floor(offsety)
        draw_list:AddText_Vec2(canvas_p0, imgui.color(COLORS.white), string.format("[%q] = {%d, %d}", self.current_sprite, offsetx, offsety), nil)
        if imgui.IsItemHovered() and imgui.IsItemActive() then
            local delta = imgui.C.igGetIO().MouseDelta / self.scale_factor
            self.current_actor.offsets[self.current_sprite] = self.current_actor.offsets[self.current_sprite] or {0,0}
            self.current_actor.offsets[self.current_sprite][1] = self.current_actor.offsets[self.current_sprite][1] + delta.x
            self.current_actor.offsets[self.current_sprite][2] = self.current_actor.offsets[self.current_sprite][2] + delta.y
        end
        local offset = floorvec(imgui.ImVec2_Float(self.current_actor:getOffset(self.default_sprite))) * self.scale_factor
        draw_list:AddImage(imgui.love.TextureRef(base_texture), floorvec(offset + topright), floorvec(offset + topright + (imgui.ImVec2_Float(base_texture:getDimensions())*self.scale_factor)), nil, nil, imgui.color(.5,.5,.5,0.5))
        offset = floorvec(imgui.ImVec2_Float(self.current_actor:getOffset(self.current_sprite))) * self.scale_factor
        draw_list:AddImage(imgui.love.TextureRef(current_texture), floorvec(offset + topright), floorvec(offset + topright + (imgui.ImVec2_Float(current_texture:getDimensions())*self.scale_factor)), nil, nil, imgui.color(1,1,1,0.8))
    end
    imgui.EndChild();
    if (imgui.Button("Revert")) then end
    imgui.SameLine();
    if (imgui.Button("Copy code")) then
        local offset_code = "self.offsets = {\n"
        for key, value in Utils.orderedPairs(self.current_actor.offsets) do
            offset_code = offset_code .. ("[%q] = {%d, %d};\n"):format(key, value[1], value[2])
        end
        offset_code = offset_code .. "}"
        love.system.setClipboardText(offset_code)
    end
    imgui.EndGroup();
end

return OffsetEditorApplet