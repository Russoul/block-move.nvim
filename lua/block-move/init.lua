local M = {}

local noop = function() end

local function composition(f, g)
  return function()
    f()
    g()
  end
end

--- Pad the 0-indexed line at {linenum} in buffer {bufnum} with spaces on the right
--- until its character count is at least {atleastcol}.
--- @param bufnum number
--- @param linenum number
--- @param atleastcol number
local function pad(bufnum, linenum, atleastcol)
  local line = unpack(vim.api.nvim_buf_get_lines(bufnum, linenum, linenum + 1, true))

  local numchars = vim.fn.strchars(line, true)

  if numchars < atleastcol then
    vim.api.nvim_buf_set_lines(bufnum, linenum, linenum + 1, true, { line .. string.rep(" ", atleastcol - numchars) })
  end
end

--- Split the line at {linenum} in buffer {bufnum} into 3 subparts by 0-indexed visual character columns {startinc} and {endexc}
--- @param bufnum number
--- @param linenum number
--- @param startinc number
--- @param endexc number
--- @return string, string, string
local function splitAt(bufnum, linenum, startinc, endexc)
  local line = unpack(vim.api.nvim_buf_get_lines(bufnum, linenum, linenum + 1, true))

  -- 1-indexed
  local startincbyte = 1 + vim.fn.strlen(vim.fn.strcharpart(line, 0, startinc, true))
  -- 1-indexed
  local endexcbyte = 1 + vim.fn.strlen(vim.fn.strcharpart(line, 0, endexc, true))

  local prefix = string.sub(line, 1, startincbyte - 1)
  local infix = string.sub(line, startincbyte, endexcbyte - 1)
  local postfix = string.sub(line, endexcbyte)

  return prefix, infix, postfix
end

--- If possible, exchanges the selection spanned by 0-indexed visual character columns {startinc} and {endexc}
--- at 0-indexed line {linenum} in buffer {bufnum} with the corresponding characters in the previous line in the same buffer.
--- If there aren't enough characters in the previous line, pads that line with space on the right until it has just enough space for a swap.
--- Returns nil if there is nowhere to move the selection. Returns a nullary function that performs the exchange otherwise.
--- @param bufnum number
--- @param linenum number
--- @param startinc number
--- @param endexc number
--- @return nil|function
local function moveLineSelectionUp(bufnum, linenum, startinc, endexc)
  if linenum - 1 < 0 then
    return nil
  end

  pad(bufnum, linenum - 1, endexc)

  local prefix, infix, postfix = splitAt(bufnum, linenum, startinc, endexc)

  local prefixprevious, infixprevious, postfixprevious = splitAt(bufnum, linenum - 1, startinc, endexc)

  local newline = prefix .. infixprevious .. postfix
  local newlineprevious = prefixprevious .. infix .. postfixprevious

  return function()
    vim.api.nvim_buf_set_lines(bufnum, linenum, linenum + 1, true, { newline })
    vim.api.nvim_buf_set_lines(bufnum, linenum - 1, linenum, true, { newlineprevious })
  end
end

--- Exchanges the selection spanned by 0-indexed visual character columns {startinc} and {endexc}
--- at 0-indexed line {linenum} in buffer {bufnum} with the corresponding characters in the next line in the same buffer.
--- If there aren't enough characters in the next line, pads that line with space on the right until it has just enough space for a swap.
--- If there is no line below, adds an empty one and pads it with space just enough.
--- Returns a nullary function that performs the exchange.
--- @param bufnum number
--- @param linenum number
--- @param startinc number
--- @param endexc number
--- @return function
local function moveLineSelectionDown(bufnum, linenum, startinc, endexc)
  local numLines = #vim.api.nvim_buf_get_lines(bufnum, 0, -1, true)

  if linenum + 1 >= numLines then
    vim.api.nvim_buf_set_lines(bufnum, linenum + 1, linenum + 1, true, { "" })
    return moveLineSelectionDown(bufnum, linenum, startinc, endexc)
  end

  pad(bufnum, linenum + 1, endexc)

  local prefix, infix, postfix = splitAt(bufnum, linenum, startinc, endexc)

  local prefixnext, infixnext, postfixnext = splitAt(bufnum, linenum + 1, startinc, endexc)

  local newline = prefix .. infixnext .. postfix
  local newlinenext = prefixnext .. infix .. postfixnext

  return function()
    vim.api.nvim_buf_set_lines(bufnum, linenum, linenum + 1, true, { newline })
    vim.api.nvim_buf_set_lines(bufnum, linenum + 1, linenum + 2, true, { newlinenext })
  end
end

--- Exchanges the selection spanned by 0-indexed visual character columns {startinc} and {endexc}
--- at 0-indexed line {linenum} in buffer {bufnum} with the character immediately next to it on the right.
--- If there are no more characters on the right, insert one space.
--- Returns a nullary function that performs the exchange.
--- @param bufnum number
--- @param linenum number
--- @param startinc number
--- @param endexc number
--- @return function
local function moveLineSelectionRight(bufnum, linenum, startinc, endexc)
  pad(bufnum, linenum, endexc + 1)

  local prefix, infix1, _ = splitAt(bufnum, linenum, startinc, endexc)

  local _, infix2, postfix = splitAt(bufnum, linenum, endexc, endexc + 1)

  return function()
    vim.api.nvim_buf_set_lines(bufnum, linenum, linenum + 1, true,
      { prefix .. infix2 .. infix1 .. postfix })
  end
end

--- If possible, exchanges the selection spanned by 0-indexed visual character columns {startinc} and {endexc}
--- at 0-indexed line {linenum} in buffer {bufnum} with the character immediately next to it on the left.
--- If there is no character preceding the selection, returns nil.
--- Returns a nullary function that performs the exchange otherwise.
--- @param bufnum number
--- @param linenum number
--- @param startinc number
--- @param endexc number
--- @return nil|function
local function moveLineSelectionLeft(bufnum, linenum, startinc, endexc)
  -- Nowhere to move: there is no space to the left of the selection
  if startinc == 0 then
    return nil
  end

  local _, infix2, postfix = splitAt(bufnum, linenum, startinc, endexc)

  local prefix, infix1, _ = splitAt(bufnum, linenum, startinc - 1, startinc)

  return function()
    vim.api.nvim_buf_set_lines(bufnum, linenum, linenum + 1, true,
      { prefix .. infix2 .. infix1 .. postfix })
  end
end

function M.moveSelectionDown()
  local bufnr = vim.fn.getpos("'<")[1]
  local lineLeft1 = vim.fn.line("'<")
  local colLeft1 = vim.fn.charcol("'<")
  local colRight1 = vim.fn.charcol("'>")
  local lineRight1 = vim.fn.line("'>")

  local lineStart1 = math.min(lineLeft1, lineRight1)
  local colStart1 = math.min(colLeft1, colRight1)
  local colEnd1 = math.max(colLeft1, colRight1)
  local lineEnd1 = math.max(lineLeft1, lineRight1)

  local colStart0 = colStart1 - 1
  local colEnd0 = colEnd1

  -- Ensure the line below the selection exists
  local numLines = #vim.api.nvim_buf_get_lines(bufnr, 0, -1, true)
  if lineEnd1 >= numLines then
    vim.api.nvim_buf_set_lines(bufnr, numLines, numLines, true, { "" })
  end

  local lineBelow1 = lineEnd1 + 1

  for linei1 = lineStart1, lineBelow1 do
    pad(bufnr, linei1 - 1, colEnd0)
  end

  -- Capture all line parts from the original buffer state
  local parts = {}
  for linei1 = lineStart1, lineBelow1 do
    local prefix, infix, postfix = splitAt(bufnr, linei1 - 1, colStart0, colEnd0)
    parts[linei1] = { prefix = prefix, infix = infix, postfix = postfix }
  end

  -- Rotation: the line below comes to the top; the selection shifts down one row
  local computation = noop
  for linei1 = lineStart1, lineBelow1 do
    local linei0 = linei1 - 1
    local srcInfix = linei1 == lineStart1 and parts[lineBelow1].infix or parts[linei1 - 1].infix
    local newLine = parts[linei1].prefix .. srcInfix .. parts[linei1].postfix
    computation = composition(computation, function()
      vim.api.nvim_buf_set_lines(bufnr, linei0, linei0 + 1, true, { newLine })
    end)
  end

  computation()

  vim.fn.setcharpos("'<", { bufnr, lineStart1 + 1, colStart1, 0 })
  vim.fn.setcharpos("'>", { bufnr, lineEnd1 + 1, colEnd1, 0 })

  vim.cmd("normal! gv")
end

function M.moveSelectionUp()
  local bufnr = vim.fn.getpos("'<")[1]
  local lineLeft1 = vim.fn.line("'<")
  local colLeft1 = vim.fn.charcol("'<")
  local colRight1 = vim.fn.charcol("'>")
  local lineRight1 = vim.fn.line("'>")

  local lineStart1 = math.min(lineLeft1, lineRight1)
  local colStart1 = math.min(colLeft1, colRight1)
  local colEnd1 = math.max(colLeft1, colRight1)
  local lineEnd1 = math.max(lineLeft1, lineRight1)

  if lineStart1 == 1 then
    vim.cmd("normal! gv")
    return
  end

  local colStart0 = colStart1 - 1
  local colEnd0 = colEnd1

  local lineAbove1 = lineStart1 - 1

  for linei1 = lineAbove1, lineEnd1 do
    pad(bufnr, linei1 - 1, colEnd0)
  end

  -- Capture all line parts from the original buffer state
  local parts = {}
  for linei1 = lineAbove1, lineEnd1 do
    local prefix, infix, postfix = splitAt(bufnr, linei1 - 1, colStart0, colEnd0)
    parts[linei1] = { prefix = prefix, infix = infix, postfix = postfix }
  end

  -- Rotation: the top of the selection goes above; the line above rotates to the bottom
  local computation = noop
  for linei1 = lineAbove1, lineEnd1 do
    local linei0 = linei1 - 1
    local srcInfix = linei1 == lineEnd1 and parts[lineAbove1].infix or parts[linei1 + 1].infix
    local newLine = parts[linei1].prefix .. srcInfix .. parts[linei1].postfix
    computation = composition(computation, function()
      vim.api.nvim_buf_set_lines(bufnr, linei0, linei0 + 1, true, { newLine })
    end)
  end

  computation()

  vim.fn.setcharpos("'<", { bufnr, lineStart1 - 1, colStart1, 0 })
  vim.fn.setcharpos("'>", { bufnr, lineEnd1 - 1, colEnd1, 0 })

  vim.cmd("normal! gv")
end

function M.moveSelectionRight()
  local bufnr = vim.fn.getpos("'<")[1]

  local lineLeft1 = vim.fn.line("'<")
  local colLeft1 = vim.fn.charcol("'<")
  local colRight1 = vim.fn.charcol("'>")
  local lineRight1 = vim.fn.line("'>")

  local lineStart1 = math.min(lineLeft1, lineRight1)
  local colStart1 = math.min(colLeft1, colRight1)
  local colEnd1 = math.max(colLeft1, colRight1)
  local lineEnd1 = math.max(lineLeft1, lineRight1)

  local toMove = true
  local computation = noop
  for linei1 = lineStart1, lineEnd1 do
    local linei0 = linei1 - 1
    local closure = moveLineSelectionRight(bufnr, linei0, colStart1 - 1, colEnd1)
    -- All sub-lines must be movable in order for the block move to succeed
    if closure then
      computation = composition(computation, closure)
    else
      toMove = false
      break
    end
  end

  if toMove then
    computation()
    vim.fn.setcharpos("'<", { bufnr, lineStart1, colStart1 + 1, 0 })
    vim.fn.setcharpos("'>", { bufnr, lineEnd1, colEnd1 + 1, 0 })
  end

  vim.cmd("normal! gv")
end

function M.moveSelectionLeft()
  local bufnr = vim.fn.getpos("'<")[1]
  local lineLeft1 = vim.fn.line("'<")
  local colLeft1 = vim.fn.charcol("'<")
  local colRight1 = vim.fn.charcol("'>")
  local lineRight1 = vim.fn.line("'>")

  local lineStart1 = math.min(lineLeft1, lineRight1)
  local colStart1 = math.min(colLeft1, colRight1)
  local colEnd1 = math.max(colLeft1, colRight1)
  local lineEnd1 = math.max(lineLeft1, lineRight1)

  local toMove = true
  local computation = noop
  for linei1 = lineStart1, lineEnd1 do
    local linei0 = linei1 - 1
    local closure = moveLineSelectionLeft(bufnr, linei0, colStart1 - 1, colEnd1)
    -- All sub-lines must be movable in order for the block move to succeed
    if closure then
      computation = composition(computation, closure)
    else
      toMove = false
      break
    end
  end

  if toMove then
    computation()
    vim.fn.setcharpos("'<", { bufnr, lineStart1, colStart1 - 1, 0 })
    vim.fn.setcharpos("'>", { bufnr, lineEnd1, colEnd1 - 1, 0 })
  end

  vim.cmd("normal! gv")
end

--- @class BlockMoveKeymaps
--- @field up    string|false  keymap to move selection up    (false to disable)
--- @field down  string|false  keymap to move selection down  (false to disable)
--- @field left  string|false  keymap to move selection left  (false to disable)
--- @field right string|false  keymap to move selection right (false to disable)

--- @class BlockMoveOpts
--- @field keymaps BlockMoveKeymaps|false  pass false to skip all keymap setup

--- @param opts BlockMoveOpts|nil
function M.setup(opts)
  opts = opts or {}
  local keymaps = opts.keymaps
  if not keymaps then
    return
  end

  local map = vim.keymap.set
  local function bind(key, fn)
    if key then
      map('v', key, fn, { noremap = true, silent = true })
    end
  end

  bind(keymaps.up,    M.moveSelectionUp)
  bind(keymaps.down,  M.moveSelectionDown)
  bind(keymaps.left,  M.moveSelectionLeft)
  bind(keymaps.right, M.moveSelectionRight)
end

return M
