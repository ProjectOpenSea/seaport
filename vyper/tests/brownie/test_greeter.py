import pytest
from brownie import Greeter, accounts


@pytest.fixture(scope="module")
def greeter():
    return Greeter.deploy('Hello vyper', {"from": accounts[0]})


def test_constructor(greeter):
    assert greeter.greet() == 'Hello vyper'

def test_set_greeting(greeter):
    greeter.setGreeting('gm')
    assert greeter.greet() == 'gm'
