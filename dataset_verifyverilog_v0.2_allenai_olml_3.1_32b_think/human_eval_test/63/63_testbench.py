import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from cocotb.result import TestFailure

@cocotb.test()
async def test_fibfib_basic(dut):
    """Test basic FibFib computation"""
    # Setup clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Initialize
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.n.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test case 1: n=1, expected=0
    dut.n.value = 1
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done
    timeout = 20
    while not dut.done.value and timeout > 0:
        await RisingEdge(dut.clk)
        timeout -= 1
    
    if timeout == 0:
        raise TestFailure("Timeout waiting for done signal")
    
    result = int(dut.result.value)
    expected = 0
    if result != expected:
        raise TestFailure(f"n=1: Expected {expected}, got {result}")
    print(f"n=1: {result} == {expected} ✓")
    await RisingEdge(dut.clk)
    
    # Test case 2: n=2, expected=1
    dut.n.value = 2
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 20
    while not dut.done.value and timeout > 0:
        await RisingEdge(dut.clk)
        timeout -= 1
    
    if timeout == 0:
        raise TestFailure("Timeout waiting for done signal")
    
    result = int(dut.result.value)
    expected = 1
    if result != expected:
        raise TestFailure(f"n=2: Expected {expected}, got {result}")
    print(f"n=2: {result} == {expected} ✓")
    await RisingEdge(dut.clk)
    
    # Test case 3: n=5, expected=4
    dut.n.value = 5
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 20
    while not dut.done.value and timeout > 0:
        await RisingEdge(dut.clk)
        timeout -= 1
    
    if timeout == 0:
        raise TestFailure("Timeout waiting for done signal")
    
    result = int(dut.result.value)
    expected = 4
    if result != expected:
        raise TestFailure(f"n=5: Expected {expected}, got {result}")
    print(f"n=5: {result} == {expected} ✓")
    await RisingEdge(dut.clk)
    
    # Test case 4: n=8, expected=24
    dut.n.value = 8
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 20
    while not dut.done.value and timeout > 0:
        await RisingEdge(dut.clk)
        timeout -= 1
    
    if timeout == 0:
        raise TestFailure("Timeout waiting for done signal")
    
    result = int(dut.result.value)
    expected = 24
    if result != expected:
        raise TestFailure(f"n=8: Expected {expected}, got {result}")
    print(f"n=8: {result} == {expected} ✓")
    await RisingEdge(dut.clk)
    
    # Test case 5: n=10, expected=81
    dut.n.value = 10
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 20
    while not dut.done.value and timeout > 0:
        await RisingEdge(dut.clk)
        timeout -= 1
    
    if timeout == 0:
        raise TestFailure("Timeout waiting for done signal")
    
    result = int(dut.result.value)
    expected = 81
    if result != expected:
        raise TestFailure(f"n=10: Expected {expected}, got {result}")
    print(f"n=10: {result} == {expected} ✓")
    await RisingEdge(dut.clk)
    
    # Test case 6: n=12, expected=274
    dut.n.value = 12
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 20
    while not dut.done.value and timeout > 0:
        await RisingEdge(dut.clk)
        timeout -= 1
    
    if timeout == 0:
        raise TestFailure("Timeout waiting for done signal")
    
    result = int(dut.result.value)
    expected = 274
    if result != expected:
        raise TestFailure(f"n=12: Expected {expected}, got {result}")
    print(f"n=12: {result} == {expected} ✓")
    await RisingEdge(dut.clk)
    
    # Test case 7: n=14, expected=927
    dut.n.value = 14
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 20
    while not dut.done.value and timeout > 0:
        await RisingEdge(dut.clk)
        timeout -= 1
    
    if timeout == 0:
        raise TestFailure("Timeout waiting for done signal")
    
    result = int(dut.result.value)
    expected = 927
    if result != expected:
        raise TestFailure(f"n=14: Expected {expected}, got {result}")
    print(f"n=14: {result} == {expected} ✓")
    await RisingEdge(dut.clk)
    
    # Test case 8: n=0, expected=0 (edge case)
    dut.n.value = 0
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 20
    while not dut.done.value and timeout > 0:
        await RisingEdge(dut.clk)
        timeout -= 1
    
    if timeout == 0:
        raise TestFailure("Timeout waiting for done signal")
    
    result = int(dut.result.value)
    expected = 0
    if result != expected:
        raise TestFailure(f"n=0: Expected {expected}, got {result}")
    print(f"n=0: {result} == {expected} ✓")
    
    print("
=== Summary: 8/8 tests passed ===")