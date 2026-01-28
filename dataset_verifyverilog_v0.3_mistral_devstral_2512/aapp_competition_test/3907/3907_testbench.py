import cocotb
from cocotb.triggers import Timer
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 16
MAX_M = 16
RESULT_WIDTH = 24

# ============================================================================
# HELPER FUNCTIONS
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

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def pack_w_array(values, element_bits=DATA_WIDTH, max_elements=MAX_M):
    """Pack list of w values into a single integer."""
    result = 0
    for i, val in enumerate(values):
        if i >= max_elements:
            break
        # Ensure value fits in element_bits
        val_clamped = val & ((1 << element_bits) - 1)
        result |= val_clamped << (i * element_bits)
    return result

# ============================================================================
# TESTS
# ============================================================================
@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_beautiful_array(dut):
    """Test the beautiful_array module."""
    
    # Test cases: (n, m, w_list, expected_result)
    test_cases = [
        # Original sample 1: n=5, m=2, w=[2,3] -> expected=5
        (5, 2, [2, 3], 5),
        # Original sample 2: n=100, m=3, w=[2,1,1] -> expected=4
        (100, 3, [2, 1, 1], 4),
        # Original sample 3: n=1, m=2, w=[1,100] -> expected=100
        (1, 2, [1, 100], 100),
        # Additional tests
        (10, 4, [5, 4, 3, 2], 14),  # k=3 (f(3)=4<=10) -> sum top 3: 5+4+3=12? Wait, but we can use k=4? f(4)=8<=10 -> sum=5+4+3+2=14
        (6, 5, [10, 20, 30, 40, 50], 100),  # k=4 (f(4)=8>6) -> k=3 (f(3)=4<=6) -> sum=50+40+30=120? But wait: f(3)=4<=6, yes -> 120
        (2, 5, [1, 2, 3, 4, 5], 9),  # k=2 (f(2)=2<=2) -> sum top2=5+4=9
        (8, 5, [1, 2, 3, 4, 5], 14),  # k=4 (f(4)=8<=8) -> sum top4=5+4+3+2=14
        (3, 3, [10, 20, 30], 50),  # k=2 (f(2)=2<=3) -> sum top2=30+20=50
        (1, 1, [42], 42),  # k=1 (f(1)=1<=1)
        (0, 3, [10, 20, 30], 0),  # n=0 -> no valid k
    ]
    
    passed = 0
    failed = 0
    
    for test_i, (n, m, w_list, expected) in enumerate(test_cases):
        dut._log.info(f"Test {test_i+1}: n={n}, m={m}, w={w_list}, expected={expected}")
        
        # Prepare packed w array
        w_packed = pack_w_array(w_list)
        
        # Set inputs
        dut.n.value = n
        dut.m.value = m
        dut.w_packed.value = w_packed
        
        # Wait for combinational logic to settle
        await Timer(100, units='ns')
        
        # Read result
        if not is_value_defined(dut.result.value):
            raise TestFailure(f"Result is undefined (X/Z)")
        
        result = safe_int(dut.result.value)
        
        # Verify
        if result != expected:
            dut._log.error(f"Test {test_i+1} FAIL: expected {expected}, got {result}")
            failed += 1
        else:
            dut._log.info(f"Test {test_i+1} PASS: result = {result}")
            passed += 1
    
    # Summary
    dut._log.info(f"{'='*50}")
    dut._log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")