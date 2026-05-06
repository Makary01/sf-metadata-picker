local M = {}

local cached_root

local function get_sf_project_root()
    if cached_root ~= nil then
        return cached_root
    end

    local start_path = vim.fs.dirname(vim.api.nvim_buf_get_name(0))

    if start_path == nil or start_path == "" or start_path == "." then
        start_path = vim.fn.getcwd()
    end

    local project_files = vim.fs.find("sfdx-project.json", {
        upward = true,
        path = start_path,
        stop = vim.uv.os_homedir(),
    })

    local project_file = project_files[1]

    if project_file == nil then
        return nil
    end

    cached_root = vim.fs.dirname(project_file)

    return cached_root
end


local cached_org

local function decode_sf_json_output(output)
    local text = table.concat(output, "\n")

    -- Salesforce CLI may print warnings before the actual JSON.
    -- Find the first "{" and decode from there.
    local json_start = text:find("{", 1, true)

    if json_start == nil then
        return nil
    end

    local json_text = text:sub(json_start)

    local ok, decoded = pcall(vim.json.decode, json_text)

    if not ok then
        return nil
    end

    return decoded
end

local function get_default_org()
    if cached_org ~= nil then
        return cached_org
    end

    local output = vim.fn.systemlist({
        "sf",
        "config",
        "get",
        "target-org",
        "--json",
    })

    if vim.v.shell_error ~= 0 then
        return nil
    end

    local decoded = decode_sf_json_output(output)

    if decoded == nil then
        return nil
    end

    local result = decoded.result and decoded.result[1]
    cached_org = result and result.value or nil

    return cached_org
end


function M.get_salesforce_context()
    local project_root = get_sf_project_root()

    if project_root == nil then
        vim.notify(
            "Not inside a Salesforce project!",
            vim.log.levels.WARN
        )
        return nil
    end

    local org = get_default_org()

    if org == nil then
        vim.notify(
            "No default Salesforce org set!",
            vim.log.levels.WARN
        )
        return nil
    end

    return {
        project_root = project_root,
        org = org,
    }
end

function M.reset_org()
    cached_org = nil
    return get_default_org()
end

return M
