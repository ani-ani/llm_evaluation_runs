import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
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

def to_signed(val, bits):
    if val >= (1 << (bits - 1)):
        return val - (1 << bits)
    return val

def from_signed(val, bits):
    if val < 0:
        return val + (1 << bits)
    return val

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def clamp_to_width(value, bits):
    max_val = (1 << bits) - 1
    return min(max_val, max(0, value))

# ============================================================================
# TEST CONFIGURATION
# ============================================================================
DATA_WIDTH = 8  # Not used, but included for completeness

# ============================================================================
# MAIN TEST
# ============================================================================
@cocotb.test(timeout_time=1000, timeout_unit='ms')
async def test_card_game(dut):
    """Test the Card Game for Three module with scaled-down inputs."""
    
    # Test cases: (n, m, k, expected_result)
    test_cases = [
        (1, 1, 1, 17),
        (4, 2, 2, 1227),
        (1, 2, 5, 5709),
    ]
    
    passed = 0
    failed = 0
    
    for n, m, k, expected in test_cases:
        cocotb.log.info(f'Testing (n={n}, m={m}, k={k}) -> expected {expected}')
        
        # Set inputs
        dut.n.value = n
        dut.m.value = m
        dut.k.value = k
        
        # Wait for combinational logic to settle
        await Timer(10, units='ns')
        
        # Read result
        if not is_value_defined(dut.result.value):
            raise TestFailure(f'Result is undefined (X/Z)')
        
        result = int(dut.result.value)
        
        if result == expected:
            cocotb.log.info(f'  PASS: result = {result}')
            passed += 1
        else:
            cocotb.log.error(f'  FAIL: expected {expected}, got {result}')
            failed += 1
    
    # Summary
    cocotb.log.info('='*50)
    cocotb.log.info(f'Results: {passed}/{passed+failed} tests passed')
    
    if failed > 0:
        raise TestFailure(f'{failed} tests failed')