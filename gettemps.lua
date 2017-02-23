t=require("ds18b20")
t.setup(ow_port)
local temp = {0,0,0,0}
sensors=t.addrs()
-- Total DS18B20 numbers, assume it is 2
local sensornum = table.getn(sensors)
if sensornum ~= 4 then
    print("ERROR - Sensors found: ",sensornum)
end
if sensornum ~= nil and sensornum ~=0 then -- ha talált sensort, akkor kiolvassa
    for tn= 1, sensornum do
        temp[tn] = t.readNumber(sensors[tn],t.C)
       -- print(bs2hex(sensors[tn]))
        tmr.delay(100)
    end
end
ds18b20 = nil
package.loaded["ds18b20"]=nil
--print(temp[1], temp[2])
return temp
