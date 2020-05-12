pico-8 cartridge // http://www.pico-8.com
version 23
__lua__

version = "0.1"

debug = false

-- constants
map_size_x = 16
map_size_y = 16

-- palettes
-- numbers start after colors
palette_orange = 16
palette_green = 17
palette_blue = 18
palette_pink = 19

-- sfx
sfx_selector_move = 0
sfx_unit_rest = 1
sfx_select_unit = 2
sfx_undefined_error = 3
sfx_cant_move_there = 4
sfx_cancel_movement = 5
sfx_prompt_change = 6
sfx_end_turn = 7
sfx_infantry_moveout = 14
sfx_tank_moveout = 15
sfx_recon_moveout = 16

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
unit_id_i = 0 -- unit id counter. each unit gets a unique id


-- game loop
function _init()
  music(music_splash_screen, 0, music_bitmask)

  make_war_maps()
  current_map = war_maps[1]
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
    current_map:update()
    selector:update()
    cam:update()

    for unit in all(units) do
      unit:update()
    end

  end
end

function _draw()
  if in_splash_screen then
    draw_splash_screen()
  else
    -- clear screen
    cls()

    current_map:draw()

    for unit in all(units) do
      unit:draw()
    end

    selector:draw()

  end
end

-- lvl manager code
players_turn = 1
players = {palette_orange, palette_blue}
players_human = {true, false}
turn_i = 1
function end_turn()
  sfx(sfx_end_turn)

  players_turn = players_turn % 2 + 1

  -- increment the turn count if we're on the second player right now
  -- will need to change if we include multiplayer
  turn_i += players_turn - 1

end

-- splash screen code
function get_splash_screen_input()
  if (btnp(4)) then 
    in_splash_screen = false
  end
end

function draw_splash_screen()
  rectfill(0, 0, 128, 128, 15)
  print("pico wars", 49, 60, 0)
end

function tile_pos_to_rect(tile_coord)
  -- given the coordinate of a tile, translate that to a rect of the tile
  local pixel_coords = tile_to_pixel_pos(tile_coord)
  return {x=pixel_coords[1], y=pixel_coords[2], w=8, h=8}
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

function get_unit_at_pos(p)
  -- returns the unit at pos, or returns nil if there isn't a unit there
  for unit in all(units) do
    if points_equal(p, unit.p) then
      return unit
    end
  end
end

function get_selection(p)
    -- returns a two part table where 
    -- the first index is a flag indicating the selection 
      -- 0: unit
      -- 1: factory
      -- 2: tile
    -- the second index is the selection.

  local unit = get_unit_at_pos(p)
  if unit and not unit.is_resting then
    -- selection is unit
    return {0, unit}
  end

  local tile = mget(tile_to_pixel_pos(p))

  if fget(tile, flag_structure) and fget(tile, flag_factory) and (not unit or not unit.is_resting)then
    -- selection is factory
    return {1, tile}
  end
  -- selection is tile
  return {2, tile}
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
  selector.active = false
  selector.time_since_last_move = 0
  selector.move_cooldown = 0.1

  selector.selecting = false

  -- selection types are:
  -- unit selection: 0
  -- unit movement: 1
  -- unit order prompt: 2
  -- unit attack prompt: 3
  -- menu prompt for ending turn: 4
  -- constructing unit: 4
  selector.selection_type = nil

  -- currently selected object
  selector.selection = nil

  -- movable tiles for selected unit
  selector.movable_tiles = {}

  -- tiles that a movement arrow has passed through, in order from first to last
  selector.arrowed_tiles = {}

  -- during a prompt, prompt_options will be populated with options
  -- for unit prompt:
  -- 1 = rest
  -- 2 = attack
  -- 3 = capture
  -- for menu prompt:
  -- 1 = end turn
  selector.prompt_selected = 1
  selector.prompt_options = {}

  prompt_texts = {}
  prompt_texts[2] = {}
  add(prompt_texts[2], "rest")
  add(prompt_texts[2], "attack")
  add(prompt_texts[2], "capture")
  prompt_texts[4] = {}
  add(prompt_texts[4], "end turn")

  selector.prompt_texts = prompt_texts


  -- targets within attack range
  selector.attack_targets = {}

  -- components
  selector.animator = make_animator(
    selector,
    0.4,
    0,
    1)

  selector.update = function(self)
    -- only update selection if it's a human's turn
    if not players_human[players_turn] then return end

    -- do selector movement
    if not self.selecting or self.selection_type == 0 then
      self:move()
    end

    if btnp(4) and not self.selecting then 
      -- start selecting
      self.selecting = true

      -- refac: make get_selection inline
      local selection = get_selection(self.p)
      self.selection = selection[2]

      if selection[1] == 0 then
        -- start unit selection
        sfx(sfx_select_unit)
        local movable_tiles = self.selection:get_movable_tiles()
        merge_tables(movable_tiles[1], movable_tiles[2])
        self.movable_tiles = movable_tiles[1]
        self.selection_type = 0
        self.arrowed_tiles = {self.selection.p}
      else
        self:start_menu_prompt()
      end

      -- return from selecting
      return
    end

    if self.selecting then

      local arrow_val
      if btnp(2) then arrow_val = 1 elseif btnp(3) then arrow_val = -1 end
      if arrow_val then
        if self.selection_type == 2 then
          -- do unit selection prompt
          self.prompt_selected = self.prompt_selected + arrow_val
          if self.prompt_selected > #self.prompt_options then
            self.prompt_selected = 1
          elseif self.prompt_selected < 1 then
            self.prompt_selected = #self.prompt_options
          end
          if #self.prompt_options > 1 then
            sfx(sfx_prompt_change)
          end
        end

      elseif btnp(4) then 
        if self.selection_type == 0 then
          -- do unit selection
          local unit_at_pos = get_unit_at_pos(self.p)
          if unit_at_pos and unit_at_pos.id ~= self.selection.id then
            -- couldn't move to position. blocked by unit
            sfx(sfx_cant_move_there)
          else
            -- movement command issued
            self.selection:move(self.arrowed_tiles)

            self.selection_type = 1  -- change selection type to unit movement
            return
          end
        elseif self.selection_type == 2 then
          -- do unit selection prompt
          if self.prompt_selected == 1 then
            self.selection.is_resting = true
            sfx(sfx_unit_rest)
            self:stop_selecting()
          elseif self.prompt_selected == 2 then
            self:start_attack_prompt()
          else
            self.selection:capture()
          end
        elseif self.selection_type == 4 then
          -- do menu selection prompt (end turn)

          -- if self.prompt_selected == 1 then
            self:stop_selecting()
            end_turn()
          -- end
        end
      elseif btnp(5) then
        -- stop selecting

        if self.selection_type == 1 or self.selection_type == 2 then
          -- return unit to start location if he's moved
          sfx(sfx_cancel_movement)
          self.selection:unmove()
          self.p = self.selection.p
        end

        self:stop_selecting()

        return
      end


    end

  end

  selector.draw = function(self)
    -- only draw the selector if it's a human's turn
    if not players_human[players_turn] then return end

    if self.selecting then
      -- draw selection ui
      if self.selection_type == 0 then
        -- select unit
        for i, t in pairs(self.movable_tiles) do
          if debug then
            rectfill(t[1], t[2], t[1] + 7, t[2] + 7, (i % 15) + 1)
            print(tostring(i), t[1], t[2], 0)
          else
            local flip = last_checked_time * 2 % 2
            spr(flip + 3, t[1], t[2], 1, 1, flip > 0.5 and flip < 1.5, flip > 1)
          end
        end

        -- draw movement arrow
        self:draw_movement_arrow()

      elseif self.selection_type == 2 then
        -- draw rest/attack/capture unit prompt
        self:draw_prompt()
      elseif self.selection_type == 4 then
        self:draw_prompt()

      end

    end

    -- draw cursor
    self.animator:draw()

    -- draw pointer bounce offset by animator
    local offset = 8 - self.animator.animation_frame * 3
    spr(2, self.p[1] + offset, self.p[2] + offset)
  end

  selector.stop_selecting = function(self)
    self.selecting = false
    self.selection = nil
    self.selection_type = nil
    self.movable_tiles = {}
    self.arrowed_tiles = {}
  end 

  selector.start_unit_prompt = function(self)
    self.selection_type = 2

    self.prompt_options = {1}  -- rest is in options by default
    self.prompt_selected = 1

    -- store the attack targets
    self.attack_targets = self.selection:targets()
    if #self.attack_targets > 0 then 
      -- add attack to the prompt if we have targets
      add(self.prompt_options, 2)
    end

    -- todo: add ability for capturing structures here
  end

  selector.start_menu_prompt = function(self)
    self.selection_type = 4

    self.prompt_options = {1}  -- end turn is in options by default
    self.prompt_selected = 1

    sfx(sfx_prompt_change)
  end

  selector.draw_prompt = function(self)
    local y_offset = 15
    local prompt_text
    for i, prompt in pairs(self.prompt_options) do
      local palette = nil
      prompt_text = self.prompt_texts[self.selection_type][prompt]
      if i == self.prompt_selected then 
        palette = palette_pink 
        prompt_text ..= "!"
      end

      draw_msg({self.p[1], self.p[2] - y_offset}, prompt_text, palette, palette == palette_pink)
      y_offset += 9
    end
  end

  selector.move = function(self)
    self.time_since_last_move += delta_time

    -- get x and y change as a vector from controls input
    local change = self:get_move_input()

    -- move to the position based on input
    -- don't move if we're in any prompt selection_type
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
          for i = 1, point_i - 1 do
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
    -- draws a movement arrow during unit selection
    -- directions = n: 0, s: 1, e: 2, w: 3
    local last_p = self.arrowed_tiles[1]
    local last_p_direction
    local next_p
    local next_p_direction
    local current_p
    local opposite_directions
    local sprite
    local flip_x
    local flip_y
    local flip_horizontal = false

    local arrowhead = 120
    local arrowhead_l = 90
    local vertical = 104
    local horizontal = 106
    local curve_w_n = 123
    local curve_n_e = 121
    local curve_n_w = 105

    for i = 2, #self.arrowed_tiles do
      sprite = nil
      next_p = nil
      flip_x = false
      flip_y = false

      current_p = self.arrowed_tiles[i]
      if last_p[2] < current_p[2] then last_p_direction = 0 
      elseif last_p[2] > current_p[2] then last_p_direction = 1 
      elseif last_p[1] > current_p[1] then last_p_direction = 2 
      elseif last_p[1] < current_p[1] then last_p_direction = 3 
      end
      next_p = self.arrowed_tiles[i+1]
      if next_p then
        -- take into account the next point so we can make curved arrows
        if next_p[2] < current_p[2] then next_p_direction = 0 
        elseif next_p[2] > current_p[2] then next_p_direction = 1 
        elseif next_p[1] > current_p[1] then next_p_direction = 2 
        elseif next_p[1] < current_p[1] then next_p_direction = 3 
        end
      end

      if next_p then
        if next_p_direction == 0 then
          if last_p_direction == 2 then
            sprite = curve_w_n
            flip_x = true
          elseif last_p_direction == 3 then
            sprite = curve_w_n
          end
        elseif next_p_direction == 1 then
          if last_p_direction == 2 then
            sprite = curve_n_e
            flip_y = true
          elseif last_p_direction == 3 then
            sprite = curve_w_n
            flip_y = true
          end
        elseif next_p_direction == 2 then
          if last_p_direction == 0 then
            sprite = curve_n_e
            flip_horizontal = true
          elseif last_p_direction == 1 then
            sprite = curve_n_e
            flip_y = true
            flip_horizontal = false
          end
        elseif next_p_direction == 3 then
          if last_p_direction == 0 then
            sprite = curve_n_w
            flip_x = true
            flip_y = true
            flip_horizontal = true
          elseif last_p_direction == 1 then
            sprite = curve_n_w
            flip_x = true
            flip_horizontal = false
          end
        end
        if not sprite then
          if last_p_direction < 2 then
            sprite = vertical
          else
            sprite = horizontal
            flip_y = flip_horizontal
          end
        end
      else
        -- draw arrowhead
        if last_p_direction == 0 then
          sprite = arrowhead
        elseif last_p_direction == 1 then
          flip_y = true
          sprite = arrowhead
        elseif last_p_direction == 2 then
          sprite = arrowhead_l
          if flip_horizontal then flip_y = true end
        elseif last_p_direction == 3 then
          flip_x = true
          sprite = arrowhead_l
          if flip_horizontal then flip_y = true end
        end
      end

      if debug then
        rectfill(current_p[1], current_p[2], current_p[1] + 7, current_p[2] + 7, 0)
        print(i, current_p[1], current_p[2], 7)
      else
        spr(sprite, current_p[1], current_p[2], 1, 1, flip_x, flip_y)
      end

      last_p = current_p

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
    rectfill(-128, -128, 256, 256, 12)
    map(0, 0, 0, 0, 18, 18)

    -- reset_palette()
  end

  return war_map
end

function make_units()
  units = {}

  units[1] = make_infantry({24, 32})
  units[2] = make_mech({32, 32})
  units[3] = make_recon({64, 32}, palette_blue)
  units[4] = make_tank({64, 48}, palette_blue)
end

function make_unit(p, sprite, team)
  local unit = {}

  unit_id_i += 1
  unit.id = unit_id_i
  unit.p = p
  if not team then team = palette_orange end
  unit.team = team
  unit.cached_animator_fps = 0.4
  
  -- points to move to one at a time
  unit.cached_p = {}
  unit.movement_points = {}
  unit.movement_i = 1
  unit.cached_sprite = sprite -- cached sprite that we can revert to after changing it
  unit.is_moving = false
  unit.is_resting = false

  -- components
  unit.animator = make_animator(
    unit,
    unit.cached_animator_fps,
    sprite,
    64,
    team,
    {0, -2},
    true
    )

  unit.update = function(self)
    if self.is_moving then
      self:update_move()
    end
  end

  unit.draw = function(self)
    if self.is_resting then
      self.animator.palette = 7
    else
      self.animator.palette = self.team
    end
    self.animator:draw()
  end

  unit.get_movable_tiles = function(self)
    -- returns two tables
    -- the first table has all of the tiles this unit can move to. this is the only one the ai wants.
    -- the second table as all of the tiles they could move to if their own units weren't occupying them. 

    local current_tile = nil
    local tiles_to_explore = {{self.p, self.travel}}  -- store the {point, travel leftover, steps_moved_so_far}
    local movable_tiles = {}
    local tiles_with_our_units = {}
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
          if get_unit_at_pos(current_t) then
            add(tiles_with_our_units, current_t)
          else
            add(movable_tiles, current_t)
          end
        end

        -- add all neighboring tiles to the explore list, while reducing their travel leftover
        for t in all(get_tile_adjacents(current_t)) do

          -- check the travel reduction for a the tile's type
          local travel_reduction = self:tile_mobility(mget(t[1] / 8, t[2] / 8))
          local travel_left = current_tile[2] - travel_reduction

          -- see if we've already checked this tile. if we have and the cost to get to it was lower, don't explore the new tile.
          local checked = false
          for t2 in all(tiles_to_explore) do

            checked = points_equal(t, t2[1]) and travel_left <= t2[2]
            if checked then break end
          end

          local unit_at_tile = get_unit_at_pos(t)
          if not checked and (not unit_at_tile or unit_at_tile.team == self.team) then
            local new_tile = {t, travel_left}
            add(tiles_to_explore, new_tile)
          end
        end
      end
    end
    return {movable_tiles, tiles_with_our_units}
  end

  unit.move = function(self, points)
    self.cached_p = copy_v(self.p)
    self.is_moving = true
    self.movement_i = 1
    self.movement_points = points
    self.animator.fps = 0.1

    sfx(self.moveout_sfx)
  end

  unit.update_move = function(self)
    local x_change = 0
    local y_change = 0

    local next_p = self.movement_points[self.movement_i]

    if next_p then
      -- next waypoint found. start moving to it

      local reached = points_equal(self.p, next_p)

      if reached then
        -- reached the goal. on to the next one
        self.movement_i += 1
        return self:update_move()
      end

      -- reset sprite to default state
      self.animator.sprite = self.cached_sprite

      if next_p[2] > self.p[2] then 
        -- animate sprite walking forwards
        self.animator.sprite = self.cached_sprite + 32
        y_change = 1
      elseif next_p[2] < self.p[2] then 
        y_change = -1
        -- animate sprite walking backwards
        self.animator.sprite = self.cached_sprite + 16
      elseif next_p[1] > self.p[1] then 
        self.animator.flip_sprite = false
        x_change = 1
      elseif next_p[1] < self.p[1] then 
        self.animator.flip_sprite = true
        x_change = -1
      end

      self.p[1] += x_change
      self.p[2] += y_change

    else
      -- no more points left. stop moving
      selector:start_unit_prompt()  -- change to select type unit prompt
      self:cleanup_move()
    end

    unit.unmove = function(self)
      -- un-does a move, moving the unit back to its start location
      self.p = self.cached_p
      self:cleanup_move()
    end

    unit.cleanup_move = function(self)
      self.animator.sprite = self.cached_sprite  -- reset animator to default state
      self.animator.fps = self.cached_animator_fps
      self.animator.flip_sprite = false
      self.is_moving = false
      self.movement_i = 1
      self.movement_points = {}
    end

  end

  unit.tile_mobility = function(self, tile)
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

  unit.targets = function(self)
    local targets = {}
    for t in all(get_tile_adjacents(self.p)) do
      local u = get_unit_at_pos(t)
      if u and u.team != self.team then add(targets, u) end
    end
    return targets
  end

  return unit
end

function make_infantry(p, team)
  local unit = make_unit(
    p, -- position
    16, -- sprite
    team
    )

  unit.mobility_type = mobility_infantry
  unit.travel = 4
  unit.damage = 1
  unit.moveout_sfx = sfx_infantry_moveout

  return unit
end

function make_mech(p, team)
  local unit = make_unit(
    p, -- position
    17, -- sprite
    team
    )

  unit.mobility_type = mobility_mech
  unit.travel = 3
  unit.damage = 1
  unit.moveout_sfx = sfx_infantry_moveout

  return unit
end

function make_recon(p, team)
  local unit = make_unit(
    p, -- position
    18, -- sprite
    team
    )

  unit.mobility_type = mobility_tires
  unit.travel = 10
  unit.damage = 1
  unit.moveout_sfx = sfx_recon_moveout

  return unit
end

function make_tank(p, team)
  local unit = make_unit(
    p, -- position
    19, -- sprite
    team
    )

  unit.mobility_type = mobility_treads
  unit.travel = 7
  unit.damage = 1
  unit.moveout_sfx = sfx_tank_moveout

  return unit
end

function make_animator(parent, fps, sprite, sprite_offset, palette, draw_offset, draw_shadow, animation_flag)
  local animator = {}
  animator.parent = parent
  animator.fps = fps
  animator.sprite = sprite
  animator.sprite_offset = sprite_offset
  animator.palette = palette
  if animation_flag then animator.animation_flag = animation_flag else animator.animation_flag = true end
  if draw_offset then animator.draw_offset = draw_offset else animator.draw_offset = {0, 0} end
  animator.draw_shadow = draw_shadow  -- draws a shadow on sprites if true
  animator.active = true

  animator.time_since_last_frame = 0
  animator.animation_frame = 0
  animator.flip_sprite = false

  animator.draw = function(self)
    -- update and animate the sprite
    self.time_since_last_frame += delta_time
    if self.active then
      if self.animation_flag and self.time_since_last_frame > self.fps then
        self.animation_frame = (self.animation_frame + 1) % 2
        self.time_since_last_frame = 0
      end

      -- draw shadow
      local animation_frame = self:get_animation_frame()
      if self.draw_shadow then
        self:draw_outline(animation_frame)
      end

      -- draw sprite
      if(self.palette) then
        set_palette(self.palette)
      end

      spr(animation_frame, parent.p[1] + self.draw_offset[1], parent.p[2] + self.draw_offset[2], 1.0, 1.0, self.flip_sprite)

      if(self.palette) then
        reset_palette()
      end
    end

  end

  animator.draw_outline = function(self, animation_frame)
    set_palette(0)
    local offset = -1 
    -- this is black magic. don't smell it don't touch it don't even look at it the wrong way
    zspr(animation_frame, 1, 1, self.parent.p[1] + self.draw_offset[1] + offset, self.parent.p[2] + self.draw_offset[2] + offset, 1.35, self.flip_sprite)
    reset_palette()
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

-- palette functions
function set_palette(palette)
  if palette == palette_orange then
    return
  elseif palette == palette_blue then
    pal(9, 6)
    pal(8, 12)
    pal(2, 5)  
  elseif palette == palette_green then
    pal(9, 3)
    pal(8, 11)
    pal(2, 10)  
  elseif palette == palette_pink then
    pal(9, 14)
    pal(8, 14)
    pal(2, 2)
  else
    for i = 0, 15 do
      pal(i,  palette)
    end
  end
end

function reset_palette()
  for i = 0, 15 do
    pal(i,  i)
  end
end

-- vector functions
function points_equal(p1, p2)
  return p1[1] == p2[1] and p1[2] == p2[2]
end

function copy_v(v)
  return {v[1], v[2]}
end


-- rect functions
function point_in_rect(p, r)
  return p[1] >= r[1] and p[1] <= r[1] + r[3] and p[2] >= r[2] and p[2] <= r[2] + r[4]
end

-- table functions

function point_in_table(p, t)
  -- returns the index of the first point that matches if it is in the table
  -- otherwise returns nil
  for i, p2 in pairs(t) do
    if points_equal(p, p2) then return i end
  end
end

function merge_tables(t1, t2)
  -- merges the second table into the first
  i = #t1 + 1
  for _, v in pairs(t2) do 
    t1[i] = v 
    i += 1
  end
end

function zspr(sprite, w, h, dx, dy, dz, flip_sprite)
  --sprite: standard sprite number
  --w: number of sprite blocks wide to grab
  --h: number of sprite blocks high to grab
  --dx: destination x coordinate
  --dy: destination y coordinate
  --dz: destination scale/zoom factor 

  -- i have no idea why this works but it does. found by randomly messing with stuff
  local magic_fucking_number = 0.8

  local sw = 8 * w
  local sh = 8 * h
  sspr(8 * (sprite % 16), 8 * flr(sprite / 16), sw, sh, dx, dy, sw * dz - magic_fucking_number, sh * dz - magic_fucking_number, flip_sprite)
end

draw_msg = function(center_pos, msg, palette, draw_bar)
  msg_length = #msg

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
  
  if draw_bar then
    line(
      x_pos - padding,
      y_pos + 5,
      x_pos + msg_length * 4,
      y_pos + 5,
      2)
  end

  -- draw message
  print(msg, x_pos, y_pos - 1, 0)
end

function get_tile_adjacents(p)
    return {{p[1], p[2] - 8},  -- north
     {p[1], p[2] + 8},  -- south
     {p[1] + 8, p[2]},  -- east
     {p[1] - 8, p[2]}}   -- west
end


__gfx__
7700007700000000777770000000000000000000000000000000000000000044000000002200000000000000000000000000000000000000566666555ccccc63
7000000707700770755000000070007007070707000000000000000000000044000000002200000000000000000000000000000000000000c66666cc5c5c5c66
00000000070000707567000007070707007000700000000000000000000000440000000022000000000000000000000000000000000000005667665c66666666
00000000000000007056700000700070070707070000000000000000000000440000000022000000000000000000000000dddd0000000000c66766cc66666666
0000000000000000700567000000000000000000000000000000000000000044000000002200000000000000000000000ddddd50000000005666665c66776677
0000000007000070000056500070007007070707000000000000000000000044000000002200000000000000000000000ddddd5000000000c66666cc66666666
7000000707700770000005500707070700700070000000000000000000000444000000002220000000000000000000000d555550000000006667666666666666
7700007700000000000000000070007007070707000000000000000044444443444444443244444400000000000000000067750000000000666766635c5c5c66
0888880008888800000000000000000000000000000000000000000055555553000000003555555500f0000000000000006dd500005555000000000033b33b33
899999808999998000998000009880000000000000000000000000002222444500000000522222220f4400f0000000000655555000757500000000053bbb5bb3
8999999889999998099978000992780000000000000000000000000022222244000000002222222272427f4200000000067dd750ddd55ddd005500553bb5bb53
22222220222222200999185599921855000000000000000000000000222222440000000022222222072707220000000006dddd50d7d57d7d055d055dbb5b5bb5
ffff1f00788f1f770999990099999955000000000000000000000000000002440000000022200000007f40770000000065555555ddd55ddd55dd55dd3b5bbb53
088fff70788fff75222922202222222000000000000000000000000000000044000000002200000007244270000ff00067d7d7d5d7d57d7dd7d7d7d7bbb5bbb5
0287777772888877282828202898989200000000000000000000000000000044000000002200000000722700000f20006dddddd5ddd55ddddddddddd33433433
080080000200200022202220022222200000000000000000000000000000004400000004220000000007700000f4220067d7d7d5ddd55dddd7d7d7d733333333
08888800008888800000000000000000000000000000000000000000000000440000000022000000333ff3333f42423333666666666666666666633300000000
8999998068999998009990000099990000000000000000000000000000000044000000002200000033f442333f24423336666666666666666666663300000000
8888888889999999099999000999999000000000000000000000000000000044000000002200000033f442333f42423366666666666666666666666300000000
f22222f08888888809999900099999900000000000000000000000000000004400000000220000003f4442233f42422366666677667766776676666300000000
088888707772222009999900299999920000000000000000000000000000004400000000220000003f4424233f44242366666666666666666667666300000000
088888707678888828999820829999280000000000000000000000000000004400000000220000003f4244233f42442366676666666666666666666300000000
02222200666288208299928028299282000000000000000000000000000000440000000022000000b4b4b24bb4b4b24b66676666666666666667666300000000
080000000020000028202820828998280000000000000000000000000000004440000000220000003bbbbbb33bbbbbb366666663333333336667666300000000
08888800088888770000000000000000000000000000000000000000000000445555555522000000000000003333333366666663333333336666666366666663
89999980899999870088800000888800000000000000000000000000000000442222222222000000000000003333333366666666666666666666666366666663
89999998899999980878780008788780000000000000000000000000000000422222222222000000000000003333333366676666666666666667666366676663
22222220222222260918190008199180000000000000000000000000000000022222222220000000000000003333333366676666666666666667666366676663
ff1ff1f08f1f17770995990029555592000000000000000000000000000000000000000000000000000000003333333366667677667766776676666366666663
0fffff7008fff7572895982082555528000000000000000000000000000000000000000000000000000000003333333366666666666666666666666366666663
02877777028886668299928028299282000000000000000000000000000000000000000000000000000000003333333336666666666666666666663366676663
08000000020000002820282082899828000000000000000000000000000000000000000000000000000000003333333333666666666666666666633366676663
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000080005ccccc6552000000000000440000000000000000
08888800088888000099800000988000000000000000000000000000000000000000000000000000000880002ccccc22cc000000000000450000000000000000
89999980899999800999780009927800000000000000000000000000000000000000000000000000008888882ccccc22cc000000000000cc0000000000000000
89999998899999980999185599921855000000000000000000000000000000000000000000000000088888882ccccc22cc000000000000cc0000000000000000
222222202222222009999900999999550000000000000000000000000000000000000000000000000088888800000000cc000000000000cc0000000000000000
ffff1f00788f1f7722292220222222200000000000000000000000000000000000000000000000000008800000000000cc000000000000cc0000000000000000
088fff70788fff752928292029898982000000000000000000000000000000000000000000000000000080000000000062000000000000cc0000000000000000
02877777728888772220222002222220000000000000000000000000000000000000000000000000000000000000000022000000000000464ccccc4400000000
08888800008888800000000000000000000000000000000000000000000000000088800000000000000000000000000033555555555555555555533300000000
89999980689999980099900000999900000000000000000000000000000000000088800000000000000000000000000035ccccccccccccccccccc63300000000
8888888889999999099999000999999000000000000000000000000000000000008880000000088888888888888000005ccccccccccccccccccccc6300000000
f22222f088888888099999000999999000000000000000000000000000000000008880000000888888888888888800005ccccccccccccccccccccc6300000000
0888887077722220099999008999999800000000000000000000000000000000008880000008888888888888888880005ccccccccccccccccccccc6300000000
0888887076788888829992802899998200000000000000000000000000000000008880000008888000000000088880005ccccccccccccccccccccc6300000000
0222220066628828289998208289982800000000000000000000000000000000008880000008880000000000008880005cccccc666666666cccccc6300000000
0000080000000020828082802829928200000000000000000000000000000000008880000008880000000000008880005ccccc63333333335ccccc6300000000
0888880008888877000000000000000000000000000000000000000000000000008880000008880000000000008880005ccccc63333333335ccccc635ccccc63
8999998089999987008880000088880000000000000000000000000000000000008880000008888000000000088880005cccccc555555555cccccc635ccccc63
8999999889999998087878000878878000000000000000000000000000000000008880000008888888888888888880005ccccccccccccccccccccc635ccccc63
2222222022222226091819000819918000000000000000000000000000000000888888800000888888888888888800005ccccccccccccccccccccc635ccccc63
ff1ff1f08f1f1777099599008955559800000000000000000000000000000000088888000000088888888888888000005ccccccccccccccccccccc635ccccc63
0fffff7008fff757829592802855558200000000000000000000000000000000008880000000000000000000000000006ccccccccccccccccccccc635ccccc63
02877777028886662899982082899828000000000000000000000000000000000008000000000000000000000000000036ccccccccccccccccccc6335ccccc63
0000800000002000828082802829928200000000000000000000000000000000000000000000000000000000000000003366666666666666666663335ccccc63
__label__
70000000777070707770077077707770000077707770077007707070777077700770000070707770777070000000000000000000000000000000000000000000
07000000700070707070707070700700000070700700700070707070707070707000000070700700777070000000000000000000000000000000000000000000
00700000770007007770707077000700000077700700700070707070777077007770000077700700707070000000000000000000000000000000000000000000
07000000700070707000707070700700000070000700700070707770707070700070000070700700707070000000000000000000000000000000000000000000
70000000777070707000770070700700000070007770077077007770707070707700070070700700707077700000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
66606000666066600660666000000660666066606660606066606660000066600000600066606660666060000000666066606660066066600000000000000000
60606000600060606000600000006000606060600600606060606000000060600000600060606060600060000000600006006060600006000000000000000000
66606000660066606660660000006000666066600600606066006600000066600000600066606600660060000000660006006600666006000000000000000000
60006000600060600060600000006000606060000600606060606000000060600000600060606060600060000000600006006060006006000000000000000000
60006660666060606600666000000660606060000600066060606660000060600000666060606660666066600000600066606060660006000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
70000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
07000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
07000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
70000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000ccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
000000000ccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
000000000ccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
000000000ccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
000000000ccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
000000000ccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
000000000ccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
000000000ccccccccccccccccccccccccccccccccccccccc444444444444444444444444444444444444444444cccccccccccccccccccccccccccccccccccccc
000000000cccccccccccccccccccccccccccccccccccccc44333333333333333333333333333333333333333322ccccccccccccccccccccccccccccccccccccc
000000000cccccccccccccccccccccccccccccccccccccc44333333333333333333333333333333333333333322ccccccccccccccccccccccccccccccccccccc
000000000cccccccccccccccccccccccccccccccccccccc44333333333333333333333333333333333333333322ccccccccccccccccccccccccccccccccccccc
000000000cccccccccccccccccccccccccccccccccccccc44333333333333333333333333333333333333333322ccccccccccccccccccccccccccccccccccccc
000000000cccccccccccccccccccccccccccccccccccccc44333333333333333333333333333333333333333322ccccccccccccccccccccccccccccccccccccc
000000000cccccccccccccccccccccccccccccccccccccc44333333333333333333333333333333333333333322ccccccccccccccccccccccccccccccccccccc
000000000ccccccccccccccccccccccccccccccccccccc444333333333333333333333333333333333333333322ccccccccccccccccccccccccccccccccccccc
000000000ccccccccccccccc44ccccc444444444444444443333333333333333333333333333333333333333322ccccccccccccccccccccccccccccccccccccc
000000000cccccccccccccc445ccccc633333333333333333333333333333333333333333333333333333333322ccccccccccccccccccccccccccccccccccccc
000000000cccccccccccccc445ccccc633333333333333333333333333333333333333333333333333333333322ccccccccccccccccccccccccccccccccccccc
000000000cccccccccccccc445ccccc633333333333333333333333333333333333333333333333333333333322ccccccccccccccccccccccccccccccccccccc
000000000cccccccccccccc445ccccc633333333333333333333333333333333333333333333333333333333322ccccccccccccccccccccccccccccccccccccc
000000000cccccccccccccc445ccccc633333333333333333333333333333333333333333333333333333333322ccccccccccccccccccccccccccccccccccccc
000000000cccccccccccccc445ccccc633333333333333333333333333333333333333333333333333333333322ccccccccccccccccccccccccccccccccccccc
000000000ccccccccccccc4445ccccc6333333333333333333333333333333333333333333333333333333333222cccccccccccccccccccccccccccccccccccc
000000000ccccccc4444444435ccccc6333333333333333333333333333333333333333333333333333333333324444444cccccccccccccccccccccccccccccc
000000000cccccc44333333335ccccc63336666666666666666666666666666666666666666666666666663333333333322ccccccccccccccccccccccccccccc
000000000cccccc44333333335ccccc63366666666666666666666666666666666666666666666666666666333333333322ccccccccccccccccccccccccccccc
000000000cccccc44333333335ccccc63666666666666666666666666666666666666666666666666666666633333333322ccccccccccccccccccccccccccccc
000000000cccccc44333333335ccccc63666666776677667766776677667766776677667766776677667666633333333322ccccccccccccccccccccccccccccc
000000000cccccc44333333335ccccc63666666666666666666666666666666666666666666666666666766633333333322ccccccccccccccccccccccccccccc
000000000cccccc44333333335ccccc63666766666666666666666666666666666666666666666666666666633333333322ccccccccccccccccccccccccccccc
000000000cccccc44333333335ccccc63666766666666666666666666666666666666666666666666666766633333333322ccccccccccccccccccccccccccccc
000000000cccccc44333333335ccccc63666666633333333333333333333333333333333333333333666766633333333322ccccccccccccccccccccccccccccc
000000000cccccc44333333335ccccc6366666663333ff333333ff333333ff3333333333333333333666666633333333322ccccccccccccccccccccccccccccc
000000000cccccc44333333335ccccc636888886333f4423333f4423333f442333773377333333333666666633333333322ccccccccccccccccccccccccccccc
000000000cccccc44333333335ccccc638999998333f4423333f4423333f442333733337333333333666766633333333322ccccccccccccccccccccccccccccc
000000000cccccc44333333335ccccc63899999983f4442233f4442233f4442233333333333333333666766633333333322ccccccccccccccccccccccccccccc
000000000cccccc44333333335ccccc63222222233f4424233f4424233f4424233333333333333333666666633333333322ccccccccccccccccccccccccccccc
000000000cccccc44333333335ccccc63ffff1f633f4244233f4244233f4244233733377777333333666666633333333322ccccccccccccccccccccccccccccc
000000000cccccc44333333335ccccc63688fff73b4b4b24bb4b4b24bb4b4b24b3773375533333333666766633333333322ccccccccccccccccccccccccccccc
000000000cccccc44333333335ccccc63628777773bbbbbb33bbbbbb33bbbbbb33333375673333333666766633333333322ccccccccccccccccccccccccccccc
000000000cccccc44333ff3335ccccc6366666663333ff333333ff33333b33b333355575567555555566666555555555552ccccccccccccccccccccccccccccc
000000000cccccc4433f442335ccccc636666666333f4423333f442333bbb5bb335ccc7cc567cccccc66666ccccccccccccccccccccccccccccccccccccccccc
000000000cccccc4433f442335ccccc636667666333f4423333f442333bb5bb535cccccccc565cccc5667665cccccccccccccccccccccccccccccccccccccccc
000000000cccccc443f4442235ccccc63666766633f4442233f444223bb5b5bb55ccccccccc55ccccc66766ccccccccccccccccccccccccccccccccccccccccc
000000000cccccc443f4424235ccccc63666666633f4424233f4424233b5bbb535ccccccccccccccc5666665cccccccccccccccccccccccccccccccccccccccc
000000000cccccc443f4244235ccccc63666666633f4244233f424423bbb5bbb55cccccccccccccccc66666ccccccccccccccccccccccccccccccccccccccccc
000000000cccccc44b4b4b24b5ccccc6366676663b4b4b24bb4b4b24b334334335cccccc666666666666766666666666662ccccccccccccccccccccccccccccc
000000000cccccc443bbbbbb35ccccc63666766633bbbbbb33bbbbbb3333333335ccccc6333333333666766633333333322ccccccccccccccccccccccccccccc
000000000cccccc44333333335ccccc636666666333333333333ff33333b33b335ccccc6333333333666666633333333322ccccccccccccccccccccccccccccc
000000000cccccc4555555555cccccc63666666633333333333f442333bbb5bb35ccccc6333333333666666633333333322ccccccccccccccccccccccccccccc
000000000cccccccccccccccccccccc63666766633333333333f442333bb5bb535ccccc6333333333666766633333333322ccccccccccccccccccccccccccccc
000000000cccccccccccccccccccccc6366676663333333333f444223bb5b5bb55ccccc6333333333666766633333333322ccccccccccccccccccccccccccccc
000000000cccccccccccccccccccccc6366666663333333333f4424233b5bbb535ccccc6333333333666666633333333322ccccccccccccccccccccccccccccc
000000000cccccccccccccccccccccc6366666663333333333f424423bbb5bbb55ccccc6333333333666666633333333322ccccccccccccccccccccccccccccc
000000000ccccccccccccccccccccc6336667666333333333b4b4b24b334334335ccccc63333333336667666333333333222cccccccccccccccccccccccccccc
000000000cccccc46666666666666633366676663333333333bbbbbb3333333335ccccc63333333336667666333333333324444444cccccccccccccccccccccc
000000000cccccc443333333333333333666666633333333333333333333333335ccccc633333333366666663333333333333333322ccccccccccccccccccccc
000000000cccccc443333333333333333666666666666666666666666666666665c5c5c666666666666666663333333333333333322ccccccccccccccccccccc
000000000cccccc44333333333333333366676666666666666666666666666666666666666666666666676663333333333333333322ccccccccccccccccccccc
000000000cccccc44333333333333333366676666666666666666666666666666666666666666666666676663333333333333333322ccccccccccccccccccccc
000000000cccccc44333333333333333366667677667766776677667766776677667766776677667766766663333333333333333322ccccccccccccccccccccc
000000000cccccc44333333333333333366666666666666666666666666666666666666666666666666666663333333333333333322ccccccccccccccccccccc
000000000cccccc44333333333333333336666666666666666666666666666666666666666666666666666633333333333333333322ccccccccccccccccccccc
000000000cccccc443333333333333333336666666666666666666666666666665c5c5c666666666666666333333333333333333322ccccccccccccccccccccc
000000000cccccc445555555333333333333333333333333333333333333333335ccccc633333333333333333333333333555555522ccccccccccccccccccccc
000000000cccccc442222444533333333333333333333333333333333333333335ccccc633333333333333333333333335222222222ccccccccccccccccccccc
000000000cccccc422222224433333333333333333333333333333333333333335ccccc633333333333333333333333332222222222ccccccccccccccccccccc
000000000ccccccc22222224433333333333333333333333333333333333333335ccccc63333333333333333333333333222222222cccccccccccccccccccccc
000000000ccccccccccccc24433333333333333333333333333333333333333335ccccc63333333333333333333333333222cccccccccccccccccccccccccccc
000000000cccccccccccccc4433333333333333333333333333333333333333335ccccc6333333333333333333333333322ccccccccccccccccccccccccccccc
000000000cccccccccccccc4433333333333333333333333333333333333333335ccccc6333333333333333333333333322ccccccccccccccccccccccccccccc
000000000cccccccccccccc4433333333333333333333333333333333333333335ccccc6333333333333333333333333322ccccccccccccccccccccccccccccc
000000000cccccccccccccc4455555555555555555555555555555555555555555ccccc6555555555555555555555555522ccccccccccccccccccccccccccccc
000000000cccccccccccccc4422222222222222222222222222222222222222222ccccc2222222222222222222222222222ccccccccccccccccccccccccccccc
000000000cccccccccccccc4222222222222222222222222222222222222222222ccccc2222222222222222222222222222ccccccccccccccccccccccccccccc
000000000ccccccccccccccc222222222222222222222222222222222222222222ccccc222222222222222222222222222cccccccccccccccccccccccccccccc
000000000ccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
000000000ccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
000000000ccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
000000000ccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
000000000ccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
000000000ccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
000000000ccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
000000000ccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
000000000ccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
000000000ccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
000000000ccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
000000000ccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
000000000ccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
000000000ccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
000000000ccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
000000000ccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
000000000ccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
000000000ccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
000000000ccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc

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
000200001e63032650076400363001630006301365005630026300263000630006000060000600006000060000600006000060000600006000060000600006000060000600006000060000600006000060000600
00010000313303b33033330033300433005330073300933009330093300a330083300633003330023200032000320003200131000300003000030000300003000430004300013000030000300003000030000300
000200002e23020230082400724007230082500926005260052500623000220002200022000220002200022000220002200022000220002200021000210002100021000200002000020000200002000020000200
000300002415023150231502315025150271502714026140221401b1401414023100231002310025100271002710026100221001b100141000010000100001000010000100001000010000100001000010000100
00020000015500f5501855027550345503e550315000e500035000050000500005000050000500005000050000500005000050000500005000050000500005000050000500005000050000500005000050000500
00030000195501f550195000050000500005000050000500005000050000500005000050000500005000050000500005000050000500005000050000500005000050000500005000050000500005000050000500
0002000027370193700a370003700c0500d0500e0500f050100501205014050180501a0501d05021050260502b05031050380503e050000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00020000146401a6002065021640266102064018600146501864021600266301b6201065012610176401d6002162028640226501a6201260013630176001964020640296102860024620216501b630166000f620
000300000c2400825007240052500324002250012400723007240062300524004230032400223009220082300722006230042200423003220022200a240092300824007230062400523003240022300124001230
00020000130501605022650190301b03021640256401d0301b06019030170201d610106100e050296400a0201d620080200704026620106200305002030010402563001030196201962013650050102261005010
