#!/usr/bin/perl

use strict;
use warnings;

use Config;
use English qw(-no_match_vars);
use File::Temp qw(tempdir);
use Test::More;
use Test::Exception;
use URI;

use FusionInventory::Agent::Controller;

plan tests => 10;

my $controller;
throws_ok {
    $controller = FusionInventory::Agent::Controller->new();
} qr/^no url parameter/,
'instanciation: no url';

throws_ok {
    $controller = FusionInventory::Agent::Controller->new(
        url => 'http://foo/bar'
    );
} qr/^no basevardir parameter/,
'instanciation: no base directory';

my $basevardir = tempdir(CLEANUP => $ENV{TEST_DEBUG} ? 0 : 1);

lives_ok {
    $controller = FusionInventory::Agent::Controller->new(
        url        => 'http://my.domain.tld/ocsinventory',
        basevardir => $basevardir
    );
} 'instanciation: ok';

my $storage_dir = $OSNAME eq 'MSWin32' ?
    "$basevardir/http..__my.domain.tld_ocsinventory" :
    "$basevardir/http:__my.domain.tld_ocsinventory" ;
ok(-d $storage_dir, "storage directory creation");
is($controller->{id}, 'server0', "identifier");

$controller = FusionInventory::Agent::Controller->new(
    url        => 'http://my.domain.tld',
    basevardir => $basevardir
);
is($controller->getUrl(), 'http://my.domain.tld/ocsinventory', 'missing path');

$controller = FusionInventory::Agent::Controller->new(
    url        => 'my.domain.tld',
    basevardir => $basevardir
);
is($controller->getUrl(), 'http://my.domain.tld/ocsinventory', 'bare hostname');

is($controller->getMaxDelay(), 3600, 'default value');
my $nextRunDate = $controller->getNextRunDate();

ok(-f "$storage_dir/target.dump", "state file existence");
$controller = FusionInventory::Agent::Controller->new(
    url        => 'http://my.domain.tld/ocsinventory',
    basevardir => $basevardir
);
is($controller->getNextRunDate(), $nextRunDate, 'state persistence');
