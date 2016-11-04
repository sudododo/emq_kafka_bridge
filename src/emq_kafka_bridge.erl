-module(emq_kafka_bridge).

-include_lib("emqttd/include/emqttd.hrl").

-include_lib("emqttd/include/emqttd_protocol.hrl").

-include_lib("emqttd/include/emqttd_internal.hrl").

-export([load/1, unload/0]).


%% Hooks functions

-export([on_client_connected/3, on_client_disconnected/3]).

-export([on_client_subscribe/4, on_client_unsubscribe/4]).

-export([on_session_created/3, on_session_subscribed/4, on_session_unsubscribed/4, on_session_terminated/4]).

-export([on_message_publish/2, on_message_delivered/4, on_message_acked/4]).

-record(struct, {lst=[]}).

%% Called when the plugin application start
load(Env) ->
	ekaf_init([Env]),
    emqttd:hook('client.connected', fun ?MODULE:on_client_connected/3, [Env]),
    emqttd:hook('client.disconnected', fun ?MODULE:on_client_disconnected/3, [Env]),
    emqttd:hook('client.subscribe', fun ?MODULE:on_client_subscribe/4, [Env]),
    emqttd:hook('client.unsubscribe', fun ?MODULE:on_client_unsubscribe/4, [Env]),
    emqttd:hook('session.created', fun ?MODULE:on_session_created/3, [Env]),
    emqttd:hook('session.subscribed', fun ?MODULE:on_session_subscribed/4, [Env]),
    emqttd:hook('session.unsubscribed', fun ?MODULE:on_session_unsubscribed/4, [Env]),
    emqttd:hook('session.terminated', fun ?MODULE:on_session_terminated/4, [Env]),
    emqttd:hook('message.publish', fun ?MODULE:on_message_publish/2, [Env]),
    emqttd:hook('message.delivered', fun ?MODULE:on_message_delivered/4, [Env]),
    emqttd:hook('message.acked', fun ?MODULE:on_message_acked/4, [Env]).

on_client_connected(ConnAck, Client = #mqtt_client{client_id = ClientId}, _Env) ->
    io:format("client ~s connected, connack: ~w~n", [ClientId, ConnAck]),
	
	    Json = mochijson2:encode([
        {type, <<"connected">>},
        {client_id, ClientId},
        {cluster_node, node()},
        {ts, emqttd_time:now_to_secs()}
    ]),
    
    ekaf:produce_async_batched(<<"connection">>, list_to_binary(Json)),
	
    {ok, Client}.

on_client_disconnected(Reason, _Client = #mqtt_client{client_id = ClientId}, _Env) ->
    io:format("client ~s disconnected, reason: ~w~n", [ClientId, Reason]),
	
	    Json = mochijson2:encode([
        {type, <<"disconnected">>},
        {client_id, ClientId},
        {reason, Reason},
        {cluster_node, node()},
        {ts, emqttd_time:now_to_secs()}
    ]),

    ekaf:produce_async_batched(<<"connection">>, list_to_binary(Json)),
	
    ok.

on_client_subscribe(ClientId, Username, TopicTable, _Env) ->
    io:format("client(~s/~s) will subscribe: ~p~n", [Username, ClientId, TopicTable]),
    {ok, TopicTable}.
    
on_client_unsubscribe(ClientId, Username, TopicTable, _Env) ->
    io:format("client(~s/~s) unsubscribe ~p~n", [ClientId, Username, TopicTable]),
    {ok, TopicTable}.

on_session_created(ClientId, Username, _Env) ->
    io:format("session(~s/~s) created.", [ClientId, Username]).

on_session_subscribed(ClientId, Username, {Topic, Opts}, _Env) ->
    io:format("session(~s/~s) subscribed: ~p~n", [Username, ClientId, {Topic, Opts}]),

	Json = mochijson2:encode([
        {type, <<"subscribed">>},
        {client_id, ClientId},
        {topic, Topic},
        {cluster_node, node()},
        {ts, emqttd_time:now_to_secs()}
    ]),
    
    ekaf:produce_async_batched(<<"connection">>, list_to_binary(Json)),

    {ok, {Topic, Opts}}.

on_session_unsubscribed(ClientId, Username, {Topic, Opts}, _Env) ->
    io:format("session(~s/~s) unsubscribed: ~p~n", [Username, ClientId, {Topic, Opts}]),
	
	Json = mochijson2:encode([
        {type, <<"unsubscribed">>},
        {client_id, ClientId},
        {topic, Topic},
        {cluster_node, node()},
        {ts, emqttd_time:now_to_secs()}
    ]),
    
    ekaf:produce_async_batched(<<"connection">>, list_to_binary(Json)),
	
    ok.

on_session_terminated(ClientId, Username, Reason, _Env) ->
    io:format("session(~s/~s) terminated: ~p.", [ClientId, Username, Reason]).

%% transform message and return
on_message_publish(Message = #mqtt_message{topic = <<"$SYS/", _/binary>>}, _Env) ->
    {ok, Message};

on_message_publish(Message, _Env) ->
    io:format("publish ~s~n", [emqttd_message:format(Message)]),

    Json = mochijson2:encode([
        {type, <<"published">>},
        %% {client_id, Message#mqtt_message.from},
        {topic, Message#mqtt_message.topic},
        {payload, Message#mqtt_message.payload},
        {qos, Message#mqtt_message.qos},
        {cluster_node, node()},
        {ts, Message#mqtt_message.timestamp}
    ]),

    ekaf:produce_async_batched(<<"connection">>, list_to_binary(Json)),
	
    {ok, Message}.

on_message_delivered(ClientId, Username, Message, _Env) ->
    io:format("delivered to client(~s/~s): ~s~n", [Username, ClientId, emqttd_message:format(Message)]),
    {ok, Message}.

on_message_acked(ClientId, Username, Message, _Env) ->
    io:format("client(~s/~s) acked: ~s~n", [Username, ClientId, emqttd_message:format(Message)]),
    {ok, Message}.

%% ===================================================================
%% ekaf_init
%% ===================================================================

ekaf_init(_Env) ->
    %% Get parameters
    %%{ok, Kafka} = application:get_env(emqttd_kafka_bridge, kafka),
    %%BootstrapBroker = proplists:get_value(bootstrap_broker, Kafka),
    %%PartitionStrategy= proplists:get_value(partition_strategy, Kafka),
    %% Set partition strategy, like 
    application:set_env(ekaf, ekaf_partition_strategy, strict_round_robin),
    %%application:set_env(ekaf, ekaf_partition_strategy, PartitionStrategy),
    %% Set broker url and port, like 
    application:set_env(ekaf, ekaf_bootstrap_broker, {"13.68.243.82", 9092}),
    %% application:set_env(ekaf, ekaf_bootstrap_broker, BootstrapBroker),
    %% Set topic
    application:set_env(ekaf, ekaf_bootstrap_topics, <<"connection">>),

    %% {ok, _} = application:ensure_all_started(kafkamocker),
    %% {ok, _} = application:ensure_all_started(gproc),
    %% {ok, _} = application:ensure_all_started(ranch),
    {ok, _} = application:ensure_all_started(ekaf),

   %% io:format("Init ekaf with ~p~n", [BootstrapBroker]).
    io:format("Init ekaf with ~p~n", [{"13.68.243.82", 9092}]).

%% Called when the plugin application stop
unload() ->
    emqttd:unhook('client.connected', fun ?MODULE:on_client_connected/3),
    emqttd:unhook('client.disconnected', fun ?MODULE:on_client_disconnected/3),
    emqttd:unhook('client.subscribe', fun ?MODULE:on_client_subscribe/4),
    emqttd:unhook('client.unsubscribe', fun ?MODULE:on_client_unsubscribe/4),
    emqttd:unhook('session.subscribed', fun ?MODULE:on_session_subscribed/4),
    emqttd:unhook('session.unsubscribed', fun ?MODULE:on_session_unsubscribed/4),
    emqttd:unhook('message.publish', fun ?MODULE:on_message_publish/2),
    emqttd:unhook('message.delivered', fun ?MODULE:on_message_delivered/4),
    emqttd:unhook('message.acked', fun ?MODULE:on_message_acked/4).

