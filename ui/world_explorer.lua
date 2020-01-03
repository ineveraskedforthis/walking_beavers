local mapModes = require "common.lua.mapModes"
local Buttons = require "ui.util.buttons"
local Textbox = require "ui.util.textbox"
local Panels = require "ui.util.panels"
netr = {}
not_netr = {}
netr.log = {}

-- 

local function loop_step()
    netr.update()
    netr.draw()
end
netr.loop_step = loop_step

local function new_colour()
    local colour = not_netr.hsv_to_rgb(netr.last_colour, 0.5, 0.5)
    netr.last_colour = (netr.last_colour + 19) % 360
    return colour
end
netr.new_colour = new_colour

local function add_band(tile)
    netr.log.f("creating new band", netr.log.add_band)
    local colour = netr.new_colour()
    netr.log.f("color is ready", netr.log.add_band)
    netr.band_count = netr.band_count + 1
    netr.log.f("id updated", netr.log.add_band)
    netr.bands[netr.band_count] = netr.Band:new(netr.band_count, tile, colour)
    netr.log.f("band created", netr.log.add_band)
end
netr.add_band = add_band

local function n_log(x, flag)
    if flag then
        log(x)
    end
end
netr.log.f = n_log

local function table_to_Color32(t) 
    return Color32(t[1], t[2], t[3], t[4])
end
netr.table_to_Color32 = table_to_Color32

local function hsv_to_rgb(H, S, V)
    netr.log.f("hsv_to_rgb " .. tostring(H) .. " " .. tostring(S) .. " " .. tostring(V), netr.log.hsv_to_rgb)
    local C = V * S
    local Hs = H / 60
    local X = C * (1 - math.abs(Hs % 2 - 1))
    netr.log.f(tostring(C) .. " " .. tostring(Hs) .. " " .. tostring(X), netr.log.hsv_to_rgb)
    local rgb = nil
    if (0 <= Hs) and (Hs <= 1) then
        rgb = {C, X, 0}
    elseif (1 < Hs) and (Hs <= 2) then
        rgb = {X, C, 0}
    elseif (2 < Hs) and (Hs <= 3) then
        rgb = {0, C, X}
    elseif (3 < Hs) and (Hs <= 4) then 
        rgb = {0, X, C}
    elseif (4 < Hs) and (Hs <= 5) then
        rgb = {X, 0, C}
    elseif (5 < Hs) and (Hs <= 6) then
        rgb = {C, 0, X}
    end
    netr.log.f(tostring(rgb), netr.log.hsv_to_rgb)
    local m = V - C
    return {math.floor(255 * (rgb[1] + m)), math.floor(255 * (rgb[2] + m)), math.floor(255 * (rgb[3] + m)), 255}
end
not_netr.hsv_to_rgb = hsv_to_rgb

local function table_to_string(o)
   if type(o) == 'table' then
      local s = '{ '
      for k,v in pairs(o) do
         if type(k) ~= 'number' then k = '"'..k..'"' end
         s = s .. '['..k..'] = ' .. table_to_string(v) .. ','
      end
      return s .. '} '
   else
      return tostring(o)
   end
end
not_netr.table_to_string = table_to_string

local function set_colour(tile_id, input_colour, save)
    if not netr.flags.draw then
        return
    end
    netr.log.f("planting the seed of colourful heaven", netr.log.set_colour)
    local colour = netr.table_to_Color32(input_colour)
    netr.log.f("death is coming " .. tostring(colour), netr.log.set_colour)
    if netr.map_mode == 'normal' then
        world.tileColor[tile_id] = colour 
    elseif netr.map_mode == 'debug_1' then
        world.tileDemianDebugColor[tile_id] = colour
    elseif netr.map_mode == 'debug_2' then
        world.tileCalaDebugColor[tile_id] = colour
    end
    netr.log.f("waiting for harvest", netr.log.set_colour)
    netr.save_colours(save)
end
netr.set_colour = set_colour

local function save_colours(save)
    if save then
        if netr.map_mode == 'normal' then
            world.ApplyColors(world.tileColorTextures)
        elseif netr.map_mode == 'debug_1' then
            world.UpdateMapMode(mapModes.DEBUG_COLOR_1)
        elseif netr.map_mode == 'debug_2' then
            world.UpdateMapMode(mapModes.DEBUG_COLOR_2)
        end
    end
end
netr.save_colours = save_colours

local function update()
    netr.log.f("update", netr.log.update)
    for i = 1, netr.band_count do
        netr.bands[i]:update()
    end
    netr.log.f("finish update", netr.log.update)
end
netr.update = update

local function draw()
    netr.log.f("draw", netr.log.draw)
    for i = 1, netr.band_count do
        netr.log.f("draw i " .. tostring(i), netr.log.draw)
        netr.bands[i]:draw(false)
    end
    netr.save_colours(netr.color_changed)
    netr.log.f("finish draw", netr.log.draw)
end
netr.draw = draw



--class Band()
netr.Band = {}

function netr.Band:new(id, tile, colour)
    o = {}
    setmetatable(o, self)
    self.__index = self
    o:init(id, tile, colour)
    return o
end

function netr.Band:init(id, tile, colour)
    netr.log.f("init band base values" .. id  .. tile, netr.log.band.init)
    self.id = id
    self.colour = colour
    self.tile = tile
    self.movement_progress = 0
    self.migration_target = nil
    netr.log.f("band base values are ready", netr.log.band.init)
end

function netr.Band:draw(save)
    netr.log.f("draw band", netr.log.draw)
    netr.log.f(netr.set_colour, netr.log.draw)
    netr.set_colour(self.tile, self.colour, save)
    netr.log.f("draw band finished", netr.log.draw)
end

function netr.Band:update()
    self:migration_update()
end

function netr.Band:migration_update()
    netr.log.f("migration update", netr.log.band.migration)
    if self.migration_target == nil then
        local target = nil
        netr.log.f("Band is looking for migration target", netr.log.band.migration)
        local possible_migration_targets = {}
        local counter = 1
        for k = 0, 5 do 
            local tmp_tile = world.tileNeighbors[6 * self.tile + k]
            -- netr.log.f("checking tile " .. tostring(tmp_tile), netr.log.band.migration)
            if world.tileIsLand[tmp_tile] and tmp_tile ~= -1 then
                netr.log.f("ok" .. tostring(tmp_tile), netr.log.band.migration)
                possible_migration_targets[counter] = tmp_tile
                counter = counter + 1
            else
                netr.log.f("not ok" .. tostring(tmp_tile), netr.log.band.migration)
            end
        end
        dice = math.random(counter - 1)
        target = possible_migration_targets[dice]
        netr.log.f(tostring(target) .. " looks okay(maybe)", netr.log.band.migration)
        self.migration_target = target
    end
    if self.migration_target ~= nil then
        self.movement_progress = self.movement_progress + 2
        netr.log.f("Band is slowly walking away " .. tostring(self.movement_progress), netr.log.band.migration)
        if self.movement_progress > 1 then
            self:move(self.migration_target)
            self.movement_progress = 0
            self.migration_target = nil
        end
    end
    netr.log.f("migration update finished", netr.log.band.migration)
end

function netr.Band:move(tile)
    netr.log.f("band move from " .. tostring(self.tile) .. " to " .. tostring(tile), netr.log.band.move)
    netr.restore_color[tile] = true
    self.tile = tile
    netr.log.f("band move finished", netr.log.band.move)
end

--end of class Band()



function netr_main()
    log('loadind netr into the world')
    netr.placement_mod = true
    netr.map_mode = 'debug_1'
    netr.last_colour = 0
    netr.tick = 0
    netr.color_changed = false
    netr.old_color = {}
    netr.restore_color = {}
    
    netr.log.hsv_to_rgb = false
    netr.log.add_colour = false
    netr.log.set_colour = false
    netr.log.update = false
    netr.log.add_band = true
    netr.log.draw = false
    netr.log.band = {}
    netr.log.band.migration = false
    netr.log.band.init = false
    netr.log.band.move = false
    
    netr.flags = {}
    netr.flags.draw = true
    netr.flags.interface = true
    ticker = Spawn(lgo.ticker)
    
    netr.bands = {}
    netr.band_count = 0
    
    if netr.flags.interface then
        log('netr is creating antiuser interface')
        update_button = Buttons:LongText(ui)
            :reorient_top_left()
            :position(400, -400)
            :size(200, 200)
            :tooltip([[return "what"]])
            :text("what")
            :on_click([[netr.loop_step()]])
    end
    
    log('netr is loaded')
end



function on_tick()
    if netr.tick == 0 then
        netr.loop_step()
    end
    netr.tick = (netr.tick + 1) % 10
end



function on_tile_left_clicked()
	log("TILE LEFT-CLICKED")
    log(tostring(netr.placement_mod))
    if netr.placement_mod then
        log("who is a God now?")
        local tile_id = world.selectedTileID
        netr.add_band(tile_id)
        netr.draw()
        log("i'm the God now")        
    end
end

local foo = on_world_explorer_loaded
on_world_explorer_loaded = function() foo() netr_main() end
