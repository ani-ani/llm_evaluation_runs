import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Helper function to check if signal value is defined (not X or Z)
def is_value_defined(value):
    try:
        int(value)
        return True
    except ValueError:
        return False

@cocotb.test(timeout_time=2000, timeout_unit="ms")
async def test_prime_fib(dut):
    """Test prime_fib module with all required test cases."""
    
    # Create and start clock (10ns period = 100MHz)
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Define test cases: (n, expected_prime_fib)
    test_cases = [
        (1, 2),
        (2, 3),
        (3, 5),
        (4, 13),
        (5, 89),
        (6, 233),
        (7, 1597),
        (8, 28657),
        (9, 514229),
        (10, 433494437),
    ]
    
    passed = 0
    total = len(test_cases)
    
    # Maximum cycles to wait per test
    MAX_CYCLES = 6000
    
    for n, expected in test_cases:
        dut._log.info(f"\nRunning test: n={n}, expecting {expected}")
        
        # Reset sequence
        dut.rst_n.value = 0
        dut.start.value = 0
        dut.n.value = 0
        await Timer(20, units='ns')
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
        
        # Verify IDLE state
        if not is_value_defined(dut.done.value):
            raise TestFailure(f"Test n={n}: done signal undefined after reset")
        if int(dut.done.value) != 0:
            raise TestFailure(f"Test n={n}: done should be 0 in IDLE, got {dut.done.value}")
        
        # Start computation
        dut.n.value = n
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0  # Pulse only for 1 cycle
        
        # Wait for done signal with cycle timeout
        done_found = False
        for cycle in range(MAX_CYCLES):
            await RisingEdge(dut.clk)
            if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                done_found = True
                break
        
        if not done_found:
            raise TestFailure(f"Test n={n}: Timeout after {MAX_CYCLES} cycles - done never went high")
        
        # Read result after done is high
        if not is_value_defined(dut.result.value):
            raise TestFailure(f"Test n={n}: Result is undefined (X/Z) when done=1")
        
        result = int(dut.result.value)
        
        if result != expected:
            raise TestFailure(f"Test n={n}: expected {expected}, got {result}")
        
        dut._log.info(f"  PASS: n={n} -> {result}")
        passed += 1
        
        # Brief pause between tests
        await Timer(50, units='ns')
    
    # Final summary
    dut._log.info(f"\n=== Summary: {passed}/{total} tests passed ===")
    
    if passed != total:
        raise TestFailure(f"Incomplete results: {passed}/{total} tests passed")
