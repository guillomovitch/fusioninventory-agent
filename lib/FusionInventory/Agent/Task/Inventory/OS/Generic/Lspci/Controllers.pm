package FusionInventory::Agent::Task::Inventory::OS::Generic::Lspci::Controllers;
use strict;
use warnings;

use English qw(-no_match_vars);

use FusionInventory::Agent::Tools;

sub isInventoryEnabled {
    return can_run("lspci");
}

sub doInventory {
    my $params = shift;
    my $config = $params->{config};
    my $inventory = $params->{inventory};
    my $logger = $params->{logger};

    my $controllers = getExtentedControllers($logger, $config->{'share-dir'});

    return unless $controllers;

    foreach my $controller (@$controllers) {
        $inventory->addController($controller);
    }
}

sub getExtentedControllers {
    my ($logger, $sharedir, $file) = @_;

    my $controllers = getControllersFromLspci($file);

    foreach my $controller (@$controllers) {
        my $info = getInfoFromPciIds ({
            sharedir       => $sharedir,
            logger         => $logger,
            pciclass       => $controller->{PCICLASS},
            pciid          => $controller->{PCIID},
            pcisubsystemid => $controller->{PCISUBSYSTEMID},
        });
        $controller->{CAPTION}      = $info->{deviceName};
        $controller->{TYPE}         = $info->{fullClassName},
        $controller->{NAME}         = $info->{fullName} if $info->{fullName};
        $controller->{MANUFACTURER} = $info->{vendorName} if $info->{vendorName};
    }

    return $controllers;
}

# Retrieve information from the pciid file
sub getInfoFromPciIds {
    my ($params) = @_;

    my $sharedir = $params->{sharedir};
    my $logger = $params->{logger};
    my $pciclass = $params->{pciclass};
    my $pciid = $params->{pciid};
    my $pcisubsystemid = $params->{pcisubsystemid};

    return unless $pciid;

    my ($vendorId, $deviceId) = split (/:/, $pciid);
    my ($subVendorId, $subDeviceId) = split (/:/, $pcisubsystemid || '');
    my $deviceName;
    my $subDeviceName;
    my $classId;
    my $subClassId;

    if ($pciclass && $pciclass =~ /^(\S\S)(\S\S)$/) {
        $classId = $1;
        $subClassId = $2;
    }

    return {} unless $vendorId;

    my %ret;
    my %current;
    if (!open PCIIDS, "<", "$sharedir/pci.ids") {
        $logger->error("Failed to open $sharedir/pci.ids");
        return;
    }
    foreach (<PCIIDS>) {
        next if /^#/;

        if (/^(\S{4})\s+(.*)/) { # Vendor ID
            $current{classId} = '';
            $current{vendorId} = lc($1);
            $current{vendorName} = $2;
            $current{deviceName} = '';
            $current{subVendorId} = '';
            $current{subDeviceId} = '';

# information found in the previous section
#            return \%ret if keys %ret;
        } elsif (/^\t(\S{4})\s+(.*)/) { # Device ID
            $current{deviceId} = lc($1);
            $current{deviceName} = $2;
            $current{subVendorId} = '';
            $current{subDeviceId} = '';
        } elsif (/^\t\t(\S{4})\s(\S{4})\s(.*)/) { # Subdevice ID
            $current{subVendorId} = lc($1);
            $current{subDeviceId} = lc($2);
            $current{subDeviceName} = $3;
        } elsif (/^C\s(\S{2})\s\s(.*)/) { # Class ID
            $current{vendorId} = '';
            $current{vendorName} = '';
            $current{deviceName} = '';
            $current{subVendorId} = '';
            $current{subDeviceId} = '';
            $current{classId} = $1;
            $current{className} = $2;
        } elsif (/^\t(\S{2})\s\s(.*)/) { # SubClass ID
            $current{subClassId} = $1;
            $current{subClassName} = $2;
        } 

        if (!$ret{subDeviceName} && $current{vendorName} && $current{deviceName}) {
            if ($vendorId eq $current{vendorId}) {
                $ret{vendorName} = $current{vendorName};
                if ($deviceId eq $current{deviceId}) {
                    $ret{deviceName} = $current{deviceName};
                    $ret{fullName} = $current{deviceName};

                    if ($subVendorId && $subDeviceId) {
                        if ($subVendorId eq $current{subVendorId}) {
                            if ($subDeviceId eq $current{subDeviceId}) {
                                $ret{subDeviceName} = $current{subDeviceName};
                                $ret{fullName} =$current{subDeviceName};
                            }
                        }
                    }
                }
            }
        }
        if (defined($current{classId}) && $classId && ($classId eq $current{classId})) {
            $ret{className} = $current{className};
            $ret{fullClassName} = $current{className};
            if ($subClassId eq $current{subClassId}) {
                $ret{subClassName} = $current{subClassName};
                $ret{fullClassName} = $current{subClassName};
            }
        }
    }

    return \%ret;
}

1;
