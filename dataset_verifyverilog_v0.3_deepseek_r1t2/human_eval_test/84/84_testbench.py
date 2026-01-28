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
async def test_digit_sum_binary(dut):
    """Test digit sum and binary conversion module."""
    
    # Helper to compute expected result
    def compute_expected(N):
        # Extract decimal digits
        hundreds = N // 100
        tens = (N % 100) // 10
        ones = N % 10
        digit_sum = hundreds + tens + ones
        # Convert to 5-bit binary
        return digit_sum & 0x1F  # Mask to 5 bits
    
    # Test cases adapted from Python problem
    test_cases = [
        # (input_N, expected_binary_sum, description)
        (1000, 1, "1000 -> digit sum 1 -> binary 1"),  # But N=1000 is out of range for 10-bit
        (1000, 1, "1000 -> 1000 mod 1024 = 1000 -> digits 9+9+9=27 -> 11011"),  # Actually 1000 > 999
        # Let's use valid test cases: 0-999
        (1000, 1, "N=1000 is out of 0-999 range, skip"),  # Skip
    ]
    
    # Valid test cases within 0-999 range
    valid_tests = [
        (1000 % 1024, 1, "1000 with 10-bit truncation = 1000 -> 9+9+9=27 -> 11011"),  # Actually 1000 in 10 bits is 1000
        # Wait, N=1000 > 999. Let's map to valid values
        # 1000 -> digits 1+0+0+0 = 1, but 1000 not in 0-999
        # Let's use these valid ones:
        (100, 1, "100 -> 1+0+0=1 -> 1"),  # Wait 100 is 1+0+0=1? No 1+0+0=1
        (150, 6, "150 -> 1+5+0=6 -> 110"),  # 150 is valid
        (147, 12, "147 -> 1+4+7=12 -> 1100"),  # 147 is valid
        (333, 9, "333 -> 3+3+3=9 -> 1001"),  # 333 is valid, 9=1001
        (963, 18, "963 -> 9+6+3=18 -> 10010"),  # 963 is valid, 18=10010
        (0, 0, "0 -> 0+0+0=0 -> 00000"),  # Edge case
        (999, 27, "999 -> 9+9+9=27 -> 11011"),  # Max case
        (1000, 27, "N=1000 -> truncated to 10 bits -> 1000 -> 9+9+9=27 -> 11011"),  # 1000 in 10 bits is 1000
        (999, 27, "999 -> 27 -> 11011"),
        (99, 18, "99 -> 9+9=18 -> 10010"),
        (10, 1, "10 -> 1+0=1 -> 1"),
        (999, 27, "Max test"),
        (100, 1, "100 -> 1"),
        (150, 6, "150 -> 6"),
        (147, 12, "147 -> 12"),
        (333, 9, "333 -> 9"),
        (963, 18, "963 -> 18"),
    ]
    
    # Filter to ensure N <= 999 (10-bit representation works for 0-1023, but problem says 0-10000)
    # We adapt to 0-999 range
    filtered_tests = [
        (100, 1, "100 -> 1"),
        (150, 6, "150 -> 6"),
        (147, 12, "147 -> 12"),
        (333, 9, "333 -> 9"),
        (963, 18, "963 -> 18"),
        (0, 0, "0 -> 0"),
        (999, 27, "999 -> 27"),
        (99, 18, "99 -> 18"),
        (10, 1, "10 -> 1"),
    ]
    
    passed = 0
    total = len(filtered_tests)
    
    dut._log.info(f"Starting test with {total} test cases")
    
    for i, (n_val, expected, desc) in enumerate(filtered_tests):
        # Set input
        dut.N.value = n_val
        
        # Wait for combinational propagation
        await Timer(100, units='ns')
        
        # Check output validity
        if not is_value_defined(dut.binary_sum.value):
            raise TestFailure(f"Test {i} ({desc}): Output binary_sum is undefined (X/Z)")
        
        # Read result
        result = int(dut.binary_sum.value)
        
        # Verify
        if result == expected:
            dut._log.info(f"Test {i} PASSED: {desc} -> got {result}")
            passed += 1
        else:
            # Calculate what digits we should have
            h = n_val // 100
            t = (n_val % 100) // 10
            o = n_val % 10
            s = h + t + o
            raise TestFailure(f"Test {i} FAILED: {desc}\n  Input: {n_val} (h={h}, t={t}, o={o}, sum={s})\n  Expected: {expected} ({expected:05b})\n  Got: {result} ({result:05b})")
    
    dut._log.info(f"Summary: {passed}/{total} tests passed")
    assert passed == total, f"Only {passed}/{total} tests passed"

# Additional test for boundary values
@cocotb.test(timeout_time=1, timeout_unit='ms')
async def test_edge_cases(dut):
    """Test edge cases and boundary values."""
    
    def is_value_defined(value):
        try:
            int(value)
            return True
        except ValueError:
            return False
    
    def compute_expected(N):
        h = N // 100
        t = (N % 100) // 10
        o = N % 10
        s = h + t + o
        return s & 0x1F
    
    edge_cases = [
        (0, 0, "Minimum value"),
        (1, 1, "Single digit"),
        (9, 9, "Single digit max"),
        (10, 1, "Two digits min"),
        (99, 18, "Two digits max"),
        (100, 1, "Three digits min"),
        (101, 2, "101 -> 1+0+1=2"),
        (111, 3, "111 -> 1+1+1=3"),
        (999, 27, "Three digits max"),
    ]
    
    passed = 0
    total = len(edge_cases)
    
    dut._log.info(f"Testing {total} edge cases")
    
    for i, (n_val, expected, desc) in enumerate(edge_cases):
        dut.N.value = n_val
        await Timer(100, units='ns')
        
        if not is_value_defined(dut.binary_sum.value):
            raise TestFailure(f"Edge {i}: Output undefined")
        
        result = int(dut.binary_sum.value)
        
        if result == expected:
            passed += 1
        else:
            h = n_val // 100
            t = (n_val % 100) // 10
            o = n_val % 10
            s = h + t + o
            raise TestFailure(f"Edge {i} FAILED: {desc}\n  N={n_val}: h={h} t={t} o={o} sum={s}\n  Expected: {expected}, Got: {result}")
    
    dut._log.info(f"Edge cases: {passed}/{total} passed")
    assert passed == total

# Additional test for digit extraction logic
@cocotb.test(timeout_time=1, timeout_unit='ms')
async def test_digit_extraction(dut):
    """Verify digit extraction and summing logic."""
    
    def is_value_defined(value):
        try:
            int(value)
            return True
        except ValueError:
            return False
    
    test_cases = [
        (123, 6, "123 -> 1+2+3=6"),
        (456, 15, "456 -> 4+5+6=15"),
        (789, 24, "789 -> 7+8+9=24"),
        (109, 10, "109 -> 1+0+9=10"),
        (990, 18, "990 -> 9+9+0=18"),
        (200, 2, "200 -> 2+0+0=2"),
        (555, 15, "555 -> 5+5+5=15"),
        (888, 24, "888 -> 8+8+8=24"),
    ]
    
    passed = 0
    total = len(test_cases)
    
    for i, (n_val, expected, desc) in enumerate(test_cases):
        dut.N.value = n_val
        await Timer(100, units='ns')
        
        if not is_value_defined(dut.binary_sum.value):
            raise TestFailure(f"Digit test {i}: Output undefined")
        
        result = int(dut.binary_sum.value)
        
        if result == expected:
            passed += 1
        else:
            raise TestFailure(f"Digit test {i} FAILED: {desc}\n  Expected {expected}, got {result}")
    
    dut._log.info(f"Digit extraction tests: {passed}/{total} passed")
    assert passed == total
