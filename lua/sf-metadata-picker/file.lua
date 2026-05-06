local M = {}

function M.file_exists(path)
    return vim.fn.filereadable(path) == 1
end

function M.read_file(path)
    local f = io.open(path, "r")
    if not f then return nil end
    local content = f:read("*a")
    f:close()
    return content
end

function M.write_file(path, content)
    local f = io.open(path, "w")
    if not f then return end
    f:write(content)
    f:close()
end

function M.delete_directory(path)
    if not M.file_exists(path) then return end
    local result = vim.fn.delete(path, "rf")
    if result ~= 0 then
        vim.notify("Failed to delete `" .. "`", vim.log.levels.ERROR)
    end
    return result
end

return M
