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
  echo "  -s: name of log stream (see aws [--profile <awscli-profile-name>] logs cribe-log-streamsAWS Console)"
  echo "    UNIX timestamp format can be generated with:"
  echo "      \"date -d '2016-01-09 15:00:00' +%s000\""
}

# define default profile for aws-cli
profile="default"
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
      ;;
    'e')
      end="${OPTARG}"
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
  local type="${1}"
  local category="${2}"
  echo "generating ${category} -> ${type}"
  echo '"'"${type}"'": {
  "label": "'"${category} ${type}"'",
  "data": [' >> "${outfile}"
}

# finish metric type
function endType() {
  echo '[]' >> "${outfile}"
  echo ']}' >> "${outfile}"
}

# write metrics of type diskIO
function writeDiskIO() {
  local type="$1"
  local number="${2:-0}"
  startType "${type}" "diskIO"
  jshon -F "${infile}" -a -e timestamp -u -p -e data -e diskIO -e "${number}" -e "${type}" -u | sed '/^[0-9][0-9]*$/ { s/$/,/;N;s/\n//; };s/^/[/g;s/$/],/g' | sort -n >> "${outfile}"
  endType
}

# write metrics of type CPU
function writeCPU() {
  local type="$1"
  startType "${type}" "cpu"
  jshon -F "${infile}" -a -e timestamp -u -p -e data -e cpuUtilization -e "${type}" -u | sed '/^[0-9][0-9]*$/ { s/$/,/;N;s/\n//; };s/^/[/g;s/$/],/g' | sort -n >> "${outfile}"
  endType
}

# write metrics of type load average
function writeLoadAvg() {
  local type="$1"
  startType "${type}" "load"
  jshon -F "${infile}" -a -e timestamp -u -p -e data -e loadAverageMinute -e "${type}" -u | sed '/^[0-9][0-9]*$/ { s/$/,/;N;s/\n//; };s/^/[/g;s/$/],/g' | sort -n >> "${outfile}"
  endType
}

# write metrics of type memory
function writeMemory() {
  local type="$1"
  startType "${type}" "memory"
  jshon -F "${infile}" -a -e timestamp -u -p -e data -e memory -e "${type}" -u | sed '/^[0-9][0-9]*$/ { s/$/,/;N;s/\n//; };s/^/[/g;s/$/],/g' | sort -n >> "${outfile}"
  endType
}

# write metrics of type network
function writeNetwork() {
  local type="$1"
  local number="${2:-0}"
  startType "${type}" "network"
  jshon -F "${infile}" -a -e timestamp -u -p -e data -e network -e "${number}" -e "${type}" -u | sed '/^[0-9][0-9]*$/ { s/$/,/;N;s/\n//; };s/^/[/g;s/$/],/g' | sort -n >> "${outfile}"
  endType
}

# start valid json
echo '{' > "${outfile}"

### process log data
writeDiskIO "await"
echo ',' >> "${outfile}"
writeDiskIO "util"
echo ',' >> "${outfile}"
writeDiskIO "tps"
echo ',' >> "${outfile}"
writeDiskIO "avgQueueLen"
echo ',' >> "${outfile}"
writeDiskIO "writeKbPS"
echo ',' >> "${outfile}"
writeDiskIO "readKbPS"
echo ',' >> "${outfile}"
writeDiskIO "readIOsPS"
echo ',' >> "${outfile}"
writeDiskIO "writeIOsPS"
echo ',' >> "${outfile}"
writeCPU "steal"
echo ',' >> "${outfile}"
writeCPU "wait"
echo ',' >> "${outfile}"
writeCPU "irq"
echo ',' >> "${outfile}"
writeCPU "system"
echo ',' >> "${outfile}"
writeLoadAvg "five"
echo ',' >> "${outfile}"
writeMemory "writeback"
echo ',' >> "${outfile}"
writeMemory "cached"
echo ',' >> "${outfile}"
writeMemory "dirty"
echo ',' >> "${outfile}"
writeMemory "buffers"
echo ',' >> "${outfile}"
writeNetwork "tx"
echo ',' >> "${outfile}"
writeNetwork "rx"


# close valid json
echo '}' >> "${outfile}"
