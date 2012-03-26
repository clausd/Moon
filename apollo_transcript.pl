#!/usr/local/bin/perl -I. -I./perllib -I./perllibx -I./spotifydj/cgi-bin/perllibx 

package A;
use Assumptions;
our @ISA = qw(Assumptions);

sub configure {
	my $app = shift;
    if ($^O eq 'MSWin32' || $^O eq 'darwin') {
        $app->set_dbix('classydk_collector', 'root', '');
    } else {
      # FIXME 1
	    $app->set_dbix('YOURDB', 'YOURUSER', 'YOURPW');
    }
#     $app->{get_user_artists_sql} = 	$app->dbh->prepare("select sum(score) as user_score, int_day from events e inner join event_related r on e.id = r.event_id where r.last_fm_id in (?) group by int_day order by user_score desc;");
}
1;
package main;
use JSON;
use URI::Escape;
use DBI;
use CGI;
use Assumptions;
use Date::Manip;
use Data::Dumper;
use LWP::Simple;
use Encode;
use Time::Duration;

# use strict;

my $app = new A;
$app->setup;

$JSON::UTF8 = 1;
$JSON::ConvBlessed = 1;

# FIXME 2
# set this to the epoch/unix time where you want the countdown to begin
my $t_zero = 1247751120;
# my $t_zero = 1247738784;
# how many log entries to fetch
my $n_future = 30;
my $debug = 0;

# update_events_from_json();
# exit;

# JSONP
my $callback = $app->cgi->param('jsonp');

print $app->cgi->header('application/json; charset=utf-8');

if ($app->cgi->param('q') eq 'transcript') {
    my $result = get_transcript();
    print json_out($result, $callback);
} elsif ($app->cgi->param('q') eq 'import') {
	my $input_file = $app->cgi->param('file');
	import_transcript($input_file);
}

sub import_transcript {
    my $file = shift;
    my $fh;
    open $fh, $file or die "Could not open $file";
    $in_comms = 0;
    my ($mission_time, $comms, $speaker) = ();
    while (my $line = <$fh>) {
        chomp($line);
        if ($line =~ /^$/ && $in_comms) {
            print "$mission_time $speaker\n$comms\n\n\n";
            $in_comms = 0;
#             next;
            my $tr = $app->db->apollo_transcripts->add;
            $tr->fields->{mission_time} = $mission_time;
            $tr->fields->{comms} = $comms;
            $tr->fields->{speaker} = $speaker;
            $tr->save;
        }
        elsif ($in_comms) {
            $comms .= $line;
        }
        elsif ($line =~ /^(\d+)\s(\d+)\s(\d+)\s(\d+)\s(.*)$/) {
            $mission_time = $1*24*3600+$2*3600+$3*60+$4;
            $speaker = $5;
            $comms = '';
            $in_comms = 1;
        }
    }
    
    
}

sub get_transcript {
    my $now = $^T;
    print "T + " . ($now - $t_zero) .  "\n" if $debug;
    my $current = $app->dbh->selectall_arrayref("select mission_time,speaker,comms from apollo_transcripts where mission_time <= ? order by mission_time desc limit 1", undef, $now-$t_zero);
    my $future = $app->dbh->selectall_arrayref("select mission_time,speaker,comms from apollo_transcripts where mission_time > ? and mission_time < ? + 10000 order by mission_time limit $n_future", undef, $now-$t_zero, $now-$t_zero);
    foreach my $f (@$future) {
        $f->[0] = $f->[0]+$t_zero;
	$f->[3] = 'right now';
    }
    if (scalar(@$current)<1) {
        die $current . scalar(@$current) . "\n" if $debug;
	$current = [0, 'LCC', 'Liftoff'];
    } else {
        $current = $current->[0];
    }
    $current->[3] = ago(-($current->[0]+$t_zero-$now),1);
    return {current=>$current,future=>$future, now=>$now, liftoff=>$t_zero, agotime=>$current->[0]+$t_zero-$now};
}


sub latintoutf8 {
	my $string = shift;
	#return $string; #dont for now
	return Encode::encode('utf8', $string);
}

sub json_out {
	my $data = shift;
	my $callback = shift;
	if ($callback) {
		return $callback . '(' . latintoutf8(objToJson($data)) . ')';
	} else {
		return latintoutf8(objToJson($data));
	}
}

sub cached_get {
	my $url = shift;
	my $data = url_from_cache($url);
	if ($data) {
		return $data;
	}
	$data = get($url);
	if ($data) {
		cache_url($url,$data);
	}
	return $data;
}


sub url_from_cache {
	my $url = shift;
	my $dr = $app->db->lastfm_cache->get({url=>$url});
	if ($dr) {
		return $dr->fields->{data};
	} else {
		return undef;
	}
}


sub cache_url {
	my $url = shift;
	my $data = shift;
	my $cache = $app->db->lastfm_cache->add;
	$cache->fields->{url} = $url;
	$cache->fields->{data} = $data;
	$cache->save;
}

__END__

create table apollo_transcripts (
    id integer not null auto_increment,
    mission_time integer,
    comms text,
    speaker varchar(50),
    primary key(id)
);

