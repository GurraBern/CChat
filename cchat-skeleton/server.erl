-module(server).
-export([start/1,stop/1]).



%Checks if the pid of client trying to join channel is already registered to any channel otherwise
%it checks if the nick of the client is already taken and will respond accordingly. If the nick hasnt been taken or the
%user is already in any channel then will attempt to join through handleJoin.
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

%Stops all the channel processes
handler({Channels, NicksMap}, {stop_channels})->
   lists:foreach(fun(Channel) -> genserver:stop(list_to_atom(Channel)) end, Channels),
   {reply, ok, {Channels, NicksMap}};


%Checks if the nick the client wants to change to is already in use and if so tells them the nick is taken, otherwise
%updates the NicksMap of the server with the new nick, tells the client to update its local nick.
handler({Channels, NicksMap}, {change_nick, NewNick, From})->
    case lists:all(fun(NickToCompare) -> NewNick =/= NickToCompare end, maps:values(NicksMap)) of
        false ->
            {reply, nick_taken, "Nick is already taken"};
        true ->
            NewNickMap = maps:update(From, NewNick, NicksMap),
            {reply, ok, {Channels, NewNickMap}}
    end.

%Checks if the channel the client is trying to join exists if so tries to join that channel, otherwise
%a new channel process will be created and added to the Channels lists.
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

%The channel receives a request to join, checking if the client is already connected. If already connected returns error,
%otherwise adds the client to the members list.
channel_handler(ChannelState, {join, From})->
    case lists:member(From, ChannelState) of
        true ->
            {reply, error, ChannelState};
        false ->
            {reply, ok, [From | ChannelState]}
    end;

%Removes the client if they are a member of the channel otherwise return an error.
channel_handler(ChannelState, {leave, From}) ->
    case lists:member(From, ChannelState) of
        true ->
            NewChannelState = lists:delete(From, ChannelState),
            {reply, ok, NewChannelState};
        false ->
            {reply, error, ChannelState}
    end;

% Sends out messages to every member except for the sender, spawning a new process in order to increase message throughput
% allowing the channel to receive further instructions faster.
% The channel spawns processes to handle the message sending instead of directly dealing with them itself
% in order to avoid issues of multithreadinng. The channel would otherwise wait for a response from the 
% client it is trying to send to, but if said client sends a new message to the channel it would break the channel
% as it isn't the response it would expect from said client. By making a new process to handle this we can avoid it
% completely as  no messages from the client can be sent to this new process except for the expected response.

% For instance if several messages are sent at the same time, if the message handling was done in the same process
% as the rest of the input from clients, the message sending could "swallow" or block new request from a client as it
% is already expects a response from said client. The channel would not be able to discern a response from the client
% from a new request. By using a new process for sending out messages we avoid this problem as the client is not usually
% sending new requests to the spawned message-sending function.
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