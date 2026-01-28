import cocotb
from cocotb.triggers import Timer
from cocotb.result import TestFailure
import random

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================
def is_value_defined(value):
    """Check if a cocotb value is defined (not X or Z)."""
    try:
        int(value)
        return True
    except ValueError:
        return False

def safe_int(value, default=0):
    """Safely convert cocotb value to int, returning default if X/Z."""
    try:
        return int(value)
    except ValueError:
        return default

def has_signal(dut, name):
    """Check if DUT has a signal with given name."""
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

# ============================================================================
# MODULAR ARITHMETIC FOR TESTBENCH
# ============================================================================
MOD = 1000000007

def mod_mul(a, b):
    return (a * b) % MOD

def mod_inv(i):
    # Precomputed inverse for i=1..64
    inv_map = {
        1: 1, 2: 500000004, 3: 333333336, 4: 250000002, 5: 400000003,
        6: 166666668, 7: 142857144, 8: 125000001, 9: 111111112, 10: 100000001,
        11: 90909091, 12: 83333334, 13: 76923077, 14: 71428572, 15: 66666667,
        16: 62500001, 17: 58823530, 18: 55555556, 19: 52631579, 20: 50000001,
        21: 47619048, 22: 45454546, 23: 43478261, 24: 41666667, 25: 40000001,
        26: 38461539, 27: 37037037, 28: 35714286, 29: 34482759, 30: 33333334,
        31: 32258065, 32: 31250001, 33: 30303031, 34: 29411765, 35: 28571429,
        36: 27777778, 37: 27027027, 38: 26315790, 39: 25641026, 40: 25000001,
        41: 24390244, 42: 23809524, 43: 23255814, 44: 22727273, 45: 22222222,
        46: 21739131, 47: 21276596, 48: 20833334, 49: 20408164, 50: 20000001,
        51: 19607844, 52: 19230770, 53: 18867925, 54: 18518519, 55: 18181819,
        56: 17857143, 57: 17543860, 58: 17241380, 59: 16949153, 60: 16666667,
        61: 16393443, 62: 16129033, 63: 15873016, 64: 15625001
    }
    return inv_map.get(i, 0)

def binom(n, r):
    if r > n:
        return 0
    if r == 0:
        return 1
    prod = 1
    for i in range(r):
        prod = mod_mul(prod, n - i)
        prod = mod_mul(prod, mod_inv(i+1))
    return prod

def expected_result(N, X, Y):
    k_max = 0
    for k in range(1, 65):
        if k * X <= N and k * Y <= N:
            k_max = k
    total = 0
    for k in range(1, k_max + 1):
        n1 = N - k * X + k - 1
        r1 = k - 1
        n2 = N - k * Y + k - 1
        r2 = k - 1
        b1 = binom(n1, r1)
        b2 = binom(n2, r2)
        total = (total + mod_mul(b1, b2)) % MOD
    return total

# ============================================================================
# MAIN TEST
# ============================================================================
@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_hopscotch(dut):
    """Test the hopscotch counter with random inputs."""
    
    # No clock/reset needed for combinational design
    
    # Generate random test cases
    random.seed(42)
    test_cases = []
    for _ in range(20):
        N = random.randint(1, 8)
        X = random.randint(1, N)
        Y = random.randint(1, N)
        exp = expected_result(N, X, Y)
        test_cases.append((N, X, Y, exp))
    
    # Additional known examples
    test_cases.append((2, 1, 1, 2))
    test_cases.append((2, 2, 2, 1))
    test_cases.append((3, 1, 1, 6))
    test_cases.append((7, 2, 3, 9))
    
    passed = 0
    failed = 0
    
    for i, (N, X, Y, expected) in enumerate(test_cases):
        # Write inputs
        dut.N.value = N
        dut.X.value = X
        dut.Y.value = Y
        
        # Wait for combinational logic to settle
        await Timer(100, units='ns')
        
        # Read result
        if not is_value_defined(dut.result.value):
            raise TestFailure(f"Test {i}: result is undefined")
        
        result = int(dut.result.value)
        
        if result != expected:
            cocotb.log.error(f"Test {i} failed: N={N}, X={X}, Y={Y}, expected={expected}, got={result}")
            failed += 1
        else:
            cocotb.log.info(f"Test {i} passed: N={N}, X={X}, Y={Y}, result={result}")
            passed += 1
    
    cocotb.log.info(f"\n{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")