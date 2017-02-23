if srv then srv:close() srv=nil collectgarbage() end
server_busy= false
srv=net.createServer(net.TCP)
srv:listen(80,function(conn)
    local idx = 0 --keep track of where we are in the file
    conn:on("receive", function(client,payload)
        local k,v, result
        local httpmsg = "\r\nServer: nodemcu-szobatermosztat\r\nContent-Type: text/html\r\nCache-Control: 86400\r\nConnection: close\r\n\r\n"
      -- print("conn:",conn, "client:",client)
          -- csak egyetlen kapcsolatot fogadunk el egyszerre
        local logmsg = "newserver.lua - conn:on 'receive' from "..client:getpeer()
        if server_busy == false then
     --       print("server ready")
        --    server_busy = true
            tgtfile = string.sub(payload,string.find(payload,"GET /")+5,string.find(payload,"HTTP/")-2)
            print("tgtfile:",tgtfile)
            if tgtfile == "" then tgtfile = "index.htm"  end
            if string.sub(tgtfile,1,1) =="?" then -- parancs ertelmezese
        --    print("parancs vetel")
                local _GET={}
                for k, v in string.gmatch(tgtfile, "(%w+)=([%w.|:,]+)&*") do
                    _GET[k] = v
              print("key:",k, " value:",_GET[k])
                end
                if ( _GET.zona and _GET.interv and _GET.start) then -- kézi vezérléshez
                    interv, zona = _GET.interv+0, _GET.zona+0
            --       if zona >= 1 and zona <= #zona_pin then
                        if _GET.start == "1" and interv >1 and interv < 60 then
                            logmsg = logmsg.." manual Start "
                            FutesBeKapcs(1)
                        else
                            logmsg = logmsg.." manual Stop "
                            FutesBeKapcs(0)
                            --tmr.alarm(2, 500, tmr.ALARM_SINGLE, function() FutesBeKapcs(0) end)
                        end
            --        end
                elseif (_GET.autofutes) then -- fűtés automatikus mód kapcsolása
                    if (_GET.autofutes =="1") then
                        -- automatikus mód visszakapcsolása
                        automode = true
                        get_env()
                    else
                        automode = false
                        get_env()
                        --tmr.alarm(2, 500, tmr.ALARM_SINGLE, get_env)
                    end
                    logmsg = logmsg.." set automode = "..tostring(automode)
                elseif (_GET.settemp) then -- kézi hőmérséklet beállítása
                    _GET.settemp = _GET.settemp +0
                    if (_GET.settemp >= min_T and _GET.settemp <= max_T) then
                        man_T =_GET.settemp
                        if automode == false then futesVez() end
                    end
                    logmsg = logmsg.." set man_T= "..tostring(man_T)
                elseif (_GET.status) then
                -- nem kell csinálni semmit,az állapotot küldi vissza
                    logmsg = logmsg.." status request"

                elseif (_GET.setremote) then -- beállítja azt a hőmérőt, amiből a hőmérsékletet ki kell olvasni
                    remoteIP = _GET.setremote
                    if (remoteIP =="0.0.0.0") then
                        isremoteIP=false
                        file.remove("remote_init.lua")
                    else
                        isremoteIP=true
                        file.open("remote_init.lua","w+")
                        file.writeline('remoteIP = "'..remoteIP..'"')
                        file.writeline("isremoteIP = "..tostring(isremoteIP))
                        file.close()
                    end
                   
                    logmsg = logmsg.." remote node ip set:"..remoteIP
                elseif (_GET.restart) then
                    logmsg = logmsg.." restarting node by user command"
                    tmr.alarm(2, 3000, tmr.ALARM_SINGLE, node.restart)
                elseif (_GET.removefile) then -- file törlése
                    if file.exists(_GET.removefile) then
                        file.remove(_GET.removefile)
                        logmsg = logmsg.." file removed: "
                    else
                        logmsg = logmsg.." remove file not found: "
                    end
                    logmsg = logmsg.._GET.removefile
                elseif (_GET.renameto and _GET.from) then -- file átnevezése
                    if file.exists(_GET.from) then
                        file.remove(_GET.renameto)
                        file.rename(_GET.from, _GET.renameto)
                        logmsg = logmsg.." file rename OK: "
                        --GetGWTime()
                    else
                        logmsg = logmsg.." file rename failed: "
                    end
                    logmsg = logmsg.._GET.from.." to ".._GET.renameto
                elseif (_GET.file and _GET.write) then -- file írása
                    logmsg = logmsg.." file=".._GET.file.." write len = "..#_GET.write
                    if (file.open(_GET.file..".tmp", "a+")) then
            --         print("_GET.write=",_GET.write)
                        file.seek("end")
                        if (_GET.replacepipe) then -- zoneconfig "|" csere "\n"-re
                            if (file.write(string.gsub(_GET.write,"|","\n"))) then
                                logmsg = logmsg.." write OK "
                            else
                                logmsg = logmsg.." write failed "
                            end
                        else
                            if (file.writeline(_GET.write)) then
                                logmsg = logmsg.." writeline OK "
                            else
                                logmsg = logmsg.." writeline failed "
                            end
                        end
                        file.close()
                    else
                        logmsg = logmsg.." .tmp file open failed "
                    end
                    logmsg = logmsg.._GET.file
                elseif (_GET.save) then -- idők módosítása
                    dofile("change_tmr.lua")
                elseif (_GET.complie and _GET.file) then -- lua script lefordítása
                    node.compile(_GET.file)
                    logmsg = logmsg.." node.compile done ".._GET.file
                end
                -- ha nem kell file-t visszaküldeni, akkor a rendszer aktuális állapotát küldi vissza
                client:send(string.format("HTTP/1.1 200 OK%s {\"automode\":\"%s\", \"auto_T\":%d, \"man_T\":%d, \"futes\":%d, \"humi_2\":%d, \"hom_2\":%d, \"elore\":%d, \"vissza_1\":%d, \"vissza_2\":%d, \"vissza_3\":%d}",
                    httpmsg, tostring(automode), auto_T, man_T, gpio.read(zona_pin), remote_env[1], remote_env[2], temps[1], temps[2], temps[3], temps[4]))
            else
                print("requested file:", tgtfile, node.heap())
                if file.open(tgtfile,"r") then
                    file.close()
                    result = "200 OK"
                else
                    tgtfile="http404.htm"
                    result = "404 Not Found"
                end
                -- fájl küldése előtt küldjük a headert
                print("sending: HTTP/1.1 "..result..httpmsg)
                client:send("HTTP/1.1 "..result..httpmsg)
         --          print("sent", node.heap())
            end
        else -- serverbusy==true
            logmsg=logmsg.." server busy"
            client:send("HTTP/1.1 503 Service Unavailable\r\nServer: nodemcu-szobatermosztat\r\nContent-Type: text/html\r\nRetry-After: 10\r\nConnection: close\r\n\r\n")
        end
        syslog(logmsg)
        logmsg = ""
    end)

        conn:on("sent", function(c) --open file, read a chunk, and send it!
        local str
   --    print("nextChunk:",tgtfile)
        if string.sub(tgtfile,1,1) =="?" then -- parancs ertelmezese
        --    print(" conn:on('sent' Function-- ide sose juthatna el")
        -- ide akkor érkezik, ha vezérlés kérés volt
            tmr.delay(10)
            c:close()
        elseif tgtfile and file.open(tgtfile) then
        --    print("nextChunk()", idx,tgtfile )
            if  not file.seek("set", idx) then  --no more to send.
       --         print("file sent", tgtfile, idx)
        --      tgtfile = nil
                file.close()
                c:close();
                local heapSize=node.heap()
                collectgarbage()
         --       print("Memory Used:"..collectgarbage("count"))
         --       print("Heap Available:"..heapSize)
            else
                str = file.read(500) --print("sending:",str)
                c:send(str)
                file.close()
                idx = idx + 500
            end
        else
            c:close();
       -- collectgarbage()
        end
    end) --every time we send a chunk, start the next one!
    conn:on("connection", function() print("socket:connection", tgtfile) end)
    conn:on("disconnection", function(c)
     --   print("socket:disconnection", c, node.heap(), collectgarbage("collect"))
        _GET="" _GET=nil server_busy=false tgtfile="" tgtfile=nil payload="" payload=nil
    end)
end)

