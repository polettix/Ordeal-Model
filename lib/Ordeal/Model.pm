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

use Ordeal::Model::Shuffler;

use experimental qw< signatures postderef >;
no warnings qw< experimental::signatures experimental::postderef >;

has backend => (
   default => sub {
      require Ordeal::Model::Backend::PlainFile;
      return Ordeal::Model::Backend::PlainFile->new;
   }
);

sub get_card ($self, $id) { return $self->backend->card($id) }
sub get_deck ($self, $id) { return $self->backend->deck($id) }

sub get_shuffled_cards ($self, %args) {
   my $random_source = $args{random_source}
      // do {
         require Ordeal::Model::ChaCha20;
         Ordeal::Model::ChaCha20->new(seed => $args{seed});
      };
   $random_source->restore($args{random_source_state})
      if exists $args{random_source_state};

   my $shuffle = Ordeal::Model::Shuffler->new(
      random_source => $random_source,
      model => $self,
   )->evaluate($args{expression});
   return $shuffle->draw if wantarray;
   return sub {
      return unless $shuffle->n_remaining;
      return $shuffle->draw(@_);
   };
}

1;
