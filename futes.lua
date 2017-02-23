-- main
print("loading : futes.lua")

-- kezdeti inicializálás global funkciók
function OntInit()
   -- slog_ip = '192.168.44.254' ha a syslog server nem a default gateway
  --  print ("env init: "..environment.init()) -- inicializálja a hőmérőt a default potokon scl=5 sda=6
    local msg = "futes.lua - OntInit() -"
    syslog( msg..string.format("Inicializálás... boot reason(%d, %d)",node.bootreason()))
    --print(type(res), #res, res[1], res[2])
    zona_pin=1 -- itt van a fűtés kapcsoló relé
    dofile("webserv.lc")
    syslog(msg.." WiFi connected: "..wifi.sta.getip())
    -- periódikus hőmérséklet mérés elindítása 2 sec múlva
    sntp.sync("pool.ntp.org",
        function(sec,usec,server)
            sec,usec = rtctime.get()
            rtctime.set(sec+3600,usec) -- időzóna miatti állítás
            local tm = rtctime.epoch2cal(rtctime.get())
            syslog(msg.." sntp.sync() - success - server: "..server.." date: "..
                string.format("%04d/%02d/%02d %01d %02d:%02d:%02d", tm["year"], tm["mon"], tm["day"], tm["wday"], tm["hour"], tm["min"], tm["sec"]))
        end,
        function(errcode)
            if errcode == 1 then errmsg = "1: DNS lookup failed"
            elseif errcode == 2 then errmsg = "2: Memory allocation failure"
            elseif errcode == 3 then errmsg = "3: UDP send failed"
            elseif errcode == 4 then errmsg = "4: Timeout, no NTP response received"
            else errmsg = tostring(errcode).." : Other failure"
            end
            syslog(msg.." sntp.sync() - error: "..errmsg)
        end)
     tmr.alarm(3, 5*1000, tmr.ALARM_SINGLE, function()
        FutesBeKapcs("0") -- fűtés kikapcsolással indít, mode=nil
        GetNxtTime() -- itt indítja fűtési program figyelő ciklust
        get_env()
        tmr.alarm(3, 5*60*1000, tmr.ALARM_AUTO, get_env)
    end)

end


-- hőmérséklet ellenőrzése és fűtés kapcsolása
-- 5 percenként történik timer3 callback segítségével, vagy érték változásakor
function get_env()
   local temps = {}
    if isremoteIP == false or isremIPtout==true then -- nincs távoli hőmérő, vagy nem válaszol
      print("no remote temp")
    else -- távoli szobahőmérőt olvassuk ki
        getRemoteTemp() -- az ertekek beerkezese utan vezérel
    end
  temps = dofile("gettemps.lc")
  print(string.format(" remote:%2.1f, %2.1f temps: %2.1f, %2.1f%%, %2.1f, %2.1f ", remote_env[1]/10, remote_env[2]/10, temps[1], temps[2], temps[3], temps[4]))
  print (string.format("futes.lua - get_env() - mert_T=%2.1f;  humidity=%2.1f%% elore=%2.1f vissza1=%2.1f, vissza2=%2.1f, vissza3=%2.1f",
           remote_env[2]/10, remote_env[1]/10, temps[1], temps[2],  temps[3], temps[4]))
        syslog(string.format("futes.lua - get_env() - mert_T=%2.1f;  humidity=%2.1f%% elore=%2.1f vissza1=%2.1f, vissza2=%2.1f, vissza3=%2.1f",
            remote_env[2]/10, remote_env[1]/10, temps[1], temps[2],  temps[3], temps[4]))
end

-- ha automode=false, akkor kézi vezérlésen vagyunk, nem kell kapcsolni, de mérni kell
function futesVez()
    local temp_needed
    local temp_curr
    -- hogy a cel_temp biztos, hogy szám legyen
    if automode == true then
        temp_needed = auto_T + 0
    else --  kézi üzemmód
        temp_needed = man_T + 0
    end
    if (isremIPtout== true) then
        temp_curr = 99
    else
        temp_curr = remote_env
    end
    if (temp_needed > temp_curr[2] + hist ) then -- hiszterézissel is számol
        FutesBeKapcs(1) --  bekapcs
    elseif  (temp_needed < temp_curr[2] - hist ) then -- hiszterézissel is számol
        FutesBeKapcs(0) -- kikapcs
    end
end

-- várakozik WiFi kapcsolatra
function WiFiOKWt()
    print("func: WiFiOKWt()")
    local ssid, password, bssid_set, bssid=wifi.sta.getconfig()
  --  print("\nCurrent Station configuration:\nSSID : "..ssid
  --      .."\nPassword  : "..password
  --      .."\nBSSID_set  : "..bssid_setv
  --      .."\nBSSID: "..bssid)
    if ssid == "" then -- nincs WiFi konfigurálva
        print ("WiFi config üres, setting default.")
        wifi.setmode(wifi.STATION)
        print ("Current WiFi Mode: "..wifi.getmode())
        wifi.sta.config("nabukodonozor", "KawaiES3DigitalisZongora2012")
    end
    if wt_time_ctr == nil then
        wt_time_ctr = 1
    else
        wt_time_ctr = wt_time_ctr*2
    end
    if wt_time_ctr > 22 then
        print("WiFI AP not connected: restarting node") node.restart()
    end
    if wifi.sta.status() == 5 then -- WiFi connected
        tmr.alarm(0, 100, tmr.ALARM_SINGLE, WTFunc)
    else
        print("WiFi not connected ", wifi.sta.getconfig(), "wait_time_ctr:", wt_time_ctr)
        tmr.alarm(0, wt_time_ctr*1000, tmr.ALARM_SINGLE,  WiFiOKWt)
    end

end

function syslog(msg)
    --local _,_,slog_ip = wifi.sta.getip() -- default gateway a syslog server
    if slog_ip == "10.10.2.20" then
        slog_ip="10.10.2.5"
    end
    if slog_ip ~= nil and msg ~=nil then
        msg = "<12> UpTime="..uptime().."; Node ID="..node.chipid().." Heap="..node.heap().."; msg: "..msg
        local slog_sck = net.createConnection(net.UDP, 0)
        slog_sck:connect(514, slog_ip)
        slog_sck:send(msg, function(sck) print("UDP Sent")
                                                sck:close()
                                                sck=nil
                                              end )
        print(msg)
    else
        print("Cannot send syslog, IP: "..tostring(slog_ip).." msg="..tostring(msg))
    end
end

--- távoli hőmérő kiolvasása
function getRemoteTemp()
  local remoteTemp = net.createConnection(net.TCP, 0)
  remoteTemp:connect(8080, remoteIP)
  tmr.alarm(2, 3000, tmr.ALARM_SINGLE, function() 
    print("remoteTemp timeout")
    isremIPtout=true
    remoteTemp:close()
  end)
  remoteTemp:on("receive", function(sck, c) 
    c= string.sub(c,string.find(c, "\r\n\r\n")+4, #c)
    local i=1
    for ertek in string.gmatch(c, '([^,]+)') do -- válasz felszabdalása vesszőknél
        remote_env[i] = ertek
        i=i+1
    end
    isremIPtout=false
    sck:close()
    futesVez() -- kapcsol is, ha szükséges
 end)
 remoteTemp:on("connection", function(sck,c)
    tmr.unregister(2) -- timeout számlálót megállítjuk
    local msg = "GET /?status=1 HTTP/1.1\r\nHost:"..wifi.sta.getip().."\r\nUser-Agent: room-therm NodeMCU\r\nAccept: text/html\r\n\r\n"
    print("in onConnection", msg)
    sck:send(msg) 
 end)
 
end

function uptime()
    local upt =tmr.time()
    local ora = math.floor(upt/3600)
    local perc = math.floor((upt-ora*3600)/60)
    local mperc = upt-ora*3600-perc*60
    return string.format("%dh %dmin %dsec", ora, perc, mperc)
end

-- hőmétő i2c kiolvasásakor transmission error kezelésére
function  try(f, catch_f)
       local status, exception = pcall(f)
       if not status then catch_f(exception) end
end 

WTFunc = OntInit -- OntInit után GetGWTime jön
WiFiOKWt() -- WiFi check
