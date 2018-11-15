-module(server).
-compile(export_all).

%% Para arrancar:
%% erl -sname peep, erl -sname linus
%% net_adm:ping('peep@host'), nodes() para comprobar los nodos conectados,
%% c(server), server:start(Port),
%% c(client) , client:start("127.0.0.1",Port) 

start(Port) -> 
	JUGADORES_ONLINE=spawn(game_functions,jugadores_online,[[]]),register(pidjugadoresonline,JUGADORES_ONLINE),
	JUEGOS_DISPONIBLES=spawn(game_functions,juegos_disponibles,[[]]),register(pidjuegosdisponibles,JUEGOS_DISPONIBLES),
	Ppid_Balance=spawn(pbalance,pbalance,[[[node(),0]]]),register(pp_balance,Ppid_Balance),
	%% Utilizada en su mayoria para enviar mensajes al usuario.
	RecibirPcomando=spawn(pcomando,recibirpcomando,[]),register(pidrecibirpcomando,RecibirPcomando),

	%% Guarda los pids de las nuevas partidas (se usa en NEW), para así poder
	%% aceptar esas partidas con el comando ACC, mandando una señal al pid de la partida correspondiente.
	FP=spawn(game_functions,funcion_de_pids,[[]]),register(funciondepids,FP),

	Admin=spawn(pcomando,administrator,[]),register(admin,Admin),
	U_A=spawn(pcomando,usuarioactual,[]),register(usuarioactual,U_A),
	OBSERV=spawn(game_functions,observando,[[]]),register(obss,OBSERV),
	Partidas_guardar=spawn(game_functions,funcion_de_pids_juego,[[]]),register(juegopids,Partidas_guardar),
	TATETI = spawn(game_functions,jugando,[[]]),register(pidjugando,TATETI),

	spawn(dispatcher,start,[Port]),
	spawn(pstat,pstat,[])

	.