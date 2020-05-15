pico-8 cartridge // http://www.pico-8.com
version 23
__lua__

-- mobility ids
mobility_infantry = 0
mobility_mech = 1
mobility_tires = 2
mobility_treads = 3

unit_infantry = "infantry"
unit_mech = "mech"
unit_recon = "recon"
unit_tank = "tank"
unit_war_tank = "war tank"
unit_artillery = "artillery"
unit_rocket = "rocket"

unit_index_infantry = 1
unit_index_mech = 2
unit_index_recon = 3
unit_index_tank = 4
unit_index_war_tank = 5
unit_index_artillery = 6
unit_index_rocket = 7


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

-- byte field lengths 


-- byte constants
starting_memory = 0x4300

-- byte counters
memory_i = starting_memory


-- globals
last_checked_time = 0.0
delta_time = 0.0  -- time since last frame


function _init()
  music(music_splash_screen, 0, music_bitmask)

  rectfill(0, 0, 1000, 1000, 9)
  -- setup cartdata
  cartdata("picowars") 


  local units = {
    make_infantry(),
    make_mech(),
    make_recon(),
    make_tank(),
    make_war_tank(),
    make_artillery(),
    make_rocket(),
  }

  -- write all data
  for unit in all(units) do
    write_unit(unit)
  end
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

-- unitdata

-- infantry
function make_infantry()
  local unit = {}

  unit.index = unit_index_infantry
  unit.type = unit_infantry
  unit.sprite = 16
  unit.mobility_type = mobility_infantry
  unit.travel = 4
  unit.moveout_sfx = sfx_infantry_moveout
  unit.combat_sfx = sfx_infantry_combat

  dc = {}
  dc[unit_index_infantry] = 5.5
  dc[unit_index_mech] = 4.5
  dc[unit_index_recon] = 1.2
  dc[unit_index_tank] = 0.5
  dc[unit_index_war_tank] = 0.1
  dc[unit_index_artillery] = 1.5
  dc[unit_index_rocket] = 2.5
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
  unit.moveout_sfx = sfx_infantry_moveout
  unit.combat_sfx = sfx_mech_combat

  dc = {}
  dc[unit_index_infantry] = 6.5
  dc[unit_index_mech] = 5.5
  dc[unit_index_recon] = 8.5
  dc[unit_index_tank] = 5.5
  dc[unit_index_war_tank] = 1.5
  dc[unit_index_artillery] = 7
  dc[unit_index_rocket] = 8.5
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
  dc[unit_index_tank] = 0.6
  dc[unit_index_war_tank] = 0.1
  dc[unit_index_artillery] = 4.5
  dc[unit_index_rocket] = 5.5
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
  unit.moveout_sfx = sfx_tank_moveout
  unit.combat_sfx = sfx_tank_combat

  dc = {}
  dc[unit_index_infantry] = 3.5
  dc[unit_index_mech] = 3.0
  dc[unit_index_recon] = 8.5
  dc[unit_index_tank] = 5.5
  dc[unit_index_war_tank] = 1.5
  dc[unit_index_artillery] = 7.0
  dc[unit_index_rocket] = 8.5
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
  unit.moveout_sfx = sfx_war_tank_moveout
  unit.combat_sfx = sfx_war_tank_combat

  dc = {}
  dc[unit_index_infantry] = 10.5
  dc[unit_index_mech] = 9.5
  dc[unit_index_recon] = 10.5
  dc[unit_index_tank] = 8.5
  dc[unit_index_war_tank] = 5.5
  dc[unit_index_artillery] = 10.5
  dc[unit_index_rocket] = 10.5
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
  unit.moveout_sfx = sfx_artillery_moveout
  unit.combat_sfx = sfx_artillery_combat

  dc = {}
  dc[unit_index_infantry] = 0.9
  dc[unit_index_mech] = 0.85
  dc[unit_index_recon] = 0.8
  dc[unit_index_tank] = 0.7
  dc[unit_index_war_tank] = 0.45
  dc[unit_index_artillery] = 0.75
  dc[unit_index_rocket] = 0.8
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
  unit.moveout_sfx = sfx_rocket_moveout
  unit.combat_sfx = sfx_rocket_combat

  dc = {}
  dc[unit_index_infantry] = 0.95
  dc[unit_index_mech] = 0.9
  dc[unit_index_recon] = 0.9
  dc[unit_index_tank] = 0.85
  dc[unit_index_war_tank] = 0.55
  dc[unit_index_artillery] = 0.8
  dc[unit_index_rocket] = 0.85
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

function poke_increment(poke_at)
  -- pokes at memory_i and increments the global memory_i counter while doing it
  poke(memory_i, poke_at)
  memory_i += 1
end

function poke4_increment(poke_at)
  -- pokes at memory_i and increments the global memory_i counter while doing it
  poke4(memory_i, poke_at)
  memory_i += 4
end

function write_unit(u)
  -- writes a unit to memory

  -- unit index
  poke_increment(u.index)

  -- type
  write_string(u.type, 10)

  -- sprite
  poke_increment(u.sprite)

  -- mobility type
  poke_increment(u.mobility_type)

  -- travel
  poke_increment(u.travel)

  -- moveout sfx
  poke_increment(u.moveout_sfx)
  
  -- combat sfx
  poke_increment(u.combat_sfx)

  -- damage chart
  for attacked_unit_index, damage_val in pairs(u.damage_chart) do
    printh("saving---")
    printh("attacked_unit_index: " .. attacked_unit_index)
    printh("damage_val: " .. damage_val)
    poke_increment(attacked_unit_index)
    poke4_increment(damage_val)
  end

end
