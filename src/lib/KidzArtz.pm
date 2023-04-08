use Dancer2 appname => 'Web';
use HTTP::API::Client;
use URI;

my $SOURCE_SITE = URI->new( $ENV{SOURCE_SITE} );

sub _browser_id {
    'Mozilla/'
        . [ 1 .. 5 ]->[ rand 5 ] . '.'
        . [ 0 .. 12 ]->[ rand 13 ] . ' ('
        . [ 'Macintosh', 'Windows', 'Linux' ]->[ rand 2 ] . '; '
        . [ 'Intel',     'AMD',     'ARM' ]->[ rand 3 ]
        . ') AppleWebKit/'
        . [ 412 .. 693 ]->[ rand 281 ] . '.'
        . [ 10 .. 50 ]->[ rand 40 ]
        . ' (KHTML, like Gecko) Chrome/'
        . [ 50 .. 112 ]->[ rand 62 ] . '.'
        . [ 0 .. 9 ]->[ rand 10 ] . '.'
        . [ 0 .. 9 ]->[ rand 10 ] . '.'
        . [ 0 .. 9 ]->[ rand 10 ];
}

sub _fetch {
    my $method  = request->method;
    my $path    = request->path;
    my @headers = request->headers->flatten;

    my $browser = HTTP::API::Client->new(
        browser_id   => _browser_id,
        content_type => 'application/x-www-form-urlencoded',
    );

    my $url = $SOURCE_SITE->clone;
    $url->path($path);

    if ( $method eq 'GET' ) {
        $url->query_form( query_parameters->flatten );
    }
    elsif ( $method eq 'POST' ) {
        $url->query_form( request->body_parameters,
            query_parameters->flatten );
    }

    return bless {
        response => $BROWSER->$method( "$url", {}, {@headers} ),
    }, __PACKAGE__;
}

sub _clean_headers {
    my ($self) = @_;

    my @blacklist = qw(
        x-powered-by
        server
        report-to
        nel
        date
        connection
        client-ssl-.*
        cf-.*
    );

    my $h = $self->response->headers;

    foreach my $key (@blacklist) {
        if ( $key !~ /\.\*/ ) {
            $h->remove_header($key);
        }
        else {
            foreach my $field ( $h->header_field_names ) {
                if ( $field =~ m/^$key/i ) {
                    $h->remove_header($field);
                }
            }
        }
    }

    foreach my $field ( $h->header_field_names ) {
        header $field => $h->header($field);
    }

    return $self;
}

sub _render {
    my ($self) = @_;
    return $self->response->decoded_content;
}

any qr/.*/ => sub {
    if (request->path =~m /\.(xml|gz|jpg|jpeg|png|pdf|svg|)$/i) {
        redirect request->path;
    }
    else {
        _fetch->_clean_headers->_render;
    }

};

1;
