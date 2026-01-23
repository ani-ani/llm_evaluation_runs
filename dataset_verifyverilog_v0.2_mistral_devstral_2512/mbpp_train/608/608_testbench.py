import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.result import TestFailure

# Bell numbers for testing (n=0 to 8)
BELL_NUMBERS = [1, 1, 2, 5, 15, 52, 203, 877, 4140]

@cocotb.test()
async def test_bell_number_basic(dut):
    """Test basic Bell number computation for n=0 to 8"""
    # Setup clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.n.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    print("
=== Testing Bell Number Computation ===")
    passed = 0
    total = 9
    
    for n in range(9):
        expected = BELL_NUMBERS[n]
        
        # Start computation
        dut.n.value = n
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done signal
        timeout = 200  # Max cycles to wait
        cycles = 0
        while not dut.done.value and cycles < timeout:
            await RisingEdge(dut.clk)
            cycles += 1
        
        if cycles >= timeout:
            raise TestFailure(f"Timeout for n={n}, done never asserted")
        
        # Read result
        actual = int(dut.result.value)
        
        # Print comparison
        print(f"n={n}: Expected={expected}, Got={actual}, Cycles={cycles}")
        
        # Verify
        if actual == expected:
            passed += 1
        else:
            raise TestFailure(f"n={n}: Expected {expected}, got {actual}")
        
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)  # Small gap between tests
    
    print(f"
=== Results: {passed}/{total} tests passed ===")
    assert passed == total, f"Only {passed}/{total} tests passed"

@cocotb.test()
async def test_bell_number_edge_cases(dut):
    """Test edge cases: minimum, maximum, and intermediate values"""
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    print("
=== Testing Edge Cases ===")
    
    test_cases = [
        (0, 1, "n=0 (minimum)"),
        (1, 1, "n=1 (first order)"),
        (4, 15, "n=4 (medium)"),
        (8, 4140, "n=8 (maximum)")
    ]
    
    for n, expected, description in test_cases:
        dut.n.value = n
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for completion
        while not dut.done.value:
            await RisingEdge(dut.clk)
        
        actual = int(dut.result.value)
        print(f"{description}: Expected={expected}, Got={actual}")
        
        if actual != expected:
            raise TestFailure(f"{description}: Expected {expected}, got {actual}")
    
    print("=== All edge cases passed ===")

@cocotb.test()
async def test_bell_number_sequential(dut):
    """Test multiple sequential computations"""
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    print("
=== Testing Sequential Computations ===")
    
    sequence = [3, 5, 2, 7]  # B3=5, B5=52, B2=2, B7=877
    expected_results = [5, 52, 2, 877]
    
    for i, (n, expected) in enumerate(zip(sequence, expected_results)):
        dut.n.value = n
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for completion
        while not dut.done.value:
            await RisingEdge(dut.clk)
        
        actual = int(dut.result.value)
        print(f"Test {i+1}: n={n}, Expected={expected}, Got={actual}")
        
        if actual != expected:
            raise TestFailure(f"Sequential test {i+1} failed: Expected {expected}, got {actual}")
    
    print("=== Sequential tests passed ===")