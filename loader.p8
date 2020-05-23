pico-8 cartridge // http://www.pico-8.com
version 27
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
-- unit_apc = "apc"
unit_artillery = "artillery"
unit_tank = "tank"
unit_rocket = "rocket"
unit_war_tank = "war tank"

unit_index_infantry = 1
unit_index_mech = 2
unit_index_recon = 3
-- unit_index_apc = 4
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

-- music
team_index_to_music = {
  31, 0, 0, 0
}

-- team icons
team_index_to_team_icon = {
  192, 208, 193, 209
}

-- ai unit ratios
-- must add up to 100
ai_unit_ratio_infantry = 5
ai_unit_ratio_mech = 15
ai_unit_ratio_recon = 18
ai_unit_ratio_apc = 0
ai_unit_ratio_artillery = 18
ai_unit_ratio_tank = 16
ai_unit_ratio_rocket = 16
ai_unit_ratio_war_tank = 12

-- byte constants
starting_memory = 0x4300
match_result_memory = 0x5ddd

-- funds
funds = 0

-- globals
last_checked_time = 0.0
delta_time = 0.0  -- time since last frame
memory_i = starting_memory


function _init()
  music(music_splash_screen, 0, music_bitmask)

  -- set initial background color
  rectfill(0, 0, 1000, 1000, 9)

  -- setup cartdata
  cartdata("picowars") 

  -- setup initial commander data
  make_commanders()

  local game_commanders = {
    make_sami(),
    make_alecia(),
  }
  local team_humans = {
    true,
    false
  }
  local team_indexes = {
    -- 1,
    -- 2
  }

  -- write commander, unit, and map data for engine use
  if game_commanders[1].team_index == game_commanders[2].team_index then game_commanders[2].team_index = (game_commanders[2].team_index + 1) % 4 end
  for i=1, 2 do
    write_co(game_commanders[i], team_humans[i], team_indexes[i])
  end
  write_map(make_map4())

  -- load save
  write_save()
  read_save()

end

function _update()
  local t = time()
  delta_time = t - last_checked_time
  last_checked_time = t

  -- if (btnp(4)) then 
  if btnp(4) then
    load_game()
  end
  -- end
end

function load_game()
  -- load game
  load("picowars.p8")
end

-- splash screen


-- dialogue

-- maps
function make_map1()
  local m = {}

  m.name = "map1"
  m.r = {0, 0, 14, 21}
  m.bg_color = 12

  -- should we load the map from a source other than the engine?
  -- 0=false, 1=load from this map, 2=load from secondary map source
  m.load_external = 0

  return m
end

function make_map2()
  local m = {}

  m.name = "map2"
  m.r = {15, 0, 15, 12}
  m.bg_color = 3

  -- should we load the map from a source other than the engine?
  -- 0=false, 1=load from this map, 2=load from secondary map source
  m.load_external = 0

  return m
end

function make_map3()
  local m = {}

  m.name = "map3"
  m.r = {31, 0, 26, 25}
  m.bg_color = 12

  -- should we load the map from a source other than the engine?
  -- 0=false, 1=load from this map, 2=load from secondary map source
  m.load_external = 0

  return m
end

function make_map4()
  local m = {}

  m.name = "map4"
  m.r = {15, 14, 15, 15}
  m.bg_color = 3

  -- should we load the map from a source other than the engine?
  -- 0=false, 1=load from this map, 2=load from secondary map source
  m.load_external = 0

  return m
end

-- commanders
function make_commanders()
  commanders = {
    make_andrew(),
    make_sami(),
    make_hachi(),
    make_bill(),
    make_guster(),
    make_slydy(),
  }
end

function make_andrew()
  local co = {}

  co.name = "andrew"
  co.sprite = 230
  co.team_index = 1
  co.team_icon = team_index_to_team_icon[co.team_index]
  co.available = true
  co.music = team_index_to_music[co.team_index]

  co.units = make_units()

  -- andrew's units get 1 more healing from structures
  for unit in all(co.units) do
    unit.struct_heal_bonus = 1
  end

  return co
end

function make_sami()
  local co = {}

  co.name = "sami"
  co.sprite = 238
  co.team_index = 1  -- orange star
  co.team_icon = team_index_to_team_icon[co.team_index]
  co.available = false
  co.music = team_index_to_music[co.team_index]

  co.units = make_units()

  -- sami's infantry and mechs travel further
  -- co.units[1].travel += 1
  -- co.units[2].travel += 1

  -- -- sami's infantry and mechs have a +5 to their capture rate
  -- co.units[1].capture_bonus += 5
  -- co.units[2].capture_bonus += 5

  -- -- sami's infantry and mechs have 30% more attack
  -- for i in all({unit_index_infantry, unit_index_mech}) do
  --   for j=1,#co.units[i].damage_chart do
  --     co.units[i].damage_chart[j] *= 1.3
  --   end
  -- end

  -- -- sami's non-infantry units have 10% less attack
  -- for i=3,#co.units do
  --   for j=1,#co.units[i].damage_chart do
  --     co.units[i].damage_chart[j] *= 0.9
  --   end
  -- end

  return co
end

function make_hachi()
  local co = {}

  co.name = "hachi"
  co.sprite = 198
  co.team_index = 1
  co.team_icon = team_index_to_team_icon[co.team_index]
  co.available = false
  co.music = team_index_to_music[co.team_index]

  co.units = make_units()

  -- hachi's non-infantry and non-mech units cost 15% less
  for i=3, #co.units do
    co.units[i].cost = flr(co.units[i].cost * 0.85)
  end

  return co
end

function make_bill()
  local co = {}

  co.name = "bill"
  co.sprite = 236
  co.team_index = 2  -- blue moon
  co.team_icon = team_index_to_team_icon[co.team_index]
  co.available = false
  co.music = team_index_to_music[co.team_index]

  co.units = make_units()

  -- bill's non-infantry units have 10% more luck
  for i=1,#co.units do
    co.units[i].luck_max = 2
  end

  return co
end

function make_alecia()
  local co = {}

  co.name = "alecia"
  co.sprite = 206
  co.team_index = 2
  co.team_icon = team_index_to_team_icon[co.team_index]
  co.available = false
  co.music = team_index_to_music[co.team_index]

  co.units = make_units()

  return co
end

function make_conrad()
  local co = {}

  co.name = "conrad"
  co.sprite = 200
  co.team_index = 2
  co.team_icon = team_index_to_team_icon[co.team_index]
  co.available = false
  co.music = team_index_to_music[co.team_index]

  co.units = make_units()

  for unit in all(co.units) do
    -- conrads's units are only healed by 1 by structures
    unit.struct_heal_bonus = -1

    -- all of conrads units have 10% more firepower
    for i=1, #unit.damage_chart do
      unit.damage_chart[i] *= 1.1
    end
  end

  return co
end

function make_guster()
  local co = {}

  co.name = "guster"
  co.sprite = 234
  co.team_index = 3  -- green earth
  co.team_icon = team_index_to_team_icon[co.team_index]
  co.available = false
  co.music = team_index_to_music[co.team_index]

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
  co.units[unit_index_infantry].ai_unit_ratio = 10
  co.units[unit_index_mech].ai_unit_ratio = 5
  co.units[unit_index_recon].ai_unit_ratio = 5
  -- co.units[unit_index_apc].ai_unit_ratio = 6
  co.units[unit_index_artillery].ai_unit_ratio = 32
  co.units[unit_index_tank].ai_unit_ratio = 5
  co.units[unit_index_rocket].ai_unit_ratio = 32
  co.units[unit_index_war_tank].ai_unit_ratio = 5

  return co
end

function make_slydy()
  local co = {}

  co.name = "slydy"
  co.sprite = 232
  co.team_index = 4  -- pink groove
  co.team_icon = team_index_to_team_icon[co.team_index]
  co.available = false
  co.music = team_index_to_music[co.team_index]

  co.units = make_units()

  return co
end

-- unitdata
function make_units()
  local units = {
    make_infantry(),
    make_mech(),
    make_recon(),
    -- make_apc(),
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
  unit.struct_heal_bonus = 0
  unit.ai_unit_ratio = ai_unit_ratio_infantry
  unit.moveout_sfx = sfx_infantry_moveout
  unit.combat_sfx = sfx_infantry_combat
  unit.is_carrier = false

  dc = {}
  dc[unit_index_infantry] = 5.5
  dc[unit_index_mech] = 4.5
  dc[unit_index_recon] = 1.2
  -- dc[unit_index_apc] = 1.4
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
  unit.struct_heal_bonus = 0
  unit.ai_unit_ratio = ai_unit_ratio_mech
  unit.moveout_sfx = sfx_infantry_moveout
  unit.combat_sfx = sfx_mech_combat
  unit.is_carrier = false

  dc = {}
  dc[unit_index_infantry] = 6.5
  dc[unit_index_mech] = 5.5
  dc[unit_index_recon] = 8.5
  -- dc[unit_index_apc] = 7.5
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
  unit.struct_heal_bonus = 0
  unit.ai_unit_ratio = ai_unit_ratio_recon
  unit.moveout_sfx = sfx_recon_moveout
  unit.combat_sfx = sfx_recon_combat
  unit.is_carrier = false

  -- just a bit stronger vs lighter units than advance wars 2 recon because fog of war is removed.
  -- made into a true anti-infantry unit
  -- if we add fog of war, consider nerfing the recon to advance-wars level
  -- https://advancewars.fandom.com/wiki/recon_(advance_wars_2)
  dc = {}
  dc[unit_index_infantry] = 7.6
  dc[unit_index_mech] = 6.8
  dc[unit_index_recon] = 3.8
  -- dc[unit_index_apc] = 4.5
  dc[unit_index_artillery] = 4.5
  dc[unit_index_tank] = 0.6
  dc[unit_index_rocket] = 5.5
  dc[unit_index_war_tank] = 0.1
  unit.damage_chart = dc

  return unit
end

function make_apc()
  local unit = {}

  unit.index = unit_index_apc
  unit.type = unit_apc
  unit.sprite = 23
  unit.mobility_type = mobility_treads
  unit.travel = 7
  unit.cost = 5
  unit.range_min = 0
  unit.range_max = 0
  unit.luck_max = 1
  unit.capture_bonus = 0
  unit.struct_heal_bonus = 0
  unit.ai_unit_ratio = ai_unit_ratio_apc
  unit.moveout_sfx = sfx_tank_moveout
  unit.combat_sfx = 0  -- no combat
  unit.is_carrier = true

  dc = {}
  dc[unit_index_infantry] = 0
  dc[unit_index_mech] = 0
  dc[unit_index_recon] = 0
  -- dc[unit_index_apc] = 0
  dc[unit_index_artillery] = 0
  dc[unit_index_tank] = 0
  dc[unit_index_rocket] = 0
  dc[unit_index_war_tank] = 0
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
  unit.struct_heal_bonus = 0
  unit.ai_unit_ratio = ai_unit_ratio_artillery
  unit.moveout_sfx = sfx_tank_moveout
  unit.combat_sfx = sfx_artillery_combat
  unit.is_carrier = false

  dc = {}
  dc[unit_index_infantry] = 9
  dc[unit_index_mech] = 8.5
  dc[unit_index_recon] = 8
  -- dc[unit_index_apc] = 7
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
  unit.struct_heal_bonus = 0
  unit.ai_unit_ratio = ai_unit_ratio_tank
  unit.moveout_sfx = sfx_tank_moveout
  unit.combat_sfx = sfx_tank_combat
  unit.is_carrier = false

  dc = {}
  dc[unit_index_infantry] = 3.5
  dc[unit_index_mech] = 3.0
  dc[unit_index_recon] = 8.5
  -- dc[unit_index_apc] = 7.5
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
  unit.struct_heal_bonus = 0
  unit.ai_unit_ratio = ai_unit_ratio_rocket
  unit.moveout_sfx = sfx_recon_moveout
  unit.combat_sfx = sfx_rocket_combat
  unit.is_carrier = false

  dc = {}
  dc[unit_index_infantry] = 9.5
  dc[unit_index_mech] = 9
  dc[unit_index_recon] = 9
  -- dc[unit_index_apc] = 8
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
  unit.struct_heal_bonus = 0
  unit.ai_unit_ratio = ai_unit_ratio_war_tank
  unit.moveout_sfx = sfx_war_tank_moveout
  unit.combat_sfx = sfx_war_tank_combat
  unit.is_carrier = false

  dc = {}
  dc[unit_index_infantry] = 10.5
  dc[unit_index_mech] = 9.5
  dc[unit_index_recon] = 10.5
  -- dc[unit_index_apc] = 10.5
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

function poke2_increment(poke_value)
  -- pokes at memory_i and increments the global memory_i counter while doing it
  poke2(memory_i, poke_value)
  memory_i += 2
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
  poke2_increment(u.struct_heal_bonus)
  poke_increment(u.ai_unit_ratio)
  poke_increment(u.moveout_sfx)
  poke_increment(u.combat_sfx)
  if u.is_carrier then poke_increment(1) else poke_increment(0) end

  -- damage chart
  for attacked_unit_index, damage_val in pairs(u.damage_chart) do
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
  poke_increment(co.team_icon)
  poke_increment(co.music)

  for unit in all(co.units) do
    write_unit(unit)
  end
end

function write_map(m)
  -- write out the map's bounds to memory
  for i=1,4 do
    poke_increment(m.r[i])
  end
  poke_increment(m.bg_color)

  if m.load_external == 0 then
    -- set byte to indicate map shouldn't be loaded from external source
    poke_increment(0)
  elseif m.load_external == 1 then
    -- set byte to indicate map should be loaded from external source
    poke_increment(1)
    -- load the map data into code
  end

end

function write_save()
  memory_i = 0x5e00

  -- write funds to disk
  poke_increment(funds)

  -- write campaign score and progress to disk


  -- write available commanders to disk
  for co in all(commanders) do
    local available = 0
    if co.available then available = 1 end
    poke_increment(available)
  end

  -- write available war maps to disk

end

function read_save()
  memory_i = 0x5e00

  -- read funds from disk
  funds = peek_increment()

  -- write campaign score and progress to disk


  -- write available commanders to disk
  for co in all(commanders) do
    local available = peek_increment()
    if available == 1 then co.available = true end
  end

  -- write available war maps to disk
end

function read_match_result()
  -- reads a match's results from memory and sets global variables for each of them

  memory_i = 0x5ddd -- beginning of match result memory

  -- reasons:
  -- * 1: victory player 1
  -- * 2: victory player 2
  -- * 3: abandon mission
  match_result_reason = peek_increment()
  for i = 1, 2 do
    match_result_units_lost[i] = peek_increment()
    match_result_units_built[i] = peek_increment()
  end
  match_result_turn_count = peek_increment()
end






__gfx__
0000000000000000000000000000000000000000000000000000000000000000000000000000004400000000220000000000000000f00000566666555ccccc63
000000000000000000000000000000000000000000000000000000000000000000000000000000440000000022000000000000000f4400f0c66666cc5c5c5c66
0000000000000000000000000000000000000000000000000000000000000000000000000000004400000000220000000000000072427f425667665c66666666
0000000000000000000000000000000000000000000000000000000000000000000000000000004400000000220000000000000007270722c66766cc66666666
00000000000000000000000000000000000000000000000000000000000000000000000000000044000000002200000000dddd00007f40775666665c66776677
0000000000000000000000000000000000000000000000000000000000000000000000000000004400000000220000000ddddd5007244270c66666cc66666666
0000000000000000000000000000000000000000000000000000000000000000000000000000044400000000222000000ddddd50007227006667666666666666
0000000000000000000000000000000000000000000000000000000000000000000000004444444344444444324444440d55555000077000666766635c5c5c66
000000000000000000000000000000000000000000000000000000000000000000000000555555530000000035555555006dd500005555000000000033b33b33
000000000000000000000000000000000000000000000000000000000000000000000000222244450000000052222222065555500d7575d0000000053bbb5bb3
000000000000000000000000000000000000000000000000000000000000000000000000222222440000000022222222067dd750ddd55ddd005500553bb5bb53
00000000000000000000000000000000000000000000000000000000000000000000000022222244000000002222222206dddd50d7d57d7d055d055dbb5b5bb5
00000000000000000000000000000000000000000000000000000000000000000000000000000244000000002220000065555555ddd55ddd55dd55dd3b5bbb53
00000000000000000000000000000000000000000000000000000000000000000000000000000044000000002200000067d7d7d5d7d57d7dd7d7d7d7bbb5bbb5
0000000000000000000000000000000000000000000000000000000000000000000000000000004400000000220000006dddddd5ddd55ddddddddddd33433433
00000000000000000000000000000000000000000000000000000000000000000000000000000044000000042200000067d7d7d5ddd55dddd7d7d7d733333333
000000000000000000000000000000000000000000000000000000000000000000000000000000440000000022000000336666666666666666666333333ff333
00000000000000000000000000000000000000000000000000000000000000000000000000000044000000002200000036666666666666666666663333f44233
00000000000000000000000000000000000000000000000000000000000000000000000000000044000000002200000066666666666666666666666333f44233
0000000000000000000000000000000000000000000000000000000000000000000000000000004400000000220000006666667766776677667666633f444223
0000000000000000000000000000000000000000000000000000000000000000000000000000004400000000220000006666666666666666666766633f442423
0000000000000000000000000000000000000000000000000000000000000000000000000000004400000000220000006667666666666666666666633f424423
000000000000000000000000000000000000000000000000000000000000000000000000000000440000000022000000666766666666666666676663b4b4b24b
0000000000000000000000000000000000000000000000000000000000000000000000000000004440000000220000006666666333333333666766633bbbbbb3
00000000000000000000000000000000000000000000000000000000000000000000000000000044555555552200000066666663333333336666666366666663
00000000000000000000000000000000000000000000000000000000000000000000000000000044222222222200000066666666666666666666666366666663
00000000000000000000000000000000000000000000000000000000000000000000000000000042222222222200000066676666666666666667666366676663
00000000000000000000000000000000000000000000000000000000000000000000000000000002222222222000000066676666666666666667666366676663
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000066667677667766776676666366666663
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000066666666666666666666666366666663
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000036666666666666666666663366676663
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000033666666666666666666633366676663
00299200002222000000000000000000006cc1000011110000000000000000000000000000000000000000000000000000000000000000000000000000000000
02222220008282000000000200000000061111100061610000000001000000000000000000000000000000000000000000000000000000000000000000000000
02899820999229990022002200222200066cc610ccc11ccc00110011000000000000000000000000000000000000000000000000000000000000000000000000
0299992098928989022902290299992006cccc10c6c16c6c011c011c000000000000000000000000000000000000000000000000000000000000000000000000
2222222299922999229922992999999261111111ccc11ccc11cc11cc000000000000000000000000000000000000000000000000000000000000000000000000
2898989298928989989898980299992066c6c6c1c6c16c6cc6c6c6c6000000000000000000000000000000000000000000000000000000000000000000000000
299999929992299999999999002222006cccccc1ccc11ccccccccccc000000000000000000000000000000000000000000000000000000000000000000000000
2898989299922999989898980029920066c6c6c1ccc11cccc6c6c6c6000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002200000000000044000000005ccccc65
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000cc00000000000044000000002ccccc22
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000cc000000000000cc000000002ccccc22
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000cc000000000000cc000000002ccccc22
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000cc000000000000cc0000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000cc000000000000cc0000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000022000000000000cc0000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000022000000000000445ccccc6400000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000033555555555555555555533333333333
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000035ccccccccccccccccccc63333333333
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000005ccccccccccccccccccccc6333333333
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000005ccccccccccccccccccccc6333333333
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000005ccccccccccccccccccccc6333333333
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000005ccccccccccccccccccccc6333333333
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000005cccccc666666666cccccc6333333333
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000005ccccc63333333335ccccc6333333333
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000005ccccc63333333335ccccc635ccccc63
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000005cccccc555555555cccccc635ccccc63
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000005ccccccccccccccccccccc635ccccc63
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000005ccccccccccccccccccccc635ccccc63
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000005ccccccccccccccccccccc635ccccc63
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000006ccccccccccccccccccccc635ccccc63
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000036ccccccccccccccccccc6335ccccc63
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000003366666666666666666663335ccccc63
__gff__
00000000000000000021212100210303000000000000000000212121060a12090000000000000000002121210303031100000000000000000021212103030303464a5200868a92000000000000000000000000000000000000002121000000210000002100000000000005050000000500000005000000000000050500000005
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__map__
6f6f6f6f6f6f6f00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
6f6f6f6f6f6f6f00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
6f6f6f406f6f6f00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
6f6f6f426f6f6f00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
6f6f6f6f6f6f6f00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
6f6f6f6f6f6f6f00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
6f6f6f6f6f6f6f00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
6f6f6f466f6f6f00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
6f6f6f446f6f6f00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
6f6f6f6f6f6f6f00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
6f6f6f6f6f6f6f00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
6f6f6f6f6f6f6f00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
6f6f6f6f6f6f6f00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
6f6f6f6f6f6f6f00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
