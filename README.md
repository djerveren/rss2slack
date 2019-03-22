rss-to-slack Nagios plugin
==========================

Simple plugin to send RSS updates to a Slack channel.

rss2slack.pl
------------

Posts a message from Nagios to a Slack channel whenver
an RSS feed gets updated. Requires the [*Incoming
Webhooks*](https://api.slack.com/incoming-webhooks)
 integration to be enabled for Slack.

The plugin is written in Perl and requires modules:
* JSON
* XML::XPath
* Getopt::Long
* Digest::SHA1
* LWP::UserAgent
* HTTP::Request::Common

While this plugin is written with Nagios in mind, it can
of course be scheduled from crontab or whatever scheduler
you wish, as long as the script executes on the target platform.

Usage:
------
```bash
./rss2slack.pl \
    --cache-file=/var/tmp/nagios/rss2slack.dat \
    --slack-botname='Nagios Bot' \
    --slack-channel='#operations' \
    --slack-api-endpoint='T00000000/B00000000/XXXXXXXXXXXXXXXXXXXXXXXX' \
    https://feedforall.com/sample.xml
```

(Where *slack-api-endpoint* is the string after /services/ generated when
setting up your *Incoming Webhook URL* for Slack.)
