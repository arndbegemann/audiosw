#!/bin/bash

GPIO_PIN=27
GPIO_NAME="gpio${GPIO_PIN}"
GPIO_DIR="/sys/class/gpio/${GPIO_NAME}"
GPIO_DIRECTION="${GPIO_DIR}/direction"
GPIO_VAL="${GPIO_DIR}/value"
OUT=false
NEXT_STATE=ST_OFF
STATE=$NEXT_STATE
STATE_BEFORE=INIT

TIMEOUT=0;
# TIMEOUT
OFF_TIMEOUT=300 # 5min
ON_TIMEOUT=10 # 10sec

trap cleanup SIGTERM SIGINT

#
# Set GPIP Out: In/OFF
#
set_pwr() {
  if [ ! -d "$GPIO_DIR" ]; then
    echo "Create GPIO PIN as output"
    echo $GPIO_PIN > /sys/class/gpio/export
    while [ `cat ${GPIO_DIRECTION}` != "out" ] 
    do
     echo out > ${GPIO_DIRECTION} 2>/dev/null
     sleep 0.1
    done
  fi
  if $1 ; then
    echo "Switch $GPIO_NAME on!"
    echo 1 > ${GPIO_VAL}
  else
    echo "Switch $GPIO_NAME off!"
    echo 0 > ${GPIO_VAL}
  fi
}

#
# Cleanup Sigterm Function
#
cleanup()
{
  echo "Script End: Switch off Audio!"
  set_pwr false
  exit
}

#
# check if audio is running
#
is_running() {
  if grep -q RUNNING /proc/asound/card*/*p/*/status 2>&1; then
    return 0 
  fi
  return 1
}


#
# Endles Loop
#
while [ true ]; do
  STATE=$NEXT_STATE
  #echo "STATE: ${STATE}"
  case $STATE in
    ST_OFF_TIMEOUT)
      if [ $STATE != $STATE_BEFORE ]; then
        echo "STATE: ST_OFF_TIMEOUT"
        TIMEOUT=0
      fi
      if is_running; then
        #echo "Playing"
        NEXT_STATE=ST_ON;
      else
       #echo "Idle"
       TIMEOUT=$((TIMEOUT + 1))
       #echo "TIMEOUT: $TIMEOUT"
       if [ $TIMEOUT -ge $OFF_TIMEOUT ]; then
      	NEXT_STATE=ST_OFF;
       fi
      fi
      ;;
    ST_OFF)
      if [ $STATE != $STATE_BEFORE ]; then
        echo "STATE: ST_OFF"
        set_pwr false
      fi
      if is_running; then
        #echo "Playing"
        NEXT_STATE=ST_ON_TIMEOUT;
      fi
      ;;
    ST_ON_TIMEOUT)
      if [ $STATE != $STATE_BEFORE ]; then
        echo "STATE: ST_ON_TIMEOUT"
        TIMEOUT=0
      fi
      if is_running; then
        #echo "Playing"
          TIMEOUT=$((TIMEOUT + 1))
          if [ $TIMEOUT -ge $ON_TIMEOUT ]; then
      	    NEXT_STATE=ST_ON;
          fi
      else
       #echo "Idle"
       NEXT_STATE=ST_OFF;
      fi
      ;;
    ST_ON)
      if [ $STATE != $STATE_BEFORE ]; then
        echo "STATE: ST_ON"
        set_pwr true
      fi
      if ! is_running; then
        #echo "Idle"
        NEXT_STATE=ST_OFF_TIMEOUT;
      fi
      ;;
    *)
      NEXT_STATE=ST_OFF;
      ;;
  esac
  STATE_BEFORE=$STATE
  sleep 1 # Sleep 1 Second
done



