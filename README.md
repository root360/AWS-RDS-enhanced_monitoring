# AWS-RDS-enhanced_monitoring
Prototype to visualize logged metric data of AWS RDS Enhanced Monitoring

## Dependencies

* [aws-cli](https://aws.amazon.com/cli/)
* [bash](https://www.gnu.org/software/bash/)
* [jshon](http://kmkeen.com/jshon/2011-02-15-13-46-51-602.html)
* [sed](http://www.gnu.org/software/sed/)

## Usage

1. define credentials and profile for aws cli `aws configure`
2. get log group from AWS CloudWatch Logs via AWS Console or cli: `aws logs describe-log-groups --query='logGroups[].logGroupName' --output=text`
3. get log stream from AWS CloudWatch Logs via AWS Console or cli: `aws logs describe-log-streams --log-group-name tmp-ubu-124-package-SYSLogs-OZL2S221088L  --query='logStreams[].logStreamName' --output=text`
4. fetch logs from AWS CloudWatch Logs using defaul profile: `bash fetch-logs.sh -g <log-group-name> -s <log-stream-name>`
5. open index.html in your browser
