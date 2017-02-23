-- Környezeti hőmérséklet és páratartalom mérés
-- AM2320 érzékelővel
local modname = ...
local M = {}
_G[modname] = M

local env = {}
local sclport=3 -- fekete
local sdaport=4 -- szürke

function M.init(sda, scl)
    local err
    sclport = scl or sclport
    sdaport = sda or sdaport
    gpio.mode(sclport, gpio.OUTPUT)
    gpio.write(sclport, gpio.HIGH)
    gpio.mode(sclport, gpio.OUTPUT)
    gpio.write(sdaport, gpio.HIGH)
   -- return am2320.init(sdaport, sclport)
    try( function() err = {am2320.init(sdaport, sclport)} end,
        function(e) err = {nil, "am2320.init "..e.."; SDA_port:"..sdaport.." SCL_port:"..sclport} end)
    return err
end   

function M.read()
    tempmeasure()
    return env
end

 
function tempmeasure()
    local rh, t
    -- az I2C homerot csak itt szabad kiolvasni
    -- ha nem kontrolláltan olvassuk ki, akkor transmission errora futhat és a node újrabootol
  try( function() env = {am2320.read()} end,
        function(e) env = {999, 999} end)
   --  print(string.format("RH: %s%%", env[1]/ 10))
  --  print(string.format("Temperature: %s degrees C", env[2] / 10))
  
        syslog(string.format("environment.lua - tempmeasure() - automode = %s; futes=%d; auto_T=%d; man_T=%d; mert_T=%d.%01d;  humidity=%d.%01d%%",
            tostring(automode), gpio.read(zona_pin), auto_T, man_T, env[2]/10, env[2]%10, env[1]/10, env[1]%10))
end

return M
