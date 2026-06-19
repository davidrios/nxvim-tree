-- nxvim-tree.keymap — install the configured key bindings on the tree buffer.
--
-- `cfg.mappings` is a `key -> action` table (defaults in config.lua). Each value is
-- one of:
--   a string   the name of a built-in action (see actions.lua / config.ACTIONS)
--   a function a custom action, called as `fn(tree, api)` like a built-in
--   false      disable this key (drop a default without redeclaring the table)
--
-- Every binding is buffer-local on the view buffer (so it only fires while the tree
-- is focused) and runs inside `api.run` — the async, error-surfacing wrapper — so an
-- action may freely `nx.await` fs / ui promises and any rejection becomes a notify
-- rather than an unhandled error.

local actions = require("nxvim-tree.actions")

local M = {}

-- install(tree, api) — bind `tree.config.mappings` on the view buffer. Returns false
-- (warned) if the buffer doesn't exist yet (the caller defers until it does).
function M.install(tree, api)
  local buf = tree.view:bufnr()
  if not buf then
    nx.notify("nxvim-tree: cannot install maps before the view buffer exists", 4)
    return false
  end

  for key, action in pairs(tree.config.mappings) do
    if action ~= false then
      local fn, name
      if type(action) == "function" then
        fn, name = action, "custom"
      else
        fn, name = actions[action], action
        if not fn then
          nx.notify("nxvim-tree: no built-in action '" .. tostring(action) .. "'", 4)
        end
      end
      if fn then
        nx.keymap.set("n", key, function()
          api.run(function()
            fn(tree, api)
          end)
        end, { buffer = buf, desc = "nxvim-tree: " .. name })
      end
    end
  end

  return true
end

return M
