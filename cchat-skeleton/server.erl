-module(server).
-export([start/1,stop/1]).

-record(serverState, {
    createdChannels = [],
    nicks = []
    }  
).

-record(channelState, {
    channelName,
    pids = []
    %pids = []::user,
    %users=maps:new()  %pidKey, nickValue
    }  
).

%TODO fix unique user names on channels
initial_state() ->
    #serverState{createdChannels = []}.


handler(ServerState, {join, Channel, Nick, From}) ->

    UpdatedNicks = case lists:member(Nick, ServerState#serverState.nicks) of
        true ->
            ServerState#serverState.nicks;
        false ->
             [Nick | ServerState#serverState.nicks]
    end,

    case lists:member(Channel, ServerState#serverState.createdChannels) of
        false -> 
            NewChannel = #channelState{channelName = Channel, pids = [From]},


            NewServerState = ServerState#serverState{createdChannels = [ServerState#serverState.createdChannels ++ Channel], nicks = UpdatedNicks},%Borde lägga till en ny channel till ServerState, TODO check!
            genserver:start(list_to_atom(Channel), NewChannel, fun channel_handler/2),
            {reply, ok, NewServerState};

        true -> 
            Response = genserver:request(list_to_atom(Channel), {join, From}),

            case Response of
                join ->


                    %dostuff
                    {reply, ok, ServerState};
                error ->
                    {reply, user_already_joined, ServerState}
                
            end
    end;

handler(ServerState, stop_channels)->
   lists:foreach(fun(Channel) -> genserver:stop(list_to_atom(Channel)) end, ServerState#serverState.createdChannels),
   {reply, ok, ServerState}.


channel_handler(ChannelState, {join, From})->
    case lists:member(From, ChannelState#channelState.pids) of
        true ->
            {reply, error, ChannelState};
        false ->
            NewChannelState = ChannelState#channelState{channelName = ChannelState#channelState.channelName, pids = [From | ChannelState#channelState.pids]},
            {reply, join, NewChannelState}
    end;

channel_handler(ChannelState, {leave, From}) ->
    case lists:member(From, ChannelState#channelState.pids) of
        true ->
            NewPidList = lists:delete(From, ChannelState#channelState.pids),%todo same here as above?

            NewChannelState = ChannelState#channelState{channelName = ChannelState#channelState.channelName, pids = NewPidList},
            {reply, leave, NewChannelState};
        false ->
            {reply, error, ChannelState}
    end;

channel_handler(ChannelState, {message_send, Msg, Channel, From, Nick}) ->  

    Others = lists:delete(From, ChannelState#channelState.pids),
    %io:fwrite("Pids = ~p~n", [Others]),
   lists:foreach((fun(To) -> genserver:request(To, {message_receive, Channel, Nick, Msg}) end), Others),
   {reply, ok, ChannelState}.


    %spawn(
      %  fun() ->
     %       [genserver:request(To, {message_receive, Channel, Nick, Msg}) || To <- ChannelState#channelState.pids, To =/= From]
    %%    end),
    %{reply, ok, ChannelState}.


    %Ismember = lists:member(From, ChannelState#channelState.pids),
    % case Ismember of
    %     true->
     %        spawn(
      %           fun() ->
         %            [genserver:request(To, {message_receive, Channel, Nick, Msg}) || To <- ChannelState#channelState.pids, To =/= From]
      %           end),
         %    {reply, message_send, ChannelState};
 %
        % false->
         %    {reply, error, ChannelState}

     %end.

  



% Start a new server process with the given name
% Do not change the signature of this function.
start(ServerAtom) ->
    % TODO Implement function
    % - Spawn a new process which waits for a message, handles it, then loops infinitely
    
    genserver:start(ServerAtom, initial_state(), fun handler/2).
    %gen_server:start(ServerAtom, printMsg()).
    % - Register this process to ServerAtom
    % - Return the process ID


% Stop the server process registered to the given name,
% together with any other associated processes
stop(ServerAtom) ->
    % TODO Implement function
    % Return ok
    genserver:request(ServerAtom, stop_channels),

    genserver:stop(ServerAtom). %TODO Need to destroy all related processes
