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

@cocotb.test(timeout_time=1, timeout_unit='ms')
async def test_eat_basic(dut):
    """Test basic eat functionality with various inputs."""
    
    # Test cases: (number, need, remaining, expected_total, expected_left)
    test_cases = [
        (5, 6, 10, 11, 4),    # eat(5, 6, 10) -> [11, 4]
        (4, 8, 9, 12, 1),     # eat(4, 8, 9) -> [12, 1]
        (1, 10, 10, 11, 0),   # eat(1, 10, 10) -> [11, 0]
        (2, 11, 5, 7, 0),     # eat(2, 11, 5) -> [7, 0]
        (4, 5, 7, 9, 2),      # eat(4, 5, 7) -> [9, 2]
        (4, 5, 1, 5, 0),      # eat(4, 5, 1) -> [5, 0]
        (0, 0, 0, 0, 0),      # Edge: all zero
        (255, 255, 255, 255, 0),  # Edge: max values
        (100, 50, 30, 130, 0),    # Need > remaining
        (100, 30, 50, 130, 20),   # Need < remaining
    ]
    
    for i, (number, need, remaining, expected_total, expected_left) in enumerate(test_cases):
        # Set inputs
        dut.number.value = number
        dut.need.value = need
        dut.remaining.value = remaining
        
        # Wait for combinational propagation
        await Timer(10, units='ns')
        
        # Check outputs are defined
        if not is_value_defined(dut.total.value):
            raise TestFailure(f"Test {i}: total output is undefined (X/Z)")
        if not is_value_defined(dut.left.value):
            raise TestFailure(f"Test {i}: left output is undefined (X/Z)")
        
        # Read results
        actual_total = int(dut.total.value)
        actual_left = int(dut.left.value)
        
        # Verify
        if actual_total != expected_total:
            raise TestFailure(f"Test {i}: total mismatch. Inputs: number={number}, need={need}, remaining={remaining}. Expected {expected_total}, got {actual_total}")
        if actual_left != expected_left:
            raise TestFailure(f"Test {i}: left mismatch. Inputs: number={number}, need={need}, remaining={remaining}. Expected {expected_left}, got {actual_left}")
        
        dut._log.info(f"Test {i} passed: eat({number}, {need}, {remaining}) = [{actual_total}, {actual_left}]")
    
    dut._log.info(f"All {len(test_cases)} tests passed!")
