-- ============================================================
-- MUSIC TWEAKS
-- CENTRAL + NETWORK AUDIO
-- ============================================================

local REPO = "alphaddiction/musictweaks"

local PROTOCOL = "musictweaks"

-- Tamaño de cada paquete DFPWM enviado por red.
-- 4096 es deliberadamente pequeño para mejorar compatibilidad
-- con modems y evitar paquetes demasiado grandes.
local AUDIO_CHUNK = 4096


-- ============================================================
-- TERMINAL
-- ============================================================

term.setBackgroundColor(colors.black)
term.setTextColor(colors.white)
term.clear()

local WIDTH, HEIGHT = term.getSize()


-- ============================================================
-- WIRELESS MODEM
-- ============================================================

local modem = peripheral.find(
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

local modemName =
    peripheral.getName(modem)

rednet.open(modemName)


-- ============================================================
-- DFPWM
-- ============================================================

local dfpwm =
    require("cc.audio.dfpwm")


-- ============================================================
-- SONG INDEX
-- ============================================================

local indexURL =
    "https://raw.githubusercontent.com/"
    .. REPO
    .. "/refs/heads/main/index.txt"


local response =
    http.get(indexURL)


if not response then
    error(
        "No se pudo descargar index.txt"
    )
end


local indexData =
    response.readAll()

response.close()


local songNames =
    textutils.unserialize(indexData)


if not songNames then
    error(
        "index.txt no tiene un formato valido"
    )
end


local songs = {}


for _, name in ipairs(songNames) do

    table.insert(
        songs,
        {
            name = name,

            fn = function()

                local encoded =
                    name:gsub(
                        " ",
                        "%%20"
                    )

                local url =
                    "https://raw.githubusercontent.com/"
                    .. REPO
                    .. "/refs/heads/main/"
                    .. encoded
                    .. ".dfpwm"


                local r =
                    http.get(url)


                if not r then
                    error(
                        "No se pudo descargar "
                        .. name
                        .. ".dfpwm"
                    )
                end


                local data =
                    r.readAll()

                r.close()

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

local currentSong = nil

local savedName =
    settings.get(
        "currentSong",
        nil
    )


if savedName then

    for _, song in ipairs(songs) do

        if song.name == savedName then
            currentSong = song
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
-- PLAYBACK CONTROL
-- ============================================================

local playbackToken = 0

local stopRequested = false


-- ============================================================
-- NETWORK ZONES
-- ============================================================

local zones = {}


-- ============================================================
-- UI
-- ============================================================

local buttons = {}

local uiDirty = true


local function markUI()
    uiDirty = true
end


-- ============================================================
-- PAGES
-- ============================================================

local TOP_ROWS = 8
local BOTTOM_ROWS = 6


local songsPerPage =
    HEIGHT
    - TOP_ROWS
    - BOTTOM_ROWS


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
    currentPage = totalPages()
end


-- ============================================================
-- SAVE
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
-- BUTTON
-- ============================================================

local function addButton(
    x,
    y,
    text,
    action,
    background,
    foreground
)

    background =
        background
        or colors.gray

    foreground =
        foreground
        or colors.white


    local output =
        "[ "
        .. text
        .. " ]"


    term.setCursorPos(
        x,
        y
    )

    term.setBackgroundColor(
        background
    )

    term.setTextColor(
        foreground
    )

    term.write(
        output
    )


    table.insert(
        buttons,
        {
            x1 = x,
            x2 = x + #output - 1,
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
            WIDTH
        )
    )


    local title =
        " MUSIC TWEAKS - CENTRAL "


    local titleX =
        math.max(
            1,
            math.floor(
                (
                    WIDTH
                    - #title
                ) / 2
            )
        )


    term.setCursorPos(
        titleX,
        1
    )

    term.setTextColor(
        colors.white
    )

    term.write(
        title
    )


    -- ========================================================
    -- NOW PLAYING
    -- ========================================================

    term.setBackgroundColor(
        colors.black
    )

    term.setCursorPos(
        2,
        2
    )

    term.setTextColor(
        colors.cyan
    )

    term.write(
        "NOW PLAYING"
    )


    term.setCursorPos(
        2,
        3
    )

    term.setTextColor(
        colors.white
    )


    local titleText =
        currentSong
        and currentSong.name
        or "(none)"


    if #titleText >
        WIDTH - 2
    then

        titleText =
            titleText:sub(
                1,
                WIDTH - 5
            )
            .. "..."

    end


    term.write(
        titleText
    )


    term.setCursorPos(
        2,
        4
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
        5
    )

    term.setTextColor(
        colors.cyan
    )

    term.write(
        "ZONES"
    )


    local zoneList = {}


    for id, zone in pairs(zones) do

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


    local zoneY = 6


    for _, item in ipairs(zoneList) do

        if zoneY <= TOP_ROWS then

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
                or "ZONE"


            local line =
                zoneName
                .. "  ID:"
                .. item.id
                .. "  SPK:"
                .. (
                    zone.speakers
                    or 0
                )


            if #line >
                WIDTH - 3
            then

                line =
                    line:sub(
                        1,
                        WIDTH - 3
                    )

            end


            term.write(
                line
            )


            zoneY =
                zoneY + 1

        end

    end


    -- ========================================================
    -- PLAYLIST
    -- ========================================================

    local playlistY =
        TOP_ROWS + 1


    term.setCursorPos(
        2,
        playlistY
    )

    term.setTextColor(
        colors.cyan
    )

    term.write(
        "PLAYLIST"
    )


    local start =
        (
            currentPage - 1
        )
        * songsPerPage
        + 1


    local firstSongY =
        playlistY + 1


    local lastSong =
        math.min(
            start
            + songsPerPage
            - 1,
            #songs
        )


    local y =
        firstSongY


    for i = start,
        lastSong
    do

        if y >
            HEIGHT - BOTTOM_ROWS
        then
            break
        end


        term.setCursorPos(
            2,
            y
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
            WIDTH - 4
        then

            songText =
                songText:sub(
                    1,
                    WIDTH - 7
                )
                .. "..."

        end


        term.write(
            songText
        )


        y =
            y + 1

    end


    -- ========================================================
    -- CONTROLS
    -- ========================================================

    local controlY =
        HEIGHT - 5


    addButton(
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


    addButton(
        15,
        controlY,
        "STOP",
        "stop",
        colors.red,
        colors.white
    )


    addButton(
        26,
        controlY,
        "NEXT >>",
        "next",
        colors.blue,
        colors.white
    )


    -- ========================================================
    -- MODES
    -- ========================================================

    local modeY =
        HEIGHT - 3


    addButton(
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
        loopText = "LOOP OFF"
    elseif loopMode == 1 then
        loopText = "LOOP ALL"
    else
        loopText = "LOOP ONE"
    end


    addButton(
        20,
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
        HEIGHT - 1
    )

    term.setTextColor(
        colors.lightGray
    )

    term.write(
        "VOL "
        .. math.floor(
            volume * 100
        )
        .. "%"
    )


    addButton(
        10,
        HEIGHT - 1,
        "-",
        "volumeDown"
    )


    addButton(
        16,
        HEIGHT - 1,
        "+",
        "volumeUp"
    )


    local page =
        "PAGE "
        .. currentPage
        .. "/"
        .. totalPages()


    term.setCursorPos(
        math.max(
            1,
            WIDTH - #page
        ),
        HEIGHT - 1
    )

    term.setTextColor(
        colors.cyan
    )

    term.write(
        page
    )


    term.setBackgroundColor(
        colors.black
    )

end


-- ============================================================
-- NETWORK - REGISTER RECEIVER
-- ============================================================

local function registerZone(
    id,
    message
)

    zones[id] = {
        name =
            message.zone
            or ("ZONE " .. id),

        speakers =
            message.speakers
            or 0,

        lastSeen =
            os.clock()
    }


    -- NO drawUI() HERE.
    --
    -- This is what removes the screen shaking.
    --
    markUI()

end


-- ============================================================
-- NETWORK LISTENER
-- ============================================================

local function networkListener()

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

            if message.type
                == "HELLO"
                or message.type
                == "RECEIVER_HELLO"
            then

                registerZone(
                    sender,
                    message
                )


                rednet.send(
                    sender,

                    {
                        type =
                            "CENTRAL_HELLO"
                    },

                    PROTOCOL
                )


            elseif message.type
                == "PONG"
            then

                if zones[sender] then

                    zones[sender].lastSeen =
                        os.clock()

                else

                    registerZone(
                        sender,
                        message
                    )

                end

            elseif message.type
                == "AUDIO_ACK"
            then

                -- Audio ACKs are handled
                -- by the streaming system.

            end

        end

    end

end


-- ============================================================
-- NETWORK MAINTENANCE
-- ============================================================

local function networkMaintenance()

    while true do

        rednet.broadcast(
            {
                type =
                    "CENTRAL_HELLO"
            },
            PROTOCOL
        )


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

                PROTOCOL
            )


            if now -
                zone.lastSeen
                > 15
            then

                zones[id] =
                    nil

                markUI()

            end

        end


        os.sleep(5)

    end

end


-- ============================================================
-- GET ACTIVE ZONES
-- ============================================================

local function getZoneIDs()

    local ids = {}


    for id, _ in pairs(zones) do

        table.insert(
            ids,
            id
        )

    end


    table.sort(ids)


    return ids

end


-- ============================================================
-- SEND CONTROL
-- ============================================================

local function sendToAll(
    message
)

    for id, _ in pairs(zones) do

        rednet.send(
            id,
            message,
            PROTOCOL
        )

    end

end


-- ============================================================
-- STREAM AUDIO
-- ============================================================

local function streamSong(
    song,
    token
)

    local ok,
        data =
        pcall(
            song.fn
        )


    if not ok then

        playing = false

        markUI()

        return

    end


    local length =
        #data


    local sequence = 0


    for position = 1,
        length,
        AUDIO_CHUNK
    do

        -- ====================================================
        -- CANCEL CHECK
        -- ====================================================

        if token
            ~= playbackToken
            or not playing
        then

            return

        end


        local chunk =
            data:sub(
                position,
                math.min(
                    position
                    + AUDIO_CHUNK
                    - 1,
                    length
                )
            )


        sequence =
            sequence + 1


        local ids =
            getZoneIDs()


        -- ====================================================
        -- SEND CHUNK
        -- ====================================================

        for _, id in ipairs(ids) do

            rednet.send(

                id,

                {
                    type =
                        "AUDIO",

                    song =
                        song.name,

                    sequence =
                        sequence,

                    data =
                        chunk,

                    volume =
                        volume,

                    last =
                        (
                            position
                            + AUDIO_CHUNK
                            > length
                        )
                },

                PROTOCOL

            )

        end


        -- ====================================================
        -- WAIT A LITTLE
        --
        -- We deliberately don't wait for every ACK here.
        -- This allows the central to keep sending audio while
        -- the receiver buffers it.
        -- ====================================================

        os.sleep(
            0.015
        )

    end


    -- ========================================================
    -- END OF SONG
    -- ========================================================

    for _, id in ipairs(
        getZoneIDs()
    ) do

        rednet.send(

            id,

            {
                type =
                    "AUDIO_END",

                song =
                    song.name,

                sequence =
                    sequence

            },

            PROTOCOL

        )

    end

end


-- ============================================================
-- CHOOSE NEXT SONG
-- ============================================================

local function chooseNextSong()

    if #songs == 0 then
        return nil
    end


    local index = 1


    if currentSong then

        for i, song in ipairs(songs) do

            if song ==
                currentSong
            then

                index = i

                break

            end

        end

    end


    if shuffle then

        if #songs == 1 then
            return songs[1]
        end


        local newIndex


        repeat

            newIndex =
                math.random(
                    #songs
                )

        until
            songs[newIndex]
            ~= currentSong


        return songs[newIndex]

    end


    if index < #songs then

        return songs[
            index + 1
        ]

    end


    if loopMode == 1 then

        return songs[1]

    end


    return nil

end


-- ============================================================
-- PLAYBACK LOOP
-- ============================================================

local function playbackLoop()

    while true do

        if currentSong
            and playing
        then

            local song =
                currentSong

            local token =
                playbackToken


            markUI()


            streamSong(
                song,
                token
            )


            if token
                ~= playbackToken
            then

                -- Song was changed manually.

            elseif not playing then

                -- Paused/stopped.

            else

                -- =================================================
                -- SONG FINISHED
                -- =================================================

                if loopMode == 2 then

                    -- Repeat current song.


                else

                    local nextSong =
                        chooseNextSong()


                    if nextSong then

                        currentSong =
                            nextSong

                    else

                        currentSong =
                            nil

                        playing =
                            false

                    end

                end


                saveSettings()

                markUI()

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

            playbackToken =
                playbackToken + 1


            sendToAll(
                {
                    type =
                        "PAUSE"
                }
            )

        else

            playing = true

            playbackToken =
                playbackToken + 1


            sendToAll(
                {
                    type =
                        "PLAY",

                    song =
                        currentSong.name,

                    volume =
                        volume
                }
            )

        end


    elseif action == "stop" then

        playing = false

        playbackToken =
            playbackToken + 1


        sendToAll(
            {
                type =
                    "STOP"
            }
        )


    elseif action == "next" then

        local nextSong =
            chooseNextSong()


        if nextSong then

            currentSong =
                nextSong

            playing =
                true

            playbackToken =
                playbackToken + 1


            sendToAll(
                {
                    type =
                        "STOP"
                }
            )

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


        sendToAll(
            {
                type =
                    "VOLUME",

                volume =
                    volume
            }
        )


    elseif action == "volumeUp" then

        volume =
            math.min(
                1,
                volume + 0.05
            )


        sendToAll(
            {
                type =
                    "VOLUME",

                volume =
                    volume
            }
        )

    end


    saveSettings()

    markUI()

end


-- ============================================================
-- MOUSE INPUT
-- ============================================================

local function inputLoop()

    while true do

        local event,
            button,
            x,
            y =
            os.pullEvent(
                "mouse_click"
            )


        if button == 1 then

            local clicked =
                false


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

                    clicked =
                        true


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

                local playlistY =
                    TOP_ROWS + 1


                local firstSongY =
                    playlistY + 1


                local start =
                    (
                        currentPage - 1
                    )
                    * songsPerPage
                    + 1


                if y >= firstSongY
                    and y <=
                        HEIGHT - BOTTOM_ROWS
                then

                    local index =
                        start
                        + (
                            y
                            - firstSongY
                        )


                    if index >= 1
                        and index <= #songs
                    then

                        currentSong =
                            songs[index]


                        playing =
                            true

                        playbackToken =
                            playbackToken + 1


                        sendToAll(
                            {
                                type =
                                    "STOP"
                            }
                        )


                        saveSettings()

                        markUI()

                    end

                end

            end

        end

    end

end


-- ============================================================
-- UI LOOP
--
-- Redraw only when needed.
-- This eliminates the screen shaking caused by network events.
-- ============================================================

local function uiLoop()

    while true do

        if uiDirty then

            uiDirty =
                false

            drawUI()

        end


        os.sleep(
            0.05
        )

    end

end


-- ============================================================
-- START
-- ============================================================

drawUI()


parallel.waitForAny(

    playbackLoop,

    inputLoop,

    networkListener,

    networkMaintenance,

    uiLoop

)
