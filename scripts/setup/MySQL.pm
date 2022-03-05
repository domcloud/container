package Virtualmin::Config::Plugin::MySQL;
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
  my $self = $class->SUPER::new(name => 'MySQL', %args);

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

  $self->spin();
  eval {
    foreign_require("mysql", "mysql-lib.pl");
    my $conf = mysql::get_mysql_config();
    my ($sect) = grep { $_->{'name'} eq 'mysqld' } @$conf;
    if ($sect) {
      mysql::save_directive($conf, $sect, "innodb_file_per_table", [1]);
      flush_file_lines($sect->{'file'});
    }
    $self->done(1);
  };
  if ($@) {
    $self->done(0);
  }
}

1;