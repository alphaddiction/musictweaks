-- ============================================================
-- MUSIC TWEAKS - CENTRAL
-- ============================================================

local REPO = "alphaddiction/musictweaks"
local PROTOCOL = "musictweaks"

local modem = peripheral.find("modem", function(name, wrapped)
    return wrapped.isWireless()
end)

if not modem then
    error("No se encontro un modem inalambrico.")
end

rednet.open(peripheral.getName(modem))

-- ============================================================
-- TERMINAL
-- ============================================================

local WIDTH, HEIGHT = term.getSize()

term.setBackgroundColor(colors.black)
term.setTextColor(colors.white)
term.clear()

-- ============================================================
-- CANCIONES
-- ============================================================

local function loadSongs()

    local url =
        "https://raw.githubusercontent.com/"
        .. REPO
        .. "/refs/heads/main/index.txt"

    local response = http.get(url)

    if not response then
        error("No se pudo descargar index.txt")
    end

    local data = response.readAll()
    response.close()

    local names = textutils.unserialize(data)

    if not names then
        error("index.txt no tiene un formato valido")
    end

    local result = {}

    for _, name in ipairs(names) do
        table.insert(result, {
            name = name
        })
    end

    return result
end

local songs = loadSongs()

if #songs == 0 then
    error("No hay canciones.")
end

-- ============================================================
-- AJUSTES
-- ============================================================

local currentSong = nil

local savedSong =
    settings.get("currentSong")

if savedSong then
    for _, song in ipairs(songs) do
        if song.name == savedSong then
            currentSong = song
            break
        end
    end
end

local playing =
    settings.get("playing", false)

local shuffle =
    settings.get("shuffle", true)

local loopMode =
    settings.get("loopMode", 0)

local volume =
    settings.get("volume", 0.35)

local currentPage =
    settings.get("currentPage", 1)

-- ============================================================
-- ZONAS
-- ============================================================

local zones = {}

-- ============================================================
-- UI
-- ============================================================

local buttons = {}
local uiDirty = true

local TOP_ROWS = 8
local BOTTOM_ROWS = 6

local songsPerPage =
    math.max(
        1,
        HEIGHT - TOP_ROWS - BOTTOM_ROWS
    )

local function totalPages()
    return math.max(
        1,
        math.ceil(
            #songs / songsPerPage
        )
    )
end

currentPage =
    math.max(
        1,
        math.min(
            currentPage,
            totalPages()
        )
    )

local function refreshUI()
    uiDirty = true
end

-- ============================================================
-- GUARDAR
-- ============================================================

local function saveSettings()

    settings.set(
        "playing",
        playing
    )

    settings.set(
        "shuffle",
        shuffle
    )

    settings.set(
        "loopMode",
        loopMode
    )

    settings.set(
        "volume",
        volume
    )

    settings.set(
        "currentPage",
        currentPage
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
-- BOTONES
-- ============================================================

local function addButton(
    x,
    y,
    text,
    action,
    bg,
    fg
)

    bg = bg or colors.gray
    fg = fg or colors.white

    local value =
        "[ "
        .. text
        .. " ]"

    term.setCursorPos(x, y)
    term.setBackgroundColor(bg)
    term.setTextColor(fg)
    term.write(value)

    table.insert(
        buttons,
        {
            x1 = x,
            x2 = x + #value - 1,
            y1 = y,
            y2 = y,
            action = action
        }
    )
end

-- ============================================================
-- INTERFAZ
-- ============================================================

local function drawUI()

    buttons = {}

    term.setBackgroundColor(colors.black)
    term.setTextColor(colors.white)
    term.clear()

    -- HEADER

    term.setBackgroundColor(colors.blue)

    term.setCursorPos(1, 1)

    term.write(
        string.rep(" ", WIDTH)
    )

    local title =
        " MUSIC TWEAKS - CENTRAL "

    term.setCursorPos(
        math.max(
            1,
            math.floor(
                (WIDTH - #title) / 2
            )
        ),
        1
    )

    term.setTextColor(colors.white)
    term.write(title)

    term.setBackgroundColor(colors.black)

    -- NOW PLAYING

    term.setCursorPos(2, 2)
    term.setTextColor(colors.cyan)
    term.write("NOW PLAYING")

    term.setCursorPos(2, 3)
    term.setTextColor(colors.white)

    local songName =
        currentSong
        and currentSong.name
        or "(ninguna)"

    if #songName > WIDTH - 2 then
        songName =
            songName:sub(
                1,
                WIDTH - 5
            )
            .. "..."
    end

    term.write(songName)

    term.setCursorPos(2, 4)

    if playing then
        term.setTextColor(colors.lime)
        term.write("● PLAYING")
    else
        term.setTextColor(colors.lightGray)
        term.write("● STOPPED")
    end

    -- ZONAS

    term.setCursorPos(2, 5)
    term.setTextColor(colors.cyan)
    term.write("ZONES")

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

            term.setCursorPos(
                2,
                zoneY
            )

            term.setTextColor(colors.lime)
            term.write("● ")

            term.setTextColor(colors.white)

            local text =
                (
                    item.zone.name
                    or "ZONE"
                )
                .. "  ID:"
                .. item.id
                .. "  SPK:"
                .. (
                    item.zone.speakers
                    or 0
                )

            if #text > WIDTH - 3 then
                text =
                    text:sub(
                        1,
                        WIDTH - 3
                    )
            end

            term.write(text)

            zoneY =
                zoneY + 1
        end
    end

    -- PLAYLIST

    local playlistY =
        TOP_ROWS + 1

    term.setCursorPos(
        2,
        playlistY
    )

    term.setTextColor(colors.cyan)
    term.write("PLAYLIST")

    local firstSongY =
        playlistY + 1

    local startIndex =
        (
            currentPage - 1
        )
        * songsPerPage
        + 1

    local endIndex =
        math.min(
            startIndex
            + songsPerPage
            - 1,
            #songs
        )

    local y =
        firstSongY

    for i = startIndex,
        endIndex
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

            term.write("> ")

        else

            term.setTextColor(
                colors.lightGray
            )

            term.write("  ")

        end

        term.setTextColor(
            colors.white
        )

        local text =
            string.format(
                "%02d",
                i
            )
            .. " "
            .. songs[i].name

        if #text > WIDTH - 4 then
            text =
                text:sub(
                    1,
                    WIDTH - 7
                )
                .. "..."
        end

        term.write(text)

        y =
            y + 1
    end

    -- CONTROLES

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

    -- MODOS

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

    -- VOLUMEN

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

    -- PAGINA

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

    term.setTextColor(colors.cyan)
    term.write(page)

    term.setBackgroundColor(colors.black)
end

-- ============================================================
-- ENVIAR A RECEPTORES
-- ============================================================

local function sendAll(message)

    for id, _ in pairs(zones) do

        rednet.send(
            id,
            message,
            PROTOCOL
        )

    end
end

-- ============================================================
-- SIGUIENTE CANCION
-- ============================================================

local function nextSong()

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
        return songs[index + 1]
    end

    if loopMode == 1 then
        return songs[1]
    end

    return nil
end

-- ============================================================
-- ACCIONES
-- ============================================================

local function action(
    name
)

    if name == "play" then

        if not currentSong then
            return
        end

        playing =
            not playing

        sendAll(
            {
                type =
                    playing
                    and "PLAY"
                    or "PAUSE",

                song =
                    currentSong.name,

                volume =
                    volume
            }
        )

    elseif name == "stop" then

        playing = false

        sendAll(
            {
                type = "STOP"
            }
        )

    elseif name == "next" then

        local song =
            nextSong()

        if song then

            currentSong =
                song

            playing =
                true

            sendAll(
                {
                    type = "PLAY",

                    song =
                        currentSong.name,

                    volume =
                        volume,

                    restart = true
                }
            )

        end

    elseif name == "shuffle" then

        shuffle =
            not shuffle

    elseif name == "loop" then

        loopMode =
            (
                loopMode + 1
            ) % 3

    elseif name == "volumeDown" then

        volume =
            math.max(
                0,
                volume - 0.05
            )

        sendAll(
            {
                type =
                    "VOLUME",

                volume =
                    volume
            }
        )

    elseif name == "volumeUp" then

        volume =
            math.min(
                1,
                volume + 0.05
            )

        sendAll(
            {
                type =
                    "VOLUME",

                volume =
                    volume
            }
        )
    end

    saveSettings()
    refreshUI()
end

-- ============================================================
-- MOUSE
-- ============================================================

local function inputLoop()

    while true do

        local _, button, x, y =
            os.pullEvent(
                "mouse_click"
            )

        if button == 1 then

            local clicked = false

            for _, btn in ipairs(buttons) do

                if
                    x >= btn.x1
                    and x <= btn.x2
                    and y >= btn.y1
                    and y <= btn.y2
                then

                    clicked = true

                    action(
                        btn.action
                    )

                    break
                end
            end

            -- SONG CLICK

            if not clicked then

                local playlistY =
                    TOP_ROWS + 1

                local firstSongY =
                    playlistY + 1

                if
                    y >= firstSongY
                    and y <=
                        HEIGHT - BOTTOM_ROWS
                then

                    local start =
                        (
                            currentPage - 1
                        )
                        * songsPerPage
                        + 1

                    local index =
                        start
                        + (
                            y
                            - firstSongY
                        )

                    if
                        index >= 1
                        and index <= #songs
                    then

                        currentSong =
                            songs[index]

                        playing =
                            true

                        sendAll(
                            {
                                type = "PLAY",

                                song =
                                    currentSong.name,

                                volume =
                                    volume,

                                restart = true
                            }
                        )

                        saveSettings()
                        refreshUI()
                    end
                end
            end
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
            and type(message)
            == "table"
        then

            if
                message.type
                == "HELLO"
                or message.type
                == "RECEIVER_HELLO"
            then

                zones[sender] =
                    {
                        name =
                            message.zone
                            or (
                                "ZONE "
                                .. sender
                            ),

                        speakers =
                            message.speakers
                            or 0,

                        lastSeen =
                            os.clock()
                    }

                rednet.send(
                    sender,

                    {
                        type =
                            "CENTRAL_HELLO"
                    },

                    PROTOCOL
                )

                refreshUI()

            elseif
                message.type
                == "PONG"
            then

                if not zones[sender] then

                    zones[sender] =
                        {
                            name =
                                message.zone
                                or (
                                    "ZONE "
                                    .. sender
                                ),

                            speakers =
                                message.speakers
                                or 0,

                            lastSeen =
                                os.clock()
                        }

                else

                    zones[sender].lastSeen =
                        os.clock()
                end

                refreshUI()
            end
        end
    end
end

-- ============================================================
-- NETWORK WATCHDOG
-- ============================================================

local function watchdog()

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

            if
                now
                - zone.lastSeen
                > 15
            then

                zones[id] = nil
                refreshUI()
            end
        end

        os.sleep(5)
    end
end

-- ============================================================
-- UI LOOP
-- ============================================================

local function uiLoop()

    while true do

        if uiDirty then

            uiDirty = false

            drawUI()
        end

        os.sleep(0.05)
    end
end

-- ============================================================
-- AUTO REFRESH GITHUB
-- ============================================================

local function songRefreshLoop()

    while true do

        os.sleep(60)

        local ok, newSongs =
            pcall(
                loadSongs
            )

        if ok
            and #newSongs > 0
        then

            songs =
                newSongs

            if currentSong then

                local currentName =
                    currentSong.name

                currentSong =
                    nil

                for _, song
                    in ipairs(songs)
                do

                    if song.name ==
                        currentName
                    then

                        currentSong =
                            song

                        break
                    end
                end
            end

            currentPage =
                math.min(
                    currentPage,
                    totalPages()
                )

            refreshUI()
        end
    end
end

-- ============================================================
-- START
-- ============================================================

drawUI()

parallel.waitForAny(

    inputLoop,
    networkLoop,
    watchdog,
    uiLoop,
    songRefreshLoop

)
