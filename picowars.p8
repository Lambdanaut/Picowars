pico-8 cartridge // http://www.pico-8.com
version 27
__lua__

-- debug = true

palette_orange, palette_blue, palette_green, palette_pink = "orange star★", "blue moon●", "green earth🅾️", "pink quasar░"
team_index_to_palette = {palette_orange, palette_blue, palette_green, palette_pink}

last_checked_time, delta_time, unit_id_i, attack_timer, end_turn_timer, memory_i, dead_str, team_icon = 0, 0, 0, 0, 0, 0x4300, 'dead', {}


function _init()
  -- add menu item to return to loader
  menuitem(1, "abandon mission", function() end_game(3) end)

  load_assets()
  current_map:load()

  make_cam()

  end_turn()

  selector_init()

  players_turn_team = players[players_turn]
end

function _update()
  t = time()
  delta_time = t - last_checked_time
  last_checked_time = t
  attack_timer += delta_time
  end_turn_timer += delta_time

  btnp4 = btnp(4)
  btnp5 = btnp(5)

  selector_update()
  cam:update()

  for unit in all(units) do
    unit:update()
  end

  if btnp4 and btnp5 then
    end_game(players_turn)
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
    spr(67, hq.p[1], hq.p[2] - 11) -- draw the spire of an hq
    pal()
  end
  
  sort_table_by_f(units, function(u1, u2) return u1.p[2] > u2.p[2] end)
  for unit in all(units) do
    unit:draw()
  end

  selector_draw()

  -- run end_turn coroutine thread
  if active_end_turn_coroutine and costatus(active_end_turn_coroutine) == dead_str then
    active_end_turn_coroutine = nil
  elseif active_end_turn_coroutine then
    coresume(active_end_turn_coroutine)
  end

  if not active_end_turn_coroutine then
    ai_update()
  end
end

players_turn = 0
players = {}
players_human = {}
players_co_name = {}
players_hqs = {}
players_gold = {0, 0}
players_units_lost = {0, 0}
players_units_built = {0, 0}
players_unit_types = {{}, {}}
players_music = {}
players_co_icon = {}
units = {}
turn_i = 0
function end_game(reason)
  -- reasons:
  -- * 1: victory player 1
  -- * 2: victory player 2
  -- * 3: abandon mission

  -- write match result
  memory_i = 0x5ddd
  poke_increment(reason)
  for i = 1, 2 do
    poke_increment(players_units_lost[i])
    poke_increment(players_units_built[i])
  end
  poke_increment(turn_i)

  load("loader.p8")
end
function end_turn()
  -- change team's turn
  players_turn = players_turn % 2 + 1
  players_turn_team = players[players_turn]

  -- increment the turn count
  turn_i += 2 - players_turn

  for unit in all(units) do
    unit.is_resting = false

    -- heal all units on cities
    local struct = get_struct_at_pos(unit.p, players_turn_team)
    if unit.team == players_turn_team and struct then
      unit.hp = min(unit.hp + 2 + unit.struct_heal_bonus, 10)
    end
  end

  for struct in all(structures) do
    if struct.team == players_turn_team then
      -- add income for each city
      players_gold[players_turn] += 1
    end
  end

  selector_p = players_hqs[players_turn].p

  -- create end_turn animation coroutine
  active_end_turn_coroutine = cocreate(end_turn_coroutine)

end

-- ai code
function ai_update()
  if players_human[players_turn] then return end  -- don't do ai for humans

  if not active_ai_coroutine then
    active_ai_coroutine = cocreate(ai_coroutine)
  elseif costatus(active_ai_coroutine) == dead_str then
    active_ai_coroutine = nil
  else
    coresume(active_ai_coroutine)
  end

end

function ai_coroutine()
  -- 3 waves of passing through our units

  -- update ai's units
  -- sort units based on infantry/mech type
  ai_units_ranged = {}
  ai_units_infantry = {}
  other_ai_units = {}
  non_ai_units = {}
  for u in all(units) do
    if u.team == players_turn_team then
      if u.ranged then
        add(ai_units_ranged, u)
      elseif u.index < 3 then
        add(ai_units_infantry, u)
      else
        add(other_ai_units, u)
      end
    else
      add(non_ai_units, u)
    end
  end
  ai_units = {}
  merge_tables(ai_units, ai_units_ranged)  -- move ranged first
  merge_tables(ai_units, ai_units_infantry)  -- then infantry
  merge_tables(ai_units, other_ai_units)  -- then other units

  -- generate places the enemy can attack so our ranged units can avoid them
  enemy_attackables = {}
  if #ai_units_ranged > 0 then
    for u2 in all(non_ai_units) do if u2.ranged then merge_tables(enemy_attackables, u2:ranged_attack_tiles())
      elseif not u2.carrier then
        local u2_movable = u2:get_movable_tiles()[1]
        for t in all(u2_movable) do
          for u2_attackable in all(get_tile_adjacents(t)) do
            add(enemy_attackables, u2_attackable)
          end
        end
      end
      yield()  -- pause to avoid lag
    end
  end

  for i = 1, 3 do
    for u in all(ai_units) do 
      if u.active and not u.is_resting then
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
        elseif u.index > 2 or not get_struct_at_pos(u.p, nil, players_turn_team) then
          -- if we're not an infantry or we're an infantry that's not capturing, then 
          -- look for the best melee attack we can make
          local attackables = {}

          -- get the positions we can attack enemies from
          -- map of tile_p => attackable enemy unit from that position 
          for t in all(unit_movable_tiles) do
            attackables[t] = u:targets(t)
          end

          -- determine best fight to take
          local best_fight_u, best_fight_pos
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

            u:complete_move()  -- rest
          end
        end

        if not has_attacked then
          -- pathfind to enemy hq by default
          local enemy_hq = players_hqs[3 - players_turn].p
          local goal = enemy_hq

          if manhattan_distance(goal, u.p) < 5 and u.index > 2 then
            -- if we're not an infantry/mech and we're next to the goal, head back home to get off their hq
            goal = players_hqs[players_turn].p
          elseif u.hp < 4 or (u.hp < 9 and get_struct_at_pos(u.p, players_turn_team, nil, nil, 3)) then
            -- if our health is low, or we're healing and standing on a structure that's not a base, navigate to the nearest friendly city/hq
            local nearest_struct
            local nearest_struct_d = 32767
            for struct in all(structures) do
              local d = manhattan_distance(u.p, struct.p)
              local unit_at_struct = get_unit_at_pos(struct.p)
              if d < nearest_struct_d and struct.team == players_turn_team and (struct.type == 1 or struct.type == 2) and
                  (not unit_at_struct or unit_at_struct.id == u.id) then
                nearest_struct = struct
                nearest_struct_d = d
              end
            end
            if nearest_struct then
              goal = nearest_struct.p
            end
          elseif u.index < 3 then
            -- if we're an infantry or mech, navigate to nearest capturable structure
            local nearest_struct
            local nearest_struct_d = 32767
            for struct in all(structures) do
              local struct_weight = 0
              if struct_type ~= 2 then struct_weight = 3 end  -- prefer to capture bases/hqs over cities
              local d = manhattan_distance(u.p, struct.p) - struct_weight
              local unit_at_struct = get_unit_at_pos(struct.p)
              if d < nearest_struct_d and struct.team ~= players_turn_team and
                  (not unit_at_struct or (unit_at_struct.id == u.id or unit_at_struct.team ~= players_turn_team)) then
                nearest_struct = struct
                nearest_struct_d = d
              end
            end
            if nearest_struct then
              goal = nearest_struct.p
            end

          end

          local goal_path = ai_pathfinding(u, goal, true)

          local path = {}
          if u.ranged then
            -- don't move ranged units into enemy attack
            for t in all(goal_path) do
              if point_in_table(t, enemy_attackables) then
                insert(path, 1, t)
              else
                add(path, t)
              end
            end
          else
            path = goal_path
          end

          -- find point in path that is closest to the goal
          local p
          for t in all(path) do
            -- disregard the enemy's hq if we're not infantry/mech
            if point_in_table(t, unit_movable_tiles) and (u.index < 3 or not points_equal(t, enemy_hq)) then
              p = t
            end
          end

          if p then
            ai_move(u, p)

            if u.index < 3 then
              -- capture a structure if we're on one
              local struct = get_struct_at_pos(u.p, nil, players_turn_team)
              if struct then
                struct:capture(u)
              end
            end

            u:complete_move()
          end
        end

      end
    end
  end

  -- build units

  -- sort the structures based on their distance from the enemy's hq
  for struct in all(structures) do
    if struct.type == 3 and struct.team == players_turn_team and not get_unit_at_pos(struct.p) then
      -- build unit for each of our bases

      -- get unit counts
      -- add 1 to counts to stop division by 0 errors
      local infantry_count, mech_count, total_unit_count, unit_counts = 1, 1, 1, {0, 0, 0, 0, 0, 0, 0, 0}

      for u in all(units) do
        if u.team == players_turn_team then
          unit_counts[u.index] += 1
          total_unit_count += 1
        end
      end

      local to_build
      for i = #players_unit_types[players_turn], 1, -1 do
        -- count backwards from the most expensive unit types 
        -- build the first one we have the money for that we don't have enough of
        local unit_type = players_unit_types[players_turn][i]
        if unit_type.cost <= players_gold[players_turn] then
          to_build = i
          if unit_counts[i] * 100 / total_unit_count < unit_type.ai_unit_ratio then
            break
          end
        end
      end

      if to_build then
        struct:build(to_build)
        selector_p = copy_v(struct.p)
      end

    end
  end

  if not debug then
    for i=1,35 do
      yield()
    end
  end

  end_turn()

end
  
function ai_move(u, p)
  local path = ai_pathfinding(u, p)
  u:move(path)
  while u.is_moving do
    selector_p = copy_v(u.p)
    yield()
  end
end

function ai_pathfinding(unit, target, is_ai)
  -- draw marker on unit we're pathfinding for
  local tiles_to_explore = {}
  local tiles_to_explore = prioqueue.new()
  tiles_to_explore:add(unit.p, manhattan_distance(unit.p, target)) -- unit position sorted by f_score as starting point
  local current_tile

  local to_explore_parents = {}  -- map from point -> parent_point. starting node has no parent ;;
  local to_explore_travel = {unit.travel}  -- map of tile's index in tiles_to_explore -> travel cost

  local g_scores = {}  -- map from point -> g_score
  g_scores[unit.p] = 0

  while #tiles_to_explore.values > 0 and #tiles_to_explore.values < 100 do
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

        if point_in_table(current_t, return_path) then
          -- bug detected. avoid crash
          -- loop detected, return empty path
          -- this fixes a bug that happens some games on certain maps where somehow the
          -- pathfinder sets a parent of a child to be the parent of its parent. ({0,1} => {1,0}, {1,0} => {0,1})
          return {unit.p}
        end

        insert(return_path, 1, current_t)
      end
      return return_path
    end

    -- explore this tile's neighbors
    local current_t_g_score = table_point_index(g_scores, current_t)

    -- add all neighboring tiles to the explore list, while reducing their travel leftover
    for t in all(get_tile_adjacents(current_t)) do

      local unit_at_t = get_unit_at_pos(t)
      if is_ai or not unit_at_t or unit_at_t.team == unit.team then
        local tile_m = unit:tile_mobility(mget(t[1] / 8, t[2] / 8))

        local ai_weight = 0
        if is_ai and unit_at_t and unit_at_t.team == unit.team then ai_weight += 2 end  -- avoid friendly units in path if we're ai

        local new_g_score = current_t_g_score + tile_m + ai_weight
 
        if new_g_score < table_point_index(g_scores, t) and tile_m < 255 then
          -- if the new g_score is less than the old one for this tile, record it
          -- and set the parent to be equal to the current tile

          local tiles_to_explore_point_i_or_nil = point_in_table(t, tiles_to_explore.values)

          to_explore_parents[t] = current_t
          g_scores[t] = new_g_score
          local new_f_score = new_g_score + manhattan_distance(t, target)

          if not tiles_to_explore_point_i_or_nil then
            -- if the point isn't already in tiles_to_explore, add it. 
            tiles_to_explore:add(t, new_f_score)
          end
        end
      end
    end
  end
  -- if no path was found, return an empty list
  return {unit.p}
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

  -- prioritize sniping capturing infantry/mech
  local s = get_struct_at_pos(u2.p)
  if s and u.index < 3 then
    gain += 5
  end

  return gain - loss
end

-- tile utilities
function get_unit_at_pos(p, filter_function)
  -- returns the unit at pos, or returns nil if there isn't a unit there
  for unit in all(units) do
    if points_equal(p, unit.p) and (not filter_function or filter_function(unit)) then
      return unit
    end
  end
end

function get_struct_at_pos(p, team, not_team, struct_type, not_struct_type)
  for struct in all(structures) do
    if points_equal(p, struct.p) and (not team or struct.team == team) and (not not_team or struct.team ~= not_team) and (not struct_type or struct.type == struct_type) and (not not_struct_type or struct.type ~= not_struct_type) then
      return struct
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

  if fget(tile, 1) and fget(tile, 4) then
    -- selection is base
    return {1, tile}
  end
  -- selection is tile
  return {2, tile}
end

function attack_coroutine()
  -- coroutine action that plays out an attack
  attack_coroutine_u1.currently_attacking = true
  attack_coroutine_u2.currently_attacking = true

  -- do attack
  selector_p = copy_v(attack_coroutine_u2.p)
  attack_timer = 0
  local damage_done = attack_coroutine_u1:calculate_damage(attack_coroutine_u2)
  attack_coroutine_u2.hp = max(0, attack_coroutine_u2.hp - damage_done)
  sfx(attack_coroutine_u1.combat_sfx)
  while attack_timer < 1.5 and not debug do
    print("-" .. damage_done, attack_coroutine_u2.p[1], attack_coroutine_u2.p[2] - 4 - attack_timer * 8, 8)
    yield()
  end
  -- do response attack
  if attack_coroutine_u2.hp > 0 and not attack_coroutine_u1.ranged and not attack_coroutine_u2.ranged and not attack_coroutine_u2.is_carrier then
    selector_p = copy_v(attack_coroutine_u1.p)
    attack_timer = 0
    damage_done = attack_coroutine_u2:calculate_damage(attack_coroutine_u1)
    attack_coroutine_u1.hp = max(0, attack_coroutine_u1.hp - damage_done)
    sfx(attack_coroutine_u2.combat_sfx)
    while attack_timer < 1.5 and not debug do
      print("-" .. damage_done, attack_coroutine_u1.p[1], attack_coroutine_u1.p[2] - 4 - attack_timer * 8, 8)
      yield()
    end
  end

  -- set units new states
  if attack_coroutine_u1.hp < 1 then
    explode_at = attack_coroutine_u1.p
    attack_coroutine_u1:kill()
  else
    -- rest
    attack_coroutine_u1:complete_move()
  end

  if attack_coroutine_u2.hp < 1 then
    explode_at = attack_coroutine_u2.p
    attack_coroutine_u2:kill()
  end

  if explode_at and not debug then
    attack_timer = 0
    while attack_timer < 1.5 do
      spr(71 + flr(attack_timer*6), explode_at[1], explode_at[2] - 3 - attack_timer * 10)
      yield()
    end
  end
  explode_at = nil

  attack_coroutine_u1.currently_attacking = false
  attack_coroutine_u2.currently_attacking = false
end

function end_turn_coroutine()
  end_turn_timer = 0

  sfx(7)
  music(-1, 300)

  local played_music = false

  while end_turn_timer < 1.6 and not debug do
    set_palette(players_turn_team)
    rectfill(cam.p[1], cam.p[2] + 51, cam.p[1] + 128, cam.p[2] + 76, 9)
    line(cam.p[1], cam.p[2] + 77, cam.p[1] + 128, cam.p[2] + 77, 8)
    local rect_offset = 0
    if turn_i > 9 then
      rect_offset = 4
    end
    rectfill(cam.p[1] + 57, cam.p[2] + 61, cam.p[1] + 77 + rect_offset, cam.p[2] + 67, 8)
    print("day " .. turn_i, cam.p[1] + 58, cam.p[2] + 62, 2)
    pal()

    if not played_music and end_turn_timer > 0.7 then
      -- play music for new player on channels 0, 1, reserving channels 2 and 3 for sfx if needed
      music(players_music[players_turn], 500, 12)
      played_music = true
    end

    yield()
  end

end

function make_cam()
  cam = {}

  -- start cam off at the selector position
  cam.p = {selector_p[1] - 64, selector_p[2] - 64}

  cam.update = function (self) 
    -- move camera with the selector
    local shake_x, shake_y = 0, 0
    if explode_at and attack_timer < 1 then
      shake_x = rnd((1 - attack_timer) * 9) - 1
      shake_y = rnd((1 - attack_timer) * 9) - 1
    end

    local move_x, move_y = (selector_p[1] - 64 - self.p[1]) / 15, (selector_p[2] - 64 - self.p[2]) / 15

    self.p[1] += move_x
    self.p[2] += move_y
    camera(self.p[1] + shake_x, self.p[2] + shake_y)
  end

end

-- selector code
function selector_init()
  selector_p = selector_p or {0, 0}

  selector_time_since_last_move = 0

  -- movable tiles for selected unit
  selector_movable_tiles = {}

  -- tiles that a movement arrow has passed through, in order from first to last
  selector_arrowed_tiles = {}

  selector_prompt_selected = 1
  selector_prompt_options = {}
  selector_prompt_options_disabled = {} -- will appear marked out as disabled

  -- map of selection_type -> prompt texts available
  selector_prompt_texts = {}
  selector_prompt_texts[2] = {}
  add(selector_prompt_texts[2], "rest")
  add(selector_prompt_texts[2], "attack")
  add(selector_prompt_texts[2], "capture")
  add(selector_prompt_texts[2], "load")
  add(selector_prompt_texts[2], "unload")
  selector_prompt_texts[4] = {}
  add(selector_prompt_texts[4], "cancel")
  add(selector_prompt_texts[4], "end turn")
  selector_prompt_texts[8] = {{}, {}}  -- unit construction prompt texts filled in programmatically

  for i=1,2 do
    for unit_type in all(players_unit_types[i]) do
      -- fill in unit type construction prompt texts
      add(selector_prompt_texts[8][i], unit_type.cost .. "g: " .. unit_type.type)
    end
  end

end

function selector_update()
  -- only update selection if it's a human's turn
  if not players_human[players_turn] then return end

  -- do selector movement
  if not selector_selecting or selector_selection_type == 0 then
    selector_move()
  end

  if selector_selecting then
    -- do selecting

    -- get arrow key directional value. left or down = -1. up or right = +1
    local allow_horizontal
    if selector_selection_type == 3 or selector_selection_type == 9 then allow_horizontal = true end
    local arrow_val
    if btnp(2) or (allow_horizontal and btnp(1)) then arrow_val = 1 elseif btnp(3) or (allow_horizontal and btnp(0)) then arrow_val = -1 end

    if not btn(5) and selector_selection_type == 5 then
      -- end checking unit attack range
      selector_stop_selecting()

    elseif not btn(4) and selector_selection_type == 6 then
      -- end checking enemy unit movement
      selector_stop_selecting()

    elseif btnp4 then 
      if selector_selection_type == 0 then
        -- do unit selection
        local u_at_p = get_unit_at_pos(selector_p)
        if u_at_p and u_at_p.id ~= selector_selection.id and 
          (selector_selection.index > 2 or not (u_at_p.is_carrier and not u_at_p.carrying)) then
          -- couldn't move to position. blocked by unit
          sfx(4)
        else
          -- movement command issued
          selector_selection:move(selector_arrowed_tiles)

          selector_selection_type = 1  -- change selection type to unit movement
          return
        end
      elseif selector_selection_type == 2 then
        -- do unit selection prompt
        if selector_prompt_options[selector_prompt_selected] == 1 then
          selector_selection:complete_move()
          sfx(1)
          selector_stop_selecting()
        elseif selector_prompt_options[selector_prompt_selected] == 2 then
          selector_start_attack_selection()
        elseif selector_prompt_options[selector_prompt_selected] == 3 then
          selector_selection:capture()
          selector_stop_selecting()
        elseif selector_prompt_options[selector_prompt_selected] == 4 then
          local carrier = get_unit_at_pos(selector_selection.p, function(u) return u.is_carrier and not u.carrying end)
          selector_selection:store(carrier)
          selector_stop_selecting()
        elseif selector_prompt_options[selector_prompt_selected] == 5 then
          selector_start_unload_selection()
        end
      elseif selector_selection_type == 3 then
        -- do begin attacking

        -- set variables to be used in attack coroutine
        attack_coroutine_u1 = selector_selection
        attack_coroutine_u2 = selector_attack_targets[selector_prompt_selected]
        active_attack_coroutine = cocreate(attack_coroutine)
        selector_selection_type = 7
      elseif selector_selection_type == 4 then
        -- do menu selection prompt (end turn)

        selector_stop_selecting()
        if selector_prompt_selected == 2 then
          end_turn()
        end
      elseif selector_selection_type == 8 then
        -- do build unit at base/factory

        if players_gold[players_turn] > 0 then
          -- ensure player has gold to spend. this fixes a bug where infantry(default prompt selection) can be built when you have 0g
          selector_selection:build(selector_prompt_selected)
          selector_stop_selecting()
        end
      elseif selector_selection_type == 9 then
        selector_selection:unload(selector_unload_tiles[selector_prompt_selected])        
        selector_stop_selecting()
      end
    elseif btnp5 and selector_selection_type ~= 5 and selector_selection_type ~= 7 then
      -- stop selecting
      -- don't cancel if type is attack range selection or active attacking
      if (0 < selector_selection_type and selector_selection_type < 4) or selector_selection_type == 9 then -- if selection type is 1,2,3, or 9
        -- return unit to start location if he's moved
        sfx(5)
        selector_selection:unmove()
        selector_p = selector_selection.p
      end

      selector_stop_selecting()

    elseif selector_selection_type == 2 or selector_selection_type == 4 or selector_selection_type == 8 then
      -- do rest, unit selection and base construction prompt
      selector_update_prompt(arrow_val)
    elseif selector_selection_type == 3 then
      -- attack selection
      selector_update_prompt(arrow_val)
      selector_p = selector_attack_targets[selector_prompt_selected].p
    elseif selector_selection_type == 9 then
      -- unload carrier selection
      selector_update_prompt(arrow_val)
      selector_p = selector_unload_tiles[selector_prompt_selected]
    end

  else
    -- do not selecting

    local selection = {}
    if btnp4 then
      selection = get_selection(selector_p)
    elseif btn(5) then
      selection = get_selection(selector_p, true)
    end

    if selection[1] == 0 then
      -- do unit selection
      selector_selection = selection[2]
      if btnp4 then
        sfx(2)
        selector_selecting = true
        if selector_selection.team == players_turn_team then
          -- start unit selection
          local movable_tiles = selector_selection:get_movable_tiles()
          merge_tables(movable_tiles[1], movable_tiles[2])
          selector_movable_tiles = movable_tiles[1]
          selector_selection_type = 0
          selector_arrowed_tiles = {selector_selection.p}
        else
          -- start enemy unit selection
          selector_movable_tiles = selector_selection:get_movable_tiles()[1]
          selector_selection_type = 6
        end
      elseif btnp5 and selector_selection.ranged then
        sfx(2)
        selector_selecting = true
        selector_movable_tiles = selector_selection:ranged_attack_tiles()
        selector_selection_type = 5
      end
    elseif btnp4 and selection[1] == 1 and not get_unit_at_pos(selector_p) then
      -- do base selection
      local struct = get_struct_at_pos(selector_p, players_turn_team, nil, 3)
      if struct then
          selector_selecting = true
          selector_selection = struct
          selector_start_build_unit_prompt()
      end

    elseif btnp4 then
      -- do menu prompt
      selector_selecting = true
      selector_start_menu_prompt()
    end

  end

end

function selector_draw()
  -- only draw the selector if it's a human's turn
  local draw_prompt  -- boolean flag for if we should draw the prompt
  if players_human[players_turn] then 
    if selector_selecting then
      -- draw unit selection ui

      local flip = last_checked_time * 2 % 2  -- used in selection sprite to flip it
      if selector_selection_type == 0 or selector_selection_type == 5 or selector_selection_type == 6 then

        -- select unit

        for i, t in pairs(selector_movable_tiles) do
          if selector_selection_type == 5 then
            -- draw in red if we're in unit attack range selection
            pal(7, 8)
          end
          spr(flip + 3, t[1], t[2], 1, 1, flip > 0.5 and flip < 1.5, flip > 1)
          if selector_selection_type == 5 then
            pal()
          end
        end

        if selector_selection_type == 0 then
          -- draw movement arrow
          selector_draw_movement_arrow()
        end

      elseif selector_selection_type == 3 then
        -- draw attack prompt
        for unit in all(selector_attack_targets) do
          pal(7, 8)
          spr(flip + 3, unit.p[1], unit.p[2], 1, 1, flip > 0.5 and flip < 1.5, flip > 1)
          pal()
        end

      elseif selector_selection_type == 2 or selector_selection_type == 4 or selector_selection_type == 8 then
        -- draw rest/attack/capture unit prompt, menu prompt, and unit construction prompts
        draw_prompt = true
      elseif selector_selection_type == 7 then
        if costatus(active_attack_coroutine) == dead_str then
          selector_stop_selecting()
        else
          coresume(active_attack_coroutine)
        end
      end

    end
    
    if selector_selection_type ~= 7 and selector_selection_type ~= 8 then
      -- draw cursor if we're not fighting and we're not building units

      local frame_offset = flr(last_checked_time * 2.4 % 2)
      local offset = 8 - frame_offset * 3

      spr(frame_offset, selector_p[1], selector_p[2])
      spr(2, selector_p[1] + offset, selector_p[2] + offset)
    end
  end

  if last_checked_time % 3 > 1.5 then
    -- draw unit hp
    for u in all(units) do
      if u.hp < 10 and not u.currently_attacking then
        set_palette(u.team)
        rectfill(u.p[1] + 1, u.p[2], u.p[1] + 5, u.p[2] + 6, 8)
        print(u.hp, u.p[1] + 2, u.p[2] + 1, 0)
        pal()
      end
    end
  else
    -- draw structure capture left
    for struct in all(structures) do
      if struct.capture_left < 20 then
        local rect_offset = 0
        if struct.capture_left > 9 then
          rect_offset = 4
        end
        rectfill(struct.p[1] + 1, struct.p[2], struct.p[1] + 5 + rect_offset, struct.p[2] + 6, 6)
        print(struct.capture_left, struct.p[1] + 2, struct.p[2] + 1, 0)
      end
    end
  end

  -- draw stats/selection bar at top of screen 
  local tile = mget(selector_p[1] / 8, selector_p[2] / 8)
  local tile_info = get_tile_info(tile)
  local struct_type = tile_info[3] 
  set_palette(players_turn_team)
  local x_corner, y_corner, gold, team_name = cam.p[1], cam.p[2], players_gold[players_turn], players_turn_team
  if last_checked_time % 4 < 2 then team_name = players_co_name[players_turn] end
  if gold < 10 then gold = "0" .. gold end
  rectfill(x_corner, y_corner, x_corner + 81, y_corner + 19, 8)  -- background
  rectfill(x_corner + 1, y_corner + 1, x_corner + 18, y_corner + 18, 0)  -- portrait border
  rectfill(x_corner + 17, y_corner + 1, x_corner + 26, y_corner + 9, 0)  -- team icon border
  line(x_corner, y_corner + 20, x_corner + 80, y_corner + 20, 2)  -- background
  rectfill(x_corner + 114, y_corner, x_corner + 128, y_corner + 7, 2)  -- player's gold border
  rectfill(x_corner + 115, y_corner, x_corner + 128, y_corner + 6, 8) -- players' gold background
  print(gold .. "g", x_corner + 116, y_corner + 1, 7 + (flr((last_checked_time*2 % 2)) * 3)) -- player's gold
  pal()
  print(team_name, x_corner + 29, y_corner + 3, 0) -- team name
  print(tile_info[1], x_corner + 30, y_corner + 12, 0) -- tile name and defense
  spr(players_co_icon[players_turn], x_corner + 2, y_corner + 2, 2, 2)  -- portrait
  spr(team_icon[players_turn], x_corner + 19, y_corner + 2, 1, 1)  -- icon

  -- draw structure capture leftover
  local struct = get_struct_at_pos(selector_p)
  if struct then
    -- change sprite to uncaptured structure so we don't draw their colors wrong
    local type_to_sprite_map = {28, 29, 30}
    tile = type_to_sprite_map[struct_type]
    rectfill(x_corner + 71, y_corner + 11, x_corner + 79, y_corner + 17, 0)  -- team icon border
    local capture_left = struct.capture_left
    if struct.capture_left < 10 then capture_left = "0" .. struct.capture_left end
    print(capture_left, x_corner + 72, y_corner + 12, 7 + (flr((last_checked_time*2 % 2)) * 3)) -- capture left
  end
  spr(tile, x_corner + 20, y_corner + 11, 1, 1)  -- tile sprite

  if draw_prompt then
    -- draw the prompt if the above flag was set
    -- we draw it last so other things don't get drawn over it
    selector_draw_prompt()
  end

end

function selector_stop_selecting()
  selector_selecting = false
  selector_selection = nil
  selector_selection_type = nil
  selector_movable_tiles = {}
  selector_arrowed_tiles = {}
  selector_prompt_options = {}
  selector_prompt_options_disabled = {}
  selector_prompt_title = nil
end 

function selector_start_unit_prompt()
  selector_selection_type = 2

  selector_prompt_options = {1}  -- rest is in options by default

  -- store the attack targets
  selector_attack_targets = selector_selection:targets()
  if #selector_attack_targets > 0 and (not selector_selection.ranged or not selector_selection.has_moved) then 
    -- add attack to the prompt if we have targets
    add(selector_prompt_options, 2)
  end

  local struct = get_struct_at_pos(selector_selection.p, nil, players_turn_team)
  if struct and selector_selection.index < 3 then
    -- ensure we're an infantry or mech with `selector_selection.index < 3`
    -- if we're on a structure that isn't ours and we're an infantry or a mech then add capture to prompt
    add(selector_prompt_options, 3)
  end

  if selector_selection.carrying then
    -- unload
    add(selector_prompt_options, 5)
  end

  local u = get_unit_at_pos(selector_selection.p, function(u) return u.is_carrier and not u.carrying end)
  if u and selector_selection.index < 3 then
    -- ensure we're an infantry or mech with `selector_selection.index < 3`
    -- offer loading as the only option
    selector_prompt_options = {4}
  end

  selector_prompt_selected = #selector_prompt_options
end

function selector_start_build_unit_prompt()
  selector_selection_type = 8

  selector_prompt_options = {}
  selector_prompt_title = "total gold: " .. players_gold[players_turn]

  for i, unit_type in pairs(players_unit_types[players_turn]) do
    if players_gold[players_turn] >= unit_type.cost then
      add(selector_prompt_options, unit_type.index)
    else
      add(selector_prompt_options_disabled, unit_type.index)
    end
  end

  selector_prompt_selected = 1
  sfx(6)
end

function selector_start_menu_prompt()
  selector_selection_type = 4

  selector_prompt_options = {1,2}  -- end turn in options by default
  selector_prompt_selected = 1

  sfx(6)
end

function selector_start_attack_selection()
  selector_selection_type = 3
  selector_prompt_options = {}

  for i = 1, #selector_attack_targets do
    add(selector_prompt_options, i)
  end
  selector_prompt_selected = 1

  sfx(6)
end

function selector_start_unload_selection()
  selector_selection_type = 9
  selector_prompt_options = {}
  selector_unload_tiles = {}

  for i, t in pairs(get_tile_adjacents(selector_selection.p)) do
    if selector_selection.carrying:tile_mobility(mget(t[1] / 8, t[2] / 8)) < 255 and not get_unit_at_pos(t) then
      add(selector_prompt_options, i)
      add(selector_unload_tiles, t)
    end
  end
  selector_prompt_selected = 1

  sfx(6)
end

function selector_draw_prompt()
  local y_offset, prompt_text = 15
  if selector_selection_type == 8 then y_offset = -25 end
  for i, prompt in pairs(selector_prompt_options) do
    local bg_color = 6
    prompt_text = selector_prompt_texts[selector_selection_type][prompt]

    if selector_selection_type == 8 then
      -- select player-specific prompt for unit production
      prompt_text = selector_prompt_texts[selector_selection_type][players_turn][prompt]
    end
    if i == selector_prompt_selected then 
      bg_color = 14
      prompt_text ..= "!"
    end

    draw_msg({selector_p[1], selector_p[2] - y_offset}, prompt_text, bg_color, bg_color == 14)
    y_offset += 9
  end
  for disabled_prompt in all(selector_prompt_options_disabled) do
    prompt_text = selector_prompt_texts[selector_selection_type][disabled_prompt]
    if selector_selection_type == 8 then
      -- select player-specific prompt for unit production
      prompt_text = selector_prompt_texts[selector_selection_type][players_turn][disabled_prompt]
    end
    draw_msg({selector_p[1], selector_p[2] - y_offset}, prompt_text, 8)
    y_offset += 9
  end
  if selector_prompt_title then

    draw_msg({selector_p[1], selector_p[2] - y_offset}, selector_prompt_title, 10)
  end
end

function selector_update_prompt(change_val)
  if not change_val then return end

  selector_prompt_selected = (selector_prompt_selected + change_val) % #selector_prompt_options
  if selector_prompt_selected < 1 then selector_prompt_selected = #selector_prompt_options end
  if #selector_prompt_options > 1 then
    sfx(6)
  end
end

function selector_move()
  selector_time_since_last_move += delta_time

  -- get x and y change as a vector from controls input
  local change = selector_get_move_input()

  -- move to the position based on input
  -- don't move if we're in any prompt selection_type
  if selector_time_since_last_move > 0.1 then
    if change[1] and change[2] then
      -- if both inputs are down, perform move twice, once for x, once for y
      local move_result = selector_move_to(change[1], 0)
      if move_result then
        selector_move_to(0, change[2])
      end
    elseif change[1] then
      -- move x
      selector_move_to(change[1], 0)
    elseif change[2] then
      -- move y
      selector_move_to(0, change[2])
    end
  end

end

function selector_get_move_input()
  local x_change, y_change
  if btn(0) then x_change = -8 end
  if btn(1) then x_change = 8 end
  if btn(2) then y_change = -8 end
  if btn(3) then y_change = 8 end
  return {x_change, y_change}
end

function selector_move_to(change_x, change_y)
  -- moves the selector to a specific location
  -- returns true on successful cursor movement

  local new_p = {selector_p[1] + change_x, selector_p[2] + change_y}
  local in_bounds = point_in_rect(new_p, {current_map.r[1]*8, current_map.r[2]*8, current_map.r[3]*8, current_map.r[4]*8})

  if selector_selecting and selector_selection_type == 0 then
    -- if we're selecting a unit, keep selector bounded by unit's mobility
    in_bounds = in_bounds and point_in_table(new_p, selector_movable_tiles)
  end

  if in_bounds then
    selector_p = new_p

    if selector_selecting and selector_selection_type == 0 then
      -- if we crossover our arrow, delete all points in the arrow after the crossover
      local point_i = point_in_table(new_p, selector_arrowed_tiles)
      if point_i then
        local new_arrowed_tiles = {}
        for i = 1, point_i - 1 do
          new_arrowed_tiles[i] = selector_arrowed_tiles[i]
        end
        selector_arrowed_tiles = new_arrowed_tiles
      end

      -- add tile to the arrowed tiles list
      add(selector_arrowed_tiles, new_p)

    end

    selector_time_since_last_move = 0
    sfx(0)
    return true
  end
end

function selector_draw_movement_arrow()
  -- draws a movement arrow during unit selection
  -- directions = n: 0, s: 1, e: 2, w: 3
  local last_p = selector_arrowed_tiles[1]
  local last_p_direction, next_p, next_p_direction, current_p, opposite_directions, sprite, flip_x, flip_y

  local arrowhead, arrowhead_l, vertical, horizontal, curve_w_n, curve_n_e, curve_n_w, flip_horizontal = 90, 91, 89, 106, 123, 121, 105

  for i = 2, #selector_arrowed_tiles do
    flip_x, flip_y, sprite, next_p = nil

    current_p = selector_arrowed_tiles[i]
    if last_p[2] < current_p[2] then last_p_direction = 0 
    elseif last_p[2] > current_p[2] then last_p_direction = 1 
    elseif last_p[1] > current_p[1] then last_p_direction = 2 
    elseif last_p[1] < current_p[1] then last_p_direction = 3 
    end
    next_p = selector_arrowed_tiles[i+1]
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

    spr(sprite, current_p[1], current_p[2], 1, 1, flip_x, flip_y)

    last_p = current_p

  end
end

function make_war_map(r)
  war_map = {}

  -- rect of bounds
  war_map.r = r

  war_map.draw = function(self)
    -- fill background in with patterns
    local x, y, w, h = self.r[1]*8, self.r[2]*8, self.r[3]*8, self.r[4]*8
    fill_color = 0b00010000 | map_bg_color  -- bitwise or
    fillp(0b1111011111111101)
    rectfill(x-38, y-38, x+w+45, y+h+45, fill_color)
    fillp(0b1011111010111110)
    rectfill(x-30, y-30, x+w+37, y+h+37, fill_color)
    fillp(0b0101101001011010)
    rectfill(x-24, y-24, x+w+29, y+h+29, fill_color)
    fillp(0b0100000101000001)
    rectfill(x-16, y-16, x+w+23, y+h+23, fill_color)
    fillp(0)
    -- fill with map bgcolor
    rectfill(x-8, y-8, x+w+15, y+h+15, map_bg_color)

    -- draw map tiles
    map(self.r[1], self.r[2], self.r[1] * 8, self.r[2] * 8, self.r[3] + 1, self.r[4] + 1)
  end

  war_map.load = function(self)
    -- set global structures to contain all structures
    structures = {}
    for tile_y = self.r[2], self.r[2] + self.r[4]  do
      for tile_x = self.r[1], self.r[1] + self.r[3] do
        local tile_info = get_tile_info(mget(tile_x, tile_y))
        if tile_info[3] then
          -- create structure of whatever type this tile is, and owned by whatever player owns this struct(if any)
          add(structures, make_structure(tile_info[3], {tile_x * 8, tile_y * 8}, tile_info[4]))
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
  struct.type, struct.p, struct.team, struct.capture_left = struct_type, p, team, 20

  -- set structure sprite based on the structure type
  local struct_sprite
  if struct_type == 1 then 
    struct_sprite = 64
    players_hqs[players_reversed[team]] = struct  -- add this hq to the list of hqs
    if team == players[1] then
      selector_p = p
    end
  elseif struct_type == 2 then struct_sprite = 65
  else struct_sprite = 66 end

  -- components
  local active_animator
  if not team then 
    -- set palette to unowned if we have no team (5 magic number for unowned)
    team = 5 
    active_animator = false
  end
  struct.animator = make_animator(struct, 0.4, struct_sprite, -58, team, {0, -3}, nil, active_animator)

  struct.draw = function(self)
    rectfill(self.p[1], self.p[2], self.p[1] + 7, self.p[2] + 7, 3)
    self.animator:draw()
  end

  struct.capture = function(self, unit)
    self.capture_left -= unit.hp + unit.capture_bonus
    if self.capture_left <= 0 then
      sfx(10)
      self.team = unit.team
      self.animator.palette = unit.team
      self.animator.animation_flag = true
      self.capture_left = 20
      if self.type == 1 then
        end_game(players_turn)
      end
    else
      sfx(9)
    end
  end

  struct.build = function(self, unit_type_index)
    sfx(11)
    local new_unit = make_unit(unit_type_index, {self.p[1], self.p[2]}, players_turn_team)
    players_gold[players_turn] -= new_unit.cost
    new_unit.is_resting = true
    players_units_built[players_turn] += 1
    add(units, new_unit)
  end

  return struct

end

function make_unit(unit_type_index, p, team)
  local unit = {}

  -- inherit all properties from unit_type
  local unit_type = players_unit_types[players_reversed[team]][unit_type_index]
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

  -- active flag is used by the ai so that we don't do ai twice for a dead unit
  unit.active = true

  -- points to move to one at a time
  -- unit.cached_p = {}
  unit.movement_points = {}
  unit.cached_sprite = unit.sprite -- cached sprite that we can revert to after changing it

  -- components
  unit.animator = make_animator(
    unit,
    unit.cached_animator_fps,
    unit.sprite,
    64,
    team,
    {0, -1},
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

  unit.get_movable_tiles = function(self, add_enemy_units_to_return)
    -- returns two tables
    -- the first table has all of the tiles this unit can move to. this is the only one the ai wants.
    -- the second table is the rest of the tiles they could move to if their own units weren't occupying them. 

    local tiles_to_explore = {{self.p, self.travel}}  -- store the {point, travel leftover}
    -- explore_i: index in tiles_to_explore of what we've explored so far
    local movable_tiles, tiles_with_our_units, explore_i, current_tile = {}, {}, 0

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
        local u = get_unit_at_pos(current_t)
        if not u or (self.index < 3 and u.is_carrier and not u.carrying) then
          -- add the tile to the list if there's no unit there or we can load into the unit
          add(movable_tiles, current_t)
        else
          add(tiles_with_our_units, current_t)
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

  unit.store = function(self, carrier)
    self.active = false
    self.p = {-32767, -32767} -- hide unit off camera
    self:complete_move() -- rest
    sfx(21)
    carrier.carrying = self
  end

  unit.unload = function(self, p)
    self.carrying.active = true
    self.carrying.is_resting = true
    self:complete_move() -- rest
    self.carrying.p = p
    sfx(21)
    self.carrying = nil
  end

  unit.move = function(self, points)
    self.cached_p = copy_v(self.p)
    self.is_moving = true
    self.movement_i = 1
    self.movement_points = points
    self.animator.fps = 0.1

    -- used by selector to return unit to starting point by pressing btn(5)
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

      if debug then
        self.p[1] += x_change*8
        self.p[2] += y_change*8
      else
        self.p[1] += x_change
        self.p[2] += y_change
      end

    else
      -- no more points left. stop moving
      if players_human[players_turn] then
        selector_start_unit_prompt()  -- change to select type unit prompt
      end

      self:cleanup_move()
    end

  end

  unit.complete_move = function(self)
    self.is_resting = true

    -- reset capture on structure if we're leaving it
    if self.cached_p and not points_equal(self.p, self.cached_p) then
      local struct = get_struct_at_pos(self.cached_p)
      if struct and self.index < 3 then
        struct.capture_left = 20
      end
    end

    self.cached_p = nil
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

  unit.capture = function(self)
    for struct in all(structures) do
      if points_equal(struct.p, self.p) then
        struct:capture(self)
        self:complete_move() -- rest
        break
      end
    end
  end

  unit.kill = function(self)
    sfx(8)

    -- uncapture struct at position
    local struct = get_struct_at_pos(self.p)
    if struct then
      struct.capture_left = 20
    end

    self.active = false
    players_units_lost[players_reversed[unit.team]] += 1
    del(units, self)
  end

  unit.tile_mobility = function(self, tile)
    -- returns the mobility cost for traversing a tile for the unit's mobility type
    if fget(tile, 0) then
      if fget(tile, 1) then return 1
      elseif fget(tile, 6) then
        if self.mobility_type == 2 then return 2
        else return 1 end
      elseif fget(tile, 3) then
        if self.mobility_type == 2 then return 3
        elseif self.mobility_type == 3 then return 2
        else return 1 end
      elseif fget(tile, 4) or fget(tile, 2) then
        if self.mobility_type == 0 then return 2
        elseif self.mobility_type == 1 then return 1
        end
      end
    elseif fget(tile, 1) then return 1 end
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
    elseif self.is_carrier then
      return {}
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
    return flr(self.damage_chart[u2.index] * 1.25 * max(0, our_life) / 10 * tile_defense + rnd(self.luck_max))
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

    local animation_frame
    if self.animation_flag then
      animation_frame = self.sprite + self.sprite_offset * self.animation_frame
    else
      animation_frame = self.sprite
    end

    -- draw sprite
    if(self.palette) then
      set_palette(self.palette)
    end

    if self.draw_shadow then
      -- draw shadow
      sprite_color = 0
      if self.parent.carrying then sprite_color = 15 end
      outline_sprite(animation_frame, sprite_color, self.parent.p[1] + self.draw_offset[1], self.parent.p[2] + self.draw_offset[2], self.flip_sprite, self.palette)
    else
      -- draw sprite normally
      spr(animation_frame, parent.p[1] + self.draw_offset[1], parent.p[2] + self.draw_offset[2], 1, 1, self.flip_sprite)
    end

    pal()

  end

  return animator

end

-- save/loading data functions
function peek_increment()
  local v = @memory_i  --peek
  memory_i += 1
  return v
end

function poke_increment(poke_value)
  poke(memory_i, poke_value)
  memory_i += 1
end

function load_string(n)
  -- reads a string from memory and increments the memory_i counter by its length
  local str = ""
  for i = 1, n do
    local charcode_val = chr(peek_increment())
    str ..= charcode_val
  end
  -- i don't know what this returns, but it's not a string. that's fine. it works. 
  return str
end

function load_assets()

  -- load all 8 unit types for players 1 and 2
  for i=1, 2 do

    -- load player data
    players_human[i] = peek_increment() == 1
    players_co_name[i] = load_string(10)
    players[i] = team_index_to_palette[peek_increment()]
    players_co_icon[i] = peek_increment()
    team_icon[i] = peek_increment()
    players_music[i] = peek_increment()

    for j=1, 8 do
      -- load unit data
      local u = {}
      u.index = peek_increment()
      u.type = load_string(10)
      u.sprite = peek_increment()
      u.mobility_type = peek_increment()
      u.travel = peek_increment()
      u.cost = peek_increment()
      u.range_min = peek_increment()
      u.range_max = peek_increment()
      u.ranged = u.range_min > 0  -- add helper variable to determine if unit is ranged
      u.luck_max = peek_increment()
      u.capture_bonus = peek_increment()
      u.struct_heal_bonus = %memory_i  -- peek2
      memory_i += 2
      u.ai_unit_ratio = peek_increment()
      u.moveout_sfx = peek_increment()
      u.combat_sfx = peek_increment()
      u.is_carrier = peek_increment() == 1

      u.damage_chart = {}
      for k=1, 8 do
        local v = peek4(memory_i)
        memory_i += 4  -- value is 4byte float. increment by 4

        add(u.damage_chart, v)
      end

      add(players_unit_types[i], u)
    end
  end

  players_reversed = {}  -- create a global reverse index for getting player index by team
  players_reversed[players[1]] = 1
  players_reversed[players[2]] = 2

  -- loads war map
  current_map = make_war_map({peek_increment(), peek_increment(), peek_increment(), peek_increment()})
  map_bg_color = peek_increment()

  -- load map data from external source
  if peek_increment() == 1 then
    reload(0x2000, 0x2000, 0x1000, 'loader.p8')
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
  return p[1] >= r[1] and p[1] <= r[1] + r[3] and p[2] >= r[2] and p[2] <= r[2] + r[4]
end

-- table functions
function sort_table_by_f(a, f)
  for i=1,#a do
    local j = i
      while j > 1 and f(a[j-1], a[j]) do
        a[j],a[j-1] = a[j-1],a[j]
        j = j - 1
      end
  end
end

function point_in_table(p, t, keys)
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
  return 32767
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
  pal()
  -- draw final sprite
  set_palette(sprite_palette)
  spr(n,x,y,1,1,flip_x,flip_y) 
  pal()
end

function draw_msg(center_pos, msg, bg_color, draw_bar)
  msg_length = #msg

  local x_pos = center_pos[1] + 5 - msg_length * 4 / 2 
  local y_pos = center_pos[2]

  rectfill(
    x_pos - 2,
    y_pos - 2,
    x_pos + msg_length * 4 ,
    y_pos + 5,
    bg_color)
  
  if draw_bar then
    line(
      x_pos - 2,
      y_pos + 5,
      x_pos + msg_length * 4,
      y_pos + 5,
      2)
  end

  -- draw message
  print(msg, x_pos, y_pos - 1, 0)
end

function get_tile_adjacents(p)
    return {{p[1], p[2] - 8},
     {p[1], p[2] + 8},
     {p[1] + 8, p[2]},
     {p[1] - 8, p[2]}}
end

function get_tile_info(tile)
  -- returns the {tile name, its defense, its structure type(if applicable), and its team(if applicable)}
  if fget(tile, 1) then
    local team
    if fget(tile, 6) then team = players[1] elseif fget(tile, 7) then team = players[2] end
    if fget(tile, 2) then return {"hq★★★★", 0.6, 1, team}
    elseif fget(tile, 3) then return {"city★★", 0.7, 2, team}
    elseif fget(tile, 4) then return {"base★★", 0.7, 3, team}
    end
  end
  if fget(tile, 0) then
    if fget(tile, 1) then return {"road", 1.0}
    elseif fget(tile, 2) then return {"river", 1.0}
    elseif fget(tile, 3) then return {"wood★★", 0.7}
    elseif fget(tile, 4) then return {"mntn★★★★", 0.4}
    elseif fget(tile, 5) then return {"cliff", 1.0}
    elseif fget(tile, 6) then return {"plain★", 0.85}
    end
  end
  return {"unmovable", 0} -- no info
end

-- priority queue code
-- edited from: https://github.com/roblox/wiki-lua-libraries/blob/master/standardlibraries/priorityqueue.lua
prioqueue = {}
prioqueue.__index = prioqueue

function prioqueue.new()
  newqueue = {}
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
  local minindex
  local lcindex = index*2
  local rcindex = index*2+1
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
7700007700000000777770000000000000000000666766630029920000222200000000000000004400000000220000000000000000f00000566666555ccccc63
700000070770077075500000007000700707070756666655022222200072720000000002000000440000000022000000000000000f4400f0c66666cc5c5c5c66
0000000007000070756700000707070700700070c66666cc0279972099922999002200220000004400000000220000000000000072427f425667665c66666666
00000000000000007056700000700070070707075667665c0299992097927979022902290000004400000000220000000000000007270722c66766cc66666666
0000000000000000700567000000000000000000c66766cc22222222999229992299229900000044000000002200000000dddd00007f40775666665c66776677
00000000070000700000565000700070070707075666665c2797979297927979979797970000004400000000220000000ddddd5007244270c66666cc66666666
7000000707700770000005500707070700700070c66666cc2999999299922999999999990000044400000000222000000ddddd50007227006667666666666666
7700007700000000000000000070007007070707666766662797979299922999979797974444444344444444324444440d55555000077000666766635c5c5c66
088888000888888000000000000000002222220000021000000210000000000008888800555555530000000035555555006dd500005555000000000033b33b33
899999808999999800998000009880002999820000222000002220210229999089997980222244450000000052222222065555500d7575d0000000053bbb5bb3
899999988999999809997800099278002992785502220000022202229999979089999798222222440000000022222222067dd750ddd55ddd005500553bb5bb53
22222220222222200999185599921855299218552220287022222978999991908999979822222244000000002222222206dddd50d7d57d7d055d055dbb5b5bb5
ffff1f00788f1f770999990099999955299999552280281822299918999999108889997700000244000000002220000065555555ddd55ddd55dd55dd3b5bbb53
088fff70788fff752229222022222220222222202222222222299222222222207888887500000044000000002200000067d7d7d5d7d57d7dd7d7d7d7bbb5bbb5
0287777772888877292829202898989228989892289898922928829228989892728888770000004400000000220000006dddddd5ddd55ddddddddddd33433433
08008000020020002220222002222220022222200222222022200222022222200200200000000044000000042200000067d7d7d5ddd55dddd7d7d7d733333333
088888000888888000000000000000000022220000010000222002220000000000888880000000440000000022000000336666666666666666666333333ff333
89999980689999980000000000000000029999200022200022200222009229006788888800000044000000002200000036666666666666666666663333f44233
88888888899999990099900000999900029999200022200022200222099229907788888800000044000000002200000066666666666666666666666333f44233
f22222f088888888099999000999999002999920028282002229922209999990777888880000004400000000220000006666667766776677667666633f444223
0888887077722220099999002999999222999922022222002229922229999992777888800000004400000000220000006666666666666666666766633f442423
0888887076788888289998208299992882999928282228202229922282999928767888880000004400000000220000006667666666666666666666633f424423
022222006662882082999280282992822829928282828280289999822829928266628820000000440000000022000000666766666666666666676663b4b4b24b
0800000000200000282028208289982882822828282028208280082882899828002000000000004440000000220000006666666333333333666766633bbbbbb3
08888800088888870000000000000000022222200021200022200222000000000888887700000044555555552200000066666663333333336666666366666663
89999980899999870088800000888800298998920022200021200212009999008999798700000044222222222200000066666666666666666666666366666663
89999998899999980878780008788780297887920022200022299222097997908999978600000042222222222200000066676666666666666667666366676663
22222220222222260918190008199180291881920278720022788722091991908999998600000002222222222000000066676666666666666667666366676663
ff1ff1f08f1f17770995990029555592295555920818180009188190299999928999977700000000000000000000000066667677667766776676666366666663
0fffff7008fff7572895982082555528825115282222222082999928829119280888875700000000000000000000000066666666666666666666666366666663
02877777028886668299928028299282285555828299928028988982282992820288866600000000000000000000000036666666666666666666663366676663
08000000020000002820282082899828828998282820282082000028828998280200000000000000000000000000000033666666666666666666633366676663
00299200002222000000000000000000006cc100001111000000000000000000000000007008800780088008a008800a05555550000550000055550000055000
02222220008282000000000200000000061111100061610000000001000000000700007008888880008998000089980055555555055555500550055005000050
02899820999229990022002200222200066cc610ccc11ccc00110011000000000088880008799780089aa9800895598055555555555005550000000000000000
0299992098928989022902290299992006cccc10c6c16c6c011c011c0008700000879800889aa98889a00a988950059855555555050000500000000000000000
2222222299922999229922992999999261111111ccc11ccc11cc11cc0007800000897800889aa98889a00a988950059805000050000000000000000000000000
2898989298928989989898980299992066c6c6c1c6c16c6cc6c6c6c6000000000088880008799780089aa9800890098009000090009000000000080000000000
299999929992299999999999002222006cccccc1ccc11ccccccccccc000000000700007008888880008998000089980008900080000000900800000000000000
2898989299922999989898980029920066c6c6c1ccc11cccc6c6c6c600000000000000007008800780088008a008800a00809800080000000090000000000000
0000000000000000000000000000000022222200002100000000000000000000000000000088800000888000000080002200000000000044000000005ccccc65
088888000888888000000000009880002999820002220000000210000229999008888800008880000088800000088000cc00000000000044000000002ccccc22
899999808999999800998000099278002992785522200000002220219999979089997980008880000088800000888888cc000000000000cc000000002ccccc22
899999988999999809997800999218552992185522002870222229789999919089999798008880008888888008888888cc000000000000cc000000002ccccc22
222222202222222009991855999999552999995522802818222299189999991089999798008880000888880000888888cc000000000000cc0000000000000000
ffff1f00788f1f7722292220222222202222222022222222222992222222222088899977008880000088800000088000cc000000000000cc0000000000000000
088fff70788fff752929292029898982298989822989898222288292298989827888887500888000000800000000800022000000000000cc0000000000000000
02877777728888772228222002222220022222200222222022200222022222207288887700888000000000000000000022000000000000445ccccc6400000000
08888800088888800000000000000000002222000001000022200222000000000088888000000000000000000000000033555555555555555555533333333333
89999980689999980000000000000000029999200022200022200222009229006788888800000000000000000000000035ccccccccccccccccccc63333333333
8888888889999999009990000099990002999920002220002220022209922990778888880000088888888888888000005ccccccccccccccccccccc6333333333
f22222f088888888099999000999999002999920028282002229922209999990777888880000888888888888888800005ccccccccccccccccccccc6333333333
0888887077722220099999008999999882999928022222002229922289999998777888800008888888888888888880005ccccccccccccccccccccc6333333333
0888887076788888829992802899998228999982822222802229922228999982767888880008888000000000088880005ccccccccccccccccccccc6333333333
0222220066628828289998208289982882899828282228208299992882899828666288280008880000000000008880005cccccc666666666cccccc6333333333
0000080000000020828082802829928228222282828082802820028228299282000000200008880000000000008880005ccccc63333333335ccccc6333333333
0888880008888887000000000000000002222220002120002220022200000000088888770008880000000000008880005ccccc63333333335ccccc635ccccc63
8999998089999987008880000088880029899892002220002120021200999900899979870008888000000000088880005cccccc555555555cccccc635ccccc63
8999999889999998087878000878878029788792002220002229922209799790899997860008888888888888888880005ccccccccccccccccccccc635ccccc63
2222222022222226091819000819918029188192027872002278872209199190899999860000888888888888888800005ccccccccccccccccccccc635ccccc63
ff1ff1f08f1f1777099599008955559829555592081818000918819089999998899997770000088888888888888000005ccccccccccccccccccccc635ccccc63
0fffff7008fff757829592802855558228511582822222802899998228911982088887570000000000000000000000006ccccccccccccccccccccc635ccccc63
02877777028886662899982082899828825555282899982082988928828998280288866600000000000000000000000036ccccccccccccccccccc6335ccccc63
0000800000002000828082802829928228299282828082802800008228299282000020000000000000000000000000003366666666666666666663335ccccc63
0092f6c6d6e0e0d6d6e7f3b200d00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
d092f6f7d1f3f3d1f6d1f3b200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0092f6c7d6e0e0d6e6f1f3b200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0092f6f6d1f3f3c6e7f1f3b200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0092f6c6d6e0e0e7f1d1f3b20000d000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0092f6c7e6f3c3d3d3d3e3b20000d000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0092d1c6e7f3e1f6f6f6f6b200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00d5d7e7d1f3f6f6f6f1f6b200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0092f6f6f6f3d1f6f1f6f6b200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
009224f6f1f3f6f1f6f6f2b200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
d092f104d3e3d1f6f6f6d1b200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0092f1f124f6f6f6f2d1f2b2d0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0093a3a3a3a3a3a3a3a3a3b300000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
d0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000d000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000d00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
888888803333333000005000000500000000500000050000000002333333333200000222222220000000000ff000000255500000000000050011111111111100
899999803bbbbb300005750000575000000575000057500000002333333333330002277ffffff200000000faafff22025570000000000070011c111111111111
899899803b333b30000565555566d500000565555566d500000233333333333300277fffffffff2000fffffaaaaaf222500707077700700011c1c11111111111
898989803b333b30000566666666d500000566666666d5000006333333333333027ffffffffffff200ffaaaaa0aaa2220000000000000000111c111111111444
899899803b343b30005676666676d500005676666676d500002666fff333366302222fff2222fff200faaaaa080aaa22000fffffffff00001111111111449494
899999803bb4bb30005606666606d500005606666606d500002f666ffff66663029492f294942ff20faaaaaa000aaa220022ffffff22f0001111111fffff4949
8888888033333330005665656566d500005665656566d50002fff66fff66663302222fff22224ff20faa000aaaa4aa2202662f22f2662f08411112fff222f442
00000000000000000056665656949490005666565694949002f00fffff66ff630226cfff2c66f2f20faa080aaaa4aa220274688f267428804426742f26742442
11111110222222200005566666494940000556666649494002fff0f2f00ffff6022712ff2172fff200f20004444aaa2208898f2828898ff04f2649fff6492422
1dcdcd102aaeaa200555556655a5a5a00555556655a5a5a02fffff2ffff0fff602f22f2ff22ffff202f22a44aaaaaaf28f282f2f8228fff04ff222fff222f422
1cdddc102aeeea205666666566ada5a05666666566ada5a02fffff2fffffffff02ffff2ffffff8f20022aaaaaaaffff28ff8ff2f8ff8ffff4ffffffffffff424
1ddddd102eaeae2056d555656da5a5a056d555656da5a5a02fffffffffffffff02ffff2fffff8f202022aaaaaff22002588fff22f88fffff4ffffff2fffff424
1cdddc102aaeaa2005500567557dd50005500567557dd50002fff22222f2fff302fffffffff8f2000222faaaff2222025ffffffffffffff54ffffffffffff424
1dcdcd102aeaea2000000567777dd50000000567777dd500002fffffffffff6302fff220ff8f2200022220000002222255ffffffffffff5540ffffffff2ff400
111111102222222000000567777dd50000000567777dd50000022ffffffff32300ffffffffff2200220222222222222255ffff222ffff255400fff2222fff400
000000000000000000000567777dd50000000567777dd500000002222222230300222222222222000000000000022222555fffffffff225540000ffffff00400
000000000000000000000567777dd500000dddddddd0d0d0000002333333333200eeeeeeeeeeeee0000333333333333300111111111111000088888888888000
000000000000000000000567777dd5000ddddddddddddd0000002333333333330eeee7eeeeeeeeee033333333333337301111111111111100288888888888880
000000000000000000000567777dd500dd7ddddddddd7ddd0002333333333333ee77eeeeeee222ee073333333333373001111111111111112888888888828878
000000000000000000000567777dd5000dd77ddd7dddddd00006333333333333e77e22f2eeefff2e337333333333333011111155555555518788881118882788
000000000000000000000567777dd500ddddd1d1d1dd1d1d002666fff3333663e7eefff2eeeffffe3333733333733333111555ccccccccc58878113331888288
000000000000000000000567777dd500ddd1d111111d11d1002f066fff066663eeeef0f22eef0ffeb33bfffb333bbbbb115cc1111ccc111c8881333333188828
000000000000000000000567777dd500ddd111f11f11f11d02ff006fff666633e7ef00ff2ee000feb3f2222fbb322f2015ccf222ffff222f8813222ffff28882
000000000000000000000567777dd500dd110000ff00001102f000fff000ff63ee2f070f2ef070fef2ff2222ffb222205c2f27772ff2777282226722ff262888
000000000000000000000567777dd500ff1f222ffff22f1102f070f2f070fff6ee2f070f2ef000feff2226422222462012f267172ff271728227707fff707288
000000000000000000000567777dd500ff1f27d2ff2d72102ff0002ff000f2f6ee2f000fffff0f2effff27a2fff2a7202fff26772ff267722ff20c7fff0c6228
000000000000000000000567777dd500ffff2717ff2172002ff00f2ff000f2ffee2ff0ffffff0f2e2fff2222fff2222012fff212ffff222fffff222fff222ff8
000000000000000000000567777dd50011fff222fff22f002fff0fffff0ff2ff0e2fff222222f2e02ffffffff22fff20002fffffffff2ff02ffffffff2fffff2
000000000000000000000567777dd500011ffffff22fff0002ffffffff0ffff30ee2ffeeeeeff2e002ff2fffffffff200002ffffff22fff022ffffffffffff22
000000000000000000000567777dd5000002fffffffff200002ffff22222ff6300ee20ffffff002e002ffff2222fff2000002fffffffff00002ffffffffff222
000000000000000000000567777dd50000002fff222ff00000022ffeeeeff323000e2000099fffa000222ffffffff200000222ff1222f0000002fff222ff2222
000000000000000000000567777dd500000002ffffff2000000002222222230300002aafffffffaf02222222222220000022222ffffff200000002ffff202020
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
00000000000300000021212100210303000000000000000000212121060a12090000000000000000002121210303031100000000000000000021212103030303464a5200868a92000000000000000000000000000000000000000000212121210000000000000000000000000505054100000000000000000000000005050505
0002000000000202000000000000000500000000000000000002020000000200010000000002000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__map__
0d000000000000000000000000000d2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f0000000000000d0000000000000000000000000d0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000d0000002f1f1f1f6f6f6f1f1f6f6f6f1f1f1f2f00000d0000000000000000000d0000000000000000000d0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00001a0a0a0a0a0a0a5e0a0a2a00002f1f422d2d1d2d2d2d2d2d2d2d1d1f2f0000001a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a2a000d0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000291d6f6f6f6f6f7f1f1f2b00002f1f1f1f6f6f6f1f1f6f6f6f1f3f1f2f000000296f2f6f6f6f6f6f6f6f6f2f2f2f6f6f6f6f6f6f2b00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000296f40426f6f6f7f1e1f2b00002f2f2f2f2f2f2f1f2f2f2f2f1f3f1f2f000000292f6f6f6f6f6f1f1f1f1f2f2f2f6f6f1d1d1d6f2b00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000296f6f3f6f6f6f7f1f1f2b00002f1f1f1f6f6f6f1f1f6f6f6f1f3f1f2f000000296f402d2d2d2d2d2d2e1f2f2f2f6f6f1d1f1d6f2b00000d00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00005d7d7d057d7d7d7e1f1f2b00002f1f402d2d2d2d2d2d2d2d2d2d441f2f000000292f6f6f6f6f6f426f3f1f2f2f2f6f6f1d1d1d6f2b00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000296f6f3f6f6f6f6f6f6f2b00002f1f3f1f6f6f6f1f1f6f6f6f1f1f1f2f000000296f2f6f6f6f6f6f6f3f1f2f2f2f6f6f3f6f6f6f2b000d0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000296f6f1d2d2d2d1d2e6f2b00002f1f3f1f2f2f2f2f1f2f2f2f2f2f2f2f00000d393a196f6f1f1f6f6f3f1f2f2f2f6f1f3f1f1b3a3b00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0d00292f2f2f2f2f2f1f3f6f2b000d2f1f3f1f6f6f6f1f1f6f6f6f1f1f1f2f0000000000296f6f1f1f6f6f3f6c6d6d6d6d6d0e6d5c000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000296f6f6f1f1d3d3d3e6f2b00002f1f1d2d2d2d2d2d2d2d1d2d2d461f2f0000000000296f6f6f6f6f6f3f7f1f1f6f1f1f3f2f2b000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000296f2c2d2d1d1f6f6f6f2b00002f1f1f1f6f6f6f6f6f6f6f6f1f1f1f2f0000000000296f6f6f6f6f1f3f7f1f6f6f6f1f3f6f2b0d0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000296f3f1f2f2f2f2f2f2f2b00002f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f0000000000296f1e6f6f1f1f3c0f3d3d3d3d3d1e6f2b000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000296f3c1d3d3d3d1d6f6f2b000000000000000000000000000000000000000000000d296f1e3d3d3d3d3d0f2e1f1f6f6f1e6f2b000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000296f6f6f6f6f6f3f6f6f2b0d002f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f0000000000296f3f1f1f6f6f1f7f3f1f6f6f6f6f6f2b00000d000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000291f1f6c6d6d6d0e6d6d5c00002f406f6f6f6f6f6f6f6f6f2f6f2f2f2f0000000000292f3f1f6f6f1f1f7f3f6f6f6f6f6f6f2b000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000291f1f7f6f6f6f3f6f6f2b00002f1f422d2d2d2d2d2d2d2d2d2d2e2f2f00000d00005d7d0e7d7d7d7d7d7e3f6f6f1f1f6f6f2b000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000291f1e7f6f6f6f46446f2b00002f1f1f1f6f6f6f6f6f6f6f2f1e3f2f2f0000001a0a091f3f1f6f2f2f2f1f3f6f6f1f1f6f6f0b0a2a00000d00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0d00291f1f7f6f6f6f6f6f1d2b00002f1f1f1f6f6f6f6f6f6f6f6f2f3f6f2f000000291f6f6f3f6f6f2f2f2f1f3f6f6f6f6f6f6f2f6f2b00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000393a3a5f3a3a3a3a3a3a3b00002f1f1d1f6f6f6f6f6f6f6f6f6f3f2f2f000000291f1d1d1d6f6f2f2f2f6f3f6f466f6f6f6f6f2f2b00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000002f1f1f1f6f6f6f6f6f6f6f6f6f3f6f2f000000291f1d1f1d6f6f2f2f2f1f3c3d3d3d3d3d3d446f2b000d0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000d00000d000000000d2f1f1d1f6f6f6f6f6f6f6f6f6f3f6f2f000000291f1d1d1d6f6f2f2f2f1f6f6f6f6f6f6f6f6f2f2b0d000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000d000000000000000000000000002f1f1f1f6f6c6d6d6d6d6d6d6d0e6d6d000000296f6f6f6f6f6f2f2f2f1f1f1f1f1f6f6f6f2f6f2b00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001a0a0a0a0a0a0a0a0a0a2a0000002f1f1d1f6f7f6f6f1e6f6f6f6f3f6f2f000000393a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3b00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00291d1f1f6f6f6f46461d2b0000007d7d7d7d7d7e6f6f6f6f6f6f6f3f6f2f0d00000000000000000000000000000d000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00291f1f6f2c2d2d2d441f2b0d00002f1f1d1f6f6f6f6f6f6f6f6f6f3f6f2f00000000000d000000000000000000000000000000000000000d0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00291f6f6f3f6f6f46461f2b00000d2f1f1f1f1f1f1f1f1f1f1f1f1f3f6f2f000000000000000000000d0000000000000000000d00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0d296f6f453f456f6f6f1d2b0000002f1f1e1f1d1f1d1f1d1f1d1f1f466f2f00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00296f6f6f3f6c6d6d6d6d5c0000002f1f1f1f1f1f1f1f1f1f1f1f1f6f442f00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00292f6f6f3f7c6d6d6e1e2b0000002f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00292f6f1d3f2c1d6f7f3f2b0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00296f6f6f3f3f6f1f7f3f2b0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__sfx__
000100001d5201d5600e54005520005200b5000850004500005000250000500005000050000500005000050000500005000050000500005000050000500005000050000500005000050000500005000050000500
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
0002000015040180401c0402204028040330402f0402f0402b04028040280402c0402f0403404036040370403a0401150002500025000a5000a5000a50002500025000f50002500025000a5000a5000250007500
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00020000146401a6002065021640266102064018600146501864021600266301b6201065012610176401d6002162028640226501a6201260013630176001964020640296102860024620216501b630166000f620
000300000c3400835007340053500334002350013400733007340063300534004330033400233009320083300732006330043200433003320023200a340093300834007330063400533003340023300134001330
01020000130501605022650190301b03021640256401d0301b06019030170201d610106100e050296400a0201d620080200704026620106200305002030010402563001030196201962013650050102261005010
000300000c4500846007450054600345002460014500744007450064400545004440034500244009430084400743006440044300444003430024400a450094400845007440064500544003450024400145001440
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000300000d65011650246502a6502e650186500d6500c65018650256502d650326502265006650006000060000600006000060000600006000060000600006000060000600006000060000600006000060000600
000400003f6400464000640026403f6400364000640026403f6400264000640056403f6400064000640006403f6400464001640006403f6400464000640066403f64000640006400064000640006400064000640
000400003965034650336402f6402964025640226400c6400b6400864006640046400364003640026400264002640036400564007640076400464000600066003f60000600006000060000600006000060000600
000300003f640046403f640026403f640036403f640026403f640026403f640056403f640036403f640046403f640046403f640076403f640046403f640066403f64000640006400064000640006400064000640
0003000032660396603c6503e6503b65037650356502f6502a6501f650196501564012640106400d6400c6400a6400964008640066400564007640066400b6400a64006640036400363003630036300363008630
0003000032660396603c6603e6603b66037660356602f6502a6501f650196501565012650106500d6400c6400a640096400d640396603d6603f6603966035660336602c66029640216401d640196401464012640
000300002f650396503d6503d650386502f650306502d65033350353503e3503a3503735034350303502b35026350223501c350143500e3500835005350003500036022670276703c6703c6703c6703c6703a670
0004000025656396563e6563f6563b656396562e656266560965624656356563a6563d6563d656396563765624656096562265635656386563d6563e6563b656376662f6760a6760767604676026760167600676
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
010f00001d1501d1301d1201d1101f1501f1201c1501c120211502113021120211101f1501f1201c1501c12000100001001c1501c12021150211202111021110231502313023120231101f1501f1201c1501c120
011000001d1501d1301d1201d1101f1501f1201c1501c120211502113021120211101f1501f1201c1501c12000100001001c1501c12021150211202111021110251502513020120201101b1501b1201915019120
011000002630026400234001f400193001f3001f3001f3001a3001a30021300214001f3001f3002130023300233001c3001a3001a3001c3001a30020300253002630026300283002830023300233002130023300
01100000233201741213330134100e3200e31013330133121a3200e41215330154121032010312173301531017320173100e3300e31210320103100e3300e3121c3201c312133301331210320104121533015412
01100000233201741213330134100e3200e31013330133121a3201a41215330154121032010312173301531017320173100e3300e31210320103100e3300e3121c3201c31213330133120e3201a4122833028412
011000001d1501d1301d1201d1101f1501f1201c1501c120211502113021120211101f1501f1201c1501c12000100001001c1501c12021150211202111021110231502313023120231101f1501f1201c1501c120
001000001d1501d1301d1201d1101f1501f1201c1501c120211502113021120211101f1501f1201c1501c12000100001001c1501c12021150211202111021110251502513020120201101b1501b1201915019120
011000000c2531b3003f225002003c6251b300246251b3000c253002003f225002003c62500200306251b3000c200002003f225002003c6250020024625306250c253002003c635002003c63500200306251b300
01100000022300222007233072230023000223092330922002230022200723307223002300022309233092200223002220072330722300230002230923309220022300222007233072230b2300b2230223302220
011000200223002220072330722300230002230923309220022300222007233072230023000223092330922002230022200723307223002300022309233092200223002220072330722315230152201723317220
010e00001704010050170401005017040100501704010050170401105017040110501704011050170401105017040130501704013050170401305017040130501704015050170401505017040150501704015050
010e000026540105002653010500245401d5001d530105002854028500215301d50021540115001d5301150028540135001c530135001d540135001c5301350018540155001d5301550024540155001d53015500
010e0000002531b3003c62500200002531b300246251b300002530020000253002000025300200306251b30000253002003f225002003c62500200246253060000253002003c635002000025300200306251b300
010e000026540105002653010500245401d5001d530105002854028500215301d50021540115001d5301150028540135001c530135001d540135001c5301350018540155001d5301550026540155002d53015500
010e00002855004500285500450029550045002955004500305500450030550045002b550045002b5500450032550045003255004500265500450026550045003055004500305500450026550045002455004500
010e00002855004500285500450029550045002955004500305500450030550045002b550045002b5500450032550045003255004500265500450026550045003055004500305500450032550045003555004500
011000002850004500285000450029500045002950004500305000450030500045002b500045002b5000450032500045003250004500265000450026500045003050004500305000450026500045002450004500
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
011000000f7400a7500f7401b70022740097000375007750177400f75017750007002274006700057500a750187401175018750247001f7400a700007500a7501d750247501d7502970024750077000375007700
011000000f5202253016520105032252009500035300950018520275301b5300e50022520065000553006500185201b5301d530025001f5200a500005302b5001d5301f530225303050024530075000353007500
011000000f52022530165200a5302252009500035300950018520275301b5301153022520065000553006500185201b5301d530055301f5200a500005302b5001d5301f530225300a53024530075000353007500
01100000002231b3003c60000200002231b300246001b300002230020000200002000022300200306001b30000223002003f200002000022300200246003060000223002003c615002000022300200306251b300
01100000002231b3003c62500200002231b300246251b300002230020000223002000022300200306251b30000223002003f225002003c62500200246253060000223002003c625002000022300200306251b300
011000000a1400a120021101114002120021100c1400a1200a110021400c120021101114002120021400a1200a1400a12002110021400f12002110021400a1200a110021400712007110021400a120071400c120
01100000183000a3001f3001c30027300023001d3000a3001130002300183000230029300023001c3000a3001830002300113000230016300023000c3000a300183001f3001f3001a300273000a300183000c300
011000000224004230052200424005230072200424005230092200724005230042200222002210022200221002340043300532004340053300732004340053300932007340053300432009320053100932005310
011000000224004230052200424005230072200424005230092200724005230042200222002210022200221002340043300532004340053300732004340053300932007340053300432005320053100232002310
011000003c4353c4253c6250040030435304003c6251b4003c4353c4253c6250040030435304003c6251b4003c4353c4253c6250040030435304003c625304003c4353c4253c6250040030435304003c6253c625
0110000028540005001d5400050028540005001d540005001c540005001f540005001c5401c5401c540005001f5400050023540005001f5401f5401f540005002354000500265400050024540245402454000500
0110000028540005001d5400050028540005001d540005001c540005001f540005001c5401c5401c540005001f5400050023540005001f5401f5401f5400050024540005001c5400050018540185401854000500
__music__
00 63264044
00 64276544
00 63262544
00 64272544
00 21262544
00 21262544
00 21262544
00 22262544
00 21266544
00 22276544
00 21662544
00 22662544
00 21666544
02 22666544
00 41424344
00 28424344
00 28294344
00 282b2a6b
00 28292a44
00 282b2a44
00 282c2a44
00 282d2a44
00 282c2a44
00 282d2a44
00 28296a44
00 282b6a44
00 282c6a44
00 282d6a44
00 682c6a44
02 682d6a44
00 41424344
00 72423644
00 72423644
00 72343644
00 72353644
00 32353644
00 33353644
00 32353644
00 33353644
00 32353644
00 33353644
00 32353644
02 35364431
00 75774471
00 3a434441
00 3a3b4441
00 3a3c4441
00 3a7c3841
00 3a7c3941
00 3a3b3841
00 3a3c3941
00 3a7c3841
00 3a7c3941
00 3a7c3841
00 3a7c3941
00 3a434441
02 3a434441
00 42434441
00 42434441
00 42434441
00 42434441
00 42434441
00 42434440
00 40404040

