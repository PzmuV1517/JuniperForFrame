-- we store the data from the host quickly from the data handler interrupt
-- and wait for the main loop to pick it up for processing/drawing

-- Frame to phone flags
BATTERY_LEVEL_FLAG = 0x0c
TAP_MSG = 0x09
MIC_DATA_FLAG = 0x0b

-- Phone to Frame flags
TEXT_FLAG = 0x0a
TAP_SUBS_FLAG = 0x10
CLEAR_FLAG = 0x12
MIC_START_FLAG = 0x11
MIC_STOP_FLAG = 0x13

local app_data_accum = {}
local app_data_block = {}
local app_data = {}

-- Track display state for battery preservation
local display_on = false
local display_timeout = 0

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

-- Parse the tap subscription message
function parse_tap_subs(data)
    local tap_subs = {}
    tap_subs.value = string.byte(data, 1)
    return tap_subs
end

-- Parse the clear message
function parse_clear(data)
    local clear = {}
    clear.value = string.byte(data, 1)
    return clear
end

-- Parse microphone start command
function parse_mic_start(data)
    local mic_start = {}
    mic_start.value = string.byte(data, 1)
    return mic_start
end

-- Parse microphone stop command
function parse_mic_stop(data)
    local mic_stop = {}
    mic_stop.value = string.byte(data, 1)
    return mic_stop
end

-- Handle tap events
function handle_tap()
    pcall(frame.bluetooth.send, string.char(TAP_MSG))
end

-- Microphone streaming variables
local mic_streaming = false
local mtu = frame.bluetooth.max_length()

-- Start microphone streaming
function start_microphone()
    if not mic_streaming then
        frame.microphone.start{sample_rate=8000, bit_depth=8}  -- 8kHz 8-bit for good quality and bandwidth
        mic_streaming = true
        print("Microphone started")
    end
end

-- Stop microphone streaming  
function stop_microphone()
    if mic_streaming then
        frame.microphone.stop()
        mic_streaming = false
        print("Microphone stopped")
    end
end

-- Stream microphone data to phone
function stream_microphone_data()
    if mic_streaming then
        local data = frame.microphone.read(mtu)
        
        if data == nil then
            -- Stream stopped, clean up
            mic_streaming = false
            return
        end
        
        if data ~= '' then
            -- Send microphone data to phone with MIC_DATA_FLAG
            local success = pcall(frame.bluetooth.send, string.char(MIC_DATA_FLAG) .. data)
            if not success then
                -- If Bluetooth send fails, we'll try again next loop
            end
        end
    end
end

-- register the respective message parsers
local parsers = {}
parsers[TEXT_FLAG] = parse_text
parsers[TAP_SUBS_FLAG] = parse_tap_subs
parsers[CLEAR_FLAG] = parse_clear
parsers[MIC_START_FLAG] = parse_mic_start
parsers[MIC_STOP_FLAG] = parse_mic_stop

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

-- draw text on the display
function print_text()
    local i = 0
    for line in app_data[TEXT_FLAG].data:gmatch("([^\n]*)\n?") do
        if line ~= "" then
            frame.display.text(line, 1, i * 60 + 1)
            i = i + 1
        end
    end
    frame.display.show()
    display_on = true
    display_timeout = frame.time.utc() + 15  -- Show for 15 seconds
end

-- Clear display for battery saving
function clear_display()
    frame.display.text(" ", 1, 1)
    frame.display.show()
    display_on = false
    display_timeout = 0
end

-- Main app loop
function app_loop()
    clear_display()
    local last_batt_update = 0
    local current_time = 0
    
    while true do
        rc, err = pcall(
            function()
                -- process any raw items, if ready
                local items_ready = process_raw_items()

                if items_ready > 0 then
                    -- Handle text messages (AI responses, date/time)
                    if (app_data[TEXT_FLAG] ~= nil and app_data[TEXT_FLAG].data ~= nil) then
                        print_text()
                        app_data[TEXT_FLAG] = nil
                    end

                    -- Handle tap subscription
                    if (app_data[TAP_SUBS_FLAG] ~= nil) then
                        if app_data[TAP_SUBS_FLAG].value == 1 then
                            -- start subscription to tap events
                            frame.imu.tap_callback(handle_tap)
                        else
                            -- cancel subscription to tap events
                            frame.imu.tap_callback(nil)
                        end
                        app_data[TAP_SUBS_FLAG] = nil
                    end

                    -- Handle clear messages
                    if (app_data[CLEAR_FLAG] ~= nil) then
                        clear_display()
                        app_data[CLEAR_FLAG] = nil
                    end

                    -- Handle microphone start
                    if (app_data[MIC_START_FLAG] ~= nil) then
                        start_microphone()
                        app_data[MIC_START_FLAG] = nil
                    end

                    -- Handle microphone stop
                    if (app_data[MIC_STOP_FLAG] ~= nil) then
                        stop_microphone()
                        app_data[MIC_STOP_FLAG] = nil
                    end
                end

                -- Stream microphone data continuously if active
                stream_microphone_data()

                -- Check if display should timeout for battery preservation
                current_time = frame.time.utc()
                if display_on and display_timeout > 0 and current_time > display_timeout then
                    clear_display()
                end

                -- periodic battery level updates
                local t = frame.time.utc()
                if (last_batt_update == 0 or (t - last_batt_update) > 120) then
                    pcall(frame.bluetooth.send, string.char(BATTERY_LEVEL_FLAG) .. string.char(math.floor(frame.battery_level())))
                    last_batt_update = t
                end

                frame.sleep(0.1)
            end
        )
        -- Catch the break signal here and clean up the display
        if rc == false then
            print(err)
            clear_display()
            break
        end
    end
end

-- register the handler as a callback for all data sent from the host
frame.bluetooth.receive_callback(update_app_data_accum)

-- run the main app loop
app_loop()
