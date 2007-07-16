package Net::Dopplr;

use strict;
use Net::Google::AuthSub;
use JSON::Any;
use URI;
use LWP::UserAgent;
use HTTP::Request::Common;

our $VERSION = '0.1';
our $AUTOLOAD;

=head1 NAME

Net::Dopplr - interface with Dopplr.com's web service

=head1 SYNOPSIS

    my $dopplr = Net::Dopplr->new($token);

    my $fellows = $dopplr->fellows('muttley');

    print "I share my trips with ".scalar(@{$fellows->{show_trips_to}})." people\n"; 
    print "I can see ".scalar(@{$fellows->{can_see_trips_of}})." people's trips\n"; 
    

=head1 GETTING A DEVELOPER TOKEN

This is a bit involved because Dopplr is still in beta.

First visit this URL

    https://www.dopplr.com/api/AuthSubRequest?next=http%3A%2F%2Fwww.example.com%2Fdopplrapi&scope=http%3A%2F%2Fwww.dopplr.com%2F&session=1

(Or you can replace next with you own web app). That will give you a developer token. 

You can then upgrade this to a permanent session token.

I use this script.

    use strict;
    use Net::Dopplr;
    use Net::Google::AuthSub;
    use LWP::UserAgent;

    my $ua = LWP::UserAgent->new;
    my $token = shift;
    my $sess;
    if (!defined $sess) {
                my $auth = Net::Google::AuthSub->new( url => 'https://www.dopplr.com/api', _bug_compat => 'dopplr');
                $auth->auth('null', $token);
                $sess    = $auth->session_token();
                print "Session token = $sess\n";
    }

    my $dopplr = Net::Dopplr->new($sess);

You can then use the session token from that point forward.

=head1 METHODS

More information here

    http://dopplr.pbwiki.com/API+Resource+URLs

=cut

=head2 new <token> 

Requires a developer token or a session token.

=cut

sub new {
    my $class = shift;
    my $token = shift;

    my $url   = 'https://www.dopplr.com/api';
    my $ua    = LWP::UserAgent->new;
    my $json  = JSON::Any->new;
    my $auth  = Net::Google::AuthSub->new(url => $url, _bug_compat => 'dopplr');
    $auth->auth('null', $token);

    return bless { _auth => $auth, _ua => $ua, _json => $json, _url => $url }, $class;
}

sub AUTOLOAD {
    my $self = shift;
    my $key  = shift;

    my $type = ref($self)
            or die "$self is not an object";

    my $name = $AUTOLOAD;
    $name =~ s/.*://;   # strip fully-qualified portion

    # die "Method $name not found\n" unless $methods{$name};

    my $uri = URI->new($self->{_url});
    $uri->path($uri->path."/$name/$key");
    $uri->query_form( format => 'js' );

    my %params = $self->{_auth}->auth_params();
    my $req    = POST "$uri", %params ;

    my $res    = $self->{_ua}->request($req);
    die "Couldn't call $name : ".$res->status_line unless $res->is_success;

    #print $res->content;

    return    $self->{_json}->decode($res->content);
}

sub DESTROY { }

=head1 TRAVELLER METHODS

=cut

=head2 fellows <traveller>

Get people <traveller> shares information with.

=cut

=head2 traveller_info <traveller> 

Get information about a traveller

=cut

=head2 trips_info <traveller>

Gte info about the trips of a traveller.

=cut

=head2 fellows_travellingtoday <traveller>

Get which of <traveller>'s fellows are travelling today.

=cut

=head2 tag <traveller>

Tag a traveller.

=cut

=head1 TRIP METHODS

=cut

=head2 trip_info <trip id>

Get info about a specific trip.

=cut

=head2 trip_tag <trip id>

Add tags to a trip

=cut

=head1 CITY METHODS

=cut

=head2 city_info <city>

Get info about a City.

=cut

=head2 city_search <city>

Find a city.

=cut

=head1 AUTHOR

Simon Wistow <simon@thegestalt.org>

=head1 COPYRIGHT

Copyright 2007, Simon Wistow

Distributed under the same terms as Perl itself.

=cut

1;
