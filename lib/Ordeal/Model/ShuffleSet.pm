package Ordeal::Model::ShuffleSet;

# vim: ts=3 sts=3 sw=3 et ai :

use 5.020;
use strict; # redundant, but still useful to document
use warnings;
{ our $VERSION = '0.001'; }
use English qw< -no_match_vars >;
use Scalar::Util qw< blessed >;
use Mo qw< default >;
use Ouch;

use experimental qw< signatures postderef >;
no warnings qw< experimental::signatures experimental::postderef >;

has shuffles => (default => undef);

sub create ($package, %args) {
   my $rs = $args{random_source} // do {
      require Ordeal::Model::ChaCha20;
      Ordeal::Model::ChaCha20->new;
   };
   my @shuffles = map {
      my $shuffle;
      my %fc = (default_n_draw => 1, random_source  => $rs);
      if (blessed($_)) {
         if ($_->can('draw')) {
            $shuffle = $_; # good for drawing cards
         }
         elsif ($_->can('cards')) {
            $fc{deck} = $_; # good for providing cards
         }
         else {
            ouch 400, 'cannot use object as an item', $_;
         }
      }
      elsif (ref($_) eq 'HASH') {
         %fc = (%fc, $_->%*);
         if ((! exists $fc{deck}) && exists($fc{deck_id})) {
            require Ordeal::Model;
            $fc{deck} = Ordeal::Model::get_deck($fc{deck_id});
         }
      }
      if (! $shuffle) { # still have to generate a shuffle
         ouch 400, 'no deck for shuffle item', $_
            unless blessed($fc{deck}) && $fc{deck}->can('cards');
         require Ordeal::Model::Shuffle;
         $shuffle = Ordeal::Shuffle::Model->new(%fc);
      }
      $shuffle->auto_reshuffle($args{auto_reshuffle});
      $shuffle;
   } $args{items}->@*;
   return $package->new(shuffles => \@shuffles);
}

sub draw ($self) { map {$_->draw} $self->shuffles->@* }
sub reshuffle ($self) { $_->reshuffle for $self->shuffles->@*; $self }
