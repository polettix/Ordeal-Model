package Ordeal::Model::ChaCha20;

# vim: ts=3 sts=3 sw=3 et ai :

# Adapted from Math::Prime::Util::ChaCha 0.70
# https://metacpan.org/pod/Math::Prime::Util::ChaCha
# which is copyright 2017 by Dana Jacobsen E<lt>dana@acm.orgE<gt>

use 5.020;
use strict;
use warnings;
{ our $VERSION = '0.001'; }
use Ouch;
use Mo qw< build default >;
use experimental qw< signatures postderef >;
no warnings qw< experimental::signatures experimental::postderef >;

use constant BITS => (~0 == 4294967295) ? 32 : 64;
use constant CACHE_SIZE => 1000;
use constant ROUNDS     => 20;

has goodseed => ();
has state    => ();
has buffer   => ();
has seed     => ();
has min_bits => (default => 4);

sub BUILD ($self) {
   my $seed = $self->seed // do {
      my $s = CORE::rand 1_000_000;
      $s < 4294967295
        ? pack 'V', $s
        : pack 'V2', $s, $s >> 32;
   };
   $self->seed($seed);
   $self->goodseed(length($seed) >= 16);
   $seed .= pack 'C', 0 while length($seed) % 4;
   my @seed = unpack 'V*', substr $seed, 0, 40;
   if (@seed < 10) {
      my $rng = __prng_new(map { $_ <= $#seed ? $seed[$_] : 0 } 0 .. 3);
      push @seed, __prng_next($rng) while @seed < 10;
   }
   ouch 500, 'seed count failure', @seed if @seed != 10;
   $self->state(
      [
         0x61707865,    0x3320646e,    0x79622d32, 0x6b206574,
         @seed[0 .. 3], @seed[4 .. 7], 0,          0,
         @seed[8 .. 9]
      ]
   );
   $self->buffer('');
} ## end sub BUILD ($self)

# Simple PRNG used to fill small seeds
sub __prng_next ($s) {
   my $word;
   my $oldstate = $s->[0];
   if (BITS == 64) {
      $s->[0] = ($s->[0] * 747796405 + $s->[1]) & 0xFFFFFFFF;
      $word =
        ((($oldstate >> (($oldstate >> 28) + 4)) ^ $oldstate) * 277803737)
        & 0xFFFFFFFF;
   } ## end if (BITS == 64)
   else {
      {
         use integer;
         $s->[0] = unpack("L", pack("L", $s->[0] * 747796405 + $s->[1]));
      }
      $word =
        (($oldstate >> (($oldstate >> 28) + 4)) ^ $oldstate) & 0xFFFFFFFF;
      { use integer; $word = unpack("L", pack("L", $word * 277803737)); }
   } ## end else [ if (BITS == 64) ]
   ($word >> 22) ^ $word;
} ## end sub __prng_next ($s)

sub __prng_new ($A, $B, $C, $D) {
   my @s = (0, (($B << 1) | 1) & 0xFFFFFFFF);
   __prng_next(\@s);
   $s[0] = ($s[0] + $A) & 0xFFFFFFFF;
   __prng_next(\@s);
   $s[0] = ($s[0] ^ $C) & 0xFFFFFFFF;
   __prng_next(\@s);
   $s[0] = ($s[0] ^ $D) & 0xFFFFFFFF;
   __prng_next(\@s);
   return \@s;
} ## end sub __prng_new

sub int_rand ($self, $low, $high) {
   my $N = $high - $low + 1;
   state $cache = [];
   my ($nbits, $reject_threshold);
   if ($N <= CACHE_SIZE && defined($cache->[$N])) {
      ($nbits, $reject_threshold) = $cache->[$N]->@*;
   }
   else {
      $nbits = int(log($N) / log(2)) + $self->min_bits;
      my $M = 2**$nbits;
      $reject_threshold = $M - $M % $N;
      $cache->[$N] = [$nbits, $reject_threshold] if $N <= CACHE_SIZE;
   } ## end else [ if ($N <= CACHE_SIZE &&...)]
   my $retval = $reject_threshold;
   while ($retval >= $reject_threshold) {
      my $bitsequence = $self->bits_rand($nbits);
      $retval = 0;
      for my $v (reverse split //, pack 'b*', $bitsequence) {
         $retval <<= 8;
         $retval += ord $v;
      }
   } ## end while ($retval >= $reject_threshold)
   return $low + $retval % $N;
} ## end sub int_rand

sub bits_rand ($self, $n) {
   while (length($self->{buffer}) < $n) {
      my $add_on = $self->_core((int(1 + $n / 8) + 63) >> 6);
      $self->{buffer} .= unpack 'b*', $add_on;
   }
   return substr $self->{buffer}, 0, $n, '';
} ## end sub bits_rand

###############################################################################
# Begin ChaCha core, reference RFC 7539
# with change to make blockcount/nonce be 64/64 from 32/96
# Dana Jacobsen, 9 Apr 2017
# Adapted Flavio Poletti, 3 Feb 2018

#  State is:
#       cccccccc  cccccccc  cccccccc  cccccccc
#       kkkkkkkk  kkkkkkkk  kkkkkkkk  kkkkkkkk
#       kkkkkkkk  kkkkkkkk  kkkkkkkk  kkkkkkkk
#       bbbbbbbb  nnnnnnnn  nnnnnnnn  nnnnnnnn
#
#     c=constant k=key b=blockcount n=nonce

# We have to take care with 32-bit Perl so it sticks with integers.
# Unfortunately the pragma "use integer" means signed integer so
# it ruins right shifts.  We also must ensure we save as unsigned.

sub _core ($self, $blocks) {
   my $j  = $self->state();
   my $ks = '';
   $blocks = 1 unless defined $blocks;

   while ($blocks-- > 0) {
      my (
         $x0, $x1, $x2,  $x3,  $x4,  $x5,  $x6,  $x7,
         $x8, $x9, $x10, $x11, $x12, $x13, $x14, $x15
      ) = @$j;
      for (1 .. ROUNDS / 2) {
         use integer;
         if (BITS == 64) {
            $x0 = ($x0 + $x4) & 0xFFFFFFFF;
            $x12 ^= $x0;
            $x12 = (($x12 << 16) | ($x12 >> 16)) & 0xFFFFFFFF;
            $x8 = ($x8 + $x12) & 0xFFFFFFFF;
            $x4 ^= $x8;
            $x4 = (($x4 << 12) | ($x4 >> 20)) & 0xFFFFFFFF;
            $x0 = ($x0 + $x4) & 0xFFFFFFFF;
            $x12 ^= $x0;
            $x12 = (($x12 << 8) | ($x12 >> 24)) & 0xFFFFFFFF;
            $x8 = ($x8 + $x12) & 0xFFFFFFFF;
            $x4 ^= $x8;
            $x4 = (($x4 << 7) | ($x4 >> 25)) & 0xFFFFFFFF;
            $x1 = ($x1 + $x5) & 0xFFFFFFFF;
            $x13 ^= $x1;
            $x13 = (($x13 << 16) | ($x13 >> 16)) & 0xFFFFFFFF;
            $x9 = ($x9 + $x13) & 0xFFFFFFFF;
            $x5 ^= $x9;
            $x5 = (($x5 << 12) | ($x5 >> 20)) & 0xFFFFFFFF;
            $x1 = ($x1 + $x5) & 0xFFFFFFFF;
            $x13 ^= $x1;
            $x13 = (($x13 << 8) | ($x13 >> 24)) & 0xFFFFFFFF;
            $x9 = ($x9 + $x13) & 0xFFFFFFFF;
            $x5 ^= $x9;
            $x5 = (($x5 << 7) | ($x5 >> 25)) & 0xFFFFFFFF;
            $x2 = ($x2 + $x6) & 0xFFFFFFFF;
            $x14 ^= $x2;
            $x14 = (($x14 << 16) | ($x14 >> 16)) & 0xFFFFFFFF;
            $x10 = ($x10 + $x14) & 0xFFFFFFFF;
            $x6 ^= $x10;
            $x6 = (($x6 << 12) | ($x6 >> 20)) & 0xFFFFFFFF;
            $x2 = ($x2 + $x6) & 0xFFFFFFFF;
            $x14 ^= $x2;
            $x14 = (($x14 << 8) | ($x14 >> 24)) & 0xFFFFFFFF;
            $x10 = ($x10 + $x14) & 0xFFFFFFFF;
            $x6 ^= $x10;
            $x6 = (($x6 << 7) | ($x6 >> 25)) & 0xFFFFFFFF;
            $x3 = ($x3 + $x7) & 0xFFFFFFFF;
            $x15 ^= $x3;
            $x15 = (($x15 << 16) | ($x15 >> 16)) & 0xFFFFFFFF;
            $x11 = ($x11 + $x15) & 0xFFFFFFFF;
            $x7 ^= $x11;
            $x7 = (($x7 << 12) | ($x7 >> 20)) & 0xFFFFFFFF;
            $x3 = ($x3 + $x7) & 0xFFFFFFFF;
            $x15 ^= $x3;
            $x15 = (($x15 << 8) | ($x15 >> 24)) & 0xFFFFFFFF;
            $x11 = ($x11 + $x15) & 0xFFFFFFFF;
            $x7 ^= $x11;
            $x7 = (($x7 << 7) | ($x7 >> 25)) & 0xFFFFFFFF;
            $x0 = ($x0 + $x5) & 0xFFFFFFFF;
            $x15 ^= $x0;
            $x15 = (($x15 << 16) | ($x15 >> 16)) & 0xFFFFFFFF;
            $x10 = ($x10 + $x15) & 0xFFFFFFFF;
            $x5 ^= $x10;
            $x5 = (($x5 << 12) | ($x5 >> 20)) & 0xFFFFFFFF;
            $x0 = ($x0 + $x5) & 0xFFFFFFFF;
            $x15 ^= $x0;
            $x15 = (($x15 << 8) | ($x15 >> 24)) & 0xFFFFFFFF;
            $x10 = ($x10 + $x15) & 0xFFFFFFFF;
            $x5 ^= $x10;
            $x5 = (($x5 << 7) | ($x5 >> 25)) & 0xFFFFFFFF;
            $x1 = ($x1 + $x6) & 0xFFFFFFFF;
            $x12 ^= $x1;
            $x12 = (($x12 << 16) | ($x12 >> 16)) & 0xFFFFFFFF;
            $x11 = ($x11 + $x12) & 0xFFFFFFFF;
            $x6 ^= $x11;
            $x6 = (($x6 << 12) | ($x6 >> 20)) & 0xFFFFFFFF;
            $x1 = ($x1 + $x6) & 0xFFFFFFFF;
            $x12 ^= $x1;
            $x12 = (($x12 << 8) | ($x12 >> 24)) & 0xFFFFFFFF;
            $x11 = ($x11 + $x12) & 0xFFFFFFFF;
            $x6 ^= $x11;
            $x6 = (($x6 << 7) | ($x6 >> 25)) & 0xFFFFFFFF;
            $x2 = ($x2 + $x7) & 0xFFFFFFFF;
            $x13 ^= $x2;
            $x13 = (($x13 << 16) | ($x13 >> 16)) & 0xFFFFFFFF;
            $x8 = ($x8 + $x13) & 0xFFFFFFFF;
            $x7 ^= $x8;
            $x7 = (($x7 << 12) | ($x7 >> 20)) & 0xFFFFFFFF;
            $x2 = ($x2 + $x7) & 0xFFFFFFFF;
            $x13 ^= $x2;
            $x13 = (($x13 << 8) | ($x13 >> 24)) & 0xFFFFFFFF;
            $x8 = ($x8 + $x13) & 0xFFFFFFFF;
            $x7 ^= $x8;
            $x7 = (($x7 << 7) | ($x7 >> 25)) & 0xFFFFFFFF;
            $x3 = ($x3 + $x4) & 0xFFFFFFFF;
            $x14 ^= $x3;
            $x14 = (($x14 << 16) | ($x14 >> 16)) & 0xFFFFFFFF;
            $x9 = ($x9 + $x14) & 0xFFFFFFFF;
            $x4 ^= $x9;
            $x4 = (($x4 << 12) | ($x4 >> 20)) & 0xFFFFFFFF;
            $x3 = ($x3 + $x4) & 0xFFFFFFFF;
            $x14 ^= $x3;
            $x14 = (($x14 << 8) | ($x14 >> 24)) & 0xFFFFFFFF;
            $x9 = ($x9 + $x14) & 0xFFFFFFFF;
            $x4 ^= $x9;
            $x4 = (($x4 << 7) | ($x4 >> 25)) & 0xFFFFFFFF;
         } ## end if (BITS == 64)
         else {    # 32-bit
            $x0 += $x4;
            $x12 ^= $x0;
            $x12 = ($x12 << 16) | (($x12 >> 16) & 0xFFFF);
            $x8 += $x12;
            $x4 ^= $x8;
            $x4 = ($x4 << 12) | (($x4 >> 20) & 0xFFF);
            $x0 += $x4;
            $x12 ^= $x0;
            $x12 = ($x12 << 8) | (($x12 >> 24) & 0xFF);
            $x8 += $x12;
            $x4 ^= $x8;
            $x4 = ($x4 << 7) | (($x4 >> 25) & 0x7F);
            $x1 += $x5;
            $x13 ^= $x1;
            $x13 = ($x13 << 16) | (($x13 >> 16) & 0xFFFF);
            $x9 += $x13;
            $x5 ^= $x9;
            $x5 = ($x5 << 12) | (($x5 >> 20) & 0xFFF);
            $x1 += $x5;
            $x13 ^= $x1;
            $x13 = ($x13 << 8) | (($x13 >> 24) & 0xFF);
            $x9 += $x13;
            $x5 ^= $x9;
            $x5 = ($x5 << 7) | (($x5 >> 25) & 0x7F);
            $x2 += $x6;
            $x14 ^= $x2;
            $x14 = ($x14 << 16) | (($x14 >> 16) & 0xFFFF);
            $x10 += $x14;
            $x6 ^= $x10;
            $x6 = ($x6 << 12) | (($x6 >> 20) & 0xFFF);
            $x2 += $x6;
            $x14 ^= $x2;
            $x14 = ($x14 << 8) | (($x14 >> 24) & 0xFF);
            $x10 += $x14;
            $x6 ^= $x10;
            $x6 = ($x6 << 7) | (($x6 >> 25) & 0x7F);
            $x3 += $x7;
            $x15 ^= $x3;
            $x15 = ($x15 << 16) | (($x15 >> 16) & 0xFFFF);
            $x11 += $x15;
            $x7 ^= $x11;
            $x7 = ($x7 << 12) | (($x7 >> 20) & 0xFFF);
            $x3 += $x7;
            $x15 ^= $x3;
            $x15 = ($x15 << 8) | (($x15 >> 24) & 0xFF);
            $x11 += $x15;
            $x7 ^= $x11;
            $x7 = ($x7 << 7) | (($x7 >> 25) & 0x7F);
            $x0 += $x5;
            $x15 ^= $x0;
            $x15 = ($x15 << 16) | (($x15 >> 16) & 0xFFFF);
            $x10 += $x15;
            $x5 ^= $x10;
            $x5 = ($x5 << 12) | (($x5 >> 20) & 0xFFF);
            $x0 += $x5;
            $x15 ^= $x0;
            $x15 = ($x15 << 8) | (($x15 >> 24) & 0xFF);
            $x10 += $x15;
            $x5 ^= $x10;
            $x5 = ($x5 << 7) | (($x5 >> 25) & 0x7F);
            $x1 += $x6;
            $x12 ^= $x1;
            $x12 = ($x12 << 16) | (($x12 >> 16) & 0xFFFF);
            $x11 += $x12;
            $x6 ^= $x11;
            $x6 = ($x6 << 12) | (($x6 >> 20) & 0xFFF);
            $x1 += $x6;
            $x12 ^= $x1;
            $x12 = ($x12 << 8) | (($x12 >> 24) & 0xFF);
            $x11 += $x12;
            $x6 ^= $x11;
            $x6 = ($x6 << 7) | (($x6 >> 25) & 0x7F);
            $x2 += $x7;
            $x13 ^= $x2;
            $x13 = ($x13 << 16) | (($x13 >> 16) & 0xFFFF);
            $x8 += $x13;
            $x7 ^= $x8;
            $x7 = ($x7 << 12) | (($x7 >> 20) & 0xFFF);
            $x2 += $x7;
            $x13 ^= $x2;
            $x13 = ($x13 << 8) | (($x13 >> 24) & 0xFF);
            $x8 += $x13;
            $x7 ^= $x8;
            $x7 = ($x7 << 7) | (($x7 >> 25) & 0x7F);
            $x3 += $x4;
            $x14 ^= $x3;
            $x14 = ($x14 << 16) | (($x14 >> 16) & 0xFFFF);
            $x9 += $x14;
            $x4 ^= $x9;
            $x4 = ($x4 << 12) | (($x4 >> 20) & 0xFFF);
            $x3 += $x4;
            $x14 ^= $x3;
            $x14 = ($x14 << 8) | (($x14 >> 24) & 0xFF);
            $x9 += $x14;
            $x4 ^= $x9;
            $x4 = ($x4 << 7) | (($x4 >> 25) & 0x7F);
         } ## end else [ if (BITS == 64) ]
      } ## end for (1 .. ROUNDS / 2)
      $ks .= pack("V16",
         $x0 + $j->[0],
         $x1 + $j->[1],
         $x2 + $j->[2],
         $x3 + $j->[3],
         $x4 + $j->[4],
         $x5 + $j->[5],
         $x6 + $j->[6],
         $x7 + $j->[7],
         $x8 + $j->[8],
         $x9 + $j->[9],
         $x10 + $j->[10],
         $x11 + $j->[11],
         $x12 + $j->[12],
         $x13 + $j->[13],
         $x14 + $j->[14],
         $x15 + $j->[15]);
      if (++$j->[12] > 4294967295) {
         $j->[12] = 0;
         $j->[13]++;
      }
   } ## end while ($blocks-- > 0)
   return $ks;
} ## end sub _core

# End ChaCha core
###############################################################################

1;
__END__
