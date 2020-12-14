#!/usr/bin/bash
########################################################################################################
# Looking for blocking indices in docker containers
# The easy way to avoid indexing stop because of a write attempt to an index on a WARM or COLD node
# This script is made to be in a crontab and executed every "TIME_RANGE" 
#####################
#    Variables

ES_URL="https://localhost:9200"
ES_USER="elastic"
ES_USER_PASS="elastic"
TIME_RANGE="1h"
tmp_file=list_blocked_index_`date +%Y%m%d%H%M`.tmp

logger -t WriteOnWarm Script launch
logger -t WriteOnWarm Genretating list of blocking indices

for container in `docker ps -q`
do
 container_name=`docker inspect --format '{{ .Name }}' $container | sed -e 's!\/!!g'`
 docker logs $container --since $[TIME_RANGE} | grep cluster_block_exception | awk -F" " '{print $12}' | sed -e 's!\]!!g' -e 's!\[!!g' | sort -u >> $tmp_file
done

if [ -s $tmp_file ]
then
 for errors in `cat $tmp_file`
  do
   result=$(curl --silent --user "${ES_USER}:${ES_USER_PASS}" -XPUT "${ES_URL}/${errors}/_settings" -H 'Content-Type: application/json' -d'{"index.blocks.write" : false}' --insecure)
   logger -t WriteOnWarm-error Etat de la modification de l index $errors : $result
 done
else
 logger -t WriteOnWarm File $tmp_file is empty
 logger -t WriteOnWarm Delete file $tmp_file
 deletion=$(rm -f $tmp_file)
fi

logger -t WriteOnWarm End of the script
