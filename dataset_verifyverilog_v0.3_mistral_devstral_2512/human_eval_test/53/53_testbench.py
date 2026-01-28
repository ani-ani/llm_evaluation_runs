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

@cocotb.test(timeout_time=100, timeout_unit='ms')
async def test_adder_basic(dut):
    """Test basic addition cases"""
    
    test_cases = [
        (0, 1, 1),
        (1, 0, 1),
        (2, 3, 5),
        (5, 7, 12),
        (7, 5, 12),
        (0, 0, 0),
        (1000, 1000, 2000),
        (65535, 1, 65536),  # Edge case: 16-bit boundary
    ]
    
    passed = 0
    total = len(test_cases)
    
    for i, (x, y, expected) in enumerate(test_cases):
        # Assign inputs
        dut.x.value = x
        dut.y.value = y
        
        # Wait for combinational logic to settle
        await Timer(10, units='ns')
        
        # Check output validity
        if not is_value_defined(dut.result.value):
            raise TestFailure(f"Test {i}: result is undefined (X/Z)")
        
        # Read result
        result = int(dut.result.value)
        
        if result != expected:
            raise TestFailure(f"Test {i}: add({x}, {y}) = {expected}, got {result}")
        
        dut._log.info(f"Test {i}: add({x}, {y}) = {result} [OK]")
        passed += 1
    
    dut._log.info(f"Summary: {passed}/{total} tests passed")


@cocotb.test(timeout_time=100, timeout_unit='ms')
async def test_adder_random(dut):
    """Test random additions"""
    import random
    
    random.seed(42)  # For reproducibility
    num_tests = 50
    passed = 0
    
    for i in range(num_tests):
        x = random.randint(0, 1000)
        y = random.randint(0, 1000)
        expected = x + y
        
        # Assign inputs
        dut.x.value = x
        dut.y.value = y
        
        # Wait for combinational logic
        await Timer(10, units='ns')
        
        # Check validity
        if not is_value_defined(dut.result.value):
            raise TestFailure(f"Random test {i}: result is undefined")
        
        result = int(dut.result.value)
        
        if result != expected:
            raise TestFailure(f"Random test {i}: add({x}, {y}) = {expected}, got {result}")
        
        passed += 1
    
    dut._log.info(f"Random tests: {passed}/{num_tests} passed")


@cocotb.test(timeout_time=100, timeout_unit='ms')
async def test_adder_edge_cases(dut):
    """Test edge cases"""
    
    # Test with powers of 2
    test_cases = [
        (1, 1, 2),
        (2, 2, 4),
        (4, 4, 8),
        (8, 8, 16),
        (16, 16, 32),
        (32, 32, 64),
        (64, 64, 128),
        (128, 128, 256),
    ]
    
    passed = 0
    total = len(test_cases)
    
    for i, (x, y, expected) in enumerate(test_cases):
        dut.x.value = x
        dut.y.value = y
        
        await Timer(10, units='ns')
        
        if not is_value_defined(dut.result.value):
            raise TestFailure(f"Edge test {i}: result is undefined")
        
        result = int(dut.result.value)
        
        if result != expected:
            raise TestFailure(f"Edge test {i}: add({x}, {y}) = {expected}, got {result}")
        
        dut._log.info(f"Edge test {i}: add({x}, {y}) = {result} [OK]")
        passed += 1
    
    dut._log.info(f"Edge cases: {passed}/{total} tests passed")
