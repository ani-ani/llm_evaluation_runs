import cocotb
from cocotb.triggers import Timer
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
MAX_N = 1000
MAX_REDS = 4*MAX_N + 4  # 4004

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
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_minesweeper_safe(dut):
    """Main test function for minesweeper safe cells module."""
    
    # Detect module type (combinational or sequential)
    is_sequential = has_signal(dut, 'clk')
    if is_sequential:
        # Our design is combinational, but keep for generality
        cocotb.log.info("Sequential module detected, but we assume combinational")
    
    # Define test cases: (n, expected_safe_count, description)
    test_cases = [
        (1, 0, "n=1, no safe cells"),
        (2, 6, "n=2, 6 safe cells (even indices)"),
        (3, 8, "n=3, 8 safe cells (odd indices)"),
        (4, 10, "n=4, 10 safe cells (even indices)"),
        (5, 12, "n=5, 12 safe cells (odd indices)"),
        (1000, 2002, "n=1000, 2002 safe cells (even indices)"),
    ]
    
    passed = 0
    failed = 0
    
    for n, exp_count, description in test_cases:
        dut._log.info(f"Testing: {description}")
        
        try:
            # Set input n
            dut.n.value = n
            
            # Wait for combinational propagation
            await Timer(10, units='ns')
            
            # Check safe_count
            if not is_value_defined(dut.safe_count.value):
                raise TestFailure("safe_count is undefined (X/Z)")
            safe_count = int(dut.safe_count.value)
            
            if safe_count != exp_count:
                raise TestFailure(f"safe_count mismatch: expected {exp_count}, got {safe_count}")
            
            # Check safe_mask
            if not is_value_defined(dut.safe_mask.value):
                raise TestFailure("safe_mask is undefined (X/Z)")
            
            # Convert safe_mask to integer (handles wide signals)
            mask_val = dut.safe_mask.value
            if isinstance(mask_val, str):
                mask_bin = mask_val.replace(' ', '')
                mask_int = int(mask_bin, 2) if mask_bin else 0
            else:
                mask_int = int(mask_val)
            
            # Compute expected mask
            if n == 1:
                exp_mask_int = 0
            else:
                exp_mask_int = 0
                for i in range(4*n + 4):  # i is 0-based index
                    cell_number = i + 1
                    if (cell_number & 1) == (n & 1):
                        exp_mask_int |= (1 << i)
            
            # Mask only the relevant bits (lower 4*n+4 bits)
            mask_relevant = mask_int & ((1 << (4*n + 4)) - 1)
            
            if mask_relevant != exp_mask_int:
                # Provide detailed binary output for debugging
                exp_bits = bin(exp_mask_int)[2:].zfill(4*n+4)
                act_bits = bin(mask_relevant)[2:].zfill(4*n+4)
                raise TestFailure(
                    f"safe_mask mismatch for n={n}\n"
                    f"Expected (LSB first): {exp_bits}\n"
                    f"Actual (LSB first):   {act_bits}"
                )
            
            dut._log.info(f"  PASS")
            passed += 1
            
        except TestFailure as e:
            dut._log.error(f"  FAIL: {e}")
            failed += 1
    
    # Summary
    dut._log.info(f"{'='*50}")
    dut._log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")