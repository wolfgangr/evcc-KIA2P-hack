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
#
# indeed - v001 did nearly anything, at least not when it should have so
# v002: try with state machine


use warnings;
use strict;
use Net::MQTT::Simple;

# allow user/pwd login
# MQTT_SIMPLE_ALLOW_INSECURE_LOGIN=1
$ENV{"MQTT_SIMPLE_ALLOW_INSECURE_LOGIN"} = 1;

# use JSON;
use Data::Dumper;
# use DBD::mysql;	
# use POSIX qw(strftime);	# time string formatting
# use Time::Piece; # from POSIX time as delivered by the station to epocs for calculation


my $debug = 5;

my $mqtt_server = "homeserver.rosner.lokal";
my $mqtt_user   = "evcc_kia";
my $mqtt_passwd = `cat /etc/evcc-k2p.secret`;
chomp $mqtt_passwd;

my $topic_evcc = "evcc";
my $topic_loadpoint   = $topic_evcc   . "/loadpoints/1";


# my $upperLimit = 5700; # 4500 ; # kW - 230 V * 8 A * 3 = 5,5 kW 
# my $lowerLimit = 3000; # 4000 ;   # kW - 230 V * 7 A * 2 = 3,2 kW

my $cutoff = 0.5 ; # mid of the limit relative to forbidden band
my $hyst  =  0.2   ; # hysteresis for trigger rel to cutoff
my $delay = 120   ; # delay in s 
my $catchband =  0.8 ; # interval in A that is considered as a hit at the other end of band

my $voltage = 225; # for power <=> current, const for now

#=== end of local config ==

# constants:
my %states_enum = (    # for check and display
  f => 'free',
  u => 'upper',
  l => 'lower',
  c => 'climbing',
  d => 'descending' 
	);

my %states_limits = (    # { lower, upper } current limits
  f => { 6, 16},
  u => { 8, 16},
  l => { 6, 7}
        );

# ==== state variables

my %state =(
  state    => 'f', 
  started  =>  0,
  updated  =>  0
); 

# my $state = 'f';
# my $tim_started = 0 ;  # when timer was started

# keep mqtt messaes as state to until complete for processing
# evcc/updated 1727972703
# my $evcc_updated =0;
my $topic_updated = $topic_evcc   . "/updated";

# evcc/loadpoints/1/chargeCurrent
# my $evcc_cCur;
my $topic_cCur = $topic_loadpoint . "/chargeCurrent";

# evcc/loadpoints/1/phasesActive
# my $evcc_phAct;
my $topic_phAct = $topic_loadpoint . "/phasesActive";

# evcc/site/gridPower 3924.7
# my $gPwr ;
my $topic_gridPower = $topic_evcc   . "/site/gridPower";

# evcc/site/homePower 4393.7
# my $hPwr ;
my $topic_homePower = $topic_evcc   . "/site/homePower";

# my $cPwr ;
my $topic_chargePower =  $topic_loadpoint . "/chargePower";


my $topic_minCurrent  =  $topic_loadpoint . "/minCurrent";
my $topic_maxCurrent  =  $topic_loadpoint . "/maxCurrent";


my $mqtt = Net::MQTT::Simple->new($mqtt_server);
$mqtt->login($mqtt_user, $mqtt_passwd);


debug_print(1, sprintf("Listening to MQTT server at <%s>, topic <%s> as user <%s> pwd=<%s>\n", 
		$mqtt_server, $topic_loadpoint, $mqtt_user, 
		substr($mqtt_passwd, 0,3) . '...' 
                       ));


#==============

# __main__ MQTT subscription callback handler 
$mqtt->run(
  # $topic_chargePower => \&do_kia_hack,

  $topic_gridPower   => sub { parse_statevar( @_[0,1], 'gPwr') }, 
  $topic_chargePower => sub { parse_statevar( @_[0,1], 'cPwr') },
  $topic_homePower   => sub { parse_statevar( @_[0,1], 'hPwr') ; doitnow() },


  $topic_evcc . "/#" => \&parse_default,
  # "#" => \&noop,

  #  parse_statevar ($topic, $message, $varnam) 

);

debug_print(-1, "OOPS - looks like mqtt listener died - this should not happen \n");

sub doitnow {
  # debug_print(4, "dummy-do-it grid: [$gPwr] home: [$hPwr] charge: [$cPwr] \n");
  debug_print(4, "dummy-do-it grid with state:\n", Dumper(\%state));
}

# noop();
exit;

#======== subs 

# sub do_kia_hack  {
#            my ($topic, $message) = @_;
#            debug_print (2, "doing kia hack with: [$topic] $message\n");
#           
#            if ($message > $upperLimit) {
#               debug_print (3, "kia hack in 'upper' branch\n");
#               $mqtt->publish( $topic_maxCurrent => "16");
#               $mqtt->publish( $topic_minCurrent => "8");
#               # $mqtt->retain( $topic => $pubstr);
#            } elsif ($message < $lowerLimit) {
#               debug_print (3, "kia hack in 'lower' branch\n");
#               $mqtt->publish( $topic_minCurrent => "6");
#               $mqtt->publish( $topic_maxCurrent => "7");
#               # $mqtt->retain( $topic => $pubstr);
#            }
#
#        }



sub noop {
	debug_print (4, "noop\n");
}

# for debug: we may parse other messages
sub parse_default  {
            my ($topic, $message) = @_;
            debug_print (4, "[$topic] $message\n");
        }

# parse into a variable with given name
sub parse_statevar {
  my ($topic, $message, $varnam) = @_;
  debug_print (4, "t=[$topic], m=[$message], v=[$varnam] \n");
  $state{$varnam} = $message;
  debug_print (3, "assigned value [$message] to \$state{$varnam} from topic [$topic] \n");
}



# debug_print($level, $content)
sub debug_print {
  my $level = shift @_;
  print STDERR @_ if ( $level <= $debug) ;
}

