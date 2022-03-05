package Virtualmin::Config::Plugin::PostgreSQL;
use strict;
use warnings;
no warnings qw(once);
use parent 'Virtualmin::Config::Plugin';

our $config_directory;
our (%gconfig, %miniserv);
our $trust_unknown_referers = 1;

sub new {
  my ($class, %args) = @_;

  # inherit from Plugin
  my $self = $class->SUPER::new(name => 'PostgreSQL', %args);

  return $self;
}

# actions method performs whatever configuration is needed for this
# plugin. TODO Needs to make a backup so changes can be reverted.
sub actions {
  my $self = shift;

  use Cwd;
  my $cwd  = getcwd();
  my $root = $self->root();
  chdir($root);
  $0 = "$root/virtual-server/config-system.pl";
  push(@INC, $root);
  eval 'use WebminCore';    ## no critic
  init_config();

  if (foreign_check("postgresql")) {
    $self->spin();
    eval {
      my $err;              # We should handle errors better here.
      foreign_require("postgresql", "postgresql-lib.pl");
      if (!-r $postgresql::config{'hba_conf'}) {

        # Needs to be initialized
        $err = postgresql::setup_postgresql();
      }

      #if ($err) { # Log an error } # Something went wrong
      $self->done(1);
    };
    if ($@) {
      $self->done(0);
    }
  }
}

1;