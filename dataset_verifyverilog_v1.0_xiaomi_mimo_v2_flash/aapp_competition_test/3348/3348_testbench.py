import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# MANDATORY HELPER FUNCTIONS
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
# TESTBENCH
# ============================================================================

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_bonbon_arrangement(dut):
    """Test the bonbon arrangement module."""
    
    # Initialize inputs
    dut.a.value = 0
    dut.b.value = 0
    dut.c.value = 0
    
    # Wait for combinational propagation
    await Timer(10, units='ns')
    
    # Test cases: (a, b, c, expected_valid, description)
    test_cases = [
        (10, 3, 3, 0, "Example 1: impossible"),
        (6, 5, 5, 1, "Example 2: valid"),
        (5, 6, 5, 1, "Permutation of (6,5,5)"),
        (5, 5, 6, 1, "Permutation of (6,5,5)"),
        (0, 0, 16, 0, "All one color (invalid)"),
        (8, 4, 4, 0, "Not a permutation of (6,5,5)"),
    ]
    
    passed = 0
    failed = 0
    
    for (a, b, c, exp_valid, desc) in test_cases:
        cocotb.log.info(f"Test: {desc} (a={a}, b={b}, c={c})")
        
        # Set inputs
        dut.a.value = a
        dut.b.value = b
        dut.c.value = c
        
        # Wait for propagation
        await Timer(10, units='ns')
        
        # Read valid
        if not is_value_defined(dut.valid.value):
            cocotb.log.error(f"  FAIL: valid is undefined (X/Z)")
            failed += 1
            continue
        
        valid = int(dut.valid.value)
        
        if valid != exp_valid:
            cocotb.log.error(f"  FAIL: expected valid={exp_valid}, got {valid}")
            failed += 1
            continue
        
        if valid == 1:
            # Read grid and decode
            grid_chars = []
            success = True
            for i in range(4):
                row_chars = []
                for j in range(4):
                    try:
                        # Access 2D array element
                        val = int(dut.grid[i][j].value)
                    except Exception as e:
                        cocotb.log.error(f"  FAIL: Cannot read grid[{i}][{j}]: {e}")
                        failed += 1
                        success = False
                        break
                    
                    # Map to character
                    if val == 0:
                        ch = 'A'
                    elif val == 1:
                        ch = 'B'
                    elif val == 2:
                        ch = 'C'
                    else:
                        cocotb.log.error(f"  FAIL: Invalid grid value {val} at ({i},{j})")
                        failed += 1
                        success = False
                        break
                    row_chars.append(ch)
                if not success:
                    break
                grid_chars.append(''.join(row_chars))
            if success:
                grid_str = '\n'.join(grid_chars)
                cocotb.log.info(f"  PASS: valid=1\n{grid_str}")
                passed += 1
                continue
        else:
            cocotb.log.info(f"  PASS: valid=0 (impossible)")
            passed += 1
    
    # Summary
    cocotb.log.info(f"{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")