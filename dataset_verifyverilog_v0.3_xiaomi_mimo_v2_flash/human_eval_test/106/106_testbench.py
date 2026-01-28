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

@cocotb.test(timeout_time=100, timeout_unit="ms")
async def test_sequence_generator(dut):
    """Test the sequence_generator module with various n values."""
    
    # Helper function to compute expected values in Python
    def compute_expected(n):
        result = []
        for i in range(1, n + 1):
            if i % 2 == 0:  # even - factorial
                fact = 1
                for j in range(1, i + 1):
                    fact *= j
                result.append(fact)
            else:  # odd - sum
                total = sum(range(1, i + 1))
                result.append(total)
        return result
    
    # Test cases: (n, expected_first_n_elements)
    test_cases = [
        (1, [1]),
        (2, [1, 2]),
        (3, [1, 2, 6]),
        (4, [1, 2, 6, 24]),
        (5, [1, 2, 6, 24, 15]),
        (7, [1, 2, 6, 24, 15, 720, 28]),
    ]
    
    passed = 0
    total = len(test_cases)
    
    for test_idx, (n, expected_values) in enumerate(test_cases):
        # Set input n
        dut.n.value = n
        
        # Wait for combinational logic to propagate
        await Timer(50, units='ns')
        
        # Read and verify each output element
        for i in range(n):
            # Access result[i] (0-indexed in Verilog)
            if not is_value_defined(dut.result[i].value):
                raise TestFailure(f"Test {test_idx} (n={n}): result[{i}] is undefined (X/Z)")
            
            actual = int(dut.result[i].value)
            expected = expected_values[i]
            
            if actual != expected:
                raise TestFailure(f"Test {test_idx} (n={n}): result[{i}] expected {expected}, got {actual}")
        
        # Verify remaining elements are 0
        for i in range(n, 8):
            if not is_value_defined(dut.result[i].value):
                raise TestFailure(f"Test {test_idx} (n={n}): result[{i}] (should be 0) is undefined")
            
            actual = int(dut.result[i].value)
            if actual != 0:
                raise TestFailure(f"Test {test_idx} (n={n}): result[{i}] should be 0, got {actual}")
        
        dut._log.info(f"Test passed: n={n}, result={expected_values}")
        passed += 1
    
    dut._log.info(f"\nSummary: {passed}/{total} tests passed")
