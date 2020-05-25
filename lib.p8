pico-8 cartridge // http://www.pico-8.com
version 27
__lua__

function get_tile_info(tile)
  -- returns the {tile name, its defense, its structure type(if applicable), and its team(if applicable)}
  if fget(tile, 1) then
    local team
    if fget(tile, 6) then team = players[1] elseif fget(tile, 7) then team = players[2] end
    if fget(tile, 2) then return {"hq★★★★", 0.25, 1, team}
    elseif fget(tile, 3) then return {"city★★★", 0.4, 2, team}
    elseif fget(tile, 4) then return {"base★★★", 0.4, 3, team}
    end
  end
  if fget(tile, 0) then
    if fget(tile, 1) then return {"road", 1.0}
    elseif fget(tile, 6) then return {"plain★", 0.8}
    elseif fget(tile, 3) then return {"wood★★", 0.6}
    elseif fget(tile, 4) then return {"mntn★★★★", 0.25}
    elseif fget(tile, 2) then return {"river", 1.0}
    elseif fget(tile, 5) then return {"cliff", 1.0}
    end
  end
  return {"unmovable", 0} -- no info
end