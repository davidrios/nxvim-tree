-- Git porcelain → sign classification. Pure, run with `nxvim --test-plugin`.

local git = require("nxvim-tree.git")

nx.test.describe("nxvim-tree.git.classify", function()
  nx.test.it("marks untracked files as new", function()
    nx.test.expect(git.classify("??").hl).to_be("NxTreeGitNew")
  end)

  nx.test.it("marks a working-tree modification", function()
    nx.test.expect(git.classify(" M").hl).to_be("NxTreeGitModified")
  end)

  nx.test.it("marks a staged-only change as staged", function()
    nx.test.expect(git.classify("M ").hl).to_be("NxTreeGitStaged")
  end)

  nx.test.it("marks a deletion in either column", function()
    nx.test.expect(git.classify(" D").hl).to_be("NxTreeGitDeleted")
    nx.test.expect(git.classify("D ").hl).to_be("NxTreeGitDeleted")
  end)

  nx.test.it("marks an addition", function()
    nx.test.expect(git.classify("A ").hl).to_be("NxTreeGitNew")
  end)
end)
