#!/usr/bin/perl

# https://github.com/wolfgangr/evcc-KIA2P-hack/tree/main
# 
# premature sketch - not even tested
# expect:
# - your car exploding
# - your house set on fire
# - your local grid destroyed beyond repair
# - getting sued for using this piece of corrupt code



use warnings;
use strict;
use Net::MQTT::Simple;
# use JSON;
# use Data::Dumper;
# use DBD::mysql;	
# use POSIX qw(strftime);	# time string formatting
# use Time::Piece; # from POSIX time as delivered by the station to epocs for calculation


my $debug = 4;

my $mqtt_server = "homeserver.rosner.lokal";
my $topic_evcc = "evcc";
my $topic_loadpoint   = $topic_evcc   . "/loadpoints/1";

#=== end of local config ==

my $topic_chargePower =  $topic_loadpoint . "/chargePower";
my $topic_minCurrent  =  $topic_loadpoint . "/minCurrent";
my $topic_maxCurrent  =  $topic_loadpoint . "/maxCurrent";


my $mqtt = Net::MQTT::Simple->new($mqtt_server);

debug_print(1, sprintf("Listening to MQTT server at <%s>, topic <%s>\n", 
		$mqtt_server, $topic_loadpoint));


#==============

# __main__ MQTT subscription callback handler 
$mqtt->run(
        # $topic_chargePower => \&do_ecowitt,
        $topic_loadpoint . "/#" => \&parse_default,
        # "#" => \&noop,

    );

debug_print(-1, sprintf("OOPS - looks like mqtt listener died - this should not happen \n");


# noop();
exit;

#======== subs 

sub noop {
	debug_print (4, "noop\n");
}

# for debug: we may parse other messages
sub parse_default  {
            my ($topic, $message) = @_;
            debug_print (2, "default: [$topic] $message\n");
        }


# debug_print($level, $content)
sub debug_print {
  my $level = shift @_;
  print STDERR @_ if ( $level <= $debug) ;
}

