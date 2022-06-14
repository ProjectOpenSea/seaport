certoraRun  certora/munged/conduit/Conduit.sol certora/helpers/DummyERC20A.sol certora/helpers/DummyERC20B.sol \
    --verify Conduit:certora/spec/conduit.spec \
    --solc solc8.13 \
    --staging \
    --optimistic_loop \
    --send_only \
    --msg "Conduit check"
