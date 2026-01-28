import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Helper function to calculate factorial in Python
def factorial(n):
    if n <= 1:
        return 1
    result = 1
    for i in range(2, n + 1):
        result *= i
    return result

# Helper function to calculate Brazilian factorial in Python
def special_factorial_py(n):
    result = 1
    for k in range(n, 0, -1):
        result *= factorial(k)
    return result

def is_value_defined(value):
    """Check if a cocotb value is defined (not X or Z)."""
    try:
        int(value)
        return True
    except ValueError:
        return False

@cocotb.test(timeout_time=2000, timeout_unit="ms")
async def test_special_factorial(dut):
    """Test special_factorial module with various inputs."""
    
    # Create clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset sequence
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.n.value = 0
    for _ in range(5):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases: (n, expected_result)
    test_cases = [
        (1, 1),
        (4, 288),
        (5, 34560),
        (7, 125411328000),
    ]
    
    passed = 0
    total = len(test_cases)
    
    for n, expected in test_cases:
        dut._log.info(f"Testing n={n}, expected={expected}")
        
        # Set input and pulse start
        dut.n.value = n
        await RisingEdge(dut.clk)
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done signal with timeout
        max_cycles = 100
        found_done = False
        
        for cycle in range(max_cycles):
            await RisingEdge(dut.clk)
            
            # Check if done is defined
            if not is_value_defined(dut.done.value):
                continue
            
            if dut.done.value == 1:
                found_done = True
                break
        
        if not found_done:
            raise TestFailure(f"Test n={n}: done signal not asserted within {max_cycles} cycles")
        
        # Read result
        if not is_value_defined(dut.result.value):
            raise TestFailure(f"Test n={n}: result is undefined (X/Z)")
        
        result = int(dut.result.value)
        
        if result != expected:
            raise TestFailure(f"Test n={n}: expected {expected}, got {result}")
        
        dut._log.info(f"Test n={n}: PASSED (result={result})")
        passed += 1
        
        # Wait a bit before next test
        await RisingEdge(dut.clk)
    
    dut._log.info(f"\nSummary: {passed}/{total} tests passed")
