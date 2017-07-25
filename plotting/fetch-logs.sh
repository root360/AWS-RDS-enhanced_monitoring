#!/bin/bash

# check dependencies
for dep in jshon sed aws; do
  type -f "${dep}" &> /dev/null || depmiss="${depmiss} ${dep}"
done
if [[ -n "${depmiss}" ]]; then
  echo "The following dependencies are missing:"
  printf '  %s\n' "${depmiss}"
  exit 1
fi

# print script usage
function usage() {
  echo "$(basename "$0") [-h] -g <log-group-name> -s <log-stream-name> [-b <start-time>] [-e <end-time>] [-p <awscli-profile-name>]"
  echo "  -b: start time of log to be fetched in 'UNIX timestamp format * 1000' (default = 0)"
  echo "  -e: end time of log to be fetched in 'UNIX timestamp format + 1000' (default = now)"
  echo "  -g: name of log group (see aws [--profile <awscli-profile-name>] logs describe-log-groups or AWS Console)"
  echo "  -h: this help"
  echo "  -p: name of aws cli profile"
  echo "  -s: name of log stream (see aws [--profile <awscli-profile-name>] --log-group-name <log-group-name> logs decribe-log-streams or AWS Console)"
  echo "    UNIX timestamp format can be generated with:"
  echo "      \"date -d '2016-01-09 15:00:00' +%s000\""
}

# define default profile for aws-cli
profile="default"
# define default log-group-name
groupname="RDSOSMetrics"
# define default start time
start="0"
# define default end time
end="$(date -u +%s)000"
# define input file for jshon
infile="logs.json"
# define file for javascript
outfile="clean_metrics.json"

# handle options
while getopts ':hp:g:s:b:e:' opt; do
  case "${opt}" in
    'p')
      profile="${OPTARG}"
      ;;
    'g')
      groupname="${OPTARG}"
      ;;
    's')
      streamname="${OPTARG}"
      ;;
    'b')
      start="${OPTARG}"
      # set timestamp to json timestamp (UNIX*1000)
      [[ ${#start} -eq 10 ]] && start="${start}000"
      [[ ${#start} -eq 11 ]] && start="${start}00"
      [[ ${#start} -eq 12 ]] && start="${start}0"
      ;;
    'e')
      end="${OPTARG}"
      # set timestamp to json timestamp (UNIX*1000)
      [[ ${#end} -eq 10 ]] && end="${end}000"
      [[ ${#end} -eq 11 ]] && end="${end}00"
      [[ ${#end} -eq 12 ]] && end="${end}0"
      ;;
    ':')
      echo "${TMPNAME}: -${OPTARG} requires an argument" >&2
      echo
      usage
      exit 1
      ;;
    'h'|*)
      usage
      exit 0
      ;;
  esac
done

# check if needed options are present
if [[ -z "${groupname}" || -z "${streamname}" ]]; then
  echo "required parameters missing."
  echo
  usage
  exit 1
fi

# declare token
token=1

echo "downloading logs for:"
echo "  profile:     ${profile}"
echo "  group-name:  ${groupname}"
echo "  stream-name: ${streamname}"
echo "  start-time:  ${start} "
echo "  end-time:    ${end}"

# initiate output json
echo -n '[' > "${infile}"

# iterate output until last token (chunk) was given by AWS API
while [[ ${oldtoken} != ${token} ]]; do
  oldtoken="${token}"
  echo "downloading with token ${token}"
  if [[ ${token} -eq 1 ]]; then
    # download logs without token = first chunk
    output="$(aws --profile "${profile}" logs get-log-events --log-group-name "${groupname}" \
      --log-stream-name "${streamname}" --start-time "${start}" \
      --end-time "${end}" --output text)"
      [[ ${PIPESTATUS} -ne 0 ]] && exit 2
  else
    # download logs with token = follow-up chunks
    output="$(aws --profile "${profile}" logs get-log-events --log-group-name "${groupname}" \
      --log-stream-name "${streamname}" --next-token "${token}" --start-time "${start}" \
      --end-time "${end}" --output text)"
      [[ ${PIPESTATUS} -ne 0 ]] && exit 2
  fi
  # get token of next chunk
  token="$(head -1 <<<"${output}" | cut -f1)"

  # manipulate log entry to be json compatible
  [[ ${oldtoken} != ${token} ]] && sed 's/.*\s\s*\([0-9][0-9]*\)\s\s*\({.*}\)\s.*/{"timestamp":\1,"data":\2},/g;/^[^{]/d' <<<"${output}" >> "${infile}"
done
# remove last comma to be json compatible
sed -i '$ s/,$//;' "${infile}"
# finish output json
echo ']' >> "${infile}"

# initialize metric type
function startType() {
  local category="${1}"
  local type="${2}"
  echo "generating ${category} -> ${type}"
  echo '"'"${category}_${type}"'": {
  "label": "'"${category} ${type}"'",
  "data": [' >> "${outfile}"
}

# finish metric type
function endType() {
  echo '[]' >> "${outfile}"
  echo ']}' >> "${outfile}"
}

function writeData() {
  local category="${1}"
  local type="${2}"
  local number=0
  startType "${3:-${category}}" "${type}" 
  if [[ $(jshon -F "${infile}" -a -e data -e "${category}") =~ ^\[ ]]; then
    # find data of given category and type
    local data="$(jshon -F "${infile}" -a -e timestamp -u -p -e data -e "${category}" -e "${number}" -e "${type}" -u)"
  else
    # find data of given category and type
    local data="$(jshon -F "${infile}" -a -e timestamp -u -p -e data -e "${category}" -e "${type}" -u)"
  fi
  # remove unnecessary lines and create valid json
  sed '/^[0-9][0-9]*$/ { s/$/,/;N;s/\n//; };s/^/[/g;s/$/],/g' <<<"${data}" | \
  # sort data by included timestamp
  sort -n >> "${outfile}"
  endType
}

# start valid json
echo '{' > "${outfile}"

### process log data
# get several disk IO metric data
for type in "avgQueueLen" "await" "readIOsPS" "readKbPS" "tps" "writeIOsPS" "writeKbPS" "util"; do
  writeData "diskIO" "${type}"
  echo ',' >> "${outfile}"
done

# get several CPU metric data
for type in "wait" "irq" "system" "steal"; do
  writeData "cpuUtilization" "${type}" "CPU"
  echo ',' >> "${outfile}"
done

for type in "nice" "total"; do
  writeData "cpuUtilization" "${type}" "CPU2"
  echo ',' >> "${outfile}"
done

# get five minutes load average 
writeData "loadAverageMinute" "five" "load"

# get several memory metric data
for type in "cached" "buffers" "dirty" "writeback"; do
  echo ',' >> "${outfile}"
  writeData "memory" "${type}"
done

# get several swap metric data
for type in "cached" "total" "free"; do
  echo ',' >> "${outfile}"
  writeData "swap" "${type}"
done

# get network traffic transmitted metric data
echo ',' >> "${outfile}"
writeData "network" "tx"
# get network traffic received metric data
echo ',' >> "${outfile}"
writeData "network" "rx"

# tasks count (should be similar to connection)
for type in "total" "sleeping" "running" "zombie" "stopped";do
  echo ',' >> "${outfile}"
  writeData "tasks" "${type}"
done

# close valid json
echo '}' >> "${outfile}"
