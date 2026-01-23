import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

@cocotb.test()
async def test_starts_one_ends(dut):
    """Test starts_one_ends module with various n values"""
    
    # Setup clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.n.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases: n -> expected result
    test_cases = [
        (1, 1),
        (2, 18),
        (3, 180),
        (4, 1800),
        (5, 18000),
        (6, 180000)  # Extended test case
    ]
    
    passed = 0
    total = len(test_cases)
    
    for n, expected in test_cases:
        # Start computation
        dut.n.value = n
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for DONE state (3 cycles latency)
        for _ in range(3):
            await RisingEdge(dut.clk)
        
        # Read result
        actual = int(dut.result.value)
        done = int(dut.done.value)
        
        if done != 1:
            raise TestFailure(f"Done signal not asserted for n={n}")
        
        if actual != expected:
            raise TestFailure(f"n={n}: expected {expected}, got {actual}")
        
        print(f"Test passed: n={n} -> {actual}")
        passed += 1
        
        # Small delay between tests
        await Timer(20, units='ns')
        await RisingEdge(dut.clk)
    
    print(f"
{passed}/{total} tests passed")
