-module(gms2).
-export([start/1, start/2]).
-define(timeout, 5000).
-define(arghh, 500).

start(Id) ->
	Rnd = random:uniform(1000),
	Self = self(),
	{ok, spawn_link(fun()-> init(Id, Rnd, Self) end)}.

init(Id, Rnd, Master) ->
	random:seed(Rnd, Rnd, Rnd),
	leader(Id, Master, [], [Master]).

start(Id, Grp) ->
	Rnd = random:uniform(1000),
	Self = self(),
	{ok, spawn_link(fun()-> init(Id, Rnd , Grp , Self) end)}.

init(Id, Rnd, Grp, Master) ->
	random:seed(Rnd, Rnd, Rnd),
	Self = self(),
	Grp ! {join, Master, Self},
	receive
		{view, [Leader|Slaves], Group} ->
			Master ! {view, Group},
			erlang:monitor(process, Leader),
			slave(Id, Master, Leader, Slaves, Group)
	end.

slave(Id, Master, Leader, Slaves, Group) ->
	receive
		{mcast, Msg} ->
			%io:format("gms ~w: received {mcast, ~w} in state ~w~n", [Id, Msg, N]),
			Leader ! {mcast, Msg},
			slave(Id, Master, Leader, Slaves, Group);
		{join, Wrk, Peer} ->
			%io:format("gms ~w: forward join from ~w to leader~n", [Id, Peer]),
			Leader ! {join, Wrk, Peer},
			slave(Id, Master, Leader, Slaves, Group);
		{msg, Msg} ->
			%io:format("gms ~w: deliver msg ~w in state ~w~n", [Id, Msg, N]),
			Master ! Msg,
			slave(Id, Master, Leader, Slaves, Group);
		{view, [Leader|Slaves2], Group2} ->
			%io:format("gms ~w: received view ~w ~w~n", [Id, N, View]),
			Master ! {view, Group2},
			slave(Id, Master, Leader, Slaves2, Group2);
		{'DOWN', _Ref , process , Leader , _Reason}->
			election(Id, Master, Slaves, Group);
		stop ->
			ok;
		Error ->
			io:format("gms ~w: slave, strange message ~w~n", [Id, Error])
	after ?timeout ->
		Master ! {error, "no reply from leader"}
	end.

leader(Id, Master, Slaves, Group) ->
	receive
		{mcast, Msg} ->
			%io:format("gms ~w: received {mcast, ~w} in state ~n", [Id, Msg]),
			bcast(Id, {msg, Msg}, Slaves),
			Master ! Msg,
			leader(Id, Master, Slaves, Group);
		{join, Wrk, Peer} ->
			%io:format("gms ~w: forward join from ~w to master~n", [Id, Peer]),
			Slaves2 = lists:append(Slaves, [Peer]),
			Group2 = lists:append(Group, [Wrk]),
			bcast(Id, {view, [self()|Slaves2], Group2}, Slaves2),
			Master ! {view, Group2},
			leader(Id, Master, Slaves2, Group2);
		stop ->
			ok;
		Error ->
			io:format("gms ~w: leader, strange message ~w~n", [Id, Error])
	end.

election(Id, Master, Slaves, [_|Group]) ->
	Self = self(),
	case Slaves of
		[Self|Rest] ->
			bcast(Id, {view, Slaves, Group}, Rest),
			Master ! {view, Group},
			leader(Id, Master, Rest, Group);
		[Leader|Rest] ->
			erlang:monitor(process, Leader),
			slave(Id, Master, Leader, Rest, Group)
	end.

% we send a message Msg to each of the processes in the list
bcast(Id, Msg, Nodes) ->
	lists:foreach(fun(Node) -> Node ! Msg, crash(Id) end, Nodes).
crash(Id) ->
	case random:uniform(?arghh) of
		?arghh ->
			io:format("leader ~w: crash~n", [Id]),
			exit(no_luck);
		_ ->
			ok
end.