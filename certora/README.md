# Running the certora verification tool

These instructions detail the process for running CVT on the (TODO: example) contracts.

Documentation for CVT and the specification language are available
[here](https://certora.atlassian.net/wiki/spaces/CPD/overview)

## Running the verification

The scripts in the `certora/scripts` directory are used to submit verification
jobs to the Certora verification service. These scripts should be run from the
root directory; for example by running

```sh
sh certora/scripts/verifyExampleContract.sh <arguments>
```

TODO: update example above, and add any special information for this customer's
setup

After the job is complete, the results will be available on
[the staging Certora portal](https://vaas-stg.certora.com/) (by default, the
scripts run on our staging cloud).

## Adapting to changes

Some of our rules require the code to be simplified in various ways. Our
primary tool for performing these simplifications is to run verification on a
contract that extends the original contracts and overrides some of the methods.
These "harness" contracts can be found in the `certora/harness` directory.

This pattern does require some modifications to the original code: some methods
need to be made virtual or public, for example. These changes are handled by
applying a patch to the code before verification.

When one of the `verify` scripts is executed, it first applies the patch file
`certora/applyHarness.patch` to the `contracts` directory, placing the output
in the `certora/munged` directory. We then verify the contracts in the
`certora/munged` directory.

If the original contracts change, it is possible to create a conflict with the
patch. In this case, the verify scripts will report an error message and output
rejected changes in the `munged` directory. After merging the changes, run
`make record` in the `certora` directory; this will regenerate the patch file,
which can then be checked into git.

Note: there have been reports of unexpected behavior on mac, see
[issue CUST-62](https://certora.atlassian.net/browse/CUST-62?atlOrigin=eyJpIjoiZWI1MGFjNGZkZGE0NGFlNjkwYjUwYjY2NmE4ZmQ1OTIiLCJwIjoiaiJ9).

