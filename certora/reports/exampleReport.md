---
breaks: false
---

## Example Contract Verification Report

### Contract description

TODO: A brief overview of the contract

### Bugs found and recommendations

TODO: Brief summary of bugs found and recommendations.  These can also be
included in the main report in the parent directory. This might include
stylistic or performance recommendations as well as bugs uncovered by the
rules.

### Assumptions made during verification

TODO: Description of the assumptions underlying each method summary, harnessed
method, or other unsound approximation, and an explanation of why they are
reasonable.  For example, a NONDET summary might mean that we assume that an
external contract does not make calls back into the current contract, or a
DISPATCHER summary might indicate that we assume that external tokens behave
according to some specification (e.g. ERC20).

TODO: The goal of this section is that if we miss any bugs that break our rules, we
should be able to point to an explicit assumption in this list to explain what
assumption doesn't actually hold.

### Important state variables

TODO: Describe your understanding of the internal and external state that
matters.  These may be fields of the contract being verified, but also external
fields (such as the ERC20 balance of the contract), or computed state that
actually depends on several fields.  This is really your description of your
mental model of the contract and the terminology you'll use while describing
your rules, more than an exact description of the fields of the contract.

### Rules

TODO: You should probably break this section up if you have more than a handful
of rules.  For example, you might organize the rules into sections like
invariants, state changes, method specs and high-level rules, or you might
organize them by topic.

TODO: Include a description of each rule in the following format:

(![status])[^footnoteName] `rule_name`
: Brief description

where `![status]` is replaced with one of the four images in ../MainReport.md
(passing, failing, todo, or timeout).  If any rules are failing or you need to
list additional notes (e.g. we didn't check this on the initialize method), you
can write the footnotes as follows:

[^footnoteName]:
    Here is an example footnote.

