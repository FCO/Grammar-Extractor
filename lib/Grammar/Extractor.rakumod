unit class Grammar::Extractor;

class Step does Iterable {
	has       &.rule;
	has Str   $.name = &!rule.?name;
	has Str   $.code = &!rule.raku;
	has       @.children;
	has Match $.result handles <Str Int pos from orig so not>;
	has Bool  $.bool is rw;

	method Bool(--> Bool()) {
		$!bool // $!result
	}

	method result is raw { $!result }

	method missing(::CLASS:D $ where {$.not}:) {
		$.orig.substr: $.from
	}

	method str-or-missing { $.so ?? $.Str !! $.missing }

	multi method add(Step:D: &rule) {
		@!children.push: my $new = $.WHAT.add: &rule;
		$new
	}

	multi method add(Step:U: &rule) {
		::?CLASS.new: :&rule
	}

	method visit(&visitor) {
		return unless visitor self;
		for @!children { .visit(&visitor) }
	}

	method Seq {
		gather { $.visit: { .take; True } }
	}

	method Array {
		$.Seq.Array
	}

	method iterator {
		$.Seq.iterator
	}

	method matches { @.grep(*.so).map(*.name).Array.Bag }
	method tested  { @.map(*.name).Array.Bag }

	multi method dump(::?CLASS:U:) {}
	multi method dump(::?CLASS:D: UInt :$indent = 0) {
		note "$!name - { $.str-or-missing } -> { $.Bool }".indent: $indent * 4;
		for @!children {
			.dump: :indent($indent + 1)
		}
	}
}

has Bool    $.debug   = False;
has Str     $.code;
has Grammar $.grammar = do {
	my $code = $!code;
	my $module = "Internal::{('a'..'z').roll(30).join}";
	qq:to/END/.EVAL
	my \$grammar;
	module $module \{
		\$grammar = \$code.EVAL
	\}
	\$grammar
	END
}
has Step    $.step handles <matches tested visit Seq dump iterator map grep>;
has Bool    $.Bool;

method Bool(--> Bool()) { $!step }

method !debug(*@data, UInt :$indent = 0) {
	return unless $!debug;
	note @data.join(", ").indent: $indent * 4;
}

submethod TWEAK(|) {
	for $!grammar.^methods.grep: { .WHAT ~~ Regex } -> &rule {
		self!debug: "wrapping {&rule.name}";
		&rule.wrap: my sub (|c) {
			my Step $step   = $_ with $*STEP;
			my UInt $indent = $*INDENT // 0;
			{
				my $*STEP = $step.add: &rule;
				$!step //= $*STEP;

				my $*INDENT = $indent + 1;
				self!debug: :$indent, "BEGIN: {&rule.name} - { c.head.raku }";
				self!pre:   :&rule, :capture(c);

				my Match $result := callsame;
				$*STEP.result     = $result;

				self!debug: :$indent, "END  : {&rule.name} - { $result.raku } -> { ?$result }";
				self!post:  :&rule, :$result;

				return $result
			}
		}
	}
}

method !pre(:&rule, :$capture) {}
method !post(:&rule, :$result) {}

method parse(|c) {
	my Match $result = $!grammar.parse: |c;
	$!Bool = ?$result;
	$!step.bool = $!Bool;
	$result
}
