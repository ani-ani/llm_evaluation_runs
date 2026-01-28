import cocotb
from cocotb.triggers import Timer
from cocotb.result import TestFailure

# ============================================================================
# MANDATORY HELPER FUNCTIONS - COPY THESE EXACTLY
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
    """Clamp value to fit within specified bit width."""
    max_val = (1 << bits) - 1
    if value < 0:
        # Handle signed values
        return from_signed(max(-((1 << (bits-1))), min((1 << (bits-1)) - 1, value)), bits)
    return min(max_val, max(0, value))

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 8
MAX_N = 8

@cocotb.test(timeout_time=1000, timeout_unit='ms')
async def test_bapc_splitter(dut):
    """Test the bapc_splitter module with given examples."""
    
    # Define test cases: (a, b, c, d, n, l_list, r_list)
    test_cases = [
        (2, 3, 3, 2, 1, [-2], [-1]),
        (1, 2, 3, 4, 3, [-1, 2, 0], [1, 1, -2]),
        (1, 2, 1, 2, 3, [-2, 2, 1], [1, 0, -1]),
    ]
    
    for i, (a, b, c, d, exp_n, exp_l, exp_r) in enumerate(test_cases):
        dut._log.info(f'Test case {i}: a={a}, b={b}, c={c}, d={d}')
        
        # Set inputs
        dut.a.value = a
        dut.b.value = b
        dut.c.value = c
        dut.d.value = d
        
        # Wait for combinational propagation
        await Timer(10, units='ns')
        
        # Read n
        if not is_value_defined(dut.n.value):
            raise TestFailure(f'Test {i}: n is undefined')
        n = int(dut.n.value)
        
        if n != exp_n:
            raise TestFailure(f'Test {i}: expected n={exp_n}, got {n}')
        
        # Read l and r arrays
        l_vals = []
        r_vals = []
        for idx in range(n):
            if not is_value_defined(dut.l[idx].value):
                raise TestFailure(f'Test {i}: l[{idx}] undefined')
            if not is_value_defined(dut.r[idx].value):
                raise TestFailure(f'Test {i}: r[{idx}] undefined')
            l_vals.append(int(dut.l[idx].value))
            r_vals.append(int(dut.r[idx].value))
        
        # Compare
        if l_vals != exp_l:
            raise TestFailure(f'Test {i}: expected l={exp_l}, got {l_vals}')
        if r_vals != exp_r:
            raise TestFailure(f'Test {i}: expected r={exp_r}, got {r_vals}')
        
        dut._log.info(f'Test {i} passed')
    
    dut._log.info('All tests passed')