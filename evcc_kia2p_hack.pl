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
# v002            alpha test state machine
# v003            max complexity
# v004            alpha test moving average


use warnings;
use strict;
use Net::MQTT::Simple;

# allow user/pwd login
$ENV{"MQTT_SIMPLE_ALLOW_INSECURE_LOGIN"} = 1;

use Data::Dumper;
use POSIX qw(strftime);	# time string formatting

# debug levels ~~~~
# 5 = local testing, 4 = early context testing , 3 = early running tests, 
#    2 = operation test, 1 = operation running in beta, 0 = stable
my $debug = 2;

my $mqtt_server = "homeserver.rosner.lokal";
my $mqtt_user   = "evcc_kia";
my $mqtt_passwd = `cat /etc/evcc-k2p.secret`;
chomp $mqtt_passwd;

my $topic_evcc = "evcc";
my $topic_loadpoint   = $topic_evcc   . "/loadpoints/1";

my $avgAvailStart = 0 ;    # start value to calc moving average
my $avgAlpha = 0.1  ; # see https://en.wikipedia.org/wiki/Exponential_smoothing#Time_constant
	# time contant ~ 5min
my $thresholdHI = 5000; # W to switch to 3P-Mode above
my $thresholdLO = 4000; # W to switch to 2P-Mode below

# my $voltage = 230; # for power <=> current, const for now

#=== end of local config ==

# constants:
my %states_enum = (    # for check and display
  f => 'free',
  h => 'high',
  l => 'low',
  i => 'idle',
  n => 'not in PV mode'
	);

my %states_limits = (    # { lower, upper } current limits
  f => [ 6, 16 ],
  h => [ 8, 16 ],
  l => [ 6, 6 ]  );


# ==== state variables

my %state =(
  state    => 'i', 
  # started  =>  0,
  # updated  =>  0,
  min_saved => 6,
  max_saved => 16,
  mode      => 'undefined',
); 

# keep mqtt messages as state to until complete for processing
# thou shall not use variable variables in PERL - so lets %hash
#
my $topic_updated = $topic_evcc      . "/updated";
my $topic_mode    = $topic_loadpoint . "/mode";

my $topic_cCur    = $topic_loadpoint . "/chargeCurrent";
my $topic_phAct   = $topic_loadpoint . "/phasesActive";
my $topic_chrgn   = $topic_loadpoint . "/charging";


my $topic_gridPower = $topic_evcc   . "/site/gridPower";
my $topic_homePower = $topic_evcc   . "/site/homePower";
my $topic_battPower = $topic_evcc   . "/site/batteryPower";

my $topic_chargePower =  $topic_loadpoint . "/chargePower";

my $topic_minCurrent  =  $topic_loadpoint . "/minCurrent";
my $topic_maxCurrent  =  $topic_loadpoint . "/maxCurrent";

my  $topic_planActive  =  $topic_loadpoint . "/planActive";
my  $topic_sCActive    =  $topic_loadpoint . "/smartCostActive";





my $mqtt = Net::MQTT::Simple->new($mqtt_server);
$mqtt->login($mqtt_user, $mqtt_passwd);


debug_print(1, sprintf("Listening to MQTT server at <%s>, topic <%s> as user <%s> pwd=<%s>\n", 
		$mqtt_server, $topic_loadpoint, $mqtt_user, 
		substr($mqtt_passwd, 0,3) . '...' 
                       ));


#==============

# __main__ MQTT subscription callback handler 
$mqtt->run(
  $topic_gridPower   => sub { parse_statevar( @_[0,1], 'gPwr') }, 
  $topic_chargePower => sub { parse_statevar( @_[0,1], 'cPwr') },
  $topic_homePower   => sub { parse_statevar( @_[0,1], 'hPwr') ; doitnow() },
  $topic_battPower   => sub { parse_statevar( @_[0,1], 'battPwr') },
  $topic_updated     => sub { parse_statevar( @_[0,1], 'updated') },
  $topic_mode        => sub { parse_statevar( @_[0,1], 'mode') },
  $topic_cCur        => sub { parse_statevar( @_[0,1], 'cCur') },
  $topic_phAct       => sub { parse_statevar( @_[0,1], 'phAct') },
  $topic_chrgn       => sub { parse_statevar( @_[0,1], 'charging') },
  $topic_minCurrent  => sub { parse_statevar( @_[0,1], 'minCurrent') },
  $topic_maxCurrent  => sub { parse_statevar( @_[0,1], 'maxCurrent') },
  $topic_planActive  => sub { parse_statevar( @_[0,1], 'planActive') },
  $topic_sCActive    => sub { parse_statevar( @_[0,1], 'smartCostActive') },

  $topic_evcc . "/#" => \&parse_default
  # "#" => \&noop,
  #  parse_statevar ($topic, $message, $varnam) 
);

die ("OOPS - looks like mqtt listener died - this should not happen \n");
# exit;

#======== subs 

my $avgAvail = $avgAvailStart;

sub doitnow {
  debug_print(4, " -\n #dummy-do-it grid with state:\n", Dumper(\%state));
  my $datetime = strftime("%F - %T", localtime($state{updated}) );
  debug_print(2, sprintf("%s: enter state: %s (%s)", 
		$datetime, $state{state}, $states_enum{$state{state}} ) );

  # if ($state{state} eq 'c' or $state{state} eq 'd' or ! $state{state} ) {
  unless (defined $state{state} and $state{state} ) {
    debug_print(0, "not yet implemented entering state maching:\n", Dumper(\%state));
    die("==== unexpected exit ===="); # ================ EMERGENCY EXIT ====
  }
 
  # calc moving average of available PV for charging
  my $PVchgPwrAvail = $state{cPwr} - $state{gPwr} - $state{battPwr};
  debug_print(3, sprintf("\n available = %d W (cPwr(= %dW) - gPwr(= %dW) - battPwr(= %dW)",
	$PVchgPwrAvail, $state{cPwr} , $state{gPwr} , $state{battPwr} ) ); 

  $avgAvail =  (1 - $avgAlpha ) * $avgAvail + $avgAlpha * $PVchgPwrAvail;
  debug_print(3, sprintf(" - new moving average: %d W\n", $avgAvail ) );

  # - - - - - start state machine - - - - - - -

  my $rapid = 1;
  if ($state{mode}        eq       'pv') { $rapid = 0 ; }
  if ($state{mode}        eq    'minpv') { $rapid = 0 ; }
  if ($state{planActive}      eq 'true') { $rapid = 1 ; }
  if ($state{smartCostActive} eq 'true') { $rapid = 1 ; }

  if ( my_is_false($state{charging})) {
    # debug_print(3, "not charging - ");
    $state{state} = 'i';
  }

  # - - - - - PV mode on/off - - - - -
#  if (  ($state{mode} ne 'pv' and $state{mode} ne 'minpv')  
#          or $state{planActive} eq 'true'
#          or $state{smartCostActive} eq 'true'
#      ) { 



   if($rapid) {
    # if ($state{state} eq 'n') {
      debug_print(4,"... in mode other than PV ..."); 
      return; # ==== nothing to do
      debug_print(2,"stay\n");
    } elsif ($state{state} eq 'i') { # transition ....
      debug_print(2, "i -> n, restoring limits\n");
      $mqtt->retain( $topic_minCurrent . '/set' => $state{min_saved}  ) ;
      $mqtt->retain( $topic_maxCurrent . '/set' => $state{max_saved}  ) ;
      $state{state} = 'n';
      return; # ==== restored saved current limits

    } else {  # leave mode over state i 
      debug_print(2, "left PV mode, switch to 'i'\n");
      $state{state} = 'i';
    }
  #}

  if ($state{state} eq 'n') { # and mode is pv or minpv - see above
    debug_print(2,"n -> entering PV mode, save limits, switch to 'i'\n");
    $state{min_saved} = $state{minCurrent};
    $state{max_saved} = $state{maxCurrent};
    debug_print(4, "  - saved - \%state:\n", Dumper(\%state));
    $state{state} = 'i';

  }


  # - - - - - core state machine  - - - - - - -
  if ($state{state} eq 'f' or $state{state} eq 'h' or $state{state} eq 'l' ) {  # handle state f='free'
    if ( $avgAvail <= $thresholdLO) {
      $state{state} = 'l';   
    } elsif ( $avgAvail >= $thresholdHI) {
      $state{state} = 'h';
    }
  }
  # - - - - - - - - - - - - - - - - - - - - - 

  # transition i -> f -> h/l
  # idea was to allow charger / car to choose where we start?
  # this most times peaks w/ high current/3P
  if ($state{state} eq 'i') {
    if ($state{cCur}) {
      $state{state} ='f';
    }
  }

  debug_print(2, sprintf(" => leave: %s (%s)\n",
                $state{state}, $states_enum{$state{state}} ) );

  if ($state{state} eq 'c' or $state{state} eq 'd' or ! $state{state} ) {
    debug_print(0, "not yet implemented leaving state maching:\n", Dumper(\%state));
    die("==== unexpected exit ===="); # ================ EMERGENCY EXIT ====
  }


  if ($state{state} eq 'i') { 
    set_current_limits('f');
  } else {
    set_current_limits($state{state});
  }
} # ------------- end of doitnow -------------------------------------------------------------------


sub set_current_limits {
  my ($mystate) = @_;

  # debug_print(99, "try to parse \%states_limits:\n", Dumper(\%states_limits));
  debug_print(2, sprintf( "   ... set current limits to [ %dA ... %dA ] \n", 
	$states_limits{$mystate}->[0], $states_limits{$mystate}->[1] ));
  $mqtt->retain( $topic_minCurrent . '/set' => $states_limits{$mystate}->[0]);
  $mqtt->retain( $topic_maxCurrent . '/set' => $states_limits{$mystate}->[1]);
} 

# dummy callable for mqtt listener
sub noop {
	debug_print (4, "noop\n");
}

# for debug: we may parse other messages
sub parse_default  {
            my ($topic, $message) = @_;
            debug_print (5, "[$topic] $message\n");
        }

# parse into a variable with given name
sub parse_statevar {
  my ($topic, $message, $varnam) = @_;
  debug_print (5, "   ... t=[$topic], m=[$message], v=[$varnam] \n");
  $state{$varnam} = $message;
  debug_print (4, " - assigned value [$message] to \$state{$varnam} from topic [$topic] \n");
}



# debug_print($level, $content)
sub debug_print {
  my $level = shift @_;
  print STDERR @_ if ( $level <= $debug) ;
}

# extends builtins to 'false' 
sub my_is_false {
  my $t = shift @_;
  # debug_print (99, "is <$t> false?");
  return 1 unless $t;
  return 1 if ($t eq "false");
  return 0;
}
