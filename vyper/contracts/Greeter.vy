# @version 0.3.1
greeting: String[64]
@external
def __init__(_greeting: String[64]):
    self.greeting = _greeting
@view
@external
def greet() -> String[64]:
    return self.greeting
@external
def setGreeting(_greeting: String[64]):
    self.greeting = _greeting