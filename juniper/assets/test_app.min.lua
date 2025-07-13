-- Simple test app to check upload timeout
function handle_tap()
    frame.bluetooth.send(string.char(0x09))
end

function app_loop()
    frame.display.text("Test", 1, 1)
    frame.display.show()
    
    while true do
        frame.sleep(1)
    end
end

frame.bluetooth.receive_callback(function(data) end)
frame.imu.tap_callback(handle_tap)
app_loop()
