#!/bin/bash

camera () {
  clear
  echo "you may now unplug your device"
  
  local ip=$1
  local serialNo=$2
  port=5555
  
  clear
  printf "IP Address: %s\nSerial Number: %s\nTCPIP Port: %i\nTCPIP connection: %s\n\n" \
  "$ip" "$serialNo" "$port" "$ip:$port"
  
  orientation=0
  size=0
  cameraId=0
  
  read -rp "Camera Orientation: " orientation
  read -rp "max-size: " size
  
  scrcpy -s "$ip:$port" --list-cameras
  read -rp "Camera Id: " cameraId
  
  echo "Press any key to continue.."
  read -rsn1
  clear
  
  echo "Starting Camera..."
  
  scrcpy --v4l2-sink=/dev/video0 --no-audio --video-source=camera --max-size="$size" --orientation="$orientation" \
  --camera-id="$cameraId" -s "$ip:$port" &>/dev/null
  
  exit 0
}

tcpip () {
  clear
  echo "waiting for a device to be found over adb"
  
  serialNo=""
  
  adb_devices="$(adb devices | wc -l)"
  adb_devices_count="$((adb_devices - 2))"
  
  echo "awaiting devices"
  
  while [ $adb_devices_count -le 0 ]; do
  adb_devices="$(adb devices | wc -l)"
  adb_devices_count="$((adb_devices - 2))"
  sleep 0.1
  done
  
  echo -e "please authorize your device(s) if they are not authorized\npress any key to continue..."
  read -rsn1
  echo ""
  
  if [ $adb_devices_count -eq 1 ]; then
    serialNo="$(adb get-serialno)"
  elif [ $adb_devices_count -gt 1 ]; then
    echo -e "$adb_devices_count found\nPlease Select A device by Serial Number/Connection ip[:port]"
    adb devices
    read -rp "Device: " serialNo
  fi
  
  echo "getting device ipv4 address"
  ip="$(adb -s "$serialNo" shell ip route get 1.1.1.1 | awk '{print $9}')"
  
  if [[ $ip != "192.168"* ]] || [[ $ip = *"10.10"* ]] || [[ $ip = "2000" ]]; then
    echo "VPN suspected, remember always disable your vpn before running this script"
    read -rp "Continue [Y/n] " c
    if [[ $c = "N" || $c = "n" ]]; then
      echo "aborted"
      exit 1
    fi
  
    if [[ $ip = "2000" ]]; then 
      ip="$(adb -s "$serialNo" shell ip route get 1.1.1.1 | awk '{print $7}')"
    fi
  fi
  
  echo "$ip, $serialNo"
  
  #initialize and connect to tcpip 5555
  if ! adb -s "$serialNo" tcpip 5555 &>/dev/null; then
    ec=$?
    echo -e "tcpip failed\nerror code: $ec"
    exit $ec
  fi
  
  echo "tcpip initialized"
  
  #free up %1
  kill -9 %1 &>/dev/null
  sleep 0.2
  
  adb connect "$ip:5555" &>/dev/null &
  
  SECONDS=0
  while bg %1 &>/dev/null; do
    if [ $SECONDS -ge 3 ]; then
      kill -9 %1 &>/dev/null
      echo "Adb connection timed out, maybe you have a vpn?"
      exit 1
    fi
  done
  
  while ! bg %1 &>/dev/null; do
    camera "$ip" "$serialNo"
    exit 0
  done
}

clear
if [ "$(id -u)" -ne 0 ]; then
  echo "script must be ran as root"
  exit 1
fi

testfor (){
  local name=$1
  local command=$2
  local install_canidate=$3

  echo "Testing for $name."

  if ! command -v "$command" &> /dev/null; then
    echo -e "Please Install $name\n commands to install include"
    echo -e "sudo <package manager> install $install_canidate"
    exit 1
  fi

  echo "$name found"
  sleep 0.1
}

testfor adb adb adb
testfor scrcpy scrcpy scrcpy
echo "Please make sure you have v4l2loopback-utils installed as this script cant check that"

echo -e "\nPress any key to continue..."
read -rsn1

tcpip