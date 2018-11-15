-module(psocket).
-compile(export_all).
-import(pbalance, [nodo_libre/0]).

psocket(Sock) ->
	case gen_tcp:recv(Sock,0) of
		{ok,Data} ->
			Rec = spawn(pcomando,mensajes,[Sock]),
			spawn(nodo_libre(),pcomando,pcomando,[Sock,Data,Rec]),psocket(Sock);
		{error,closed} -> ok
	end.