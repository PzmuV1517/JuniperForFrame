local data_accum = {}
local data_block = {}
local data = {}
local display_on = false
local display_timeout = 0
local mic_active = false
local mtu = frame.bluetooth.max_length()

-- Ensure MTU is even for microphone reading (required for 16-bit audio)
if mtu % 2 == 1 then mtu = mtu - 1 end

function update_app_data_accum(raw_data)
    local msg_flag = string.byte(raw_data, 1)
    local item = data_accum[msg_flag]
    if item == nil or next(item) == nil then
        item = { chunk_table = {}, num_chunks = 0, size = 0, recv_bytes = 0 }
        data_accum[msg_flag] = item
    end

    if item.num_chunks == 0 then
        item.size = string.byte(raw_data, 2) << 8 | string.byte(raw_data, 3)
        item.chunk_table[1] = string.sub(raw_data, 4)
        item.num_chunks = 1
        item.recv_bytes = string.len(raw_data) - 3

        if item.recv_bytes == item.size then
            data_block[msg_flag] = item.chunk_table[1]
            item.size = 0
            item.recv_bytes = 0
            item.num_chunks = 0
            item.chunk_table[1] = nil
            data_accum[msg_flag] = item
        end
    else
        item.chunk_table[item.num_chunks + 1] = string.sub(raw_data, 2)
        item.num_chunks = item.num_chunks + 1
        item.recv_bytes = item.recv_bytes + string.len(raw_data) - 1

        if item.recv_bytes == item.size then
            data_block[msg_flag] = table.concat(item.chunk_table)
            for i, chunk in pairs(item.chunk_table) do
                item.chunk_table[i] = nil
            end
            item.size = 0
            item.recv_bytes = 0
            item.num_chunks = 0
            data_accum[msg_flag] = item
        end
    end
end

function text_raw_processor(raw_data)
    local parsed_data = {}
    parsed_data.data = raw_data
    return parsed_data
end

function tap_subs_raw_processor(raw_data)
    local parsed_data = {}
    parsed_data.value = string.byte(raw_data, 1)
    return parsed_data
end

function clear_raw_processor(raw_data)
    local parsed_data = {}
    parsed_data.value = string.byte(raw_data, 1)
    return parsed_data
end

function mic_start_raw_processor(raw_data)
    local parsed_data = {}
    parsed_data.value = string.byte(raw_data, 1)
    return parsed_data
end

function mic_stop_raw_processor(raw_data)
    local parsed_data = {}
    parsed_data.value = string.byte(raw_data, 1)
    return parsed_data
end

function handle_tap()
    pcall(frame.bluetooth.send, string.char(0x09))
end

function start_mic()
    if not mic_active then
        -- Use 16-bit audio like CitizenOneX's implementation
        pcall(frame.microphone.start, {sample_rate=8000, bit_depth=16})
        mic_active = true
        frame.display.text("Listening...", 1, 1)
        frame.display.show()
    end
end

function stop_mic()
    if mic_active then
        pcall(frame.microphone.stop)
        mic_active = false
        -- Send end-of-stream signal
        pcall(frame.bluetooth.send, string.char(0x06))
        frame.sleep(0.0025)
    end
end

function stream_mic()
    -- Prioritize audio streaming like CitizenOneX (20x more than other events)
    for i=1,20 do
        if mic_active then
            local mic_data = frame.microphone.read(mtu)
            
            if mic_data == nil then
                -- Microphone stopped, send final message
                pcall(frame.bluetooth.send, string.char(0x06))
                frame.sleep(0.0025)
                mic_active = false
                break
            elseif mic_data ~= '' then
                -- Send non-final audio data
                pcall(frame.bluetooth.send, string.char(0x05) .. mic_data)
                frame.sleep(0.0025)
            end
        end
    end
end

local msg_processors = {}
msg_processors[0x0a] = text_raw_processor
msg_processors[0x10] = tap_subs_raw_processor
msg_processors[0x12] = clear_raw_processor
msg_processors[0x11] = mic_start_raw_processor
msg_processors[0x13] = mic_stop_raw_processor

function process_raw_items()
    local num_new_items = 0
    for msg_flag, raw_data in pairs(data_block) do
        data[msg_flag] = msg_processors[msg_flag](raw_data)
        data_block[msg_flag] = nil
        num_new_items = num_new_items + 1
    end
    return num_new_items
end

function print_text()
    local line_index = 0
    for line in data[0x0a].data:gmatch("([^\n]*)\n?") do
        if line ~= "" then
            frame.display.text(line, 1, line_index * 60 + 1)
            line_index = line_index + 1
        end
    end
    frame.display.show()
    display_on = true
    display_timeout = frame.time.utc() + 15
end

function clear_display()
    frame.display.text(" ", 1, 1)
    frame.display.show()
    display_on = false
    display_timeout = 0
end

function app_loop()
    clear_display()
    local last_batt_send = 0
    local current_time = 0

    while true do
        rc, err = pcall(function()
            local num_new_items = process_raw_items()
            if num_new_items > 0 then
                if data[0x0a] ~= nil and data[0x0a].data ~= nil then
                    print_text()
                    data[0x0a] = nil
                end

                if data[0x10] ~= nil then
                    if data[0x10].value == 1 then
                        frame.imu.tap_callback(handle_tap)
                    else
                        frame.imu.tap_callback(nil)
                    end
                    data[0x10] = nil
                end

                if data[0x12] ~= nil then
                    clear_display()
                    data[0x12] = nil
                end

                if data[0x11] ~= nil then
                    start_mic()
                    data[0x11] = nil
                end

                if data[0x13] ~= nil then
                    stop_mic()
                    data[0x13] = nil
                end
            end

            -- Stream microphone data with high priority
            stream_mic()

            current_time = frame.time.utc()
            if display_on and display_timeout > 0 and current_time > display_timeout then
                clear_display()
            end

            local utc_time = frame.time.utc()
            if last_batt_send == 0 or utc_time - last_batt_send > 120 then
                pcall(frame.bluetooth.send, string.char(0x0c) .. string.char(math.floor(frame.battery_level())))
                last_batt_send = utc_time
            end

            -- Shorter sleep when not streaming to be more responsive
            if not mic_active then frame.sleep(0.1) end
        end)

        if rc == false then
            clear_display()
            break
        end
    end
end

frame.bluetooth.receive_callback(update_app_data_accum)
frame.display.set_brightness(1)
app_loop()
