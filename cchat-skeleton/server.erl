-module(server).
-export([start/1,stop/1]).

-record( 
    channels, {channelMap = []::channel}
).

-record(
   channel, {nicks = [], pid = []}
).

initial_state() ->
    #channels{channelMap = maps:new()}.



%Fraga: GUI printar inte ut error meddelande?
%Fraga: Ar varan losning viable, ar det multithreadat ish?
handler(Channels, {join, Channel, Nick, From}) ->
    case maps:find(Channel, Channels) of
        error -> 
            NewChannel = #channel{nicks = [Nick], pid = [From]},
            NewChannels = maps:put(Channel, NewChannel, Channels),
            From ! ok,
            {reply, ok, NewChannels};
        {ok, _} -> 
            CurrentChannel = maps:get(Channel, Channels),
            NicksList = CurrentChannel#channel.nicks,
            PidList = CurrentChannel#channel.pid,
            case lists:member(Nick, NicksList) of 
                true ->
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
    io:fwrite("Does something~n"),

            case maps:find(Channel, Channels) of
                error -> 
                    From ! error,
                    {reply, error, Channels};
                {ok, _} -> 
                    CurrentChannel = maps:get(Channel, Channels),
                    NicksList = CurrentChannel#channel.nicks,
                    PidList = CurrentChannel#channel.pid,
                    From ! ok,
                    {reply, ok, Channels}
                    %case index_of(From, PidList) of
                    %    not_found -> From ! error, {reply, error, Channels};
                    %    Index -> ActiveNick = lists:nth((Index-1), NicksList),
                    %    lists:map (fun (sendMessage({ActiveNick, Channel} PidList)))
                    %end
            end.

%handler(Channels, {leave, Channel, nick, self()})->
%NewMap = maps:remove().

%TestChannel = #channel{nicks=[Nick]}, 
%NewChannelMap = maps:put(Channel, TestChannel, St#channels.channelMap),
%io:fwrite("value of NewMap is: ~p~n", [NewChannelMap]),
    
%DETTA FUNKAR
%Test = #channel{nicks=["Gurk", "Krut"]},
%Nicks = Test#channel.nicks,
%io:fwrite("value of test is: ~s\n", [Nicks]).


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
