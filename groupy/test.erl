-module(test).
-compile(export_all).


run(Module,Number)->
	case Number>0 of
		true->
			Leader = worker:start(1,Module,15,1000),
			create_slaves(Leader,Number-1,Module);
		false ->
			ok
	end.

create_slaves(Pid,Number_slaves,Module)->
	case Number_slaves=:=0 of
		true->
			ok;
		false->
			worker:start(Number_slaves+1,Module,10+Number_slaves,Pid,1000),
			create_slaves(Pid,Number_slaves-1,Module)
	end.