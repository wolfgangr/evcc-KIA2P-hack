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
my $topic_chargePower =  $topic_loadpoint . "/chargePower";
my $topic_minCurrent  =  $topic_loadpoint . "/minCurrent";
my $topic_maxCurrent  =  $topic_loadpoint . "/maxCurrent";

noop();
exit;

#======== subs 

sub noop {
	debug_print (4, "noop\n");
}


# debug_print($level, $content)
sub debug_print {
  my $level = shift @_;
  print STDERR @_ if ( $level <= $debug) ;
}

