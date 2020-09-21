#!/bin/bash
#Variables
IMAGE="homeassistant/amd64-hassio-supervisor:latest"
SCRIPT_NAME="extract-snapshot.py"
#check arguments
if [ "$#" -ne 1 ]; then
    echo "You must enter exactly 1 command line arguments"
    echo "example: ./extract-snapshot.sh SNAPSHOT_FILENAME"
    exit 1
fi
SNAPSHOT_FILENAME="$1"
#check if all required commands are found
#docker-cli
if ! command -v docker &> /dev/null
then
    echo "docker command could not be found.A working local docker environment is required"
    exit
fi
#mktemp
if ! command -v mktemp &> /dev/null
then
    echo "mktemp command could not be found."
    exit
fi
#ask for password
echo -n "please enter the snapshot password:"
read SNAPSHOT_PASSWORD
echo "password is $SNAPSHOT_PASSWORD"
TEMP_DIR=$(mktemp -d /tmp/tmp.extract-snapshot-XXXX)
#write out python script
cat > "$TEMP_DIR/$SCRIPT_NAME" << EOF
import os
from supervisor.utils.tar import SecureTarFile
from supervisor.snapshots.utils import password_to_key

password = os.environ.get('SNAPSHOT_PASSWORD')
snapshot_filename = os.environ.get('SNAPSHOT_FILENAME')
key = password_to_key(password)
with SecureTarFile(name=snapshot_filename,mode='r',gzip=False) as snapshot_tar:
    snapshot_tar.extractall(path='.',members=snapshot_tar)

with SecureTarFile(name='homeassistant.tar.gz',mode='r',key=key) as homeassistant_tar:
    homeassistant_tar.extractall(path='homeassistant/',members=homeassistant_tar)
EOF
cp "$SNAPSHOT_FILENAME"  "$TEMP_DIR/"
#call docker
docker run --rm -it -w /tmp -e SNAPSHOT_FILENAME="$SNAPSHOT_FILENAME" -e SNAPSHOT_PASSWORD="$SNAPSHOT_PASSWORD" -v "$TEMP_DIR":/tmp/:Z --entrypoint= "$IMAGE" python "$SCRIPT_NAME"
if [ $? -eq 0 ]
then
  echo "snapshot extracted to $TEMP_DIR"
else
  echo "Something Went wrong" >&2
  echo "inspect and cleanup temp_dir $TEMP_DIR manualy"
fi