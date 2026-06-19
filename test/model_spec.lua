-- The node model over a real (temp) filesystem. Run with `nxvim --test-plugin`.
--
-- model.load/expand await nx.fs, and an `it` body already runs inside an nx.async
-- coroutine, so we can drive them directly (no view, no dock — pure tree shape).

local model = require("nxvim-tree.model")
local fs = nx.fs

-- A minimal tree state: model only reads `config.hidden` / `config.dirs_first`.
local function new_tree(root, opts)
  opts = opts or {}
  return {
    config = { hidden = opts.hidden or false, dirs_first = opts.dirs_first ~= false },
    root = model.root(root),
  }
end

local function names(nodes)
  local out = {}
  for _, n in ipairs(nodes) do
    out[#out + 1] = n.name
  end
  return out
end

nx.test.describe("nxvim-tree.model", function()
  local ROOT
  nx.test.before_each(function()
    ROOT = nx.test.tempdir()
    nx.await(fs.write(model.join(ROOT, "readme.txt"), "hi"))
    nx.await(fs.write(model.join(ROOT, "apple.txt"), ""))
    nx.await(fs.mkdir(model.join(ROOT, "src")))
    nx.await(fs.write(model.join(ROOT, "src/main.lua"), ""))
    nx.await(fs.write(model.join(ROOT, ".hidden"), ""))
  end)

  nx.test.it("descends only into expanded+loaded directories (lazy)", function()
    local tree = new_tree(ROOT)
    -- The root is pre-marked expanded but NOT yet loaded → flatten shows only it.
    nx.test.expect(#model.flatten(tree.root)).to_be(1)
    model.expand(tree, tree.root)
    -- A child directory is listed but its own children aren't loaded until expanded.
    local src = model.find_child(tree.root, "src")
    nx.test.expect(src.loaded).to_be_falsy()
  end)

  nx.test.it("sorts directories first, then alpha; hides dotfiles", function()
    local tree = new_tree(ROOT, { hidden = false })
    model.expand(tree, tree.root)
    local ns = names(model.flatten(tree.root))
    -- ns[1] is the root header (its name is the full path); children follow.
    nx.test.expect(ns[2]).to_be("src") -- directory first
    nx.test.expect(ns[3]).to_be("apple.txt") -- then files, alpha
    nx.test.expect(ns[4]).to_be("readme.txt")
    nx.test.expect(ns).never.to_contain(".hidden")
  end)

  nx.test.it("includes dotfiles when hidden = true", function()
    local tree = new_tree(ROOT, { hidden = true })
    model.expand(tree, tree.root)
    nx.test.expect(names(model.flatten(tree.root))).to_contain(".hidden")
  end)

  nx.test.it("expand_all loads and opens every descendant", function()
    local tree = new_tree(ROOT)
    model.expand_all(tree, tree.root)
    local ns = names(model.flatten(tree.root))
    nx.test.expect(ns).to_contain("main.lua") -- the nested file is now visible
  end)

  nx.test.it("refresh preserves expansion and node identity", function()
    local tree = new_tree(ROOT)
    model.expand(tree, tree.root)
    local src = model.find_child(tree.root, "src")
    model.expand(tree, src)
    -- Add a sibling on disk, then refresh.
    nx.await(fs.write(model.join(ROOT, "zeta.txt"), ""))
    model.refresh(tree, tree.root)
    -- src is the SAME node object and still expanded; the new file showed up.
    nx.test.expect(model.find_child(tree.root, "src")).to_be(src)
    nx.test.expect(src.expanded).to_be_truthy()
    nx.test.expect(names(tree.root.children)).to_contain("zeta.txt")
  end)
end)
