package Ordeal::Model::Deck;

# vim: ts=3 sts=3 sw=3 et ai :

use 5.020;
use strict; # redundant, but still useful to document
use warnings;
use English qw< -no_match_vars >;
use Mo qw< default >;
use Ouch;
use List::Util qw< shuffle >;

use experimental qw< signatures postderef >;
no warnings qw< experimental::signatures experimental::postderef >;

has group => (default => '');
has id => (default => undef);
has name => (default => '');
has cards => (default => []);

1;
__END__
