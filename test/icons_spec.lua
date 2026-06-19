-- Icon resolution. Pure lookups, run with `nxvim --test-plugin`.

local icons = require("nxvim-tree.icons")

local function file(name)
  return { type = "file", name = name }
end

nx.test.describe("nxvim-tree.icons", function()
  nx.test.it("resolves by extension", function()
    local _, hl = icons.get(file("main.rs"), { icons = true })
    nx.test.expect(hl).to_be("NxTreeIconRust")
  end)

  nx.test.it("prefers an exact filename over its extension", function()
    -- Cargo.toml is a .toml file but has its own (rust) icon entry.
    local _, hl = icons.get(file("Cargo.toml"), { icons = true })
    nx.test.expect(hl).to_be("NxTreeIconRust")
  end)

  nx.test.it("falls back to the default for an unknown kind", function()
    local _, hl = icons.get(file("mystery.zzz"), { icons = true })
    nx.test.expect(hl).to_be("NxTreeIconDefault")
  end)

  nx.test.it("uses the folder glyph for directories, open vs closed", function()
    local closed_glyph =
      select(1, icons.get({ type = "directory", expanded = false }, { icons = true }))
    local open_glyph =
      select(1, icons.get({ type = "directory", expanded = true }, { icons = true }))
    nx.test.expect(closed_glyph).never.to_be(open_glyph)
  end)

  nx.test.it("register() extends the registry", function()
    icons.register({ zzz = { glyph = "Z", hl = "NxTreeIconText" } })
    local _, hl = icons.get(file("mystery.zzz"), { icons = true })
    nx.test.expect(hl).to_be("NxTreeIconText")
  end)

  nx.test.it("renders ASCII markers when icons are off", function()
    local glyph = select(1, icons.get(file("main.rs"), { icons = false }))
    -- The ASCII file marker is a plain blank (no Nerd-Font glyph).
    nx.test.expect(glyph).to_be(" ")
  end)
end)
