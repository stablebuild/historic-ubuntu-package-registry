#!/bin/bash
set -e

SCRIPTPATH="$( cd "$(dirname "$0")" ; pwd -P )"

DATE=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

echo "Date is $DATE"
echo ""

echo "Running apt-mirror..."
sudo apt-mirror
echo "Running apt-mirror OK"
echo ""

echo "Cleaning mirror..."
sudo /debmirror/live/var/clean.sh
echo "Cleaning mirror OK"
echo ""

echo "Creating snapshot..."
sudo zfs snapshot debmirror@$DATE
sudo mkdir /debmirror/$DATE
sudo mount -t zfs debmirror@$DATE /debmirror/$DATE
echo "Creating snapshot OK ($DATE)"
echo ""

# print pool info
zpool list
