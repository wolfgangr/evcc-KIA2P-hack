#!/usr/bin/perl

# https://github.com/wolfgangr/evcc-KIA2P-hack/tree/main
# 
# premature sketch - not even tested
# expect:
# - your wallbox going bust
# - your car exploding
# - your house set on fire
# - your local grid destroyed beyond repair
# - getting jailed for using this piece of corrupt code



use warnings;
use strict;
use Net::MQTT::Simple;
# use JSON;
# use Data::Dumper;
# use DBD::mysql;	
# use POSIX qw(strftime);	# time string formatting
# use Time::Piece; # from POSIX time as delivered by the station to epocs for calculation


my $debug = 3;

my $mqtt_server = "homeserver.rosner.lokal";
my $topic_evcc = "evcc";
my $topic_loadpoint   = $topic_evcc   . "/loadpoints/1";


my $upperLimit = 4.5 ; # kW - 230 V * 8 A * 3 = 5,5 kW 
my $lowerLimit = 4 ;   # kW - 230 V * 7 A * 2 = 3,2 kW

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
        $topic_chargePower => \&do_kia_hack,
        $topic_loadpoint . "/#" => \&parse_default,
        # "#" => \&noop,

    );

debug_print(-1, "OOPS - looks like mqtt listener died - this should not happen \n");


# noop();
exit;

#======== subs 

sub do_kia_hack  {
            my ($topic, $message) = @_;
            debug_print (2, "doing kia hack with: [$topic] $message\n");
           
            if ($message > $upperLimit) {
               debug_print (3, "kia hack in 'upper' branch\n");
               $mqtt->publish( $topic_maxCurrent => "16");
               $mqtt->publish( $topic_minCurrent => "8");
               # $mqtt->retain( $topic => $pubstr);
            } elsif ($message < $lowerLimit) {
               debug_print (3, "kia hack in 'lower' branch\n");
               $mqtt->publish( $topic_minCurrent => "6");
               $mqtt->publish( $topic_maxCurrent => "7");
               # $mqtt->retain( $topic => $pubstr);
            }

        }



sub noop {
	debug_print (4, "noop\n");
}

# for debug: we may parse other messages
sub parse_default  {
            my ($topic, $message) = @_;
            debug_print (4, "[$topic] $message\n");
        }





# debug_print($level, $content)
sub debug_print {
  my $level = shift @_;
  print STDERR @_ if ( $level <= $debug) ;
}

