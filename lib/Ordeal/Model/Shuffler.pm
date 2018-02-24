package Ordeal::Model::Shuffler;

# vim: ts=3 sts=3 sw=3 et ai :

use 5.020;
use strict;    # redundant, but still useful to document
use warnings;
{ our $VERSION = '0.001'; }
use English qw< -no_match_vars >;
use Scalar::Util qw< blessed >;
use Mo qw< build default >;
use Ouch;
use Ordeal::Model::Deck;
use Ordeal::Model::Shuffle;

use experimental qw< signatures postderef >;
no warnings qw< experimental::signatures experimental::postderef >;

has deck_cache => (default => sub { return {} });
has model         => ();
has random_source => (
   default => sub {
      require Ordeal::Model::ChaCha20;
      return Ordeal::Model::ChaCha20->new;
   }
);

sub _shuffle ($self, $deck) {
   $deck = Ordeal::Model::Deck->new(cards => $deck) unless blessed $deck;
   return Ordeal::Model::Shuffle->new(
      auto_reshuffle => 0,
      deck           => $deck,
      default_n_draw => $deck->n_cards,
      random_source  => $self->random_source,
   )->sort;
} ## end sub _shuffle ($self, $deck)

sub _get_integer ($self, $i, $mod = 0) {
   return($mod ? $i % $mod : $i) unless ref $i; # plain integer

   my @candidates = map {
      if (ref $_) {
         my ($lo, $hi) = map { $mod ? $_ % $mod : $_ } $_->[1]->@[0,1];
         $lo .. $hi;
      }
      else {
         $mod ? $_ % $mod : $_;
      }
   } $i->[1]->@*;

   return $candidates[$self->random_source->int_rand(0, $#candidates)];
}

sub assign ($self, $name, $s) {
   $self->cache->{$name} = $self->resolve($s);
}

sub evaluate_ast ($self, $ast) {
   my ($op, @params) = $ast->@*;
   my $method = $self->can("op_$op")
      or ouch 400, 'unknown op', [evaluate_ast => $op];
   my $retval = $self->$method(@params);

   return $retval;
}

sub op_slice ($self, $s_ast, $slices) {
   my $s = $self->evaluate_ast($s_ast)
      or ouch 400, 'invalid AST for a shuffle', op_slice => $s_ast;
   my $N = $s->deck->n_cards;

   my @indexes;
   my $max = 0;
   for my $slice ($slices->@*) {
      if (ref($slice) eq 'ARRAY') {
         if ($slice->[0] eq 'range') {
            my $lo = $self->_get_integer($slice->[1][0], $N);
            my $hi = $self->_get_integer($slice->[1][1], $N);
            push @indexes, $lo .. $hi;
         }
         elsif ($slice->[0] eq 'random') {
            push @indexes, $self->_get_integer($slice, $N);
         }
      }
      else {
         push @indexes, $self->_get_integer($slice, $N);
      }
      $max = $indexes[-1] if @indexes && ($max < $indexes[-1]);
   }

   my @cards = $s->draw($max + 1);
   return $self->_shuffle([@cards[@indexes]]);
}

sub op_replicate ($self, $s_ast, $n) {
   $n = $self->_get_integer($n);
   my $s = $self->evaluate_ast($s_ast);
   my @cards = $s->draw;
   return $self->_shuffle([(@cards) x $n]);
}

sub op_repeat ($self, $s_ast, $n) {
   $n = $self->_get_integer($n);
   my @cards;
   while ($n-- > 0) {
      my $s = $self->evaluate_ast($s_ast);
      push @cards, $s->draw;
   }
   return $self->_shuffle(\@cards);
}

sub op_resolve ($self, $shuffle) {
   return $shuffle
     if blessed($shuffle) && $shuffle->isa('Ordeal::Model::Shuffle');
   my $cache = $self->deck_cache;
   my $deck = $cache->{$shuffle} //= $self->model->get_deck($shuffle);
   return $self->_shuffle($deck);
}

sub op_shuffle ($self, $s_ast) {
   return $self->evaluate_ast($s_ast)->shuffle;
}

sub op_sort ($self, $s_ast) {
   return $self->evaluate_ast($s_ast)->sort;
}

sub op_subtract ($self, $s1_ast, $s2_ast) {
   my $s1 = $self->evaluate_ast($s1_ast);
   my $s2 = $self->evaluate_ast($s2_ast);
   my @cards = $s1->draw;
   for my $deleted ($s2->draw) {
      for my $i (0 .. $#cards) {
         next if $cards[$i] ne $deleted;
         splice @cards, $i, 1;
         last;
      }
   }
   return $self->_shuffle(\@cards);
}

sub op_sum ($self, $s1_ast, $s2_ast) {
   my $s1 = $self->evaluate_ast($s1_ast);
   my $s2 = $self->evaluate_ast($s2_ast);
   return $self->_shuffle([$s1->draw, $s2->draw]);
}

1;
__END__

GRAMMAR:



EXPRESSION = FACTOR (MULT_OP INT)* | INT MULT_OP EXPRESSION

FACTOR = ADDEND (SUM_OP EXPRESSION)*

ADDEND = 

MULT_OP = "*" | "x"
SUM_OP  = "+" | "-"

INT = SIMPLE_INT | RANDOM_INT
INT_RANGE = INT ".." INT
INT_ELEMENT = INT_RANGE | INT
RANDOM_INT = "{" LIST_OF_SIMPLE_INTS "}"
LIST_OF_INTS = INT_ELEMENT ("," INT_ELEMENT)*

SIMPLE_INT = NEGATIVE_SIMPLE_INT | "0" | POSITIVE_SIMPLE_INT
NEGATIVE_SIMPLE_INT = "-" POSITIVE_SIMPLE_INT
POSITIVE_SIMPLE_INT = /[1-9]\d*/
SIMPLE_INT_RANGE = SIMPLE_INT ".." SIMPLE_INT
SIMPLE_INT_ELEMENT = SIMPLE_INT_RANGE | SIMPLE_INT
LIST_OF_SIMPLE_INTS = SIMPLE_INT_ELEMENT ("," SIMPLE_INT_ELEMENT)*

IDENTIFIER = TOKEN | QUOTED_STRING
TOKEN = /[a-zA-Z_]\w*/
QUOTED_STRING = """ QUOTED_CHARS """
QUOTED_CHARS = /(?mxs: [^"\\] | \\. )*/


MODIFIED_ATOM = ATOM (ATOM_MODIFIER)*

ATOM_MODIFIER = "%" | "@" | SLICE
SLICE = "[" LIST_OF_INTS "]"


PARENTHESIZED_EXPRESSION = "(" EXPRESSION ")"
ATOM = PARENTHESIZED_EXPRESSION | IDENTIFIER
