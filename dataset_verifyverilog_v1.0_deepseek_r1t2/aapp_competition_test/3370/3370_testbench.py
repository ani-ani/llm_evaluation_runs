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
    """Clamp value to fit within specified bit width."""
    max_val = (1 << bits) - 1
    if value < 0:
        # Handle signed values
        return from_signed(max(-((1 << (bits-1))), min((1 << (bits-1)) - 1, value)), bits)
    return min(max_val, max(0, value))

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 32
ARRAY_SIZE = 4
CLK_PERIOD_NS = 10
MAX_CYCLES = 10000
FRAC_BITS = 16  # Q16.16 fixed-point

# ============================================================================
# FIXED-POINT HELPERS
# ============================================================================
def float_to_fixed(f):
    """Convert float to Q16.16 fixed-point."""
    return int(f * (1 << FRAC_BITS))

def fixed_to_float(fixed):
    """Convert Q16.16 fixed-point to float."""
    return fixed / (1 << FRAC_BITS)

# ============================================================================
# ARRAY WRITE HELPER
# ============================================================================
async def write_heights(dut, heights, N):
    """Write heights to individual h0..h3 ports."""
    for i in range(N):
        if i == 0:
            dut.h0.value = clamp_to_width(heights[i], DATA_WIDTH)
        elif i == 1:
            dut.h1.value = clamp_to_width(heights[i], DATA_WIDTH)
        elif i == 2:
            dut.h2.value = clamp_to_width(heights[i], DATA_WIDTH)
        elif i == 3:
            dut.h3.value = clamp_to_width(heights[i], DATA_WIDTH)
    # Set unused to 0
    for i in range(N, 4):
        if i == 0:
            dut.h0.value = 0
        elif i == 1:
            dut.h1.value = 0
        elif i == 2:
            dut.h2.value = 0
        elif i == 3:
            dut.h3.value = 0

# ============================================================================
# EXPECTED RESULT COMPUTATION (Python)
# ============================================================================
def compute_expected(N, k, heights):
    """Simulate the remodeling process until convergence."""
    h = [float(heights[i]) for i in range(N)]
    k_float = float(k)
    max_iter = 100000
    for _ in range(max_iter):
        changed = False
        for i in range(N):
            left = h[i-1] if i > 0 else 0.0
            right = h[i+1] if i < N-1 else 0.0
            target = (left + right) / 2.0 + k_float
            if h[i] < target:
                h[i] = target
                changed = True
        if not changed:
            break
    return max(h) if h else 0.0

# ============================================================================
# MAIN TEST
# ============================================================================
@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_eagleton_tallest(dut):
    """Test the EagletonTallest module."""
    # Setup clock
    if has_signal(dut, 'clk'):
        cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
        # Reset
        dut.rst_n.value = 0
        dut.start.value = 0
        for _ in range(2):
            await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
    else:
        await Timer(100, units='ns')
    
    # Test cases
    test_cases = [
        {
            "N": 3,
            "k": 1.0,
            "heights": [39.0, 10.0, 40.0],
            "expected": 40.5
        },
        {
            "N": 5,
            "k": 0.1,
            "heights": [1.01e6, 1000.0, 100.0, 20.45, 0.0],
            "expected": 1010000.0
        },
        {
            "N": 1,
            "k": 0.5,
            "heights": [10.0],
            "expected": 10.0
        },
    ]
    
    for i, case in enumerate(test_cases):
        dut._log.info(f"Running test case {i+1}: N={case['N']}, k={case['k']}, heights={case['heights']}")
        
        # Convert to fixed-point
        k_fixed = float_to_fixed(case['k'])
        heights_fixed = [float_to_fixed(h) for h in case['heights']]
        expected_fixed = float_to_fixed(case['expected'])
        
        # Set inputs
        dut.N.value = case['N']
        dut.k.value = k_fixed
        await write_heights(dut, heights_fixed, case['N'])
        
        # Pulse start
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        cycles = 0
        while not (has_signal(dut, 'done') and is_value_defined(dut.done.value) and int(dut.done.value) == 1):
            await RisingEdge(dut.clk)
            cycles += 1
            if cycles > MAX_CYCLES:
                raise TestFailure(f"Test {i+1}: Timeout waiting for done")
        
        # Read result
        if not is_value_defined(dut.result.value):
            raise TestFailure(f"Test {i+1}: Result is undefined")
        
        result_fixed = int(dut.result.value)
        result_float = fixed_to_float(result_fixed)
        expected_float = case['expected']
        
        # Compare with tolerance
        if abs(result_float - expected_float) > 1e-6:
            raise TestFailure(f"Test {i+1}: Expected {expected_float}, got {result_float}")
        
        dut._log.info(f"Test {i+1}: PASS (result={result_float})")
    
    dut._log.info("All tests passed!")
