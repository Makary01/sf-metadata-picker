local M = {}

local function build_maps(metadata_json)
    local types_by_xml = {}
    local child_to_parent = {}

    for _, obj in ipairs(metadata_json.result.metadataObjects) do
        if obj.xmlName then
            types_by_xml[obj.xmlName] = obj
        end

        if obj.childXmlNames then
            for _, child in ipairs(obj.childXmlNames) do
                child_to_parent[child] = obj.xmlName
            end
        end
    end

    return types_by_xml, child_to_parent
end

local function new_node(xmlName, metadata_to_retrieve, label)
    return {
        xmlName = xmlName,
        label = label,
        metadata_to_retrieve = metadata_to_retrieve,
        children = {},
    }
end

local function find(parent, xmlName)
    for _, child in ipairs(parent.children) do
        if child.xmlName == xmlName then
            return child
        end
    end

    return nil
end

local function createNode(parent, xmlName, metadata_to_retrieve, label)
    local node = new_node(xmlName, metadata_to_retrieve or {}, label or xmlName)
    table.insert(parent.children, node)
    return node
end

function M.build_metadata_tree(manifest_tree, metadata_json)
    local types_by_xml, child_to_parent = build_maps(metadata_json)

    local root = new_node("root", {}, "root")

    for type_xml_name, members in pairs(manifest_tree) do
        local type_info = types_by_xml[type_xml_name];

        -- =========================
        -- CASE 1: NORMAL TYPE
        -- =========================
        if type_info and not type_info.inFolder then
            local type_node = find(root, type_xml_name)
            if not type_node then
                type_node = createNode(root, type_xml_name, {}, type_info.directoryName)
            end

            for _, member in ipairs(members) do
                local child_node = find(type_node, member)
                if not child_node then
                    child_node = createNode(type_node, member, { type_xml_name .. ":" .. member })
                else
                    child_node.metadata_to_retrieve = { type_xml_name .. ":" .. member }
                end
            end

            -- =========================
            -- CASE 2: FOLDER TYPE
            -- =========================
        elseif type_info and type_info.inFolder then
            local type_node = createNode(root, type_xml_name, {}, type_info.directoryName)

            local folders = {}

            -- PASS 1: create folders
            for _, member in ipairs(members) do
                if member:sub(-1) == "/" then
                    local folder = member:sub(1, -2)
                    if folder == "unfiled$public" then
                        folders[folder] = createNode(type_node, folder)
                    else
                        folders[folder] = createNode(type_node, folder, { type_xml_name .. "Folder:" .. folder })
                    end
                end
            end

            -- PASS 2: assign files to folders
            for _, member in ipairs(members) do
                if member:sub(-1) ~= "/" then
                    local folder, name = member:match("(.+)/(.+)")

                    if folder and name then
                        if not folders[folder] then
                            folders[folder] = createNode(type_node, folder, { type_xml_name .. "Folder:" .. folder })
                        end

                        createNode(folders[folder], name, { type_xml_name .. ":" .. member })
                    else
                        createNode(type_node, member, { type_xml_name .. ":" .. member })
                    end
                end
            end

            -- =========================
            -- CASE 3: CHILD TYPE
            -- =========================
        else
            local parent_type = child_to_parent[type_xml_name]

            if parent_type then
                local parent_type_info = types_by_xml[parent_type]
                local parent_node = find(root, parent_type_info.xmlName)
                if not parent_node then
                    parent_node = createNode(root, parent_type_info.xmlName, {}, parent_type_info.directoryName)
                end

                for _, member in ipairs(members) do
                    local parent_obj_name, child_name = member:match("([^%.]+)%.(.+)")

                    if parent_obj_name and child_name then
                        local parent_obj_node = find(parent_node, parent_obj_name)
                        if not parent_obj_node then
                            parent_obj_node = createNode(parent_node, parent_obj_name)
                        end
                        local type_node = find(parent_obj_node, type_xml_name)
                        if not type_node then
                            type_node = createNode(parent_obj_node, type_xml_name)
                        end

                        createNode(type_node, child_name, { type_xml_name .. ":" .. member })
                    end
                end
            else
                -- fallback (unknown type)
                local type_node = createNode(root, type_xml_name)
                for _, member in ipairs(members) do
                    createNode(type_node, member, { type_xml_name .. ":" .. member })
                end
            end
        end
    end

    return root
end

return M
