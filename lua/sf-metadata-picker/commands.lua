local M = {}

local T = require("sf-metadata-picker.tree")
local F = require("sf-metadata-picker.file")
local P = require("sf-metadata-picker.parser")
local SF_CONTEXT = require("sf-metadata-picker.sf-context")

local xml_package_name = "sf_meta_package"
local tree_cache_file_name = "metadata_tree.json"

local function get_org_cache_dir(org)
    return vim.fs.joinpath(vim.fn.stdpath("cache"), "sf-metadata-picker", org)
end

local function is_cache_ready(org)
    local tree_filepath = vim.fs.joinpath(get_org_cache_dir(org), tree_cache_file_name)
    return F.file_exists(tree_filepath)
end

function M.get_metadata_tree()
    local sf_ctx = SF_CONTEXT.get_salesforce_context()
    if not sf_ctx then
        return
    end

    local org = sf_ctx.org

    if not is_cache_ready(org) then
        vim.notify(
            "Metadata cache missing for org " .. org .. ". Please run \":SfMeta refresh\" first.",
            vim.log.levels.WARN
        )
        return nil
    end

    local tree_filepath = vim.fs.joinpath(get_org_cache_dir(org), tree_cache_file_name)
    local tree_content = F.read_file(tree_filepath)
    if not tree_content then
        vim.notify(
            "Error when reading tree_content",
            vim.log.levels.ERROR
        )
        return
    end

    return vim.json.decode(tree_content)
end

function M.refresh_metadata()
    local sf_ctx = SF_CONTEXT.get_salesforce_context()
    if not sf_ctx then
        return
    end
    local org = sf_ctx.org
    local org_cache_dir = get_org_cache_dir(org)

    F.delete_directory(org_cache_dir)
    vim.fn.mkdir(org_cache_dir, "p")

    vim.notify("Fetching and compiling metadata for " .. org .. "...", vim.log.levels.INFO)

    local tasks_pending = 2
    local has_errors = false
    local metadata_json_raw = nil -- Holds the in-memory JSON stdout

    -- Callback to compile the tree once BOTH parallel background tasks finish
    local function compile_and_cache_tree()
        if tasks_pending > 0 then return end

        if has_errors then
            vim.notify("Metadata refresh for " .. org .. " completed with errors.", vim.log.levels.ERROR)
            return
        end

        local package_filepath = vim.fs.joinpath(org_cache_dir, xml_package_name .. ".xml")
        local package_content = F.read_file(package_filepath)

        local manifest = P.parse_package_xml(package_content)
        local metadata_json = P.parse_json(metadata_json_raw)

        local final_tree = T.build_metadata_tree(manifest, metadata_json)

        local tree_filepath = vim.fs.joinpath(org_cache_dir, tree_cache_file_name)
        F.write_file(tree_filepath, vim.json.encode(final_tree))

        vim.notify("Metadata tree successfully compiled and cached!", vim.log.levels.INFO)
    end

    vim.system({
        "sf", "project", "generate", "manifest",
        "--from-org", org,
        "--output-dir", org_cache_dir,
        "--name", xml_package_name
    }, { text = true }, function(result)
        vim.schedule(function()
            tasks_pending = tasks_pending - 1
            if result.code ~= 0 then
                has_errors = true
                vim.notify("Error generating manifest:\n" .. vim.inspect(result), vim.log.levels.ERROR)
            end
            compile_and_cache_tree()
        end)
    end)

    vim.system({
        "sf", "org", "list", "metadata-types", "--json", "-o", org
    }, { text = true }, function(result)
        vim.schedule(function()
            tasks_pending = tasks_pending - 1
            if result.code ~= 0 then
                has_errors = true
                vim.notify("Error fetching metadata types:\n" .. vim.inspect(result), vim.log.levels.ERROR)
            else
                metadata_json_raw = result.stdout
            end
            compile_and_cache_tree()
        end)
    end)
end

function M.retrieve_metadata(metadata_list)
    local ctx = SF_CONTEXT.get_salesforce_context()
    if not ctx then
        return
    end

    local cmd = {
        "sf",
        "project",
        "retrieve",
        "start",
        "--ignore-conflicts",
        "--target-org", ctx.org,
        "--metadata", unpack(metadata_list),
    }

    vim.cmd.vnew()
    vim.cmd.wincmd("J")

    local job_id = vim.fn.jobstart(cmd, {
        cwd = ctx.project_root,
        term = true,
    })

    if job_id <= 0 then
        vim.notify("Failed to open terminal", vim.log.levels.ERROR)
        return
    end

    vim.keymap.set("t", "<Esc>", [[<C-\><C-n>]], {
        buffer = true,
    })

    vim.cmd.startinsert()
end

return M
