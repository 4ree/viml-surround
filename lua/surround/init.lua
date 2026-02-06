local M = {}

-- Pair lookup for visual surround (opening variant = tight, closing variant = spaced)
local surround_pairs = {
  ["("] = { "(", ")" },   [")"] = { "( ", " )" },
  ["["] = { "[", "]" },   ["]"] = { "[ ", " ]" },
  ["{"] = { "{", "}" },   ["}"] = { "{ ", " }" },
  ["<"] = { "<", ">" },   [">"] = { "< ", " >" },
  ["'"] = { "'", "'" },
  ['"'] = { '"', '"' },
  ["`"] = { "`", "`" },
}

-- Search patterns for finding surrounding pairs (used by searchpairpos)
local search_pairs = {
  ["("] = { "(",  ")" },  [")"] = { "(",  ")" },
  ["["] = { "\\[", "\\]" }, ["]"] = { "\\[", "\\]" },
  ["{"] = { "[{]", "[}]" }, ["}"] = { "[{]", "[}]" },
  ["<"] = { "<",  ">" },  [">"] = { "<",  ">" },
}

local function get_char()
  local ok, nr = pcall(vim.fn.getchar)
  if not ok then return nil end
  if type(nr) == "number" then
    return nr == 27 and nil or vim.fn.nr2char(nr)
  end
  return nr
end

function M.get_pair(char)
  if char == "t" then
    local tag = vim.fn.input("Enter tag: ")
    if tag == "" then return nil, nil end
    local name = tag:match("^(%S+)")
    return "<" .. tag .. ">", "</" .. name .. ">"
  end
  local pair = surround_pairs[char]
  if pair then return pair[1], pair[2] end
  return char, char
end

function M.find_surrounding(char)
  local save = vim.fn.getpos(".")

  if char == "t" then
    local open_pos = vim.fn.searchpairpos("<\\w", "", ">", "bnW")
    if open_pos[1] == 0 then return nil end
    vim.fn.setpos(".", { 0, open_pos[1], open_pos[2], 0 })
    local open_end = vim.fn.searchpos(">", "nW")
    vim.fn.setpos(".", save)

    local close_start = vim.fn.searchpairpos("<\\w", "", "</\\w\\+>", "nW")
    if close_start[1] == 0 then return nil end
    vim.fn.setpos(".", { 0, close_start[1], close_start[2], 0 })
    local close_end = vim.fn.searchpos(">", "nW")
    vim.fn.setpos(".", save)

    return {
      open  = { open_pos[1], open_pos[2], open_end[1], open_end[2] },
      close = { close_start[1], close_start[2], close_end[1], close_end[2] },
    }
  end

  local open_pos, close_pos
  local sp = search_pairs[char]
  if sp then
    open_pos  = vim.fn.searchpairpos(sp[1], "", sp[2], "bnW")
    close_pos = vim.fn.searchpairpos(sp[1], "", sp[2], "nW")
  else
    local escaped = "\\V" .. vim.fn.escape(char, "\\")
    open_pos  = vim.fn.searchpos(escaped, "bnW")
    close_pos = vim.fn.searchpos(escaped, "nW")
  end

  vim.fn.setpos(".", save)
  if open_pos[1] == 0 or close_pos[1] == 0 then return nil end

  return {
    open  = { open_pos[1], open_pos[2], open_pos[1], open_pos[2] },
    close = { close_pos[1], close_pos[2], close_pos[1], close_pos[2] },
  }
end

function M.delete_surround()
  local char = get_char()
  if not char then return end

  local result = M.find_surrounding(char)
  if not result then
    vim.notify("No surrounding " .. char .. " found", vim.log.levels.WARN)
    return
  end

  local save = vim.fn.winsaveview()
  local o, c = result.open, result.close

  -- Remove close first (so open positions stay valid)
  local cline = vim.fn.getline(c[1])
  if char == "t" then
    vim.fn.setline(c[1], cline:sub(1, c[2] - 1) .. cline:sub(c[4] + 1))
  else
    vim.fn.setline(c[1], cline:sub(1, c[2] - 1) .. cline:sub(c[2] + 1))
  end

  -- Remove open
  local oline = vim.fn.getline(o[1])
  if char == "t" then
    vim.fn.setline(o[1], oline:sub(1, o[2] - 1) .. oline:sub(o[4] + 1))
  else
    vim.fn.setline(o[1], oline:sub(1, o[2] - 1) .. oline:sub(o[2] + 1))
  end

  vim.fn.winrestview(save)
end

function M._add_operatorfunc(type)
  local char = get_char()
  if not char then return end

  local open, close = M.get_pair(char)
  if not open then return end

  local s = vim.fn.getpos("'[")
  local e = vim.fn.getpos("']")

  if type == "line" then
    vim.fn.append(e[2], close)
    vim.fn.append(s[2] - 1, open)
  elseif s[2] == e[2] then
    local line = vim.fn.getline(s[2])
    vim.fn.setline(s[2],
      line:sub(1, s[3] - 1) .. open ..
      line:sub(s[3], e[3]) .. close ..
      line:sub(e[3] + 1))
  else
    local el = vim.fn.getline(e[2])
    vim.fn.setline(e[2], el:sub(1, e[3]) .. close .. el:sub(e[3] + 1))
    local sl = vim.fn.getline(s[2])
    vim.fn.setline(s[2], sl:sub(1, s[3] - 1) .. open .. sl:sub(s[3]))
  end
end

function M.add_surround()
  vim.o.operatorfunc = "v:lua.require'surround'._add_operatorfunc"
  return "g@"
end

function M.add_surround_line()
  vim.o.operatorfunc = "v:lua.require'surround'._add_operatorfunc"
  return "g@_"
end

function M.visual_surround()
  local char = get_char()
  if not char then return end

  local open, close = M.get_pair(char)
  if not open then return end

  local s = vim.fn.getpos("'<")
  local e = vim.fn.getpos("'>")
  local mode = vim.fn.visualmode()

  if mode == "V" then
    -- Linewise: put open/close on their own lines
    vim.fn.append(e[2], close)
    vim.fn.append(s[2] - 1, open)
  elseif s[2] == e[2] then
    -- Same line
    local line = vim.fn.getline(s[2])
    vim.fn.setline(s[2],
      line:sub(1, s[3] - 1) .. open ..
      line:sub(s[3], e[3]) .. close ..
      line:sub(e[3] + 1))
  else
    -- Multi-line: wrap end first so start positions stay valid
    local el = vim.fn.getline(e[2])
    vim.fn.setline(e[2], el:sub(1, e[3]) .. close .. el:sub(e[3] + 1))
    local sl = vim.fn.getline(s[2])
    vim.fn.setline(s[2], sl:sub(1, s[3] - 1) .. open .. sl:sub(s[3]))
  end
end

return M
