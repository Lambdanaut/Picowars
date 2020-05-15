priorityqueue = {}
priorityqueue.__index = priorityqueue

function priorityqueue.new()
  local newqueue = {}
  setmetatable(newqueue, priorityqueue)

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

function priorityqueue:add(newvalue, priority)
  insert(self.values, newvalue)
  insert(self.priorities, priority)

  if #self.values <= 1 then
    return
  end

  siftup(self, #self.values)
end

function priorityqueue:pop()
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

  return returnval, returnpriority
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

return priorityqueue
