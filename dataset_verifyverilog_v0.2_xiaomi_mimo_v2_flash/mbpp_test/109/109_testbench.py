import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from cocotb.result import TestFailure

@cocotb.test()
async def test_odd_equivalent(dut):
    """Test the odd_equivalent module with various inputs."""
    # Create a clock with 10ns period
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset the DUT
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.s.value = 0
    dut.n.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test case 1: s="011001" (6 bits), n=6
    # We map to 8-bit: 01100100
    # Expected result: 6 (all 6 rotations have odd parity)
    dut.s.value = 0b01100100
    dut.n.value = 6
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done signal (should take 10 cycles)
    timeout = 0
    while not dut.done.value and timeout < 20:
        await RisingEdge(dut.clk)
        timeout += 1
    
    if timeout >= 20:
        raise TestFailure("Test case 1: Timeout waiting for done signal")
    
    if dut.result.value != 6:
        raise TestFailure(f"Test case 1: Expected 6, got {int(dut.result.value)}")
    print(f"Test 1 Passed: s=01100100, n=6, result={int(dut.result.value)}")
    
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    
    # Test case 2: s="11011" (5 bits), n=5
    # Map to 8-bit: 11011000
    # Rotations:
    # 0: 11011000 (4 ones - even)
    # 1: 10110001 (4 ones - even)
    # 2: 01100011 (4 ones - even)
    # 3: 11000110 (4 ones - even)
    # 4: 10001101 (4 ones - even)
    # Result: 0
    dut.s.value = 0b11011000
    dut.n.value = 5
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 0
    while not dut.done.value and timeout < 20:
        await RisingEdge(dut.clk)
        timeout += 1
    
    if timeout >= 20:
        raise TestFailure("Test case 2: Timeout waiting for done signal")
    
    if dut.result.value != 0:
        raise TestFailure(f"Test case 2: Expected 0, got {int(dut.result.value)}")
    print(f"Test 2 Passed: s=11011000, n=5, result={int(dut.result.value)}")
    
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    
    # Test case 3: s="1010" (4 bits), n=4
    # Map to 8-bit: 10100000
    # Rotations:
    # 0: 10100000 (2 ones - even)
    # 1: 01000001 (2 ones - even)
    # 2: 10000010 (2 ones - even)
    # 3: 00000101 (2 ones - even)
    # Result: 0
    dut.s.value = 0b10100000    dut.n.value = 4
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 0
    while not dut.done.value and timeout < 20:
        await RisingEdge(dut.clk)
        timeout += 1
    
    if timeout >= 20:
        raise TestFailure("Test case 3: Timeout waiting for done signal")
    
    if dut.result.value != 0:
        raise TestFailure(f"Test case 3: Expected 0, got {int(dut.result.value)}")
    print(f"Test 3 Passed: s=10100000, n=4, result={int(dut.result.value)}")
    
    # Additional test: s="01010101" (4 ones - even), n=4
    # Rotations all have 4 ones (even), result should be 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.s.value = 0b01010101
    dut.n.value = 4
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 0
    while not dut.done.value and timeout < 20:
        await RisingEdge(dut.clk)
        timeout += 1
    
    if timeout >= 20:
        raise TestFailure("Test 4: Timeout waiting for done signal")
    
    if dut.result.value != 0:
        raise TestFailure(f"Test 4: Expected 0, got {int(dut.result.value)}")
    print(f"Test 4 Passed: s=01010101, n=4, result={int(dut.result.value)}")
    
    # Test with all ones: s="11111111", n=8 (all odd - should get 8)
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.s.value = 0b11111111
    dut.n.value = 8
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 0
    while not dut.done.value and timeout < 25:
        await RisingEdge(dut.clk)
        timeout += 1
    
    if timeout >= 25:
        raise TestFailure("Test 5: Timeout waiting for done signal")
    
    if dut.result.value != 8:
        raise TestFailure(f"Test 5: Expected 8, got {int(dut.result.value)}")
    print(f"Test 5 Passed: s=11111111, n=8, result={int(dut.result.value)}")
    
    print("All tests passed!")