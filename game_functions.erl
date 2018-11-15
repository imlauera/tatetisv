-module(game_functions).
-compile(export_all).

observando(List) ->
	receive
		{add_obs,Partida} -> 
			observando(List++[Partida]);
		{del_obs,Partida} ->
			observando(List--[Partida]);
		{lista,Pid} -> 
			Pid ! {lista,List},observando(List)
	end.
retornar_obs() ->
	LNodes = [node() | nodes()],
	[ {obss,Node}!{lista,self()} || Node <- LNodes],
	[ receive {lista,Pid} -> Pid end || _Node1 <- LNodes].
jugadores_online(List) ->
	receive
		{jugadores,User} -> 
				    jugadores_online(List++[User]);
		{lista,Pid} -> Pid ! {lista,List},jugadores_online(List)
	end.
retornar_lista() ->
	LNodes = [node() | nodes()],
	[ {pidjugadoresonline,Node}!{lista,self()} || Node <- LNodes],
	[ receive {lista,Pid} -> Pid end || _Node1 <- LNodes].
juegos_disponibles(List) ->
	receive
		{disponibles,Pid} -> Pid ! {disponibles,List}, juegos_disponibles(List);
		{agregar,JUEGO} -> juegos_disponibles(List++[JUEGO]);
		{eliminar,JUEGO} -> 
			juegos_disponibles(List--[JUEGO++"\n"])
	end.
retornar_juegos() ->
	ListaDeNodos = [node() | nodes()],
	[ {pidjuegosdisponibles,Node} ! {disponibles,self()} || Node <- ListaDeNodos],	
	[ receive {disponibles,List} -> List end || _Node1 <- ListaDeNodos ].
jugando(List) ->
	receive
		{jugando,Pid} -> Pid ! {jugando,List}, jugando(List);
		{agregar_jugando,Jugadores} -> jugando(List++[Jugadores]);
		{quitar_jugando,Jugadores} -> jugando(List--[Jugadores])
	end.
retornar_jugando() ->
	% Tenes que pedirle a todos los nodos la informacion de quienes estan jugando
	ListaDeNodos = [node() | nodes()],
	[ {pidjugando,Node} ! {jugando,self()} || Node <- ListaDeNodos],	
	[ receive {jugando,List} -> List end || _Node1 <- ListaDeNodos ].
esperar(Tiempo) -> 
    receive
        after Tiempo*1000 -> ok
    end.
help() ->
	List = "con <user>\nnew <sala>\nacc <sala>\npla <sala> JUGADA\npla <sala> ABANDONAR\nobs <sala>\nlea <sala>\nwhoami\nlsg\nbye\nhelp\n",
	List.
funcion_de_pids(Lista) ->
	receive
		{pid,JUEGOSDM} -> funcion_de_pids(Lista++[JUEGOSDM]);
		{lista,Pid} -> Pid!{lista,Lista},funcion_de_pids(Lista)
	end.
retornar_pid() ->
	ListadeNodos = [node() | nodes()],
	[{funciondepids,Node} ! {lista,self()} || Node <- ListadeNodos],
	[ receive {lista,Lista} -> Lista end || _Node1 <- ListadeNodos ].
funcion_de_pids_juego(Lista) ->
	receive
		{pid_,JUEGOSDM} -> funcion_de_pids_juego(Lista++[JUEGOSDM]);
		{lista,Pid} -> Pid!{lista,Lista},funcion_de_pids_juego(Lista)
	end.
retornar_pid_juegos() ->
	ListadeNodos = [node() | nodes()],
	[{juegopids,Node} ! {lista,self()} || Node <- ListadeNodos],
	[ receive {lista,Lista} -> Lista end || _Node1 <- ListadeNodos ].
