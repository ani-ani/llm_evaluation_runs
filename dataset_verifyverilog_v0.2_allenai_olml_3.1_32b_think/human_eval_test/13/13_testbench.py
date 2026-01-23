import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from cocotb.result import TestFailure

@cocotb.test()
async def test_gcd_calculator(dut):
    """Test GCD calculator with various test cases"""
    
    # Create clock (10ns period)
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset sequence
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.a.value = 0
    dut.b.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test case 1: gcd(3, 7) = 1
    dut.a.value = 3
    dut.b.value = 7
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for completion (max 32 cycles)
    timeout = 0
    while not dut.done.value and timeout < 40:
        await RisingEdge(dut.clk)
        timeout += 1
    
    if timeout >= 40:
        raise TestFailure("Test case 1: Timeout - did not complete in 40 cycles")
    
    if dut.result.value != 1:
        raise TestFailure(f"Test case 1: Expected 1, got {dut.result.value}")
    
    print(f"Test case 1: gcd(3, 7) = {dut.result.value} ✓")
    await RisingEdge(dut.clk)
    
    # Test case 2: gcd(10, 15) = 5
    dut.a.value = 10
    dut.b.value = 15
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 0
    while not dut.done.value and timeout < 40:
        await RisingEdge(dut.clk)
        timeout += 1
    
    if timeout >= 40:
        raise TestFailure("Test case 2: Timeout")
    
    if dut.result.value != 5:
        raise TestFailure(f"Test case 2: Expected 5, got {dut.result.value}")
    
    print(f"Test case 2: gcd(10, 15) = {dut.result.value} ✓")
    await RisingEdge(dut.clk)
    
    # Test case 3: gcd(49, 14) = 7
    dut.a.value = 49
    dut.b.value = 14
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 0
    while not dut.done.value and timeout < 40:
        await RisingEdge(dut.clk)
        timeout += 1
    
    if timeout >= 40:
        raise TestFailure("Test case 3: Timeout")
    
    if dut.result.value != 7:
        raise TestFailure(f"Test case 3: Expected 7, got {dut.result.value}")
    
    print(f"Test case 3: gcd(49, 14) = {dut.result.value} ✓")
    await RisingEdge(dut.clk)
    
    # Test case 4: gcd(144, 60) = 12
    dut.a.value = 144
    dut.b.value = 60
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 0
    while not dut.done.value and timeout < 40:
        await RisingEdge(dut.clk)
        timeout += 1
    
    if timeout >= 40:
        raise TestFailure("Test case 4: Timeout")
    
    if dut.result.value != 12:
        raise TestFailure(f"Test case 4: Expected 12, got {dut.result.value}")
    
    print(f"Test case 4: gcd(144, 60) = {dut.result.value} ✓")
    await RisingEdge(dut.clk)
    
    # Test case 5: gcd(0, 5) = 5 (edge case)
    dut.a.value = 0
    dut.b.value = 5
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 0
    while not dut.done.value and timeout < 40:
        await RisingEdge(dut.clk)
        timeout += 1
    
    if timeout >= 40:
        raise TestFailure("Test case 5: Timeout")
    
    if dut.result.value != 5:
        raise TestFailure(f"Test case 5: Expected 5, got {dut.result.value}")
    
    print(f"Test case 5: gcd(0, 5) = {dut.result.value} ✓")
    await RisingEdge(dut.clk)
    
    # Test case 6: gcd(5, 0) = 5 (edge case)
    dut.a.value = 5
    dut.b.value = 0
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 0
    while not dut.done.value and timeout < 40:
        await RisingEdge(dut.clk)
        timeout += 1
    
    if timeout >= 40:
        raise TestFailure("Test case 6: Timeout")
    
    if dut.result.value != 5:
        raise TestFailure(f"Test case 6: Expected 5, got {dut.result.value}")
    
    print(f"Test case 6: gcd(5, 0) = {dut.result.value} ✓")
    await RisingEdge(dut.clk)
    
    # Test case 7: gcd(0, 0) = error
    dut.a.value = 0
    dut.b.value = 0
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 0
    while not dut.done.value and timeout < 40:
        await RisingEdge(dut.clk)
        timeout += 1
    
    if timeout >= 40:
        raise TestFailure("Test case 7: Timeout")
    
    if not dut.error.value:
        raise TestFailure(f"Test case 7: Expected error=1, got error={dut.error.value}")
    
    print(f"Test case 7: gcd(0, 0) = error ✓")
    await RisingEdge(dut.clk)
    
    # Test case 8: gcd(17, 31) = 1 (consecutive primes)
    dut.a.value = 17
    dut.b.value = 31
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 0
    while not dut.done.value and timeout < 40:
        await RisingEdge(dut.clk)
        timeout += 1
    
    if timeout >= 40:
        raise TestFailure("Test case 8: Timeout")
    
    if dut.result.value != 1:
        raise TestFailure(f"Test case 8: Expected 1, got {dut.result.value}")
    
    print(f"Test case 8: gcd(17, 31) = {dut.result.value} ✓")
    await RisingEdge(dut.clk)
    
    print("
=== All 8 tests passed ===")