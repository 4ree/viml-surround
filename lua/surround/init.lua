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

-- Bracket open/close mapping
local bracket_pair = {
  ["("] = { "(", ")" },  [")"] = { "(", ")" },
  ["["] = { "[", "]" },  ["]"] = { "[", "]" },
  ["{"] = { "{", "}" },  ["}"] = { "{", "}" },
  ["<"] = { "<", ">" },  [">"] = { "<", ">" },
}

local function find_bracket(open, close)
  local cur = vim.api.nvim_win_get_cursor(0)
  local crow, ccol = cur[1], cur[2] + 1
  local total = vim.api.nvim_buf_line_count(0)

  -- backward: find unmatched open
  local depth, orow, ocol = 0
  local found = false
  for lnum = crow, 1, -1 do
    local line = vim.fn.getline(lnum)
    local ec = lnum == crow and ccol or #line
    for c = ec, 1, -1 do
      local ch = line:sub(c, c)
      if ch == close and not (lnum == crow and c == ccol) then
        depth = depth + 1
      elseif ch == open then
        if depth == 0 then
          orow, ocol = lnum, c; found = true; break
        end
        depth = depth - 1
      end
    end
    if found then break end
  end
  if not found then return nil end

  -- forward: find matching close from open+1
  depth = 0; found = false
  local crow2, ccol2
  for lnum = orow, total do
    local line = vim.fn.getline(lnum)
    local sc = lnum == orow and ocol + 1 or 1
    for c = sc, #line do
      local ch = line:sub(c, c)
      if ch == open then depth = depth + 1
      elseif ch == close then
        if depth == 0 then
          crow2, ccol2 = lnum, c; found = true; break
        end
        depth = depth - 1
      end
    end
    if found then break end
  end
  if not found then return nil end

  return {
    open  = { orow, ocol, orow, ocol },
    close = { crow2, ccol2, crow2, ccol2 },
  }
end

local function find_quote(char)
  local cur = vim.api.nvim_win_get_cursor(0)
  local row, col = cur[1], cur[2] + 1
  local line = vim.fn.getline(row)

  local pos = {}
  for i = 1, #line do
    if line:sub(i, i) == char then pos[#pos + 1] = i end
  end

  for i = 1, #pos - 1, 2 do
    if pos[i] <= col and pos[i + 1] >= col then
      return {
        open  = { row, pos[i],     row, pos[i] },
        close = { row, pos[i + 1], row, pos[i + 1] },
      }
    end
  end
  return nil
end

local function find_tag()
  local save = vim.fn.getpos(".")
  local srow, scol = save[2], save[3]

  vim.fn.setpos(".", save)
  while true do
    local op = vim.fn.searchpos("<\\w", "bW")
    if op[1] == 0 then vim.fn.setpos(".", save); return nil end

    local line = vim.fn.getline(op[1])
    local tag = line:match("<(%w[%w%-]*)", op[2])
    if tag then
      local oe = vim.fn.searchpos(">", "nW")
      if oe[1] ~= 0 then
        local opat = "\\V<" .. tag .. "\\m\\>"
        local cpat = "\\V</" .. tag .. ">"
        local cs = vim.fn.searchpairpos(opat, "", cpat, "nW")
        if cs[1] ~= 0 then
          vim.fn.setpos(".", { 0, cs[1], cs[2], 0 })
          local ce = vim.fn.searchpos(">", "nW")
          if ce[1] ~= 0 then
            local after  = srow > op[1] or (srow == op[1] and scol >= op[2])
            local before = srow < ce[1] or (srow == ce[1] and scol <= ce[2])
            if after and before then
              vim.fn.setpos(".", save)
              return {
                open  = { op[1], op[2], oe[1], oe[2] },
                close = { cs[1], cs[2], ce[1], ce[2] },
              }
            end
          end
        end
      end
    end

    -- move before this match so next iteration searches further back
    if op[2] > 1 then
      vim.fn.setpos(".", { 0, op[1], op[2] - 1, 0 })
    elseif op[1] > 1 then
      vim.fn.setpos(".", { 0, op[1] - 1, #vim.fn.getline(op[1] - 1), 0 })
    else
      vim.fn.setpos(".", save); return nil
    end
  end
end

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
  if char == "t" then return find_tag() end
  local bp = bracket_pair[char]
  if bp then return find_bracket(bp[1], bp[2]) end
  return find_quote(char)
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
