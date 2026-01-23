import cocotb
from cocotb.triggers import Timer
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
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_interesting_subseq(dut):
    """Test the interesting subsequence module with the N=8 sample case."""
    
    # Detect interface (combinational, no clk/rst_n)
    cocotb.log.info("Testing combinational module")
    
    # Define the test case from sample input 3
    N = 8
    S_val = 3
    A_vals = [1, 1, 1, 1, 1, 1, 1, 1]
    expected = [6, 6, 6, 4, 4, 2, 2, 0]
    
    # Set threshold S
    dut.S.value = S_val
    
    # Set array A element by element
    for i in range(N):
        if has_signal(dut, f'A_{i}'):
            getattr(dut, f'A_{i}').value = A_vals[i]
        else:
            dut.A[i].value = A_vals[i]
    
    # Wait for combinational propagation
    await Timer(10, units='ns')
    
    # Verify results
    for i in range(N):
        # Read result[i]
        if has_signal(dut, f'result_{i}'):
            val = getattr(dut, f'result_{i}').value
        else:
            val = dut.result[i].value
        
        if not is_value_defined(val):
            raise TestFailure(f"Result[{i}] is undefined (X/Z)")
        
        actual = int(val)
        exp = expected[i]
        
        if actual != exp:
            raise TestFailure(f"Index {i}: expected {exp}, got {actual}")
        
        dut._log.info(f"result[{i}] = {actual} (OK)")
    
    dut._log.info("All tests passed")