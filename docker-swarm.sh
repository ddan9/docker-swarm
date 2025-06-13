#!/bin/bash

########
# TODO #
########

#
# протестировать всё
# опционально режим дебага средствами bash (set -x -n -u) (пока хз как это реализовывать местными вызовами)
# не хукается env? (по крайней мере при линте)
# короче там надо убрать source и оставить export, но проблема экспорта в том, что он дурак и не умеет иногда обрабатывать спец.символы (# например). Решить
# докер ещё с какого-то хрена или умудряется хукать .env которого нет или запоминает параметры предыдущего (непонятно). UPD: Короче экспорт делается в сессию терминала, поэтому он запомнил
#

###############
# DESCRIPTION #
###############

#
# Script that acts like docker-compose, solving problems and reduces difference in comfortation between docker-compose script and docker swarm basic control
# Sadly, but some of functionality couldn't be implemented (bcs swarm is about network interaction)
# Generally, it needs only docker package
# Currently, there is no help, just watch workaround for possible parameters
#

##########
# TRIVIA #
##########

#
# source .env &> /dev/null
# export $(cat .env) &> /dev/null
# export $(cat .env) && docker stack up -d -c docker-compose.yml $(basename $(pwd))
# export $(cat .env) && docker stack down -d $(basename $(pwd))
# docker stack services $(basename $(pwd))
# docker stack ps $(basename $(pwd))
#

#############
# VARIABLES #
#############

SCRIPT_PATH=$(realpath $(dirname "$0"))

STACK_PATH=$(realpath $(pwd))

STACK_RESTART_COOLDOWN=5

STACK_CONFIG_NAME_DEFAULT="docker-compose.yml"

STACK_CONFIG_NAME_DEFAULT_STAGE="stage-docker-compose.yml"

#################
# DEFINE COLORS #
#################

COLOR_DEFAULT='\033[0m'

COLOR_WHITE='\033[0;1m'

COLOR_RED='\033[0;1;31m'

COLOR_GREEN='\033[0;1;32m'

COLOR_YELLOW='\033[0;1;33m'

COLOR_CYAN='\033[0;1;36m'

COLOR_YELLOW_BLINK='\033[1;33;5m'

function throw_error_message()

{

	error="$1"

	echo -e "${COLOR_RED}[${COLOR_YELLOW_BLINK}!${COLOR_RED}]${COLOR_WHITE}: ${COLOR_RED}$error ${COLOR_DEFAULT}"

}

function throw_stage_message()

{

	stage="$1"

	echo -e "${COLOR_GREEN}[${COLOR_YELLOW_BLINK}!${COLOR_GREEN}]${COLOR_WHITE}: ${COLOR_GREEN}Executing stage${COLOR_WHITE}: ${COLOR_YELLOW}$stage ${COLOR_DEFAULT}"

}

function throw_notify_message()

{

	notify="$1"

	echo -e "${COLOR_CYAN}[${COLOR_YELLOW_BLINK}!${COLOR_CYAN}]${COLOR_WHITE}: ${COLOR_CYAN}$notify ${COLOR_DEFAULT}"

}

#############
# FUNCTIONS #
#############

#
# Function for skipping, bcs it's missed in system calls (like blob)
#
# Usage: nothing special
#
# Outputs: nothing
#

function skip()

{

	sleep 0

}

#
# Function for moving into stack directory
#
# Usage: nothing special
#
# Outputs: nothing
#

function go_to_stack_path()

{

	cd "$STACK_PATH"

}

#
# Function for display help for this script. Also displays with incorrect combinations of parameters
#
# Usage: docker-swarm < --help | help | -h | h >
#
# Outputs: formated help text
#

function do_show_help()

{

	echo -e "there will be help"

}

#
# Function for display man for this script
#
# Usage: docker-swarm < --man | man | -m | m >
#
# Outputs: formated man text with less
#

function do_show_man()

{

	cat "$0" | less

}

function do_clean_everything()

{

	docker builder prune -af

	docker container prune -f

	docker image prune -af

	docker system prune -af

	docker volume prune -f

}

#
# General function for doing preparations before next commands executions
#
# Usage: nothing special
#
# Outputs: nothing
#

function auto_do_preparations()

{

	go_to_stack_path

	auto_export_env

}

#
# Function for automatic export local .env file with variables. Uses two ways for export (thru source and export (bcs one of them may not work correctly))
#
# Usage: nothing special
#
# Outputs: nothing
#

function auto_export_env()

{

	if [[ -f "./.env" ]]

	then

#		source "./.env" &> "/dev/null"

		export $(cat "./.env") &> "/dev/null" # Moving all output into null, bcs otherwise it may violate security of variables

	else

		throw_notify_message "Not found .env file here! Skipping..."

	fi

}

#
# Function for automatic definition of stack name. Uses current directory name as basic, just like docker-compose, may be overriden with new stack name
#
# Usage auto_define_stack_config <new_stack_name>
#
# Outputs string: final stack name (default basicly current directory name)
#

function auto_define_stack_name()

{

	stack_name_override="$1"

	stack_name_default=$(basename $(pwd))

	stack_name_output="$stack_name_default"

	if [[ -n "$stack_name_override" && "$stack_name_override" != "" && "$stack_name_override" != " " && "$stack_name_override" != "-" ]]

	then

		stack_name_output="$stack_name_override"

	else

		stack_name_output="$stack_name_default"

	fi

	echo "$stack_name_output"

}

#
# Function for automatic definition of config name. Uses default const variable as default, may be overriden with new file name
#
# Usage auto_define_stack_config <new-stack-config.yml>
#
# Outputs string: final config name (default basicly "docker-compose.yml")
#

function auto_define_stack_config()

{

	config_name_override="$1"

	config_name_default="$STACK_CONFIG_NAME_DEFAULT"

	config_name_output="$config_name_default"

	if [[ -n "$config_name_override" && "$config_name_override" != "" && "$config_name_override" != " " && "$config_name_override" != "-" ]]

	then

		config_name_output="$config_name_override"

	else

		config_name_output="$config_name_default"

	fi

	echo "$config_name_output"

}

function swarm_lint_config()

{

	config_name="$1"

	config_lint_debug="$2"

	auto_do_preparations

	config_name_auto=$(auto_define_stack_config "$config_name")

	if [[ -n "$config_name_auto" && "$config_name_auto" != "" && "$config_name_auto" != " " && -f "$config_name_auto" ]]

	then

		if [[ ( -n "$config_lint_debug" && "$config_lint_debug" != "" && "$config_lint_debug" != " " ) && ( "$config_lint_debug" == "--debug" || "$config_lint_debug" == "debug" ) ]]

		then

			docker stack config -c "$config_name_auto"

			exit 0

		else

			docker stack config -c "$config_name_auto" &> "/dev/null" && throw_stage_message "Linting successful!" || { throw_error_message "Linting failed! Use --debug for details"; exit 1; }

		fi

	else

		throw_error_message "Config file $config_name_auto does not exists!"

		exit 1

	fi

}

function swarm_stack_up()

{

	config_name="$1"

	stack_name="$2"

	auto_do_preparations

	config_name_auto=$(auto_define_stack_config "$config_name")

	stack_name_auto=$(auto_define_stack_name "$stack_name")

	swarm_lint_config "$config_name_auto"

	throw_stage_message "Deploying stack, named $stack_name_auto, via config $config_name_auto ..."

	docker stack up --with-registry-auth -d -c "$config_name_auto" "$stack_name_auto"

}

function swarm_stack_down()

{

	stack_name="$1"

	auto_do_preparations

	stack_name_auto=$(auto_define_stack_name "$stack_name")

	docker stack down -d "$stack_name_auto"

}

function swarm_stack_restart_service_image()

{

	service_name="$1"

	service_image="$2"

	auto_do_preparations

	service_name_full=$(auto_define_stack_name)_$service_name

	docker service update --force --image "$service_image" "$service_name_full"

}

function swarm_stack_restart_service_force()

{

	service_name="$1"

	auto_do_preparations

	service_name_full=$(auto_define_stack_name)_$service_name

	docker service update --force "$service_name_full"

}

function swarm_stack_restart_service_soft()

{

	service_name="$1"

	auto_do_preparations

	service_name_full=$(auto_define_stack_name)_$service_name

	docker service update "$service_name_full"

}

function swarm_stack_restart_service()

{

	auto_do_preparations

	restart_service_mode="$1"

	restart_service_name="$2"

	restart_service_image="$3"

	case "$restart_service_mode" in

		"--image" | "image")
		swarm_stack_restart_service_image "$restart_service_name" "$restart_service_image"
		exit 0
		;;

		"--force" | "force")
		swarm_stack_restart_service_force "$restart_service_name"
		exit 0
		;;

		"--soft" | "soft" | *)
		swarm_stack_restart_service_soft "$restart_service_name"
		exit 0
		;;

	esac

}

function swarm_stack_restart_force()

{

	config_name="$1"

	stack_name="$2"

	auto_do_preparations

	# On this place should be stack force-update with auto enumeration of services/containers thru stack-service. May be painful in implemention

}

function swarm_stack_restart_full()

{

	config_name="$1"

	stack_name="$2"

	auto_do_preparations

	swarm_stack_down

	sleep "$STACK_RESTART_COOLDOWN"

	swarm_stack_up "$config_name" "$stack_name"

}

function swarm_stack_restart_fast()

{

	config_name="$1"

	stack_name="$2"

	auto_do_preparations

	swarm_stack_up "$config_name" "$stack_name"

}

function swarm_stack_restart()

{

	restart_stack_mode="$1"

	restart_stack_config="$2"

	restart_stack_name="$3"

	auto_do_preparations

	case "$restart_stack_mode" in

		"--force" | "force")
		swarm_stack_restart_force "$restart_stack_config" "$restart_stack_name"
		exit 0
		;;

		"--full" | "full")
		swarm_stack_restart_full "$restart_stack_config" "$restart_stack_name"
		exit 0
		;;

		"--fast" | "fast" | "--soft" | "soft" | *)
		swarm_stack_restart_fast "$restart_stack_config" "$restart_stack_name"
		exit 0
		;;

	esac

}

function swarm_stack_services()

{

	stack_name="$1"

	auto_do_preparations

	stack_name_auto=$(auto_define_stack_name "$stack_name")

	docker stack services "$stack_name_auto"

}

function swarm_stack_ps()

{

	stack_name="$1"

	auto_do_preparations

	stack_name_auto=$(auto_define_stack_name "$stack_name")

	docker stack ps "$stack_name_auto"

}

function swarm_stack_ls

{

	auto_do_preparations

	docker stack ls

}

##############
# WORKAROUND #
##############

#
# Classic simple system of selecting parameters and keys accepted by the script from outside (see bash parameters and keys)
#

while [ -n "$1" ]

do

	case "$1" in

		#
		# Parameters for up/start/enable/deploy stack
		#

		"--up" | "up" | "--deploy" | "deploy" | "--start" | "start" | "--enable" | "enable" | "--stack-{up,deploy,start,enable}" | "stack-{up,deploy,start,enable}")
		config_name="$2"
		stack_name="$3"
		swarm_stack_up "$config_name" "$stack_name"
		exit 0
		;;

		#
		# Parameters for down/stop/disable/remove stack
		#

		"--down" | "down" | "--remove" | "remove" | "--rm" | "rm" | "--stop" | "stop" | "--disable" | "disable" | "--stack-{down,remove,rm,stop,disable}" | "stack-{down,remove,rm,stop,disable}")
		stack_name="$2"
		swarm_stack_down "$stack_name"
		exit 0
		;;

		#
		# Parameters for restart stack
		#

		"--restart" | "restart" | "--restart-stack" | "restart-stack")
		restart_stack_mode="$2"
		restart_stack_config="$3"
		restart_stack_name="$4"
		swarm_stack_restart "$restart_stack_mode" "$restart_stack_config" "$restart_stack_name"
		exit 0
		;;

		#
		# Parameters for restart services in stack
		#

		"--reload" | "reload" | "--restart-service" | "restart-service")
		restart_service_mode="$2"
		restart_service_name="$3"
		restart_service_image="$4"
		swarm_stack_restart_service "$restart_service_mode" "$restart_service_name" "$restart_service_image"
		exit 0
		;;

		#
		# Parameters for show/display/watch services in stack
		#

		"--services" | "services" | "--service" | "service")
		stack_name="$2"
		swarm_stack_services "$stack_name"
		exit 0
		;;

		#
		# Parameters for lint swarm config file
		#

		"--lint" | "lint")
		config_name="$2"
		config_lint_debug="$3"
		swarm_lint_config "$config_name" "$config_lint_debug"
		exit 0
		;;

		#
		# Parameters for show/display/watch containers/tasks/processes in stack
		#

		"--ps" | "ps")
		stack_name="$2"
		swarm_stack_ps "$stack_name"
		exit 0
		;;

		#
		# Parameters for show/display/watch list of working stacks
		#

		"--ls" | "ls")
		swarm_stack_ls
		exit 0
		;;

		#
		# Parameters for full docker clean up
		#

		"--clean-everything" "clean-everything")
		do_clean_everything
		exit 0
		;;

		#
		# Parameters for show/display/watch man page
		#

		"--man" | "man" | "-m" | "m")
		do_show_man
		exit 0
		;;

		#
		# Parameters for show/display/watch help page. Also displays with incorrect parameters (i.e. by default)
		#

		"--help" | "help" | "-h" | "h" | *)
		do_show_help
		exit 0
		;;

	esac

	shift

done

do_show_help # Displaying help by default. Also it will showed if parameters not completed with exit

###########
# THE END #
###########
