package Ordeal::Model;

# vim: ts=3 sts=3 sw=3 et ai :

use 5.020;
use strict;
use warnings;
{ our $VERSION = '0.001'; }

use English qw< -no_match_vars >;
use Ouch;
use Mo qw< default >;
use Path::Tiny;
use List::Util qw< shuffle >;

use Ordeal::Model::Card;
use Ordeal::Model::Deck;
use Ordeal::Model::Shuffle;

use experimental qw< signatures postderef >;
no warnings qw< experimental::signatures experimental::postderef >;

has base_directory => (default => 'ordeal-assets');

sub get_card ($self, $id) {
   my ($group, $nid, $name, $extension) = $id =~ m{
      \A
            (.*?) # group
         -  (\d+) # numerical identifier
         -  (.*)  # name (possibly including dots)
         \. (.*)  # extension
      \z
   }mxs or ouch 400, 'invalid identifier', $id;

   state $content_type_for = {
      png => 'image/png',
      jpg => 'image/jpeg',
      svg => 'image/svg+xml',
   };
   my $content_type = $content_type_for->{$extension}
     or ouch 400, 'invalid extension', $extension, $id;

   my $path = path($self->base_directory)->child(cards => $id);
   $path->exists or ouch 404, 'not found', $id;

   return Ordeal::Model::Card->new(
      content_type => $content_type,
      group        => $group,
      id           => $id,
      name         => $name,
      data         => sub { __data_reader($path->stringify) },
   );
} ## end sub get_card

sub _get_cards_iterator ($self, %args) {
   my %query = ($args{query} || {})->%*;

   my @candidates;
   if (exists $query{id}) {
      @candidates = ref($query{id}) ? $query{id}->@* : $query{id};
   }
   else {    # every card is a candidate
      @candidates = map { $_->basename }
        path($self->base_directory)->child('cards')->children;
   }

   my %groups;
   if (exists $query{group}) {
      %groups =
        map { $_ => 1 }
        ref($query{group}) ? $query{group}->@* : $query{group};
   }

   return sub {
      while (@candidates) {
         my $candidate = shift @candidates;
         my $card = eval { $self->get_card($candidate) } or next;
         next if exists($query{group}) && !exists($groups{$card->group});
         return $card;
      } ## end while (@candidates)
      return;
   };
} ## end sub _get_cards_iterator

sub __exhaust_iterator ($it) {
   my @retval;
   while (defined(my $item = $it->())) {
      push @retval, $item;
   }
   return @retval;
} ## end sub __exhaust_iterator ($it)

sub get_cards ($self, %args) {
   my $iterator = $self->_get_cards_iterator(%args);
   return $iterator unless wantarray;
   return __exhaust_iterator($iterator);
}

sub __data_reader ($filename) {
   local $/;
   open my $fh, '<', $filename or ouch 500, "open(): $OS_ERROR", $filename;
   binmode $fh, ':raw' or ouch 500, "binmode(): $OS_ERROR", $filename;
   defined(my $retval = readline($fh))
     or ouch 500, "readline(): $OS_ERROR", $filename;
   close $fh or ouch 500, "close(): $OS_ERROR", $filename;
   return $retval;
} ## end sub __data_reader ($filename)

sub get_deck ($self, $id) {
   my ($group, $nid, $name) = $id =~ m{
      \A
            (.*?) # group
         -  (\d+) # numerical identifier
         -  (.*)  # name
      \z
   }mxs or ouch 400, 'invalid identifier', $id;

   my $path = path($self->base_directory)->child(decks => $id);
   $path->exists or ouch 404, 'not found', $id;

   my @cards =
     map  { $self->get_card($_->realpath->basename) }
     sort { $a->basename cmp $b->basename } $path->children;

   return Ordeal::Model::Deck->new(
      group => $group,
      id    => $id,
      name  => $name,
      cards => \@cards,
   );
} ## end sub get_deck

sub get_shuffled_deck ($self, $deck_id, %args) {
   my $deck    = $self->get_deck($deck_id);
   my $shuffle = Ordeal::Model::Shuffle->new(
      deck => $deck,
      seed => $args{seed},
   );
   my $n = $args{n} // $deck->n_cards;
   ouch 400, 'invalid number of requested cards', $args{n}
     if $n > $shuffle->n_remaining;
   return $shuffle->draw($n) if wantarray;
   return sub {
      return if $n <= 0;
      return if $shuffle->n_remaining <= 0;
      $n--;
      return $shuffle->draw(1);
   };
} ## end sub get_shuffled_deck

1;
