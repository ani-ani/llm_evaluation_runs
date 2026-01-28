import cocotb
from cocotb.triggers import Timer
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 8
MAX_DIGITS = 8
RESULT_WIDTH = 32

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

def clamp_to_width(value, bits):
    """Clamp value to fit within specified bit width."""
    max_val = (1 << bits) - 1
    return min(max_val, max(0, value))

# ============================================================================
# ARRAY ACCESS HELPERS
# ============================================================================

async def write_digits(dut, digits):
    """Write digits to individual ports arr_0 through arr_7."""
    # Ensure we don't exceed maximum
    if len(digits) > MAX_DIGITS:
        raise ValueError(f"Too many digits: {len(digits)} (max {MAX_DIGITS})")
    
    # Write each digit to corresponding port
    for i in range(MAX_DIGITS):
        port_name = f"arr_{i}"
        if has_signal(dut, port_name):
            if i < len(digits):
                # Clamp digit value to DATA_WIDTH
                val = clamp_to_width(digits[i], DATA_WIDTH)
                getattr(dut, port_name).value = val
            else:
                # Set unused ports to 0
                getattr(dut, port_name).value = 0
        else:
            raise TestFailure(f"Signal {port_name} not found")
    
    # Set length
    dut.len.value = len(digits)

async def read_result(dut):
    """Read result from DUT."""
    if not is_value_defined(dut.result.value):
        raise TestFailure("Result is undefined (X/Z)")
    return int(dut.result.value)

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_find_max_num(dut):
    """Test the find_max_num module."""
    
    # Wait for combinational logic to settle
    await Timer(10, units='ns')
    
    # Test cases: (input_digits, expected_output, description)
    test_cases = [
        ([1, 2, 3], 321, "Three digits: 1,2,3"),
        ([4, 5, 6, 1], 6541, "Four digits: 4,5,6,1"),
        ([1, 2, 3, 9], 9321, "Four digits: 1,2,3,9"),
        ([9], 9, "Single digit"),
        ([0, 0, 1, 2], 2100, "With zeros"),
        ([5, 5, 5, 5, 5], 55555, "All same digits"),
        ([1, 0, 3, 0, 2], 32100, "Mixed with zeros"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (digits, expected, description) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {description}")
        cocotb.log.info(f"  Input: {digits}")
        cocotb.log.info(f"  Expected: {expected}")
        
        try:
            # Write inputs
            await write_digits(dut, digits)
            
            # Wait for combinational logic to propagate
            await Timer(20, units='ns')
            
            # Read result
            result = await read_result(dut)
            
            # Verify
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            cocotb.log.info(f"  Result: {result} [PASS]")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
        except Exception as e:
            cocotb.log.error(f"  ERROR: {e}")
            failed += 1
    
    # Summary
    cocotb.log.info(f"{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")