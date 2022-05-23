import pytest
from brownie import Greeter, accounts

min_gas_price = 875000000 


@pytest.fixture(scope="module")
def greeter():
    return Greeter.deploy('Hello vyper', {"from": accounts[0], "gas_price": min_gas_price})

def test_constructor(greeter):
    assert greeter.greet() == 'Hello vyper'

def test_set_greeting(greeter):
    greeter.setGreeting('gm', {"gas_price": min_gas_price})
    assert greeter.greet() == 'gm'
