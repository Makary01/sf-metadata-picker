local M = {}

local config = require("sf-metadata-picker.config")
local commands = require("sf-metadata-picker.commands")
local ui = require("sf-metadata-picker.ui")
local sf_context = require("sf-metadata-picker.sf-context");

function M.setup(opts)
    config.setup(opts)
end

function M.open()
    local mtd_tree = commands.get_metadata_tree()
    if not mtd_tree then
        return
    end
    ui.show_tree(mtd_tree, function(selected_mtd)
        if vim.tbl_isempty(selected_mtd or {}) then
            return
        end
        commands.retrieve_metadata(selected_mtd)
    end)
end

function M.refresh()
    sf_context.reset_org()
    commands.refresh_metadata()
end

return M
