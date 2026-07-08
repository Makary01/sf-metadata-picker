vim.api.nvim_create_user_command("SfMeta", function(opts)
    local sub = opts.args

    if sub == "open" then
        require("sf-metadata-picker").open()
    elseif sub == "refresh" then
        require("sf-metadata-picker").refresh()
    else
        vim.notify(
            "Unknown SfMeta subcommand: " .. sub,
            vim.log.levels.ERROR
        )
    end
end, {
    nargs = 1,
    complete = function(arglead)
        local completions = { "open", "refresh" }
        local filtered = {}
        for _, completion in ipairs(completions) do
            if vim.startswith(completion, arglead) then
                table.insert(filtered, completion)
            end
        end
        return filtered
    end,
})
