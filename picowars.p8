pico-8 cartridge // http://www.pico-8.com
version 23
__lua__

version = "0.1"

debug = false

-- constants
map_size_x = 16
map_size_y = 16

-- palettes
palette_orange = 0
palette_green = 1
palette_blue = 2
palette_pink = 4

-- sfx
sfx_selector_move = 0
sfx_train_unit = 1
sfx_select_unit = 2

-- musics
music_splash_screen = 0

music_bitmask = 3

-- tile flags
flag_terrain = 0  -- required for terrain
flag_road = 1
flag_river = 2
flag_forest = 3
flag_mountain = 4
flag_ocean = 5
flag_plain = 6

flag_structure = 1  -- required for structure
flag_city = 2
flag_capital = 3
flag_factory = 4

flag_unit = 2

-- mobility ids
mobility_infantry = 0
mobility_mech = 1
mobility_tires = 2
mobility_treads = 3

-- map currently loaded
current_map = nil

-- globals
in_splash_screen = true
last_checked_time = 0.0
delta_time = 0.0  -- time since last frame


-- game loop
function _init()
  music(music_splash_screen, 0, music_bitmask)

  make_war_maps()
  current_map = war_maps[1]
  make_lvl_manager()
  make_selector({0, 0})
  make_cam({-64, -64})
  make_units()
end

function _update()
  local t = time()
  delta_time = t - last_checked_time
  last_checked_time = t
  if in_splash_screen then
    get_splash_screen_input()
  else
    -- update level manager
    lvl_manager:update()
    current_map:update()
    selector:update()
    cam:update()

  end
end

function _draw()
  if in_splash_screen then
    draw_splash_screen()
  else
    -- clear screen
    cls()

    lvl_manager:draw()
    current_map:draw()

    for unit in all(units) do
      unit:draw()
    end

    selector:draw()

  end
end

-- splash screen code
function get_splash_screen_input()
  if (btnp(4)) then 
    in_splash_screen = false
  end
end

function draw_splash_screen()
  rectfill(0, 0, 128, 128, 15)
end

function tile_pos_to_rect(tile_coord)
  -- given the coordinate of a tile, translate that to a rect of the tile
  local pixel_coords = tile_to_pixel_pos(tile_coord)
  return {x=pixel_coords[1], y=pixel_coords[2], w=8, h=8 }
end

function pixel_to_tile_pos(pixel_coord)
  -- given coordinates in pixels, translate that to a tile position
  return {pixel_coord[1] / 8, pixel_coord[2] / 8}
end

function tile_to_pixel_pos(tile_coord)
  -- given the coordinate of a tile, translate that to pixel values
  return {tile_coord[1]*8, tile_coord[2]*8}
end

function tile_has_flag(x, y, flag)
  local tile = mget(x, y)
  local has_flag = fget(tile, flag)
  return has_flag
end

-- level manager code
function make_lvl_manager()
  lvl_manager = {}

  lvl_manager.level = 1

  lvl_manager.message_pos = tile_to_pixel_pos({8.5, 2})  -- position on screen to display dialogue messages at

  -- components

  -- do_for that can be edited from anywhere. hotswap the callback_fn and do start() to run it
  lvl_manager.ui_do_for = make_do_for(lvl_manager, 2.5)  
  -- do_for for special effects like whiting out the screen. hotswap the callback_fn and do start() to run it
  lvl_manager.effect_do_for = make_do_for(lvl_manager, 20)  

  lvl_manager.init_level = function(self)
    -- play music
    music(music_lvl1, 0, music_bitmask)

  end

  lvl_manager.reset_level = function(self)
    self:destroy_level()
    self:init_level()
  end

  lvl_manager.destroy_level = function(self)
    -- reset all level components
  end

  lvl_manager.update = function(self)
  end

  lvl_manager.draw = function(self)
  end

  lvl_manager.draw_ui_msg = function(self, msg, palette, duration, dont_overwrite)
    if dont_overwrite and self.ui_do_for.time_left > 0 then
      return
    end 
    self.ui_do_for.callback_fn = function(l)
      l:draw_msg(self.message_pos, msg, palette)
    end 
    if duration then
      self.ui_do_for.duration = duration
    else
      self.ui_do_for.duration = 5
    end
    self.ui_do_for:start()
  end

  lvl_manager.draw_msg = function(self, center_pos, msg, palette)
    msg_length = #msg

    local bar_length = bar_length
    if bar_length then
      -- bar_length should be between 0.0 and 1.0
      local bar_length = max(0.0, bar_length or 1.0)
    end
    local padding = 2
    local x_pos = center_pos[1] + 5 - msg_length * 4 / 2 
    local y_pos = center_pos[2]
    local bg_color = 6

    -- grey is default 
    if (palette) then
      if palette == palette_orange then
        bg_color = 9
      elseif palette == palette_green then
        bg_color = 3  -- dark green
      elseif palette == palette_blue then
        bg_color = 12
      elseif palette == palette_pink then
        bg_color = 14
      end
    end

    -- draw message background rectangle
    rectfill(
      x_pos - padding,
      y_pos - padding,
      x_pos + msg_length * 4 ,
      y_pos + 5,
      bg_color)

    -- draw message
    print(msg, x_pos, y_pos - 1, 0)

    -- draw bar
    if (bar_length) then
      local bar_bg_color = 0
      local bar_fill_color = 8

      -- bar background
      line(
        x_pos - padding,
        y_pos + 5,
        x_pos + msg_length * 4,
        y_pos + 5,
        bar_bg_color
      )
      -- bar fill
      if(bar_length > 0.0) then
        -- green
        local bar_fill_color = 11
        if (bar_length < 0.25) then
          -- red
          bar_fill_color = 8
        elseif (bar_length < 0.6) then
          -- yellow
          bar_fill_color = 10
        end

        line(
          x_pos - padding,
          y_pos + 5,
          x_pos - padding + (((msg_length * 4) + padding) * bar_length),
          y_pos + 5,
          bar_fill_color
        )
      end
    end
  end

  lvl_manager:init_level()

  return lvl_manager

end

function make_cam(p)
  cam = {}

  cam.p = p

  cam.update = function (self) 
    -- move camera with the selector
    local move_x = (selector.p[1] - 64 - self.p[1]) / 15
    local move_y = (selector.p[2] - 64 - self.p[2]) / 15

    self.p[1] += move_x
    self.p[2] += move_y
    camera(self.p[1], self.p[2])
  end

end


function make_selector(p)
  selector = {}

  -- {x, y} vector of position
  selector.p = p
  selector.time_since_last_move = 0
  selector.move_cooldown = 0.1

  selector.selecting = false

  -- selection types are:
  -- unit selection: 0
  -- constructing unit: 1
  -- menu: 2
  selector.selection_type = nil

  -- currently selected object
  selector.selection = nil

  -- movable tiles for selected unit
  selector.movable_tiles = {}

  -- tiles that a movement arrow has passed through, in order from first to last
  selector.arrowed_tiles = {}


  -- components
  selector.animator = make_animator(
    selector,
    0.4,
    0,
    1)

  selector.update = function(self)

    if btnp(4) and not self.selecting then 
      -- start selecting
      self.selecting = true

      local selection = current_map:get_selection(self.p)
      self.selection = selection[2]

      if selection[1] == 0 then
        -- start unit selection
        sfx(sfx_select_unit)
        self.movable_tiles = self.selection:get_movable_tiles()
        self.selection_type = 0
        self.arrowed_tiles = {self.selection.p}
      end
    end

    if self.selecting then
      if btnp(5) then 
        -- stop selecting
        self.selecting = false
        self.selection = nil
        self.selection_type = nil
        self.movable_tiles = {}
        self.arrowed_tiles = {}
        return
      end

    end

    -- do selector movement
    self:move()
  end

  selector.draw = function(self)

    if self.selecting then
      -- draw selection ui
      if self.selection_type == 0 then
        -- select unit
        for i, t in pairs(self.movable_tiles) do
          if debug then
            rectfill(t[1], t[2], t[1] + 7, t[2] + 7, (i % 15) + 1)
            print(tostring(i), t[1], t[2], 0)
          else
            local flip = last_checked_time * 2 % 2 > 1
            spr(3, t[1], t[2], 1, 1, flip, flip)
          end
        end

        -- draw movement arrow
        self:draw_movement_arrow()

      end
    end

    -- draw cursor
    self.animator:draw()

    -- draw pointer bounce offset by animator
    local offset = 8 - self.animator.animation_frame * 3
    spr(2, self.p[1] + offset, self.p[2] + offset)
  end

  selector.move = function(self)
    self.time_since_last_move += delta_time

    -- get x and y change as a vector from controls input
    local change = self:get_move_input()

    -- move to the position based on input
    if self.time_since_last_move > self.move_cooldown then
      if change[1] and change[2] then
        -- if both inputs are down, perform move twice, once for x, once for y
        local move_result = self:move_to(change[1], 0)
        if move_result then
          self:move_to(0, change[2])
        end
      elseif change[1] then
        -- move x
        self:move_to(change[1], 0)
      elseif change[2] then
        -- move y
        self:move_to(0, change[2])
      end
    end

  end

  selector.get_move_input = function(self)
    x_change = nil
    y_change = nil
    if btn(0) then x_change = -8 end
    if btn(1) then x_change = 8 end
    if btn(2) then y_change = -8 end
    if btn(3) then y_change = 8 end
    return {x_change, y_change}
  end

  selector.move_to = function(self, change_x, change_y)
    -- moves the selector to a specific location
    -- returns true on successful cursor movement

    local new_p = {self.p[1] + change_x, self.p[2] + change_y}
    local in_bounds = point_in_rect(new_p, current_map.r)

    if self.selecting and self.selection_type == 0 then
      -- if we're selecting a unit, keep selector bounded by unit's mobility
      in_bounds = in_bounds and point_in_table(new_p, self.movable_tiles)
    end

    if in_bounds then
      self.p = new_p

      if self.selecting and self.selection_type == 0 then
        -- if we crossover our arrow, delete all points in the arrow after the crossover
        local point_i = point_in_table(new_p, self.arrowed_tiles)
        if point_i then
          local new_arrowed_tiles = {}
          for i = 1, point_i do
            new_arrowed_tiles[i] = self.arrowed_tiles[i]
          end
          self.arrowed_tiles = new_arrowed_tiles
        end

        -- add tile to the arrowed tiles list
        add(self.arrowed_tiles, new_p)

      end

      self.time_since_last_move = 0
      sfx(sfx_selector_move)
      return true
    end
  end

  selector.draw_movement_arrow = function(self)
    for p in all(self.arrowed_tiles) do
      rectfill(p[1], p[2], p[1] + 7, p[2] + 7, 0)
    end
  end

end

function make_war_maps()
  war_maps = {}

  -- load war maps
  war_maps[1] = make_war_map(
    {0, 0, 128, 128}
    
  )

  return war_maps

end

function make_war_map(r)
  war_map = {}

  -- rect of bounds
  war_map.r = r

  war_map.update = function(self)
  end

  war_map.draw = function(self)
    -- set_palette(self.map_palette)

    -- fill background with blue water
    rectfill(0, 0, 128, 128, 12)
    map(0, 0, 0, 0, 18, 18)

    -- reset_palette()
  end

  war_map.get_selection = function(self, p)
    -- returns a two part table where 
    -- the first index is a flag indicating the selection 
      -- 0: unit
      -- 1: factory
      -- 2: tile
    -- the second index is the selection.

    for unit in all(units) do
      if points_equal(p, unit.p) then
        -- selection is unit
        return {0, unit}
      end
    end

    local tile = mget(tile_to_pixel_pos(p))

    if fget(tile, flag_structure) and fget(tile, flag_factory) then
      -- selection is factory
      return {1, tile}
    end

    -- selection is tile
    return {2, tile}

  end

  return war_map

end

function make_units()
  units = {}

  units[1] = make_infantry({24, 32})
end

function make_unit(p, sprite, team)
  local unit = {}

  unit.p = p

  -- components
  unit.animator = make_animator(
    unit,
    0.4,
    sprite,
    64,
    team)

  unit.draw = function(self)
    self.animator:draw()
  end

  unit.get_movable_tiles = function(self)
    local current_tile = nil
    local tiles_to_explore = {{self.p, self.travel}}  -- store the {point, travel leftover, steps_moved_so_far}
    local movable_tiles = {}
    local explore_i = 0  -- index in tiles_to_explore of what we've explored so far

    while #tiles_to_explore > explore_i do
      -- pop the last entry off the tiles_to_explore table and set it as the current tile
      explore_i += 1
      current_tile = tiles_to_explore[explore_i]

      if current_tile[2] > 0 then
        -- if we have any travel left in this tile then explore its neighbors
        local current_t = current_tile[1] -- helper to get the current tile(without travel)

        -- if we haven't already added this tile to be returned, add it to be returned
        local has_added_to_movable_tiles = false
        for t2 in all(movable_tiles) do

          has_added_to_movable_tiles = points_equal(current_t, t2)
          if has_added_to_movable_tiles then break end
        end
        if not has_added_to_movable_tiles then
          add(movable_tiles, current_t)
        end

        -- add all neighboring tiles to the explore list, while reducing their travel leftover
        for t in all({
          {current_t[1], current_t[2] - 8},  -- north
           {current_t[1], current_t[2] + 8},  -- south
           {current_t[1] + 8, current_t[2]},  -- east
           {current_t[1] - 8, current_t[2]}   -- west
           }) do

          -- check the travel reduction for a the tile's type
          local travel_reduction = self:tile_mobility(mget(t[1] / 8, t[2] / 8))
          local travel_left = current_tile[2] - travel_reduction

          -- see if we've already checked this tile. if we have and the cost to get to it was lower, don't explore the new tile.
          local checked = false
          for t2 in all(tiles_to_explore) do

            checked = points_equal(t, t2[1]) and travel_left <= t2[2]
            if checked then break end
          end

          if not checked then
            local new_tile = {t, travel_left}
            add(tiles_to_explore, new_tile)
          end
        end
      end

    end

    return movable_tiles

  end

  unit.tile_mobility = function(self, tile)
    printh(tile)
    -- returns the mobility cost for traversing a tile for the unit's mobility type
    if fget(tile, flag_structure) then return 1 end
    if fget(tile, flag_terrain) then
      if fget(tile, flag_road) then return 1
      elseif fget(tile, flag_plain) then
        if self.mobility_type == mobility_tires then return 2
        else return 1 end
      elseif fget(tile, flag_forest) then
        if self.mobility_type == mobility_tires then return 3
        elseif self.mobility_type == mobility_treads then return 2
        else return 1 end
      elseif fget(tile, flag_mountain) or fget(tile, flag_river) then
        if self.mobility_type == mobility_infantry then return 2
        elseif self.mobility_type == mobility_mech then return 1
        else return 255 end
      end
    end
    return 255 -- unwalkable if all other options are exhausted
  end


  return unit
end

function make_infantry(p, team)
  local infantry = make_unit(
    p, -- position
    16, -- sprite
    team
    )

  infantry.mobility_type = mobility_infantry
  infantry.travel = 16
  infantry.damage = 1

  return infantry
end

function make_animator(parent, fps, sprite, sprite_offset, palette, animation_flag)
  local animator = {}
  animator.parent = parent
  animator.fps = fps
  animator.sprite = sprite
  animator.sprite_offset = sprite_offset
  if animation_flag == nil then animator.animation_flag = true else animator.animation_flag = animation_flag end
  animator.active = true

  animator.time_since_last_frame = 0
  animator.animation_frame = 0
  animator.flip_sprite = false

  animator.palette = palette

  animator.draw = function(self)
    -- update and animate the sprite
    self.time_since_last_frame += delta_time
    if self.active then
      if self.animation_flag and self.time_since_last_frame > self.fps then
        self.animation_frame = (self.animation_frame + 1) % 2
        self.time_since_last_frame = 0
      end

      if(self.palette != nil) then
        set_palette(self.palette)
      end

      spr(self:get_animation_frame(), parent.p[1], parent.p[2], 1.0, 1.0, self.flip_sprite)

      if(self.palette != nil) then
        reset_palette()
      end
    end

  end

  animator.get_animation_frame = function(self)
    if self.animation_flag then
      return self.sprite + self.sprite_offset * (self.animation_frame)
    else
      return self.sprite
    end
  end

  return animator

end

-- health
function make_health(parent, max_health, death_callback_fn, low_health_amount, low_health_sprite)

  local health = {}
  health.parent = parent

  health.max_health = max_health
  health.health = max_health
  health.death_callback_fn = death_callback_fn  --optional. function to call when health drops below 0

  health.active = true

  health.update = function(self)
  end

  health.damage = function(self, damage)
    if self.active then
      self.health -= damage

      if self.health <= 0.0 and self.death_callback_fn then
        -- do death callback function when dead
        self.death_callback_fn(self.parent)
      end
    end
  end

  health.heal = function(self, health)
    self.health += health
    self.health = min(self.health, 1.0)
  end

  return health
end


function make_do_for(parent, duration, callback_fn, expired_fn)
  -- calls a callback function n amount of times per second(default is every frame) until duration expires
  -- call start() to start the timer
  local do_for = {}

  do_for.parent = parent
  do_for.duration = duration
  do_for.callback_fn = callback_fn
  do_for.expired_fn = expired_fn

  do_for_has_expired = false
  do_for.time_left = 0

  do_for.update = function(self)
    if self.time_left > 0 then
      self.time_left -= delta_time
      if self.callback_fn then
        self.callback_fn(self.parent)
      end
    elseif not self.has_expired and self.expired_fn then
      self.has_expired = true
      self.expired_fn(self.parent)
    end
  end

  do_for.start = function(self)
    self.time_left = self.duration
    self.has_expired = false
  end

  do_for.stop = function(self)
    self.time_left = 0
    self.has_expired = true
  end

  return do_for
end

-- linear interpolation functions
function lerp(a, b, t)
  -- does a linear interpolation between two points
  return a + (b - a) * t
end

function bounce(a, b, t)
  -- does a bounce interpolation between two points
  local x
  if t <= 1/2.75 then
    x = 7.5625 * t * t
  elseif t <= 2/2.75 then
    x = 7.5625 * (t - 1.5/2.75)^2 + .75
  elseif t <= 2.25/2.75 then
    x = 7.5625 * (t - 2.25/2.75)^2 + .9375
  elseif t <= 1 then
    x = 7.5625 * (t - 2.625/2.75)^2 + .984375
  end
  return lerp(a, b, x)
end

-- palette functions
function set_palette(palette)
  if palette == palette_orange then
    return
  elseif palette == palette_blue then
    pal(9,  1)
    pal(10, 12)
    pal(15, 6)  
    pal(4, 0) -- additionally change dark brown for blue palette
  elseif palette == palette_green then
    pal(9,  3)
    pal(10, 11)
    pal(15, 11)
  elseif palette == palette_pink then
    pal(9,  5)
    pal(10, 6)
    pal(15, 6)
  end
end

function reset_palette()
  pal(9,  9)
  pal(10, 10)
  pal(15, 15)
  pal(4, 4)
  pal(7, 7)
end

-- vector functions
function points_equal(p1, p2)
  return p1[1] == p2[1] and p1[2] == p2[2]
end

-- rect functions
function point_in_rect(p, r)
  return p[1] >= r[1] and p[1] <= r[1] + r[3] and p[2] >= r[2] and p[2] <= r[2] + r[4]
end

-- table functions
function table_pop(t)
  -- pops and returns the last value of the table
  local v = t[#t]
  t[#t] = nil
  return v
end

function point_in_table(p, t)
  -- returns the index of the first point that matches if it is in the table
  -- otherwise returns nil
  for i, p2 in pairs(t) do
    if points_equal(p, p2) then return i end
  end
end


__gfx__
7700007700000000777770000000000000000000000000000000000000000044000000002200000000000000000000000000000000000000566666555ccccc63
7000000707700770755000000707070700000000000000000000000000000044000000002200000000000000000000000000000000000000c66666cc5c5c5c66
00000000070000707567000000700070000000000000000000000000000000440000000022000000000000000000000000000000000000005667665c66666666
00000000000000007056700007070707000000000000000000000000000000440000000022000000000000000000000000dddd0000000000c66766cc66666666
0000000000000000700567000000000000000000000000000000000000000044000000002200000000000000000000000ddddd50000000005666665c66776677
0000000007000070000056500707070700000000000000000000000000000044000000002200000000000000000000000ddddd5000000000c66666cc66666666
7000000707700770000005500070007000000000000000000000000000000444000000002220000000000000000000000d555550000000006667666666666666
7700007700000000000000000707070700000000000000000000000044444443444444443244444400000000000000000067750000000000666766635c5c5c66
0888880008888800000000000000000000000000000000000000000055555553000000003555555500f0000000000000006dd500005555000000000033b33b33
899999808999998000888000008880000000000000000000000000002222444500000000522222220f4400f0000000000655555000757500000000053bbb5bb3
8999999889999998088278000882780000000000000000000000000022222244000000002222222272427f4200000000067dd750ddd55ddd005500553bb5bb53
22222220222222208882186688821866000000000000000000000000222222440000000022222222072707220000000006dddd50d7d57d7d055d055dbb5b5bb5
ffff1f00ffff1f778888880088888866000000000000000000000000000002440000000022200000007f40770000000065555555ddd55ddd55dd55dd3b5bbb53
088fff70788fff75222022200222220000000000000000000000000000000044000000002200000007244270000ff00067d7d7d5d7d57d7dd7d7d7d7bbb5bbb5
0287777772888877262026202656562000000000000000000000000000000044000000002200000000722700000f20006dddddd5ddd55ddddddddddd33433433
020020000200200022202220022222000000000000000000000000000000004400000004220000000007700000f4220067d7d7d5ddd55dddd7d7d7d733333333
00000000000000000000000000000000000000000000000000000000000000440000000022000000333ff3333f42423333666666666666666666633300000000
0000000000000000000000000000000000000000000000000000000000000044000000002200000033f442333f24423336666666666666666666663300000000
0000000000000000000000000000000000000000000000000000000000000044000000002200000033f442333f42423366666666666666666666666300000000
000000000000000000000000000000000000000000000000000000000000004400000000220000003f4442233f42422366666677667766776676666300000000
000000000000000000000000000000000000000000000000000000000000004400000000220000003f4424233f44242366666666666666666667666300000000
000000000000000000000000000000000000000000000000000000000000004400000000220000003f4244233f42442366676666666666666666666300000000
00000000000000000000000000000000000000000000000000000000000000440000000022000000b4b4b24bb4b4b24b66676666666666666667666300000000
000000000000000000000000000000000000000000000000000000000000004440000000220000003bbbbbb33bbbbbb366666663333333336667666300000000
00000000000000000000000000000000000000000000000000000000000000445555555522000000000000003333333366666663333333336666666366666663
00000000000000000000000000000000000000000000000000000000000000442222222222000000000000003333333366666666666666666666666366666663
00000000000000000000000000000000000000000000000000000000000000422222222222000000000000003333333366676666666666666667666366676663
00000000000000000000000000000000000000000000000000000000000000022222222220000000000000003333333366676666666666666667666366676663
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000003333333366667677667766776676666366666663
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000003333333366666666666666666666666366666663
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000003333333336666666666666666666663366676663
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000003333333333666666666666666666633366676663
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000005ccccc6552000000000000440000000000000000
08888800000000000000000000000000000000000000000000000000000000000000000000000000000000002ccccc22cc000000000000450000000000000000
89999980000000000000000000000000000000000000000000000000000000000000000000000000000000002ccccc22cc000000000000cc0000000000000000
89999998000000000000000000000000000000000000000000000000000000000000000000000000000000002ccccc22cc000000000000cc0000000000000000
222222200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000cc000000000000cc0000000000000000
ffff1f000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000cc000000000000cc0000000000000000
088fff70000000000000000000000000000000000000000000000000000000000000000000000000000000000000000062000000000000cc0000000000000000
02877777000000000000000000000000000000000000000000000000000000000000000000000000000000000000000022000000000000464ccccc4400000000
00000000000000000000000000000000000000000000000000000000000000000008884000000000000000000000000033555555555555555555533300000000
00000000000000000000000000000000000000000000000000000000000000000008884000000000000000000000000035ccccccccccccccccccc63300000000
0000000000000000000000000000000000000000000000000000000000000000000888400000088888888888888000005ccccccccccccccccccccc6300000000
0000000000000000000000000000000000000000000000000000000000000000000888400000888888888888888800005ccccccccccccccccccccc6300000000
0000000000000000000000000000000000000000000000000000000000000000000888400008888888888888888840005ccccccccccccccccccccc6300000000
0000000000000000000000000000000000000000000000000000000000000000000888400008884444444444488840005ccccccccccccccccccccc6300000000
0000000000000000000000000000000000000000000000000000000000000000000888400008884000000000088840005cccccc666666666cccccc6300000000
0000000000000000000000000000000000000000000000000000000000000000000888400008884000000000088840005ccccc63333333335ccccc6300000000
0000000000000000000000000000000000000000000000000000000000000000000888400008884000000000088840005ccccc63333333335ccccc635ccccc63
0000000000000000000000000000000000000000000000000000000000000000000888400008884000000000088840005cccccc555555555cccccc635ccccc63
0000000000000000000000000000000000000000000000000000000000000000000888400008888888888888888840005ccccccccccccccccccccc635ccccc63
0000000000000000000000000000000000000000000000000000000000000000088888880008888888888888888840005ccccccccccccccccccccc635ccccc63
0000000000000000000000000000000000000000000000000000000000000000048888840000888888888888888400005ccccccccccccccccccccc635ccccc63
0000000000000000000000000000000000000000000000000000000000000000004888400000044444444444444000006ccccccccccccccccccccc635ccccc63
00000000000000000000000000000000000000000000000000000000000000000004840000000000000000000000000036ccccccccccccccccccc6335ccccc63
0000000000000000000000000000000000000000000000000000000000000000000040000000000000000000000000003366666666666666666663335ccccc63
__gff__
00000000000000212121000000004343000000000000002121210100060a1209000000000000002121211111030343000000000000000001010100410303434300000000000000000000000000000000000000000000000000000000000000000000000000000000000000000505050000000000000000000000000005050505
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__map__
0000000018080808080828000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00185e08073b3b3b3b3b29000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
18077f3b3b3b3b3b3b3b09280000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
273b7f2c2d2d2d2d2d2e3b290000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
273b7f3f2a2a2a3b3b3f3b290000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
272a7f3f2a2a1f6c6d0e6d5c0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
5d7d7e3f3b2a1f7f3b3f3b092800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
273b3b3c3d3d3d0f3d3e3b3b2900000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
37173b3b3b3b3b7f3b3b3b193900000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
003738383838385b383838390000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__sfx__
000100001f5201d5600e54005520005200b5000850004500005000250000500005000050000500005000050000500005000050000500005000050000500005000050000500005000050000500005000050000500
000100001e37032370073700337001370003701337005370023700237000370003000030000300003000030000300003000030000300003000030000300003000030000300003000030000300003000030000300
000200000f75021750267502b7502b75025750237501a750107500875001750007500a700017000a7000670002700007000070000700007000070000700007000070000700007000070000700007000070000700
