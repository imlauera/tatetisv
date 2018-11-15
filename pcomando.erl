-module(pcomando).
-compile(export_all).
-import(game_functions,[retornar_lista/0,retornar_juegos/0,retornar_pid/0,retornar_pid_juegos/0,retornar_jugando/0,retornar_obs/0,esperar/1,help/0]).

primerelem(List) -> F = ( [ J || {J,_} <- List ] ),F.
segundoelem(List) -> S = ( [ J || {_,J} <- List ] ),S.
usuarioactual() ->
    receive
    	%% Identificando al usuario a traves del socket.
        {cual,Sock,Pid} ->
            %% Volvemos a actualizar la lista por si hay algún usuario nuevo registrado.
            Lista_de_verdad = lists:merge(retornar_lista()),
            Usuario = [User ||  User<-Lista_de_verdad,element(2,User) =:= Sock],
            io:format("Eres el usuario: ~p~n",[Usuario]),
            Pid!{cual,Usuario};

        %% Obteniendo el socket a traves del usuario.
        {cual2,Uss,Pid} ->
            Lista_de_verdad = lists:merge(retornar_lista()),
            io:format("lista de verdad: ~p~n",[Lista_de_verdad]),
            Usuario = [User ||  User<-Lista_de_verdad,element(1,User) =:= Uss],
            io:format("Oponente: ~p~n",[Usuario]),
            Pid!{cual,Usuario}

    end,
    usuarioactual().


devolver_usuario(Sock) ->
	usuarioactual ! {cual,Sock,self()},
	receive	{cual,User} -> primerelem(User) end.
devolver_sock(Usuario) ->
	usuarioactual ! {cual2,Usuario,self()},
	receive	{cual,User} -> lists:nth(1,segundoelem(User)) end.
mensajes(Sock) ->
	receive
		{enviar,Msg} -> 
			gen_tcp:send(Sock,Msg)
	end,mensajes(Sock).


%% Esta es la funcion que me permite inicializar partidas.
administrator() ->
	receive
		%% Creo una nueva partida.
		{new,JUEGO,User,Pid} ->
			Nuevo = spawn(?MODULE,nueva_partida,[JUEGO,User]),
			Pid ! {partida,Nuevo}

	end,administrator().




ultimo_elemento([]) -> vacio;
ultimo_elemento( [ H | [] ]) -> H;
ultimo_elemento( [_|T]) -> ultimo_elemento(T).


armar_tabla(JUGADA,K) ->
		if
			JUGADA == "A\n" ->  
				[K,[],[],[],[],[],[],[],[]];
			JUGADA == "B\n" ->  
				[[],K,[],[],[],[],[],[],[]];
			JUGADA == "C\n" -> 
				[[],[],K,[],[],[],[],[],[]];
			JUGADA == "D\n" ->  
				[[],[],[],K,[],[],[],[],[]];
			JUGADA == "E\n" ->  
				[[],[],[],[],K,[],[],[],[]];
			JUGADA == "F\n" ->  
				[[],[],[],[],[],K,[],[],[]];
			JUGADA == "G\n" ->  
				[[],[],[],[],[],[],K,[],[]];
			JUGADA == "H\n" ->  
				[[],[],[],[],[],[],[],K,[]];
			JUGADA == "I\n" ->  
				[[],[],[],[],[],[],[],[],K]
		end.


%% Arreglamos la longitud de la tabla para poder concatenarla.
fix(List,C) ->
	if 
		C == 0 -> List;
		C >  0 -> fix(List++[ [[],[],[],[],[],[],[],[],[]] ],C-1)
	end.

estado([A1, A2, A3, B1, B2, B3, C1, C2, C3]) ->
	Filas =	[[A1, A2, A3], [B1, B2, B3], [C1, C2, C3]],
	Columnas =	[[A1, B1, C1], [A2, B2, C2], [A3, B3, C3]],
	Diagonales = [[A1, B2, C3], [A3, B2, C1]],
	ganador(Filas++Columnas++Diagonales).

ganador([]) -> nod;
%% El caso de listas vacias
ganador(   [  [[], [], []] | T]  ) ->  ganador(T);
ganador(   [  [X, X, X] | _]  ) ->  X;
ganador([_ | T]) -> ganador(T).

resultado_juego(Juego) ->
	case estado(Juego) of
		nod ->
			Terminado = lists:all(fun(X) -> (X =:= "x") or (X =:= "o") end, Juego),
			case Terminado of 
				true -> empate;
				false -> continue
			end;
		X -> X
	end.

nueva_partida(JUEGO,Usuario) ->
	receive

		{aceptar,JUEGO,Oponente} ->
			JUGADORES = lists:append(Usuario,Oponente),
			List_Sock = [ devolver_sock(U) || U <- JUGADORES ], 
			NodeList = [node() | nodes()],

			%% Aca me equivoque cuando empece a limpiar el codigo
			%[ lists:foreach(fun(N) -> {pidrecibirpcomando,NODOS} ! {pcomando,"Tu oponente es "++[Oponente]++"\n"++"Podes jugar con el comando PLA\n",N} end,List_Sock) || NODOS <- NodeList],
			
			[ {pidrecibirpcomando,NODES} ! {pcomando,"Estas jugando con "++[Oponente]++"\n"++"Ahora podes jugar con el comando PLA\n",lists:nth(1,List_Sock)} || NODES <- NodeList],
			[ {pidrecibirpcomando,NODES} ! {pcomando,"Estas jugando con "++[Usuario]++"\n"++"Ahora podes jugar con el comando PLA\n",lists:nth(2,List_Sock)} || NODES <- NodeList],


			%%% Creo la partida.
			Jugar = spawn(?MODULE,espero_guardo,[[],JUEGO,Usuario,Oponente]),
			%%% Guardo el pid con la funcion funcion_de_pids_juego.
			juegopids ! {pid_,Jugar},
			%%% Agrego a la lista de jugando a los dos.
			pidjugando ! {agregar_jugando,{Usuario,Oponente,JUEGO}}
	end.


%% Une varias listas.
con(JF,1) ->
        lists:nth(1,JF);
con(JF,N) ->
        lists:zipwith(fun(X,Y) -> X++Y end, lists:nth(N,JF),(con(JF,N-1))).


print(Format,7) -> 
	"\t"++lists:sublist(Format,7,3)++"\n";
print(Format,N) ->
	"\t"++lists:sublist(Format,N,3)++"\n"++print(Format,N+3).


%% Mantengo una lista local por cada partida.
espero_guardo(List,PARTIDA,Usuario,Oponente) ->
	receive
		{jugar,PARTIDA,User,Jugada,CmdId} ->
				NodeList = [node() | nodes()],

				Sock = devolver_sock(lists:merge(User)),
				JUGADA = lists:append(User,lists:append([Jugada],[PARTIDA])),

	           	OPCION = lists:nth(2,JUGADA),

	           	PERMITIDOS = ["A\n","B\n","C\n","D\n","E\n","F\n","G\n","H\n","I\n","ABANDONAR\n"],
	           	%%% Los paso por una lista, si alguno acierta entonces pasa la validacion de la jugada.
	           	VALIDACION = [ Elem || Elem<-PERMITIDOS,Elem =:= OPCION],
	           	if 
	           		VALIDACION == [] ->

	           			[ {pidrecibirpcomando,NODOS} ! {pcomando,"Jugada no permitida.\nERROR "++[CmdId]++"\n",Sock} || NODOS <- NodeList],
	           			%%% Si la jugada no es admitida vuelvo a llamar a la funcion para así esperar nuevas jugadas
	           			%%% y descartar la actual jugada.
	           			espero_guardo(List,PARTIDA,Usuario,Oponente);


	           		VALIDACION == ["ABANDONAR\n"] -> 
	           			%%% Tengo que borrar la partida
	           			JUGADORES = lists:append(Usuario,Oponente),
						List_Sock = [ devolver_sock(U) || U <- JUGADORES ], 
	           			[ {pidjuegosdisponibles,NODOS} ! {eliminar,PARTIDA--"\n"} || NODOS <- NodeList ],

						[ lists:foreach(fun(N) -> {pidrecibirpcomando,NODOS} ! {pcomando,"El usuario "++devolver_usuario(Sock)++" ha abandonado la partida: "++[PARTIDA--"\n"]++"\n",N} end,List_Sock) || NODOS <- NodeList],


	           			exit(self(),normal);


	    			true ->
	    				%%% Saco de la lista de jugadas solo las jugadas pertenecientes a la partida actual
	    				%%% Lista_UJ se refiere a una lista con la ultima jugada hecha

	    				%% creo que viene con un salto de linea la partida, verificarlo! see

	    				%%% No hace falta filtrarlo por partida.
				       	%Lista_UJ = lists:filter(fun([_,_,J]) -> J == lists:nth(3,JUGADA) end, List),
				       	Lista_UJ = List,
				       	%%% Lo mismo que la anterior, solo que agregando la última jugada hecha por el actual usuario
			       		%Lista_objetivo = lists:filter(fun([_,_,J]) -> J == lists:nth(3,JUGADA) end, List++[JUGADA]),
			       		Lista_objetivo = List++[JUGADA],

			       		%%% Saco simplemente el ultimo elemento de lista que contiene todas las jugadas excepto la ultima
			       		Ultima_jugada = ultimo_elemento(Lista_UJ),

				    	if 
					    	Ultima_jugada /= vacio ->
					    		%%% Defino quien fue el ultimo usuario que jugo, y quien es el que esta enviando el comando.
				    			Usuario_anterior = lists:nth(1,Ultima_jugada),
								Usuario_actual = lists:nth(1,JUGADA),

								if
									%%% Obviamente si el usuario anterior es igual al actual entonces no puede jugar, salvo que la
									%%% jugada sea abandonar la sala
									Usuario_actual == Usuario_anterior -> 
										%%% Envio un mensaje de error al que me envio el comando y me vuelvo a llamar para
										%%% seguir esperando nuevas consultas.
										[ {pidrecibirpcomando,NODOS} ! {pcomando,"No es tu turno!\nERROR "++[CmdId]++"\n",Sock} || NODOS <- NodeList],
										espero_guardo(List,PARTIDA,Usuario,Oponente)
									;

									Usuario_actual /= Usuario_anterior -> 
										%%% Filtro todas las jugadas de cada usuario desde la Lista objetivo que tenia
										%%% todas las jugadas que coincidian con la partida.
										JAn_Lista = lists:filter(fun([K,_,_])->K==Usuario_anterior end, Lista_objetivo), 
										JAc_Lista = lists:filter(fun([K,_,_])->K==Usuario_actual end, Lista_objetivo),

										%%% Solo quiero las jugadas hechas por cada usuario
										%%% Ejemplo, Usuario = [A,B,C,D]
										JugadasUser1 = [ F || [_,F,_]=_E<-JAc_Lista ],
										JugadasUser2 = [ F || [_,F,_]=_E<-JAn_Lista ],

										%%% Comprobamos si otro ya habia jugado esa posicion.
										Total = lists:append(JugadasUser1,JugadasUser2),
										Compr = lists:any(fun(X) -> (X =:= lists:nth(2,JUGADA)) end, Total--[lists:nth(2,JUGADA)] ),
										case Compr of
											true ->    
												[ {pidrecibirpcomando,NODOS} ! {pcomando,"No podes hacer esa jugada!\nERROR "++[CmdId]++"\n",Sock} || NODOS <- NodeList],
												espero_guardo(List,PARTIDA,Usuario,Oponente)
											;
											false -> 
												ok
										end,

										U1 = lists:flatlength(JugadasUser1),
										U2 = lists:flatlength(JugadasUser2),

										%%% Truco para mostrar bien las o y x, para nada elegante.
										if 
											U1 > U2 ->
												Jugadas_1 = lists:map(fun(N)-> armar_tabla(N,"x") end ,JugadasUser1),
												Jugadas_2 = lists:map(fun(N)-> armar_tabla(N,"o") end ,JugadasUser2);
											true ->
												Jugadas_1 = lists:map(fun(N)-> armar_tabla(N,"o") end ,JugadasUser1),
												Jugadas_2 = lists:map(fun(N)-> armar_tabla(N,"x") end ,JugadasUser2)
										end,

										%%% Cuanto la longitud para despues poder agregar el tamaño y asi poder concatenarlas.
										%%% creo que hay mejores opciones que hacer esto, pero esta es la primera que se me ocurrio
										C = lists:flatlength(Jugadas_1),
										Z = lists:flatlength(Jugadas_2),

										Jugadas_final = fix(Jugadas_1,9-C),
										Jugadas_final2 = fix(Jugadas_2,9-Z),

										Usuario_dos = con(Jugadas_final2,9),
										Usuario_uno = con(Jugadas_final,9),

										%%% Concateno las dos tablas de jugadas de cada usuario en una sola tabla.
										CONCATENACION_FINAL = lists:zipwith(fun(X,Y)->X++Y end, Usuario_uno,Usuario_dos),

										Format = [ if N == [] -> "_"; true-> N end ||  N <- CONCATENACION_FINAL ],

										SockOponente = devolver_sock(Usuario_anterior),

										%%% Mando la tabla completa con las jugadas.
										Msg = print(Format,1),
										List_Sock = lists:merge([Sock],[SockOponente]),
										[ lists:foreach(fun(N) -> {pidrecibirpcomando,NODOS} ! {pcomando,Msg,N} end,List_Sock) || NODOS <- NodeList],
										%%% Respondo enviando un UPD
										[ {pidrecibirpcomando,NODOS} ! {pcomando,"UPD "++[CmdId]++" "++[PARTIDA--"\n"]++" "++[Jugada]++"\n",SockOponente} || NODOS <- NodeList],

										%% Aca actualizo a todos los observadores del juego.
										case resultado_juego(CONCATENACION_FINAL) of
											empate ->
												[ lists:foreach(fun(N) -> {pidrecibirpcomando,NODOS} ! {pcomando,"Empate.\nPartida finalizada\n",N} end,List_Sock) || NODOS <- NodeList], 
												%%% Se termino la jugada entonces la eliminamos
												[ {pidjuegosdisponibles,NODOS} ! {eliminar,PARTIDA--"\n"} || NODOS <- NodeList ],
												exit(self(),normal)
											;
											continue -> 
												[ {pidrecibirpcomando,NODOS} ! {pcomando,"Todavia no hay ganador.\n",Sock} || NODOS <- NodeList],
												spawn(?MODULE,obs,[Format,CmdId,PARTIDA,Jugada,[]]),
												%%% Me vuelvo a llamar para que pueda seguir jugando.
												espero_guardo(List++[JUGADA],PARTIDA,Usuario,Oponente);
											_Resultado -> 
												%%% Mando el ganador a los dos oponentes y a los observadores.
												[ lists:foreach(fun(N) -> {pidrecibirpcomando,NODOS} ! {pcomando,"El ganador es: "++devolver_usuario(Sock)++"\n",N} end,List_Sock) || NODOS <- NodeList], 
												spawn(?MODULE,obs,[Format,CmdId,PARTIDA,Jugada,devolver_usuario(Sock)]),

												%%% Borro la partida
												[ {pidjuegosdisponibles,NODOS} ! {eliminar,PARTIDA--"\n"} || NODOS <- NodeList ],

												exit(self(),normal)
											end
									
								end;
								%%% Si la ultima jugada es nula es porque todavia nadie ha jugado.
								Ultima_jugada == vacio ->
									%%% Lo que hago aca es generar una tabla con un x en la ubicacion correspondiente
									Jugadas_1 = armar_tabla(Jugada,"x"),
									%%% Esto es solo para mostrar mejor la matriz
									Format = [ if N == [] -> "_"; true-> N end ||  N <- Jugadas_1 ],

									Usuario_usando = lists:merge(User),
									Opo_=lists:merge(Oponente),

									%%% Saco el oponente, de seguro hay alguna forma mas elegante de hacerlo.
									if 
										Usuario_usando == Opo_ ->
											Opo = lists:merge(Usuario)
										;
										Usuario_usando /= Opo_ ->
											Opo = Opo_
									end,
									%io:format("el oponente soy yo: ~p~n",[Opo]),
									SockOponente = devolver_sock(Opo),
									List_Sock = lists:merge([Sock],[SockOponente]),

									%% Mando la tabla con las jugadas a mi oponente y a los observadores.
									Msg = print(Format,1),
									[ lists:foreach(fun(N) -> {pidrecibirpcomando,NODOS} ! {pcomando,Msg,N} end,List_Sock) || NODOS <- NodeList],
									spawn(?MODULE,obs,[Format,CmdId,PARTIDA,Jugada,[]]),
									[ {pidrecibirpcomando,NODOS} ! {pcomando,"UPD "++[CmdId]++" "++[PARTIDA--"\n"]++" "++[Jugada]++"\n",SockOponente} || NODOS <- NodeList],
									espero_guardo(List++[JUGADA],PARTIDA,Usuario,Oponente)
						end

			end

	end.



obs(Format,CmdId,PARTIDA,Jugada,Ganador) -> 
	NodeList = [node() | nodes()],
	%% Retorno la lista de sockets que posee la partida que etsan observando y el usuario.
	Observadores = retornar_obs(),
	io:format("dbg> observadores: ~p~n",[Observadores]),
	%% La lista posee usuario y el socket, ahora yo quiero una lista solo con los sockets de cada usuario.
	%% obs = {partida,usuario}
	Obs_P = lists:filter(fun({P,_})->P++"\n"==PARTIDA end, lists:merge(Observadores)),
	List_Sock = [ devolver_sock(U) || {_,[U]} = _Usuario <- Obs_P ],
	%%% Mando la partida y el mensaje de UPD, creo que solo deberia enviar UPD y el cliente luego interpretar eso,
	%%% pero se pude entender de las dos maneras, creo.
	Msg = print(Format,1),
	[ lists:foreach(fun(N) -> {pidrecibirpcomando,NODES} ! {pcomando,Msg,N} end ,List_Sock) || NODES <- NodeList],
	[ lists:foreach(fun(N) -> {pidrecibirpcomando,NODOS} ! {pcomando,"UPD "++[CmdId]++" "++[PARTIDA--"\n"]++" "++[Jugada]++"\n",N} end,List_Sock) || NODOS <- NodeList],
	%%% En cada llamado que se hace a obs se pasa una lista llamada Ganador, aca verificamos si esa lista contiene al ganador.
	if 
		Ganador == [] ->
			ok;
		Ganador /= [] -> 
			[ lists:foreach(fun(N) -> {pidrecibirpcomando,NODOS} ! {pcomando,"El ganador es: "++[Ganador]++"\n",N} end,List_Sock) || NODOS <- NodeList],
			%% Borramos a todos los observadores de la partida, ya que la partida termino.
			[ lists:foreach(fun(N) -> {obss,NODOS} ! {del_obs,{PARTIDA--"\n",devolver_usuario(N)}} end,List_Sock) || NODOS <- NodeList]

	end.


recibirpcomando() ->
	receive
		%% Para enviar los mensajes al cliente.
		{pcomando,Data,Sock} -> 
			gen_tcp:send(Sock,Data),recibirpcomando();
		{bomber,Lista_Juegos,PARTIDA,User} -> 
			[TodosLosPids ! {aceptar,PARTIDA,User} || TodosLosPids <- Lista_Juegos],recibirpcomando();

		%% Parecido al primero, solo que usado para entrar a jugar, usado en PLA.
		{bomber2,Lista_Partidas,PARTIDA,User,JUGADA,CmdId} -> 
			[TodosLosPids ! {jugar,PARTIDA,User,JUGADA,CmdId} || TodosLosPids <- Lista_Partidas],recibirpcomando()

	end.
pcomando(Sock,Data,From) ->
	NodeList = [node() | nodes() ],
	%%% Identificamos el comando y los argumentos, separandolos los argumentos por espacio.
	case string:tokens(Data," ") of
		["con",CmdId,User] -> 
		First = devolver_usuario(Sock),
			if 
				First /= [] ->
					From ! {enviar,"Ya estas registrado!\n"++"ERROR "++[CmdId]++"\n"};
				First == [] ->
					Lista = retornar_lista(),
					Lista_de_verdad=lists:merge(Lista),
					case lists:member(User,primerelem(Lista_de_verdad)) of
						false ->
							%%% No solo vamos a guardar el usuario sino también el socket con el que se ha conectado.
							pidjugadoresonline!{jugadores,{User,Sock}},
							From ! {enviar,"Te registraste como "++[User]++"\n"++"OK "++[CmdId]++"\n"}
						;

						true -> 
							From ! {enviar,"El nombre que has elegido ha sido usado.\n"++"ERROR "++[CmdId]++"\n"}
					end
				end

				;


		["lsg",CmdId] -> 
			First = devolver_usuario(Sock),
			if 
				First /= [] ->
					%%% Recupera la lista de juegos de todos los nodos y se lo manda al cliente.
					RJuegos = retornar_juegos(),
					From ! {enviar,RJuegos++"OK "++[CmdId]};
				First == [] ->
					From ! {enviar,"No estas registrado!.\n"++"ERROR "++[CmdId]++"\n"}
			end
			;

		["new",CmdId,PARTIDA] ->
			First = devolver_usuario(Sock),
			if 
				First /= [] -> 
					%%% Agregamos el juego a la lista
					pidjuegosdisponibles ! {agregar,PARTIDA} ,
					admin ! {new,PARTIDA,devolver_usuario(Sock),self()},
					receive
						{partida,Nuevo} -> 
							funciondepids ! {pid,Nuevo}
					end,
					From ! {enviar,"OK "++[CmdId]++"\n"};

				First == [] ->
					From ! {enviar,"No estas registrado!.\n"++"ERROR "++[CmdId]++"\n"}			
			end
			;

		["acc",CmdId,PARTIDA] ->
			First = devolver_usuario(Sock),
			if 
				First /= [] -> 
					RJuegos = lists:merge(retornar_juegos()),
					case lists:member(PARTIDA,RJuegos) of
		 				true ->
							AA = retornar_pid(),
							AAA = lists:merge(AA),
							io:format("retornar pid: ~p~n",[AAA]),
							%%% Todos los nodos mandan señal a todos los pids de las "nuevas partidas" existentes en todo el sv, no es muy eficiente.
							[ {pidrecibirpcomando,NODOS} ! {bomber,AAA,PARTIDA,devolver_usuario(Sock)} || NODOS <- NodeList],
							From ! {enviar,"OK "++[CmdId]++"\n"};
						false ->
							From ! {enviar,"Esa partida no existe!\n"++"ERROR "++[CmdId]++"\n"}
						end;
				First == [] ->
					From ! {enviar,"No estas registrado!.\n"++"ERROR "++[CmdId]++"\n"}	
			end
			;  
		["whoami",CmdId] -> 
			Usuario = devolver_usuario(Sock),
			if 
				Usuario == [] ->
					From ! {enviar,"Todavia no te registraste\nERROR "++[CmdId]++"\n"};
				Usuario /= [] ->
					From ! {enviar,Usuario++"\n"++"OK "++[CmdId]++"\n"}
			end

			;

		["\n"] -> ok;


		["pla",CmdId,PARTIDA,Jugada] ->
			First = devolver_usuario(Sock),
			if 
				First /= [] -> 
		 			RJuegos = lists:merge(retornar_juegos()),

		 			case lists:member(PARTIDA++"\n",RJuegos) of
		 				true ->
		 					AA = lists:merge(retornar_pid_juegos()),
		 					%%% Manda señal a todos los pids de partida el que machea con el nombre entra.
							pidrecibirpcomando ! {bomber2,AA,PARTIDA++"\n",devolver_usuario(Sock),Jugada,CmdId},
							From ! {enviar,"OK "++[CmdId]++"\n"}
						;
						false -> 
							From ! {enviar,"Esa partida no existe!\n"++"ERROR "++[CmdId]++"\n"}
					end
					;
				First == [] -> 
					From ! {enviar,"No estas registrado!.\n"++"ERROR "++[CmdId]++"\n"}
			end

		;
		
		["obs",CmdId,PARTIDA] -> 
			First = devolver_usuario(Sock),
			if 
				First /= [] ->  
					%% Lo agrego a la lista de observadores.
					%% Agregamos la partida que queremos observar y el usuario que manda el comando.
					RJuegos = lists:merge(retornar_juegos()),

		 			case lists:member(PARTIDA++"\n",RJuegos) of
		 				true ->
							obss ! {add_obs,{PARTIDA,devolver_usuario(Sock)}} ,
							From ! {enviar,"OK "++[CmdId]++"\n"};
						false ->
							From ! {enviar,"No podes observar una partida que no existe!\n"++"ERROR "++[CmdId]++"\n"}
					end;

				First == [] -> 
					From ! {enviar,"No estas registrado!.\n"++"ERROR "++[CmdId]++"\n"}
			end

		;
	
 		["lea",CmdId,PARTIDA] -> 
			First = devolver_usuario(Sock),
			if 
				First /= [] ->  
		 			%%%% Simplemente saca al usuario de la lista de "broadcast"
		 			[ {obss,NODOS} ! {del_obs,{PARTIDA,devolver_usuario(Sock)}} || NODOS <- NodeList],
					From ! {enviar,"Se ha dejado de observar la partida.\n"++"OK "++[CmdId]++"\n"};

				First == [] -> 
					From ! {enviar,"No estas registrado!.\n"++"ERROR "++[CmdId]++"\n"}
			end
 		;

		["help",CmdId] -> 
			From ! {enviar,help()++"OK "++[CmdId]++"\n"}
		
		;

		["bye",CmdId] -> 
			First = devolver_usuario(Sock),
			if 
				First /= [] -> 

					%%% Recupera la lista de todas las partidas que hay en TODO el sv.
					YO_ESTOY = retornar_jugando(),
					%%% Recupera la lista de pids de todos los juegos existentes en todo el sv, no es eficiente.
				 	AA = lists:merge(retornar_pid_juegos()),

				 	%%% Recupera filtro de TOODAS las jugadas que hay en el servidor, solo las que yo participo, no es eficiente.
					Bye = lists:filter(fun({U,O,_})-> (U==devolver_usuario(Sock)) or (O==devolver_usuario(Sock))   end, lists:merge(YO_ESTOY)),

					%%% Una lista con todas las partidas que participo.
					io:format("Bye: ~p~n",[Bye]),
					NombresPartidas = [ P || {_,_,P} = _Usuario <- Bye ],

					io:format("Nombre de partidas: ~p~n",[NombresPartidas]),
					%%% Mando a todas las partidas que juega el usuario la jugada "ABANDONAR"
					lists:foreach(fun(N) -> pidrecibirpcomando ! {bomber2,AA,N,devolver_usuario(Sock),"ABANDONAR\n",CmdId} end,NombresPartidas),

					From ! {enviar,"OK "++[CmdId]++"\n"},
					esperar(1),
					exit(normal);


				First == [] -> 
					From ! {enviar,"No estas registrado!.\n"++"ERROR "++[CmdId]++"\n"}
			end
		;

		_ ->  From ! {enviar,"Comando no valido!\n"}

 		end.
