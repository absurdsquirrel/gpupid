#!/bin/bash

TEMP=40
FANMAX=80
FANMIN=40
SETPOINT=40
Kp=3.25
Ki=0.5
Kd=2
ERROR=0
ACCUMULATED=0
DERIVATIVE=0
TIMEDELTA=0
LAST_t=$(date +%s)
LAST_err=0
TARGETFANSPEED=40

get_temp() {
	TEMP=$(nvidia-settings -q "[gpu:0]/GPUCoreTemp" -t)
}

enable_fan_control() {
	nvidia-settings -a "[gpu:0]/GPUFanControlState=1"
}

set_fan_speed() {
	nvidia-settings -a "[fan:0]/GPUTargetFanSpeed=$1" -a "[fan:1]/GPUTargetFanSpeed=$1"
}

get_error() {
	get_temp
	let "ERROR=$TEMP - $SETPOINT"
}

delta_t() {
	time=$(date +%s)
	TIMEDELTA=$(("$time - $LAST_t"))
	LAST_t=$time
}

get_integral() {
	let "ACCUMULATED += $1 * $2"
}

get_derivative() {
	DERIVATIVE=$(("$(($1 - $LAST_err)) / $2"))
	LAST_err=$1
}

min() {
	target=$(("$1 < $2 ? $1 : $2"))
}

max() {
	target=$(("$1 > $2 ? $1 : $2"))
}

desired_fan_speed() {
	get_error
	delta_t
	get_integral $ERROR $TIMEDELTA
	get_derivative $ERROR $TIMEDELTA
	local target=$(bc <<< "$ERROR * $Kp + $ACCUMULATED * $Ki + $DERIVATIVE * $Kd")
	target=${target%.*}
	min $FANMAX $target
	max $FANMIN $target
	TARGETFANSPEED=$target
}

enable_fan_control
delta_t
while :
do
	sleep 10
	desired_fan_speed
	set_fan_speed $TARGETFANSPEED
done

set_fan_speed 40
