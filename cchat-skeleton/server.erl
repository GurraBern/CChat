-module(server).
-export([start/1,stop/1]).

-record( channel, {nicks, pids}).

initial_state() ->
    %#currentState{
        nicks = [],
        channels = [].
    %}.




handler(St, {join, Channel, Nick})->
    io:format("This is the server you tried to join : "),

    
    case lists:member(Channel, channels) of
        true ->
            %joina channel
                case lists:member(Nick, nicks) of
                    true ->
                        {reply, error, St};
                    false ->
                        


            %% do something
            
        false ->
            ok
    end.

%    {join, Channel}->
 %       {reply, ok, St}
    
    %{reply, {error, user_already_joined, "Skrrpaow"}
    







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
    genserver:stop(ServerAtom).
