local enabled = vim.fn.executable("java") == 1

return {
  {
    "stevearc/conform.nvim",
    enabled = enabled,
    optional = true,
    opts = {
      formatters_by_ft = {
        java = { "google-java-format" },
      },
      format_on_save = function(bufnr)
        if vim.bo[bufnr].filetype == "java" then
          return { timeout_ms = 5000, lsp_fallback = true }
        end
      end,
    },
  },
  {
    "mfussenegger/nvim-lint",
    enabled = enabled,
    optional = true,
    opts = {
      linters_by_ft = {
        java = { "checkstyle" },
      },
    },
  },
  {
    "mason-org/mason.nvim",
    enabled = enabled,
    opts = function(_, opts)
      vim.list_extend(opts.ensure_installed, {
        "google-java-format",
        "checkstyle",
      })
    end,
  },
}
