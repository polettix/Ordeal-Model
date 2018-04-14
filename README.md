# NAME

Ordeal::Model - Manage cards and decks

# VERSION

This document describes Ordeal::Model version {{\[ version \]}}.

<div>
    <a href="https://travis-ci.org/polettix/Ordeal-Model">
    <img alt="Build Status" src="https://travis-ci.org/polettix/Ordeal-Model.svg?branch=master">
    </a>
    <a href="https://www.perl.org/">
    <img alt="Perl Version" src="https://img.shields.io/badge/perl-5.20+-brightgreen.svg">
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

    # leverage Ordeal::Model::Backend::PlainFile
    my $model = Ordeal::Model->new(PlainFile => [base_directory => $dir]);

    # get a card by identifier
    my $card = $model->get_card($card_id);

    # get a deck by identifier
    my $deck = $model->get_deck($deck_id);

    # get shuffled cards, via Ordeal::Model::Shuffler's "evaluate"
    my @cards = $model->get_shuffled_cards(expression => $expr);

    # useful for overriding and provide backends under different
    # namespaces
    my $backend_class = $model->resolve_backend_name($some_name);

# DESCRIPTION

This module allows you to manage cards and group them into decks. The
main goal is to provide an easy mean to shuffle decks and get some cards
out of them.

# METHODS

## **get\_card**

    my $card = $model->get_card($id);

get an [Ordeal::Model::Card](https://metacpan.org/pod/Ordeal::Model::Card) by identifier.

## **get\_deck**

    my $deck = $model->get_deck($id);

get an [Ordeal::Model::Deck](https://metacpan.org/pod/Ordeal::Model::Deck) by identifier.

## **get\_shuffled\_cards**

    my @cards   = $o->get_shuffled_cards(%args); # list
    my $shuffle = $o->get_shuffled_cards(%args); # scalar

get shuffled cards from one or more shuffles/decks.

Supported keys are:

- `expression`

    whatever expression is good for [Ordeal::Model::Shuffler](https://metacpan.org/pod/Ordeal::Model::Shuffler).

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

The list-context invocation returns the cards directly.

The scalar context invocation returns an [Ordeal::Model::Shuffle](https://metacpan.org/pod/Ordeal::Model::Shuffle) object
that you can use to draw cards from, e.g.:

    my @two_cards        = $shuffle->draw(2);
    my @three_more_cards = $shuffle->draw(3);

Be careful that [Ordeal::Model::Shuffle](https://metacpan.org/pod/Ordeal::Model::Shuffle) will throw an exception if you
try to draw more cards than available!

## **new**

    my $model = Ordeal::Model->new(%args); # OR
    my $model = Ordeal::Model->new(\%args);

constructor.

The `%args` hash can contain only one key/value pair. If the key is
`backend`, then the value MUST be either a blessed object to be used as
backend, or an array reference with information suitable for generating
one. In particular, the array form should contain a name that can be
resolved through ["resolve\_backend\_name"](#resolve_backend_name) as the first item, and any
argument for the resolved class as the remaining items, in order as they
are supposed to be consumed by its `new` method.

Otherwise, the key is considered a name suitable for
["resolve\_backend\_name"](#resolve_backend_name), and the associated value MUST be an array/hash
reference that is expanded and passed to the `new` method associated to
the class resolved from the name.

Too complicated? A few examples will hopefull help:

    use Ordeal::Model::Backend::PlainFile;
    my $pf = Ordeal::Model::Backend::PlainFile->new;

    # Case: backend => $blessed_reference
    my $m1 = Ordeal::Model->new(backend => $pf);

    # Case: backend => $array_ref
    my $m2 = Ordeal::Model->new(
       backend => [PlainFile => base_directory => '/some/path']);

    # Case: key different from 'backend', points to an array reference
    my $m3 = Ordeal::Model->new(PlainFile => [base_directory => '/some/path']);

    # Case: key different from 'backend', points to a hash reference
    my $m4 = Ordeal::Model->new(PlainFile => {base_directory => '/some/path'});

If `%args` contains nothing, then [Ordeal::Model::Backend::PlainFile](https://metacpan.org/pod/Ordeal::Model::Backend::PlainFile)
is used with default parameters for its constructor.

## **resolve\_backend\_name**

    my $class_name = $model->resolve_backend_name($name);
    my $class_name = $package>resolve_backend_name($name);

resolve a `$name` for a backend to use - this is a class method.

The resolution process is as follows:

- if `$name` begins with a `-`, then it is considered directly the class
name to be used after removing the initial `-` character. Examples:

        $name = '-Whatever';         # resolves to class Whatever
        $name = '-Whatever::Module'; # resolves to class Whatever::Module

- otherwise, if it contains `::`, but does not begin with `::`, then it is
again considered as the full name to use for the class. Example:

        $name = 'Whatever::Module';  # resolves to class Whatever::Module

- otherwise, it is used to search for a candidate class, first in namespace
`$package . '::Backend::'`, then in namespace
`Ordeal::Model::Backend::`. Examples (assuming that the package you call
it with is `Ordeal::Model`):

        $name = 'Whatever'; # resolves to Ordeal::Model::Backend::Whatever
        $name = '::W::Ever': # resolves to Ordeal::Model::Backend::W::Ever

If you want to be on the _safe side_, always pre-pend `::` if you want
to activate the automatic search for a backend class, and always pre-pend
`-` if you want to specify the full backend class name.

This method is used by ["new"](#new) behind the scenes, so you can override it
to provide a different resolution algorithm.

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
