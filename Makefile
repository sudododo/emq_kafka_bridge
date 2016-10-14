PROJECT = emqttd_kafka_bridge
PROJECT_DESCRIPTION = emqttd kafka bridge
PROJECT_VERSION = 2.0

BUILD_DEPS = emqttd
dep_emqttd = git https://github.com/emqtt/emqttd master

COVER = true

include erlang.mk

app:: rebar.config
