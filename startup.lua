local repo = "alphaddiction/musictweaks"

-- CC: Tweaked DFPWM Playlist
-- Control mediante ratón en la pantalla del ordenador

local dfpwm = require("cc.audio.dfpwm")

local speakers = { peripheral.find("speaker") }

if #speakers == 0 then
    error("No speaker(s) attached")
end

-- ===== Terminal setup =====

term.setBackgroundColor(colors.black)
term.setTextColor(colors.white)
term.clear()

-- ===== Songs setup =====

local songIndexUrl =
    "https://raw.githubusercontent.com/" ..
    repo ..
    "/refs/heads/main/index.txt"

local response = http.get(songIndexUrl)

if not response then
    error("No se pudo descargar el index.txt desde GitHub")
end

local indexData = response.readAll()
response.close()

local songNames = textutils.unserialize(indexData)

if not songNames then
    error("El index.txt no tiene un formato valido")
end

local songs = {}

for _, name in ipairs(songNames) do

    table.insert(songs, {

        name = name,

        fn = function()

            local encodedName =
                name:gsub(" ", "%%20")

            local url =
                "https://raw.githubusercontent.com/" ..
                repo ..
                "/refs/heads/main/" ..
                encodedName ..
                ".dfpwm"

            local songResponse =
                http.get(url)

            if not songResponse then
                error(
                    "No se pudo descargar: " ..
                    name ..
                    ".dfpwm"
                )
            end

            local data =
                songResponse.readAll()

            songResponse.close()

            return data

        end
    })

end

-- ===== Playback state =====

local savedName =
    settings.get("currentSong", nil)

local currentSong = nil

if savedName ~= nil then

    for _, song in ipairs(songs) do

        if song.name == savedName then

            currentSong = song

            break

        end

    end

end

local playing =
    settings.get("playing", false)

local stopFlag = false

local shuffle =
    settings.get("shuffle", true)

local loopMode =
    settings.get("loopMode", 0)

-- 0 = Off
-- 1 = All
-- 2 = One

local volume = 0.35

local decoder =
    dfpwm.make_decoder()

local currentPage =
    settings.get("currentPage", 1)

local width, height =
    term.getSize()

local topRows = 2
local bottomRows = 5

local songsPerPage =
    height -
    topRows -
    bottomRows

if songsPerPage < 1 then
    songsPerPage = 1
end

-- ===== Button storage =====

local buttons = {}

-- ===== Page calculation =====

local function totalPages()

    return math.max(
        1,
        math.ceil(
            #songs /
            songsPerPage
        )
    )

end

-- Make sure the saved page is valid

if currentPage < 1 then
    currentPage = 1
end

if currentPage > totalPages() then
    currentPage = totalPages()
end

-- ===== UI =====

local function drawUI()

    term.setBackgroundColor(
        colors.black
    )

    term.setTextColor(
        colors.white
    )

    term.clear()

    -- ===== Now Playing =====

    term.setCursorPos(2, 1)

    term.setTextColor(
        colors.white
    )

    term.write(
        "Now Playing: " ..
        (
            currentSong
            and currentSong.name
            or "(none)"
        )
    )

    -- ===== Song list =====

    local startIdx =
        (currentPage - 1) *
        songsPerPage +
        1

    local y = 3

    for i = startIdx,
        math.min(
            startIdx +
            songsPerPage -
            1,
            #songs
        )
    do

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

        else

            term.setTextColor(
                colors.white
            )

        end

        term.write(
            songs[i].name
        )

        y = y + 1

    end

    -- ===== Buttons =====

    buttons = {}

    local btnLines = {

        {
            "Shuffle: " ..
            (
                shuffle
                and "On"
                or "Off"
            ),

            "Loop: " ..
            ({
                [0] = "Off",
                [1] = "All",
                [2] = "One"
            })[loopMode]
        },

        {
            "Page " ..
            currentPage ..
            "/" ..
            totalPages(),

            "Prev",
            "Next"
        },

        {
            (
                playing
                and "Playing"
                or "Stopped"
            ),

            "Skip"
        },

        {
            "-",

            "Volume: " ..
            math.floor(
                volume * 100
            ) ..
            "%",

            "+"
        }

    }

    local startY =
        height -
        bottomRows +
        1

    for lineIdx, line
        in ipairs(btnLines)
    do

        local x = 2

        local buttonY =
            startY +
            lineIdx -
            1

        for _, btn
            in ipairs(line)
        do

            local btnStartX = x

            local btnEndX =
                btnStartX +
                #btn +
                1

            -- Dibujar botón

            term.setCursorPos(
                btnStartX,
                buttonY
            )

            term.setBackgroundColor(
                colors.gray
            )

            term.setTextColor(
                colors.white
            )

            term.write(
                " " ..
                btn ..
                " "
            )

            -- Guardar zona exacta
            -- del botón

            table.insert(
                buttons,
                {
                    text = btn,

                    x1 = btnStartX,
                    x2 = btnEndX,

                    y1 = buttonY,
                    y2 = buttonY
                }
            )

            x =
                btnEndX +
                2

        end

    end

    term.setBackgroundColor(
        colors.black
    )

end

-- ===== Save settings =====

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

    settings.set(
        "playing",
        playing
    )

    settings.save()

end

-- ===== Playback =====

local function playerLoop()

    while true do

        if currentSong and playing then

            local songData =
                currentSong.fn()

            local dataLen =
                #songData

            for i = 1,
                dataLen,
                16 * 1024
            do

                if stopFlag then
                    break
                end

                local chunk =
                    songData:sub(
                        i,
                        math.min(
                            i +
                            16 * 1024 -
                            1,
                            dataLen
                        )
                    )

                local buffer =
                    decoder(chunk)

                local pending = {}

                for _, spk
                    in pairs(speakers)
                do

                    if stopFlag then
                        break
                    end

                    if not spk.playAudio(
                        buffer,
                        volume
                    )
                    then

                        pending[
                            peripheral.getName(
                                spk
                            )
                        ] = spk

                    end

                end

                while
                    not stopFlag
                    and next(pending)
                do

                    local _, name =
                        os.pullEvent(
                            "speaker_audio_empty"
                        )

                    local spk =
                        pending[name]

                    if spk
                        and spk.playAudio(
                            buffer,
                            volume
                        )
                    then

                        pending[name] = nil

                    end

                end

            end

            -- ===== Song finished =====

            if stopFlag then

                stopFlag = false

            else

                if loopMode == 2 then

                    -- Same song

                elseif shuffle then

                    currentSong =
                        songs[
                            math.random(
                                #songs
                            )
                        ]

                elseif loopMode == 1 then

                    local idx = 1

                    for i, s
                        in ipairs(songs)
                    do

                        if s ==
                            currentSong
                        then

                            idx = i

                            break

                        end

                    end

                    currentSong =
                        songs[
                            idx % #songs + 1
                        ]

                else

                    local idx = 1

                    for i, s
                        in ipairs(songs)
                    do

                        if s ==
                            currentSong
                        then

                            idx = i

                            break

                        end

                    end

                    if idx < #songs then

                        currentSong =
                            songs[idx + 1]

                    else

                        currentSong = nil

                        playing = false

                    end

                end

                saveSettings()

            end

            drawUI()

        else

            os.sleep(0.05)

        end

    end

end

-- ===== Mouse input =====

local function inputLoop()

    drawUI()

    while true do

        -- IMPORTANTE:
        -- El ordenador recibe:
        --
        -- button, x, y
        --
        -- mediante mouse_click.

        local button, x, y =
            os.pullEvent(
                "mouse_click"
            )

        -- Solo aceptamos
        -- el botón izquierdo.

        if button == 1 then

            local clicked = false

            -- ==================================
            -- BOTONES
            -- ==================================

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

                    -- ===== Shuffle =====

                    if
                        btn.text:find(
                            "Shuffle"
                        )
                    then

                        shuffle =
                            not shuffle

                    -- ===== Loop =====

                    elseif
                        btn.text:find(
                            "Loop"
                        )
                    then

                        loopMode =
                            (
                                loopMode +
                                1
                            ) % 3

                    -- ===== Previous =====

                    elseif
                        btn.text == "Prev"
                    then

                        if currentPage > 1 then

                            currentPage =
                                currentPage -
                                1

                        end

                    -- ===== Next =====

                    elseif
                        btn.text == "Next"
                    then

                        if currentPage <
                            totalPages()
                        then

                            currentPage =
                                currentPage +
                                1

                        end

                    -- ===== Play / Stop =====

                    elseif
                        btn.text == "Playing"
                        or
                        btn.text == "Stopped"
                    then

                        if playing then

                            stopFlag = true

                            playing = false

                        else

                            if currentSong then

                                playing = true

                            end

                        end

                    -- ===== Skip =====

                    elseif
                        btn.text == "Skip"
                    then

                        if #songs > 0 then

                            local idx = 1

                            if currentSong then

                                for i, s
                                    in ipairs(songs)
                                do

                                    if s ==
                                        currentSong
                                    then

                                        idx = i

                                        break

                                    end

                                end

                            end

                            if shuffle then

                                currentSong =
                                    songs[
                                        math.random(
                                            #songs
                                        )
                                    ]

                            elseif idx <
                                #songs
                            then

                                currentSong =
                                    songs[
                                        idx + 1
                                    ]

                            else

                                currentSong =
                                    songs[1]

                            end

                            stopFlag = true

                            playing = true

                        end

                    -- ===== Volume - =====

                    elseif
                        btn.text == "-"
                    then

                        volume =
                            math.max(
                                0,
                                volume -
                                0.05
                            )

                    -- ===== Volume + =====

                    elseif
                        btn.text == "+"
                    then

                        volume =
                            math.min(
                                1,
                                volume +
                                0.05
                            )

                    end

                    saveSettings()

                    drawUI()

                    break

                end

            end

            -- ==================================
            -- SONG LIST
            -- ==================================

            if not clicked then

                local startIdx =
                    (currentPage - 1) *
                    songsPerPage +
                    1

                for i = startIdx,
                    math.min(
                        startIdx +
                        songsPerPage -
                        1,
                        #songs
                    )
                do

                    local row =
                        3 +
                        (i - startIdx)

                    if y == row then

                        currentSong =
                            songs[i]

                        stopFlag = true

                        playing = true

                        saveSettings()

                        drawUI()

                        clicked = true

                        break

                    end

                end

            end

        end

    end

end

-- ===== Start program =====

parallel.waitForAny(
    playerLoop,
    inputLoop
)
