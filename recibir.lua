-- ============================================================
-- MUSIC TWEAKS - RECEIVER
-- ============================================================

local REPO =
    "alphaddiction/musictweaks"

local PROTOCOL =
    "musictweaks"


-- ============================================================
-- MODEM
-- ============================================================

local modem =
    peripheral.find(
        "modem",
        function(name, wrapped)
            return wrapped.isWireless()
        end
    )

if not modem then
    error(
        "No se encontro un modem inalambrico."
    )
end

rednet.open(
    peripheral.getName(
        modem
    )
)


-- ============================================================
-- SPEAKER
-- ============================================================

local speakers = {
    peripheral.find(
        "speaker"
    )
}

if #speakers == 0 then
    error(
        "No se encontro ningun speaker."
    )
end


-- ============================================================
-- ZONA
-- ============================================================

local zoneName =
    settings.get(
        "musictweaks.zoneName"
    )

if not zoneName then

    term.clear()

    term.setCursorPos(
        1,
        1
    )

    print(
        "MUSIC TWEAKS RECEIVER"
    )

    print("")
    print(
        "Nombre de esta zona:"
    )

    print(
        "Ejemplo: SALON"
    )

    print("")

    write("> ")

    zoneName =
        read()

    if zoneName == "" then
        zoneName =
            "RECEIVER"
    end

    settings.set(
        "musictweaks.zoneName",
        zoneName
    )

    settings.save()
end


-- ============================================================
-- STATE
-- ============================================================

local centralId = nil

local connected = false

local currentSong = nil

local playing = false

local paused = false

local volume = 0.35

local stopRequested = false

local playRequest = nil

local playGeneration = 0


-- ============================================================
-- SCREEN
-- ============================================================

local function drawUI(
    status
)

    term.setBackgroundColor(
        colors.black
    )

    term.setTextColor(
        colors.white
    )

    term.clear()

    term.setCursorPos(
        1,
        1
    )

    term.setTextColor(
        colors.cyan
    )

    print(
        "================================"
    )

    print(
        "       MUSIC TWEAKS"
    )

    print(
        "        AUDIO RECEIVER"
    )

    print(
        "================================"
    )

    term.setTextColor(
        colors.white
    )

    print("")

    print(
        "ZONE: "
        .. zoneName
    )

    print(
        "ID: "
        .. os.getComputerID()
    )

    print("")

    if connected then

        term.setTextColor(
            colors.lime
        )

        print(
            "● CONNECTED"
        )

    else

        term.setTextColor(
            colors.red
        )

        print(
            "● WAITING FOR CENTRAL"
        )
    end

    term.setTextColor(
        colors.white
    )

    print("")

    print(
        "SONG: "
        .. (
            currentSong
            or "---"
        )
    )

    if playing then

        term.setTextColor(
            colors.lime
        )

        print(
            "● PLAYING"
        )

    elseif paused then

        term.setTextColor(
            colors.yellow
        )

        print(
            "● PAUSED"
        )

    else

        term.setTextColor(
            colors.lightGray
        )

        print(
            "● STOPPED"
        )
    end

    term.setTextColor(
        colors.white
    )

    print("")

    print(
        "VOLUME: "
        .. math.floor(
            volume * 100
        )
        .. "%"
    )

    if status then

        print("")
        print(status)

    end
end


-- ============================================================
-- STOP
-- ============================================================

local function stopSpeakers()

    for _, speaker
        in ipairs(speakers)
    do

        pcall(
            function()
                speaker.stop()
            end
        )
    end
end


-- ============================================================
-- DOWNLOAD SONG
-- ============================================================

local function downloadSong(
    songName
)

    local encoded =
        songName:gsub(
            " ",
            "%%20"
        )

    local url =
        "https://raw.githubusercontent.com/"
        .. REPO
        .. "/refs/heads/main/"
        .. encoded
        .. ".dfpwm"

    local response =
        http.get(url)

    if not response then

        return nil,
            "No se pudo descargar "
            .. songName

    end

    local data =
        response.readAll()

    response.close()

    return data
end


-- ============================================================
-- PLAY SONG
-- ============================================================

local function playSong(
    songName,
    generation
)

    local data, err =
        downloadSong(
            songName
        )

    if not data then

        drawUI(err)

        playing = false

        return
    end

    -- Si mientras descargaba se pidió otra canción,
    -- cancelamos esta reproducción.

    if generation
        ~= playGeneration
    then

        return
    end

    local decoder =
        require(
            "cc.audio.dfpwm"
        ).make_decoder()


    local position = 1

    local chunkSize =
        16 * 1024


    while position <= #data do

        if
            generation
            ~= playGeneration
        then

            return
        end

        if stopRequested then

            return
        end

        if not playing then

            os.sleep(
                0.05
            )

        else

            local chunk =
                data:sub(
                    position,
                    math.min(
                        position
                        + chunkSize
                        - 1,
                        #data
                    )
                )

            local buffer =
                decoder(
                    chunk
                )


            local pending = {}


            for _, speaker
                in ipairs(speakers)
            do

                if not speaker.playAudio(
                    buffer,
                    volume
                )
                then

                    pending[
                        peripheral.getName(
                            speaker
                        )
                    ] =
                        speaker
                end
            end


            while next(pending) do

                if
                    generation
                    ~= playGeneration
                    or stopRequested
                then

                    stopSpeakers()

                    return
                end


                local event,
                    name =
                    os.pullEvent()


                if
                    event
                    == "speaker_audio_empty"
                then

                    local speaker =
                        pending[name]

                    if speaker
                        and speaker.playAudio(
                            buffer,
                            volume
                        )
                    then

                        pending[name] =
                            nil
                    end
                end
            end


            position =
                position
                + #chunk
        end
    end


    -- ========================================================
    -- SONG FINISHED
    -- ========================================================

    if generation
        == playGeneration
        and not stopRequested
    then

        playing = false
        paused = false

        drawUI(
            "FINISHED"
        )

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

            playRequest =
                nil

            stopRequested =
                false

            playing =
                true

            paused =
                false

            currentSong =
                request.song

            drawUI(
                "DOWNLOADING..."
            )

            playSong(
                request.song,
                request.generation
            )

        else

            os.sleep(
                0.05
            )
        end
    end
end


-- ============================================================
-- NETWORK
-- ============================================================

local function networkLoop()

    while true do

        local sender,
            message =
            rednet.receive(
                PROTOCOL
            )

        if
            sender
            and type(message)
            == "table"
        then

            -- ==================================================
            -- CENTRAL
            -- ==================================================

            if
                message.type
                == "CENTRAL_HELLO"
            then

                centralId =
                    sender

                connected =
                    true

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

                drawUI(
                    "CONNECTED"
                )


            -- ==================================================
            -- PING
            -- ==================================================

            elseif
                message.type
                == "PING"
            then

                centralId =
                    sender

                connected =
                    true

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
                message.type
                == "PLAY"
            then

                centralId =
                    sender

                connected =
                    true


                if message.song then

                    playGeneration =
                        playGeneration
                        + 1

                    stopRequested =
                        true

                    stopSpeakers()

                    currentSong =
                        message.song

                    volume =
                        message.volume
                        or volume


                    playRequest =
                        {
                            song =
                                message.song,

                            generation =
                                playGeneration
                        }

                    playing =
                        true

                    paused =
                        false


                    drawUI(
                        "LOADING..."
                    )
                end


            -- ==================================================
            -- PAUSE
            -- ==================================================

            elseif
                message.type
                == "PAUSE"
            then

                playing =
                    false

                paused =
                    true

                drawUI(
                    "PAUSED"
                )


            -- ==================================================
            -- STOP
            -- ==================================================

            elseif
                message.type
                == "STOP"
            then

                playGeneration =
                    playGeneration
                    + 1

                stopRequested =
                    true

                playRequest =
                    nil

                playing =
                    false

                paused =
                    false

                stopSpeakers()

                drawUI(
                    "STOPPED"
                )


            -- ==================================================
            -- VOLUME
            -- ==================================================

            elseif
                message.type
                == "VOLUME"
            then

                volume =
                    math.max(
                        0,
                        math.min(
                            1,
                            message.volume
                            or volume
                        )
                    )

                drawUI(
                    "VOLUME"
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

drawUI(
    "STARTING"
)

parallel.waitForAny(

    networkLoop,
    playbackLoop,
    connectionLoop

)
