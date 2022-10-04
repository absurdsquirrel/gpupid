#!/bin/bash

# Variables you want to adjust
# coefficients for PID math
Kp=0.50         # proportional
Ki=0.05         # integral
Kd=10.0         # derivative

# May want to adjust these, but probably best as-is
INTERVAL=5      # how often (in seconds) to update
SETPOINT=40     # desired temperature (in celcius)
FANMAX=80      # maximum fan speed
FANMIN=40       # minimum fan speed (I'd go lower, but the fan drops to 0 on anything under 40)

# These are all updated by the script. No need to change anything.
# Just giving them some initial values because I was trained to always initialize variables.
TEMP=40
ERROR=0
ACCUMULATED=0
DERIVATIVE=0
TIMEDELTA=0
LAST_t=$(date +%s)
LAST_err=0
TARGETFANSPEED=40
CURRENT_TARGET=0
CURRENT_SPEED=0


# [gpu:#] and [fan:#] should probably be variables defined above...
# ...but I'm lazy and this script is already way more lines than I expected it to be
# just make sure these all point at the correct gpu/fan(s)
get_temp() {
	TEMP=$(nvidia-settings -q "[gpu:0]/GPUCoreTemp" -t)
}

enable_fan_control() {
	nvidia-settings -a "[gpu:0]/GPUFanControlState=1" > /dev/null &2>1 &
	echo "$(date) Fan control enabled"
}

get_target_fan_speed() {
	CURRENT_TARGET=$(nvidia-settings -q "[fan:0]/GPUTargetFanSpeed" -t)
}

get_current_fan_speed() {
	CURRENT_SPEED=$(nvidia-settings -q "[fan:0]/GPUCurrentFanSpeed" -t)
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
	# guard against numbers -1 < target < 1
	if [[ "$target" =~ ^-?\.[0-9]+$ ]]; then
		target=0
	fi
	target=${target%.*}
	min $FANMAX $target
	max $FANMIN $target
	TARGETFANSPEED=$target
	if [ $ACCUMULATED -lt -3000 ]; then
		echo "$(date) [INFO] Integral very negative. Reset to 0."
		ACCUMULATED=0
	fi
}

# initialize some values from current state
enable_fan_control
get_target_fan_speed
sleep 1
desired_fan_speed

# main loop
while :
do
	sleep $INTERVAL
	desired_fan_speed
	get_target_fan_speed
	if [ $CURRENT_TARGET == $TARGETFANSPEED ] || [ $CURRENT_SPEED != $CURRENT_TARGET ]; then
		continue
	fi
	set_fan_speed $TARGETFANSPEED > /dev/null 2>&1 &
	echo "$(date) [INFO] Set fan speed ${TARGETFANSPEED}%"
done

set_fan_speed 40
