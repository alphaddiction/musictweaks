local dfpwm = require "cc.audio.dfpwm"
local modem = peripheral.find("modem") or error("No Ender Modem attached!")

term.clear()
term.setCursorPos(1, 1)
print("====================================")
print("    TUNABLE STREAM TRANSMITTER      ")
print("====================================")

-- 1. Prompt user for the broadcasting frequency
write("Enter transmission channel (e.g. 99): ")
local CHANNEL = tonumber(read())
if not CHANNEL or CHANNEL < 1 or CHANNEL > 65535 then
    error("Invalid channel! Please enter a number between 1 and 65535.")
end

-- 2. Prompt user for the direct raw audio URL
print("\nPlease enter or paste your direct raw link:")
write("> ")
local url = read()
if not url or url == "" then error("You must enter a valid URL!") end

term.clear()
term.setCursorPos(1, 1)
print("Channel Tuned: " .. CHANNEL)
print("Requesting stream connection...")

-- Asynchronous HTTP request prevents 15MB+ files from freezing the thread
http.request({ url = url, binary = true })

local response = nil
local timeoutTimer = os.startTimer(360)

while true do
    local event, p1, p2 = os.pullEvent()
    if event == "http_success" and p1 == url then
        response = p2
        break
    elseif event == "http_failure" and p1 == url then
        error("Connection failed! Check the link or server config.")
    elseif event == "timer" and p1 == timeoutTimer then
        error("Connection timed out! Server HTTP might be disabled.")
    end
end

print("Connected! Broadcasting pipeline...")
print("Press Ctrl+T to cancel transmission.")

local chunk_size = 1024 
local delay = chunk_size / (48000 / 8) 

while true do
    local chunk = response.read(chunk_size)
    if not chunk then break end
    
    -- Broadcast over the dynamically selected channel
    modem.transmit(CHANNEL, CHANNEL, chunk)
    os.sleep(delay) 
end

response.close()
print("\nStream finished successfully!")