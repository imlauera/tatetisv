-module(pbalance).
-compile(export_all).

nodos(AAA) ->
	KKK = lists:map(fun(X)->io:format("~p~n", [[J,_] = X]), []++[J] end , AAA),
	KKK.

%% Recibe la informacion de Pstat  y calcula cual nodo debe recibir los siguientes comandos.
pbalance(List) ->
	receive
		%% Lo guardo en una lista
		{lista,Pid} -> Pid ! {select,List}, pbalance(List);
		{pstat,Nodo,Reductions} ->
				%% Me quedo con los nodos nuevos, ninguno tiene que ser repetido, si es repetido
				%% es porque ya los nodos ejecutaron varias veces Pstat.
				io:format("Nodo:~p, Reductions: ~p List:~p~n",[Nodo,Reductions,List]),
				case lists:member([Nodo],nodos(List)) of
					true -> 
						Repetido = lists:filter(fun([K,_])->K==Nodo end, List), 
						R = List--Repetido,
						%io:format("Resultado final: ~p~n",[R++[[Nodo,Reductions]] ] ),
						pbalance(R++[[Nodo,Reductions]])
						;
					false -> pbalance(List++[[Nodo,Reductions]])
				end, pbalance(List)
		end.		

nodo_libre() ->
	Select = retornar_estadisticas(),
	[Node,_] = lists:nth(1,lists:sort(fun([KeyA,ValA], [KeyB,ValB]) -> [ValA,KeyA] =< [ValB,KeyB] end,Select)),
	io:format("Pbalance: lanzamos pcommand en el nodo: ~p~n",[Node]),
	Node.

retornar_estadisticas() ->
	pp_balance ! {lista,self()},
	receive
		{select,List} -> List
	end.
