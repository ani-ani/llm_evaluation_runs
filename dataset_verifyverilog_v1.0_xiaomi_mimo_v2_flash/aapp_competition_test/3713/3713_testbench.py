import cocotb
from cocotb.triggers import Timer
from cocotb.result import TestFailure

# ============================================================================
# MANDATORY HELPER FUNCTIONS
# ============================================================================
def is_value_defined(value):
    try:
        int(value)
        return True
    except ValueError:
        return False

def safe_int(value, default=0):
    try:
        return int(value)
    except ValueError:
        return default

# ============================================================================
# TESTBENCH CONFIGURATION
# ============================================================================
DATA_WIDTH = 5
STRING_WIDTH = 16
MAX_N = 16

# Test cases: (n, string, expected)
test_cases = [
    (1, "0", 1),
    (1, "1", 1),
    (2, "00", 2),
    (2, "01", 2),
    (2, "10", 2),
    (2, "11", 2),
    (3, "000", 3),
    (3, "001", 3),
    (3, "010", 3),
    (3, "011", 3),
    (3, "100", 3),
    (3, "101", 3),
    (3, "110", 3),
    (3, "111", 3),
    (4, "0000", 3),
    (4, "0001", 4),
    (4, "0010", 4),
    (4, "0011", 4),
    (4, "0100", 4),
    (4, "0101", 4),
    (4, "0110", 4),
    (4, "0111", 4),
    (4, "1000", 4),
    (4, "1001", 4),
    (4, "1010", 4),
    (4, "1011", 4),
    (4, "1100", 4),
    (4, "1101", 4),
    (4, "1110", 4),
    (4, "1111", 3),
    (5, "00000", 3),
    (5, "00001", 4),
    (5, "00011", 4),
    (5, "00111", 4),
    (5, "01010", 5),
    (5, "11111", 3),
    (16, "0000000000000000", 3),
    (16, "0000000000000001", 4),
    (16, "0101010101010101", 16),
    # Additional test cases from examples
    (8, "10000011", 5),
    (2, "01", 2),
    (5, "10101", 5),
    (75, "010101010101010101010101010101010101010101010101010101010101010101010101010", 75),
    (11, "00000000000", 3),
    (56, "10101011010101010101010101010101010101011010101010101010", 56),
    (50, "01011010110101010101010101010101010101010101010100", 49),
    (7, "0110100", 7),
    (8, "11011111", 5),
    (6, "000000", 3),
    (5, "01000", 5),
]

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_longest_alternating_subsequence(dut):
    """Test the longest_alternating_subsequence module."""
    
    # Initialize inputs
    dut.n.value = 0
    dut.s.value = 0
    
    # Wait for initial propagation
    await Timer(10, units='ns')
    
    passed = 0
    failed = 0
    
    for n_val, s_str, expected in test_cases:
        # Convert string to 16-bit integer (LSB = first character)
        s_val = 0
        for i, char in enumerate(s_str):
            if i >= STRING_WIDTH:
                break
            if char == '1':
                s_val |= (1 << i)
        
        # Clamp n_val to valid range
        if n_val > MAX_N:
            n_val = MAX_N
        
        # Assign inputs
        dut.n.value = n_val
        dut.s.value = s_val
        
        # Wait for combinational logic to settle
        await Timer(10, units='ns')
        
        # Read and verify result
        if not is_value_defined(dut.result.value):
            raise TestFailure(f"Undefined result for n={n_val}, s={s_str}")
        
        result = int(dut.result.value)
        
        if result == expected:
            passed += 1
            dut._log.info(f"PASS: n={n_val}, s={s_str}, result={result}")
        else:
            failed += 1
            raise TestFailure(
                f"FAIL: n={n_val}, s={s_str}\n"
                f"  Expected: {expected}, Got: {result}"
            )
    
    dut._log.info(f"{'='*50}")
    dut._log.info(f"Test Summary: {passed}/{len(test_cases)} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")
