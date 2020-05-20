# AWS RDS Enhanced Monitoring

See [our blog](https://www.root360.de/aws-enhanced-monitoring-problemanalyse-bei-aws-rds/) for details.

## Plotting

Prototype to plot system metric data collected by AWS RDS Enhanced Monitoring

### Dependencies

* [aws-cli](https://aws.amazon.com/cli/)
* [bash](https://www.gnu.org/software/bash/)
* [jshon](http://kmkeen.com/jshon/2011-02-15-13-46-51-602.html)
* [sed](http://www.gnu.org/software/sed/)
* [flot](http://www.flotcharts.org/) (included in code)

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
* fetch logs from AWS CloudWatch Logs
  * get all-time data using default profile
```
bash fetch-logs.sh -g <log-group-name> -s <log-stream-name>
```
  * get all-time data using foobar profile
```
bash fetch-logs.sh -p foobar -g <log-group-name> -s <log-stream-name>
```
  * get data from 1454573815 (Thu Feb  4 09:16:55 CET 2016) until 1454574007 (Thu Feb  4 09:20:07 CET 2016) using foobar profile
```
bash fetch-logs.sh -p foobar -g <log-group-name> -s <log-stream-name> -b 1454573815 -e 1454574007
```
  * get data from 1454573815 (Thu Feb  4 09:16:55 CET 2016) until now using foobar profile
```
bash fetch-logs.sh -p foobar -g <log-group-name> -s <log-stream-name> -b 1454573815
```
* open index.html in your browser

### Adding graphs

* add function call to get wanted metric to fetch-logs.sh
* add plotting segments to javascript of index.html
* for available metrics see [AWS RDS documentation](http://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/USER_Monitoring.html#Available_OS_Metrics)
* included metrics:
 * diskIO
  * avgQueueLen
  * await
  * readIOsPS
  * readKbPS
  * tps
  * writeIOsPS
  * writeKbPS
  * util
 * cpuUtilization
  * wait
  * irq
  * system
  * steal
 * loadAverageMinute
  * five
 * memory
  * buffers
  * cached
  * dirty
  * writeback
 * network
  * tx
  * rx

### TODO

* implement array awareness for diskIO and network
