local M = {}
local api = vim.api

local function has_mtd(node)
    return node.metadata_to_retrieve and #node.metadata_to_retrieve > 0
end

-- Recursive toggle for "Select All" behavior
local function toggle_recursive(node, is_selected)
    node.is_selected = is_selected
    if node.children then
        for _, child in ipairs(node.children) do
            toggle_recursive(child, is_selected)
        end
    end
end

local function update_parents(node)
    local curr = node.parent
    while curr do
        -- Only automatically sync state for nodes widthout metadata (i.e. folders)
        if not has_mtd(curr) then
            local all_selected = true
            for _, child in ipairs(curr.children or {}) do
                if not child.is_selected then
                    all_selected = false
                    break
                end
            end
            curr.is_selected = all_selected
        end
        curr = curr.parent
    end
end

-- Initialize tree and create parent links for bubbling state
local function init_tree(node, parent)
    node.is_expanded = node.is_expanded or false
    node.is_selected = node.is_selected or false
    node.parent = parent

    if node.children then
        table.sort(node.children, function(a, b) return (a.label or "") < (b.label or "") end)
        for _, child in ipairs(node.children) do
            init_tree(child, node)
        end
    end
end

local function build_lines(state, node, indent)
    -- Filtering logic
    if state.show_only_selected and node.xmlName ~= "root" then
        local function has_sel(n)
            if n.is_selected then return true end
            for _, c in ipairs(n.children or {}) do if has_sel(c) then return true end end
            return false
        end
        if not has_sel(node) then return end
    end

    if node.xmlName ~= "root" then
        local prefix = string.rep("  ", indent)
        local has_children = node.children and #node.children > 0
        local expand_icon = has_children and (node.is_expanded and "▼ " or "▶ ") or "  "

        local select_icon = ""
        if has_mtd(node) then
            select_icon = node.is_selected and "(*) " or "( ) "
        else
            select_icon = node.is_selected and "[x] " or "[ ] "
        end

        table.insert(state.lines, prefix .. expand_icon .. select_icon .. (node.label or "Unknown"))
        state.line_to_node[#state.lines] = node
    end

    if node.xmlName == "root" or node.is_expanded or state.show_only_selected then
        for _, child in ipairs(node.children or {}) do
            build_lines(state, child, (node.xmlName == "root" and indent or indent + 1))
        end
    end
end

local function render(state)
    state.lines = {}
    state.line_to_node = {}

    table.insert(state.lines,
        " <Tab> Expand/Collapse | <CR> Toggle/Select All | [f] Filter Selected | [r] Reset All | [s] Submit | [q] Close"
    )
    table.insert(state.lines, "")

    build_lines(state, state.tree, 0)


    vim.bo[state.buf].modifiable = true
    api.nvim_buf_set_lines(state.buf, 0, -1, false, state.lines)
    vim.bo[state.buf].modifiable = false
end

local function collect_selected(tree)
    local results = {}
    local seen = {}

    local function collect(n)
        if n.is_selected and has_mtd(n) then
            for _, m in ipairs(n.metadata_to_retrieve) do
                if not seen[m] then
                    seen[m] = true
                    results[#results + 1] = m
                end
            end
        end

        for _, c in ipairs(n.children or {}) do
            collect(c)
        end
    end

    collect(tree)
    return results
end

function M.show_tree(tree, on_submit)
    init_tree(tree, nil) -- Pass nil as the parent for the root node

    local buf = api.nvim_create_buf(false, true)
    local width, height = math.floor(vim.o.columns * 0.8), math.floor(vim.o.lines * 0.8)
    local win = api.nvim_open_win(buf, true, {
        relative = "editor",
        width = width,
        height = height,
        row = math.floor((vim.o.lines - height) / 2),
        col = math.floor((vim.o.columns - width) / 2),
        border = "rounded",
        title = " Metadata Picker ",
        title_pos = "center",
        style = "minimal",
    })

    local state = { buf = buf, win = win, tree = tree, line_to_node = {}, show_only_selected = false }
    render(state)

    local function map(key, fn)
        vim.keymap.set('n', key, fn, { buffer = buf, silent = true })
    end

    map('<Tab>', function()
        local node = state.line_to_node[api.nvim_win_get_cursor(win)[1]]
        if node and node.children and #node.children > 0 then
            node.is_expanded = not node.is_expanded
            render(state)
        end
    end)

    map('<CR>', function()
        local line = api.nvim_win_get_cursor(win)[1]
        local node = state.line_to_node[line]
        if not node then return end

        if has_mtd(node) then
            node.is_selected = not node.is_selected
        else
            toggle_recursive(node, not node.is_selected)
        end

        update_parents(node)
        render(state)
    end)

    map('f', function()
        state.show_only_selected = not state.show_only_selected; render(state)
    end)

    map('r', function()
        toggle_recursive(state.tree, false); render(state)
    end)

    map('q', function() api.nvim_win_close(win, true) end)

    map('s', function()
        local selected = collect_selected(state.tree)
        api.nvim_win_close(win, true)
        if on_submit then
            on_submit(selected)
        else
            print("Selected Metadata: " .. vim.inspect(selected))
        end
    end)
end

return M
