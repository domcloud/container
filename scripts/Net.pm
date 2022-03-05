package Virtualmin::Config::Plugin::Net;
use strict;
use warnings;
no warnings qw(once);
use parent 'Virtualmin::Config::Plugin';

our $config_directory;
our (%gconfig, %miniserv);
our $trust_unknown_referers = 1;

my $log = Log::Log4perl->get_logger("virtualmin-config-system");

sub new {
  my ($class, %args) = @_;

  # inherit from Plugin
  my $self = $class->SUPER::new(name => 'Net', %args);

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
    if (foreign_check("net")) {
      foreign_require("net", "net-lib.pl");
      my $dns = net::get_dns_config();
      if (indexof("127.0.0.1", @{$dns->{'nameserver'}}) < 0) {
        unshift(@{$dns->{'nameserver'}}, "127.0.0.1");
        net::save_dns_config($dns);
      }

      # Force 127.0.0.1 into name servers in resolv.conf
      # XXX This shouldn't be necessary. There's some kind of bug in net::
    #   my $resolvconf = '/etc/resolv.conf';
    #   my $rlref      = read_file_lines($resolvconf);
    #   if (indexof('nameserver 127.0.0.1'), @{$rlref} < 0) {
    #     $log->info("Adding name server 127.0.0.1 to resolv.conf.");
    #     unshift(@{$rlref}, 'nameserver 127.0.0.1');
    #     unshift(@{$rlref}, '# Added by Virtualmin.');
    #   }
    #   flush_file_lines($resolvconf);

      # On Debian/Ubuntu, if there are extra interfaces files, we need
      # to update them, too.
      # Check for additional included config files.
      my @interfaces_d = glob "/etc/network/interfaces.d/*";
      if (@interfaces_d) {

        # Find all of the dns-nameservers entries and update'em
        foreach my $includefile (@interfaces_d) {
          open my $fh, "<", $includefile
            or
            $log->warning("Failed to open network config file: $includefile.");
          close $fh;
        }
      }

      # Check to see if we're configured with dhcp.
      my @dhcp = grep { $_->{'dhcp'} } net::boot_interfaces();
      foreach my $includefile (@interfaces_d) {
        open my $fh, '<', $includefile or die;
        while (my $line = <$fh>) {

          # This is not smart.
          if ($line =~ /inet .* dhcp/) {
            push @dhcp, "1";    # Just stick something truthy in there.
          }
        }
      }
      if (@dhcp) {
        $log->warn(
          "Detected DHCP-configured network. This probably isn't ideal.");
        my $lref;
        my $file = '/etc/dhcp/dhclient.conf';
        if (-e $file) {
          $lref = read_file_lines($file);
          if (indexof("prepend domain-name-servers 127.0.0.1;", @{$lref}) < 0) {
            $log->info(
              "Attempting to add name server 127.0.0.1 to dhcp configuration.");
            push(@{$lref}, 'prepend domain-name-servers 127.0.0.1;');
            push(@{$lref}, '# Added by Virtualmin.');
          }
          flush_file_lines($file);
        }
      }

      # Restart Postfix so that it picks up the new resolv.conf
    #   foreign_require("virtual-server");
    #   virtual_server::stop_service_mail();
    #   virtual_server::start_service_mail();
    }
    $self->done(1);    # OK!
  };
  if ($@) {
    $self->done(0);
  }
}

1;