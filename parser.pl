#!/usr/bin/env perl
use 5.024;
use strict;
use warnings;
use experimental qw< postderef signatures >;
no warnings qw< experimental::postderef experimental::signatures >;
use Data::Dumper;
$Data::Dumper::Indent = 1;

use lib 'lib';
use lib 'local/lib/perl5';
use Ordeal::Model::Shuffler;
use Try::Tiny;
use Ouch qw< :trytiny_var >;


my $model = Model->new;
my $shuffler = Ordeal::Model::Shuffler->new(model => $model);


package Model;
use 5.024;
use experimental qw< postderef signatures >;
no warnings qw< experimental::postderef experimental::signatures >;

sub new ($package) { return bless {}, $package }

sub get_deck ($self, $name) {
   require Ordeal::Model::Deck;
   state $decks = {
      map {
         my ($name, $cards) = $_->@*;
         $name => Ordeal::Model::Deck->new(cards => $cards);
      } (
         [ whatever => [qw< whatever1 whatever2 whatever3 >] ],
         [ what => [qw< what1 what2 what3 what-the-fsck >] ],
         [ something_else => [qw< seA seB seC seD seE seF >] ],
         [ die6 => [1..6] ],
      )
   };
   return $decks->{$name};
}


package main;


my $input =
   #'wH4TEv3r@! you! "do to us"@'
   #'{1,4, -5..-3, 1,  117..122}'
   #'whatever@![1, 3..5, -5..-2, 12]'
   #'2 x 4 * whatever@![1, 3..5, -5..-2, 12] * 3 + something_else'
   #'whatever! * 3 + something_else + (what@ * 2)[1, 0..{2..4}] x2'
   'die6[{0..5}] * 3 + die6@[0] * 3'
   #'[0..{2..4}]'
   ;
my $ast =
   # _SEQUENCE(\$input, ('ATOM') x 3)
   #RANDOM_INT(\$input)
   #ATOM(\$input)
   parse($input)
   #SLICER(\$input)
   ;

say Dumper [ $input => $ast ];

try {
   my $retval = $shuffler->evaluate_ast($ast);
   say "retval<$retval>";
   say Dumper [ $retval->draw ];
}
catch {
   say Dumper $_;
};

sub parse ($input) {
   my $ast = EXPRESSION(\$input);
   my $pos = pos $input;
   my ($blanks, $rest) = substr($input, $pos) =~ m{\A (\s*) (.*) }mxs;
   if (length $rest) {
      $pos += length($blanks // '');
      $rest = substr($rest, 0, 5) . '...' if length($rest) > 8;
      die "parsed up to position $pos, remaining '$rest'";
   }
   return $ast;
}

sub _RESOLVE ($what) {
   return $what if ref $what;
   return __PACKAGE__->can($what);
}

sub _ALTERNATIVES ($rtext, @alternatives) {
   EWS($rtext);
   my $retval;
   for my $alt (@alternatives) {
      last if defined ($retval = _RESOLVE($alt)->($rtext));
   }
   EWS($rtext);
   return $retval;
}

sub _LIST ($rtext, $what, $sep = undef) {
   $what = _RESOLVE($what);
   $sep = _RESOLVE($sep) if defined $sep;
   EWS($rtext);
   defined(my $base = $what->($rtext)) or return;
   my $rest = _STAR($rtext, sub ($rtext) {
      EWS($rtext);
      if ($sep) {
         $sep->($rtext) or return; # check & discard
         EWS($rtext);
      }
      $what->($rtext);
   });
   if ($sep) {
      $sep->($rtext); # optional ending
      EWS($rtext);
   }
   unshift $rest->@*, $base;
   return $rest;
}

sub _REGEXP ($rtext, $rx) {
   my ($retval) = $$rtext =~ m{\G$rx}cgmxs;
   return $retval;
}

sub _SEQUENCE ($rtext, @items) {
   EWS($rtext);
   my $pos = pos $$rtext;
   my @retval;
   for my $item (@items) {
      if (defined(my $retval = _RESOLVE($item)->($rtext))) {
         push @retval, $retval;
         EWS($rtext);
      }
      else { # backtrack
         pos($$rtext) = $pos;
         return;
      }
   }
   return \@retval;
}

sub _STAR ($rtext, $sexp) {
   $sexp = _RESOLVE($sexp);

   my @retval;

   EWS($rtext);
   my $pos = pos $$rtext;
   while (defined(my $retval = $sexp->($rtext))) {
      push @retval, $retval;
      EWS($rtext);
      $pos = pos $$rtext;
   }
   pos($$rtext) = $pos;
   return \@retval;
}

sub IDENTIFIER ($rtext) {
   defined(my $rv = _ALTERNATIVES($rtext, qw< TOKEN QUOTED_STRING >))
      or return;
   return [resolve => $rv];
}

sub TOKEN ($rtext) { _REGEXP($rtext, qr{([a-zA-Z]\w*)}) }
sub QUOTED_STRING ($rtext) { _REGEXP($rtext, qr{"(([^\\"]|\\.)*)"}) }
sub EWS ($rtext) { _REGEXP($rtext, qr{\s+}) }

sub PARENTHESIZED_EXPRESSION ($rtext) {
   my $m = _SEQUENCE($rtext, qw< OPEN_ROUND EXPRESSION CLOSE_ROUND >)
      or return;
   return $m->[1];
}
sub OPEN_ROUND ($rtext) { _REGEXP($rtext, qr{[(]}) }
sub CLOSE_ROUND ($rtext) { _REGEXP($rtext, qr{[)]}) }

sub ATOM_BASE ($rtext) {
   return _ALTERNATIVES($rtext, qw< PARENTHESIZED_EXPRESSION IDENTIFIER >);
}

sub ATOM_UNARY ($rtext) {
   return _ALTERNATIVES($rtext, qw< SLICER SORTER SHUFFLER >);
}
sub SLICER ($rtext) {
   my $slicer = _SEQUENCE(
      $rtext,
      sub ($rtext) { _REGEXP($rtext, qr{(\[)}) },
      'INT_ITEM_LIST',
      sub ($rtext) { _REGEXP($rtext, qr{(\])}) },
   ) or return;
   return [slice => $slicer->[1]];
}
sub SORTER ($rtext) { _REGEXP($rtext, qr{([!])}) ? 'sort' : undef }
sub SHUFFLER ($rtext) { _REGEXP($rtext, qr{([@])}) ? 'shuffle' : undef }

sub ATOM ($rtext) {
   defined(my $retval = ATOM_BASE($rtext)) or return;
   my $unaries = _STAR($rtext, 'ATOM_UNARY');
   for my $unary ($unaries->@*) {
      if (ref $unary) {
         my ($name, @rest) = $unary->@*;
         $retval = [$name, $retval, @rest];
      }
      else {
         $retval = [$unary, $retval];
      }
   }
   return $retval;
}

sub INT ($rtext) { _ALTERNATIVES($rtext, qw< SIMPLE_INT RANDOM_INT >) }
sub INT_RANGE ($rtext) {
   my $r = _SEQUENCE(
      $rtext,
      'INT',
      sub ($rtext) { _REGEXP($rtext, qr{(\.\.)}) },
      'INT',
   ) or return;
   return [range => [$r->@[0,2]]];
}
sub INT_ITEM ($rtext) { _ALTERNATIVES($rtext, qw< INT_RANGE INT >) }
sub INT_ITEM_LIST ($rtext) { _LIST($rtext, 'INT_ITEM', 'COMMA') }
sub COMMA ($rtext) { _REGEXP($rtext, qr{(,)}) }

sub SIMPLE_INT ($rtext) { _REGEXP($rtext, qr{(0|-?[1-9][0-9]*)}) }
sub SIMPLE_INT_RANGE ($rtext) {
   my $r = _SEQUENCE(
      $rtext,
      'SIMPLE_INT',
      sub ($rtext) { _REGEXP($rtext, qr{(\.\.)}) },
      'SIMPLE_INT',
   ) or return;
   return [range => [$r->@[0,2]]];
}
sub SIMPLE_INT_ITEM ($rtext) {
   _ALTERNATIVES($rtext, qw< SIMPLE_INT_RANGE SIMPLE_INT >);
}

sub RANDOM_INT ($rtext) {
   my $seq = _SEQUENCE(
      $rtext,
      sub ($rtext) { _REGEXP($rtext, qr<([{])>) },
      sub ($rtext) { _LIST( $rtext, 'SIMPLE_INT_ITEM', 'COMMA') },
      sub ($rtext) { _REGEXP($rtext, qr<([}])>) },
   ) or return;
   return [random => $seq->[1]];
}

sub POSITIVE_SIMPLE_INT ($rtext) { _REGEXP($rtext, qr{([1-9][0-9]*)}) }
sub POSITIVE_RANDOM_INT ($rtext) {
   my $pos = pos $$rtext;
   defined (my $rint = RANDOM_INT($rtext)) or return;
   my $alternatives = $rint->[1];
   for my $alt ($alternatives->@*) {
      for my $n (ref($alt) ? $alt->[1]->@* : $alt) {
         next if $n > 0;
         pos($$rtext) = $pos;
         return;
      }
   }
   return [POSITIVE_RANDOM_INT => $alternatives];
}

sub POSITIVE_INT ($rtext) {
   _ALTERNATIVES($rtext, qw< POSITIVE_SIMPLE_INT POSITIVE_RANDOM_INT >);
}

sub ADDEND ($rtext) {
   my $match = _SEQUENCE(
      $rtext,
      sub ($rtext) {
         _STAR(
            $rtext,
            sub ($rtext) {
               _SEQUENCE($rtext, qw< POSITIVE_INT MULTIPLIER >)
            }
         )
      },
      'ATOM',
      sub ($rtext) {
         _STAR(
            $rtext,
            sub ($rtext) {
               _SEQUENCE($rtext, qw< MULTIPLIER POSITIVE_INT >)
            }
         )
      },
   ) or return;
   my ($pre, $retval, $post) = $match->@*;
   $retval = _MULT($retval, reverse($_->@*)) for reverse($pre->@*);
   $retval = _MULT($retval,        ($_->@*)) for        ($post->@*);
   return $retval;
}

sub MULTIPLIER ($rtext) { _REGEXP($rtext, qr{([*x])}) }


sub PRE_MULT ($rtext) {
   my $r = _SEQUENCE(
      $rtext,
      'POSITIVE_INT',
      sub ($rtext) {_REGEXP($rtext, qr{([*x])})},
      'ATOM',
   ) or return;
   return _MULT(reverse $r->@*);
}

sub POST_MULT ($rtext) {
   my $r = _SEQUENCE(
      $rtext,
      'ATOM',
      sub ($rtext) {_REGEXP($rtext, qr{([*x])})},
      'POSITIVE_INT',
   ) or return;
   return _MULT($r->@*);
}

sub _MULT ($atom, $op, $n) {
   state $name_for = {
      '*' => 'repeat',
      'x' => 'replicate'
   };
   return [$name_for->{$op}, $atom, $n];
}

sub EXPRESSION ($rtext) {
   my $match = _SEQUENCE($rtext,
      'ADDEND',
      sub ($rtext) {
         _STAR($rtext,
            sub ($rtext) { _SEQUENCE($rtext, qw< SUMMER ADDEND >) },
         )
      }
   ) or return;
   my ($retval, $transformations) = $match->@*;
   state $name_for = {
      '+' => 'sum',
      '-' => 'subtract',
   };
   for my $t ($transformations->@*) {
      my ($op, $addend) = $t->@*;
      $retval = [$name_for->{$op}, $retval, $addend];
   }
   return $retval;
}

sub SUMMER ($rtext) { _REGEXP($rtext, qr{([-+])}) }
