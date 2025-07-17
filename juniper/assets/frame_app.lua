-- Jun-- Phone to Frame flags
TEXT_FLAG = 0x0a          -- Basic centered text (legacy)
POSITIONED_TEXT_FLAG = 0x0b  -- Positioned text elements (x,y coordinates)
CODE_FLAG = 0x10          -- Code execution command
CLEAR_FLAG = 0x12         -- Clear display command

-- Custom code commands (sent via TxCode value parameter)
SHOW_DISPLAY_CODE = 1     -- Show the backbuffer Frame - HUD System with Backbuffer
-- Supports positioned text elements and backbuffer display

-- Frame to phone flags
BATTERY_LEVEL_FLAG = 0x0c

-- Phone to Frame flags
TEXT_FLAG = 0x0a          -- Basic centered text (legacy)
POSITIONED_TEXT_FLAG = 0x0b  -- Positioned text elements (draw to backbuffer)
CODE_FLAG = 0x10          -- Code execution command
CLEAR_FLAG = 0x12         -- Clear display command

-- Custom code commands
SHOW_DISPLAY_CODE = 0x01  -- Show the backbuffer

local app_data_accum = {}
local app_data_block = {}
local app_data = {}

-- Data Handler: called when data arrives, must execute quickly.
function update_app_data_accum(data)
    local msg_flag = string.byte(data, 1)
    local item = app_data_accum[msg_flag]
    if item == nil or next(item) == nil then
        item = { chunk_table = {}, num_chunks = 0, size = 0, recv_bytes = 0 }
        app_data_accum[msg_flag] = item
    end

    if item.num_chunks == 0 then
        -- first chunk of new data contains size (Uint16)
        item.size = string.byte(data, 2) << 8 | string.byte(data, 3)
        item.chunk_table[1] = string.sub(data, 4)
        item.num_chunks = 1
        item.recv_bytes = string.len(data) - 3

        if item.recv_bytes == item.size then
            app_data_block[msg_flag] = item.chunk_table[1]
            item.size = 0
            item.recv_bytes = 0
            item.num_chunks = 0
            item.chunk_table[1] = nil
            app_data_accum[msg_flag] = item
        end
    else
        item.chunk_table[item.num_chunks + 1] = string.sub(data, 2)
        item.num_chunks = item.num_chunks + 1
        item.recv_bytes = item.recv_bytes + string.len(data) - 1

        -- if all bytes are received, concat and move message to block
        if item.recv_bytes == item.size then
            app_data_block[msg_flag] = table.concat(item.chunk_table)

            for k, v in pairs(item.chunk_table) do item.chunk_table[k] = nil end
            item.size = 0
            item.recv_bytes = 0
            item.num_chunks = 0
            app_data_accum[msg_flag] = item
        end
    end
end

-- Parse the text message raw data
function parse_text(data)
    local text = {}
    text.data = data
    return text
end

-- Parse positioned text message: "x,y text content"
function parse_positioned_text(data)
    local positioned = {}
    -- Find the first space to separate coordinates from text
    local space_pos = string.find(data, " ")
    if space_pos then
        local coords = string.sub(data, 1, space_pos - 1)
        local text = string.sub(data, space_pos + 1)
        
        -- Parse x,y coordinates
        local comma_pos = string.find(coords, ",")
        if comma_pos then
            positioned.x = tonumber(string.sub(coords, 1, comma_pos - 1)) or 1
            positioned.y = tonumber(string.sub(coords, comma_pos + 1)) or 1
            positioned.text = text
        else
            -- Fallback if format is wrong
            positioned.x = 1
            positioned.y = 1
            positioned.text = data
        end
    else
        -- Fallback if no space found
        positioned.x = 1
        positioned.y = 1
        positioned.text = data
    end
    return positioned
end

-- Parse code execution command
function parse_code(data)
    local code = {}
    if string.len(data) > 0 then
        -- For TxCode with value parameter, the value is sent as a single byte
        code.command = string.byte(data, 1)
    else
        code.command = 0
    end
    return code
end

-- Parse clear command
function parse_clear(data)
    return { command = "clear" }
end

-- register the respective message parsers
local parsers = {}
parsers[TEXT_FLAG] = parse_text
parsers[POSITIONED_TEXT_FLAG] = parse_positioned_text
parsers[CODE_FLAG] = parse_code
parsers[CLEAR_FLAG] = parse_clear

-- Works through app_data_block and if any items are ready, run the corresponding parser
function process_raw_items()
    local processed = 0

    for flag, block in pairs(app_data_block) do
        -- parse the app_data_block item into an app_data item
        app_data[flag] = parsers[flag](block)

        -- then clear out the raw data
        app_data_block[flag] = nil

        processed = processed + 1
    end

    return processed
end

-- draw legacy centered text
function print_text()
    local i = 0
    for line in app_data[TEXT_FLAG].data:gmatch("([^\n]*)\n?") do
        if line ~= "" then
            frame.display.text(line, 1, i * 60 + 1)
            i = i + 1
        end
    end
end

-- Clear the display completely
function clear_display()
    frame.display.text(" ", 1, 1)  -- Clear with single space
end

-- Execute code commands
function execute_code(command)
    if command == 1 then  -- SHOW_DISPLAY_CODE = 1 (from TxCode value)
        -- Show the backbuffer (display all positioned elements)
        frame.display.show()
    end
end

-- Main app loop
function app_loop()
    local last_batt_update = 0
    while true do
        rc, err = pcall(
            function()
                -- process any raw items, if ready
                local items_ready = process_raw_items()

                frame.sleep(0.005)

                -- Handle different message types
                if items_ready > 0 then
                    -- Handle legacy centered text display
                    if (app_data[TEXT_FLAG] ~= nil and app_data[TEXT_FLAG].data ~= nil) then
                        clear_display()
                        print_text()
                        frame.display.show()
                        app_data[TEXT_FLAG] = nil  -- Clear after processing
                    end
                    
                    -- Handle positioned text elements (draw to backbuffer, don't show yet)
                    if (app_data[POSITIONED_TEXT_FLAG] ~= nil) then
                        local pos_data = app_data[POSITIONED_TEXT_FLAG]
                        -- Draw positioned text to backbuffer
                        frame.display.text(pos_data.text, pos_data.x, pos_data.y)
                        app_data[POSITIONED_TEXT_FLAG] = nil  -- Clear after processing
                    end
                    
                    -- Handle code execution commands
                    if (app_data[CODE_FLAG] ~= nil) then
                        execute_code(app_data[CODE_FLAG].command)
                        app_data[CODE_FLAG] = nil  -- Clear after processing
                    end
                    
                    -- Handle clear command
                    if (app_data[CLEAR_FLAG] ~= nil) then
                        clear_display()
                        frame.display.show()
                        app_data[CLEAR_FLAG] = nil  -- Clear after processing
                    end
                end

                frame.sleep(0.005)

                -- periodic battery level updates
                local t = frame.time.utc()
                if (last_batt_update == 0 or (t - last_batt_update) > 180) then
                    pcall(frame.bluetooth.send, string.char(BATTERY_LEVEL_FLAG) .. string.char(math.floor(frame.battery_level())))
                    last_batt_update = t
                end
            end
        )
        -- Catch the break signal here and clean up the display
        if rc == false then
            print(err)
            frame.display.text(" ", 1, 1)
            frame.display.show()
            frame.sleep(0.04)
            break
        end
    end
end

-- register the handler as a callback for all data sent from the host
frame.bluetooth.receive_callback(update_app_data_accum)

-- run the main app loop
app_loop()
