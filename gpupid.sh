#!/bin/bash

# Variables you want to adjust
INTERVAL=5		# how often (in seconds) to update
SETPOINT=40		# desired temperature (in celcius)
# coefficients for PID math
Kp=3.25			# proportional
Ki=0.5			# integral
Kd=2			# derivative

# May want to adjust these, but probably best as-is
FANMAX=100
FANMIN=40

# These are all updated by the script. No need to change anything.
TEMP=40
ERROR=0
ACCUMULATED=0
DERIVATIVE=0
TIMEDELTA=0
LAST_t=$(date +%s)
LAST_err=0
TARGETFANSPEED=40
CURRENT_TARGET=0

get_temp() {
	TEMP=$(nvidia-settings -q "[gpu:0]/GPUCoreTemp" -t)
}

enable_fan_control() {
	nvidia-settings -a "[gpu:0]/GPUFanControlState=1"
}

get_target_fan_speed() {
	CURRENT_TARGET=$(nvidia-settings -q "[fan:0]/GPUTargetFanSpeed" -t)
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
	if [ $ACCUMULATED -lt -3000 ]; then
		echo "$(date) [INFO] Integral very negative. Reset to 0."
		ACCUMULATED=0
	fi
}

enable_fan_control
get_target_fan_speed
delta_t
while :
do
	sleep $INTERVAL
	desired_fan_speed
	get_target_fan_speed
	if [ $CURRENT_TARGET == $TARGETFANSPEED ]; then
		continue
	fi
	set_fan_speed $TARGETFANSPEED > /dev/null 2>&1 &
	echo "$(date) [INFO] Set fan speed ${TARGETFANSPEED}%"
done

set_fan_speed 40
