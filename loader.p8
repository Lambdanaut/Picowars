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

-- mobility ids
mobility_infantry = 0
mobility_mech = 1
mobility_tires = 2
mobility_treads = 3

unit_infantry = "infantry"
unit_mech = "mech"
unit_recon = "recon"
unit_artillery = "artillery"
unit_tank = "tank"
unit_rocket = "rocket"
unit_war_tank = "war tank"

unit_index_infantry = 1
unit_index_mech = 2
unit_index_recon = 3
unit_index_artillery = 4
unit_index_tank = 5
unit_index_rocket = 6
unit_index_war_tank = 7


-- sfx
sfx_infantry_moveout = 14
sfx_tank_moveout = 15
sfx_recon_moveout = 16
sfx_war_tank_moveout = 17
sfx_infantry_combat = 22
sfx_mech_combat = 23
sfx_recon_combat = 24
sfx_tank_combat = 25
sfx_war_tank_combat = 26
sfx_artillery_combat = 27
sfx_rocket_combat = 28

-- ai unit ratios
-- must add up to 100
ai_unit_ratio_infantry = 15
ai_unit_ratio_mech = 15
ai_unit_ratio_recon = 14
ai_unit_ratio_artillery = 14
ai_unit_ratio_tank = 14
ai_unit_ratio_rocket = 15
ai_unit_ratio_war_tank = 13

-- byte constants
starting_memory = 0x4300
match_result_memory = 0x5ddd

-- globals
last_checked_time = 0.0
delta_time = 0.0  -- time since last frame
memory_i = starting_memory

-- match result globals
match_result_turn_count = nil
match_result_p1_unit_count = nil
match_result_p2_unit_count = nil
match_result_p1_units_lost = nil
match_result_p2_units_lost = nil


function _init()
  music(music_splash_screen, 0, music_bitmask)

  rectfill(0, 0, 1000, 1000, 9)
  -- setup cartdata
  cartdata("picowars") 

  local commanders = {
    make_guster(),
    make_bill(),
  }
  local team_humans = {
    false,
    false 
  }
  local team_indexes = {
    -- 1,
    -- 2
  }

  -- write all data
  for i=1, 2 do
    write_co(commanders[i], team_humans[i])
  end
  write_map(make_map1())
end

function _update()
  local t = time()
  delta_time = t - last_checked_time
  last_checked_time = t

  if (btnp(4)) then 
    load_game()
  end
end

function load_game()
  -- load game
  load("picowars.p8")
end


-- dialogue

-- maps
function make_map1()
  local m = {}

  m.name = "map1"
  m.r = {0, 0, 8, 26}

  return m
end


-- commanders
function make_sami()
  local co = {}

  co.index = 1
  co.name = "sami"
  co.sprite = 238
  co.team_index = 1  -- orange star

  co.units = make_units()

  -- sami's infantry and mechs travel further
  co.units[1].travel += 1
  co.units[2].travel += 1

  -- sami's infantry and mechs have a +5 to their capture rate
  co.units[1].capture_bonus += 5
  co.units[2].capture_bonus += 5

  -- sami's infantry and mechs have 25% more attack
  for i in all({unit_index_infantry, unit_index_mech}) do
    for j=1,#co.units[i].damage_chart do
      co.units[i].damage_chart[j] *= 1.25
    end
  end

  -- sami's non-infantry units have 10% less attack
  for i=3,#co.units do
    for j=1,#co.units[i].damage_chart do
      co.units[i].damage_chart[j] *= 0.9
    end
  end

  return co
end

function make_bill()
  local co = {}

  co.index = 2
  co.name = "bill"
  co.sprite = 236
  co.team_index = 2  -- blue moon

  co.units = make_units()

  -- bill's non-infantry units have 10% more luck
  for i=1,#co.units do
    co.units[i].luck_max = 2
  end

  return co
end

function make_guster()
  local co = {}

  co.index = 3
  co.name = "guster"
  co.sprite = 234
  co.team_index = 3  -- green earth

  co.units = make_units()

  -- guster's ranged units have +1 range
  co.units[4].range_max += 1
  co.units[6].range_max += 1

  -- guster's ranged units have 30% more attack
  for i in all({unit_index_artillery, unit_index_rocket}) do
    for j=1,#co.units[i].damage_chart do
      co.units[i].damage_chart[j] *= 1.3
    end
  end

  -- guster's non-ranged, non-infantry units have 10% less attack
  for i in all({unit_index_mech, unit_index_recon, unit_index_tank, unit_index_war_tank}) do
    for j=1,#co.units[i].damage_chart do
      co.units[i].damage_chart[j] *= 0.9
    end
  end

  -- guster's ai prioritizes ranged units
  co.units[1].ai_unit_ratio = 10
  co.units[2].ai_unit_ratio = 5
  co.units[3].ai_unit_ratio = 5
  co.units[4].ai_unit_ratio = 35
  co.units[5].ai_unit_ratio = 5
  co.units[6].ai_unit_ratio = 35
  co.units[7].ai_unit_ratio = 5

  return co
end


-- unitdata
function make_units()
  local units = {
    make_infantry(),
    make_mech(),
    make_recon(),
    make_artillery(),
    make_tank(),
    make_rocket(),
    make_war_tank()
  }
  return units
end

-- infantry
function make_infantry()
  local unit = {}

  unit.index = unit_index_infantry
  unit.type = unit_infantry
  unit.sprite = 16
  unit.mobility_type = mobility_infantry
  unit.travel = 4
  unit.cost = 1
  unit.range_min = 0
  unit.range_max = 0
  unit.luck_max = 1
  unit.capture_bonus = 0
  unit.ai_unit_ratio = ai_unit_ratio_infantry
  unit.moveout_sfx = sfx_infantry_moveout
  unit.combat_sfx = sfx_infantry_combat

  dc = {}
  dc[unit_index_infantry] = 5.5
  dc[unit_index_mech] = 4.5
  dc[unit_index_recon] = 1.2
  dc[unit_index_artillery] = 1.5
  dc[unit_index_tank] = 0.5
  dc[unit_index_rocket] = 2.5
  dc[unit_index_war_tank] = 0.1
  unit.damage_chart = dc

  return unit
end

function make_mech()
  local unit = {}

  unit.index = unit_index_mech
  unit.type = unit_mech
  unit.sprite = 17
  unit.mobility_type = mobility_mech
  unit.travel = 3
  unit.cost = 3
  unit.luck_max = 1
  unit.range_min = 0
  unit.range_max = 0
  unit.capture_bonus = 0
  unit.ai_unit_ratio = ai_unit_ratio_mech
  unit.moveout_sfx = sfx_infantry_moveout
  unit.combat_sfx = sfx_mech_combat

  dc = {}
  dc[unit_index_infantry] = 6.5
  dc[unit_index_mech] = 5.5
  dc[unit_index_recon] = 8.5
  dc[unit_index_artillery] = 7
  dc[unit_index_tank] = 5.5
  dc[unit_index_rocket] = 8.5
  dc[unit_index_war_tank] = 1.5
  unit.damage_chart = dc

  return unit
end

function make_recon()
  local unit = {}

  unit.index = unit_index_recon
  unit.type = unit_recon
  unit.sprite = 18
  unit.mobility_type = mobility_tires
  unit.travel = 9
  unit.cost = 4
  unit.range_min = 0
  unit.range_max = 0
  unit.luck_max = 1
  unit.capture_bonus = 0
  unit.ai_unit_ratio = ai_unit_ratio_recon
  unit.moveout_sfx = sfx_recon_moveout
  unit.combat_sfx = sfx_recon_combat

  -- just a bit stronger vs lighter units than advance wars 2 recon because fog of war is removed.
  -- made into a true anti-infantry unit
  -- if we add fog of war, consider nerfing the recon to advance-wars level
  -- https://advancewars.fandom.com/wiki/recon_(advance_wars_2)
  dc = {}
  dc[unit_index_infantry] = 7.6
  dc[unit_index_mech] = 6.8
  dc[unit_index_recon] = 3.8
  dc[unit_index_artillery] = 4.5
  dc[unit_index_tank] = 0.6
  dc[unit_index_rocket] = 5.5
  dc[unit_index_war_tank] = 0.1
  unit.damage_chart = dc

  return unit
end

function make_artillery()
  local unit = {}

  unit.index = unit_index_artillery
  unit.type = unit_artillery
  unit.sprite = 21
  unit.mobility_type = mobility_treads
  unit.travel = 6
  unit.cost = 6
  unit.range_min = 2
  unit.range_max = 3
  unit.luck_max = 1
  unit.capture_bonus = 0
  unit.ai_unit_ratio = ai_unit_ratio_artillery
  unit.moveout_sfx = sfx_tank_moveout
  unit.combat_sfx = sfx_artillery_combat

  dc = {}
  dc[unit_index_infantry] = 9
  dc[unit_index_mech] = 8.5
  dc[unit_index_recon] = 8
  dc[unit_index_artillery] = 7.5
  dc[unit_index_tank] = 7
  dc[unit_index_rocket] = 8
  dc[unit_index_war_tank] = 4.5
  unit.damage_chart = dc

  return unit
end

function make_tank()
  local unit = {}

  unit.index = unit_index_tank
  unit.type = unit_tank
  unit.sprite = 19
  unit.mobility_type = mobility_treads
  unit.travel = 7
  unit.cost = 7
  unit.range_min = 0
  unit.range_max = 0
  unit.luck_max = 1
  unit.capture_bonus = 0
  unit.ai_unit_ratio = ai_unit_ratio_tank
  unit.moveout_sfx = sfx_tank_moveout
  unit.combat_sfx = sfx_tank_combat

  dc = {}
  dc[unit_index_infantry] = 3.5
  dc[unit_index_mech] = 3.0
  dc[unit_index_recon] = 8.5
  dc[unit_index_artillery] = 7.0
  dc[unit_index_tank] = 5.5
  dc[unit_index_rocket] = 8.5
  dc[unit_index_war_tank] = 1.5
  unit.damage_chart = dc

  return unit
end

function make_rocket()
  local unit = {}

  unit.index = unit_index_rocket
  unit.type = unit_rocket
  unit.sprite = 22
  unit.mobility_type = mobility_tires
  unit.travel = 6
  unit.cost = 15
  unit.range_min = 3
  unit.range_max = 5
  unit.luck_max = 1
  unit.capture_bonus = 0
  unit.ai_unit_ratio = ai_unit_ratio_rocket
  unit.moveout_sfx = sfx_recon_moveout
  unit.combat_sfx = sfx_rocket_combat

  dc = {}
  dc[unit_index_infantry] = 9.5
  dc[unit_index_mech] = 9
  dc[unit_index_recon] = 9
  dc[unit_index_artillery] = 8
  dc[unit_index_tank] = 8.5
  dc[unit_index_rocket] = 8.5
  dc[unit_index_war_tank] = 5.5
  unit.damage_chart = dc

  return unit
end

function make_war_tank()
  local unit = {}

  unit.index = unit_index_war_tank
  unit.type = unit_war_tank
  unit.sprite = 20
  unit.mobility_type = mobility_treads
  unit.travel = 6
  unit.cost = 16
  unit.range_min = 0
  unit.range_max = 0
  unit.luck_max = 1
  unit.capture_bonus = 0
  unit.ai_unit_ratio = ai_unit_ratio_war_tank
  unit.moveout_sfx = sfx_war_tank_moveout
  unit.combat_sfx = sfx_war_tank_combat

  dc = {}
  dc[unit_index_infantry] = 10.5
  dc[unit_index_mech] = 9.5
  dc[unit_index_recon] = 10.5
  dc[unit_index_artillery] = 10.5
  dc[unit_index_tank] = 8.5
  dc[unit_index_rocket] = 10.5
  dc[unit_index_war_tank] = 5.5
  unit.damage_chart = dc

  return unit
end

function write_string(string, length)
  -- writes a string to memory
  for i = 1, length do
    local c = sub(string, i,i)
    local charcode_val = ord(c)
    poke_increment(charcode_val)
  end
end

function peek_increment()
  -- peeks at memory_i and increments the global memory_i counter while doing it
  local v = peek(memory_i)
  memory_i += 1
  return v
end

function poke_increment(poke_value)
  -- pokes at memory_i and increments the global memory_i counter while doing it
  poke(memory_i, poke_value)
  memory_i += 1
end

function poke4_increment(poke_value)
  -- pokes at memory_i and increments the global memory_i counter while doing it
  poke4(memory_i, poke_value)
  memory_i += 4
end

function write_unit(u)
  -- writes a unit to memory

  poke_increment(u.index)
  write_string(u.type, 10)
  poke_increment(u.sprite)
  poke_increment(u.mobility_type)
  poke_increment(u.travel)
  poke_increment(u.cost)
  poke_increment(u.range_min)
  poke_increment(u.range_max)
  poke_increment(u.luck_max)
  poke_increment(u.capture_bonus)
  poke_increment(u.ai_unit_ratio)
  poke_increment(u.moveout_sfx)
  poke_increment(u.combat_sfx)

  -- damage chart
  for attacked_unit_index, damage_val in pairs(u.damage_chart) do
    poke_increment(attacked_unit_index)
    poke4_increment(damage_val)
  end

end

function write_co(co, human_player, team_index)
  if not team_index then team_index = co.team_index end
  if human_player then human_player = 1 else human_player = 0 end

  poke_increment(human_player)
  write_string(co.name, 10)
  poke_increment(team_index)
  poke_increment(co.sprite)

  for unit in all(co.units) do
    write_unit(unit)
  end
end

function write_map(m)
  -- write out the map's bounds to memory
  for i=1,4 do
    poke_increment(m.r[i])
  end
end


function read_match_result()
  

end
