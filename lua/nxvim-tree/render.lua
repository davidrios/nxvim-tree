-- nxvim-tree.render — project the model into view lines + extmark decoration.
--
-- `render(tree[, opts])` flattens the (optionally filtered) tree, builds one display
-- line per visible node — `<indent guides><icon> <name>` — pushes them through
-- `view:set_lines` / `view:set_userdata` (userdata[i] is the node, so on_select gets
-- it directly), and computes a parallel batch of extmarks: indent-guide color, icon
-- color, name color (root/dir/file/link), a clipboard tint for a pending cut/copy,
-- plus whatever the registered decorators contribute (git signs, diagnostics, …).
--
-- Decoration needs the view's real buffer number, which only exists once the
-- create/mount ops have drained, so the `set_decor` is deferred a tick with
-- `nx.schedule` (the buffer is stable by then).
--
-- `opts.restore_cursor` (default false): after replacing the lines, move the cursor
-- back onto the node it was on. Done ONLY when the tree window is the focused window
-- — `view:set_cursor` focuses the view, so restoring during a background (watch)
-- refresh would yank focus out of the editor. Action handlers pass it true.

local model = require("nxvim-tree.model")
local icons = require("nxvim-tree.icons")

local M = {}

-- The tree-guide prefix for a node: a bar for each ancestor that still has siblings
-- below it, then a "├ "/"└ " connector for the node itself. Root (depth 0) has none.
-- Box-drawing segments are 4 bytes, blanks 2 — the caller measures with `#prefix` so
-- the column math stays byte-exact.
local function guide(node)
  if node.depth == 0 then
    return ""
  end
  local connector = node._last and "└ " or "├ "
  local bars = ""
  local p = node.parent
  while p and p.depth >= 1 do
    bars = (p._last and "  " or "│ ") .. bars
    p = p.parent
  end
  return bars .. connector
end

-- Keep only nodes whose name matches the (case-insensitive substring) filter, plus
-- the ancestors of every match so the path to a hit stays visible.
local function apply_filter(entries, filter)
  local needle = filter:lower()
  local keep = {}
  for _, n in ipairs(entries) do
    if n.depth == 0 or n.name:lower():find(needle, 1, true) then
      keep[n] = true
      local p = n.parent
      while p do
        keep[p] = true
        p = p.parent
      end
    end
  end
  local out = {}
  for _, n in ipairs(entries) do
    if keep[n] then
      out[#out + 1] = n
    end
  end
  return out
end

-- The display name for a node: the full path for the root header (with the filter
-- shown when one is active), the basename otherwise, directories suffixed "/".
local function display_name(tree, node)
  if node.depth == 0 then
    local name = node.path
    if tree.filter and tree.filter ~= "" then
      name = name .. "  (/" .. tree.filter .. ")"
    end
    return name
  end
  if node.type == "directory" then
    return node.name .. "/"
  end
  return node.name
end

-- The name highlight for a node.
local function name_hl(node)
  if node.depth == 0 then
    return "NxTreeRoot"
  elseif node.type == "directory" then
    return "NxTreeFolderName"
  elseif node.type == "link" then
    return "NxTreeLinkName"
  end
  return "NxTreeFileName"
end

-- render(tree, opts) — rebuild the view's content and decoration from the model.
function M.render(tree, opts)
  opts = opts or {}

  -- Remember the node under the cursor so we can land back on it after the rebuild.
  local keep
  if opts.restore_cursor then
    local line = tree.view:line()
    keep = line and tree.flat[line]
  end

  local entries = model.flatten(tree.root)
  if tree.filter and tree.filter ~= "" then
    entries = apply_filter(entries, tree.filter)
  end

  local lines, userdata, marks = {}, {}, {}
  for i, node in ipairs(entries) do
    local prefix = guide(node)
    local glyph, ghl = icons.get(node, tree.config)
    local text = prefix .. glyph .. " " .. display_name(tree, node)
    lines[i] = text
    userdata[i] = node

    local line = i - 1
    local pbytes = #prefix
    local gbytes = #glyph
    local name_col = pbytes + gbytes + 1 -- after "<prefix><glyph> "
    local eol = #text

    if pbytes > 0 then
      marks[#marks + 1] =
        { line = line, col = 0, end_row = line, end_col = pbytes, hl_group = "NxTreeIndent" }
    end
    marks[#marks + 1] =
      { line = line, col = pbytes, end_row = line, end_col = pbytes + gbytes, hl_group = ghl }

    -- A pending cut/copy source paints its name with the clipboard tint instead.
    local clip = tree._clipboard
    local hl = (clip and clip.node == node) and "NxTreeClipboard" or name_hl(node)
    marks[#marks + 1] =
      { line = line, col = name_col, end_row = line, end_col = eol, hl_group = hl }

    -- Decorators: each returns nil or { sign_text=, sign_hl=, hl=, virt_text= }.
    for _, dec in ipairs(tree.config._decorators or {}) do
      local d = dec(node)
      if d then
        if d.sign_text then
          marks[#marks + 1] =
            { line = line, col = 0, sign_text = d.sign_text, sign_hl_group = d.sign_hl }
        end
        if d.hl then
          marks[#marks + 1] =
            { line = line, col = name_col, end_row = line, end_col = eol, hl_group = d.hl }
        end
        if d.virt_text then
          marks[#marks + 1] = { line = line, col = eol, virt_text = d.virt_text }
        end
      end
    end
  end

  tree.flat = entries
  tree.view:set_lines(lines)
  tree.view:set_userdata(userdata)

  -- Restore the cursor onto the same node — only while the tree is focused, so a
  -- background refresh never steals focus from the editor (set_cursor focuses).
  if keep and nx.win.current() == tree.view:winid() then
    for i, n in ipairs(entries) do
      if n == keep then
        tree.view:set_cursor(i)
        break
      end
    end
  end

  -- set_decor needs the backing buffer; it exists by the next tick at the latest.
  nx.schedule(function()
    if tree.view:bufnr() then
      tree.view:set_decor(tree.ns, marks)
    end
  end)
end

return M
