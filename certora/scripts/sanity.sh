
make -C certora munged

echo "TODO: fix the sanity script"
exit 1


certoraRun \
    certora/harness/ExampleHarness.sol \ # TODO: change ExampleHarness to main contract harness
    certora/helpers/DummyERC20A.sol    \
    certora/helpers/DummyERC20B.sol    \ # TODO: add contracts for linking and dispatchers
    --verify ExampleHarness:certora/spec/sanity.spec \
    --rule sanity                       \ # TODO: add --link Contract1:field1=Contract2 Contract1:field2=Contract3 for linked fields in main contract _and_ linked contracts
    --solc solc8.0                      \
    --solc_args '["--optimize"]' \
    --settings -t=60, \
    --msg "sanity $1" \
    --staging \
    $*


