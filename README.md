# PID controller script for GPU fans

> tfw nvidia's buggy-ass linux drivers can't run your gpu fan right so you write your own PID controller in bash because fuck it, your an engineer. you went to college and got a piece of paper saying ur so smrt and everything. why not make a needlessly complicated solution to something that shouldn't be a problem? and what the hell, let's do it in bash while we're at it. y'know, for nerd-cred or w/e

**I make no promises about how well this will work for you, and I take no responsibility if you bork your ProGamerRGBLEDWTFBBQxX420blazeitXx 3090 using this total bodge of a script I banged out in an afternoon**

Kp, Ki, and Kd will need to be adjusted to fit your situation. You'll have to experiment to find the right combinations.  
Monitor your temperature and fan speeds carefully while doing this!

Some tips:
- P will respond aggressively to the immediate difference between measured temperature and target temperature
  - keep Kp small to give the fan time to do its job before the script just ramps it all the way up
- I has "memory" of the deviation from target; the longer the temp stays high, the more aggressive this gets
  - keep Ki _really_ small or the script will just ramp the fan way up
- D looks at the direction the temperature is moving and responds aggressively to big changes
  - keep Kd large to stay ahead of the curve; will ramp up quickly when temp spikes, and counteract P & I when the temp starts coming down.
- longer polling intervals will give the fans time to stabilize the temp without ramping all the way up, but they will also respond less quickly as temp changes

![](docs/engineer.jpg)
