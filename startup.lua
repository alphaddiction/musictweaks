-- ============================================================
-- MusicTweaks - ComputerCraft / CC:Tweaked
-- Standalone startup.lua
--
-- INTERFAZ:
--   Se muestra SIEMPRE en la pantalla del ordenador.
--   No utiliza monitores.
--
-- CONTROL:
--   Ratón del ordenador -> mouse_click
--
-- REPOSITORIO:
--   https://github.com/alphaddiction/musictweaks
-- ============================================================


-- ============================================================
-- CONFIGURACION
-- ============================================================

local REPO = "alphaddiction/musictweaks"

local INDEX_URL =
    "https://raw.githubusercontent.com/"
    .. REPO
    .. "/refs/heads/main/index.txt"


-- ============================================================
-- TERMINAL DEL ORDENADOR
-- ============================================================

-- term.native() es la pantalla nativa del ordenador.
-- Esto evita que una redirección anterior hacia un monitor
-- nos mande la interfaz a otro dispositivo.

local computerTerm = term.native()

term.redirect(computerTerm)

term.setBackgroundColor(colors.black)
term.setTextColor(colors.white)
term.clear()
term.setCursorPos(1, 1)


-- ============================================================
-- SPEAKERS
-- ============================================================

local speakers = {
    peripheral.find("speaker")
}

if #speakers == 0 then
    error("No speaker(s) attached")
end


-- ============================================================
-- DFPWM
-- ============================================================

local dfpwm = require("cc.audio.dfpwm")

local decoder = dfpwm.make_decoder()


-- ============================================================
-- CARGAR INDEX
-- ============================================================

local response = http.get(INDEX_URL)

if not response then
    error(
        "No se pudo descargar index.txt"
    )
end

local indexData = response.readAll()

response.close()

local songNames =
    textutils.unserialize(indexData)

if not songNames then
    error(
        "index.txt no tiene un formato valido"
    )
end


-- ============================================================
-- CREAR LISTA DE CANCIONES
-- ============================================================

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
                    .. REPO
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


-- ============================================================
-- ESTADO
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

-- 0 = Off
-- 1 = All
-- 2 = One


local volume = 0.35

local stopFlag = false


-- ============================================================
-- PANTALLA
-- ============================================================

local width, height =
    term.getSize()


local topRows = 2

local bottomRows = 5


local songsPerPage =
    height
    - topRows
    - bottomRows


if songsPerPage < 1 then
    songsPerPage = 1
end


local currentPage =
    settings.get(
        "currentPage",
        1
    )


-- ============================================================
-- BOTONES
-- ============================================================

local buttons = {}


-- ============================================================
-- PAGINAS
-- ============================================================

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
-- GUARDAR CONFIGURACION
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
-- DIBUJAR INTERFAZ
-- ============================================================

local function drawUI()

    term.redirect(
        computerTerm
    )

    term.setBackgroundColor(
        colors.black
    )

    term.setTextColor(
        colors.white
    )

    term.clear()


    -- --------------------------------------------------------
    -- NOW PLAYING
    -- --------------------------------------------------------

    term.setCursorPos(
        2,
        1
    )

    term.setTextColor(
        colors.white
    )

    term.write(
        "Now Playing: "
        ..
        (
            currentSong
            and currentSong.name
            or "(none)"
        )
    )


    -- --------------------------------------------------------
    -- CANCIONES
    -- --------------------------------------------------------

    local startIdx =
        (currentPage - 1)
        * songsPerPage
        + 1


    local y = 3


    for i = startIdx,
        math.min(
            startIdx
            + songsPerPage
            - 1,
            #songs
        )
    do

        term.setCursorPos(
            2,
            y
        )


        if currentSong
            == songs[i]
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


    -- --------------------------------------------------------
    -- BOTONES
    -- --------------------------------------------------------

    buttons = {}


    local loopName =
        ({
            [0] = "Off",
            [1] = "All",
            [2] = "One"
        })[loopMode]


    local btnLines = {

        {
            "Shuffle: "
            ..
            (
                shuffle
                and "On"
                or "Off"
            ),

            "Loop: "
            ..
            loopName
        },


        {
            "Page "
            ..
            currentPage
            ..
            "/"
            ..
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

            "Volume: "
            ..
            math.floor(
                volume * 100
            )
            ..
            "%",

            "+"
        }

    }


    local startY =
        height
        - bottomRows
        + 1


    for lineIndex,
        line
        in ipairs(btnLines)
    do

        local x = 2

        local buttonY =
            startY
            + lineIndex
            - 1


        for _, text
            in ipairs(line)
        do

            if text ~= "" then

                local x1 = x

                local x2 =
                    x1
                    + #text
                    + 1


                -- Dibujar botón

                term.setCursorPos(
                    x1,
                    buttonY
                )

                term.setBackgroundColor(
                    colors.gray
                )

                term.setTextColor(
                    colors.white
                )

                term.write(
                    " "
                    ..
                    text
                    ..
                    " "
                )


                -- Guardar coordenadas

                table.insert(
                    buttons,
                    {
                        text = text,

                        x1 = x1,
                        x2 = x2,

                        y1 = buttonY,
                        y2 = buttonY
                    }
                )


                x =
                    x2 + 2

            end

        end

    end


    term.setBackgroundColor(
        colors.black
    )

end


-- ============================================================
-- REPRODUCCION
-- ============================================================

local function playerLoop()

    while true do

        if currentSong
            and playing
        then

            local songData =
                currentSong.fn()


            local dataLength =
                #songData


            for i = 1,
                dataLength,
                16 * 1024
            do

                if stopFlag then
                    break
                end


                local chunk =
                    songData:sub(
                        i,
                        math.min(
                            i
                            + 16 * 1024
                            - 1,
                            dataLength
                        )
                    )


                local buffer =
                    decoder(chunk)


                local pending = {}


                for _, speaker
                    in ipairs(speakers)
                do

                    if stopFlag then
                        break
                    end


                    if not speaker.playAudio(
                        buffer,
                        volume
                    )
                    then

                        pending[
                            peripheral.getName(
                                speaker
                            )
                        ] = speaker

                    end

                end


                while
                    not stopFlag
                    and next(pending)
                do

                    local event,
                        speakerName =
                        os.pullEvent(
                            "speaker_audio_empty"
                        )


                    local speaker =
                        pending[
                            speakerName
                        ]


                    if speaker
                        and speaker.playAudio(
                            buffer,
                            volume
                        )
                    then

                        pending[
                            speakerName
                        ] = nil

                    end

                end

            end


            -- ------------------------------------------------
            -- FIN DE CANCION
            -- ------------------------------------------------

            if stopFlag then

                stopFlag = false

            else

                -- LOOP ONE

                if loopMode == 2 then

                    -- No cambiar canción.


                -- SHUFFLE

                elseif shuffle then

                    currentSong =
                        songs[
                            math.random(
                                #songs
                            )
                        ]


                -- LOOP ALL

                elseif loopMode == 1 then

                    local index = 1


                    for i, song
                        in ipairs(songs)
                    do

                        if song
                            == currentSong
                        then

                            index = i

                            break

                        end

                    end


                    currentSong =
                        songs[
                            index
                            % #songs
                            + 1
                        ]


                -- NORMAL

                else

                    local index = 1


                    for i, song
                        in ipairs(songs)
                    do

                        if song
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

                    else

                        currentSong = nil

                        playing = false

                    end

                end


                saveSettings()

            end


            drawUI()


        else

            os.sleep(
                0.05
            )

        end

    end

end


-- ============================================================
-- RATON DEL ORDENADOR
-- ============================================================

local function inputLoop()

    drawUI()


    while true do

        -- ====================================================
        -- ESTA ES LA PARTE IMPORTANTE
        --
        -- NO monitor_touch
        -- NO monitor
        -- NO eventos genéricos
        --
        -- El ordenador recibe mouse_click.
        -- ====================================================

        local button,
            x,
            y =
            os.pullEvent(
                "mouse_click"
            )


        -- Solo botón izquierdo

        if button == 1 then

            local handled = false


            -- =================================================
            -- BOTONES
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


                    -- -----------------------------------------
                    -- SHUFFLE
                    -- -----------------------------------------

                    if btn.text:find(
                        "Shuffle"
                    )
                    then

                        shuffle =
                            not shuffle


                    -- -----------------------------------------
                    -- LOOP
                    -- -----------------------------------------

                    elseif btn.text:find(
                        "Loop"
                    )
                    then

                        loopMode =
                            (
                                loopMode
                                + 1
                            ) % 3


                    -- -----------------------------------------
                    -- PREV
                    -- -----------------------------------------

                    elseif btn.text == "Prev" then

                        if currentPage > 1 then

                            currentPage =
                                currentPage - 1

                        end


                    -- -----------------------------------------
                    -- NEXT
                    -- -----------------------------------------

                    elseif btn.text == "Next" then

                        if currentPage
                            < totalPages()
                        then

                            currentPage =
                                currentPage + 1

                        end


                    -- -----------------------------------------
                    -- PLAY / STOP
                    -- -----------------------------------------

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


                    -- -----------------------------------------
                    -- SKIP
                    -- -----------------------------------------

                    elseif btn.text == "Skip" then

                        if #songs > 0 then

                            local index = 1


                            if currentSong then

                                for i, song
                                    in ipairs(songs)
                                do

                                    if song
                                        == currentSong
                                    then

                                        index = i

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

                            elseif index < #songs then

                                currentSong =
                                    songs[
                                        index + 1
                                    ]

                            else

                                currentSong =
                                    songs[1]

                            end


                            stopFlag = true

                            playing = true

                        end


                    -- -----------------------------------------
                    -- VOLUMEN -
                    -- -----------------------------------------

                    elseif btn.text == "-" then

                        volume =
                            math.max(
                                0,
                                volume - 0.05
                            )


                    -- -----------------------------------------
                    -- VOLUMEN +
                    -- -----------------------------------------

                    elseif btn.text == "+" then

                        volume =
                            math.min(
                                1,
                                volume + 0.05
                            )

                    end


                    saveSettings()

                    drawUI()

                    break

                end

            end


            -- =================================================
            -- LISTA DE CANCIONES
            -- =================================================

            if not handled then

                local startIdx =
                    (currentPage - 1)
                    * songsPerPage
                    + 1


                for i = startIdx,
                    math.min(
                        startIdx
                        + songsPerPage
                        - 1,
                        #songs
                    )
                do

                    local row =
                        3
                        + (
                            i
                            - startIdx
                        )


                    if y == row then

                        currentSong =
                            songs[i]


                        stopFlag = true

                        playing = true


                        saveSettings()

                        drawUI()


                        handled = true

                        break

                    end

                end

            end

        end

    end

end


-- ============================================================
-- ARRANCAR
-- ============================================================

drawUI()


parallel.waitForAny(
    playerLoop,
    inputLoop
)
