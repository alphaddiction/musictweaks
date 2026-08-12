-- ============================================================
-- MUSIC TWEAKS - RECEIVER
-- VERSION CORREGIDA
-- ============================================================

local REPO = "alphaddiction/musictweaks"
local BRANCH = "main"
local PROTOCOL = "musictweaks"

local dfpwm = require("cc.audio.dfpwm")

-- ============================================================
-- MODEM
-- ============================================================

local modem = peripheral.find("modem", function(name, wrapped)
    return wrapped.isWireless()
end)

if not modem then
    error("No se encontro un modem inalambrico.")
end

rednet.open(peripheral.getName(modem))

-- ============================================================
-- SPEAKERS
-- ============================================================

local speakers = {
    peripheral.find("speaker")
}

if #speakers == 0 then
    error("No se encontro ningun speaker.")
end

-- ============================================================
-- ZONA
-- ============================================================

local zoneName = settings.get("musictweaks.zoneName")

if not zoneName then

    term.clear()
    term.setCursorPos(1, 1)

    print("MUSIC TWEAKS RECEIVER")
    print("")
    print("Nombre de esta zona:")
    print("Ejemplo: SALON")
    print("")
    write("> ")

    zoneName = read()

    if zoneName == "" then
        zoneName = "RECEIVER"
    end

    settings.set(
        "musictweaks.zoneName",
        zoneName
    )

    settings.save()
end

-- ============================================================
-- ESTADO
-- ============================================================

local centralId = nil
local connected = false

local currentSong = nil

local playing = false
local paused = false

local volume = 0.35

local playbackId = 0
local playRequest = nil

local status = "Iniciando..."

-- ============================================================
-- PANTALLA
-- ============================================================

local function drawUI()

    term.setBackgroundColor(colors.black)
    term.setTextColor(colors.white)

    term.clear()
    term.setCursorPos(1, 1)

    term.setTextColor(colors.cyan)

    print("================================")
    print("        MUSIC TWEAKS")
    print("        AUDIO RECEIVER")
    print("================================")

    term.setTextColor(colors.white)

    print("")
    print("ZONE: " .. zoneName)
    print("ID:   " .. os.getComputerID())
    print("")

    if connected then
        term.setTextColor(colors.lime)
        print("● CONNECTED")
    else
        term.setTextColor(colors.red)
        print("● WAITING FOR CENTRAL")
    end

    term.setTextColor(colors.white)

    print("")

    print(
        "SONG: "
        .. (currentSong or "---")
    )

    if playing then

        term.setTextColor(colors.lime)
        print("● PLAYING")

    elseif paused then

        term.setTextColor(colors.yellow)
        print("● PAUSED")

    else

        term.setTextColor(colors.lightGray)
        print("● STOPPED")

    end

    term.setTextColor(colors.white)

    print("")

    print(
        "VOLUME: "
        .. math.floor(volume * 100)
        .. "%"
    )

    print("")
    print(status)
end

-- ============================================================
-- ESTADO SIN REDIBUJAR
-- ============================================================

local function setStatus(text)

    status = text

    drawUI()
end

-- ============================================================
-- STOP SPEAKERS
-- ============================================================

local function stopSpeakers()

    for _, speaker in ipairs(speakers) do

        pcall(function()
            speaker.stop()
        end)

    end
end

-- ============================================================
-- URL ENCODE
--
-- Esto es importante para:
-- espacios
-- emojis
-- acentos
-- parentesis
-- caracteres especiales
-- ============================================================

local function urlEncodePath(text)

    local result = {}

    for i = 1, #text do

        local byte = string.byte(text, i)

        -- Caracteres URL seguros
        if
            (byte >= 48 and byte <= 57)
            or
            (byte >= 65 and byte <= 90)
            or
            (byte >= 97 and byte <= 122)
            or
            byte == 45
            or
            byte == 46
            or
            byte == 95
            or
            byte == 126
        then

            table.insert(
                result,
                string.char(byte)
            )

        else

            table.insert(
                result,
                string.format(
                    "%%%02X",
                    byte
                )
            )

        end
    end

    return table.concat(result)
end

-- ============================================================
-- URL DE LA CANCION
-- ============================================================

local function getSongURL(songName)

    return
        "https://raw.githubusercontent.com/"
        .. REPO
        .. "/refs/heads/"
        .. BRANCH
        .. "/"
        .. urlEncodePath(songName)
        .. ".dfpwm"

end

-- ============================================================
-- DESCARGAR
-- ============================================================

local function downloadSong(songName)

    local url =
        getSongURL(songName)

    setStatus(
        "Descargando..."
    )

    local response, err =
        http.get(url)

    if not response then

        return nil,
            "ERROR DESCARGA\n"
            .. tostring(err)
            .. "\n\n"
            .. songName

    end

    local data =
        response.readAll()

    response.close()

    if not data or #data == 0 then

        return nil,
            "ARCHIVO VACIO\n"
            .. songName

    end

    return data
end

-- ============================================================
-- REPRODUCCION
-- ============================================================

local function playSong(
    songName,
    myPlaybackId
)

    local data, err =
        downloadSong(songName)

    if not data then

        playing = false
        paused = false

        setStatus(err)

        return
    end

    -- Si ya se pidio otra cancion
    if myPlaybackId ~= playbackId then
        return
    end

    setStatus(
        "Preparando audio..."
    )

    local decoder =
        dfpwm.make_decoder()

    local chunkSize =
        16 * 1024

    local position = 1

    playing = true
    paused = false

    setStatus(
        "Reproduciendo"
    )

    while position <= #data do

        -- Cancelado
        if myPlaybackId ~= playbackId then
            stopSpeakers()
            return
        end

        -- PAUSA
        while paused do

            if myPlaybackId ~= playbackId then
                stopSpeakers()
                return
            end

            os.sleep(0.1)
        end

        if not playing then
            stopSpeakers()
            return
        end

        local chunk =
            data:sub(
                position,
                math.min(
                    position + chunkSize - 1,
                    #data
                )
            )

        local audio =
            decoder(chunk)

        -- ====================================================
        -- ENVIAR AUDIO A TODOS LOS SPEAKERS
        -- ====================================================

        local pending = {}

        for _, speaker in ipairs(speakers) do

            local name =
                peripheral.getName(speaker)

            local ok =
                speaker.playAudio(
                    audio,
                    volume
                )

            if not ok then

                pending[name] =
                    speaker

            end
        end

        -- ====================================================
        -- ESPERAR SOLO SI EL SPEAKER ESTA LLENO
        -- ====================================================

        while next(pending) do

            if myPlaybackId ~= playbackId then

                stopSpeakers()
                return

            end

            while paused do

                os.sleep(0.05)

                if myPlaybackId ~= playbackId then
                    stopSpeakers()
                    return
                end
            end

            if not playing then

                stopSpeakers()
                return

            end

            local event, name =
                os.pullEvent()

            if event ==
                "speaker_audio_empty"
            then

                local speaker =
                    pending[name]

                if speaker then

                    local ok =
                        speaker.playAudio(
                            audio,
                            volume
                        )

                    if ok then
                        pending[name] = nil
                    end
                end
            end
        end

        position =
            position + #chunk
    end

    -- ========================================================
    -- FIN
    -- ========================================================

    if myPlaybackId ==
        playbackId
    then

        playing = false
        paused = false

        setStatus(
            "Cancion terminada"
        )

        if centralId then

            rednet.send(
                centralId,
                {
                    type =
                        "SONG_FINISHED",

                    song =
                        songName,

                    zone =
                        zoneName
                },
                PROTOCOL
            )
        end
    end
end

-- ============================================================
-- PLAYBACK MANAGER
-- ============================================================

local function playbackLoop()

    while true do

        if playRequest then

            local request =
                playRequest

            playRequest = nil

            playSong(
                request.song,
                request.id
            )

        else

            os.sleep(0.05)

        end
    end
end

-- ============================================================
-- NETWORK
-- ============================================================

local function networkLoop()

    while true do

        local sender, message =
            rednet.receive(
                PROTOCOL
            )

        if
            sender
            and type(message) == "table"
        then

            -- ==================================================
            -- CENTRAL HELLO
            -- ==================================================

            if
                message.type ==
                "CENTRAL_HELLO"
            then

                centralId =
                    sender

                connected = true

                rednet.send(
                    centralId,
                    {
                        type =
                            "RECEIVER_HELLO",

                        zone =
                            zoneName,

                        speakers =
                            #speakers
                    },
                    PROTOCOL
                )

                setStatus(
                    "Conectado"
                )

            -- ==================================================
            -- PING
            -- ==================================================

            elseif
                message.type ==
                "PING"
            then

                centralId =
                    sender

                connected = true

                rednet.send(
                    centralId,
                    {
                        type =
                            "PONG",

                        zone =
                            zoneName,

                        speakers =
                            #speakers
                    },
                    PROTOCOL
                )

            -- ==================================================
            -- PLAY
            -- ==================================================

            elseif
                message.type ==
                "PLAY"
            then

                centralId =
                    sender

                connected = true

                if message.song then

                    playbackId =
                        playbackId + 1

                    -- Detener inmediatamente
                    stopSpeakers()

                    currentSong =
                        message.song

                    volume =
                        message.volume
                        or volume

                    playing = true
                    paused = false

                    playRequest =
                        {
                            song =
                                message.song,

                            id =
                                playbackId
                        }

                    setStatus(
                        "Cargando..."
                    )
                end

            -- ==================================================
            -- PAUSE
            -- ==================================================

            elseif
                message.type ==
                "PAUSE"
            then

                paused = true
                playing = true

                setStatus(
                    "Pausado"
                )

            -- ==================================================
            -- STOP
            -- ==================================================

            elseif
                message.type ==
                "STOP"
            then

                playbackId =
                    playbackId + 1

                playRequest = nil

                playing = false
                paused = false

                stopSpeakers()

                setStatus(
                    "Detenido"
                )

            -- ==================================================
            -- VOLUME
            -- ==================================================

            elseif
                message.type ==
                "VOLUME"
            then

                volume =
                    math.max(
                        0,
                        math.min(
                            1,
                            tonumber(
                                message.volume
                            )
                            or volume
                        )
                    )

                setStatus(
                    "Volumen "
                    .. math.floor(
                        volume * 100
                    )
                    .. "%"
                )
            end
        end
    end
end

-- ============================================================
-- CONNECTION
-- ============================================================

local function connectionLoop()

    while true do

        if centralId then

            rednet.send(
                centralId,
                {
                    type =
                        "PONG",

                    zone =
                        zoneName,

                    speakers =
                        #speakers
                },
                PROTOCOL
            )

        else

            rednet.broadcast(
                {
                    type =
                        "HELLO",

                    zone =
                        zoneName,

                    speakers =
                        #speakers
                },
                PROTOCOL
            )
        end

        os.sleep(5)
    end
end

-- ============================================================
-- START
-- ============================================================

drawUI()

parallel.waitForAny(
    networkLoop,
    playbackLoop,
    connectionLoop
)
