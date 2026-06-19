-- nxvim-tree.highlights — the highlight palette and a fallback-only applier.
--
-- `apply(overrides)` installs the tree's highlight groups, but only as a FALLBACK:
-- an explicit user override always wins; otherwise a default is defined only when
-- the group is not already defined, so a colorscheme that already styles these
-- names (or the file-icon groups it shares with other plugins) keeps its colors.
--
-- The palette is Catppuccin-Mocha-ish so a bare `setup()` reads well on the default
-- dark background with no theme loaded. Group names are namespaced `NxTree*` so they
-- never collide with another plugin's.

local M = {}

-- name -> default spec (the `nx.hl.define` opts table). Structural groups first,
-- then the per-icon color groups (referenced from icons.lua).
M.defaults = {
  -- structure
  NxTreeRoot = { fg = "#f9e2af", bold = true }, -- the root header line
  NxTreeFolderName = { fg = "#89b4fa", bold = true }, -- a directory's name
  NxTreeFileName = { fg = "#cdd6f4" }, -- a file's name
  NxTreeLinkName = { fg = "#94e2d5", italic = true }, -- a symlink's name
  NxTreeIndent = { fg = "#45475a" }, -- the tree guide lines
  NxTreeFolderIcon = { fg = "#89b4fa" }, -- the open/closed folder glyph
  NxTreeClipboard = { fg = "#f38ba8", italic = true }, -- a cut/copied entry's name
  NxTreeFilter = { fg = "#a6adc8", italic = true }, -- the "/filter" header
  -- git (used by the optional git module)
  NxTreeGitNew = { fg = "#a6e3a1" },
  NxTreeGitModified = { fg = "#f9e2af" },
  NxTreeGitDeleted = { fg = "#f38ba8" },
  NxTreeGitStaged = { fg = "#94e2d5" },
  NxTreeGitDirty = { fg = "#fab387" },
  -- per-extension icon colors
  NxTreeIconDefault = { fg = "#9399b2" },
  NxTreeIconRust = { fg = "#fab387" },
  NxTreeIconLua = { fg = "#74c7ec" },
  NxTreeIconJs = { fg = "#f9e2af" },
  NxTreeIconTs = { fg = "#89b4fa" },
  NxTreeIconJson = { fg = "#f9e2af" },
  NxTreeIconToml = { fg = "#fab387" },
  NxTreeIconMd = { fg = "#cdd6f4" },
  NxTreeIconPy = { fg = "#f9e2af" },
  NxTreeIconGo = { fg = "#89dceb" },
  NxTreeIconC = { fg = "#89b4fa" },
  NxTreeIconShell = { fg = "#a6e3a1" },
  NxTreeIconHtml = { fg = "#fab387" },
  NxTreeIconCss = { fg = "#89b4fa" },
  NxTreeIconImage = { fg = "#f5c2e7" },
  NxTreeIconText = { fg = "#bac2de" },
  NxTreeIconGit = { fg = "#f38ba8" },
  NxTreeIconLock = { fg = "#9399b2" },
}

-- apply(overrides) — define each group as a fallback (see the module header). An
-- entry in `overrides` is applied unconditionally; an unrecognized override name is
-- still honored (a plugin may color its own extra group). Idempotent.
function M.apply(overrides)
  overrides = overrides or {}
  for name, spec in pairs(M.defaults) do
    if overrides[name] then
      nx.hl.define(0, name, overrides[name])
    elseif not nx.hl.exists(name) then
      nx.hl.define(0, name, spec)
    end
  end
  for name, spec in pairs(overrides) do
    if not M.defaults[name] then
      nx.hl.define(0, name, spec)
    end
  end
end

return M
