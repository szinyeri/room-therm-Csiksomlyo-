-- init globals
nxt_temp = 100 -- ez lesz a következő elérendő hőmérséklet
auto_T = 100 -- aktuálisan ezt a hőmérsékletet kell elérni
man_T = 30 -- kézi beállítás esetén itt tárolja a szükséges hőmérsékletet
min_T = 20 -- minimum beállítható hőmérséklet
max_T = 300 -- maximum beállítható hőmérséklet
prev_temp = 0 -- időzítésben az aktuális időhöz képest előzőleg megadott hőmérséklet érték
lastenv = {0,0}
remote_env ={0,0,0,0}
napok ={"Sun", "Mon", "Tue", "Thu", "Wed", "Fri", "Sat"}
automode = false -- ha automatikus üzemmódban van, azaz az előre beállítottak alapján kapcsol
hist = 3 -- histerezis 
isremIPtout=false --távoli homero még nem került kiolvasasra
hetiProgFile="ahetiprog"
slog_ip="192.168.4.254"

ow_port = 4 -- one wire port
sensors = {}


if file.open("remote_init.lua","r") then
    file.close()
    dofile("remote_init.lua")
else
    remoteIP="0.0.0.0"
    isremoteIP=false
end

-- timerek
-- 0 fő fűtésprogram időzítő
-- 
