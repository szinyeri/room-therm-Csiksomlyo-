-- Find next time from config
print("loading : futes_proc.lua")

-- timerek
-- 0 fő fűtésprogram időzítő
--

function GetNxtTime()
--print("func: GetNxtTime()")
    local ido = rtctime.epoch2cal(rtctime.get())
    local tm
    local ido_perc = ido.hour*60+ido.min -- napon belül eltelt idő
    local nap = napok[ido.wday] -- a hét melyik napján vagyunk
    if file.exists(hetiProgFile) then
        file.open(hetiProgFile,"r")
        repeat tm = file.readline() -- finding the weekday in config file
        until tm == nap.."\n" or tm==nil
        if tm then
            repeat tm = file.readline() -- finding the start time
              --  print("ReadLine: ",tm)
                if tm == nil then break end
                if not string.find(tm,"[a-z|A-z]+")  then -- ha nincsenek betűk a sorban
                    st_ido = string.sub(tm,string.find(tm,"[0-9]+:[0-9]+"))
                    st_ido = string.sub(st_ido,string.find(st_ido,"^[0-9]+"))*60 + string.sub(st_ido, string.find(st_ido,"[0-9]+$"))
                    -- print("Compare:",ido,st_ido )
                    if ido_perc < st_ido then  -- kovetkezo idozites szamolasa
                      --  print("Kovetkezo; most:", ido_perc,' Start:',st_ido)
                        if st_ido - ido_perc < 60 then -- ha egy órán belül kell indítani
           -- zona es következő cél hőmérséklet beallitasa
                            zona = string.sub(tm,  string.find(tm,",[0-9]+,")) zona =  string.sub(zona,  2, #zona-1) + 0
                            nxt_temp = string.sub(tm,  string.find(tm,",[0-9]+\n")) nxt_temp = string.sub(nxt_temp,  2)
                            -- cél hőmérséklet aktiválása
                            tmr.alarm(0, (st_ido - ido_perc)*60*1000, tmr.ALARM_SINGLE, function()
                                    auto_T = nxt_temp
                                    get_env() -- hőmérséklet mérése és fűtés kapcsolása
                                    GetNxtTime() -- következő hőmérséklet érték kiolvasása
                               end) -- idozites lejarta utan beállítja az elérni kívánt hőmérsékletet
                            print("Timer 0 : "..st_ido - ido_perc.." perc")
                        else -- tobb mint egy ora van a következő hőmérséklet értékig
                            tmr.alarm(0, 60*60*1000, tmr.ALARM_SINGLE, GetNxtTime) -- 1 ora varakozas
                            syslog("futes_proc.lua - GetNxtTime() - Timer0 = 1 hour wait...")
                        end
                        break -- kilepes a repeat ciklusbol mert talált egyet
                    else
                        local p_temp = string.sub(tm,  string.find(tm,",[0-9]+\n"))
                        auto_T = string.sub(p_temp,  2)
                    end
                end
            until string.find(tm,"[a-z|A-Z]+") or tm==nil
        else
            print(nap.." no timing found") -- erre a napra nincs tobb idozites
        end
        if tm == nil then tm = nap end
        if string.find(tm,"[a-z|A-Z]+") then -- nincs tobb idozites erre a napra
           if 1440-ido_perc > 60 then
           --       print("Timer 0 Várakozás...1ó")
                 tmr.alarm(0, 60*60*1000, tmr.ALARM_SINGLE, GetNxtTime) -- 1 ora varakozas
           else
           --      print("Timer 0 : Várakozás következő napra")
                 tmr.alarm(0, (1440-ido_perc)*60*1000, tmr.ALARM_SINGLE, GetNxtTime) -- nap végéig várakozás
          end
        end
        file.close()
    else
        syslog("futes_proc.lua - GetNxtTime(): File open failed: "..hetiProgFile)
    end
end

-- mindig csak egy zona lehet aktiv
-- bekapcs="1" ->  bekapcsol, minden másra kikapcsol
-- manual=true -> logban jelzi, hogy kezi kapcsolas tortent
-- Hi tipusú relénél gpio.LOW kapcsolja ki a relét, NO kimenetre csatlakozunk
function FutesBeKapcs(bekapcs)
  -- print( "func: FutesBeKapcs()", type(bekapcs), bekapcs )
    local kell_log = false
    if bekapcs ~= nil and bekapcs == 1 then
        if gpio.read(zona_pin) == gpio.LOW then -- be kell kapcsolni, mert ki van kapcsolva
            gpio.write(zona_pin, gpio.HIGH) -- bekapcsolja a fűtés relét
            kell_log = true
        end
    elseif bekapcs ~=nil and bekapcs == 0 then
        if gpio.read(zona_pin) == gpio.HIGH then -- ki kell kapcsolni, mert be van kapcsolva
            gpio.write(zona_pin, gpio.LOW)
            kell_log = true
        else -- FSD-ben központi vezérlés miatt kell egy trigger
            gpio.write(zona_pin, gpio.LOW) -- 3 sec-re bekapcsol, majd timer1-el kikapcsol
         --   tmr.alarm(1, 3*1000, tmr.ALARM_SINGLE, function() gpio.write(zona_pin, gpio.LOW) end)
        end
    end
    if kell_log then
        syslog(string.format("futes_proc.lua - FutesBeKapcs(): bekapcs=%s ; automode=%s", tostring(bekapcs), tostring(automode) ))
    end
end

function bs2hex(b)
     local t = {}
     for i = 1, #b do
          t[i] = string.format('%02X', b:byte(i))
     end
     return table.concat(t)
end

function hex2bs(h)
    local t={}
    for k in h:gmatch"(%x%x)" do
        table.insert(t,string.char(tonumber(k,16)))
    end
    return table.concat(t)
end
