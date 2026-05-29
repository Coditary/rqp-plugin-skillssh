plugin = {}

local PLUGIN_NAME = "Skillssh"
local PLUGIN_VERSION = "0.1.0"
local APP_PACKAGE_NAME = "app:skillssh"
local APP_HOMEPAGE = "https://skills.sh"
local JSON_NULL = {}
local cached_json_decoder = nil

local function trim(value)
    return (tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", ""))
end

local function lower(value)
    return string.lower(tostring(value or ""))
end

local function starts_with(value, prefix)
    local text = tostring(value or "")
    local expected = tostring(prefix or "")
    return text:sub(1, #expected) == expected
end

local function ends_with(value, suffix)
    local text = tostring(value or "")
    local expected = tostring(suffix or "")
    return expected == "" or text:sub(-#expected) == expected
end

local function strip_trailing_slashes(value)
    return tostring(value or ""):gsub("/+$", "")
end

local function shell_quote(value)
    return "'" .. tostring(value or ""):gsub("'", "'\\''") .. "'"
end

local function first_nonempty(...)
    for index = 1, select("#", ...) do
        local value = select(index, ...)
        if value ~= nil and value ~= JSON_NULL then
            if type(value) == "string" then
                local text = trim(value)
                if text ~= "" then return text end
            else
                return value
            end
        end
    end
    return nil
end

local function shallow_copy(value)
    local copy = {}
    for key, item in pairs(value or {}) do
        copy[key] = item
    end
    return copy
end

local function read_field(value, key)
    if value == nil then return nil end
    local ok, result = pcall(function()
        return value[key]
    end)
    if ok then return result end
    return nil
end

local function read_nested_field(value, ...)
    local current = value
    for _, key in ipairs({ ... }) do
        current = read_field(current, key)
        if current == nil then return nil end
    end
    return current
end

local function path_basename(path)
    local text = strip_trailing_slashes(path)
    return text:match("([^/]+)$") or text
end

local function path_dirname(path)
    local text = strip_trailing_slashes(path)
    local dir = text:match("^(.*)/[^/]+$")
    if dir ~= nil and dir ~= "" then return dir end
    if starts_with(text, "/") then return "/" end
    return "."
end

local function join_path(...)
    local parts = {}
    for index = 1, select("#", ...) do
        local raw = tostring(select(index, ...) or "")
        if raw ~= "" then
            if #parts == 0 then
                parts[#parts + 1] = strip_trailing_slashes(raw)
            else
                parts[#parts + 1] = strip_trailing_slashes(raw:gsub("^/+", ""))
            end
        end
    end
    return table.concat(parts, "/")
end

local function normalize_token(value)
    local text = trim(value)
    if text == "" then return "item" end
    text = text:gsub("^https://", "")
    text = text:gsub("[^%w._-]+", "_")
    text = text:gsub("_+", "_")
    text = text:gsub("^_+", "")
    text = text:gsub("_+$", "")
    return text ~= "" and text or "item"
end

local function unique_push(list, seen, value)
    local text = trim(value)
    if text == "" then return end
    seen[text] = seen[text] or false
    if not seen[text] then
        seen[text] = true
        list[#list + 1] = text
    end
end

local function emit_event(context, name, payload)
    if context == nil or context.events == nil then return end
    local fn = context.events[name]
    if type(fn) == "function" then fn(payload) end
end

local function begin_step(context, label)
    if context == nil or context.tx == nil then return end
    local fn = context.tx.begin_step
    if type(fn) == "function" then fn(label) end
end

local function tx_success(context)
    if context == nil or context.tx == nil then return end
    local fn = context.tx.success
    if type(fn) == "function" then fn() end
end

local function tx_failed(context, message)
    if context == nil or context.tx == nil then return end
    local fn = context.tx.failed
    if type(fn) == "function" then fn(message) end
    emit_event(context, "failed", message)
end

local function log_message(context, level, message)
    if context == nil or context.log == nil then return end
    local fn = context.log[level]
    if type(fn) == "function" then fn(message) end
end

local function normalize_run_result(first, second, third, fourth, fifth)
    if type(first) == "table" and first.success ~= nil then return first end
    local result = {}
    local function merge_exec_like(value)
        local probes = { "success", "ok", "stdout", "stderr", "exitCode", "exit_code", "code", "status" }
        for _, key in ipairs(probes) do
            local ok, item = pcall(function()
                return value[key]
            end)
            if ok and item ~= nil and result[key] == nil then result[key] = item end
        end
    end
    local function merge_table(value)
        for key, item in pairs(value or {}) do result[key] = item end
    end
    local function apply_scalar(value)
        local value_type = type(value)
        if value_type == "table" then
            merge_table(value)
        elseif value_type == "userdata" then
            merge_exec_like(value)
        elseif value_type == "boolean" then
            if result.success == nil then result.success = value end
        elseif value_type == "number" then
            if result.exitCode == nil then result.exitCode = value end
        elseif value_type == "string" then
            if result.stdout == nil then result.stdout = value elseif result.stderr == nil then result.stderr = value end
        end
    end
    apply_scalar(first)
    apply_scalar(second)
    apply_scalar(third)
    apply_scalar(fourth)
    apply_scalar(fifth)
    if result.exitCode == nil then result.exitCode = result.exit_code or result.code or result.status end
    if result.success == nil and result.ok ~= nil then result.success = result.ok end
    if result.success == nil and result.exitCode ~= nil then result.success = result.exitCode == 0 end
    return result
end

local function is_command_success(result)
    if type(result) ~= "table" then return false end
    if result.success or result.ok then return true end
    local exit_code = result.exitCode or result.exit_code or result.code or result.status
    return exit_code == 0
end

local function run_command(context, command)
    local first, second, third, fourth, fifth
    if context ~= nil and context.exec ~= nil and type(context.exec.run) == "function" then
        first, second, third, fourth, fifth = context.exec.run(command)
        return normalize_run_result(first, second, third, fourth, fifth)
    end
    first, second, third, fourth, fifth = reqpack.exec.run(command)
    return normalize_run_result(first, second, third, fourth, fifth)
end

local function ensure_directory(context, path)
    local result = run_command(context, "mkdir -p " .. shell_quote(path))
    if is_command_success(result) then return true, nil end
    return nil, first_nonempty(result and result.stderr, result and result.stdout, "failed to create directory: " .. tostring(path))
end

local function path_exists(context, path)
    local result = run_command(context, "test -e " .. shell_quote(path))
    return is_command_success(result)
end

local function file_exists(context, path)
    local result = run_command(context, "test -f " .. shell_quote(path))
    return is_command_success(result)
end

local function directory_exists(context, path)
    local result = run_command(context, "test -d " .. shell_quote(path))
    return is_command_success(result)
end

local function remove_path_if_exists(context, path)
    if not path_exists(context, path) then return true, nil end
    local result = run_command(context, "rm -rf " .. shell_quote(path))
    if is_command_success(result) then return true, nil end
    return nil, first_nonempty(result and result.stderr, result and result.stdout, "failed to remove path: " .. tostring(path))
end

local function copy_path(context, source_path, target_path, source_kind)
    local parent = path_dirname(target_path)
    local ok, err = ensure_directory(context, parent)
    if not ok then return nil, err end
    local command = source_kind == "directory"
        and ("cp -R " .. shell_quote(source_path) .. " " .. shell_quote(target_path))
        or ("cp " .. shell_quote(source_path) .. " " .. shell_quote(target_path))
    local result = run_command(context, command)
    if is_command_success(result) then return true, nil end
    return nil, first_nonempty(result and result.stderr, result and result.stdout, "failed to copy path")
end

local function read_text_file(path)
    local handle = io.open(path, "rb")
    if handle == nil then return nil end
    local content = handle:read("*a")
    handle:close()
    return content
end

local function write_text_file(context, path, content)
    local parent = path_dirname(path)
    if parent ~= nil and trim(parent) ~= "" then
        local ok, err = ensure_directory(context, parent)
        if not ok then return nil, err end
    end
    local handle = io.open(path, "wb")
    if handle == nil then return nil, "failed to open file for write: " .. tostring(path) end
    local ok, err = handle:write(content)
    handle:close()
    if not ok then return nil, err end
    return true, nil
end

local function codepoint_to_utf8(codepoint)
    if codepoint <= 0x7F then
        return string.char(codepoint)
    elseif codepoint <= 0x7FF then
        return string.char(0xC0 + math.floor(codepoint / 0x40), 0x80 + (codepoint % 0x40))
    elseif codepoint <= 0xFFFF then
        return string.char(0xE0 + math.floor(codepoint / 0x1000), 0x80 + (math.floor(codepoint / 0x40) % 0x40), 0x80 + (codepoint % 0x40))
    end
    return string.char(0xF0 + math.floor(codepoint / 0x40000), 0x80 + (math.floor(codepoint / 0x1000) % 0x40), 0x80 + (math.floor(codepoint / 0x40) % 0x40), 0x80 + (codepoint % 0x40))
end

local function normalize_json_tree(value, null_sentinel, seen)
    if value == nil then return nil end
    if null_sentinel ~= nil and value == null_sentinel then return JSON_NULL end
    if type(value) ~= "table" then return value end
    seen = seen or {}
    if seen[value] ~= nil then return seen[value] end
    local normalized = {}
    seen[value] = normalized
    for key, item in pairs(value) do normalized[key] = normalize_json_tree(item, null_sentinel, seen) end
    return normalized
end

local function decode_json_internal(raw)
    local text = tostring(raw or "")
    local length = #text
    local index = 1
    local function decode_error(message) error(message .. " at byte " .. tostring(index), 0) end
    local function peek() return text:sub(index, index) end
    local function skip_whitespace()
        while index <= length do
            local byte = text:byte(index)
            if byte == 32 or byte == 9 or byte == 10 or byte == 13 then index = index + 1 else break end
        end
    end
    local parse_value
    local function parse_string()
        index = index + 1
        local parts = {}
        local segment_start = index
        while index <= length do
            local current = text:sub(index, index)
            if current == '"' then
                parts[#parts + 1] = text:sub(segment_start, index - 1)
                index = index + 1
                return table.concat(parts)
            elseif current == "\\" then
                parts[#parts + 1] = text:sub(segment_start, index - 1)
                index = index + 1
                if index > length then decode_error("unterminated escape sequence") end
                local escape = text:sub(index, index)
                if escape == '"' or escape == "\\" or escape == "/" then parts[#parts + 1] = escape index = index + 1
                elseif escape == "b" then parts[#parts + 1] = "\b" index = index + 1
                elseif escape == "f" then parts[#parts + 1] = "\f" index = index + 1
                elseif escape == "n" then parts[#parts + 1] = "\n" index = index + 1
                elseif escape == "r" then parts[#parts + 1] = "\r" index = index + 1
                elseif escape == "t" then parts[#parts + 1] = "\t" index = index + 1
                elseif escape == "u" then
                    local hex = text:sub(index + 1, index + 4)
                    if #hex ~= 4 or hex:match("^[0-9a-fA-F]+$") == nil then decode_error("invalid unicode escape") end
                    parts[#parts + 1] = codepoint_to_utf8(tonumber(hex, 16))
                    index = index + 5
                else decode_error("unsupported escape sequence") end
                segment_start = index
            else
                local byte = text:byte(index)
                if byte ~= nil and byte < 32 then decode_error("control character in string") end
                index = index + 1
            end
        end
        decode_error("unterminated string")
    end
    local function parse_number()
        local start_index = index
        if peek() == "-" then index = index + 1 end
        if peek() == "0" then index = index + 1 else
            if peek():match("%d") == nil then decode_error("invalid number") end
            repeat index = index + 1 until index > length or text:sub(index, index):match("%d") == nil
        end
        if peek() == "." then
            index = index + 1
            if peek():match("%d") == nil then decode_error("invalid number") end
            repeat index = index + 1 until index > length or text:sub(index, index):match("%d") == nil
        end
        local exponent = peek()
        if exponent == "e" or exponent == "E" then
            index = index + 1
            local sign = peek()
            if sign == "+" or sign == "-" then index = index + 1 end
            if peek():match("%d") == nil then decode_error("invalid number") end
            repeat index = index + 1 until index > length or text:sub(index, index):match("%d") == nil
        end
        local number = tonumber(text:sub(start_index, index - 1))
        if number == nil then decode_error("invalid number") end
        return number
    end
    local function parse_array()
        index = index + 1
        skip_whitespace()
        local array = {}
        if peek() == "]" then index = index + 1 return array end
        while true do
            array[#array + 1] = parse_value()
            skip_whitespace()
            local current = peek()
            if current == "]" then index = index + 1 return array end
            if current ~= "," then decode_error("expected ',' or ']' in array") end
            index = index + 1
            skip_whitespace()
        end
    end
    local function parse_object()
        index = index + 1
        skip_whitespace()
        local object = {}
        if peek() == "}" then index = index + 1 return object end
        while true do
            if peek() ~= '"' then decode_error("expected string key") end
            local key = parse_string()
            skip_whitespace()
            if peek() ~= ":" then decode_error("expected ':' after object key") end
            index = index + 1
            skip_whitespace()
            object[key] = parse_value()
            skip_whitespace()
            local current = peek()
            if current == "}" then index = index + 1 return object end
            if current ~= "," then decode_error("expected ',' or '}' in object") end
            index = index + 1
            skip_whitespace()
        end
    end
    parse_value = function()
        skip_whitespace()
        local current = peek()
        if current == '"' then return parse_string()
        elseif current == "{" then return parse_object()
        elseif current == "[" then return parse_array()
        elseif current == "-" or (current ~= "" and current:match("%d") ~= nil) then return parse_number()
        elseif text:sub(index, index + 3) == "true" then index = index + 4 return true
        elseif text:sub(index, index + 4) == "false" then index = index + 5 return false
        elseif text:sub(index, index + 3) == "null" then index = index + 4 return JSON_NULL end
        decode_error("unexpected token")
    end
    local value = parse_value()
    skip_whitespace()
    if index <= length then decode_error("trailing content") end
    return value
end

local function load_json_decoder()
    if cached_json_decoder ~= nil then return cached_json_decoder end
    local candidates = {
        function()
            local ok, module = pcall(require, "cjson.safe")
            if ok and module ~= nil and type(module.decode) == "function" then
                return function(raw)
                    local value, err = module.decode(raw)
                    if err ~= nil then error(err, 0) end
                    return normalize_json_tree(value, module.null)
                end
            end
        end,
        function()
            local ok, module = pcall(require, "cjson")
            if ok and module ~= nil and type(module.decode) == "function" then
                return function(raw) return normalize_json_tree(module.decode(raw), module.null) end
            end
        end,
        function()
            local ok, module = pcall(require, "dkjson")
            if ok and module ~= nil and type(module.decode) == "function" then
                return function(raw)
                    local value, _, err = module.decode(raw, 1, nil)
                    if err ~= nil then error(err, 0) end
                    return normalize_json_tree(value, module.null)
                end
            end
        end,
    }
    for _, candidate in ipairs(candidates) do
        local ok, decoder = pcall(candidate)
        if ok and type(decoder) == "function" then cached_json_decoder = decoder return cached_json_decoder end
    end
    cached_json_decoder = decode_json_internal
    return cached_json_decoder
end

local function decode_json(raw)
    local decoder = load_json_decoder()
    local ok, value = pcall(decoder, raw)
    if not ok then return nil, tostring(value) end
    return value, nil
end

local function encode_json_string(value)
    local text = tostring(value or "")
    text = text:gsub("\\", "\\\\")
    text = text:gsub('"', '\\"')
    text = text:gsub("\b", "\\b")
    text = text:gsub("\f", "\\f")
    text = text:gsub("\n", "\\n")
    text = text:gsub("\r", "\\r")
    text = text:gsub("\t", "\\t")
    return '"' .. text .. '"'
end

local function is_array_table(value)
    if type(value) ~= "table" then return false end
    local count = 0
    for key in pairs(value) do
        if type(key) ~= "number" or key <= 0 or key % 1 ~= 0 then return false end
        if key > count then count = key end
    end
    for index = 1, count do if value[index] == nil then return false end end
    return true
end

local function encode_json(value)
    local value_type = type(value)
    if value == nil or value == JSON_NULL then return "null" end
    if value_type == "string" then return encode_json_string(value) end
    if value_type == "number" or value_type == "boolean" then return tostring(value) end
    if value_type ~= "table" then return encode_json_string(tostring(value)) end
    if is_array_table(value) then
        local parts = {}
        for _, item in ipairs(value) do parts[#parts + 1] = encode_json(item) end
        return "[" .. table.concat(parts, ",") .. "]"
    end
    local keys = {}
    for key in pairs(value) do keys[#keys + 1] = key end
    table.sort(keys, function(left, right) return tostring(left) < tostring(right) end)
    local parts = {}
    for _, key in ipairs(keys) do parts[#parts + 1] = encode_json_string(tostring(key)) .. ":" .. encode_json(value[key]) end
    return "{" .. table.concat(parts, ",") .. "}"
end

local function decode_json_file(path)
    local content = read_text_file(path)
    if content == nil then return nil, "failed to read file: " .. tostring(path) end
    return decode_json(content)
end

local function get_reqpack_path(name)
    local paths = type(reqpack) == "table" and read_field(reqpack, "paths") or nil
    if type(paths) ~= "table" then return nil end
    return first_nonempty(read_field(paths, name))
end

local function read_proc_environ_value(name)
    if os ~= nil and type(os.getenv) == "function" then
        local current = os.getenv(tostring(name or ""))
        if current ~= nil and current ~= "" then return trim(current) end
    end
    local handle = io.open("/proc/self/environ", "rb")
    if handle == nil then return nil end
    local payload = handle:read("*a")
    handle:close()
    if payload == nil or payload == "" then return nil end
    local prefix = tostring(name or "") .. "="
    for entry in tostring(payload):gmatch("[^%z]+") do
        if starts_with(entry, prefix) then return trim(entry:sub(#prefix + 1)) end
    end
    return nil
end

local function aicache_root()
    local data_root = get_reqpack_path("dataRoot")
    if data_root ~= nil then return join_path(data_root, "aicache") end
    local xdg_data_home = read_proc_environ_value("XDG_DATA_HOME")
    if xdg_data_home ~= nil and xdg_data_home ~= "" then return join_path(xdg_data_home, "aicache") end
    local home = read_proc_environ_value("HOME")
    if home ~= nil and home ~= "" then return join_path(home, ".local", "share", "aicache") end
    return nil
end

local function skillssh_root()
    local home = read_proc_environ_value("HOME")
    if home == nil or home == "" then return nil end
    return join_path(home, ".local", "share", "skillssh")
end

local function skillssh_reqpack_root()
    local root = skillssh_root()
    return root ~= nil and join_path(root, "reqpack") or nil
end

local function app_metadata_path()
    local root = skillssh_reqpack_root()
    return root ~= nil and join_path(root, "app.json") or nil
end

local function projections_metadata_path()
    local root = skillssh_reqpack_root()
    return root ~= nil and join_path(root, "projections.json") or nil
end

local function ensure_skillssh_roots(context)
    local root = skillssh_root()
    local reqpack_root = skillssh_reqpack_root()
    local aicache = aicache_root()
    if root == nil or reqpack_root == nil or aicache == nil then return nil, "skillssh roots unavailable" end
    for _, path in ipairs({ root, reqpack_root, join_path(aicache, "artifacts"), join_path(aicache, "views") }) do
        local ok, err = ensure_directory(context, path)
        if not ok then return nil, err end
    end
    return { root = root, reqpack = reqpack_root, aicache = aicache }, nil
end

local function load_app_metadata()
    local path = app_metadata_path()
    if path == nil or read_text_file(path) == nil then return nil, nil end
    return decode_json_file(path)
end

local function save_app_metadata(context, metadata)
    local path = app_metadata_path()
    if path == nil then return nil, "skillssh app metadata path unavailable" end
    return write_text_file(context, path, encode_json(metadata))
end

local function empty_projections_payload()
    return { projections = {} }
end

local function load_projections_payload()
    local path = projections_metadata_path()
    if path == nil or read_text_file(path) == nil then return empty_projections_payload(), nil end
    local payload, err = decode_json_file(path)
    if payload == nil then return nil, err end
    if type(payload) ~= "table" or type(payload.projections) ~= "table" then return empty_projections_payload(), nil end
    return payload, nil
end

local function save_projections_payload(context, payload)
    local path = projections_metadata_path()
    if path == nil then return nil, "skillssh projections metadata path unavailable" end
    return write_text_file(context, path, encode_json(payload))
end

local function current_timestamp_utc(context)
    local result = run_command(context, "date -u +%Y-%m-%dT%H:%M:%SZ")
    if result == nil or not is_command_success(result) then
        return nil, first_nonempty(result and result.stderr, result and result.stdout, "failed to capture timestamp")
    end
    return trim(result.stdout), nil
end

local function package_name(package)
    local name = read_field(package, "name")
    return trim(name ~= nil and name or package)
end

local function package_flags(package)
    local flags = read_field(package, "flags")
    return type(flags) == "table" and flags or {}
end

local function is_app_package_name(name)
    return lower(trim(name)) == APP_PACKAGE_NAME
end

local function parse_flags(package)
    local options = {
        isGlobal = false,
        scope = "project",
        copyMode = "symlink",
        agents = {},
        skills = {},
    }
    local seen_agents = {}
    local seen_skills = {}
    for _, flag in ipairs(package_flags(package)) do
        local text = trim(flag)
        if lower(text) == "global" then
            options.isGlobal = true
            options.scope = "global"
        elseif lower(text) == "project" then
            options.isGlobal = false
            options.scope = "project"
        elseif lower(text) == "copy" then
            options.copyMode = "copy"
        else
            local agent = text:match("^agent=(.+)$")
            if agent ~= nil then
                unique_push(options.agents, seen_agents, agent)
            else
                local skill = text:match("^skill=(.+)$")
                if skill ~= nil then unique_push(options.skills, seen_skills, skill) end
            end
        end
    end
    return options
end

local function normalize_github_url_source(source)
    local text = trim(source)
    local owner, repo, skill = text:match("^https://github%.com/([A-Za-z0-9_.%-]+)/([A-Za-z0-9_.%-]+)#([A-Za-z0-9_.%-]+)$")
    if owner ~= nil then return "https://github.com/" .. owner .. "/" .. repo, skill end
    local owner2, repo2 = text:match("^https://github%.com/([A-Za-z0-9_.%-]+)/([A-Za-z0-9_.%-]+)%.git$")
    if owner2 ~= nil then return "https://github.com/" .. owner2 .. "/" .. repo2, nil end
    local owner3, repo3 = text:match("^https://github%.com/([A-Za-z0-9_.%-]+)/([A-Za-z0-9_.%-]+)$")
    if owner3 ~= nil then return "https://github.com/" .. owner3 .. "/" .. repo3, nil end
    return nil, nil
end

local function parse_dynamic_package(name)
    local text = trim(name)
    if text == "" then return nil, "skillssh package missing name" end
    if is_app_package_name(text) then
        return {
            kind = "app",
            packageId = APP_PACKAGE_NAME,
            source = APP_PACKAGE_NAME,
            sourceUrl = APP_HOMEPAGE,
            sourceInput = APP_PACKAGE_NAME,
        }, nil
    end
    if starts_with(lower(text), "https://github.com/") then
        local normalized_source, skill_name = normalize_github_url_source(text)
        if normalized_source == nil then return nil, "skillssh package must use supported GitHub HTTPS URL shape" end
        if skill_name ~= nil then
            return {
                kind = "skill",
                packageId = normalized_source .. "#" .. skill_name,
                source = normalized_source,
                sourceUrl = normalized_source,
                sourceInput = normalized_source,
                skillName = skill_name,
                repoName = path_basename(normalized_source),
            }, nil
        end
        return {
            kind = "repo",
            packageId = normalized_source,
            source = normalized_source,
            sourceUrl = normalized_source,
            sourceInput = normalized_source,
            repoName = path_basename(normalized_source),
        }, nil
    end
    local owner, repo, skill_name = text:match("^([A-Za-z0-9_.%-]+)/([A-Za-z0-9_.%-]+)/([A-Za-z0-9_.%-]+)$")
    if owner ~= nil then
        local source = owner .. "/" .. repo
        return {
            kind = "skill",
            packageId = source .. "#" .. skill_name,
            source = source,
            sourceUrl = "https://github.com/" .. source,
            sourceInput = source,
            skillName = skill_name,
            repoName = repo,
        }, nil
    end
    local owner2, repo2 = text:match("^([A-Za-z0-9_.%-]+)/([A-Za-z0-9_.%-]+)$")
    if owner2 ~= nil then
        local source = owner2 .. "/" .. repo2
        return {
            kind = "repo",
            packageId = source,
            source = source,
            sourceUrl = "https://github.com/" .. source,
            sourceInput = source,
            repoName = repo2,
        }, nil
    end
    return nil, "skillssh package must be owner/repo, owner/repo/skill, or supported GitHub HTTPS URL"
end

local function app_item_from_metadata(metadata)
    local version = first_nonempty(read_field(metadata, "version"))
    return {
        name = APP_PACKAGE_NAME,
        packageId = APP_PACKAGE_NAME,
        version = version,
        latestVersion = version,
        summary = "skills.sh CLI launcher",
        description = "skills.sh CLI launcher",
        homepage = APP_HOMEPAGE,
        sourceUrl = APP_HOMEPAGE,
        packageType = "app",
        type = "package",
        extraFields = {
            launcher = read_field(metadata, "launcher"),
            detectedAt = read_field(metadata, "detected_at"),
        },
    }
end

local function static_app_search_item(version)
    return {
        name = APP_PACKAGE_NAME,
        packageId = APP_PACKAGE_NAME,
        version = version,
        latestVersion = version,
        summary = "skills.sh CLI launcher",
        description = "skills.sh CLI launcher",
        homepage = APP_HOMEPAGE,
        sourceUrl = APP_HOMEPAGE,
        packageType = "app",
        type = "package",
    }
end

local function build_projection_item(record)
    if type(record) ~= "table" then return nil end
    local package_id = trim(read_field(record, "package_id") or "")
    if package_id == "" then return nil end
    local package_kind = trim(read_field(record, "package_kind") or "skill")
    local skill_name = trim(read_field(record, "skill_name") or "")
    local summary = package_kind == "repo" and "skills.sh source repo projection" or "skills.sh skill projection"
    return {
        name = package_id,
        packageId = package_id,
        version = first_nonempty(read_field(record, "installed_revision"), read_field(record, "installed_at")),
        latestVersion = first_nonempty(read_field(record, "installed_revision"), read_field(record, "installed_at")),
        summary = summary,
        description = summary,
        homepage = read_field(record, "source_url"),
        sourceUrl = read_field(record, "source_url"),
        packageType = package_kind,
        type = "package",
        extraFields = {
            source = read_field(record, "source"),
            skillName = skill_name ~= "" and skill_name or nil,
            artifactId = read_field(record, "artifact_id"),
            artifactPath = read_field(record, "artifact_path"),
            scope = read_field(record, "scope"),
            agents = read_field(record, "agents"),
            targetPaths = read_field(record, "target_paths"),
            copyMode = read_field(record, "copy_mode"),
            installedAt = read_field(record, "installed_at"),
            discoveredSkills = read_field(record, "discovered_skills"),
        },
    }
end

local function artifact_dir(artifact_id)
    local root = aicache_root()
    if root == nil then return nil end
    return join_path(root, "artifacts", artifact_id)
end

local function repo_view_path(source)
    local root = aicache_root()
    if root == nil then return nil end
    return join_path(root, "views", "by-source", "skillssh", "repo", normalize_token(source), "current.json")
end

local function skill_view_path(source, skill_name)
    local root = aicache_root()
    if root == nil then return nil end
    return join_path(root, "views", "by-source", "skillssh", "skill", normalize_token(source), normalize_token(skill_name), "current.json")
end

local function make_repo_artifact_id(source, revision)
    return join_path("skillssh", "repo", normalize_token(source) .. "@" .. normalize_token(revision))
end

local function make_skill_artifact_id(source, skill_name, revision)
    return join_path("skillssh", "skill", normalize_token(source), normalize_token(skill_name) .. "@" .. normalize_token(revision))
end

local function write_artifact_metadata(context, artifact_id, manifest, source_metadata, files_payload)
    local root = artifact_dir(artifact_id)
    if root == nil then return nil, "skillssh artifact root unavailable" end
    local ok, err = ensure_directory(context, root)
    if not ok then return nil, err end
    local write_ok, write_error = write_text_file(context, join_path(root, "manifest.json"), encode_json(manifest))
    if not write_ok then return nil, write_error end
    write_ok, write_error = write_text_file(context, join_path(root, "source.json"), encode_json(source_metadata))
    if not write_ok then return nil, write_error end
    write_ok, write_error = write_text_file(context, join_path(root, "files.json"), encode_json(files_payload))
    if not write_ok then return nil, write_error end
    return root, nil
end

local function write_current_view(context, path, payload)
    if path == nil then return nil, "skillssh current view path unavailable" end
    local ok, err = ensure_directory(context, path_dirname(path))
    if not ok then return nil, err end
    return write_text_file(context, path, encode_json(payload))
end

local function read_current_view(path)
    if path == nil or read_text_file(path) == nil then return nil end
    return decode_json_file(path)
end

local function detect_launcher(context)
    local probes = {
        { command = "bunx skills", versionCommand = "bunx skills --version", launcher = "bunx" },
        { command = "npx --yes skills", versionCommand = "npx --yes skills --version", launcher = "npx" },
    }
    for _, probe in ipairs(probes) do
        local result = run_command(context, probe.versionCommand)
        if result ~= nil and is_command_success(result) then
            return {
                command = probe.command,
                launcher = probe.launcher,
                version = trim(result.stdout),
            }, nil
        end
    end
    return nil, "skillssh launcher unavailable: bunx skills and npx --yes skills both failed"
end

local function parse_installed_skills_json(raw)
    local decoded, err = decode_json(raw)
    if decoded == nil then return nil, err end
    if type(decoded) == "table" and type(decoded.skills) == "table" then return decoded.skills, nil end
    if type(decoded) == "table" and type(decoded.items) == "table" then return decoded.items, nil end
    if type(decoded) == "table" and #decoded >= 0 then return decoded, nil end
    return {}, nil
end

local function normalize_installed_skill(entry)
    if type(entry) ~= "table" then return nil end
    local name = trim(first_nonempty(read_field(entry, "name"), read_field(entry, "skill")))
    if name == "" then return nil end
    return {
        name = name,
        description = first_nonempty(read_field(entry, "description")),
        path = first_nonempty(read_field(entry, "path")),
        canonicalPath = first_nonempty(read_field(entry, "canonicalPath"), read_field(entry, "canonical_path")),
        scope = first_nonempty(read_field(entry, "scope")),
        revision = first_nonempty(read_field(entry, "skillFolderHash"), read_field(entry, "skill_folder_hash"), read_field(entry, "revision")),
    }
end

local function query_installed_skills(context, launcher)
    local result = run_command(context, launcher.command .. " list --json")
    if result == nil or not is_command_success(result) then
        return nil, first_nonempty(result and result.stderr, result and result.stdout, "skillssh list failed")
    end
    local decoded, err = parse_installed_skills_json(result.stdout or "[]")
    if decoded == nil then return nil, err end
    local items = {}
    for _, entry in ipairs(decoded or {}) do
        local normalized = normalize_installed_skill(entry)
        if normalized ~= nil then items[#items + 1] = normalized end
    end
    return items, nil
end

local function unquote_yaml_value(value)
    local text = trim(value)
    local quote = text:sub(1, 1)
    if #text >= 2 and (quote == '"' or quote == "'") and text:sub(-1) == quote then
        return text:sub(2, -2)
    end
    return text
end

local function parse_skill_frontmatter(raw)
    local text = tostring(raw or "")
    local lines = {}
    for line in text:gmatch("([^\n]*)\n?") do lines[#lines + 1] = line:gsub("\r$", "") end
    if trim(lines[1] or "") ~= "---" then return nil end
    local payload = { metadata = {} }
    local in_metadata = false
    for index = 2, #lines do
        local line = lines[index]
        if trim(line) == "---" then return payload end
        if in_metadata then
            local child_key, child_value = line:match("^%s%s([%w_.-]+):%s*(.-)%s*$")
            if child_key ~= nil then
                payload.metadata[child_key] = unquote_yaml_value(child_value)
            elseif trim(line) ~= "" then
                in_metadata = false
            end
        end
        if not in_metadata then
            local key, value = line:match("^([%w_.-]+):%s*(.-)%s*$")
            if key ~= nil then
                if key == "metadata" then
                    in_metadata = true
                else
                    payload[key] = unquote_yaml_value(value)
                end
            end
        end
    end
    return nil
end

local function skill_markdown_path(target_path)
    local text = trim(target_path)
    if text == "" then return nil end
    if text:match("/SKILL%.md$") ~= nil then return text end
    return join_path(text, "SKILL.md")
end

local function frontmatter_metadata_from_record(context, record)
    local target_paths = type(read_field(record, "target_paths")) == "table" and read_field(record, "target_paths") or {}
    for _, target_path in ipairs(target_paths) do
        local skill_path = skill_markdown_path(target_path)
        if skill_path ~= nil and file_exists(context, skill_path) then
            local parsed = parse_skill_frontmatter(read_text_file(skill_path))
            if parsed ~= nil then return parsed, skill_path end
        end
    end
    return nil, nil
end

local function apply_frontmatter_to_projection_item(item, parsed, skill_path)
    if item == nil or type(parsed) ~= "table" then return item end
    item.summary = first_nonempty(read_field(parsed, "description"), read_field(parsed, "name"), item.summary)
    item.description = first_nonempty(read_field(parsed, "description"), item.description)
    local metadata = type(read_field(parsed, "metadata")) == "table" and read_field(parsed, "metadata") or {}
    item.version = first_nonempty(
        read_field(metadata, "skillFolderHash"),
        read_field(metadata, "revision"),
        read_field(metadata, "github-tree-sha"),
        read_field(metadata, "github-ref"),
        item.version
    )
    item.latestVersion = item.version
    item.extraFields = type(item.extraFields) == "table" and item.extraFields or {}
    item.extraFields.frontmatterName = read_field(parsed, "name")
    item.extraFields.frontmatterDescription = read_field(parsed, "description")
    item.extraFields.frontmatterLicense = read_field(parsed, "license")
    item.extraFields.frontmatterAuthor = read_field(parsed, "author")
    item.extraFields.frontmatterHomepage = read_field(parsed, "homepage")
    item.extraFields.skillMarkdownPath = skill_path
    item.extraFields.frontmatterMetadata = metadata
    item.extraFields.githubRepo = read_field(metadata, "github-repo")
    item.extraFields.githubRef = read_field(metadata, "github-ref")
    item.extraFields.githubTreeSha = read_field(metadata, "github-tree-sha")
    item.extraFields.githubPath = read_field(metadata, "github-path")
    item.extraFields.skillFolderHash = read_field(metadata, "skillFolderHash")
    item.homepage = first_nonempty(read_field(parsed, "homepage"), item.homepage)
    item.sourceUrl = first_nonempty(read_field(parsed, "homepage"), item.sourceUrl)
    return item
end

local function build_cli_flags(spec, options)
    local args = {}
    local seen_skills = {}
    if spec.skillName ~= nil then unique_push(args, seen_skills, "--skill " .. shell_quote(spec.skillName)) end
    for _, skill_name in ipairs(options.skills or {}) do unique_push(args, seen_skills, "--skill " .. shell_quote(skill_name)) end
    for _, agent in ipairs(options.agents or {}) do args[#args + 1] = "--agent " .. shell_quote(agent) end
    if options.isGlobal then args[#args + 1] = "-g" end
    if options.copyMode == "copy" then args[#args + 1] = "--copy" end
    return args
end

local function select_installed_skills(entries, spec, options)
    local selected = {}
    local desired_names = {}
    local desired_seen = {}
    if spec.skillName ~= nil then unique_push(desired_names, desired_seen, spec.skillName) end
    for _, value in ipairs(options.skills or {}) do unique_push(desired_names, desired_seen, value) end
    if #desired_names > 0 then
        local desired_lookup = {}
        for _, value in ipairs(desired_names) do desired_lookup[lower(value)] = true end
        for _, entry in ipairs(entries or {}) do
            if desired_lookup[lower(entry.name)] then selected[#selected + 1] = entry end
        end
        return selected
    end
    local repo_name = lower(trim(spec.repoName or path_basename(spec.source)))
    for _, entry in ipairs(entries or {}) do
        local haystack = lower(table.concat({ entry.path or "", entry.canonicalPath or "" }, " "))
        if repo_name ~= "" and haystack:find(repo_name, 1, true) ~= nil then selected[#selected + 1] = entry end
    end
    if #selected > 0 then return selected end
    return shallow_copy(entries or {})
end

local function detect_source_kind(context, path)
    if trim(path or "") == "" then return nil end
    if directory_exists(context, path) then return "directory" end
    if path_exists(context, path) then return "file" end
    return nil
end

local function snapshot_skill_path(context, artifact_root, logical_name, entry)
    local source_path = first_nonempty(entry.canonicalPath, entry.path)
    if source_path == nil then return nil end
    local source_kind = detect_source_kind(context, source_path)
    if source_kind == nil then
        log_message(context, "warn", "skillssh source path missing for snapshot: " .. tostring(source_path))
        return nil
    end
    local target_path = join_path(artifact_root, logical_name)
    local ok, err = copy_path(context, source_path, target_path, source_kind)
    if not ok then return nil, err end
    return {
        logical_path = logical_name,
        source_path = source_path,
        canonical_path = entry.canonicalPath,
        entry_path = entry.path,
    }, nil
end

local function choose_revision(installed_at, entries)
    local parts = {}
    local seen = {}
    for _, entry in ipairs(entries or {}) do
        unique_push(parts, seen, first_nonempty(entry.revision, entry.name))
    end
    if #parts == 0 then return installed_at end
    return table.concat(parts, "+")
end

local function write_repo_artifact(context, spec, launcher, installed_at, entries)
    local revision = choose_revision(installed_at, entries)
    local artifact_id = make_repo_artifact_id(spec.source, revision)
    local artifact_root = artifact_dir(artifact_id)
    if artifact_root == nil then return nil, "skillssh artifact root unavailable" end
    local payload_root = join_path(artifact_root, "payload", "skills")
    local ok, err = ensure_directory(context, payload_root)
    if not ok then return nil, err end
    local files = {}
    for _, entry in ipairs(entries or {}) do
        local logical_name = join_path("payload", "skills", normalize_token(entry.name))
        local file_record, copy_error = snapshot_skill_path(context, artifact_root, logical_name, entry)
        if copy_error ~= nil then return nil, copy_error end
        if file_record ~= nil then files[#files + 1] = file_record end
    end
    local discovered_skills = {}
    local discovered_seen = {}
    for _, entry in ipairs(entries or {}) do unique_push(discovered_skills, discovered_seen, entry.name) end
    local manifest = {
        kind = "skill-repo",
        created_at = installed_at,
        source = {
            system = "skillssh",
            normalized_source = spec.source,
            source_url = spec.sourceUrl,
            revision = revision,
        },
    }
    local source_metadata = {
        package_id = spec.packageId,
        package_kind = spec.kind,
        source = spec.source,
        source_url = spec.sourceUrl,
        discovered_skills = discovered_skills,
        upstream_metadata = {
            launcher = launcher.launcher,
            version = launcher.version,
        },
    }
    local artifact_path, metadata_error = write_artifact_metadata(context, artifact_id, manifest, source_metadata, { files = files })
    if artifact_path == nil then return nil, metadata_error end
    local view_ok, view_error = write_current_view(context, repo_view_path(spec.source), {
        artifact_id = artifact_id,
        artifact_path = artifact_path,
        source = spec.source,
        source_url = spec.sourceUrl,
        revision = revision,
        package_id = spec.packageId,
        discovered_skills = discovered_skills,
        kind = "repo",
    })
    if not view_ok then return nil, view_error end
    return {
        artifactId = artifact_id,
        artifactPath = artifact_path,
        revision = revision,
        discoveredSkills = discovered_skills,
    }, nil
end

local function write_skill_artifact(context, spec, launcher, installed_at, entry)
    local revision = first_nonempty(entry.revision, installed_at)
    local artifact_id = make_skill_artifact_id(spec.source, entry.name, revision)
    local artifact_root = artifact_dir(artifact_id)
    if artifact_root == nil then return nil, "skillssh artifact root unavailable" end
    local payload_root = join_path(artifact_root, "payload")
    local ok, err = ensure_directory(context, payload_root)
    if not ok then return nil, err end
    local file_record, copy_error = snapshot_skill_path(context, artifact_root, join_path("payload", normalize_token(entry.name)), entry)
    if copy_error ~= nil then return nil, copy_error end
    local manifest = {
        kind = "skill-bundle",
        created_at = installed_at,
        source = {
            system = "skillssh",
            normalized_source = spec.source,
            source_url = spec.sourceUrl,
            revision = revision,
            skill_name = entry.name,
        },
    }
    local source_metadata = {
        package_id = spec.kind == "skill" and spec.packageId or (spec.source .. "#" .. entry.name),
        package_kind = "skill",
        source = spec.source,
        source_url = spec.sourceUrl,
        skill_name = entry.name,
        upstream_metadata = {
            launcher = launcher.launcher,
            version = launcher.version,
        },
    }
    local artifact_path, metadata_error = write_artifact_metadata(context, artifact_id, manifest, source_metadata, { files = file_record ~= nil and { file_record } or {} })
    if artifact_path == nil then return nil, metadata_error end
    local view_ok, view_error = write_current_view(context, skill_view_path(spec.source, entry.name), {
        artifact_id = artifact_id,
        artifact_path = artifact_path,
        source = spec.source,
        source_url = spec.sourceUrl,
        revision = revision,
        package_id = spec.source .. "#" .. entry.name,
        kind = "skill",
        skill_name = entry.name,
        description = entry.description,
    })
    if not view_ok then return nil, view_error end
    return {
        artifactId = artifact_id,
        artifactPath = artifact_path,
        revision = revision,
        skillName = entry.name,
    }, nil
end

local function find_projection_by_package_id(payload, package_id)
    for index, record in ipairs(type(payload) == "table" and payload.projections or {}) do
        if trim(read_field(record, "package_id") or "") == trim(package_id) then return record, index end
    end
    return nil, nil
end

local function upsert_projection(payload, record)
    local existing, index = find_projection_by_package_id(payload, read_field(record, "package_id"))
    if existing ~= nil and index ~= nil then
        payload.projections[index] = record
    else
        payload.projections[#payload.projections + 1] = record
    end
end

local function any_target_exists(context, record)
    local paths = type(read_field(record, "target_paths")) == "table" and read_field(record, "target_paths") or {}
    for _, path in ipairs(paths) do
        if path_exists(context, path) then return true end
    end
    return false
end

local function install_app(context)
    local roots, root_error = ensure_skillssh_roots(context)
    if roots == nil then return nil, root_error end
    local launcher, launcher_error = detect_launcher(context)
    if launcher == nil then return nil, launcher_error end
    local detected_at, time_error = current_timestamp_utc(context)
    if detected_at == nil then return nil, time_error end
    local metadata = {
        launcher = launcher.launcher,
        version = launcher.version,
        detected_at = detected_at,
    }
    local ok, err = save_app_metadata(context, metadata)
    if not ok then return nil, err end
    return app_item_from_metadata(metadata), nil
end

local function build_install_record(spec, options, installed_at, repo_artifact, selected_entries)
    local target_paths = {}
    local target_seen = {}
    local discovered_skills = {}
    local discovered_seen = {}
    for _, entry in ipairs(selected_entries or {}) do
        unique_push(target_paths, target_seen, first_nonempty(entry.path, entry.canonicalPath))
        unique_push(discovered_skills, discovered_seen, entry.name)
    end
    local skill_name = spec.skillName
    if skill_name == nil and spec.kind == "skill" and #discovered_skills > 0 then skill_name = discovered_skills[1] end
    return {
        package_id = spec.packageId,
        package_kind = spec.kind,
        source = spec.source,
        source_url = spec.sourceUrl,
        skill_name = skill_name,
        artifact_id = repo_artifact.artifactId,
        artifact_path = repo_artifact.artifactPath,
        scope = options.scope,
        agents = options.agents,
        target_paths = target_paths,
        copy_mode = options.copyMode,
        installed_at = installed_at,
        installed_revision = repo_artifact.revision,
        discovered_skills = discovered_skills,
    }
end

local function install_dynamic_package(context, package)
    local roots, root_error = ensure_skillssh_roots(context)
    if roots == nil then return nil, root_error end
    local spec, spec_error = parse_dynamic_package(package_name(package))
    if spec == nil then return nil, spec_error end
    local options = parse_flags(package)
    local launcher, launcher_error = detect_launcher(context)
    if launcher == nil then return nil, launcher_error end
    local cli_flags = build_cli_flags(spec, options)
    local command = launcher.command .. " add " .. shell_quote(spec.sourceInput)
    for _, arg in ipairs(cli_flags) do command = command .. " " .. arg end
    command = command .. " -y"
    local result = run_command(context, command)
    if result == nil or not is_command_success(result) then
        return nil, first_nonempty(result and result.stderr, result and result.stdout, "skillssh install failed")
    end
    local installed_entries, list_error = query_installed_skills(context, launcher)
    if installed_entries == nil then return nil, list_error end
    local selected_entries = select_installed_skills(installed_entries, spec, options)
    if #selected_entries == 0 then return nil, "skillssh missing plugin-managed projection metadata after install flow" end
    local installed_at, time_error = current_timestamp_utc(context)
    if installed_at == nil then return nil, time_error end
    local repo_artifact, repo_error = write_repo_artifact(context, spec, launcher, installed_at, selected_entries)
    if repo_artifact == nil then return nil, repo_error end
    local primary_artifact = repo_artifact
    if spec.kind == "skill" then
        local skill_artifact, skill_error = write_skill_artifact(context, spec, launcher, installed_at, selected_entries[1])
        if skill_artifact == nil then return nil, skill_error end
        primary_artifact = skill_artifact
    else
        for _, entry in ipairs(selected_entries) do
            local _, skill_error = write_skill_artifact(context, spec, launcher, installed_at, entry)
            if skill_error ~= nil then return nil, skill_error end
        end
    end
    local payload, payload_error = load_projections_payload()
    if payload == nil then return nil, payload_error end
    local record = build_install_record(spec, options, installed_at, primary_artifact, selected_entries)
    upsert_projection(payload, record)
    local save_ok, save_error = save_projections_payload(context, payload)
    if not save_ok then return nil, save_error end
    return build_projection_item(record), nil
end

local function remove_projection_records_matching(payload, predicate)
    local removed = {}
    local kept = {}
    for _, record in ipairs(payload.projections or {}) do
        if predicate(record) then
            removed[#removed + 1] = record
        else
            kept[#kept + 1] = record
        end
    end
    payload.projections = kept
    return removed
end

local function remove_dynamic_package(context, package)
    local spec, spec_error = parse_dynamic_package(package_name(package))
    if spec == nil then return nil, spec_error end
    local payload, payload_error = load_projections_payload()
    if payload == nil then return nil, payload_error end
    local matching = {}
    if spec.kind == "repo" then
        matching = remove_projection_records_matching(payload, function(record)
            return trim(read_field(record, "source") or "") == spec.source
        end)
    else
        matching = remove_projection_records_matching(payload, function(record)
            return trim(read_field(record, "package_id") or "") == spec.packageId
        end)
    end
    local launcher, launcher_error = detect_launcher(context)
    if launcher == nil then return nil, launcher_error end
    local removed_skill_names = {}
    local removed_seen = {}
    for _, record in ipairs(matching) do
        if spec.kind == "repo" then
            for _, skill_name in ipairs(read_field(record, "discovered_skills") or {}) do unique_push(removed_skill_names, removed_seen, skill_name) end
        else
            unique_push(removed_skill_names, removed_seen, read_field(record, "skill_name"))
        end
    end
    if #removed_skill_names == 0 and spec.kind == "skill" and spec.skillName ~= nil then removed_skill_names[1] = spec.skillName end
    if #removed_skill_names == 0 and spec.kind == "repo" then
        local view = read_current_view(repo_view_path(spec.source))
        for _, skill_name in ipairs(read_field(view, "discovered_skills") or {}) do unique_push(removed_skill_names, removed_seen, skill_name) end
    end
    for _, skill_name in ipairs(removed_skill_names) do
        local command = launcher.command .. " remove " .. shell_quote(skill_name)
        local result = run_command(context, command)
        if result == nil or not is_command_success(result) then
            return nil, first_nonempty(result and result.stderr, result and result.stdout, "skillssh remove failed")
        end
    end
    local save_ok, save_error = save_projections_payload(context, payload)
    if not save_ok then return nil, save_error end
    if spec.kind == "repo" then
        return build_projection_item({
            package_id = spec.packageId,
            package_kind = "repo",
            source = spec.source,
            source_url = spec.sourceUrl,
        }), nil
    end
    return build_projection_item({
        package_id = spec.packageId,
        package_kind = "skill",
        source = spec.source,
        source_url = spec.sourceUrl,
        skill_name = spec.skillName,
    }), nil
end

local function info_from_cached_view(spec)
    local view = spec.kind == "repo" and read_current_view(repo_view_path(spec.source)) or read_current_view(skill_view_path(spec.source, spec.skillName))
    if type(view) ~= "table" then return nil end
    return build_projection_item({
        package_id = read_field(view, "package_id") or spec.packageId,
        package_kind = read_field(view, "kind") or spec.kind,
        source = read_field(view, "source") or spec.source,
        source_url = read_field(view, "source_url") or spec.sourceUrl,
        skill_name = read_field(view, "skill_name") or spec.skillName,
        artifact_id = read_field(view, "artifact_id"),
        artifact_path = read_field(view, "artifact_path"),
        installed_revision = read_field(view, "revision"),
        discovered_skills = read_field(view, "discovered_skills"),
    })
end

local function cached_view_root(kind)
    local root = aicache_root()
    if root == nil then return nil end
    return join_path(root, "views", "by-source", "skillssh", kind)
end

local function collect_cached_view_items(context, kind, items, seen)
    local root = cached_view_root(kind)
    if root == nil or not directory_exists(context, root) then return end
    local result = run_command(context, "find " .. shell_quote(root) .. " -type f -name current.json | LC_ALL=C sort")
    if result == nil or not is_command_success(result) then return end
    for line in tostring(result.stdout or ""):gmatch("[^\r\n]+") do
        local payload = read_current_view(trim(line))
        if type(payload) == "table" then
            local item = build_projection_item({
                package_id = read_field(payload, "package_id"),
                package_kind = read_field(payload, "kind"),
                source = read_field(payload, "source"),
                source_url = read_field(payload, "source_url"),
                skill_name = read_field(payload, "skill_name"),
                artifact_id = read_field(payload, "artifact_id"),
                artifact_path = read_field(payload, "artifact_path"),
                installed_revision = read_field(payload, "revision"),
                discovered_skills = read_field(payload, "discovered_skills"),
            })
            local key = item and trim(item.packageId or item.name or "") or ""
            if item ~= nil and key ~= "" and not seen[key] then
                seen[key] = true
                items[#items + 1] = item
            end
        end
    end
end

function plugin.getName()
    return PLUGIN_NAME
end

function plugin.getVersion()
    return PLUGIN_VERSION
end

function plugin.getRequirements()
    return {}
end

function plugin.getCategories()
    return { "AI", "Package Manager", "Skills.sh" }
end

function plugin.getMissingPackages(packages)
    local missing = {}
    local app_metadata = select(1, load_app_metadata())
    local payload = select(1, load_projections_payload()) or empty_projections_payload()
    for _, package in ipairs(packages or {}) do
        local name = package_name(package)
        if is_app_package_name(name) then
            if app_metadata == nil then missing[#missing + 1] = package end
        else
            local spec = select(1, parse_dynamic_package(name))
            local record = spec ~= nil and find_projection_by_package_id(payload, spec.packageId) or nil
            if record == nil or not any_target_exists(nil, record) then missing[#missing + 1] = package end
        end
    end
    return missing
end

function plugin.install(context, packages)
    local requested = packages or {}
    if #requested == 0 then return true end
    local installed = {}
    for _, package in ipairs(requested) do
        local name = package_name(package)
        local item, err
        if is_app_package_name(name) then
            begin_step(context, "install skillssh app")
            item, err = install_app(context)
        else
            begin_step(context, "install skillssh package")
            item, err = install_dynamic_package(context, package)
        end
        if item == nil then tx_failed(context, err) return false end
        installed[#installed + 1] = item
    end
    emit_event(context, "installed", installed)
    tx_success(context)
    return true
end

function plugin.installLocal(context, path)
    tx_failed(context, "skillssh plugin does not support installLocal()")
    emit_event(context, "unavailable", { path = path, reason = "local-install-unsupported" })
    return false
end

function plugin.remove(context, packages)
    local requested = packages or {}
    if #requested == 0 then return true end
    local removed = {}
    for _, package in ipairs(requested) do
        local name = package_name(package)
        if is_app_package_name(name) then
            begin_step(context, "remove skillssh app")
            local ok, err = remove_path_if_exists(context, app_metadata_path())
            if not ok then tx_failed(context, err) return false end
            removed[#removed + 1] = static_app_search_item(nil)
        else
            begin_step(context, "remove skillssh package")
            local item, err = remove_dynamic_package(context, package)
            if item == nil then tx_failed(context, err) return false end
            removed[#removed + 1] = item
        end
    end
    emit_event(context, "deleted", removed)
    tx_success(context)
    return true
end

function plugin.update(context, packages)
    local requested = packages or {}
    if #requested == 0 then return true end
    local updated = {}
    for _, package in ipairs(requested) do
        local name = package_name(package)
        local item, err
        if is_app_package_name(name) then
            begin_step(context, "update skillssh app")
            item, err = install_app(context)
        else
            begin_step(context, "update skillssh package")
            item, err = install_dynamic_package(context, package)
        end
        if item == nil then tx_failed(context, err) return false end
        updated[#updated + 1] = item
    end
    emit_event(context, "updated", updated)
    tx_success(context)
    return true
end

function plugin.list(context)
    local items = {}
    local seen = {}
    local app_metadata = select(1, load_app_metadata())
    if app_metadata ~= nil then
        local item = app_item_from_metadata(app_metadata)
        items[#items + 1] = item
        seen[item.packageId] = true
    else
        local launcher = select(1, detect_launcher(context))
        if launcher ~= nil then
            local item = static_app_search_item(launcher.version)
            items[#items + 1] = item
            seen[item.packageId] = true
        end
    end
    local payload = select(1, load_projections_payload()) or empty_projections_payload()
    for _, record in ipairs(payload.projections or {}) do
        if any_target_exists(context, record) then
            local item = build_projection_item(record)
            local parsed, skill_path = frontmatter_metadata_from_record(context, record)
            item = apply_frontmatter_to_projection_item(item, parsed, skill_path)
            local key = item and trim(item.packageId or item.name or "") or ""
            if item ~= nil and key ~= "" and not seen[key] then
                seen[key] = true
                items[#items + 1] = item
            end
        end
    end
    collect_cached_view_items(context, "repo", items, seen)
    collect_cached_view_items(context, "skill", items, seen)
    table.sort(items, function(left, right)
        return lower(left.packageId or left.name or "") < lower(right.packageId or right.name or "")
    end)
    emit_event(context, "listed", items)
    return items
end

function plugin.outdated(context)
    emit_event(context, "outdated", {})
    return {}
end

function plugin.search(context, prompt)
    local query = lower(trim(prompt))
    local results = {}
    if query == "" or query == APP_PACKAGE_NAME or query:find("skills", 1, true) ~= nil or query:find("skills.sh", 1, true) ~= nil or query:find("skillssh", 1, true) ~= nil then
        results[#results + 1] = static_app_search_item(nil)
    end
    emit_event(context, "searched", results)
    return results
end

function plugin.info(context, name)
    local requested = trim(name)
    if requested == "" then return {} end
    if is_app_package_name(requested) then
        local metadata = select(1, load_app_metadata())
        if metadata ~= nil then
            local item = app_item_from_metadata(metadata)
            emit_event(context, "informed", item)
            return item
        end
        local launcher = select(1, detect_launcher(context))
        local item = static_app_search_item(launcher and launcher.version or nil)
        emit_event(context, "informed", item)
        return item
    end
    local spec = select(1, parse_dynamic_package(requested))
    if spec == nil then return {} end
    local payload = select(1, load_projections_payload()) or empty_projections_payload()
    local record = find_projection_by_package_id(payload, spec.packageId)
    if record ~= nil then
        local item = build_projection_item(record)
        local parsed, skill_path = frontmatter_metadata_from_record(context, record)
        item = apply_frontmatter_to_projection_item(item, parsed, skill_path)
        emit_event(context, "informed", item)
        return item
    end
    local cached = info_from_cached_view(spec)
    if cached ~= nil then
        emit_event(context, "informed", cached)
        return cached
    end
    return {}
end

function plugin.resolvePackage(context, package)
    local name = package_name(package)
    if name == "" then return nil end
    if is_app_package_name(name) then return static_app_search_item(nil) end
    return plugin.info(context, name)
end

function plugin.getSecurityMetadata()
    return {
        role = "package-manager",
        capabilities = { "exec", "network" },
        ecosystemScopes = { "skills.sh", "agent-skills" },
        writeScopes = {
            { kind = "temp" },
            { kind = "user-home-subpath", value = ".local/share/aicache" },
            { kind = "user-home-subpath", value = ".local/share/skillssh" },
            { kind = "user-home-subpath", value = ".config/opencode/skills" },
        },
        networkScopes = {
            { host = "github.com", scheme = "https" },
            { host = "api.github.com", scheme = "https" },
        },
        privilegeLevel = "user",
        purlType = "generic",
    }
end

function plugin.init()
    return true
end

function plugin.shutdown()
    return true
end

return plugin
