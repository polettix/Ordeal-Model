package Ordeal::Model::Shuffle;

# vim: ts=3 sts=3 sw=3 et ai :

use 5.020;
use strict; # redundant, but still useful to document
use warnings;
{ our $VERSION = '0.001'; }
use English qw< -no_match_vars >;
use Mo qw< build default >;
use Ouch;
use Ordeal::Model::ChaCha20;

use experimental qw< signatures postderef >;
no warnings qw< experimental::signatures experimental::postderef >;

has deck => (default => undef);
has random_source => (default => undef);
has seed => (default => undef);
has i => (default => undef);
has indexes => (default => undef);

sub BUILD ($self) {
   $self->reset();
}

sub reset ($self) {
   my $rs = Ordeal::Model::ChaCha20->new(seed => $self->seed);
   $self->random_source($rs);
   $self->seed($rs->seed);
   return $self->reshuffle;
}

sub reshuffle ($self) {
   $self->i(my $i = $self->deck->n_cards - 1);
   $self->indexes([0 .. $i]);
   return $self;
}

sub draw ($self, $n = 1) {
   ouch 400, 'invalid number of cards', $n
      unless $n =~ m{\A(?: 0 | [1-9]\d*)\z}mxs;
   my $deck = $self->deck;
   $n = $deck->n_cards if $n == 0; # take them all

   my $i = $self->i;
   ouch 400, 'not enough cards left', $n, $i + 1
      if $n > $i + 1;

   my $rs = $self->random_source;
   my $indexes = $self->indexes;
   my @retval;
   while ($n-- > 0) {
      my $j = $rs->int_rand(0, $i); # extremes included
      (my $retval, $indexes->[$j]) = $indexes->@[$j, $i--];
      push @retval, $deck->card_at($retval);
   }
   $self->i($i); # save for next iteration
   return $retval[0] if @retval == 1;
   return @retval;
}

sub n_remaining ($self) { return $self->i + 1 }
