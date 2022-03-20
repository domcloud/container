package Virtualmin::Config::Plugin::Bind;
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
  my $self = $class->SUPER::new(name => 'Bind', %args);

  return $self;
}

# actions method performs whatever configuration is needed for this
# plugin. XXX Needs to make a backup so changes can be reverted.
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
    foreign_require("init", "init-lib.pl");
    foreign_require("bind8", "bind8-lib.pl");
    my $conffile = bind8::make_chroot($bind8::config{'named_conf'});
    if (!-r $conffile) {
      $bind8::config{'named_conf'} =~ /^(\S+)\/([^\/]+)$/;
      my $conf_directory = $1;
      my $pid_file       = $bind8::config{'pid_file'} || "/var/run/named.pid";
      my $pid_dir;

      # Make sure all directories used by BIND exist
      my $chroot = bind8::get_chroot();
      if ($chroot && !-d $chroot) {
        mkdir($chroot, oct(755));
      }
      if (!-d bind8::make_chroot($conf_directory)) {
        mkdir(bind8::make_chroot($conf_directory), oct(755));
      }
      if ($bind8::config{'master_dir'}
        && !-d bind8::make_chroot($bind8::config{'master_dir'}))
      {
        mkdir(bind8::make_chroot($bind8::config{'master_dir'}), oct(755));
      }
      if ($bind8::config{'slave_dir'}
        && !-d bind8::make_chroot($bind8::config{'slave_dir'}))
      {
        mkdir(bind8::make_chroot($bind8::config{'slave_dir'}), oct(777));
      }
      if ($pid_file =~ /^(.*)\//) {
        $pid_dir = $1;
        if (!-d bind8::make_chroot($pid_dir)) {
          mkdir(bind8::make_chroot($pid_dir), oct(777));
        }
      }

      # Need to setup named.conf file, with root zone
      open(my $BOOT, ">", "$conffile");
      print $BOOT "options {\n";
      print $BOOT "    directory \"$conf_directory\";\n";
      print $BOOT "    pid-file \"$pid_file\";\n";
      print $BOOT "    allow-recursion { localnets; 127.0.0.1; };\n";
      print $BOOT "    };\n";
      print $BOOT "\n";
      print $BOOT "zone \".\" {\n";
      print $BOOT "    type hint;\n";
      print $BOOT "    file \"$conf_directory/db.cache\";\n";
      print $BOOT "    };\n";
      print $BOOT "\n";
      close($BOOT);
      system("cp $root/bind8/db.cache "
          . bind8::make_chroot("$conf_directory/db.cache"));
      bind8::set_ownership(bind8::make_chroot("$conf_directory/db.cache"));
      bind8::set_ownership($conffile);
    }

    # Remove any options that would make BIND listen on localhost only
    undef(@bind8::get_config_cache);
    my $conf    = bind8::get_config();
    my $options = bind8::find("options", $conf);
    if ($options) {
      bind8::save_directive($options, "allow-query", [], 0);
      foreach my $dir ("listen-on", "listen-on-v6") {
        my @listen = bind8::find($dir, $options->{'members'});
        next if (!@listen);

        # XXX This is ridiculous.
        next
          if (!defined($listen[0]->{'values'})
          || !defined($listen[0]->{'values'}->[0])
          || !defined($listen[0]->{'values'}->[1])
          || !defined($listen[0]->{'type'})
          || !defined($listen[0]->{'members'})
          || !defined($listen[0]->{'members'}->[0]->{'name'}));
        if (
             $listen[0]->{'values'}->[0] eq 'port'
          && $listen[0]->{'values'}->[1] eq '53'
          && $listen[0]->{'type'}
          && ( $listen[0]->{'members'}->[0]->{'name'} eq '127.0.0.1'
            || $listen[0]->{'members'}->[0]->{'name'} eq '::1')
          )
        {
          $listen[0]->{'members'}->[0]->{'name'} = 'any';
        }
        bind8::save_directive($options, $dir, \@listen, 1);
      }
      bind8::flush_file_lines();
    }

    $self->done(1);    # OK!
  };
  if ($@) {
    $self->done(0);
  }
}

1;