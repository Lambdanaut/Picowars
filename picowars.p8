pico-8 cartridge // http://www.pico-8.com
version 23
__lua__
-- pico wars
-- by lambdanaut
-- https://lambdanaut.itch.io/
-- https://twitter.com/lambdanaut
-- thanks to nintendo for making advance wars
-- special thanks to caaz for making the original picowars that gave me so much inspiration along the way

version = "0.1"
-- refac: delete lots of locals and check for bugs

-- debug = true


-- palettes
palette_orange = "orange star★"
palette_blue = "blue moon●"
palette_green = "green earth🅾️"
palette_pink = "pink groove♥"

palette_icon = {}
palette_icon[palette_orange] = 240
palette_icon[palette_blue] = 241
palette_icon[palette_green] = 242
palette_icon[palette_pink] = 243

co_icon = {}
co_icon[palette_orange] = 238
co_icon[palette_blue] = 236
co_icon[palette_green] = 234
co_icon[palette_pink] = 232

-- sfx
-- refac: unit sounds changed to magic numbers
sfx_selector_move = 0
sfx_unit_rest = 1
sfx_select_unit = 2
sfx_undefined_error = 3
sfx_cant_move_there = 4
sfx_cancel_movement = 5
sfx_prompt_change = 6
sfx_end_turn = 7
sfx_unit_death = 8
sfx_capturing = 9
sfx_captured = 10
sfx_build_unit = 11

-- musics
music_bitmask = 3

-- tile flags
flag_terrain = 0  -- required for terrain
flag_road = 1
flag_river = 2
flag_forest = 3
flag_mountain = 4
flag_cliff = 5
flag_plain = 6

flag_structure = 1  -- required for structure
flag_capital = 2
flag_city = 3
flag_base = 4

flag_player_1_owner = 6
flag_player_2_owner = 7

-- table of all unit types. loaded from memory
unit_types = {}

-- mobility ids
-- mobility_infantry = 0
-- mobility_mech = 1
-- mobility_tires = 2
-- mobility_treads = 3

-- map currently loaded
-- current_map = nil

-- coroutines
-- active_attack_coroutine = nil
-- active_ai_coroutine = nil
-- currently_attacking = false
attack_coroutine_u1 = nil
attack_coroutine_u2 = nil

-- globals
last_checked_time = 0.0
delta_time = 0.0  -- time since last frame
unit_id_i = 0 -- unit id counter. each unit gets a unique id
attack_timer = 0 -- used to space out attack co-routine
memory_i = 0x4300 -- counter to determine where we are in reading from memory


function _init()
  load_assets()

  make_selector()
  make_war_maps()
  current_map = war_maps[1]
  current_map:load()
  make_cam()
  make_units()

  end_turn()

  -- update the global players_turn_team to be the palette of the players turn
  players_turn_team = players[players_turn]
end

function _update()
  local t = time()
  delta_time = t - last_checked_time
  last_checked_time = t
  attack_timer += delta_time  -- update attack timer. used to space out attack co-routine
  -- update level manager
  current_map:update()
  selector:update()
  cam:update()

  for unit in all(units) do
    unit:update()
  end
  for struct in all(structures) do
    struct:update()
  end
end

function _draw()
  -- clear screen
  cls()

  current_map:draw()

  for structure in all(structures) do
    structure:draw()
  end

  -- draw tips of hqs
  for i = 1, 2 do
    local hq = players_hqs[i]
    set_palette(hq.team)
    spr(208, hq.p[1], hq.p[2] - 11) -- draw the spire of an hq
    pal()
  end
  
  sort_table_by_y(units)
  for unit in all(units) do
    unit:draw()
  end

  -- do ai_update in draw section for debug purposes
  ai_update()

  selector:draw()
end

-- lvl manager code
players_turn = 0
players = {palette_orange, palette_green}
players_reversed = {}  -- reverse index for getting player index by team
players_reversed[players[1]] = 1
players_reversed[players[2]] = 2
players_human = {false, false}
players_hqs = {}  -- the hqs for the two players
players_gold = {0, 0}
turn_i = 1
function end_turn()
  sfx(sfx_end_turn)

  players_turn = players_turn % 2 + 1
  players_turn_team = players[players_turn]

  -- increment the turn count if we're on the second player right now
  -- will need to change if we include multiplayer
  turn_i += players_turn - 1

  for unit in all(units) do
    unit.is_resting = false

    -- heal all units on cities
    for struct in all(structures) do
      if unit.team == players_turn_team and struct.team == players_turn_team and points_equal(unit.p, struct.p) then
        unit.hp = min(unit.hp + 2, 10)
      end
    end
  end

  for struct in all(structures) do
    if struct.type == 2 and struct.team == players_turn_team then
      -- add income for each city
      players_gold[players_turn] += 1
    end
  end

end

-- ai code

function ai_update()
  if players_human[players_turn] then return end  -- don't do ai for humans

  -- update ai's units
  -- sort units based on infantry/mech type
  ai_units_ranged = {}
  ai_units_infantry = {}
  other_ai_units = {}
  for u in all(units) do
    if u.team == players_turn_team then
      if u.ranged then
        add(ai_units_ranged, u)
      elseif u.mobility_type == 0 then
        add(ai_units_infantry, u)
      else
        add(other_ai_units, u)
      end
    end
  end
  ai_units = {}
  merge_tables(ai_units, ai_units_ranged)  -- move ranged first
  merge_tables(ai_units, ai_units_infantry)  -- then infantry
  merge_tables(ai_units, other_ai_units)  -- then other units

  -- run primary coroutine thread
  if not active_ai_coroutine then
    active_ai_coroutine = cocreate(ai_coroutine)
  elseif costatus(active_ai_coroutine) == 'dead' then
    active_ai_coroutine = nil
  else
    coresume(active_ai_coroutine)
  end

end

function ai_coroutine()
  printh("starting ai_coroutine\n---------------------")
  -- 3 waves of passing through our units

  for i = 1, 2 do
    for u in all(ai_units) do 
      if not u.is_resting then
        -- get unit's movable tiles
        local unit_movable_tiles = u:get_movable_tiles()[1]
        add(unit_movable_tiles, u.p)

        local has_attacked

        -- determine if there are any good fights to have within our range
        if u.ranged then
          -- ranged attack
          local ranged_targets = u:targets()

          if #ranged_targets > 0 then
            local best_target_u
            local best_target_value = -32767  -- start at negative infinity
            for u2 in all(ranged_targets) do
              local attack_value = ai_calculate_attack_value(u, u2)
              if attack_value > best_target_value then
                best_target_value = attack_value
                best_target_u = u2
              end
            end

            if best_target_u then
              attack_coroutine_u1 = u
              attack_coroutine_u2 = best_target_u
              attack_coroutine()
              has_attacked = true
            end
          end
        else
          -- melee attacks
          local attackables = {}

          -- get the positions we can attack enemies from
          -- map of tile_p => attackable enemy unit from that position 
          for t in all(unit_movable_tiles) do
            attackables[t] = u:targets(t)
          end

          -- determine best fight to take
          local best_fight_u
          local best_fight_pos
          local best_fight_value = -32767  -- start at negative infinity

          for t, attackable_unit in pairs(attackables) do
            for u2 in all(attackable_unit) do
              -- simulate us attacking them and them attacking back
              local attack_value = ai_calculate_attack_value(u, u2, t)
              if attack_value >= 0 and attack_value > best_fight_value then
                best_fight_value = attack_value
                best_fight_u = u2
                best_fight_pos = t
              end
            end
          end

          if best_fight_pos then
            -- do melee attack
            ai_move(u, best_fight_pos)

            attack_coroutine_u1 = u
            attack_coroutine_u2 = best_fight_u
            attack_coroutine()
            has_attacked = true
          end
        end

        if not has_attacked then
          -- pathfind to enemy hq by default
          local goal = players_hqs[3 - players_turn].p

          if manhattan_distance(goal, u.p) < 5 and u.index > 2 then
            -- if we're not an infantry/mech and we're next to the goal, head back home to get off their hq
            goal = players_hqs[players_turn].p
          elseif u.index < 3 then
            -- if we're an infantry or mech, navigate to nearest capturable structure
            local nearest_struct
            local nearest_struct_d = 32767
            for struct in all(structures) do
              local d = manhattan_distance(u.p, struct.p)
              local unit_at_struct = get_unit_at_pos(struct.p)
              if struct.team ~= players_turn_team and d < nearest_struct_d and 
                  (not unit_at_struct or unit_at_struct.id == u.id or unit_at_struct.team ~= players_turn_team) then
                nearest_struct = struct
                nearest_struct_d = d
              end
            end
            goal = nearest_struct.p
          end

          local path = ai_pathfinding(u, goal, true)
          local path_movable = {}
          for t in all(path) do
            if point_in_table(t, unit_movable_tiles) then
              add(path_movable, t)
            end
          end

          -- find point in path that is closest to enemy's hq
          local p = point_closest_to_p(path_movable, goal)
          ai_move(u, p)
        end

      end
    end
  end

  -- build units

  for struct in all(structures) do
    if struct.type == 3 and struct.team == players_turn_team and not get_unit_at_pos(struct.p) then
      -- build unit for each of our bases

      -- get unit counts
      -- artificially add 1 to counts to stop division by 0 errors
      local infantry_count = 1
      local mech_count = 1
      local unit_count = 1
      for u in all(units) do
        if u.team == players_turn_team then
          if u.index == 1 then
            infantry_count += 1
          elseif u.index == 2 then
            mech_count += 1
          end
          unit_count += 1
        end
      end

      if infantry_count / unit_count < 0.3 then
        struct:build(1)
      elseif mech_count / unit_count < 0.2 then
        struct:build(2)
      else
        for i = #unit_types, 3, -1 do
          -- count backwards from the most expensive non-infantry/mech unit types 
          -- build the first one we have the money for
          if unit_types[i].cost <= players_gold[players_turn] then
            struct:build(i)
          end
        end
      end
    end
  end

  end_turn()

end
  
function ai_move(u, p)
  local path = ai_pathfinding(u, p)
  u:move(path)
  while u.is_moving do
    selector.p = u.p
    yield()
  end
  if u.index < 3 then
    for struct in all(structures) do
      if points_equal(struct.p, u.p) then
        struct:capture(u)
      end
    end
  end
  u.is_resting = true
end

function ai_pathfinding(unit, target, ignore_enemy_units)

  -- draw marker on unit we're pathfinding for
  if debug then rectfill(unit.p[1], unit.p[2], unit.p[1] + 8, unit.p[2] + 8) end

  local tiles_to_explore = {}
  local tiles_to_explore = prioqueue.new()
  tiles_to_explore:add(unit.p, manhattan_distance(unit.p, target)) -- unit position sorted by f_score as starting point
  local current_tile

  local to_explore_parents = {}  -- map from point -> parent_point. starting node has no parent ;;
  local to_explore_travel = {unit.travel}  -- map of tile's index in tiles_to_explore -> travel cost

  local g_scores = {}  -- map from point -> g_score
  g_scores[unit.p] = 0

  while #tiles_to_explore.values > 0 do
    -- explore the next tile in tiles_to_explore


    -- set the current tile to be the tile in tiles_to_explore with the lowest f_score
    -- current_tile is two parts {{x, y}, f_score}
    current_tile = tiles_to_explore:pop()
    local current_t = current_tile[1] -- helper to get the current tile(without f_score)

    if points_equal(current_t, target) then
      -- goal reached. build and return path going backwards from the current node to each parent in the line
      local return_path = {current_t}
      while point_in_table(current_t, to_explore_parents, true) do
        current_t = table_point_index(to_explore_parents, current_t)
        insert(return_path, 1, current_t)
      end
      return return_path
    end

    -- explore this tile's neighbors
    local current_t_g_score = table_point_index(g_scores, current_t)

    if debug then
      rectfill(current_t[1], current_t[2], current_t[1] + 8, current_t[2] + 8, (current_t[1]+current_t[2]) % 15 )
      yield()
    end

    -- add all neighboring tiles to the explore list, while reducing their travel leftover
    for t in all(get_tile_adjacents(current_t)) do

      local unit_at_t = get_unit_at_pos(t)
      if ignore_enemy_units or not unit_at_t or unit_at_t.team == unit.team then
        local tile_m = unit:tile_mobility(mget(t[1] / 8, t[2] / 8))
        local new_g_score = current_t_g_score + tile_m

        if new_g_score < table_point_index(g_scores, t) and tile_m < 255 then
          -- if the new g_score is less than the old one for this tile, record it
          -- and set the parent to be equal to the current tile

          local tiles_to_explore_point_i_or_nil = point_in_table(t, tiles_to_explore.values)

          to_explore_parents[t] = current_t
          g_scores[t] = new_g_score
          local new_f_score = new_g_score + manhattan_distance(t, target)

          -- in the wiki pseudocode it says to record the fscore even if the point is already in the to_explore list
          -- we're not doing that and things seem fine. just keep an eye out if we see weird behavior
          -- https://en.wikipedia.org/wiki/a*_search_algorithm#pseudocode
          if not tiles_to_explore_point_i_or_nil then
            -- if the point isn't already in tiles_to_explore, add it. 
            tiles_to_explore:add(t, new_f_score)
          end
        end
      end
    end
  end
end

function manhattan_distance(p, target)
  return abs(p[1] - target[1]) / 8 + abs(p[2] - target[2]) / 8
end

function ai_calculate_attack_value(u, u2, tile)
  -- returns the estimated value of an attack as the difference between the gain and loss
  -- tile is the tile we expect to attack from if we're melee
  local damage_done = u:calculate_damage(u2)
  local gain = (damage_done + min(0, u2.hp - damage_done)) * u2.cost
  local loss
  if u.ranged then
    loss = 0
  else
    local damage_loss = u2:calculate_damage(u, true, tile, u2.hp - damage_done)
    loss = (damage_loss + min(0, u.hp - damage_loss)) * u.cost
  end
  return gain - loss
end

-- tile utilities
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

function get_selection(p, include_resting)
    -- returns a two part table where 
    -- the first index is a flag indicating the selection 
      -- 0: unit
      -- 1: base
      -- 2: tile
    -- the second index is the selection.

  local unit = get_unit_at_pos(p)
  if unit and (include_resting or not unit.is_resting) then
    -- selection is unit
    return {0, unit}
  end

  local tile = mget(p[1] / 8, p[2] / 8)

  if fget(tile, flag_structure) and fget(tile, flag_base) then
    -- selection is base
    return {1, tile}
  end
  -- selection is tile
  return {2, tile}
end

function get_tile_info(tile)
  -- returns the {tile name, its defense, its structure type(if applicable), and its team(if applicable)}
  if fget(tile, flag_structure) then
    local team
    if fget(tile, flag_player_1_owner) then team = players[1] elseif fget(tile, flag_player_2_owner) then team = players[2] end
    if fget(tile, flag_capital) then return {"hq★★★★", 0.25, 1, team}
    elseif fget(tile, flag_city) then return {"city★★★", 0.4, 2, team}
    elseif fget(tile, flag_base) then return {"base★★★", 0.4, 3, team}
    end
  end
  if fget(tile, flag_terrain) then
    if fget(tile, flag_road) then return {"road", 1.0}
    elseif fget(tile, flag_plain) then return {"plain★", 0.8}
    elseif fget(tile, flag_forest) then return {"wood★★", 0.6}
    elseif fget(tile, flag_mountain) then return {"mntn★★★★", 0.25}
    elseif fget(tile, flag_river) then return {"river", 1.0}
    elseif fget(tile, flag_cliff) then return {"cliff", 1.0}
    end
  end
  return {"unmovable", 0} -- no info
end

function point_closest_to_p(points, p)
  -- returns the point in points closest to p that doesn't have a unit in it
  local closest = points[1]
  local closest_d = 32767
  for p2 in all(points) do
    local d = manhattan_distance(p, p2)
    if d < closest_d and not get_unit_at_pos(p2) then
      closest = p2
      closest_d = d
    end
  end
  return closest
end

attack_coroutine = function()
  -- coroutine action that plays out an attack
  currently_attacking = true

  -- do attack
  selector.p = {attack_coroutine_u2.p[1], attack_coroutine_u2.p[2]}
  attack_timer = 0
  local damage_done = attack_coroutine_u1:calculate_damage(attack_coroutine_u2)
  attack_coroutine_u2.hp = max(0, attack_coroutine_u2.hp - damage_done)
  sfx(attack_coroutine_u1.combat_sfx)
  while attack_timer < 1.25 do
    print("-" .. damage_done, attack_coroutine_u2.p[1], attack_coroutine_u2.p[2] - 4 - attack_timer * 8, 8)
    yield()
  end
  -- do response attack
  if attack_coroutine_u2.hp > 0 and not attack_coroutine_u1.ranged and not attack_coroutine_u2.ranged then
    selector.p = {attack_coroutine_u1.p[1], attack_coroutine_u1.p[2]}
    attack_timer = 0
    damage_done = attack_coroutine_u2:calculate_damage(attack_coroutine_u1)
    attack_coroutine_u1.hp = max(0, attack_coroutine_u1.hp - damage_done)
    sfx(attack_coroutine_u2.combat_sfx)
    while attack_timer < 1.25 do
      print("-" .. damage_done, attack_coroutine_u1.p[1], attack_coroutine_u1.p[2] - 4 - attack_timer * 8, 8)
      yield()
    end
  end

  -- set units new states
  if attack_coroutine_u1.hp < 1 then
    explode_at = attack_coroutine_u1.p
    attack_coroutine_u1:kill()
  else
    attack_coroutine_u1.is_resting = true
  end

  if attack_coroutine_u2.hp < 1 then
    explode_at = attack_coroutine_u2.p
    attack_coroutine_u2:kill()
  end

  if explode_at then
    attack_timer = 0
    while attack_timer < 1.5 do
      spr(64 + flr(attack_timer*6), explode_at[1], explode_at[2] - 3 - attack_timer * 10)
      yield()
    end
  end
  explode_at = nil

  currently_attacking = false

end

function make_cam()
  cam = {}

  -- start cam off at the selector position
  cam.p = {selector.p[1] - 64, selector.p[2] - 64}

  cam.update = function (self) 
    -- move camera with the selector
    local shake_x = 0
    local shake_y = 0
    if explode_at and attack_timer < 1 then
      shake_x = rnd((1 - attack_timer) * 9) - 1
      shake_y = rnd((1 - attack_timer) * 9) - 1
    end

    local move_x = (selector.p[1] - 64 - self.p[1]) / 15
    local move_y = (selector.p[2] - 64 - self.p[2]) / 15

    self.p[1] += move_x
    self.p[2] += move_y
    camera(self.p[1] + shake_x, self.p[2] + shake_y)
  end

end

-- refac: make all of selector a global top level entity. huge token savings (2 for each self. called)
function make_selector()
  selector = {}

  -- {x, y} vector of position
  selector.p = {0, 0}
  selector.time_since_last_move = 0
  selector.move_cooldown = 0.1

  selector.selecting = false

  -- selection types are:
  -- unit selection: 0
  -- unit movement: 1
  -- unit order prompt: 2
  -- unit attack prompt: 3
  -- menu prompt for ending turn: 4
  -- unit attack range selection: 5
  -- enemy unit movement range selection: 6
  -- unit attacking: 7
  -- constructing unit: 8
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
  -- for attack prompt:
  --   each index is an index into self.attack_targets
  -- for menu prompt:
  -- 1 = end turn
  selector.prompt_selected = 1
  selector.prompt_options = {}
  selector.prompt_options_disabled = {} -- will appear marked out as disabled

  -- map of selection_type -> prompt texts available
  prompt_texts = {}
  prompt_texts[2] = {}
  add(prompt_texts[2], "rest")
  add(prompt_texts[2], "attack")
  add(prompt_texts[2], "capture")
  prompt_texts[4] = {}
  add(prompt_texts[4], "end turn")
  prompt_texts[8] = {}  -- unit construction prompt texts filled in programmatically

  for unit_type in all(unit_types) do
    -- fill in unit type construction prompt texts
    add(prompt_texts[8], unit_type.cost .. "g: " .. unit_type.type)
  end

  selector.prompt_texts = prompt_texts

  -- targets within attack range
  selector.attack_targets = {}

  -- unit we're actively attacking. used in attack coroutine
  -- self.attacking_unit = nil

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

    if self.selecting then
      -- do selecting

      -- get arrow key directional value. left or down = -1. up or right = +1
      local arrow_val
      if btnp(2) or btnp(1) then arrow_val = 1 elseif btnp(3) or btnp(0) then arrow_val = -1 end

      if not btn(5) and self.selection_type == 5 then
        -- end checking unit attack range
        self:stop_selecting()

      elseif not btn(4) and self.selection_type == 6 then
        -- end checking enemy unit movement
        self:stop_selecting()

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
          if self.prompt_options[self.prompt_selected] == 1 then
            self.selection.is_resting = true
            sfx(sfx_unit_rest)
            self:stop_selecting()
          elseif self.prompt_options[self.prompt_selected] == 2 then
            self:start_attack_selection()
          else
            self.selection:capture()
            self:stop_selecting()
          end
        elseif self.selection_type == 3 then
          -- do begin attacking

          -- set variables to be used in attack coroutine
          attack_coroutine_u1 = self.selection
          attack_coroutine_u2 = self.attack_targets[self.prompt_selected]
          active_attack_coroutine = cocreate(attack_coroutine)
          self.selection_type = 7
        elseif self.selection_type == 4 then
          -- do menu selection prompt (end turn)

          self:stop_selecting()
          end_turn()
        elseif self.selection_type == 8 then
          -- do build unit at base/factory

          self.selection:build(self.prompt_selected)
          self:stop_selecting()
        end
      elseif btnp(5) and self.selection_type ~= 5 and self.selection_type ~= 7 then
        -- stop selecting
        -- don't cancel if type is attack range selection or active attacking
        if 0 < self.selection_type and self.selection_type < 4 then -- if selection type is 1,2, or 3
          -- return unit to start location if he's moved
        
          sfx(sfx_cancel_movement)
          self.selection:unmove()
          self.p = self.selection.p
        end

        self:stop_selecting()

      elseif self.selection_type == 2 or self.selection_type == 8 then
        -- do unit selection and base construction prompt
        self:update_prompt(arrow_val)
      elseif self.selection_type == 3 then
        -- unit attack selection
        -- selector follows attack target
        self:update_prompt(arrow_val)
        self.p = self.attack_targets[self.prompt_selected].p
      end

    else
      -- do not selecting

      -- refac: set globals for button presses each turn. btnp(4) could be btnp_4

      local selection = {}
      if btnp(4) then
        selection = get_selection(self.p)
      elseif btn(5) then
        selection = get_selection(self.p, true)
      end

      if selection[1] == 0 then
        -- do unit selection
        self.selection = selection[2]
        if btnp(4) then
          sfx(sfx_select_unit)
          self.selecting = true
          if self.selection.team == players_turn_team then
            -- start unit selection
            local movable_tiles = self.selection:get_movable_tiles()
            merge_tables(movable_tiles[1], movable_tiles[2])
            self.movable_tiles = movable_tiles[1]
            self.selection_type = 0
            self.arrowed_tiles = {self.selection.p}
          else
            -- start enemy unit selection
            self.movable_tiles = self.selection:get_movable_tiles()[1]
            self.selection_type = 6
          end
        elseif btnp(5) then
          sfx(sfx_select_unit)
          self.selecting = true
          if self.selection.ranged then
            self.movable_tiles = self.selection:ranged_attack_tiles()
          else
            self.movable_tiles = self.selection:get_movable_tiles(1, true)[1]
          end
          self.selection_type = 5
        end
      elseif btnp(4) and selection[1] == 1 and not get_unit_at_pos(self.p) then
        -- do base selection
        for struct in all(structures) do
          if struct.team == players_turn_team and points_equal(struct.p, self.p) and struct.type == 3 then
            self.selecting = true
            self.selection = struct
            self:start_build_unit_prompt()
          end
        end

      elseif btnp(4) then
        -- do menu prompt
        self.selecting = true
        self:start_menu_prompt()
      end

    end

  end

  selector.draw = function(self)
    -- only draw the selector if it's a human's turn
    local draw_prompt  -- boolean flag for if we should draw the prompt
    if players_human[players_turn] then 
      if self.selecting then
        -- draw unit selection ui

        local flip = last_checked_time * 2 % 2  -- used in selection sprite to flip it
        if self.selection_type == 0 or self.selection_type == 5 or self.selection_type == 6 then

          -- select unit

          for i, t in pairs(self.movable_tiles) do
            if debug then
              rectfill(t[1], t[2], t[1] + 7, t[2] + 7, (i % 15) + 1)
              print(i, t[1], t[2], 0)
            else

              if self.selection_type == 5 then
                -- draw in red if we're in unit attack range selection
                pal(7, 8)
              end
              spr(flip + 3, t[1], t[2], 1, 1, flip > 0.5 and flip < 1.5, flip > 1)
              if self.selection_type == 5 then
                pal(7, 7)
              end
            end
          end

          if self.selection_type == 0 then
            -- draw movement arrow
            self:draw_movement_arrow()
          end

        elseif self.selection_type == 3 then
          -- draw attack prompt
          for unit in all(self.attack_targets) do
            pal(7, 8)
            spr(flip + 3, unit.p[1], unit.p[2], 1, 1, flip > 0.5 and flip < 1.5, flip > 1)
            pal(7, 7)
          end

        elseif self.selection_type == 2 or self.selection_type == 4 or self.selection_type == 8 then
          -- draw rest/attack/capture unit prompt, menu prompt, and unit construction prompts
          draw_prompt = true
        elseif self.selection_type == 7 then
          if costatus(active_attack_coroutine) == 'dead' then
            self:stop_selecting()
          else
            coresume(active_attack_coroutine)
          end
        end

      end
      
      if self.selection_type ~= 7 and self.selection_type ~= 8 then
        -- draw cursor if we're not fighting and we're not building units
        self.animator:draw()

        -- draw pointer bounce offset by animator
        local offset = 8 - self.animator.animation_frame * 3
        spr(2, self.p[1] + offset, self.p[2] + offset)
      end
    end

    if last_checked_time % 3 > 1.75 and not currently_attacking then
      for u in all(units) do
        if u.hp < 10 then
          set_palette(u.team)
          rectfill(u.p[1] + 1, u.p[2], u.p[1] + 5, u.p[2] + 6, 8)
          print(u.hp, u.p[1] + 2, u.p[2] + 1, 0)
          pal()
        end
      end
    end

    -- draw stats/selection bar at top of screen 
    local tile = mget(self.p[1] / 8, self.p[2] / 8)
    local tile_info = get_tile_info(tile)
    local struct_type = tile_info[3] 
    set_palette(players_turn_team)
    local x_corner = cam.p[1]
    local y_corner = cam.p[2]
    local gold = players_gold[players_turn]
    if gold < 10 then gold = "0" .. gold end
    rectfill(x_corner, y_corner, x_corner + 81, y_corner + 19, 8)  -- background
    rectfill(x_corner + 1, y_corner + 1, x_corner + 18, y_corner + 18, 0)  -- portrait border
    rectfill(x_corner + 17, y_corner + 1, x_corner + 26, y_corner + 9, 0)  -- team icon border
    line(x_corner, y_corner + 20, x_corner + 80, y_corner + 20, 2)  -- background
    rectfill(x_corner + 114, y_corner, x_corner + 128, y_corner + 7, 2)  -- player's gold border
    rectfill(x_corner + 115, y_corner, x_corner + 128, y_corner + 6, 8) -- players' gold background
    print(gold .. "g", x_corner + 116, y_corner + 1, 7 + (flr((last_checked_time*2 % 2)) * 3)) -- player's gold
    pal()
    print(players_turn_team, x_corner + 29, y_corner + 3, 0) -- team name
    print(tile_info[1], x_corner + 30, y_corner + 12, 0) -- tile name and defense
    spr(co_icon[players_turn_team], x_corner + 2, y_corner + 2, 2, 2)  -- portrait
    spr(palette_icon[players_turn_team], x_corner + 19, y_corner + 2, 1, 1)  -- icon

    -- draw structure capture leftover
    for struct in all(structures) do
      if points_equal(struct.p, self.p) then
        -- change sprite to uncaptured structure so we don't draw their colors wrong
        local type_to_sprite_map = {28, 29, 30}
        tile = type_to_sprite_map[struct_type]
        rectfill(x_corner + 71, y_corner + 11, x_corner + 79, y_corner + 17, 0)  -- team icon border
        local capture_left = struct.capture_left
        if struct.capture_left < 10 then capture_left = "0" .. struct.capture_left end
        print(capture_left, x_corner + 72, y_corner + 12, 7 + (flr((last_checked_time*2 % 2)) * 3)) -- capture left
        break
      end
    end
    spr(tile, x_corner + 20, y_corner + 11, 1, 1)  -- tile sprite

    if draw_prompt then
      -- draw the prompt if the above flag was set
      -- we draw it last so other things don't get drawn over it
      self:draw_prompt()
    end

  end

  selector.stop_selecting = function(self)
    self.selecting = false
    self.selection = nil
    self.selection_type = nil
    self.movable_tiles = {}
    self.arrowed_tiles = {}
    self.prompt_options = {}
    self.prompt_options_disabled = {}
    self.prompt_title = nil
  end 

  selector.start_unit_prompt = function(self)
    self.selection_type = 2

    self.prompt_options = {1}  -- rest is in options by default

    -- store the attack targets
    self.attack_targets = self.selection:targets()
    if #self.attack_targets > 0 and (not self.selection.ranged or not self.selection.has_moved) then 
      -- add attack to the prompt if we have targets
      add(self.prompt_options, 2)
    end

    for struct in all(structures) do
      if points_equal(struct.p, self.selection.p) then
        -- ensure we're an infantry or mech with `self.selection.index < 3`
        if self.selection.index < 3 and struct.team ~= players_turn_team then 
          -- if we're on a structure that isn't ours and we're an infantry or a mech then add capture to prompt
          add(self.prompt_options, 3)
        end
      end
    end

    self.prompt_selected = #self.prompt_options
  end

  selector.start_build_unit_prompt = function(self)
    self.selection_type = 8

    self.prompt_options = {}
    self.prompt_title = "total gold: " .. players_gold[players_turn]

    for i, unit_type in pairs(unit_types) do
      if players_gold[players_turn] >= unit_type.cost then
        add(self.prompt_options, unit_type.index)
      else
        add(self.prompt_options_disabled, unit_type.index)
      end
    end

    self.prompt_selected = 1
    sfx(sfx_prompt_change)
  end

  selector.start_menu_prompt = function(self)
    self.selection_type = 4

    self.prompt_options = {1}  -- end turn is in options by default
    self.prompt_selected = 1

    sfx(sfx_prompt_change)
  end

  selector.start_attack_selection = function(self)
    self.selection_type = 3
    self.prompt_options = {}

    for i = 1, #self.attack_targets do
      add(self.prompt_options, i)
    end
    self.prompt_selected = 1

    sfx(sfx_prompt_change)
  end

  selector.draw_prompt = function(self)
    local y_offset = 15
    if self.selection_type == 8 then y_offset = -25 end
    local prompt_text
    for i, prompt in pairs(self.prompt_options) do
      local bg_color = 6
      prompt_text = self.prompt_texts[self.selection_type][prompt]
      if i == self.prompt_selected then 
        bg_color = 14
        prompt_text = prompt_text .. "!"
      end

      draw_msg({self.p[1], self.p[2] - y_offset}, prompt_text, bg_color, bg_color == 14)
      y_offset += 9
    end
    for disabled_prompt in all(self.prompt_options_disabled) do
      prompt_text = self.prompt_texts[self.selection_type][disabled_prompt]
      draw_msg({self.p[1], self.p[2] - y_offset}, prompt_text, 8)
      y_offset += 9
    end
    if self.prompt_title then
      draw_msg({self.p[1], self.p[2] - y_offset}, self.prompt_title, 10)
    end
  end

  selector.update_prompt = function(self, change_val)
    if not change_val then return end

    self.prompt_selected = (self.prompt_selected + change_val) % #self.prompt_options
    if self.prompt_selected < 1 then self.prompt_selected = #self.prompt_options end
    if #self.prompt_options > 1 then
      sfx(sfx_prompt_change)
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
    local x_change
    local y_change
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
  add(war_maps, make_war_map({-16, -16, 128, 112}))

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


    -- fillp(0b0100000101000001)
    -- rectfill(self.r[1] - 256, self.r[2], self.r[1] + self.r[3] + 256, self.r[2] - 256, 0x1c)
    -- rectfill(self.r[1] - 256, self.r[2], self.r[1], self.r[2] + self.r[4] + 256, 0x1c)
    -- fillp(0)

    -- fill background in with patterns
    local x = self.r[1]
    local y = self.r[2]
    local w = self.r[3]
    local h = self.r[4]
    fillp(0b1111011111111101)
    rectfill(x-38, y-38, x+w+45, y+h+45, 0x1c)
    fillp(0b1011111010111110)
    rectfill(x-30, y-30, x+w+37, y+h+37, 0x1c)
    fillp(0b0101101001011010)
    rectfill(x-24, y-24, x+w+29, y+h+29, 0x1c)
    fillp(0b0100000101000001)
    rectfill(x-16, y-16, x+w+23, y+h+23, 0x1c)
    fillp(0)
    -- fill with blue sea
    rectfill(x-8, y-8, x+w+15, y+h+15, 12)


    -- fill background with blue water
    map(0, 0, 0, 0, 18, 18)

    -- pal()
  end

  war_map.load = function(self)
    -- set global structures to contain all structures
    structures = {}
    for tile_y = self.r[2], self.r[2] + self.r[4], 8  do
      for tile_x = self.r[1], self.r[1] + self.r[3], 8  do
        local tile_info = get_tile_info(mget(tile_x / 8, tile_y / 8))
        if tile_info[3] then
          -- create structure of whatever type this tile is, and owned by whatever player owns this struct(if any)
          add(structures, make_structure(tile_info[3], {tile_x, tile_y}, tile_info[4]))
        end
      end
    end
  end

  return war_map
end

function make_structure(struct_type, p, team)
  local struct = {}

  -- structure types:
  -- 1: hq
  -- 2: city
  -- 3: base
  struct.type = struct_type
  struct.p = p
  struct.team = team
  struct.capture_left = 20

  -- set structure sprite based on the structure type
  local struct_sprite
  if struct_type == 1 then 
    struct_sprite = 224 
    players_hqs[players_reversed[team]] = struct  -- add this hq to the list of hqs
    if team == players[1] then
      selector.p = p
    end
  elseif struct_type == 2 then struct_sprite = 225 
  else struct_sprite = 226 end

  -- components
  local active_animator
  if not team then 
    -- set palette to unowned if we have no team (5 magic number for unowned)
    team = 5 
    active_animator = false
  end
  struct.animator = make_animator(struct, 0.4, struct_sprite, -32, team, {0, -3}, nil, active_animator)

  struct.update = function(self)
    if not get_unit_at_pos(self.p) then
      self.capture_left = 20
    end
  end

  struct.draw = function(self)
    rectfill(self.p[1], self.p[2], self.p[1] + 7, self.p[2] + 7, 3)
    self.animator:draw()
  end

  struct.capture = function(self, unit)
    self.capture_left -= unit.hp
    if self.capture_left <= 0 then
      sfx(sfx_captured)
      self.team = unit.team
      self.animator.palette = unit.team
      self.animator.animation_flag = true
      self.capture_left = 20
      if self.type == 1 then
        -- hq captured; end game
        load("loader.p8")
      end
    else
      sfx(sfx_capturing)
    end
  end

  struct.build = function(self, unit_type_index)
    sfx(sfx_build_unit)
    local new_unit = make_unit(unit_type_index, {self.p[1], self.p[2]}, players[players_turn])
    players_gold[players_turn] -= new_unit.cost
    new_unit.is_resting = true
    add(units, new_unit)
    selector.p = {self.p[1], self.p[2]}
  end

  return struct

end

function make_units()
  units = {}

  units[1] = make_unit(1, {24, 32})
  units[2] = make_unit(2, {40, 32})
  units[3] = make_unit(7, {24, 40})
  units[4] = make_unit(1, {64, 32}, palette_green)
  units[5] = make_unit(3, {64, 40}, palette_green)
  units[6] = make_unit(6, {64, 48}, palette_green)
end

function make_unit(unit_type_index, p, team)
  local unit = {}

  -- inherit all properties from unit_type
  local unit_type = unit_types[unit_type_index]
  for k, v in pairs(unit_type) do
    unit[k] = v
  end

  unit_id_i += 1
  unit.id = unit_id_i
  unit.p = p
  if not team then team = palette_orange end
  unit.team = team
  unit.cached_animator_fps = 0.4
  unit.hp = 10

  -- points to move to one at a time
  unit.cached_p = {}
  unit.movement_points = {}
  unit.movement_i = 1
  unit.cached_sprite = unit.sprite -- cached sprite that we can revert to after changing it
  unit.is_moving = false
  unit.is_resting = false

  -- components
  unit.animator = make_animator(
    unit,
    unit.cached_animator_fps,
    unit.sprite,
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

  unit.get_movable_tiles = function(self, travel_offset, add_enemy_units_to_return)
    -- returns two tables
    -- the first table has all of the tiles this unit can move to. this is the only one the ai wants.
    -- the second table is the rest of the tiles they could move to if their own units weren't occupying them. 

    -- travel_offset increases the distance of the search by one. you can determine areas of attack of setting this to 1
    -- if we want to see the enemy units we can attack, we should also set `add_enemy_units_to_return` to true. 
    travel_offset = travel_offset or 0

    local current_tile
    local tiles_to_explore = {{self.p, self.travel + travel_offset}}  -- store the {point, travel leftover}
    local movable_tiles = {}
    local tiles_with_our_units = {}
    local explore_i = 0  -- index in tiles_to_explore of what we've explored so far

    while #tiles_to_explore > explore_i do
      explore_i += 1
      current_tile = tiles_to_explore[explore_i]

      -- explore this tile's neighbors
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

        -- check the travel reduction for the tile's type
        local travel_left = current_tile[2] - self:tile_mobility(mget(t[1] / 8, t[2] / 8))

        -- see if we've already checked this tile. if we have and the cost to get to it was lower, don't explore the new tile.
        local checked = false
        for t2 in all(tiles_to_explore) do

          checked = points_equal(t, t2[1]) and travel_left <= t2[2]
          if checked then break end
        end

        local unit_at_tile = get_unit_at_pos(t)
        if travel_left > 0 then
          if not checked and (not unit_at_tile or unit_at_tile.team == self.team) then
            local new_tile = {t, travel_left}
            add(tiles_to_explore, new_tile)
          end
          if add_enemy_units_to_return and unit_at_tile and unit_at_tile.team ~= self.team then
            add (movable_tiles, t)
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

    self.has_moved = #points > 1

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
      if players_human[players_turn] then
        selector:start_unit_prompt()  -- change to select type unit prompt
      end

      self:cleanup_move()
    end

  end

  unit.kill = function(self)
    sfx(sfx_unit_death)
    del(units, self)
  end

  unit.capture = function(self)
    for struct in all(structures) do
      if points_equal(struct.p, self.p) then
        struct:capture(self)
        self.is_resting = true
        break
      end
    end
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
    self.has_moved = false
    self.movement_i = 1
    self.movement_points = {}
  end

  unit.tile_mobility = function(self, tile)
    -- returns the mobility cost for traversing a tile for the unit's mobility type
    if fget(tile, flag_terrain) then
      if fget(tile, flag_road) then return 1
      elseif fget(tile, flag_plain) then
        if self.mobility_type == 2 then return 2
        else return 1 end
      elseif fget(tile, flag_forest) then
        if self.mobility_type == 2 then return 3
        elseif self.mobility_type == 3 then return 2
        else return 1 end
      elseif fget(tile, flag_mountain) or fget(tile, flag_river) then
        if self.mobility_type == 0 then return 2
        elseif self.mobility_type == 1 then return 1
        end
        -- else return 255 end
      end
    elseif fget(tile, flag_structure) then return 1 end
    return 255 -- unwalkable if all other options are exhausted
  end

  unit.ranged_attack_tiles = function(self, p)
    local tiles = {}
    if not p then p = self.p end
    for t_y = -self.range_max * 8, self.range_max * 8, 8 do
      for t_x = -self.range_max * 8, self.range_max * 8, 8 do
        local d = manhattan_distance({p[1] + t_x, p[2] + t_y}, p)
        if d >= self.range_min and d <= self.range_max then
          add(tiles, {p[1] + t_x, p[2] + t_y})
        end
      end
    end
    return tiles
  end

  unit.targets = function(self, p)
    local targets = {}
    local tiles
    if not p then p = self.p end
    if self.ranged then
      tiles = self:ranged_attack_tiles(p)
    else
      tiles = get_tile_adjacents(p)
    end
    for t in all(tiles) do
      local u = get_unit_at_pos(t)
      if u and u.team ~= self.team then
        add(targets, u) 
      end
    end
    return targets
  end

  unit.calculate_damage = function(self, u2, return_strike, tile_p, our_life)
    if not our_life then our_life = self.hp end
    if not tile_p then tile_p = u2.p end
    if return_strike and self.ranged then return 0 end
    local tile_defense = get_tile_info(mget(tile_p[1] / 8, tile_p[2] / 8))[2]
    return flr(self.damage_chart[u2.index] * 1.25 * our_life / 10 * tile_defense + rnd(1))
  end

  return unit
end

-- components
function make_animator(parent, fps, sprite, sprite_offset, palette, draw_offset, draw_shadow, animation_flag)
  local animator = {}
  animator.parent = parent
  animator.fps = fps
  animator.sprite = sprite
  animator.sprite_offset = sprite_offset
  animator.palette = palette
  if animation_flag ~= nil then animator.animation_flag = animation_flag else animator.animation_flag = true end
  if draw_offset then animator.draw_offset = draw_offset else animator.draw_offset = {0, 0} end
  animator.draw_shadow = draw_shadow  -- draws a shadow on sprites if true

  animator.time_since_last_frame = 0
  animator.animation_frame = 0
  animator.flip_sprite = false

  animator.draw = function(self)
    -- update and animate the sprite
    self.time_since_last_frame += delta_time
    if self.animation_flag and self.time_since_last_frame > self.fps then
      self.animation_frame = (self.animation_frame + 1) % 2
      self.time_since_last_frame = 0
    end

    local animation_frame = self:get_animation_frame()


    -- draw sprite
    if(self.palette) then
      set_palette(self.palette)
    end

    if self.draw_shadow then
      -- draw shadow
      outline_sprite(animation_frame, 0, self.parent.p[1] + self.draw_offset[1], self.parent.p[2] + self.draw_offset[2], self.flip_sprite, self.palette)
    else
      -- draw sprite normally
      spr(animation_frame, parent.p[1] + self.draw_offset[1], parent.p[2] + self.draw_offset[2], 1, 1, self.flip_sprite)
    end

    if(self.palette) then
      pal()
    end

  end

  animator.draw_outline = function(self, animation_frame)
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

-- save/loading data functions
function peek_increment()
  -- peeks at memory_i and increments the global memory_i counter while doing it
  local v = peek(memory_i)
  memory_i += 1
  return v
end

function load_string(n)
  -- reads a string from memory and increments the memory_i counter by its length
  if not n then n = 20 end  -- string default length
  local str = ""
  for i = 1, n do
    local charcode_val = chr(peek_increment())
    str = str .. charcode_val
  end
  -- i don't know what this returns, but it's not a string. that's fine. it works. 
  return str
end

function load_assets()

  -- load all 7 unit types

  for i=1, 7 do
    local u = {}

    u.index = peek_increment()
    u.type = load_string(10)
    u.sprite = peek_increment()
    u.mobility_type = peek_increment()
    u.travel = peek_increment()
    u.cost = peek_increment()
    u.range_min = peek_increment()
    u.range_max = peek_increment()
    if u.range_min > 0 then u.ranged = true end  -- add helper variable to determine if unit is ranged
    u.moveout_sfx = peek_increment()
    u.combat_sfx = peek_increment()

    u.damage_chart = {}
    for i=1, 7 do
      peek_increment() -- get rid of the index. we assume they're ordered from 1 to 7

      local v = peek4(memory_i)  -- value is 4byte float. increment by 4
      memory_i += 4

      add(u.damage_chart, v)
    end

    add(unit_types, u)
  end
  
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
    pal(9, 11)
    pal(8, 3)
    pal(2, 10)  
  elseif palette == palette_pink then
    pal(9, 14)
    pal(8, 2)
    pal(2, 10)
  elseif palette == 5 then -- un-owned palette. 5 is magic number we use
    pal(9, 13)
    pal(8, 6)
    pal(2, 5)
  else
    for i = 0, 15 do
      pal(i,  palette)
    end
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
  -- refac: if only one use. can be refactored to be inline
  return p[1] >= r[1] and p[1] <= r[1] + r[3] and p[2] >= r[2] and p[2] <= r[2] + r[4]
end

-- table functions
function sort_table_by_y(a)
  for i=1,#a do
    local j = i
      while j > 1 and a[j-1].p[2] > a[j].p[2] do
        a[j],a[j-1] = a[j-1],a[j]
        j = j - 1
      end
  end
end

function point_in_table(p, t, keys)
  -- returns the index of the first point that matches if it is in the table
  -- otherwise returns nil

  -- if keys is true we instead compare p against the table's keys and return the value.
  for i, p2 in pairs(t) do
    if keys then 
      if points_equal(p, i) then return p2 end  -- compare p with keys
    else
      if points_equal(p, p2) then return i end  -- compare p with values
    end
  end
end

function table_point_index(t, p)
  -- works like table[key] except key can be a point
  -- otherwise returns nil
  for k, v in pairs(t) do
    if points_equal(p, k) then return v end
  end
  return 32767  -- return (essentiall) infinity if the point isn't in the table. this is for pathfinding
end

function merge_tables(t1, t2)
  -- merges the second table into the first
  i = #t1 + 1
  for _, v in pairs(t2) do 
    t1[i] = v 
    i += 1
  end
end

function insert(list, pos, value)
  if pos and not value then
    value = pos
    pos = #list + 1
  end
  if pos <= #list then
    for i = #list, pos, -1 do
      list[i + 1] = list[i]
    end
  end
  list[pos] = value
end

function remove(list, pos)
  if not pos then
    pos = #list
  end
  for i = pos, #list do
    list[i] = list[i + 1]
  end
end

function outline_sprite(n,col_outline,x,y,flip_x,sprite_palette)
  -- reset palette to black
  for c=1,15 do
    pal(c,col_outline)
  end
  -- draw outline
  for xx=-1,1 do
    for yy=-1,1 do
      spr(n,x+xx,y+yy,1,1,flip_x,flip_y)
    end
  end
  -- reset palette
  pal()
  -- draw final sprite
  set_palette(sprite_palette)
  spr(n,x,y,1,1,flip_x,flip_y) 
  pal()
end

function draw_msg(center_pos, msg, bg_color, draw_bar)
  msg_length = #msg

  local padding = 2
  local x_pos = center_pos[1] + 5 - msg_length * 4 / 2 
  local y_pos = center_pos[2]

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

-- priority queue code
-- code edited from: https://github.com/roblox/wiki-lua-libraries/blob/master/standardlibraries/priorityqueue.lua
prioqueue = {}
prioqueue.__index = prioqueue

function prioqueue.new()
  local newqueue = {}
  setmetatable(newqueue, prioqueue)

  newqueue.values = {}
  newqueue.priorities = {}

  return newqueue
end

local function siftup(queue, index)
  local parentindex
  if index ~= 1 then
    parentindex = flr(index/2)
    if queue.priorities[parentindex] > queue.priorities[index] then
      queue.values[parentindex], queue.priorities[parentindex], queue.values[index], queue.priorities[index] =
        queue.values[index], queue.priorities[index], queue.values[parentindex], queue.priorities[parentindex]
      siftup(queue, parentindex)
    end
  end
end

local function siftdown(queue, index)
  local lcindex, rcindex, minindex
  lcindex = index*2
  rcindex = index*2+1
  if rcindex > #queue.values then
    if lcindex > #queue.values then
      return
    else
      minindex = lcindex
    end
  else
    if queue.priorities[lcindex] < queue.priorities[rcindex] then
      minindex = lcindex
    else
      minindex = rcindex
    end
  end

  if queue.priorities[index] > queue.priorities[minindex] then
    queue.values[minindex], queue.priorities[minindex], queue.values[index], queue.priorities[index] =
      queue.values[index], queue.priorities[index], queue.values[minindex], queue.priorities[minindex]
    siftdown(queue, minindex)
  end
end

function prioqueue:add(newvalue, priority)
  insert(self.values, newvalue)
  insert(self.priorities, priority)

  if #self.values > 1 then
    siftup(self, #self.values)
  end
end

function prioqueue:pop()
  if #self.values <= 0 then
    return nil, nil
  end

  local returnval, returnpriority = self.values[1], self.priorities[1]
  self.values[1], self.priorities[1] = self.values[#self.values], self.priorities[#self.priorities]
  remove(self.values, #self.values)
  remove(self.priorities, #self.priorities)
  if #self.values > 0 then
    siftdown(self, 1)
  end

  return {returnval, returnpriority}
end


__gfx__
7700007700000000777770000000000000000000000000000000000000000044000000002200000000000000000000000000000000000000566666555ccccc63
7000000707700770755000000070007007070707000000000000000000000044000000002200000000000000000000000000000000000000c66666cc5c5c5c66
00000000070000707567000007070707007000700000000000000000000000440000000022000000000000000000000000000000000000005667665c66666666
0000000000000000705670000070007007070707000000000000000000000044000000002200000000000000000000000000000000000000c66766cc66666666
00000000000000007005670000000000000000000000000000000000000000440000000022000000000000000000000000dddd00000000005666665c66776677
0000000007000070000056500070007007070707000000000000000000000044000000002200000000000000000000000ddddd5000000000c66666cc66666666
7000000707700770000005500707070700700070000000000000000000000444000000002220000000000000000000000ddddd50000000006667666666666666
7700007700000000000000000070007007070707000000000000000044444443444444443244444400000000000000000d55555000000000666766635c5c5c66
0888880008888800000000000000000022222200000210000222282855555553000000003555555500f0000000000000006dd500005555000000000033b33b33
899999808999998000998000009880002999820000222000222222202222444500000000522222220f4400f000000000065555500d7575d0000000053bbb5bb3
8999999889999998099978000992780029927855022200002222200022222244000000002222222272427f4200000000067dd750ddd55ddd005500553bb5bb53
22222220222222200999185599921855299218552220287022299870222222440000000022222222072707220000000006dddd50d7d57d7d055d055dbb5b5bb5
ffff1f00788f1f770999990099999955299999552280281829999818000002440000000022200000007f40770000000065555555ddd55ddd55dd55dd3b5bbb53
088fff70788fff75222922202222222022222220222222222229222800000044000000002200000007244270000ff00067d7d7d5d7d57d7dd7d7d7d7bbb5bbb5
0287777772888877282828202898989228989892289898922828282000000044000000002200000000722700000f20006dddddd5ddd55ddddddddddd33433433
080080000200200022202220022222200222222002222220222022200000004400000004220000000007700000f4220067d7d7d5ddd55dddd7d7d7d733333333
08888800008888800000000000000000002222000001000000222200000000440000000022000000333ff3333f42423333666666666666666666633300000000
8999998068999998000000000000000002999920002220000222222000000044000000002200000033f442333f24423336666666666666666666663300000000
8888888889999999009990000099990002999920002220000222222000000044000000002200000033f442333f42423366666666666666666666666300000000
f22222f08888888809999900099999900299992000828000022222200000004400000000220000003f4442233f42422366666677667766776676666300000000
088888707772222009999900299999922299992202222200022222200000004400000000220000003f4424233f44242366666666666666666667666300000000
088888707678888828999820829999288299992828222820289999820000004400000000220000003f4244233f42442366676666666666666666666300000000
02222200666288208299928028299282282992828282828082999928000000440000000022000000b4b4b24bb4b4b24b66676666666666666667666300000000
080000000020000028202820828998288282282828202820282002820000004440000000220000003bbbbbb33bbbbbb366666663333333336667666300000000
08888800088888770000000000000000022222200021200002822820000000445555555522000000000000003333333366666663333333336666666366666663
89999980899999870088800000888800298998920022200002222220000000442222222222000000000000003333333366666666666666666666666366666663
89999998899999980878780008788780297887920022200002299220000000422222222222000000000000003333333366676666666666666667666366676663
22222220222222260918190008199180291881920278720000788700000000022222222220000000000000003333333366676666666666666667666366676663
ff1ff1f08f1f17770995990029555592295555920818180008188180000000000000000000000000000000003333333366667677667766776676666366666663
0fffff7008fff7572895982082555528825115282222222028999982000000000000000000000000000000003333333366666666666666666666666366666663
02877777028886668299928028299282285555828299928082988928000000000000000000000000000000003333333336666666666666666666663366676663
08000000020000002820282082899828828998282820282028000082000000000000000000000000000000003333333333666666666666666666633366676663
00000000000000007008800780088008a008800a0555555000055000005555000005500000000000000000000000000000000000000000000000000000000000
00000000070000700888888000899800008998005555555505555550055005500500005000000000000000000000000000000000000000000000000000000000
000000000088880008799780089aa980089559805555555555500555000000000000000000000000000000000000000000000000000000000000000000000000
0008700000879800889aa98889a00a98895005985555555505000050000000000000000000000000000000000000000000000000000000000000000000000000
0007800000897800889aa98889a00a98895005980500005000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000088880008799780089aa980089009800900009000900000000008000000000000000000000000000000000000000000000000000000000000000000
00000000070000700888888000899800008998000890008000000090080000000000000000000000000000000000000000000000000000000000000000000000
00000000000000007008800780088008a008800a0080980008000000009000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000222222000021000002222828000000000000000000000000000080005ccccc6522000000000000440000000000000000
08888800088888000000000000988000299982000222000022222220000000000000000000000000000880002ccccc22cc000000000000440000000000000000
89999980899999800099800009927800299278552220000022222000000000000000000000000000008888882ccccc22cc000000000000cc0000000000000000
89999998899999980999780099921855299218552200287022299870000000000000000000000000088888882ccccc22cc000000000000cc0000000000000000
222222202222222009991855999999552999995522802818299998180000000000000000000000000088888800000000cc000000000000cc0000000000000000
ffff1f00788f1f7722292220222222202222222022222222222922280000000000000000000000000008800000000000cc000000000000cc0000000000000000
088fff70788fff752929292029898982298989822989898229282920000000000000000000000000000080000000000022000000000000cc0000000000000000
02877777728888772228222002222220022222200222222022202220000000000000000000000000000000000000000022000000000000445ccccc6400000000
08888800008888800000000000000000002222000001000000222200000000000088800000000000000000000000000033555555555555555555533300000000
89999980689999980000000000000000029999200022200002222220000000000088800000000000000000000000000035ccccccccccccccccccc63300000000
8888888889999999009990000099990002999920002220000222222000000000008880000000088888888888888000005ccccccccccccccccccccc6300000000
f22222f088888888099999000999999002999920008280000222222000000000008880000000888888888888888800005ccccccccccccccccccccc6300000000
0888887077722220099999008999999882999928022222000222222000000000008880000008888888888888888880005ccccccccccccccccccccc6300000000
0888887076788888829992802899998228999982822222808222222800000000008880000008888000000000088880005ccccccccccccccccccccc6300000000
0222220066628828289998208289982882899828282228202899998200000000008880000008880000000000008880005cccccc666666666cccccc6300000000
0000080000000020828082802829928228222282828082808280082800000000008880000008880000000000008880005ccccc63333333335ccccc6300000000
0888880008888877000000000000000002222220002120000282282000000000008880000008880000000000008880005ccccc63333333335ccccc635ccccc63
8999998089999987008880000088880029899892002220000222222000000000008880000008888000000000088880005cccccc555555555cccccc635ccccc63
8999999889999998087878000878878029788792002220000229922000000000008880000008888888888888888880005ccccccccccccccccccccc635ccccc63
2222222022222226091819000819918029188192027872000078870000000000888888800000888888888888888800005ccccccccccccccccccccc635ccccc63
ff1ff1f08f1f1777099599008955559829555592081818000818818000000000088888000000088888888888888000005ccccccccccccccccccccc635ccccc63
0fffff7008fff757829592802855558228511582822222808299992800000000008880000000000000000000000000006ccccccccccccccccccccc635ccccc63
02877777028886662899982082899828825555282899982028988982000000000008000000000000000000000000000036ccccccccccccccccccc6335ccccc63
0000800000002000828082802829928228299282828082808200002800000000000000000000000000000000000000003366666666666666666663335ccccc63
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
008992000022220000000000000000000000000000000000000000000000000000eeeeeeeeeeeee0000333333333333300111111111111000000000000000000
08222220007272000000000200000000000000000000000000000000000000000eeee7eeeeeeeeee033333333333337301111111111111100000000000000000
0879972099922999002200220000000000000000000000000000000000000000ee77eeeeeee222ee073333333333373001111111111111110000000000000000
0899992097927979022902290000000000000000000000000000000000000000e77e22f2eeefff2e337333333333333011111155555555510000000000000000
8222222299922999229922990000000000000000000000000000000000000000e7eefff2eeeffffe3333733333733333111555ccccccccc50000000000000000
8797979297927979979797970000000000000000000000000000000000000000eeeef0f22eef0ffeb33bfffb333bbbbb115cc1111ccc111c0000000000000000
8999999299922999999999990000000000000000000000000000000000000000e7ee00ff2ee000feb3f2222fbb322f2015cc222222f222220000000000000000
8797979299922999979797970000000000000000000000000000000000000000ee2f070f2ef070fef2ff2222ffb222205c2227772ff277720000000000000000
0000000000000000000000000000000000000000000000000000000000000000ee2f070f2ef000feff2226722222762012f267172ff271720000000000000000
0000000000000000000000000000000000000000000000000000000000000000ee2f000fffff0f2effff2712fff217202ff226772ff267720000000000000000
0000000000000000000000000000000000000000000000000000000000000000ee2ff0ffffff0f2e2fff2222fff2222012ff22122fff222f0000000000000000
00000000000000000000000000000000000000000000000000000000000000000e2fff222222f2e02ffffffff22fff20002ff2f2ffff2ff00000000000000000
00999900000000000000000000000000000000000000000000000000000000000ee2ff11111ff2e002feeeff77ffee200002f2f2ff22fff00000000000000000
099999200000000000000000000000000000000000000000000000000000000000ee20eeeeef002e002fffff12ffff2000002fffffffff000000000000000000
0999992000000000000000000000000000000000000000000000000000000000000e2000099fffa000222fff77fff200000222ff1222f0000000000000000000
092222200000000000000000000000000000000000000000000000000000000000002aafffffffaf02222222222220000022222ff22ff2000000000000000000
008992000022220000000000006cc1000011110000000000000000000000000000eeeeeeeeeeeee0000333333333333300111111111111000088888888888000
08222220008282000000000206111110006161000000000100000000000000000eeee7eeeeeeeeee033333333333337301111111111111100288888888888880
088998209992299900220022066cc610ccc11ccc001100110000000000000000ee77eeeeeee222ee073333333333373001111111111111112888888888828878
08999920989289890229022906cccc10c6c16c6c011c011c0000000000000000e77e22f2eeefff2e337333333333333011111155555555518788881118882788
82222222999229992299229961111111ccc11ccc11cc11cc0000000000000000e7eefff2eeeffffe3333733333733333111555ccccccccc58878113331888288
88989892989289899898989866c6c6c1c6c16c6cc6c6c6c60000000000000000eeeef0f22eef0ffeb33bfffb333bbbbb115cc1111ccc111c8881333333188828
8999999299922999999999996cccccc1ccc11ccccccccccc0000000000000000e7ee00ff2ee000feb3f2222fbb322f2015cc222222f222228813222ffff28882
88989892999229999898989866c6c6c1ccc11cccc6c6c6c60000000000000000ee2f070f2ef070fef2ff2222ffb222205c2227772ff2777282226722ff262888
8888888011111110333333302222222000000000000000000000000000000000ee2f070f2ef000feff2226722222762012f267172ff271728227717fff717288
899999801dcdcd103bbbbb302aaeaa2000000000000000000000000000000000ee2f000fffff0f2effff2712fff217202ff226772ff267722ff21c7fff1c6228
899899801cdddc103b333b302aeeea2000000000000000000000000000000000ee2ff0ffffff0f2e2fff2222fff2222012ff22122fff222fffff222fff222ff8
898989801ddddd103b333b302eaeae20000000000000000000000000000000000e2fff222222f2e02ffffffff22fff20002ff2f2ffff2ff02ffffffff2fffff2
899899801cdddc103b343b302aaeaa20000000000000000000000000000000000ee2ffeeeeeff2e002feeeffffffee200002f2f2ff22fff022ffffffffffff22
899999801dcdcd103bb4bb302aeaea200000000000000000000000000000000000ee20ffffff002e002fffff22ffff2000002fffffffff00002ffffffffff222
8888888011111110333333302222222000000000000000000000000000000000000e2000099fffa000222ffffffff200000222ff1222f0000002fff222ff2222
000000000000000000000000000000000000000000000000000000000000000000002aafffffffaf02222222222220000022222ffffff200000002ffff202020
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
00000000000000212121000000000303000000000000002121210100060a1209000000000000002121211111030303000000000000000021212100410303030300000000000000000000000000000000000000000000000000000021212121000000000000000000000000000505050000000000000000000000000005050505
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000464a52868a920000000000000000000000000000000000000000000000000000
__map__
0000000018080808080828000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00185e08073b3be13b3b29000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
18077fe13be0e23b3b3b09280000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
273b7f2c2d2d2d2d2d2e3b290000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
273b7f3f2a2a2a2a2a3f2a290000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
272a7f3f2a2a1f6c6d0e6d5c0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
5d7d7e3f3b2a1f7f3b3fe4092800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
273b3b3c3d3d3d0f3d3e3b3b2900000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
37173b3b3b3b3b7fe4e5e3193900000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
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
000300003c6603c6603c6603c6503c6503965037640366403464034640316402f6402d6302b630296302763024630216301f6301d6301b63019630186301563012630106300d6300b63009630056300363000630
00020000114501e4502545025450224501a4500f450084501145017450204502445020450104500a450164501b45022450284502c45024450154500e450164501d4502245026450294502c4502b4502945025450
000200000205004050080500c05012050180501e050240502a0502f050330503605038050370503705038050390503b0503d0503e0503f05032050330503505037050380503a0503b0503c0503d0503f0503f050
000200001e05020050260502d050000003b0503805035050320502d0502a050240501c05012050100500000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00020000146401a6002065021640266102064018600146501864021600266301b6201065012610176401d6002162028640226501a6201260013630176001964020640296102860024620216501b630166000f620
000300000c3400835007340053500334002350013400733007340063300534004330033400233009320083300732006330043200433003320023200a340093300834007330063400533003340023300134001330
01020000130501605022650190301b03021640256401d0301b06019030170201d610106100e050296400a0201d620080200704026620106200305002030010402563001030196201962013650050102261005010
000300000c4500846007450054600345002460014500744007450064400545004440034500244009430084400743006440044300444003430024400a450094400845007440064500544003450024400145001440
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000400003f6400464000640026403f6400364000640026403f6400264000640056403f6400064000640006403f6400464001640006403f6400464000640066403f64000640006400064000640006400064000640
000400003965034650336402f6402964025640226400c6400b6400864006640046400364003640026400264002640036400564007640076400464000600066003f60000600006000060000600006000060000600
000300003f640046403f640026403f640036403f640026403f640026403f640056403f640036403f640046403f640046403f640076403f640046403f640066403f64000640006400064000640006400064000640
0003000032660396603c6503e6503b65037650356502f6502a6501f650196501564012640106400d6400c6400a6400964008640066400564007640066400b6400a64006640036400363003630036300363008630
0003000032660396603c6603e6603b66037660356602f6502a6501f650196501565012650106500d6400c6400a640096400d640396603d6603f6603966035660336602c66029640216401d640196401464012640
000300002f650396503d6503d650386502f650306502d65033350353503e3503a3503735034350303502b35026350223501c350143500e3500835005350003500036022670276703c6703c6703c6703c6703a670
0004000025656396563e6563f6563b656396562e656266560965624656356563a6563d6563d656396563765624656096562265635656386563d6563e6563b656376662f6760a6760767604676026760167600676
