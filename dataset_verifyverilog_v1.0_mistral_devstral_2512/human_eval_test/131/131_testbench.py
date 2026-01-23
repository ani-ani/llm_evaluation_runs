import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer, FallingEdge
from cocotb.result import TestFailure

# Helper function to check if value is defined (not X or Z)
def is_value_defined(value):
    try:
        int(value)
        return True
    except ValueError:
        return False

# Helper to wait for done with cycle timeout
async def wait_for_done(dut, max_cycles=200):
    """Wait for done signal to go high, with timeout."""
    for cycle in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and dut.done.value == 1:
            return True
    return False

@cocotb.test(timeout_time=2000, timeout_unit="ms")
async def test_digits_product(dut):
    """Test the digits_product module with various inputs."""
    
    # Create and start clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset sequence
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.n.value = 0
    await Timer(50, units="ns")
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases: (input, expected_output)
    test_cases = [
        (5, 5),        # digits(5) == 5
        (54, 5),       # digits(54) == 5
        (120, 1),      # digits(120) == 1
        (5014, 5),     # digits(5014) == 5
        (98765, 315),  # digits(98765) == 315
        (2468, 0),     # digits(2468) == 0 (all even)
    ]
    
    passed = 0
    total = len(test_cases)
    
    for i, (n_val, expected) in enumerate(test_cases):
        dut._log.info(f"Test case {i+1}: n = {n_val}, expected = {expected}")
        
        # Apply input and start pulse
        dut.n.value = n_val
        await RisingEdge(dut.clk)
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        done_received = await wait_for_done(dut, max_cycles=150)
        
        if not done_received:
            raise TestFailure(f"Test {i+1}: Timeout - done never went high")
        
        # Check result is defined
        if not is_value_defined(dut.result.value):
            raise TestFailure(f"Test {i+1}: Result has undefined value (X/Z)")
        
        # Read result
        result = int(dut.result.value)
        
        if result != expected:
            raise TestFailure(f"Test {i+1}: For n={n_val}, expected {expected}, got {result}")
        
        dut._log.info(f"Test {i+1}: PASSED (result={result})")
        passed += 1
        
        # Wait one cycle before next test
        await RisingEdge(dut.clk)
    
    dut._log.info(f"\nSummary: {passed}/{total} tests passed")
    
    if passed != total:
        raise TestFailure(f"Overall: {passed}/{total} tests passed")
