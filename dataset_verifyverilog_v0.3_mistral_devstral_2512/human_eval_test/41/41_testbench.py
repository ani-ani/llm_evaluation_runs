import cocotb
from cocotb.triggers import Timer
from cocotb.result import TestFailure

def is_value_defined(value):
    """Check if a cocotb value is defined (not X or Z)."""
    try:
        int(value)
        return True
    except ValueError:
        return False

@cocotb.test(timeout_time=1, timeout_unit="ms")
async def test_car_race_collision(dut):
    """Test car_race_collision module with various n values."""
    
    # Test cases from the problem: n=2,3,4,8,10
    test_cases = [
        (2, 4),   # 2*2 = 4 collisions
        (3, 9),   # 3*3 = 9 collisions
        (4, 16),  # 4*4 = 16 collisions
        (8, 64),  # 8*8 = 64 collisions
        (10, 100) # 10*10 = 100 collisions
    ]
    
    passed = 0
    total = len(test_cases)
    
    for i, (n_input, expected) in enumerate(test_cases):
        # Set input
        dut.n.value = n_input
        
        # Wait for combinational logic to propagate
        await Timer(10, units='ns')
        
        # Check if output is defined
        if not is_value_defined(dut.collisions.value):
            raise TestFailure(f"Test {i+1}: Output is undefined (X/Z) for n={n_input}")
        
        # Read result
        result = int(dut.collisions.value)
        
        # Verify
        if result == expected:
            dut._log.info(f"Test {i+1} PASSED: n={n_input}, collisions={result} (expected {expected})")
            passed += 1
        else:
            raise TestFailure(f"Test {i+1} FAILED: n={n_input}, got {result}, expected {expected}")
    
    # Summary
    dut._log.info(f"\nSummary: {passed}/{total} tests passed")
    if passed != total:
        raise TestFailure(f"Only {passed}/{total} tests passed")
