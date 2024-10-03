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

my $voltage = 230; # for power <=> current, const for now

#=== end of local config ==

# constants:
my %states_enum = (    # for check and display
  f => 'free',
  u => 'upper',
  l => 'lower',
  c => 'climbing',
  d => 'descending',
  i => 'idle' 
	);

my %states_limits = (    # { lower, upper } current limits
  f => [ 6, 16 ],
  u => [ 8, 16 ],
  l => [ 6, 7 ]  );

# ===== calculated constants
my %band_marks = (
  top    => $states_limits{f}->[1],
  # top_m  => '',
  hi_min => $states_limits{u}->[0],

  # ctr_up => '',
  # center => '',
  # ctr_dn => '',

  lo_max => $states_limits{l}->[1],
  # bot_m  => '',
  bot    => $states_limits{f}->[0],
);

$band_marks{center} = ($band_marks{hi_min} + $band_marks{lo_max}) /2;
my $bandgap = $band_marks{hi_min} - $band_marks{lo_max} ;
$band_marks{cutoff} = $band_marks{hi_min} +  $cutoff * $bandgap; 
# $band_marks{cutoff} = $band_marks{lo_max};
$band_marks{cut_lo} = $band_marks{cutoff} - 0.5 * $hyst * $bandgap;
$band_marks{cut_hi} = $band_marks{cutoff} + 0.5 * $hyst * $bandgap;

$band_marks{top_m} = $band_marks{top} - $catchband ;
$band_marks{bot_m} = $band_marks{bot} + $catchband ;

debug_print(4, "\%band_marks:\n" , Dumper (\%band_marks) );
# exit;

# ==== state variables

my %state =(
  state    => 'i', 
  started  =>  0,
  updated  =>  0
); 

# keep mqtt messages as state to until complete for processing
# thou shall not use variable variables in PERL - so lets %hash
#
my $topic_updated = $topic_evcc      . "/updated";
my $topic_cCur    = $topic_loadpoint . "/chargeCurrent";
my $topic_phAct   = $topic_loadpoint . "/phasesActive";
my $topic_chrgn   = $topic_loadpoint . "/charging";


my $topic_gridPower = $topic_evcc   . "/site/gridPower";
my $topic_homePower = $topic_evcc   . "/site/homePower";
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
  $topic_gridPower   => sub { parse_statevar( @_[0,1], 'gPwr') }, 
  $topic_chargePower => sub { parse_statevar( @_[0,1], 'cPwr') },
  $topic_homePower   => sub { parse_statevar( @_[0,1], 'hPwr') ; doitnow() },
  $topic_updated     => sub { parse_statevar( @_[0,1], 'updated') },
  $topic_cCur        => sub { parse_statevar( @_[0,1], 'cCur') },
  $topic_phAct       => sub { parse_statevar( @_[0,1], 'phAct') },
  $topic_chrgn       => sub { parse_statevar( @_[0,1], 'charging') },
  $topic_minCurrent  => sub { parse_statevar( @_[0,1], 'minCurrent') },
  $topic_maxCurrent  => sub { parse_statevar( @_[0,1], 'maxCurrent') },

  $topic_evcc . "/#" => \&parse_default
  # "#" => \&noop,
  #  parse_statevar ($topic, $message, $varnam) 
);

# debug_print(-1, 
die ("OOPS - looks like mqtt listener died - this should not happen \n");
# noop();
# exit;

#======== subs 

sub doitnow {
  # debug_print(4, "dummy-do-it grid: [$gPwr] home: [$hPwr] charge: [$cPwr] \n");
  debug_print(3, sprintf("enter state machine with state [%s] (%s)", 
		$state{state}, $states_enum{$state{state}} ) );
  debug_print(99, " -\n #dummy-do-it grid with state:\n", Dumper(\%state));

  if ($state{state} eq 'c' or $state{state} eq 'd' or ! $state{state} ) {
    debug_print(0, "not yet implemented entering state maching:\n", Dumper(\%state));
    die("==== unexpected exit ===="); # ================ EMERGENCY EXIT ====
  }
  
  if ( my_is_false($state{charging})) {
    # debug_print(3, "not charging - ");
    $state{state} = 'i';
  }

  if ($state{state} eq 'i') {
    if ($state{cCur}) {
      $state{state} ='f';
    } 
  }

  # - - - - - core state machine  - - - - - - -
  if ($state{state} eq 'f') {
    if ($state{phAct} == 2) {
      $state{state} = 'l';   
    } elsif ($state{cCur} >= $band_marks{hi_min}) { 
      $state{state} = 'h';
    }

  } elsif ($state{state} eq 'h') {
    if ($state{cCur} >= $band_marks{top_m}) {
      $state{state} = 'f';
    } elsif ($state{cCur} < $band_marks{cut_lo}) {
      $state{state} = 'l';
    }


  } elsif ($state{state} eq 'l') {
    if ($state{cCur} <= $band_marks{bot_m}) {
      $state{state} = 'f';
    } elsif ($state{cCur} > $band_marks{cut_hi}) {
      $state{state} = 'h';
    }
  } 
  # - - - - - - - - - - - - - - - - - - - - - 

  debug_print(3, sprintf(" -> leaving with state [%s] (%s)\n",
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
  debug_print(99, "try to parse \%states_limits:\n", Dumper(\%states_limits));
  $mqtt->retain( $topic_minCurrent => $states_limits{$mystate}->[0]);
  $mqtt->retain( $topic_maxCurrent => $states_limits{$mystate}->[1]);
} 

# dummy callable for mqtt listener
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
  debug_print (4, "   ... t=[$topic], m=[$message], v=[$varnam] \n");
  $state{$varnam} = $message;
  debug_print (3, " - assigned value [$message] to \$state{$varnam} from topic [$topic] \n");
}



# debug_print($level, $content)
sub debug_print {
  my $level = shift @_;
  print STDERR @_ if ( $level <= $debug) ;
}

# extends builtins to 'false' 
sub my_is_false {
  my $t = shift @_;
  debug_print (99, "is <$t> false?");
  return 1 unless $t;
  return 1 if ($t eq "false");
  return 0;
}
