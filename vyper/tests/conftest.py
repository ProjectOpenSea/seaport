import pytest

@pytest.fixture(autouse=True)
def isolate(fn_isolation):
    pass