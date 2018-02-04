# NAME

Ordeal::Model - Manage cards and decks

# VERSION

This document describes Ordeal::Model version {{\[ version \]}}.

<div>
    <a href="https://travis-ci.org/polettix/Ordeal-Model">
    <img alt="Build Status" src="https://travis-ci.org/polettix/Ordeal-Model.svg?branch=master">
    </a>

    <a href="https://www.perl.org/">
    <img alt="Perl Version" src="https://img.shields.io/badge/perl-5.10+-brightgreen.svg">
    </a>

    <a href="https://badge.fury.io/pl/Ordeal-Model">
    <img alt="Current CPAN version" src="https://badge.fury.io/pl/Ordeal-Model.svg">

    </a>

    <a href="http://cpants.cpanauthors.org/dist/Ordeal-Model">
    <img alt="Kwalitee" src="http://cpants.cpanauthors.org/dist/Ordeal-Model.png">
    </a>

    <a href="http://www.cpantesters.org/distro/O/Ordeal-Model.html?distmat=1">
    <img alt="CPAN Testers" src="https://img.shields.io/badge/cpan-testers-blue.svg">
    </a>

    <a href="http://matrix.cpantesters.org/?dist=Ordeal-Model">
    <img alt="CPAN Testers Matrix" src="https://img.shields.io/badge/matrix-@testers-blue.svg">
    </a>
</div>

# SYNOPSIS

    use Ordeal::Model;

    # get a list of all cards, either as an iterator or as a list
    my $cards_iterator = get_cards();
    my $card = $cards_iterator->();
    my @cards = get_cards();

    # get a list of cards, based on a query. Again, both interfaces
    # are available, we'll use the iterator from now on
    my $it = get_cards(query => {group => ['mine']});
    my $it = get_cards(query => {group => ['a', 'b'], id => \@ids});

    # get one single card, by identifier. Two alternatives:
    my $card = get_card($id);
    my $card = get_cards(query => {id => [$id]})->();

# DESCRIPTION

This module allows you to manage cards and group them into decks. The
main goal is to provide an easy mean to shuffle decks and get some cards
out of them.

# METHODS

## **get\_card**

    my $card = $o->get_card($id);

get a card.

## **get\_cards**

    my @cards    = $o->get_cards(%args); # list-returning interface
    my $iterator = $o->get_cards(%args); # iterator-returning interface

get a list of cards. The following keys are supported in `%args`:

- `query`

    a filtering to the queried data. This will be somehow a flux in the
    beginning, although providing either a value or a list of verbatim
    values for any field in a card SHOULD be supported and future proof.

## **get\_deck**

    my @cards    = $o->get_deck($id); # list-returning interface
    my $iterator = $o->get_deck($id); # iterator-returning

get a deck, ordered. See also ["get\_shuffled\_cards"](#get_shuffled_cards).

## **get\_shuffled\_cards**

    my @cards    = $o->get_shuffled_cards(%args); # list
    my $iterator = $o->get_shuffled_cards(%args); # scalar

get shuffled cards from one or more shuffles/decks.

This method uses [Ordeal::Model::ShuffleSet::create](https://metacpan.org/pod/Ordeal::Model::ShuffleSet::create) behind the scenes,
to which it forwards most of the parameters in `%args`. Any parameter
described in [Ordeal::Model::ShuffleSet](https://metacpan.org/pod/Ordeal::Model::ShuffleSet) and not below is a
documentation bug!

Supported keys are:

- `auto_reshuffle`

    automatically reshuffle the whole set after each draw (allows easy
    simulation of dice).

- `items`

    reference to an array of items to be part of the
    [Ordeal::Model::ShuffleSet](https://metacpan.org/pod/Ordeal::Model::ShuffleSet). The exact shape of
    an input item is described in [Ordeal::Model::ShuffleSet](https://metacpan.org/pod/Ordeal::Model::ShuffleSet); in this
    context, it suffices to say that you can provide a list of plain deck
    identifiers and they will be turned into shuffles;

- `default_n_draw`

    the default number of cards to be drawn from a shuffle. Defaults to
    `undef` (i.e. it will translate to whatever default is the shuffle).

- `n`

    call [Ordeal::Model::ShuffleSet::draw](https://metacpan.org/pod/Ordeal::Model::ShuffleSet::draw) this number of times. Defaults
    to `1`.

- `random_source`

    a default random source to be used in common by all shuffles. Any specific
    random source set in a definition overrides this, even an explicit
    `undef` taht will trigger creation of a shuffle-specific random source.
    It is not used for items passed as shuffles.

- `random_source_state`

    opaque data useful for fully restoring the state of a random data
    source. The actual usage of these data is up to the module implementing
    the random data source. It is passed to method `restore` of whatever
    random data source is available, i.e. either the one provided by
    `%args` or, as a fallback, an instance of [Ordeal::Model::ChaCha20](https://metacpan.org/pod/Ordeal::Model::ChaCha20).

- `seed`

    this parameter is consumed internally in this method, and in particular
    it is used for creating a new instance of [Ordeal::Model::ChaCha20](https://metacpan.org/pod/Ordeal::Model::ChaCha20) if
    ["random\_source"](#random_source) is not present.

The list-context invocation returns the cards directly. The
scalar-context invocation returns an iterator to go through the
`$args{n}` draws sequentially, like this:

    my $iterator = $o->get_shuffled_cards(%args);
    while (my @cards = $iterator->()) {
       # ... use @cards
    }

Note that the `$iterator` function always returns a list; hence, you
will probably want to avoid to call it in scalar context, because
otherwise it will return the number of cards of the specific draw.

# BUGS AND LIMITATIONS

The code leverages some experimental Perl features like signatures and
postderef; for this reason, at least perl 5.20 will be needed.

Report bugs through GitHub (patches welcome) at
[https://github.com/polettix/Ordeal-Model](https://github.com/polettix/Ordeal-Model).

# AUTHOR

Flavio Poletti <polettix@cpan.org>

# COPYRIGHT AND LICENSE

Copyright (C) 2018 by Flavio Poletti <polettix@cpan.org>

This module is free software. You can redistribute it and/or modify it
under the terms of the Artistic License 2.0.

This program is distributed in the hope that it will be useful, but
without any warranty; without even the implied warranty of
merchantability or fitness for a particular purpose.
