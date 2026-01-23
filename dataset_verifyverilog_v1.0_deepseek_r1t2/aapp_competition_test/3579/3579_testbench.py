import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 8
ARRAY_SIZE = 8  # flattened grid size (4x2)
CLK_PERIOD_NS = 10
MAX_CYCLES = 1000

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
# FIXED-POINT HELPERS
# ============================================================================

FRAC_BITS = 16

def float_to_fixed(f, frac_bits=FRAC_BITS):
    """Convert float to fixed-point integer."""
    return int(f * (1 << frac_bits))

def fixed_to_float(fixed, frac_bits=FRAC_BITS):
    """Convert fixed-point integer to float."""
    return fixed / (1 << frac_bits)

# ============================================================================
# EXPECTED MAD CALCULATION (Python reference)
# ============================================================================

def compute_mad(h, w, a, b, grid):
    """Compute Median of All Densities (MAD) exactly as per problem."""
    # grid is list of lists
    # Compute all rectangles
    densities = []
    for top in range(h):
        for bottom in range(top, h):
            for left in range(w):
                for right in range(left, w):
                    area = (bottom - top + 1) * (right - left + 1)
                    if a <= area <= b:
                        total = 0
                        for i in range(top, bottom + 1):
                            for j in range(left, right + 1):
                                total += grid[i][j]
                        densities.append(total / area)
    if not densities:
        return 0.0
    densities.sort()
    n = len(densities)
    if n % 2 == 1:
        return densities[n // 2]
    else:
        return (densities[n // 2 - 1] + densities[n // 2]) / 2.0

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_mad_calculator(dut):
    """Test the MAD calculator with sample inputs."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset sequence
    dut.rst_n.value = 0
    dut.start.value = 0
    for _ in range(2):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases: (h, w, a, b, grid_list, expected_float)
    # Grid is flattened row-wise: [row0col0, row0col1, row1col0, row1col1, ...]
    test_cases = [
        (
            4, 2, 1, 8,
            [6,5, 2,5, 2,9, 7,13],
            5.25
        ),
        (
            2, 3, 2, 4,
            [6,1,4, 2,7,1],
            3.667
        ),
    ]
    
    for tc_idx, (h, w, a, b, grid_flat, expected_float) in enumerate(test_cases):
        dut._log.info(f"Running test case {tc_idx+1}: h={h}, w={w}, a={a}, b={b}")
        
        # Pack grid into 64-bit vector
        grid_packed = 0
        for i, val in enumerate(grid_flat):
            grid_packed |= (val & 0xFF) << (8 * i)
        
        # Assign inputs
        dut.h.value = h
        dut.w.value = w
        dut.a.value = a
        dut.b.value = b
        dut.grid.value = grid_packed
        
        # Pulse start
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        timeout = 0
        while not (has_signal(dut, 'done') and is_value_defined(dut.done.value) and int(dut.done.value) == 1):
            await RisingEdge(dut.clk)
            timeout += 1
            if timeout > MAX_CYCLES:
                raise TestFailure(f"Timeout waiting for done in test case {tc_idx+1}")
        
        # Read median output
        if not is_value_defined(dut.median.value):
            raise TestFailure(f"Median output is undefined (X/Z) in test case {tc_idx+1}")
        
        median_fixed = int(dut.median.value)
        median_float = fixed_to_float(median_fixed)
        
        # Compute expected using Python reference
        grid_2d = []
        idx = 0
        for i in range(h):
            row = []
            for j in range(w):
                row.append(grid_flat[idx])
                idx += 1
            grid_2d.append(row)
        
        expected = compute_mad(h, w, a, b, grid_2d)
        
        # Compare with tolerance
        error = abs(median_float - expected)
        if error > 1e-3:
            raise TestFailure(
                f"Test case {tc_idx+1}: Expected {expected:.9f}, got {median_float:.9f}, "
                f"error {error:.9f} exceeds 1e-3"
            )
        
        dut._log.info(f"Test case {tc_idx+1}: PASS (median = {median_float:.9f})")
    
    dut._log.info("All tests passed!")