-- nxvim-tree.model — the node tree, lazy directory loading, and flatten-to-visible.
--
-- A node is `{ path, name, type, depth, parent, expanded, loaded, children, _last }`:
--   path      absolute filesystem path
--   name      basename (the root node's `name` is its full path, shown as a header)
--   type      "file" | "directory" | "link"   (lstat-flavoured, from nx.fs.readdir)
--   depth     0 for the root, +1 per level
--   expanded  the directory is open (its children are shown)
--   loaded    the children were scandir'd at least once (lazy: only on first expand)
--   children  ordered child nodes (sorted; hidden filtered per cfg)
--   _last     true when this node is the last among its siblings (for tree guides)
--
-- Everything here is pure data + async fs reads — no editor calls. `load` (and the
-- callers that drive it: expand/refresh) await `nx.fs`, so run them inside an
-- `nx.async` coroutine; `flatten` / `node` / `find_child` are synchronous.

local M = {}

-- Join a directory path and a child name without doubling the separator.
function M.join(dir, name)
  if dir:sub(-1) == "/" then
    return dir .. name
  end
  return dir .. "/" .. name
end

-- node(path, name, type, depth, parent) -> a fresh unexpanded, unloaded node.
function M.node(path, name, typ, depth, parent)
  return {
    path = path,
    name = name,
    type = typ,
    depth = depth,
    parent = parent,
    expanded = false,
    loaded = false,
    children = {},
    _last = false,
  }
end

-- root(path) -> a root node (depth 0, pre-marked expanded so its children show once
-- loaded). The full path is the display name.
function M.root(path)
  -- Normalize away a trailing slash (except the filesystem root "/") so paths
  -- joined under it stay single-separator and the header reads cleanly.
  if #path > 1 and path:sub(-1) == "/" then
    path = path:sub(1, -2)
  end
  local n = M.node(path, path, "directory", 0, nil)
  n.expanded = true
  return n
end

-- Sort comparator honoring cfg.dirs_first; ties broken case-insensitively by name.
local function comparator(cfg)
  local dirs_first = not cfg or cfg.dirs_first ~= false
  return function(a, b)
    if dirs_first then
      local ad, bd = a.type == "directory", b.type == "directory"
      if ad ~= bd then
        return ad
      end
    end
    return a.name:lower() < b.name:lower()
  end
end

-- load(tree, node) — scandir `node` (ONE nx.fs.readdir round-trip, kind included),
-- build its child nodes sorted per cfg with the hidden filter applied, and mark it
-- `loaded`. Awaits; call inside nx.async. Re-loading preserves the expand/load state
-- of children that still exist (matched by name), so a refresh never collapses the
-- tree.
function M.load(tree, node)
  local entries = nx.await(nx.fs.readdir(node.path))
  table.sort(entries, comparator(tree.config))

  local prev = {}
  for _, c in ipairs(node.children) do
    prev[c.name] = c
  end

  local children = {}
  for _, e in ipairs(entries) do
    if tree.config.hidden or e.name:sub(1, 1) ~= "." then
      local existing = prev[e.name]
      if existing and existing.type == e.type then
        children[#children + 1] = existing -- keep the node (and its expanded subtree)
      else
        children[#children + 1] =
          M.node(M.join(node.path, e.name), e.name, e.type, node.depth + 1, node)
      end
    end
  end

  for i, c in ipairs(children) do
    c._last = (i == #children)
  end
  node.children = children
  node.loaded = true
end

-- expand(tree, node) — ensure `node` is loaded then mark it expanded. Awaits.
function M.expand(tree, node)
  if not node.loaded then
    M.load(tree, node)
  end
  node.expanded = true
end

-- expand_all(tree, node) — recursively load + expand `node` and every descendant
-- directory. Awaits; depth-first. Used by the `expand_all` action.
function M.expand_all(tree, node)
  M.expand(tree, node)
  for _, c in ipairs(node.children) do
    if c.type == "directory" then
      M.expand_all(tree, c)
    end
  end
end

-- collapse_all(node) — collapse `node` and every descendant (state kept; no fs).
function M.collapse_all(node)
  for _, c in ipairs(node.children) do
    if c.type == "directory" then
      M.collapse_all(c)
      c.expanded = false
    end
  end
end

-- refresh(tree, node) — re-scandir `node` and every still-loaded descendant directory,
-- preserving expansion. Awaits; call inside nx.async.
function M.refresh(tree, node)
  if not node.loaded then
    return
  end
  M.load(tree, node)
  for _, c in ipairs(node.children) do
    if c.type == "directory" and c.loaded then
      M.refresh(tree, c)
    end
  end
end

-- find_child(node, name) -> the child with that basename, or nil. Synchronous.
function M.find_child(node, name)
  for _, c in ipairs(node.children) do
    if c.name == name then
      return c
    end
  end
  return nil
end

-- flatten(root) -> ordered list of the visible nodes (depth-first, descending only
-- into expanded+loaded directories). The root is the first entry; the list is
-- parallel to the view's lines, so `list[i]` is the node on view line `i`.
function M.flatten(root)
  local out = {}
  local function walk(node)
    out[#out + 1] = node
    if node.type == "directory" and node.expanded and node.loaded then
      for _, c in ipairs(node.children) do
        walk(c)
      end
    end
  end
  walk(root)
  return out
end

return M
