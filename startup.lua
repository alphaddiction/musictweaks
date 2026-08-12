-- ============================================================
-- MUSIC TWEAKS
-- CENTRAL CONTROLLER
-- ============================================================

local repo = "alphaddiction/musictweaks"

local NETWORK_PROTOCOL = "musictweaks"


-- ============================================================
-- DFPWM
-- ============================================================

local dfpwm = require("cc.audio.dfpwm")


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

    term.clear()
    term.setCursorPos(1, 1)

    term.setTextColor(colors.red)

    print("MUSIC TWEAKS")
    print("")
    print("ERROR")
    print("")
    print("No wireless modem found.")
    print("")
    print("Connect a wireless modem to")
    print("this computer.")

    error("No wireless modem found")

end


local modemName =
    peripheral.getName(modem)


rednet.open(modemName)


-- ============================================================
-- OPTIONAL LOCAL SPEAKERS
-- ============================================================
--
-- El CENTRAL ya NO necesita speaker.
-- Si tiene uno conectado, puede reproducir localmente.
--

local speakers = {
    peripheral.find("speaker")
}


-- ============================================================
-- TERMINAL
-- ============================================================

term.setBackgroundColor(
    colors.black
)

term.setTextColor(
    colors.white
)

term.clear()


local width,
    height =
    term.getSize()


-- ============================================================
-- SONGS
-- ============================================================

local songIndexUrl =
    "https://raw.githubusercontent.com/"
    .. repo
    .. "/refs/heads/main/index.txt"


local response =
    http.get(
        songIndexUrl
    )


if not response then

    error(
        "No se pudo descargar el index.txt desde GitHub"
    )

end


local indexData =
    response.readAll()


response.close()


local songNames =
    textutils.unserialize(
        indexData
    )


if not songNames then

    error(
        "El index.txt no tiene un formato valido"
    )

end


local songs = {}


for _, name in ipairs(songNames) do

    table.insert(
        songs,

        {
            name = name,

            fn = function()

                local encodedName =
                    name:gsub(
                        " ",
                        "%%20"
                    )


                local url =
                    "https://raw.githubusercontent.com/"
                    .. repo
                    .. "/refs/heads/main/"
                    .. encodedName
                    .. ".dfpwm"


                local songResponse =
                    http.get(url)


                if not songResponse then

                    error(
                        "No se pudo descargar: "
                        .. name
                        .. ".dfpwm"
                    )

                end


                local data =
                    songResponse.readAll()


                songResponse.close()


                return data

            end
        }
    )

end


if #songs == 0 then

    error(
        "No hay canciones en index.txt"
    )

end


-- ============================================================
-- SETTINGS
-- ============================================================

local savedName =
    settings.get(
        "currentSong",
        nil
    )


local currentSong = nil


if savedName then

    for _, song in ipairs(songs) do

        if song.name == savedName then

            currentSong =
                song

            break

        end

    end

end


local playing =
    settings.get(
        "playing",
        false
    )


local shuffle =
    settings.get(
        "shuffle",
        true
    )


local loopMode =
    settings.get(
        "loopMode",
        0
    )


local volume =
    settings.get(
        "volume",
        0.35
    )


local currentPage =
    settings.get(
        "currentPage",
        1
    )


-- ============================================================
-- PLAYBACK
-- ============================================================

local stopFlag = false


local playbackToken = 0


local decoder =
    dfpwm.make_decoder()


-- ============================================================
-- NETWORK ZONES
-- ============================================================

local zones = {}


-- ============================================================
-- PAGE
-- ============================================================

local topRows = 8

local bottomRows = 7


local songsPerPage =
    height
    - topRows
    - bottomRows


if songsPerPage < 1 then

    songsPerPage = 1

end


local function totalPages()

    return math.max(
        1,

        math.ceil(
            #songs /
            songsPerPage
        )
    )

end


if currentPage < 1 then

    currentPage = 1

end


if currentPage > totalPages() then

    currentPage =
        totalPages()

end


-- ============================================================
-- BUTTONS
-- ============================================================

local buttons = {}


-- ============================================================
-- SAVE SETTINGS
-- ============================================================

local function saveSettings()

    settings.set(
        "currentPage",
        currentPage
    )


    settings.set(
        "loopMode",
        loopMode
    )


    settings.set(
        "shuffle",
        shuffle
    )


    settings.set(
        "playing",
        playing
    )


    settings.set(
        "volume",
        volume
    )


    if currentSong then

        settings.set(
            "currentSong",
            currentSong.name
        )

    else

        settings.unset(
            "currentSong"
        )

    end


    settings.save()

end


-- ============================================================
-- STOP LOCAL SPEAKERS
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
-- DRAW BUTTON
-- ============================================================

local function drawButton(
    x,
    y,
    text,
    action,
    bg,
    fg
)

    bg =
        bg or colors.gray

    fg =
        fg or colors.white


    term.setCursorPos(
        x,
        y
    )


    term.setBackgroundColor(
        bg
    )

    term.setTextColor(
        fg
    )


    local output =
        " "
        .. text
        .. " "


    term.write(
        output
    )


    table.insert(
        buttons,

        {
            x1 = x,

            x2 =
                x
                + #output
                - 1,

            y1 = y,

            y2 = y,

            action = action
        }
    )

end


-- ============================================================
-- DRAW UI
-- ============================================================

local function drawUI()

    buttons = {}


    term.setBackgroundColor(
        colors.black
    )

    term.setTextColor(
        colors.white
    )

    term.clear()


    -- ========================================================
    -- HEADER
    -- ========================================================

    term.setBackgroundColor(
        colors.blue
    )

    term.setCursorPos(
        1,
        1
    )


    term.write(
        string.rep(
            " ",
            width
        )
    )


    local title =
        " MUSIC TWEAKS - CENTRAL "


    term.setCursorPos(
        math.max(
            1,
            math.floor(
                (
                    width
                    - #title
                )
                / 2
            )
        ),
        1
    )


    term.setTextColor(
        colors.white
    )

    term.write(
        title
    )


    -- ========================================================
    -- CONNECTION STATUS
    -- ========================================================

    term.setCursorPos(
        2,
        2
    )

    term.setBackgroundColor(
        colors.black
    )

    term.setTextColor(
        colors.lightGray
    )


    local zoneCount = 0


    for _, _ in pairs(zones) do

        zoneCount =
            zoneCount + 1

    end


    term.write(
        "NETWORK  "
        .. zoneCount
        .. " ZONE"
        .. (
            zoneCount == 1
            and ""
            or "S"
        )
        .. " CONNECTED"
    )


    -- ========================================================
    -- NOW PLAYING
    -- ========================================================

    term.setCursorPos(
        2,
        3
    )

    term.setTextColor(
        colors.cyan
    )

    term.write(
        "NOW PLAYING"
    )


    term.setCursorPos(
        2,
        4
    )

    term.setTextColor(
        colors.white
    )


    local songTitle =
        currentSong
        and currentSong.name
        or "(none)"


    if #songTitle >
        width - 2
    then

        songTitle =
            songTitle:sub(
                1,
                width - 5
            )
            .. "..."

    end


    term.write(
        songTitle
    )


    term.setCursorPos(
        2,
        5
    )


    if playing then

        term.setTextColor(
            colors.lime
        )

        term.write(
            "● PLAYING"
        )

    else

        term.setTextColor(
            colors.lightGray
        )

        term.write(
            "● STOPPED"
        )

    end


    -- ========================================================
    -- ZONES
    -- ========================================================

    term.setCursorPos(
        2,
        6
    )

    term.setTextColor(
        colors.cyan
    )

    term.write(
        "CONNECTED ZONES"
    )


    local zoneY = 7


    local zoneList = {}


    for id, zone
        in pairs(zones)
    do

        table.insert(
            zoneList,

            {
                id = id,
                zone = zone
            }
        )

    end


    table.sort(
        zoneList,

        function(a, b)

            return a.id < b.id

        end
    )


    for _, item
        in ipairs(zoneList)
    do

        if zoneY <= 8 then

            local zone =
                item.zone


            term.setCursorPos(
                2,
                zoneY
            )


            term.setTextColor(
                colors.lime
            )

            term.write(
                "● "
            )


            term.setTextColor(
                colors.white
            )


            local zoneName =
                zone.name
                or "UNKNOWN"


            local zoneText =
                zoneName
                .. "  ID:"
                .. item.id
                .. "  SPK:"
                .. (
                    zone.speakers
                    or 0
                )


            if #zoneText >
                width - 2
            then

                zoneText =
                    zoneText:sub(
                        1,
                        width - 2
                    )

            end


            term.write(
                zoneText
            )


            zoneY =
                zoneY + 1

        end

    end


    -- ========================================================
    -- PLAYLIST
    -- ========================================================

    local playlistHeader =
        math.max(
            9,
            zoneY + 1
        )


    term.setCursorPos(
        2,
        playlistHeader
    )

    term.setTextColor(
        colors.cyan
    )

    term.write(
        "PLAYLIST"
    )


    local startIdx =
        (
            currentPage - 1
        )
        * songsPerPage
        + 1


    local songY =
        playlistHeader + 1


    local endIdx =
        math.min(
            startIdx
            + songsPerPage
            - 1,

            #songs
        )


    for i = startIdx,
        endIdx
    do

        if songY >
            height - bottomRows
        then

            break

        end


        term.setCursorPos(
            2,
            songY
        )


        if currentSong ==
            songs[i]
        then

            term.setTextColor(
                colors.yellow
            )

            term.write(
                "> "
            )

        else

            term.setTextColor(
                colors.lightGray
            )

            term.write(
                "  "
            )

        end


        term.setTextColor(
            colors.white
        )


        local songText =
            string.format(
                "%02d",
                i
            )
            .. " "
            .. songs[i].name


        if #songText >
            width - 4
        then

            songText =
                songText:sub(
                    1,
                    width - 7
                )
                .. "..."

        end


        term.write(
            songText
        )


        songY =
            songY + 1

    end


    -- ========================================================
    -- BUTTONS
    -- ========================================================

    local controlY =
        height - 6


    drawButton(
        2,
        controlY,
        playing
        and "PAUSE"
        or "PLAY",

        "play",

        playing
        and colors.green
        or colors.blue,

        colors.black
    )


    drawButton(
        12,
        controlY,
        "STOP",

        "stop",

        colors.red,

        colors.white
    )


    drawButton(
        21,
        controlY,
        "NEXT >>",

        "next",

        colors.blue,

        colors.white
    )


    -- ========================================================
    -- SECOND ROW
    -- ========================================================

    local modeY =
        height - 4


    drawButton(
        2,
        modeY,
        shuffle
        and "SHUFFLE ON"
        or "SHUFFLE OFF",

        "shuffle",

        shuffle
        and colors.green
        or colors.gray,

        shuffle
        and colors.black
        or colors.white
    )


    local loopText


    if loopMode == 0 then

        loopText =
            "LOOP OFF"

    elseif loopMode == 1 then

        loopText =
            "LOOP ALL"

    else

        loopText =
            "LOOP ONE"

    end


    drawButton(
        18,
        modeY,
        loopText,

        "loop",

        colors.purple,

        colors.white
    )


    -- ========================================================
    -- VOLUME
    -- ========================================================

    term.setCursorPos(
        2,
        height - 2
    )

    term.setTextColor(
        colors.lightGray
    )


    term.write(
        "VOLUME "
        .. math.floor(
            volume * 100
        )
        .. "%"
    )


    drawButton(
        13,
        height - 2,
        "-",

        "volumeDown"
    )


    drawButton(
        18,
        height - 2,
        "+",

        "volumeUp"
    )


    -- ========================================================
    -- PAGE
    -- ========================================================

    local pageText =
        "PAGE "
        .. currentPage
        .. "/"
        .. totalPages()


    term.setCursorPos(
        math.max(
            1,
            width - #pageText - 1
        ),
        height - 2
    )

    term.setTextColor(
        colors.cyan
    )

    term.write(
        pageText
    )


    term.setBackgroundColor(
        colors.black
    )

end


-- ============================================================
-- NETWORK: UPDATE ZONE
-- ============================================================

local function updateZone(
    id,
    message
)

    zones[id] = {

        id = id,

        name =
            message.zone
            or (
                "ZONE "
                .. tostring(id)
            ),

        speakers =
            message.speakers
            or 0,

        lastSeen =
            os.clock()

    }


    drawUI()

end


-- ============================================================
-- NETWORK: ANNOUNCE CENTRAL
-- ============================================================

local function announceCentral()

    rednet.broadcast(

        {
            type =
                "CENTRAL_HELLO"
        },

        NETWORK_PROTOCOL

    )

end


-- ============================================================
-- NETWORK LISTENER
-- ============================================================

local function networkListener()

    while true do

        local senderId,
            message =
            rednet.receive(
                NETWORK_PROTOCOL
            )


        if senderId
            and type(message)
            == "table"
        then

            if message.type
                == "HELLO"
                or message.type
                == "RECEIVER_HELLO"
                or message.type
                == "PONG"
            then

                updateZone(
                    senderId,
                    message
                )


                rednet.send(

                    senderId,

                    {
                        type =
                            "CENTRAL_HELLO"
                    },

                    NETWORK_PROTOCOL

                )

            end

        end

    end

end


-- ============================================================
-- NETWORK MAINTENANCE
-- ============================================================

local function networkMaintenance()

    while true do

        announceCentral()


        local now =
            os.clock()


        for id, zone
            in pairs(zones)
        do

            rednet.send(

                id,

                {
                    type =
                        "PING"
                },

                NETWORK_PROTOCOL

            )


            if now -
                zone.lastSeen
                > 15
            then

                zones[id] =
                    nil

            end

        end


        drawUI()


        os.sleep(5)

    end

end


-- ============================================================
-- PLAYBACK
-- ============================================================

local function playerLoop()

    while true do

        if currentSong
            and playing
            and #speakers > 0
        then

            local token =
                playbackToken


            local ok,
                songData =
                pcall(
                    currentSong.fn
                )


            if not ok then

                playing = false

                drawUI()

                os.sleep(1)

            else

                local dataLen =
                    #songData


                for i = 1,
                    dataLen,
                    16 * 1024
                do

                    if stopFlag
                        or token
                        ~= playbackToken
                    then

                        break

                    end


                    local chunk =
                        songData:sub(
                            i,
                            math.min(
                                i
                                + 16 * 1024
                                - 1,

                                dataLen
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


                    while
                        not stopFlag
                        and token
                        == playbackToken
                        and next(pending)
                    do

                        local event,
                            name =
                            os.pullEvent(
                                "speaker_audio_empty"
                            )


                        if event ==
                            "speaker_audio_empty"
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

                end


                if token ==
                    playbackToken
                    and not stopFlag
                then

                    if loopMode == 2 then

                        -- LOOP ONE


                    elseif shuffle then

                        currentSong =
                            songs[
                                math.random(
                                    #songs
                                )
                            ]


                    else

                        local idx = 1


                        for i, song
                            in ipairs(songs)
                        do

                            if song ==
                                currentSong
                            then

                                idx = i

                                break

                            end

                        end


                        if idx < #songs then

                            currentSong =
                                songs[
                                    idx + 1
                                ]

                        elseif loopMode == 1 then

                            currentSong =
                                songs[1]

                        else

                            currentSong = nil

                            playing = false

                        end

                    end


                    saveSettings()

                    drawUI()

                end


                stopFlag = false

            end

        else

            os.sleep(
                0.05
            )

        end

    end

end


-- ============================================================
-- BUTTON ACTION
-- ============================================================

local function buttonAction(
    action
)

    if action == "play" then

        if not currentSong then

            return

        end


        if playing then

            playing = false

            stopFlag = true

            playbackToken =
                playbackToken + 1

            stopSpeakers()

        else

            playing = true

            stopFlag = false

            playbackToken =
                playbackToken + 1

        end


    elseif action == "stop" then

        playing = false

        stopFlag = true

        playbackToken =
            playbackToken + 1

        stopSpeakers()


    elseif action == "next" then

        if #songs > 0 then

            local idx = 1


            if currentSong then

                for i, song
                    in ipairs(songs)
                do

                    if song ==
                        currentSong
                    then

                        idx = i

                        break

                    end

                end

            end


            if shuffle
                and #songs > 1
            then

                local newIndex


                repeat

                    newIndex =
                        math.random(
                            #songs
                        )

                until
                    songs[newIndex]
                    ~= currentSong


                currentSong =
                    songs[newIndex]

            elseif idx < #songs then

                currentSong =
                    songs[
                        idx + 1
                    ]

            elseif loopMode == 1 then

                currentSong =
                    songs[1]

            else

                currentSong =
                    songs[1]

            end


            stopFlag = true

            playbackToken =
                playbackToken + 1

            stopSpeakers()

            playing = true

        end


    elseif action == "shuffle" then

        shuffle =
            not shuffle


    elseif action == "loop" then

        loopMode =
            (
                loopMode + 1
            ) % 3


    elseif action == "volumeDown" then

        volume =
            math.max(
                0,
                volume - 0.05
            )


    elseif action == "volumeUp" then

        volume =
            math.min(
                1,
                volume + 0.05
            )

    end


    saveSettings()

    drawUI()

end


-- ============================================================
-- MOUSE
-- ============================================================

local function inputLoop()

    drawUI()


    while true do

        local button,
            x,
            y =
            os.pullEvent(
                "mouse_click"
            )


        if button == 1 then

            local clicked = false


            -- =================================================
            -- BUTTONS
            -- =================================================

            for _, btn
                in ipairs(buttons)
            do

                if
                    x >= btn.x1
                    and x <= btn.x2
                    and y >= btn.y1
                    and y <= btn.y2
                then

                    clicked = true


                    buttonAction(
                        btn.action
                    )


                    break

                end

            end


            -- =================================================
            -- SONG LIST
            -- =================================================

            if not clicked then

                local playlistHeader =
                    9


                local startIdx =
                    (
                        currentPage - 1
                    )
                    * songsPerPage
                    + 1


                local firstSongY =
                    playlistHeader + 1


                local index =
                    startIdx
                    + (
                        y
                        - firstSongY
                    )


                if index >= 1
                    and index <= #songs
                    and y >= firstSongY
                    and y <= height - bottomRows
                then

                    currentSong =
                        songs[index]


                    stopFlag = true

                    playbackToken =
                        playbackToken + 1

                    stopSpeakers()

                    playing = true


                    saveSettings()

                    drawUI()

                end

            end

        end

    end

end


-- ============================================================
-- START
-- ============================================================

drawUI()


parallel.waitForAny(

    playerLoop,

    inputLoop,

    networkListener,

    networkMaintenance

)
