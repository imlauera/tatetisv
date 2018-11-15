-module(pstat).
-compile(export_all).

%% Mandar intervalos regulares la informacion de carga del nodo al resto.
pstat() -> spawn(fun() -> send(5) end).
send(Tiempo) ->
	receive
		after Tiempo*1000 -> 
			{_,Reductions1} = statistics(exact_reductions),
			NodeList = [node() | nodes() ],
			[ {pp_balance,NODOS} ! {pstat,node(),Reductions1} || NODOS <- NodeList ]
	end,
	send(5).
