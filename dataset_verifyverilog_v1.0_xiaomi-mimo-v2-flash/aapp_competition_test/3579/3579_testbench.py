import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Helpers
def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def clamp_to_width(v, bits):
    max_val = (1 << bits) - 1
    return min(max_val, max(0, v))

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

# Fixed-point conversion
FIXED_SCALE = 65536  # 2^16

def float_to_fixed(f):
    return int(f * FIXED_SCALE)

def fixed_to_float(v):
    return v / FIXED_SCALE

# For sorting median calculation
def compute_median(densities):
    if not densities:
        return 0.0
    sorted_d = sorted(densities)
    n = len(sorted_d)
    mid = n // 2
    if n % 2 == 1:
        return sorted_d[mid]
    else:
        return (sorted_d[mid-1] + sorted_d[mid]) / 2.0

# Helper to write grid
def write_grid(dut, grid_vals):
    # grid_vals is 8x8 list of integers
    for r in range(8):
        for c in range(8):
            dut.grid[r][c].value = clamp_to_width(grid_vals[r][c], 8)

@cocotb.test(timeout_time=2000, timeout_unit="ms")
async def test_mad_module(dut):
    # Check for clock
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
        # Reset
        dut.rst_n.value = 0
        if has_signal(dut, 'start'): dut.start.value = 0
        for _ in range(2): await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
    else:
        # Combinational, just wait for settling
        await Timer(100, units='ns')

    # Test Case 1: 4x2 grid, scaled down to 8x8 or test partial
    # We'll map the sample to a smaller grid for demonstration
    # Input: 4x2, stats: [6,5], [2,5], [2,9], [7,13]
    # Let's create an 8x8 grid by padding zeros or tiling
    # For this test, we use a 4x4 grid with values, rest zeros
    grid_1 = [
        [6, 5, 0, 0, 0, 0, 0, 0],
        [2, 5, 0, 0, 0, 0, 0, 0],
        [2, 9, 0, 0, 0, 0, 0, 0],
        [7, 13, 0, 0, 0, 0, 0, 0],
        [0, 0, 0, 0, 0, 0, 0, 0],
        [0, 0, 0, 0, 0, 0, 0, 0],
        [0, 0, 0, 0, 0, 0, 0, 0],
        [0, 0, 0, 0, 0, 0, 0, 0]
    ]
    a_min_1 = 1  # Area min
    a_max_1 = 8  # Area max
    
    # Expected densities calculation (Python reference)
    densities = []
    h, w = 8, 8  # Grid size in module
    for r1 in range(h):
        for r2 in range(r1, h):
            for c1 in range(w):
                for c2 in range(c1, w):
                    area = (r2 - r1 + 1) * (c2 - c1 + 1)
                    if area >= a_min_1 and area <= a_max_1:
                        total = 0
                        for rr in range(r1, r2+1):
                            for cc in range(c1, c2+1):
                                total += grid_1[rr][cc]
                        if area > 0:
                            density = total / area
                            densities.append(density)
    
    if not densities:
        raise TestFailure("No valid rectangles found for test case 1")
    
    expected_median = compute_median(densities)
    expected_fixed = float_to_fixed(expected_median)
    
    # Load grid
    write_grid(dut, grid_1)
    
    # Set area bounds (if inputs exist)
    if has_signal(dut, 'a_min'):
        dut.a_min.value = a_min_1
        dut.a_max.value = a_max_1
    
    # Start
    if is_seq:
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        max_cycles = 10000
        for _ in range(max_cycles):
            await RisingEdge(dut.clk)
            if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                break
        else:
            raise TestFailure("Timeout waiting for done")
    
    # Read result
    if is_value_defined(dut.result.value):
        result_val = int(dut.result.value)
        # Sign extend if 32-bit signed
        if result_val >= (1 << 31):
            result_val -= (1 << 32)
        
        result_float = fixed_to_float(result_val)
        
        # Allow absolute error tolerance
        abs_err = abs(result_float - expected_median)
        if abs_err > 1e-3:
            raise TestFailure(f"MAD mismatch: expected {expected_median:.6f}, got {result_float:.6f} (err {abs_err:.6f})")
        
        cocotb.log.info(f"Test Passed: MAD = {result_float:.6f}")
    else:
        raise TestFailure("Result signal undefined")