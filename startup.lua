-- ============================================================
-- MUSIC TWEAKS V2
-- CC:Tweaked - Advanced Computer Music Player
-- ============================================================

local REPO = "alphaddiction/musictweaks"

local INDEX_URL =
    "https://raw.githubusercontent.com/"
    .. REPO
    .. "/refs/heads/main/index.txt"


-- ============================================================
-- TERMINAL
-- ============================================================

local screen = term.native()

term.redirect(screen)

local W, H = term.getSize()

term.setBackgroundColor(colors.black)
term.setTextColor(colors.white)
term.clear()
term.setCursorPos(1, 1)


-- ============================================================
-- COLORES
-- ============================================================

local BG        = colors.black
local PANEL     = colors.gray
local PANEL2    = colors.lightGray

local TEXT      = colors.white
local DIM       = colors.lightGray

local ACCENT    = colors.cyan
local ACTIVE    = colors.blue

local GREEN     = colors.lime
local RED       = colors.red

local YELLOW    = colors.yellow
local PURPLE    = colors.purple


-- ============================================================
-- SPEAKERS
-- ============================================================

local speakers = {
    peripheral.find("speaker")
}

if #speakers == 0 then

    term.clear()
    term.setCursorPos(2, 2)

    term.setTextColor(RED)

    print("MUSIC TWEAKS")
    print("")
    print("ERROR: No speaker found.")
    print("")
    print("Connect a speaker to the computer.")

    error("No speaker attached")

end


-- ============================================================
-- DFPWM
-- ============================================================

local dfpwm = require("cc.audio.dfpwm")


-- ============================================================
-- DOWNLOAD INDEX
-- ============================================================

local response = http.get(INDEX_URL)

if not response then

    term.clear()
    term.setCursorPos(2, 2)

    term.setTextColor(RED)

    print("MUSIC TWEAKS")
    print("")
    print("ERROR: Could not download index.txt.")
    print("")
    print("Check that HTTP is enabled.")

    error("Could not download index.txt")

end


local indexData = response.readAll()

response.close()


local songNames =
    textutils.unserialize(indexData)


if not songNames then

    error("Invalid index.txt")

end


-- ============================================================
-- SONG LIST
-- ============================================================

local songs = {}


for _, name in ipairs(songNames) do

    table.insert(
        songs,
        {
            name = name,

            load = function()

                local encodedName =
                    name:gsub(
                        " ",
                        "%%20"
                    )

                local url =
                    "https://raw.githubusercontent.com/"
                    .. REPO
                    .. "/refs/heads/main/"
                    .. encodedName
                    .. ".dfpwm"


                local r = http.get(url)


                if not r then

                    error(
                        "Could not download "
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

    error("No songs found in index.txt")

end


-- ============================================================
-- STATE
-- ============================================================

local currentSong = nil

local playing = false

local shuffle = false

local loopMode = 0

-- 0 = OFF
-- 1 = ALL
-- 2 = ONE

local volume = 0.35

local currentPage = 1

local status = "READY"

local stopPlayback = false

local playbackToken = 0


-- ============================================================
-- SCREEN LAYOUT
-- ============================================================

local HEADER = 5

local FOOTER = 7

local SONG_FIRST = HEADER + 1

local SONG_LAST =
    H - FOOTER


local SONGS_PER_PAGE =
    math.max(
        1,
        SONG_LAST - SONG_FIRST + 1
    )


-- ============================================================
-- BUTTONS
-- ============================================================

local buttons = {}


-- ============================================================
-- PAGE COUNT
-- ============================================================

local function pageCount()

    return math.max(
        1,
        math.ceil(
            #songs /
            SONGS_PER_PAGE
        )
    )

end


-- ============================================================
-- SAFE SPEAKER STOP
-- ============================================================

local function stopSpeakers()

    for _, speaker in ipairs(speakers) do

        pcall(
            function()
                speaker.stop()
            end
        )

    end

end


-- ============================================================
-- BUTTON DRAW
-- ============================================================

local function addButton(
    x1,
    x2,
    y,
    text,
    action,
    background,
    foreground
)

    if x1 < 1 then
        x1 = 1
    end

    if x2 > W then
        x2 = W
    end


    table.insert(
        buttons,
        {
            x1 = x1,
            x2 = x2,
            y1 = y,
            y2 = y,

            action = action
        }
    )


    term.setCursorPos(
        x1,
        y
    )


    term.setBackgroundColor(
        background or PANEL
    )

    term.setTextColor(
        foreground or TEXT
    )


    local available =
        x2 - x1 + 1


    local output =
        text


    if #output > available then

        output =
            output:sub(
                1,
                available
            )

    end


    if #output < available then

        output =
            output
            .. string.rep(
                " ",
                available - #output
            )

    end


    term.write(
        output
    )

end


-- ============================================================
-- CENTERED TEXT
-- ============================================================

local function centerText(
    text,
    y,
    color
)

    local x =
        math.floor(
            (W - #text) / 2
        ) + 1


    if x < 1 then
        x = 1
    end


    term.setCursorPos(
        x,
        y
    )

    term.setTextColor(
        color or TEXT
    )

    term.write(
        text
    )

end


-- ============================================================
-- DRAW UI
-- ============================================================

local function drawUI()

    term.redirect(screen)

    buttons = {}


    term.setBackgroundColor(
        BG
    )

    term.setTextColor(
        TEXT
    )

    term.clear()


    -- ========================================================
    -- HEADER
    -- ========================================================

    term.setBackgroundColor(
        ACTIVE
    )

    term.setTextColor(
        TEXT
    )

    term.setCursorPos(
        1,
        1
    )

    term.write(
        string.rep(
            " ",
            W
        )
    )


    centerText(
        "MUSIC TWEAKS",
        1,
        TEXT
    )


    term.setBackgroundColor(
        BG
    )


    -- ========================================================
    -- NOW PLAYING
    -- ========================================================

    term.setCursorPos(
        2,
        2
    )

    term.setTextColor(
        DIM
    )

    term.write(
        "NOW PLAYING"
    )


    local songTitle =
        currentSong
        and currentSong.name
        or "Nothing"


    term.setCursorPos(
        2,
        3
    )

    term.setTextColor(
        ACCENT
    )


    local maxTitle =
        W - 2


    if #songTitle > maxTitle then

        songTitle =
            songTitle:sub(
                1,
                maxTitle - 3
            )
            .. "..."

    end


    term.write(
        songTitle
    )


    -- ========================================================
    -- STATUS
    -- ========================================================

    term.setCursorPos(
        2,
        4
    )

    if playing then

        term.setTextColor(
            GREEN
        )

        term.write(
            "● PLAYING"
        )

    else

        term.setTextColor(
            DIM
        )

        term.write(
            "● "
            .. status
        )

    end


    -- ========================================================
    -- PLAYLIST HEADER
    -- ========================================================

    term.setCursorPos(
        1,
        SONG_FIRST
    )

    term.setBackgroundColor(
        PANEL
    )

    term.setTextColor(
        TEXT
    )

    term.write(
        " PLAYLIST"
        .. string.rep(
            " ",
            math.max(
                0,
                W - 9
            )
        )
    )


    -- ========================================================
    -- SONG LIST
    -- ========================================================

    local listStart =
        SONG_FIRST + 1


    local listEnd =
        SONG_LAST


    local startIndex =
        (
            currentPage - 1
        )
        * SONGS_PER_PAGE
        + 1


    for y = listStart,
        listEnd
    do

        local index =
            startIndex
            + (
                y - listStart
            )


        term.setCursorPos(
            1,
            y
        )


        if index <= #songs then

            local song =
                songs[index]


            local selected =
                song ==
                currentSong


            if selected then

                term.setBackgroundColor(
                    ACTIVE
                )

                term.setTextColor(
                    TEXT
                )

            else

                term.setBackgroundColor(
                    BG
                )

                term.setTextColor(
                    TEXT
                )

            end


            local prefix

            if selected then

                prefix = "> "

            else

                prefix = "  "

            end


            local number =
                string.format(
                    "%02d",
                    index
                )


            local text =
                prefix
                .. number
                .. " "
                .. song.name


            if #text > W then

                text =
                    text:sub(
                        1,
                        W - 3
                    )
                    .. "..."

            end


            if #text < W then

                text =
                    text
                    .. string.rep(
                        " ",
                        W - #text
                    )

            end


            term.write(
                text
            )


        else

            term.setBackgroundColor(
                BG
            )

            term.setTextColor(
                TEXT
            )

            term.write(
                string.rep(
                    " ",
                    W
                )
            )

        end

    end


    -- ========================================================
    -- FOOTER CONTROLS
    -- ========================================================

    local yPlay =
        H - 6

    local yMode =
        H - 5

    local yVolume =
        H - 4

    local yPages =
        H - 2


    -- ========================================================
    -- PLAY / STOP / NEXT
    -- ========================================================

    local third =
        math.floor(
            W / 3
        )


    addButton(
        1,
        third,
        yPlay,

        playing
        and "[ PAUSE ]"
        or "[ PLAY ]",

        "play",

        playing
        and GREEN
        or ACTIVE,

        colors.black
    )


    addButton(
        third + 1,
        third * 2,
        yPlay,

        "[ STOP ]",

        "stop",

        RED,

        colors.white
    )


    addButton(
        third * 2 + 1,
        W,
        yPlay,

        "[ NEXT >> ]",

        "next",

        ACTIVE,

        colors.white
    )


    -- ========================================================
    -- SHUFFLE / LOOP
    -- ========================================================

    local half =
        math.floor(
            W / 2
        )


    addButton(
        1,
        half,
        yMode,

        shuffle
        and "[ SHUFFLE: ON ]"
        or "[ SHUFFLE: OFF ]",

        "shuffle",

        shuffle
        and GREEN
        or PANEL,

        shuffle
        and colors.black
        or TEXT
    )


    local loopText

    if loopMode == 0 then

        loopText =
            "[ LOOP: OFF ]"

    elseif loopMode == 1 then

        loopText =
            "[ LOOP: ALL ]"

    else

        loopText =
            "[ LOOP: ONE ]"

    end


    addButton(
        half + 1,
        W,
        yMode,

        loopText,

        "loop",

        loopMode ~= 0
        and PURPLE
        or PANEL,

        colors.white
    )


    -- ========================================================
    -- VOLUME
    -- ========================================================

    local volumePercent =
        math.floor(
            volume * 100
        )


    local barSize =
        math.max(
            5,
            W - 18
        )


    local filled =
        math.floor(
            barSize
            * volume
        )


    local empty =
        barSize
        - filled


    local volumeBar =
        string.rep(
            "#",
            filled
        )
        ..
        string.rep(
            "-",
            empty
        )


    addButton(
        1,
        math.floor(
            W / 5
        ),
        yVolume,

        "[ VOL- ]",

        "volumeDown",

        PANEL,

        TEXT
    )


    term.setCursorPos(
        math.floor(
            W / 5
        ) + 1,
        yVolume
    )

    term.setBackgroundColor(
        BG
    )

    term.setTextColor(
        ACCENT
    )


    local middleStart =
        math.floor(
            W / 5
        ) + 1


    local middleEnd =
        math.floor(
            W * 4 / 5
        )


    local volumeText =
        "VOL "
        .. volumePercent
        .. "% "
        .. volumeBar


    if #volumeText >
        (
            middleEnd
            - middleStart
            + 1
        )
    then

        volumeText =
            volumeText:sub(
                1,
                middleEnd
                - middleStart
                + 1
            )

    end


    term.write(
        volumeText
    )


    addButton(
        math.floor(
            W * 4 / 5
        ) + 1,
        W,
        yVolume,

        "[ VOL+ ]",

        "volumeUp",

        PANEL,

        TEXT
    )


    -- ========================================================
    -- PAGE CONTROLS
    -- ========================================================

    local pages =
        pageCount()


    addButton(
        1,
        math.floor(
            W / 3
        ),
        yPages,

        "[ << PAGE ]",

        "pagePrevious",

        PANEL,

        TEXT
    )


    centerText(
        "PAGE "
        .. currentPage
        .. "/"
        .. pages,

        yPages,

        ACCENT
    )


    addButton(
        math.floor(
            W * 2 / 3
        ) + 1,
        W,
        yPages,

        "[ PAGE >> ]",

        "pageNext",

        PANEL,

        TEXT
    )


    term.setBackgroundColor(
        BG
    )

end


-- ============================================================
-- PLAYBACK
-- ============================================================

local function playSong(song, token)

    if not song then
        return
    end


    status = "LOADING"

    drawUI()


    local ok, data =
        pcall(
            song.load
        )


    if token ~= playbackToken then
        return
    end


    if not ok then

        playing = false

        status = "DOWNLOAD ERROR"

        drawUI()

        return

    end


    status = "PLAYING"

    drawUI()


    local decoder =
        dfpwm.make_decoder()


    local dataLength =
        #data


    for position = 1,
        dataLength,
        16 * 1024
    do

        -- ====================================================
        -- CANCEL CHECK
        -- ====================================================

        if token ~= playbackToken then

            return

        end


        if not playing then

            return

        end


        local chunk =
            data:sub(
                position,
                math.min(
                    position
                    + 16 * 1024
                    - 1,
                    dataLength
                )
            )


        local buffer =
            decoder(
                chunk
            )


        -- ====================================================
        -- SEND TO SPEAKERS
        -- ====================================================

        for _, speaker
            in ipairs(speakers)
        do

            if token ~= playbackToken then
                return
            end


            local sent = false


            while not sent do

                if token ~= playbackToken then
                    return
                end


                if not playing then
                    return
                end


                sent =
                    speaker.playAudio(
                        buffer,
                        volume
                    )


                if not sent then

                    -- IMPORTANT:
                    --
                    -- No hacemos un os.pullEvent
                    -- esperando eternamente a
                    -- speaker_audio_empty.
                    --
                    -- Comprobamos periódicamente
                    -- si se ha solicitado cambio
                    -- de canción.

                    local timer =
                        os.startTimer(
                            0.03
                        )


                    while true do

                        local event,
                            a =
                            os.pullEvent()


                        if token
                            ~= playbackToken
                        then

                            return

                        end


                        if not playing then

                            return

                        end


                        if event ==
                            "speaker_audio_empty"
                        then

                            break

                        end


                        if event ==
                            "timer"
                            and a == timer
                        then

                            break

                        end

                    end

                end

            end

        end

    end

end


-- ============================================================
-- PLAYBACK LOOP
-- ============================================================

local function playbackLoop()

    while true do

        if playing
            and currentSong
        then

            local token =
                playbackToken


            local song =
                currentSong


            playSong(
                song,
                token
            )


            -- =================================================
            -- SONG CANCELLED
            -- =================================================

            if token
                ~= playbackToken
            then

                -- Do nothing.

            elseif not playing then

                -- Paused/stopped.

            else

                -- =================================================
                -- SONG FINISHED
                -- =================================================

                if loopMode == 2 then

                    -- LOOP ONE
                    -- Same song.


                elseif shuffle then

                    -- SHUFFLE

                    if #songs > 1 then

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

                    end


                else

                    -- NORMAL / LOOP ALL

                    local index = 1


                    for i, songItem
                        in ipairs(songs)
                    do

                        if songItem
                            == currentSong
                        then

                            index = i

                            break

                        end

                    end


                    if index < #songs then

                        currentSong =
                            songs[
                                index + 1
                            ]

                    elseif loopMode == 1 then

                        currentSong =
                            songs[1]

                    else

                        currentSong = nil

                        playing = false

                        status = "FINISHED"

                    end

                end


                drawUI()

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

local function buttonAction(action)

    -- ========================================================
    -- PLAY / PAUSE
    -- ========================================================

    if action == "play" then

        if not currentSong then

            status =
                "SELECT A SONG"

        elseif playing then

            playing = false

            playbackToken =
                playbackToken + 1

            stopSpeakers()

            status =
                "PAUSED"

        else

            playing = true

            playbackToken =
                playbackToken + 1

            status =
                "PLAYING"

        end


    -- ========================================================
    -- STOP
    -- ========================================================

    elseif action == "stop" then

        playing = false

        playbackToken =
            playbackToken + 1

        stopSpeakers()

        status =
            "STOPPED"


    -- ========================================================
    -- NEXT
    -- ========================================================

    elseif action == "next" then

        if #songs > 0 then

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

            else

                if index < #songs then

                    currentSong =
                        songs[index + 1]

                elseif loopMode == 1 then

                    currentSong =
                        songs[1]

                else

                    currentSong =
                        songs[1]

                end

            end


            -- ================================================
            -- IMPORTANT FIX
            -- ================================================

            playbackToken =
                playbackToken + 1

            stopSpeakers()

            playing = true

            status =
                "LOADING"

        end


    -- ========================================================
    -- PREVIOUS
    -- ========================================================

    elseif action == "previous" then

        if #songs > 0 then

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


            if index > 1 then

                currentSong =
                    songs[index - 1]

            else

                currentSong =
                    songs[#songs]

            end


            playbackToken =
                playbackToken + 1

            stopSpeakers()

            playing = true

            status =
                "LOADING"

        end


    -- ========================================================
    -- SHUFFLE
    -- ========================================================

    elseif action == "shuffle" then

        shuffle =
            not shuffle


        status =
            shuffle
            and "SHUFFLE ON"
            or "SHUFFLE OFF"


    -- ========================================================
    -- LOOP
    -- ========================================================

    elseif action == "loop" then

        loopMode =
            (
                loopMode + 1
            ) % 3


        if loopMode == 0 then

            status =
                "LOOP OFF"

        elseif loopMode == 1 then

            status =
                "LOOP ALL"

        else

            status =
                "LOOP ONE"

        end


    -- ========================================================
    -- VOLUME DOWN
    -- ========================================================

    elseif action == "volumeDown" then

        volume =
            math.max(
                0,
                volume - 0.05
            )


        status =
            "VOLUME "
            .. math.floor(
                volume * 100
            )
            .. "%"


    -- ========================================================
    -- VOLUME UP
    -- ========================================================

    elseif action == "volumeUp" then

        volume =
            math.min(
                1,
                volume + 0.05
            )


        status =
            "VOLUME "
            .. math.floor(
                volume * 100
            )
            .. "%"


    -- ========================================================
    -- PAGE PREVIOUS
    -- ========================================================

    elseif action == "pagePrevious" then

        if currentPage > 1 then

            currentPage =
                currentPage - 1

        end


        status =
            "PAGE "
            .. currentPage


    -- ========================================================
    -- PAGE NEXT
    -- ========================================================

    elseif action == "pageNext" then

        if currentPage <
            pageCount()
        then

            currentPage =
                currentPage + 1

        end


        status =
            "PAGE "
            .. currentPage

    end


    drawUI()

end


-- ============================================================
-- MOUSE INPUT
-- ============================================================

local function inputLoop()

    drawUI()


    while true do

        local event,
            button,
            x,
            y =
            os.pullEvent(
                "mouse_click"
            )


        if button == 1 then

            local handled = false


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

                    handled = true


                    buttonAction(
                        btn.action
                    )


                    break

                end

            end


            -- =================================================
            -- SONG CLICK
            -- =================================================

            if not handled
                and y >= SONG_FIRST + 1
                and y <= SONG_LAST
            then

                local startIndex =
                    (
                        currentPage - 1
                    )
                    * SONGS_PER_PAGE
                    + 1


                local index =
                    startIndex
                    + (
                        y
                        - (
                            SONG_FIRST + 1
                        )
                    )


                if index >= 1
                    and index <= #songs
                then

                    currentSong =
                        songs[index]


                    playbackToken =
                        playbackToken + 1

                    stopSpeakers()

                    playing = true

                    status =
                        "LOADING"


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
    playbackLoop,
    inputLoop
)
