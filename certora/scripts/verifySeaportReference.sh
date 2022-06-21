certoraRun  certora/mungedReference/Seaport.sol certora/helpers/DummyERC20A.sol certora/helpers/DummyERC20B.sol \
    --verify Seaport:certora/spec/seaport.spec \
    --solc solc8.13 \
    --staging \
    --optimistic_loop \
    --send_only \
    --msg "Seaport check"


#  --send_only \
# --solc_args "['--optimize', '200']" \