certoraRun  certora/mungedReference/Seaport.sol certora/helpers/DummyERC20A.sol certora/helpers/DummyERC20B.sol  \
    --verify Seaport:certora/spec/seaport_sanity.spec \
    --solc solc8.13 \
    --staging Shahar/windows_imports_issue\
    --settings -verboseReachabilityChecks \
    --optimistic_loop \
    --rule sanity_fulfillOrder\
    --send_only \
    --msg "Seaport check"


#  --send_only \
# --solc_args "['--optimize', '200']" \