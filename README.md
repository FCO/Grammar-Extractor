[![Actions Status](https://github.com/FCO/Grammar-Extractor/actions/workflows/test.yml/badge.svg)](https://github.com/FCO/Grammar-Extractor/actions)

NAME
====

Grammar::Extractor — Trace and introspect Raku grammar parses with a step-by-step rule tree

SYNOPSIS
========

```raku
use Grammar::Extractor;

# With an existing grammar type
grammar MyGrammar {
    token TOP { <word> '!'? }
    token word { \w+ }
}
my $e = Grammar::Extractor.new(:grammar(MyGrammar));
my $m = $e.parse("hello!");
say $e.Bool;    # True
say $e.step.name;       # TOP
say $e.step.children[0].name;  # word

# With a grammar defined as a string
my $e2 = Grammar::Extractor.new(:code('grammar { token TOP { \d+ } }'));
$e2.parse("42");

# Debug mode prints BEGIN/END traces to stderr
my $e3 = Grammar::Extractor.new(:grammar(MyGrammar), :debug);
$e3.parse("hello!");

# With a pre-built action object (applied on every parse)
my $actions = class { method TOP($/) { say "matched" } }.new;
my $e4 = Grammar::Extractor.new(:grammar(MyGrammar), :actions($actions));
$e4.parse("hello!");  # calls $actions.TOP($/)

# With an action class defined as a string (compiled automatically)
my $e5 = Grammar::Extractor.new(
    :grammar(MyGrammar),
    :actions-code('class A { method TOP($/) { say "matched" } }')
);
$e5.parse("hello!");

# Dump the step tree to stderr
$e.dump;
```

DESCRIPTION
===========

Grammar::Extractor wraps every regex rule in a Grammar at construction time, building a **Step tree** that mirrors the full parse. Each step corresponds to one rule that was tested and stores its result, name, and child steps for sub-rules. This lets you inspect exactly which rules matched, which failed, and what text each consumed — without modifying the grammar itself.

CONSTRUCTOR
===========

:grammar
--------

    my $e = Grammar::Extractor.new(:grammar(MyGrammar));

Accepts an existing [Grammar](Grammar) type. The grammar's regex rules are wrapped at clone time to build the trace tree.

:code
-----

    my $e = Grammar::Extractor.new(:code('grammar { token TOP { \d+ } }'));

Accepts a Raku source string that evaluates to a grammar. Each invocation compiles in an isolated internal namespace, so identical grammar names across instances do not conflict.

:actions
--------

    my $e = Grammar::Extractor.new(:grammar(MyGrammar), :actions($obj));

Accepts an existing action object whose methods (named after grammar rules) will be called automatically on each `.parse` invocation. This avoids passing `:actions` at every parse call. The action object is stored in `$.actions` and can be accessed or replaced.

:actions-code
-------------

    my $e = Grammar::Extractor.new(
        :grammar(MyGrammar),
        :actions-code('class A { method TOP($/) { say "matched" } }')
    );

Like `:actions`, but accepts a Raku source string that defines the action class. The code is compiled in an isolated namespace and instantiated automatically. Useful for inline action definitions.

:debug
------

    my $e = Grammar::Extractor.new(:grammar(MyGrammar), :debug);

When True, prints `BEGIN` / `END` trace lines to stderr for each rule as it is entered and exited during parsing.

METHODS
=======

parse
-----

    my $match = $e.parse($string, :$actions);

Delegates to the underlying grammar's `.parse` method, forwarding all arguments. Returns the [Match](Match) object. After parsing, `.Bool` reflects success and `.step` holds the root of the trace tree.

If `:actions` was set in the constructor, it is automatically forwarded to every `.parse` call. You can still override it per-call: `$e.parse($str, :actions($other))`.

Bool
----

    say $e.Bool;  # True if parse succeeded

Returns whether the most recent `.parse` call succeeded.

dump
----

    $e.dump;

Prints the full step tree to stderr. Each line shows the rule name, matched or missing text, and whether the rule succeeded. Children are indented.

matches / tested
----------------

    say $e.matches;   # Bag of matched rule names
    say $e.tested;    # Bag of all tested rule names

Convenience methods delegated from the root `Step`. `matches` returns a [Bag](Bag) of rule names that matched; `tested` returns a Bag of every rule that was tried during the parse.

visit
-----

    $e.visit: -> $step { say $step.name; True };

Traverses the step tree depth-first. The callback receives each step; return `True` to continue into children, `False` to prune.

Seq / Array
-----------

    my @all-steps = $e.Seq;
    say @all-steps.elems;  # total steps in tree

Returns a flat sequence or array of every step in the tree.

grep / map
----------

    say $e.grep(*.so).elems;  # count successful steps
    say $e.map(*.name);       # all rule names

CLASS: Grammar::Extractor::Step
===============================

Each node in the trace tree.

name
----

    $step.name  # Str — rule name, e.g. "TOP"

children
--------

    $step.children  # Positional of child Step objects

result
------

    $step.result  # Match — the underlying Match object (raw)

Delegates `Str`, `Int`, `pos`, `from`, `orig`, `so`, `not` to the Match.

Bool
----

    $step.Bool  # True if the rule matched

so / not
--------

    $step.so   # True if matched
    $step.not  # True if failed

missing
-------

    $step.missing  # Str — unmatched remainder (only on failure)

Returns the text from `.from` to end of original string.

str-or-missing
--------------

    $step.str-or-missing  # Str — matched text on success, missing on failure

dump
----

    $step.dump(:$indent);

Recursively prints this step and its children to stderr.

Iterable
--------

    .say for $step;  # iterates all descendant steps

Step `does Iterable`, so you can loop over it, call `.map`, `.grep`, etc. The iteration visits all descendants depth-first.

Seq / Array
-----------

    my $all = $step.Seq;     # flat sequence of all steps
    my @arr = $step.Array;   # same as array

visit
-----

    $step.visit: -> $s { say $s.name; True };

Depth-first traversal. Return `True` from the callback to descend into children, `False` to stop.

matches / tested
----------------

    say $step.matches;   # Bag("TOP" => 1, "word" => 1)
    say $step.tested;    # Bag of all rules tried in subtree

`matches` returns a [Bag](Bag) of rule names that succeeded. `tested` returns a Bag of every rule name in the subtree.

AUTHOR
======

Fernando Correa de Oliveira <fco@cpan.org>

COPYRIGHT AND LICENSE
=====================

Copyright 2026 Fernando Correa de Oliveira

This library is free software; you can redistribute it and/or modify it under the Artistic License 2.0.

