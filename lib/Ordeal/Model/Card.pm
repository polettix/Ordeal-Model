package Ordeal::Model::Card;

# vim: ts=3 sts=3 sw=3 et ai :

use 5.020;
use strict; # redundant, but still useful to document
use warnings;
use English qw< -no_match_vars >;
use Mo qw< default >;
use Ouch;

use experimental qw< signatures postderef >;
no warnings qw< experimental::signatures experimental::postderef >;

has content_type => (default => undef);
has group => (default => '');
has id => (default => undef);
has name => (default => '');

sub data ($self, $data = undef) {
   $self->{data} = $data if @_ > 1;
   $self->{data} = $self->{data}->() if ref $self->{data};
   return $self->{data};
}

1;
__END__
