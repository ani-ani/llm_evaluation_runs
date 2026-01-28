import cocotb
from cocotb.triggers import Timer
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 16
MAX_INPUT = (1 << DATA_WIDTH) - 1  # 65535

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

def python_highest_power_of_2(n):
    """Reference Python implementation."""
    if n == 0:
        return 0
    # Find highest power of 2 <= n
    res = 0
    for i in range(n, 0, -1):
        if ((i & (i - 1)) == 0):
            res = i
            break
    return res

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_highest_power_of_2(dut):
    """Test the highest_power_of_2 module."""
    
    cocotb.log.info("Testing highest_power_of_2 module")
    
    # Combinational module - no clock or reset needed
    # Just wait for propagation delay
    
    # Define test cases
    test_cases = [
        # (input_n, expected_result, description)
        (0, 0, "Zero input"),
        (1, 1, "Minimum positive"),
        (2, 2, "Exact power of 2"),
        (3, 2, "Between 2 and 4"),
        (4, 4, "Exact power of 2"),
        (8, 8, "Exact power of 2"),
        (10, 8, "Test case 1: 10 -> 8"),
        (15, 8, "Just below 16"),
        (16, 16, "Exact power of 2"),
        (19, 16, "Test case 2: 19 -> 16"),
        (31, 16, "Just below 32"),
        (32, 32, "Test case 3: 32 -> 32"),
        (33, 32, "Just above 32"),
        (255, 128, "0xFF -> 128"),
        (256, 256, "Exact power of 2"),
        (1000, 512, "Mid-range value"),
        (32767, 16384, "15-bit max"),
        (32768, 32768, "Exact 2^15"),
        (65535, 32768, "16-bit max"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (input_n, expected, description) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}/{len(test_cases)}: {description}")
        cocotb.log.info(f"  Input n = {input_n} (0x{input_n:04X})")
        
        try:
            # Set input
            if has_signal(dut, 'n'):
                dut.n.value = clamp_to_width(input_n, DATA_WIDTH)
            elif has_signal(dut, 'n_i'):
                dut.n_i.value = clamp_to_width(input_n, DATA_WIDTH)
            else:
                raise TestFailure("Cannot find input signal 'n' or 'n_i'")
            
            # Wait for combinational propagation
            # Most FPGA tools need ~1-10ns for small logic
            await Timer(50, units='ns')
            
            # Read output
            if has_signal(dut, 'result'):
                output_signal = dut.result
            elif has_signal(dut, 'result_o'):
                output_signal = dut.result_o
            else:
                raise TestFailure("Cannot find output signal 'result' or 'result_o'")
            
            # Validate output is defined
            if not is_value_defined(output_signal.value):
                raise TestFailure(f"Output is undefined (X/Z)")
            
            # Read and convert result
            result = int(output_signal.value)
            
            # Verify
            if result != expected:
                raise TestFailure(f"Expected {expected} (0x{expected:04X}), got {result} (0x{result:04X})")
            
            # Additional verification: result must be power of 2
            if result != 0:
                if (result & (result - 1)) != 0:
                    raise TestFailure(f"Result {result} is not a power of 2")
            
            # Additional verification: result <= input
            if result > input_n and input_n != 0:
                raise TestFailure(f"Result {result} > input {input_n}")
            
            cocotb.log.info(f"  PASS: result = {result} (0x{result:04X})")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    # Summary
    cocotb.log.info(f"{'='*60}")
    cocotb.log.info(f"Test Summary: {passed}/{passed+failed} passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")