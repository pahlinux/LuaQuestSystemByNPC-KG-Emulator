# LuaQuestSystemByNPC-KG-Emulator
Lua Quest System para KG-emulator Mu online
Quest System por Mapas con un mismo NPC.
Podes poner todas las quest que quieras, este sistema esta pensado para poner misiones por mapa
y misiones por unica vez tambien por mapa, estas ultimas son apilables, es decir q podes poner 10 pero se van mostrando de a una por ves.
Cuando terminas la primera te muestra la segunda y asi sucesivamente.
Las quest solo pueden realizarce de a una, asi tengas 20 en distintos mapas, siempre vas a poder hacer una y al terminarla
vas a poder hacer otra.

Antes de arrancar el GS o reiniciar lua descomentar al final del codigo QuestSystemByMaps.lua la linea dentro de:

function QuestSystem.Init()

-- [INSTALADOR] Ejecutamos el instalador de DB antes que nada
   
	--QuestSystem.CheckDatabase() --Descomentar ACA
	
Una vez ejecutado el lua, volver a comentar y recomiendo reiniciar el gs completo.
