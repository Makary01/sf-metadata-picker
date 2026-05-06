local M = {}

function M.parse_package_xml(xml)
    local package = {}

    for type_block in xml:gmatch("<types>(.-)</types>") do
        local type_name = type_block:match("<name>(.-)</name>")
        package[type_name] = {}

        for member in type_block:gmatch("<members>(.-)</members>") do
            table.insert(package[type_name], member)
        end
    end

    return package
end

function M.parse_json(content)
    return vim.json.decode(content);
end

return M
