---
breaks: false
---

# Template verification report

## Summary

TODO: This document describes the specification and verification of XXX using the
Certora Prover. The work was undertaken from START_DATE to END_DATE. The latest
commit that was reviewed and run through the Certora Prover was XXX.

TODO: The scope of our verification was the XXX.

TODO: The Certora Prover proved the implementation of the <name> is correct with
respect to the formal rules written by the <name> and the Certora teams. During
the verification process, the Certora Prover discovered bugs in the code listed
in the table below. All issues were promptly corrected, and the fixes were
verified to satisfy the specifications up to the limitations of the Certora
Prover. The Certora development team is currently handling these limitations.
The next section formally defines high level specifications of <name>. <All the
rules are publically available in a public github>.

## Disclaimer

The Certora Prover takes as input a contract and a specification and formally
proves that the contract satisfies the specification in all scenarios.
Importantly, the guarantees of the Certora Prover are scoped to the provided
specification, and the Certora Prover does not check any cases not covered by
the specification.

We hope that this information is useful, but provide no warranty of any kind,
explicit or implied. The contents of this report should not be construed as a
complete guarantee that the contract is secure in all dimensions. In no event
shall Certora or any of its employees be liable for any claim, damages or other
liability, whether in an action of contract, tort or otherwise, arising from,
out of or in connection with the results reported here.

# Detailed Verification Reports

## Notations

![passing]
indicates the rule is formally verified on the latest reviewed commit, with the listed assumptions and simplifications.

![failing]
indicates the rule was violated under one of the tested versions of the code.

![todo]
indicates the rule is not yet formally specified.

![timeout]
indicates that some functions cannot be verified because the rules timed out


[timeout]: https://hackmd.io/_uploads/rJ918RPQY.png "rule times out for some methods"
[passing]: https://hackmd.io/_uploads/Sk5kLCPQF.png "rule passes"
[failing]: https://hackmd.io/_uploads/Sk5kL0PQK.png "rule does not pass for some methods"
[todo]: https://hackmd.io/_uploads/Syq18AD7Y.png    "rule not implemented"

