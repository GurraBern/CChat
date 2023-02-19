-module(server).
-export([start/1,stop/1]).





handler({Channels, NicksMap}, {join, Channel, Nick, From}) ->

    case lists:member(From, maps:keys(NicksMap)) of
        true -> 
            case lists:member(Channel, Channels) of
                false -> 
                    NewChannelsList = [Channel | Channels] ,%Borde lägga till en ny channel till ServerState, TODO check!
                    
                    genserver:start(list_to_atom(Channel), [From], fun channel_handler/2),
                    {reply, ok, {NewChannelsList, NicksMap}};

                true -> 
                    Response = catch genserver:request(list_to_atom(Channel), {join, From}),
                    case Response of
                        ok -> 
                            {reply, ok, {Channels, NicksMap}};
                        error ->
                            {reply, error, {Channels, NicksMap}};
                        {'EXIT', _} ->
                            {reply, {error, server_not_reached, "server not reached"}, {Channels, NicksMap}}
                    end
            end;
        false ->
            all()
    end;




handler({Channels, NicksMap}, {change_nick, NewNick, From})->


;


handler({Channels, NicksMap}, {stop_channels})->
   lists:foreach(fun(Channel) -> genserver:stop(list_to_atom(Channel)) end, Channels),
   {reply, ok, {Channels, NicksMap}}.


channel_handler(ChannelState, {join, From})->
    case lists:member(From, ChannelState) of
        true ->
            {reply, error, ChannelState};
        false ->
            {reply, ok, [From | ChannelState]}
    end;

channel_handler(ChannelState, {leave, From}) ->
    case lists:member(From, ChannelState) of
        true ->
            NewChannelState = lists:delete(From, ChannelState),%todo same here as above?
            %NewChannelState = ChannelState#channelState{channelName = ChannelState#channelState.channelName, pids = NewPidList},


            
            {reply, ok, NewChannelState};
        false ->
            {reply, error, ChannelState}
    end;

channel_handler(ChannelState, {message_send, Msg, Channel, From, Nick}) ->  
    io:fwrite("Pids in this channel: ~p~n", [ChannelState]),



    case lists:member(From, ChannelState) of
        true -> 
           spawn(
                fun() ->
                    [genserver:request(To, {message_receive, Channel, Nick, Msg}) || To <- ChannelState, To =/= From]
            end),
            {reply, ok, ChannelState};

        false ->
            {reply, error, ChannelState}
  end.

% Start a new server process with the given name
% Do not change the signature of this function.
start(ServerAtom) ->
    % TODO Implement function
    % - Spawn a new process which waits for a message, handles it, then loops infinitely
    %{List, [{Pid, nick}]}
    genserver:start(ServerAtom, {[],maps:new()}, fun handler/2).
    %gen_server:start(ServerAtom, printMsg()).
    % - Register this process to ServerAtom
    % - Return the process ID


% Stop the server process registered to the given name,
% together with any other associated processes
stop(ServerAtom) ->
    % TODO Implement function
    % Return ok
    genserver:request(ServerAtom, {stop_channels}),

    genserver:stop(ServerAtom),
    ok. %TODO Need to destroy all related processes
