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
use Ordeal::Model::Shuffler::Evaluator;
use Ordeal::Model::Shuffler::Parser;

use experimental qw< signatures postderef >;
no warnings qw< experimental::signatures experimental::postderef >;

has _cache => (default => sub { return {} });
has max_cache => (default => 0);
has model         => ();
has random_source => (
   default => sub {
      require Ordeal::Model::ChaCha20;
      return Ordeal::Model::ChaCha20->new;
   }
);

sub evaluate ($self, $what) {
   my $ast = ref($what) ? $what : $self->parse($what);
   return Ordeal::Model::Shuffler::Evaluator::EVALUATE(
      ast           => $ast,
      model         => $self->model,
      random_source => $self->random_source,
   );
}

sub parse ($self, $text) {
   my $cache = $self->_cache;
   my $ast;
   if (exists $cache->{$text}) {
      $ast = $cache->{$text};
   }
   else {
      $ast = Ordeal::Model::Shuffler::Parser::PARSE($text);

      my $max = $self->max_cache;
      $cache->{$text} = $ast
         if ($max < 0) || (scalar(keys $cache->%*) < $max);
   }
   return $ast;
}
