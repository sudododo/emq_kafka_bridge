PROJECT = emqttd_kafka_bridge
PROJECT_DESCRIPTION = emqttd kafka bridge
PROJECT_VERSION = 2.0

DEPS = ekaf
dep_ekaf = git https://github.com/helpshift/ekaf master


BUILD_DEPS = emqttd
dep_emqttd = git https://github.com/emqtt/emqttd master

COVER = true

ERLC_OPTS += +'{parse_transform, lager_transform}'

include erlang.mk

app:: rebar.config
