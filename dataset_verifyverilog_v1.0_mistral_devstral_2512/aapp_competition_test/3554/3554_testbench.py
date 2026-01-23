import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION - Adjust these to match your HDL design
# ============================================================================
CLK_PERIOD_NS = 10
MAX_CYCLES = 1000

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

def is_value_defined(value):
    """Check if a cocotb value is defined (not X or Z)."""
    try:
        float(value)
        return True
    except (ValueError, TypeError):
        return False

def safe_int(value, default=0):
    """Safely convert cocotb value to int, returning default if X/Z."""
    try:
        return int(value)
    except (ValueError, TypeError):
        return default

def to_signed(val, bits):
    """Convert unsigned integer to signed (two's complement)."""
    if val >= (1 << (bits - 1)):
        return val - (1 << bits)
    return val

def from_signed(val, bits):
    """Convert signed integer to unsigned for Verilog assignment."""
    if val < 0:
        return val + (1 << bits)
    return val

def has_signal(dut, name):
    """Check if DUT has a signal with given name."""
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def clamp_to_width(value, bits):
    """Clamp value to fit within specified bit width (unsigned)."""
    max_val = (1 << bits) - 1
    return min(max_val, max(0, value))

# ============================================================================
# COMPUTATION FUNCTION (same as in Verilog)
# ============================================================================

def compute_deliverable(D, W, C):
    """Compute the deliverable amount in ml for verification."""
    F = W / C
    L = D / C
    if F <= 1:
        return max(0, (F - L) * C)
    n = int(F)  # floor
    f = F - n
    d1 = f / (2*n + 1)
    # Compute T_n = sum_{k=1}^{n} 1/(2k-1)
    T_n = sum(1/(2*k-1) for k in range(1, n+1))
    if L >= d1 + T_n:
        return 0.0
    R = L - d1
    target = T_n - R
    T_i = 0.0
    i = 0
    while T_i < target:
        i += 1
        T_i += 1/(2*i - 1)
    deliverable_normalized = i - (2*i - 1) * (T_i - target)
    return deliverable_normalized * C

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_three_headed_monkey(dut):
    """Main test function for Three-Headed Monkey problem."""
    
    # Check if module has required signals
    if not has_signal(dut, 'D') or not has_signal(dut, 'W') or not has_signal(dut, 'C') or not has_signal(dut, 'result'):
        raise TestFailure("DUT missing required signals: D, W, C, result")
    
    # Initialize inputs
    dut.D.value = 0
    dut.W.value = 0
    dut.C.value = 0
    
    # Wait for initial propagation
    await Timer(100, units='ns')
    
    # Define test cases: (D, W, C, expected_result)
    test_cases = [
        (1000, 3000, 1000, 533.3333333333),
        (1000, 500, 1000, 0.0),
        (0, 0, 1, 0.0),  # Zero distance
        (100, 100, 100, 0.0),  # W <= C, D >= W
        (50, 100, 100, 50.0),  # W <= C, D < W
        (1000, 2000, 500, 0.0),  # Destination beyond max distance
    ]
    
    passed = 0
    failed = 0
    
    for i, (D, W, C, expected) in enumerate(test_cases):
        dut._log.info(f"Test {i+1}: D={D}, W={W}, C={C}")
        
        # Set inputs
        dut.D.value = D
        dut.W.value = W
        dut.C.value = C
        
        # Wait for combinational propagation
        await Timer(100, units='ns')
        
        # Read output
        if not is_value_defined(dut.result.value):
            raise TestFailure(f"Result is undefined (X/Z)")
        
        actual = float(dut.result.value)
        
        # Check with tolerance
        tolerance = 1e-7
        if abs(actual - expected) > tolerance:
            dut._log.error(f"  FAIL: Expected {expected}, got {actual}")
            failed += 1
        else:
            dut._log.info(f"  PASS: result = {actual}")
            passed += 1
    
    # Summary
    dut._log.info(f"{'='*50}")
    dut._log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")