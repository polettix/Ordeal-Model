package Ordeal::Model::Shuffle;

# vim: ts=3 sts=3 sw=3 et ai :

use 5.020;
use strict; # redundant, but still useful to document
use warnings;
{ our $VERSION = '0.001'; }
use English qw< -no_match_vars >;
use Mo qw< build default >;
use Ouch;

use experimental qw< signatures postderef >;
no warnings qw< experimental::signatures experimental::postderef >;

has deck => (default => undef);
has random_source => (default => undef);
has _i => (default => undef);
has _indexes => (default => undef);

sub BUILD ($self) {
   ouch 400, 'no deck defined' unless $self->deck;
   if (! $self->random_source) {
      require Ordeal::Model::ChaCha20;
      $self->random_source(Ordeal::Model::ChaCha20->new);
   }
   $self->reshuffle;
}

sub draw ($self, $n = 1) {
   ouch 400, 'invalid number of cards', $n
      unless $n =~ m{\A(?: 0 | [1-9]\d*)\z}mxs;
   my $deck = $self->deck;

   my $i = $self->_i;
   $n = $i + 1 if $n == 0; # take them all
   ouch 400, 'not enough cards left', $n, $i + 1
      if $n > $i + 1;

   my $rs = $self->random_source;
   my $indexes = $self->_indexes;
   my @retval;
   while ($n-- > 0) {
      my $j = $rs->int_rand(0, $i); # extremes included
      (my $retval, $indexes->[$j]) = $indexes->@[$j, $i--];
      push @retval, $deck->card_at($retval);
   }
   $self->_i($i); # save for next iteration
   return $retval[0] if @retval == 1;
   return @retval;
}

sub n_remaining ($self) { return $self->_i + 1 }

sub reset ($self) {
   $self->random_source->reset;
   return $self->reshuffle;
}

sub reshuffle ($self) {
   $self->_i(my $i = $self->deck->n_cards - 1);
   $self->_indexes([0 .. $i]);
   return $self;
}
