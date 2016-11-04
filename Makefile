PROJECT = emq_kafka_bridge
PROJECT_DESCRIPTION = emqttd kafka bridge
PROJECT_VERSION = 2.0

DEPS = ekaf
dep_ekaf = git https://github.com/helpshift/ekaf master

DEPS = eavro
dep_eavro = git https://github.com/SIfoxDevTeam/eavro master

BUILD_DEPS = emqttd
dep_emqttd = git https://github.com/emqtt/emqttd master

TEST_DEPS = cuttlefish
dep_cuttlefish = git https://github.com/emqtt/cuttlefish


ERLC_OPTS += +'{parse_transform, lager_transform}'

COVER = true

include erlang.mk

app:: rebar.config

app.config::
	cuttlefish -l info -e etc/ -c etc/emq_kafka_bridge.conf -i priv/emq_kafka_bridge.schema -d data
