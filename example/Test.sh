#!/bin/bash
# making sure we're in the correct dir
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"; cd ${DIR}
 
# make sure libraries are loaded from the local directory
# it's not elegant, but it works
export LD_LIBRARY_PATH=$DIR:$LD_LIBRARY_PATH
 
# start the game
./Test
