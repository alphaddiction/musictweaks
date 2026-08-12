-- ============================================================
-- MUSIC TWEAKS - AUDIO RECEIVER
-- FASE 1 - NETWORK TEST
-- ============================================================

local PROTOCOL = "musictweaks"

-- ============================================================
-- CONFIGURACIÓN
-- ============================================================

local modem = peripheral.find(
    "modem",
    function(name, wrapped)
        return wrapped.isWireless()
    end
)

if not modem then
    error("No wireless modem found.")
end

rednet.open(
    peripheral.getName(modem)
)


-- ============================================================
-- NOMBRE DE LA ZONA
-- ============================================================

local zoneName =
    settings.get(
        "musictweaks.zoneName",
        nil
    )


if not zoneName then

    term.clear()
    term.setCursorPos(1, 1)

    print("================================")
    print("       MUSIC TWEAKS")
    print("        AUDIO RECEIVER")
    print("================================")
    print("")
    print("Este ordenador sera un receptor.")
    print("")
    print("Introduce el nombre de la zona:")
    print("Ejemplo: SALON")
    print("")


    write("> ")

    zoneName =
        read()


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
-- ID
-- ============================================================

local myId =
    os.getComputerID()


-- ============================================================
-- SPEAKERS
-- ============================================================

local speakers = {
    peripheral.find("speaker")
}


-- ============================================================
-- INTERFAZ
-- ============================================================

local function draw(
    centralId,
    connected
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
        "        MUSIC TWEAKS"
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
        .. myId
    )

    print("")

    if connected then

        term.setTextColor(
            colors.lime
        )

        print(
            "● CONNECTED"
        )

        term.setTextColor(
            colors.white
        )

        print("")

        print(
            "CENTRAL ID: "
            .. tostring(
                centralId
            )
        )

    else

        term.setTextColor(
            colors.red
        )

        print(
            "● WAITING FOR CENTRAL"
        )

        term.setTextColor(
            colors.white
        )

    end

    print("")

    print(
        "SPEAKERS: "
        .. #speakers
    )

    print("")

    print(
        "Protocol: "
        .. PROTOCOL
    )

end


-- ============================================================
-- ESTADO
-- ============================================================

local centralId = nil

local connected = false


draw(
    centralId,
    connected
)


-- ============================================================
-- ENVIAR HELLO
-- ============================================================

local function sendHello()

    rednet.broadcast(
        {
            type = "HELLO",

            zone = zoneName,

            computerId = myId,

            speakers = #speakers
        },

        PROTOCOL
    )

end


-- ============================================================
-- HELLO INICIAL
-- ============================================================

sendHello()


-- ============================================================
-- EVENT LOOP
-- ============================================================

local function networkLoop()

    while true do

        local senderId,
            message =
            rednet.receive(
                PROTOCOL,
                5
            )


        if senderId
            and type(message)
            == "table"
        then

            -- ================================================
            -- CENTRAL HELLO
            -- ================================================

            if message.type
                == "CENTRAL_HELLO"
            then

                centralId =
                    senderId

                connected = true


                rednet.send(
                    centralId,

                    {
                        type = "RECEIVER_HELLO",

                        zone = zoneName,

                        computerId = myId,

                        speakers = #speakers
                    },

                    PROTOCOL
                )


                draw(
                    centralId,
                    connected
                )


            -- ================================================
            -- PING
            -- ================================================

            elseif message.type
                == "PING"
            then

                centralId =
                    senderId

                connected = true


                rednet.send(
                    centralId,

                    {
                        type = "PONG",

                        zone = zoneName,

                        computerId = myId,

                        speakers = #speakers
                    },

                    PROTOCOL
                )


                draw(
                    centralId,
                    connected
                )


            -- ================================================
            -- SET ZONE NAME
            -- ================================================

            elseif message.type
                == "SET_ZONE"
            then

                if message.name then

                    zoneName =
                        tostring(
                            message.name
                        )


                    settings.set(
                        "musictweaks.zoneName",
                        zoneName
                    )

                    settings.save()


                    centralId =
                        senderId

                    connected = true


                    draw(
                        centralId,
                        connected
                    )

                end

            end

        else

            -- Timeout:
            -- comprobar que el central sigue ahí.

            connected = false

            centralId = nil

            draw(
                centralId,
                connected
            )

            sendHello()

        end

    end

end


-- ============================================================
-- START
-- ============================================================

parallel.waitForAny(
    networkLoop
)
