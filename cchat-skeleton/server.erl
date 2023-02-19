-module(server).
-export([start/1,stop/1]).

handler({Channels, NicksMap}, {join, Channel, Nick, From}) ->
    case lists:member(From, maps:keys(NicksMap)) of
        true -> 
            handleJoin({Channels, NicksMap}, {join, Channel, From});
        false ->
            case lists:all(fun(NickToCompare) -> Nick =/= NickToCompare end, maps:values(NicksMap)) of
                false ->
                    {reply, nick_taken, "Nick is already taken"};
                true ->
                    NewNickMap = maps:put(From, Nick, NicksMap),
                    handleJoin({Channels, NewNickMap}, {join, Channel, From})
            end
    end;

handler({Channels, NicksMap}, {stop_channels})->
   lists:foreach(fun(Channel) -> genserver:stop(list_to_atom(Channel)) end, Channels),
   {reply, ok, {Channels, NicksMap}};

handler({Channels, NicksMap}, {change_nick, NewNick, From})->
    case lists:all(fun(NickToCompare) -> NewNick =/= NickToCompare end, maps:values(NicksMap)) of
        false ->
            {reply, nick_taken, "Nick is already taken"};
        true ->
            NewNickMap = maps:update(From, NewNick, NicksMap),
            {reply, ok, {Channels, NewNickMap}}
    end.

handleJoin({Channels, NicksMap}, {join, Channel, From}) ->
    case lists:member(Channel, Channels) of
        false -> 
            NewChannelsList = [Channel | Channels],
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
                    {reply, {error, server_not_reached, "Server not reached"}, {Channels, NicksMap}}
            end
    end.

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
            NewChannelState = lists:delete(From, ChannelState),
            {reply, ok, NewChannelState};
        false ->
            {reply, error, ChannelState}
    end;

channel_handler(ChannelState, {message_send, Msg, Channel, From, Nick}) ->  
    case lists:member(From, ChannelState) of
        true -> 
           spawn(
                fun() ->
                    [genserver:request(To, {message_receive, Channel, Nick, Msg}) || To <- ChannelState, To =/= From]
                end
            ),
            {reply, ok, ChannelState};
        false ->
            {reply, error, ChannelState}
  end.

% Start a new server process with the given name
% Do not change the signature of this function.
start(ServerAtom) ->
    genserver:start(ServerAtom, {[], #{}}, fun handler/2).

% Stop the server process registered to the given name,
% together with any other associated processes
stop(ServerAtom) ->
    genserver:request(ServerAtom, {stop_channels}),
    genserver:stop(ServerAtom),
    ok.