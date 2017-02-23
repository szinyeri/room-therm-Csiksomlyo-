dofile("globals.lc")
dofile("futes_proc.lc")
dofile("futes.lc")
--dofile("tartalyszint.lc")
 print("Wait 5 sec for WiFi connection")
tmr.alarm(0, 5*1000, tmr.ALARM_SINGLE,  OntInit) -- 5 másodpercet várunk WiFi csatlakozásra
