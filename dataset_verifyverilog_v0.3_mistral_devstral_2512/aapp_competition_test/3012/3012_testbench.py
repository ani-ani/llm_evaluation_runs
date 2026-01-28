import cocotb
from cocotb.triggers import Timer
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
MOD = 1000000007

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

def is_value_defined(value):
    try:
        int(value)
        return True
    except ValueError:
        return False

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def mod_pow(base, exp, mod):
    result = 1
    base = base % mod
    while exp > 0:
        if exp % 2 == 1:
            result = (result * base) % mod
        exp = exp >> 1
        base = (base * base) % mod
    return result

def compute_expected(a11, a12, a21, a22, N):
    if (a11 > 0 and a12 == 0 and a21 == 0 and a22 == 0) or \
       (a12 > 0 and a11 == 0 and a21 == 0 and a22 == 0) or \
       (a21 > 0 and a11 == 0 and a12 == 0 and a22 == 0) or \
       (a22 > 0 and a11 == 0 and a12 == 0 and a21 == 0):
        if a11 > 0:
            P = a11
        elif a12 > 0:
            P = a12
        elif a21 > 0:
            P = a21
        else:
            P = a22
        if N == 0:
            return 1
        elif P < 2:
            return 0
        elif N == 1:
            return (P * (P - 1)) % MOD
        else:
            part1 = (P * (P - 1)) % MOD
            part2 = mod_pow(P - 2, N - 1, MOD)
            return (part1 * part2) % MOD
    else:
        return 0

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_move_sequences(dut):
    """Test the move_sequences module."""
    
    if not all(has_signal(dut, name) for name in ['a11', 'a12', 'a21', 'a22', 'N', 'result']):
        raise TestFailure("Missing required signals")
    
    test_cases = [
        (3, 0, 0, 0, 3),   # Sample 1
        (3, 0, 0, 0, 1),   # P=3, N=1
        (3, 0, 0, 0, 2),   # P=3, N=2
        (4, 0, 0, 0, 4),   # P=4, N=4
        (2, 0, 0, 0, 3),   # P=2, N=3
        (0, 4, 0, 0, 3),   # all type12
        (0, 0, 5, 0, 2),   # all type21
        (0, 0, 0, 6, 1),   # all type22
        (1, 0, 0, 0, 1),   # P=1 -> 0
        (1, 0, 0, 0, 2),   # P=1 -> 0
        (0, 0, 0, 0, 3),   # P=0 -> 0
    ]
    
    passed = 0
    failed = 0
    
    for i, (a11, a12, a21, a22, N) in enumerate(test_cases):
        dut.a11.value = a11
        dut.a12.value = a12
        dut.a21.value = a21
        dut.a22.value = a22
        dut.N.value = N
        
        await Timer(100, units='ns')
        
        if not is_value_defined(dut.result.value):
            raise TestFailure(f"Test {i+1}: result is undefined")
        
        result = int(dut.result.value)
        expected = compute_expected(a11, a12, a21, a22, N)
        
        if result != expected:
            raise TestFailure(f"Test {i+1}: expected {expected}, got {result}")
        else:
            dut._log.info(f"Test {i+1} passed: result = {result}")
            passed += 1
    
    dut._log.info(f"{'='*50}")
    dut._log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")
