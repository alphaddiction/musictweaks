-- ============================================================
-- MUSIC TWEAKS
-- AUDIO RECEIVER
-- ============================================================

local PROTOCOL =
    "musictweaks"


-- ============================================================
-- WIRELESS MODEM
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
        "No wireless modem found."
    )

end


rednet.open(
    peripheral.getName(
        modem
    )
)


-- ============================================================
-- DFPWM
-- ============================================================

local dfpwm =
    require("cc.audio.dfpwm")


-- ============================================================
-- ZONE NAME
-- ============================================================

local zoneName =
    settings.get(
        "musictweaks.zoneName",
        nil
    )


if not zoneName then

    term.clear()

    term.setCursorPos(
        1,
        1
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

    print("")

    print(
        "Nombre de esta zona:"
    )

    print(
        "Ejemplo: SALON"
    )

    print("")

    write(
        "> "
    )


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
-- SPEAKERS
-- ============================================================

local speakers = {
    peripheral.find(
        "speaker"
    )
}


if #speakers == 0 then

    error(
        "No speaker found."
    )

end


-- ============================================================
-- STATE
-- ============================================================

local connected =
    false


local centralId =
    nil


local playing =
    false


local paused =
    false


local volume =
    0.35


local currentSong =
    nil


local currentSequence =
    0


local expectedSequence =
    1


local audioQueue =
    {}


local stopRequested =
    false


local decoder =
    dfpwm.make_decoder()


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


    term.setTextColor(
        colors.white
    )

    print(
        "================================"
    )

    print("")


    print(
        "ZONE: "
        .. zoneName
    )


    print(
        "COMPUTER ID: "
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


    if currentSong then

        print(
            "SONG: "
            .. currentSong
        )

    else

        print(
            "SONG: ---"
        )

    end


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


    print("")


    print(
        "BUFFER: "
        .. #audioQueue
    )


    if status then

        print("")

        term.setTextColor(
            colors.lightGray
        )

        print(
            status
        )

    end

end


-- ============================================================
-- STOP SPEAKERS
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
-- CLEAR AUDIO
-- ============================================================

local function clearAudio()

    audioQueue =
        {}

    currentSequence =
        0

    expectedSequence =
        1

    stopSpeakers()

end


-- ============================================================
-- SEND HELLO
-- ============================================================

local function sendHello()

    rednet.broadcast(

        {
            type =
                "HELLO",

            zone =
                zoneName,

            computerId =
                os.getComputerID(),

            speakers =
                #speakers
        },

        PROTOCOL

    )

end


-- ============================================================
-- PLAY AUDIO BUFFER
-- ============================================================

local function playBuffer(
    encodedData,
    bufferVolume
)

    local buffer =
        decoder(
            encodedData
        )


    local pending =
        {}


    for _, speaker
        in ipairs(speakers)
    do

        if not speaker.playAudio(
            buffer,
            bufferVolume
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


    -- ========================================================
    -- WAIT FOR SPEAKER
    -- ========================================================

    while next(pending) do

        local event,
            name =
            os.pullEvent()


        if event ==
            "speaker_audio_empty"
        then

            local speaker =
                pending[name]


            if speaker
                and speaker.playAudio(
                    buffer,
                    bufferVolume
                )
            then

                pending[name] =
                    nil

            end

        elseif event ==
            "rednet_message"
        then

            -- Do not let the receiver become completely
            -- unresponsive to STOP while audio is playing.

            -- The network listener will handle the actual
            -- command in its own parallel process.

        end

    end

end


-- ============================================================
-- AUDIO PLAYER
-- ============================================================

local function audioPlayer()

    while true do

        if stopRequested then

            stopRequested =
                false

            clearAudio()

            playing =
                false

            paused =
                false


            drawUI(
                "STOP"
            )

        elseif #audioQueue > 0
            and playing
        then

            local packet =
                table.remove(
                    audioQueue,
                    1
                )


            if packet then

                playBuffer(
                    packet.data,
                    packet.volume
                    or volume
                )


                rednet.send(

                    centralId,

                    {
                        type =
                            "AUDIO_ACK",

                        sequence =
                            packet.sequence,

                        zone =
                            zoneName
                    },

                    PROTOCOL

                )

            end

        else

            os.sleep(
                0.01
            )

        end

    end

end


-- ============================================================
-- NETWORK
-- ============================================================

local function networkLoop()

    sendHello()


    while true do

        local sender,
            message =
            rednet.receive(
                PROTOCOL
            )


        if sender
            and type(message)
            == "table"
        then

            -- ==================================================
            -- CENTRAL HELLO
            -- ==================================================

            if message.type
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

                        computerId =
                            os.getComputerID(),

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

            elseif message.type
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

                        computerId =
                            os.getComputerID(),

                        speakers =
                            #speakers
                    },

                    PROTOCOL

                )


            -- ==================================================
            -- PLAY
            -- ==================================================

            elseif message.type
                == "PLAY"
            then

                centralId =
                    sender

                connected =
                    true

                playing =
                    true

                paused =
                    false


                if message.song then

                    currentSong =
                        message.song

                end


                if message.volume then

                    volume =
                        message.volume

                end


                drawUI(
                    "PLAY"
                )


            -- ==================================================
            -- PAUSE
            -- ==================================================

            elseif message.type
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

            elseif message.type
                == "STOP"
            then

                stopRequested =
                    true

                playing =
                    false

                paused =
                    false

                audioQueue =
                    {}


                drawUI(
                    "STOP"
                )


            -- ==================================================
            -- VOLUME
            -- ==================================================

            elseif message.type
                == "VOLUME"
            then

                if message.volume then

                    volume =
                        math.max(
                            0,
                            math.min(
                                1,
                                message.volume
                            )
                        )

                end


                drawUI(
                    "VOLUME"
                )


            -- ==================================================
            -- AUDIO
            -- ==================================================

            elseif message.type
                == "AUDIO"
            then

                centralId =
                    sender

                connected =
                    true


                if message.song then

                    if currentSong
                        ~= message.song
                    then

                        currentSong =
                            message.song

                        clearAudio()

                    end

                end


                -- =================================================
                -- Detectar perdida de paquetes
                -- =================================================

                if message.sequence
                    and message.sequence
                    >= expectedSequence
                then

                    table.insert(
                        audioQueue,
                        {
                            data =
                                message.data,

                            sequence =
                                message.sequence,

                            volume =
                                message.volume
                                or volume
                        }
                    )


                    expectedSequence =
                        message.sequence
                        + 1


                    playing =
                        true

                    paused =
                        false

                end


            -- ==================================================
            -- AUDIO END
            -- ==================================================

            elseif message.type
                == "AUDIO_END"
            then

                -- The last queued audio will finish naturally.

                currentSong =
                    message.song


            end

        end

    end

end


-- ============================================================
-- CONNECTION WATCHDOG
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

                    computerId =
                        os.getComputerID(),

                    speakers =
                        #speakers
                },

                PROTOCOL

            )

        else

            sendHello()

        end


        os.sleep(
            5
        )

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

    audioPlayer,

    connectionLoop

)
