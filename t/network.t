#!/usr/bin/perl

use strict;
use lib 't';

use FusionInventory::Agent::Network;
use FusionInventory::Agent::XML::Query::SimpleMessage;
use FusionInventory::Logger;
use FusionInventory::Test::Server;
use FusionInventory::Test::Proxy;
use Test::More;
use Test::Exception;
use Compress::Zlib;

plan tests => 43;

my $ok = sub {
    my ($server, $cgi) = @_;

    print "HTTP/1.0 200 OK\r\n";
    print "\r\n";
    print compress("hello");
};

my $logger = FusionInventory::Logger->new({
    config => { logger => 'Test' }
});

my $message = FusionInventory::Agent::XML::Query::SimpleMessage->new({
    target => { deviceid =>  'foo' },
    msg => {
        foo => 'foo',
        bar => 'bar'
    },
});

my ($network, $server, $response);

# instanciations tests

throws_ok {
    $network = FusionInventory::Agent::Network->new({});
} qr/^no URL/,
'instanciation without URL';

throws_ok {
    $network = FusionInventory::Agent::Network->new({
        url => 'foo',
    });
} qr/^no protocol for URL/,
'instanciation without protocol';

throws_ok {
    $network = FusionInventory::Agent::Network->new({
        url => 'xml://foo',
    });
} qr/^invalid protocol for URL/,
'instanciation with an invalid protocol';

throws_ok {
    $network = FusionInventory::Agent::Network->new({
        url    => 'https://localhost:8080/public',
        logger => $logger
    });
} qr/^neither certificate file or certificate directory given/,
'instanciation: https, no certificates';

# no connection tests

lives_ok {
    $network = FusionInventory::Agent::Network->new({
        url    => "http://localhost:8080/public",
        logger => $logger
    });
} 'instanciation: http';

subtest "no response" => sub {
    check_response_nok(
        scalar $network->send({ message => $message }),
        $logger,
        qr/^Can't connect to localhost:8080/
    );
};

# http connection tests

$server = FusionInventory::Test::Server->new(
    port     => 8080,
    user     => 'test',
    realm    => 'test',
    password => 'test',
);
$server->set_dispatch({
    '/public'  => $ok,
    '/private' => sub { return $ok->(@_) if $server->authenticate(); }
});
$server->background();

subtest "correct response" => sub {
    check_response_ok($network->send({ message => $message }));
};

lives_ok {
    $network = FusionInventory::Agent::Network->new({
        url    => "http://localhost:8080/private",
        logger => $logger
    });
} 'instanciation: http, auth, no credentials';

subtest "no response" => sub {
    check_response_nok(
        scalar $network->send({ message => $message }),
        $logger,
        "Authentication required",
    );
};

lives_ok {
    $network = FusionInventory::Agent::Network->new({
        url      => "http://localhost:8080/private",
        realm    => 'Authorized area',
        user     => 'test',
        password => 'test',
        logger   => $logger,
    });
} 'instanciation:  http, auth, with credentials';

subtest "correct response" => sub {
    check_response_ok($network->send({ message => $message }));
};

$server->stop();

# https connection tests

$server = FusionInventory::Test::Server->new(
    port     => 8080,
    user     => 'test',
    realm    => 'test',
    password => 'test',
    ssl      => 1,
    crt      => 't/httpd/conf/ssl/crt/good.pem',
    key      => 't/httpd/conf/ssl/key/good.pem',
);
$server->set_dispatch({
    '/public'  => $ok,
    '/private' => sub { return $ok->(@_) if $server->authenticate(); }
});
$server->background();

lives_ok {
    $network = FusionInventory::Agent::Network->new({
        url            => 'https://localhost:8080/public',
        logger         => $logger,
        'no-ssl-check' => 1,
    });
} 'instanciation: https, check disabled';

subtest "correct response" => sub {
    check_response_ok($network->send({ message => $message }));
};

lives_ok {
    $network = FusionInventory::Agent::Network->new({
        url            => "https://localhost:8080/private",
        logger         => $logger,
        'no-ssl-check' => 1,
    });
} 'instanciation: https, check disabled, auth, no credentials';

subtest "no response" => sub {
    check_response_nok(
        scalar $network->send({ message => $message }),
        $logger,
        "Authentication required",
    );
};

lives_ok {
    $network = FusionInventory::Agent::Network->new({
        url            => "https://localhost:8080/private",
        realm          => 'Authorized area',
        user           => 'test',
        password       => 'test',
        logger         => $logger,
        'no-ssl-check' => 1,
    });
} 'instanciation: https, check disabled, auth, credentials';

subtest "correct response" => sub {
    check_response_ok($network->send({ message => $message }));
};

lives_ok {
    $network = FusionInventory::Agent::Network->new({
        url            => 'https://localhost:8080/public',
        logger         => $logger,
        'ca-cert-file' => 't/httpd/conf/ssl/crt/ca.pem',
    });
} 'instanciation: https';

subtest "correct response" => sub {
    check_response_ok($network->send({ message => $message })); 
};

lives_ok {
    $network = FusionInventory::Agent::Network->new({
        url            => "https://localhost:8080/private",
        logger         => $logger,
        'ca-cert-file' => 't/httpd/conf/ssl/crt/ca.pem',
    });
} 'instanciation: https, auth, no credentials';

subtest "no response" => sub {
    check_response_nok(
        scalar $network->send({ message => $message }),
        $logger,
        "Authentication required",
    );
};

lives_ok {
    $network = FusionInventory::Agent::Network->new({
        url            => "https://localhost:8080/private",
        realm          => 'Authorized area',
        user           => 'test',
        password       => 'test',
        logger         => $logger,
        'ca-cert-file' => 't/httpd/conf/ssl/crt/ca.pem',
    });
} 'instanciation: https, auth, credentials';

subtest "correct response" => sub {
    check_response_ok($network->send({ message => $message }));
};

$server->stop();

# http connection through proxy tests

$server = FusionInventory::Test::Server->new(
    port     => 8080,
    user     => 'test',
    realm    => 'test',
    password => 'test',
);
$server->set_dispatch({
    '/public'  => sub { return $ok->(@_) if $server->{forwarded}; },
    '/private' => sub { return $ok->(@_) if $server->{forwarded} && $server->authenticate(); }
});
$server->background();

my $proxy = FusionInventory::Test::Proxy->new();
$proxy->background();

lives_ok {
    $network = FusionInventory::Agent::Network->new({
        url    => "http://localhost:8080/public",
        logger => $logger,
        proxy  => $proxy->url()
    });
} 'instanciation: http, proxy';

subtest "correct response" => sub {
    check_response_ok($network->send({ message => $message }));
};

lives_ok {
    $network = FusionInventory::Agent::Network->new({
        url    => "http://localhost:8080/private",
        logger => $logger,
        proxy  => $proxy->url()
    });
} 'instanciation: http, proxy, auth, no credentials';

subtest "no response" => sub {
    check_response_nok(
        scalar $network->send({ message => $message }),
        $logger,
        "Authentication required",
    ); 
};

lives_ok {
    $network = FusionInventory::Agent::Network->new({
        url      => "http://localhost:8080/private",
        realm    => 'Authorized area',
        user     => 'test',
        password => 'test',
        logger   => $logger,
        proxy    => $proxy->url()
    });
} 'instanciation: http, proxy, auth, credentials';

subtest "correct response" => sub {
    check_response_ok($network->send({ message => $message }));
};

$server->stop();

# https connection through proxy tests

$server = FusionInventory::Test::Server->new(
    port     => 8080,
    user     => 'test',
    realm    => 'test',
    password => 'test',
    ssl      => 1,
    crt      => 't/httpd/conf/ssl/crt/good.pem',
    key      => 't/httpd/conf/ssl/key/good.pem',
);
$server->set_dispatch({
    '/public'  => sub { return $ok->(@_) if $server->{forwarded}; },
    '/private' => sub { return $ok->(@_) if $server->{forwarded} && $server->authenticate(); }
});
$server->background();

lives_ok {
    $network = FusionInventory::Agent::Network->new({
        url            => 'https://localhost:8080/public',
        logger         => $logger,
        'no-ssl-check' => 1,
        proxy          => $proxy->url()
    });
} 'instanciation: https, proxy, check disabled';

subtest "correct response" => sub {
    check_response_ok($network->send({ message => $message }));
};

lives_ok {
    $network = FusionInventory::Agent::Network->new({
        url            => "https://localhost:8080/private",
        logger         => $logger,
        'no-ssl-check' => 1,
        proxy          => $proxy->url()
    });
} 'instanciation: https, check disabled, proxy, auth, no credentials';

subtest "no response" => sub {
    check_response_nok(
        scalar $network->send({ message => $message }),
        $logger,
        "Authentication required",
    );
};

lives_ok {
    $network = FusionInventory::Agent::Network->new({
        url            => "https://localhost:8080/private",
        realm          => 'Authorized area',
        user           => 'test',
        password       => 'test',
        logger         => $logger,
        'no-ssl-check' => 1,
        proxy          => $proxy->url()
    });
} 'instanciation: https, check disabled, proxy, auth, credentials';

subtest "correct response" => sub {
    check_response_ok($network->send({ message => $message }));
};

lives_ok {
    $network = FusionInventory::Agent::Network->new({
        url            => 'https://localhost:8080/public',
        logger         => $logger,
        'ca-cert-file' => 't/httpd/conf/ssl/crt/ca.pem',
        proxy          => $proxy->url()
    });
} 'instanciation: https';

subtest "correct response" => sub {
    check_response_ok($response = $network->send({ message => $message })); 
};

lives_ok {
    $network = FusionInventory::Agent::Network->new({
        url            => "https://localhost:8080/private",
        logger         => $logger,
        'ca-cert-file' => 't/httpd/conf/ssl/crt/ca.pem',
        proxy          => $proxy->url()
    });
} 'instanciation: https, proxy, auth, no credentials';

subtest "no response" => sub {
    check_response_nok(
        scalar $network->send({ message => $message }),
        $logger,
        "Authentication required",
    ); 
};

lives_ok {
    $network = FusionInventory::Agent::Network->new({
        url            => "https://localhost:8080/private",
        realm          => 'Authorized area',
        user           => 'test',
        password       => 'test',
        logger         => $logger,
        'ca-cert-file' => 't/httpd/conf/ssl/crt/ca.pem',
        proxy          => $proxy->url()
    });
} 'instanciation: https, proxy, auth, credentials';

subtest "correct response" => sub {
    check_response_ok($network->send({ message => $message }));
};

$server->stop();
$proxy->stop();

# compression tests

my $data = "this is a test";
is(
    $network->_uncompressNative($network->_compressNative($data)),
    $data,
    'round-trip compression with Compress::Zlib'
);

is(
    $network->_uncompressGzip($network->_compressGzip($data)),
    $data,
    'round-trip compression with Gzip'
);

sub check_response_ok {
    my ($response) = @_;

    plan tests => 3;
    ok(defined $response, "response from server");
    isa_ok(
        $response,
        'FusionInventory::Agent::XML::Response',
        'response class'
    );
    is($response->getContent(), 'hello', 'response content');
}

sub check_response_nok {
    my ($response, $logger, $message) = @_;

    plan tests => 3;
    ok(!defined $response,  "no response");
    is(
        $logger->{backend}->[0]->{level},
        'error',
        "error message level"
    );
    if (ref $message eq 'Regexp') {
        like(
            $logger->{backend}->[0]->{message},
            $message,
            "error message content"
        );
    } else {
        is(
            $logger->{backend}->[0]->{message},
            $message,
            "error message content"
        );
    }
}
