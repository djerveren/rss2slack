#!/usr/bin/perl -w

use strict;
use JSON;
use XML::XPath;
use Getopt::Long;
use LWP::UserAgent;
use Digest::SHA1 qw(sha1_base64);
use HTTP::Request::Common qw(POST);

my $ver = 0.1;
my $prg = "rss2slack.pl";
my $slack_hook = "https://hooks.slack.com/services";
our(@cache, %opts, %posts);

# Get options.
GetOptions(\%opts,
    'help!',
    'cache-file=s',
    'slack-botname=s',
    'slack-channel=s',
    'slack-hook-endpoint=s'
) or die "Usage!\n";

# Exit with help text if missing options.
&help if (
	($#ARGV < 0) or
	(defined($opts{'help'})) or
	(!defined($opts{'cache-file'})) or
	(!defined($opts{'slack-botname'})) or
	(!defined($opts{'slack-channel'})) or
	(!defined($opts{'slack-hook-endpoint'}))
);


# Set 15 second global timeout to avoid hanging.
$SIG{'ALRM'} = sub {
    print ("ERROR: timed out.\n");
    exit 3;
};
alarm(15);


# Fetch XML contents from RSS feed.
my $rss_url = $ARGV[0];
my $ua = new LWP::UserAgent;
my $response = $ua->get("$rss_url");
my $rss = $response->content;

# Parse XML contents and store items.
my $xp = XML::XPath->new(xml => $rss);
my $stories = $xp->find('/rss/channel/item');

# Iterate over all items in feed.
foreach my $story($stories->get_nodelist) {
	# Retrieve interesting fields in each item.
	my $link  = $xp->find('link',  $story)->string_value;
	my $date  = $xp->find('pubDate', $story)->string_value;
	my $title = $xp->find('title', $story)->string_value;
	my $descr = $xp->find('description', $story)->string_value;

	# Create unique keyname by hashing title+link.
	my $key = sha1_base64($title,$link);

	# Store fields in hash using above key for matching against cached data.
	$posts{$key}{date} = $date;
	$posts{$key}{link} = $link;
	$posts{$key}{title} = $title;
	$posts{$key}{descr} = $descr;
}

# Bail if %posts is empty.
if (!%posts) {
	print "Failed to retreive RSS items.\n";
	exit 2;
}

# If cache file exists, store its contents.
if (-e "$opts{'cache-file'}") {
	open(CACHE, "<$opts{'cache-file'}");
	chomp(@cache = <CACHE>);
	close(CACHE);
}

# If @cache is empty, only inform that we are starting fresh.
if ($#cache < 0) {
	print "Starting on new cache file ($opts{'cache-file'}) ...\n";
} else  {
	my $new_posts = 0;

	# Iterate through all items retreived, and match against cached items.
	foreach my $key (keys %posts) {
		my $exist = 0;
		for (@cache) {
			$exist = 1 if ($key eq $_);
		}

		# If item doesn't exist in cache, report to Slack.
		if ($exist == 0) {
			$new_posts++;
			&slack_send($key);
		}
	}

	# Print something useful for Nagios plugin output.
	if ($new_posts == 0) {
		print "Found no new posts on $rss_url\n";
	} else {
		print "Found $new_posts new posts on $rss_url\n";
	}
}

# Update cache file with retreived hash values.
open(OUT, ">$opts{'cache-file'}") or die $!;
print OUT "$_\n" for keys %posts;
close(OUT);



# Slack post sub.
sub slack_send {
	my $key = shift;

	# Compile a suitable message string for Slack.
	my $msg = ":spiral_note_pad: *$posts{$key}{title}*\n";
	my @lines = split /\n/, $posts{$key}{descr};
	foreach my $line (@lines) {
		$msg .= ">$line\n";
	}
	$msg .= ":link: $posts{$key}{link}\n";

	my $payload = {
	       channel => $opts{'slack-channel'},
	       username => $opts{'slack-botname'},
	       icon_emoji => ':construction:',
	       text => $msg,
        };

	# Send message to slack through the hook interface.
	my $ua = LWP::UserAgent->new;
	my $req = POST("$slack_hook/$opts{'slack-hook-endpoint'}", ['payload' => encode_json($payload)]);
	my $resp = $ua->request($req);
}

# Help text sub.
sub help {
	print "$prg $ver\n\nUsage: $prg <options> <RSS URL>\n\n" .
		"OPTIONS:\n" .
		"\t--cache-file          <file>     To keep track of what we already read\n" .
         	"\t--slack-botname       <name>     Name of bot sending messages\n" .
         	"\t--slack-channel       <#channel> Slack channel to send messages to\n" .
         	"\t--slack-hook-endpoint <endpoint> API endpoint at https://hooks.slack.com/services/\n\n" .
		"Example: $prg \\\n" .
			"\t--cache-file=/var/tmp/nagios/rss2slack.dat \\\n" .
			"\t--slack-botname='Nagios Bot' \\\n" .
			"\t--slack-channel='#operations' \\\n" .
			"\t--slack-hook-endpoint='LB3FWS7UN/NL7KMIN63/VvzhVly0gmOsAW4rfIt6hrJh' \\\n" .
 			"\thttps://feedforall.com/sample.xml\n\n"; 

	exit 1;
}
