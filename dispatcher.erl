-module(dispatcher).
-compile(export_all).

%% Abro un puerto a la escucha de un cliente.
start(Port) ->
	{ok,DSock}=gen_tcp:listen(Port,[{active,false}]),
	loop(DSock).

%% Creo un nuevo hilo psocket por cada cliente nuevo.
loop(DSock) ->
	{ok,Sock} = gen_tcp:accept(DSock),
	spawn(psocket, psocket,[Sock]), 
	loop(DSock).
