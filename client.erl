-module(client).
-compile(export_all).


receive_data(Socket) ->
    case gen_tcp:recv(Socket,0) of 
       {ok,Data} -> 
            Output = binary_to_list(Data),
            io:format("~s",[Output]);
        {error,closed} -> ok
    end,receive_data(Socket).



send(Id,Socket) ->
    Com = io:get_line("%% "), 
    Command = lists:sublist(Com,1,lists:flatlength(Com)-1),
    %io:format("Este es el comando a enviar: ~p~n",[Command]),
    case string:tokens(Command," ") of
        ["con",User] ->  gen_tcp:send(Socket, "con "++integer_to_list(Id)++" "++User);
        ["lsg"] -> gen_tcp:send(Socket, "lsg "++integer_to_list(Id)++"\n");
        ["new",Partida] -> gen_tcp:send(Socket, "new "++integer_to_list(Id)++" "++Partida++"\n");
        ["acc",Partida] -> gen_tcp:send(Socket, "acc "++integer_to_list(Id)++" "++Partida++"\n");
        ["pla",Partida,Jugada] -> gen_tcp:send(Socket, "pla "++integer_to_list(Id)++" "++Partida++" "++Jugada++"\n");
        ["obs",Partida] -> gen_tcp:send(Socket, "obs "++integer_to_list(Id)++" "++Partida);
        ["lea",Partida] -> gen_tcp:send(Socket, "lea "++integer_to_list(Id)++" "++Partida);
        ["whoami"] -> gen_tcp:send(Socket, "whoami "++integer_to_list(Id));
        ["help"] ->  gen_tcp:send(Socket, Command++" "++integer_to_list(Id));
        ["bye"] -> gen_tcp:send(Socket, Command++" "++integer_to_list(Id));
        _ -> gen_tcp:send(Socket, Command)
    end,
    send(Id+1,Socket).


start(Host,Port) ->
    io:format("SuperTateti 0.1~n"),
    io:format("Tablero: ~n"),
    io:format(" A|B|C~n D|E|F~n G|H|I~n~n"),
    io:format("Te podes registrar usando el comando: con nombre~n"),
    {ok, Socket} = gen_tcp:connect(Host, Port, [binary, {active, false}]),
    spawn(?MODULE,receive_data,[Socket]),
    send(0,Socket).