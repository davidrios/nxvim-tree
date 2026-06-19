-- Config merge + validation. Pure (no editor state), run with `nxvim --test-plugin`.

local config = require("nxvim-tree.config")

nx.test.describe("nxvim-tree.config", function()
  nx.test.it("defaults() hands out an independent copy each call", function()
    local a = config.defaults()
    local b = config.defaults()
    a.width = 999
    a.mappings["zz"] = "refresh"
    nx.test.expect(b.width).never.to_be(999)
    nx.test.expect(b.mappings["zz"]).to_be_nil()
  end)

  nx.test.it("merges scalars and merges mappings key-by-key", function()
    local cfg = config.merge(config.defaults(), {
      width = 40,
      mappings = { ["X"] = "delete", ["a"] = false },
    })
    nx.test.expect(cfg.width).to_be(40)
    -- the user's new key is present…
    nx.test.expect(cfg.mappings["X"]).to_be("delete")
    -- …their disabled default survives as `false`…
    nx.test.expect(cfg.mappings["a"]).to_be(false)
    -- …and the untouched defaults are still there.
    nx.test.expect(cfg.mappings["<CR>"]).to_be("select")
  end)

  nx.test.it("accepts a function as a custom mapping", function()
    local cfg = config.merge(config.defaults(), { mappings = { ["g?"] = function() end } })
    nx.test.expect(type(cfg.mappings["g?"])).to_be("function")
  end)

  nx.test.it("rejects an unknown action name (fails loud)", function()
    nx.test
      .expect(function()
        config.merge(config.defaults(), { mappings = { ["z"] = "does_not_exist" } })
      end)
      .to_error("unknown action")
  end)

  nx.test.it("rejects an invalid position", function()
    nx.test
      .expect(function()
        config.merge(config.defaults(), { position = "middle" })
      end)
      .to_error("position")
  end)

  nx.test.it("rejects a non-positive width", function()
    nx.test
      .expect(function()
        config.merge(config.defaults(), { width = 0 })
      end)
      .to_error("width")
  end)
end)
