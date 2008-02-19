package Net::Dopplr;

use strict;
use Net::Google::AuthSub;
use JSON::Any;
use URI;
use LWP::UserAgent;
use HTTP::Request::Common;

our $VERSION = '0.5';
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
    use Net::Google::AuthSub;

    my $token = shift;
    my $auth = Net::Google::AuthSub->new( url => 'https://www.dopplr.com/api');
   
    $auth->auth('null', $token);
    my $sess    = $auth->session_token() || die "Couldn't get token: $@";
    print "Session token = $sess\n";

and then later

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
    my $auth  = Net::Google::AuthSub->new(url => $url);
    $auth->auth('null', $token);

    return bless { _auth => $auth, _ua => $ua, _json => $json, _url => $url }, $class;
}

my %methods = (
    fellows                 => 'traveller', 
    traveller_info          => 'traveller',
    trips_info              => 'traveller',
    future_trips_info       => 'traveller',
    fellows_travellingtoday => 'traveller',
    tag                     => 'traveller',
    location_on_date        => 'traveller',
 
    trip_info               => 'trip',
    add_trip_tags           => 'trip',
    add_trip_note           => 'trip',
    delete_trip             => 'trip',

    city_info               => 'city',
    add_trip                => 'city',

    search                  => 'search',
    city_search             => 'search',
    traveller_search        => 'search',
);

my %key_names = (
    traveller => 'traveller',
    trip      => 'trip_id',
    city      => 'geoname_id',
    search    => 'q',
);


my %post = map { $_ => 1 } qw(add_trip_tags 
                              add_trip_note 
                              delete_trip
                              add_trip
                              update_traveller);
sub AUTOLOAD {
    my $self = shift;

    ref($self) or die "$self is not an object";

    my $name = $AUTOLOAD;
    $name =~ s/.*://;   # strip fully-qualified portion

    my $type = $methods{$name};
    die "Method $name not found\n" unless $type;

    if ($type eq 'traveller') {
        $self->_traveller($name, @_);
    } else {
        my $key  = $key_names{$type};
        my $val  = shift @_;
        my %opts = @_;
        $self->_do($name, $key => $val, %opts);
    }
}

sub _traveller {
    my $self = shift;
    my $name = shift;
    my $val  = shift;
    my %opts = (defined $val)? ( traveller => $val ) : ();
    $self->_do($name, %opts);     
}

sub _do {
    my $self = shift;
    my $name = shift;

    my %opts = @_;
    my $type = ($post{$name})? "POST" : "GET";

    $opts{format} = 'js';

    my $uri = URI->new($self->{_url});
    $uri->path($uri->path."/$name");
    my %params = $self->{_auth}->auth_params();
	my $req;
	if ("POST" eq $type) {
		$req = POST "$uri", [%opts], %params;
	} else { 
		$uri->query_form(%opts);
		$req = GET "$uri", %params;
	}
	
    my $res    = $self->{_ua}->request($req);
    die "Couldn't call $name : ".$res->status_line unless $res->is_success;

    return    $self->{_json}->decode($res->content);
}





sub DESTROY { }

=head1 TRAVELLER METHODS

=cut

=head2 fellows [traveller]

Get people C<traveller> shares information with. 

If C<traveller> is not provided then defaults to 
the logged-in user.

=cut

=head2 traveller_info [traveller] 

Get information about a traveller.

If C<traveller> is not provided then defaults to
the logged-in user.

=cut

=head2 trips_info [traveller]

Get info about the trips of a traveller.

If C<traveller> is not provided then defaults to
the logged-in user.

=cut

=head2 future_trips_info [traveller]

Returns a list of all trips entered by the 
selected user that have yet to finish.

If C<traveller> is not provided then defaults to
the logged-in user.

=head2 fellows_travellingtoday [traveller]

Get which of C<traveller>'s fellows are travelling today.

If C<traveller> is not provided then defaults to
the logged-in user.

=cut

=head2 

=head2 tag <tag> [traveller].

Returns data about all trips with a specific tag.

For more information about tags see

    http://dopplr.pbwiki.com/Tags

If C<traveller> is not provided then defaults to
the logged-in user.

=cut


sub tag {
    my $self      = shift;
    my $tag       = shift;
    my $traveller = shift;
    my %opts      = ( tag => $tag );
    $opts{traveller} = $traveller if defined $traveller;
    $self->_do('tag', %opts);
}

=head2 location_on_date <date> [traveller]

Returns the location of a traveller on a particular date.

Date should be in ISO date format e.g

    2007-04-01

If C<traveller> is not provided then defaults to
the logged-in user.

=cut

sub location_on_date {
    my $self      = shift;
    my $date      = shift;
    my $traveller = shift;
    my %opts      = ( date => $date );
    $opts{traveller} = $traveller if defined $traveller;
    $self->_do('location_on_date', %opts);
}

=head1 TRIP METHODS

=cut

=head2 trip_info <trip id>

Get info about a specific trip.

=cut

=head2 add_trip_tags <trip id> <tag[s]>

Add tags to a trip.

=cut

sub add_trip_tags {
    my $self    = shift;
    my $trip_id = shift;
    my $tags    = join(" ", @_);
    my %opts    = ( trip_id => $trip_id, tags => $tags );
    $self->_do('add_trip_tags', %opts);
}

=head2 add_trip_note <trip id> <note>

Add a note to a trip.

=cut

sub add_trip_note {
    my $self    = shift;
    my $trip_id = shift;
    my $note    = shift;
    my %opts    = ( trip_id => $trip_id, body => $note );
    $self->_do('add_trip_note', %opts);
}

=head2 delete_trip <trip_id>

Delete a trip

=cut


=head1 CITY METHODS

=cut

=head2 city_info <geoname id>

Get info about a City.

Use search to get the geoname id.

=cut

=head2 add_trip <geoname id> <start> <finish>

Add a trip for the currently logged in user.

Use search to get the geoname id.

Dates should be in ISO date format e.g

    2007-04-01

=cut

sub add_trip {
    my $self   = shift;
    my $geo_id = shift;
    my $start  = shift;
    my $finish = shift;
    my %opts   = ( geoname_id => $geo_id, start => $start, finish => $finish );
    $self->_do('add_trip', %opts); 

}

=head1 SEARCH METHODS

=head2 search <term>

Searches for travellers or cities.

=cut

=head2 city_search <term>

Searches for cities.

=cut

=head2 <term>

Searches for travellers.

=cut

=head1 OTHER METHODS

=head2 update_traveller <opt[s]>

Update a traveller's details. 

Takes a hash with the new values. Possible keys are

    email
    forename
    surname
    password

=cut

sub update_traveller {
    my $self = shift;
    my %opts = @_;
    $self->_do('update_traveller', %opts);
}

=head1 AUTHOR

Simon Wistow <simon@thegestalt.org>

=head1 COPYRIGHT

Copyright 2008, Simon Wistow

Distributed under the same terms as Perl itself.

=cut

1;
