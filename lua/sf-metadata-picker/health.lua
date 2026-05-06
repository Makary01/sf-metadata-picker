local M = {}

function M.check()
    vim.health.start("sf-metadata-picker")

    vim.health.ok("Plugin loaded successfully")

    if vim.fn.has("nvim-0.11") == 1 then
        vim.health.ok("Neovim version is supported")
    else
        vim.health.warn("Neovim >= 0.11 is recommended")
    end

    if vim.fn.executable("sf") == 1 then
        vim.health.ok("sf cli found.")
    else
        vim.health.error("sf cli not found!")
    end
end

return M
