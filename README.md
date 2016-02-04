# AWS RDS Enhanced Monitoring

## Plotting

Prototype to plot system metric data collected by AWS RDS Enhanced Monitoring

### Dependencies

* [aws-cli](https://aws.amazon.com/cli/)
* [bash](https://www.gnu.org/software/bash/)
* [jshon](http://kmkeen.com/jshon/2011-02-15-13-46-51-602.html)
* [sed](http://www.gnu.org/software/sed/)

### Usage

* define credentials and profile for aws cli 
```
aws configure
```
* get log group from AWS CloudWatch Logs via AWS Console or cli:
```
aws logs describe-log-groups --query='logGroups[].logGroupName' --output=text
```
* get log stream from AWS CloudWatch Logs via AWS Console or cli:
```
aws logs describe-log-streams --log-group-name <log-group-name>  --query='logStreams[].logStreamName' --output=text
```
* fetch logs from AWS CloudWatch Logs using defaul profile:
```
bash fetch-logs.sh -g <log-group-name> -s <log-stream-name>
```
* open index.html in your browser
