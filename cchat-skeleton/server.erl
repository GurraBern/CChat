-module(server).
-export([start/1,stop/1]).

-record( 
    channels, {channelMap = []::channel}
).

-record(
   channel, {nicks = [], pid = []}
).


initial_state() ->
   % #serverState{}.
    #channels{channelMap = maps:new()}.



handler(Channels, {join, Channel, Nick, From}) ->
    case maps:find(Channel, Channels) of
        error -> 
            NewChannel = #channel{nicks = [Nick], pid = [From]},
            NewChannels = maps:put(Channel, NewChannel, Channels),


            %genserver:start(list_to_atom(Channel), NewChannels, fun channel_handler/2),

            From ! ok,
            %{reply, join, NewChannels};
            {reply, ok, NewChannels};
        {ok, _} -> 
            CurrentChannel = maps:get(Channel, Channels),
            NicksList = CurrentChannel#channel.nicks,
            PidList = CurrentChannel#channel.pid,

            %io:fwrite("Nick: ~n~p ", [Nick]),
            %io:fwrite("NicksLists: ~p~n ", [NicksList]),
            case lists:member(Nick, NicksList) of 
                true ->

                    %genserver:request(From, error),
                    From ! error,
                    {reply, error, Channels};

                false -> 
                    NewNicksList = lists:append(NicksList, [Nick]),
                    NewPidList = lists:append(PidList, [From]),
                    From ! ok,
                    NewChannel = #channel{nicks = NewNicksList, pid = NewPidList},
                    NewChannels = maps:update(Channel, NewChannel, Channels),
                    {reply, ok, NewChannels}
            end
    end;

    handler(Channels, {leave, Channel, Nick, From}) ->
        case maps:find(Channel, Channels) of
            error -> 
                From ! error,
                {reply, error, Channels};
            {ok, _} -> 
                CurrentChannel = maps:get(Channel, Channels),
                NicksList = CurrentChannel#channel.nicks,
                PidList = CurrentChannel#channel.pid,
                case lists:member(Nick, NicksList) of 
                    true ->
                        NewNicksList = lists:delete(Nick, NicksList),
                        NewPidList = lists:delete(From, PidList),
                        NewChannel = #channel{nicks = NewNicksList, pid = NewPidList},
                        NewChannels = maps:update(Channel, NewChannel, Channels),
                        From ! ok,
                        {reply, ok, NewChannels};
    
                    false -> 
                        From ! error,
                        {reply, error, Channels}
                end
        end;


 handler(Channels, {message_send, Msg, Channel, From}) ->
    case maps:find(Channel, Channels) of
        error -> 
            From ! error, % TODO does this do anything?
            {reply, error, Channels};
        {ok, _} -> 
            CurrentChannel = maps:get(Channel, Channels),
            NicksList = CurrentChannel#channel.nicks,
            PidList = CurrentChannel#channel.pid,

            %Ans= We need to use the Pid of the channel to send messages to, we should be able to kill a server and still send messages with help of that Pid
            spawn(
                fun() ->
                    [genserver:request(To, {message_receive, Channel, pid_to_list(To), Msg})|| To <- PidList]
                end),
            {reply, message_send, Channels}


            %case index_of(From, PidList) of
            %    not_found -> From ! error, {reply, error, Channels};
            %    Index -> ActiveNick = lists:nth((Index-1), NicksList),
            %    lists:map (fun (sendMessage({ActiveNick, Channel} PidList)))
            %end
    end.


sendMessage(Pid, MsgRequest, From) ->
    Pid ! MsgRequest,
    io:format("~p~n", [Pid]).

sendMessages(List, MsgRequest, From) ->
    lists:foreach(fun(E) -> sendMessage(E, MsgRequest, From) end, List).



% Start a new server process with the given name
% Do not change the signature of this function.
start(ServerAtom) ->
    % TODO Implement function
    % - Spawn a new process which waits for a message, handles it, then loops infinitely
    
    genserver:start(ServerAtom, maps:new(), fun handler/2).
    %gen_server:start(ServerAtom, printMsg()).
    % - Register this process to ServerAtom
    % - Return the process ID


% Stop the server process registered to the given name,
% together with any other associated processes
stop(ServerAtom) ->
    % TODO Implement function
    % Return ok
    genserver:stop(ServerAtom).
