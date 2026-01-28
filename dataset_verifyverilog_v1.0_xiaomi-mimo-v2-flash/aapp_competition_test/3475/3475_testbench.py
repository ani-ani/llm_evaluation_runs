import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

# Constants
DATA_WIDTH = 16
MAX_POINTS = 16
MAX_MODES = 4
CLK_NS = 10

# Helpers
def is_value_defined(v):
    try: int(v); return True
    except (ValueError, TypeError): return False

def clamp_to_width(v, bits):
    if v < 0: return v & ((1 << bits) - 1) # Return 2's comp
    return min((1 << bits) - 1, max(0, v))

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

def to_signed(val, bits):
    if val >= (1 << (bits-1)):
        return val - (1 << bits)
    return val

async def wait_for_done(dut, max_cycles=2000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def set_arr(dut, name, vals, width):
    for i, v in enumerate(vals):
        if hasattr(dut, name):
            getattr(dut, name)[i].value = clamp_to_width(v, width)
        else:
            # Try port naming scheme: name_0, name_1...
            attr = getattr(dut, f"{name}_{i}", None)
            if attr:
                attr.value = clamp_to_width(v, width)

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_transport_solver(dut):
    """Test the transport solver with generated cases."""
    if has_signal(dut, 'clk'):
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    else:
        await Timer(100, units='ns')

    # Helper to run a test case
    async def run_test(t_modes, n_points, dmin_vals, ang_range_vals, dists, headings, expected_result, expected_valid):
        # Setup inputs
        dut.t_cnt.value = t_modes
        dut.n_cnt.value = n_points
        
        # Write transport parameters
        for i in range(MAX_MODES):
            if i < t_modes:
                if hasattr(dut, f'dmin_t_{i}'):
                    getattr(dut, f'dmin_t_{i}').value = clamp_to_width(dmin_vals[i], DATA_WIDTH)
                if hasattr(dut, f'angle_range_t_{i}'):
                    getattr(dut, f'angle_range_t_{i}').value = clamp_to_width(ang_range_vals[i], DATA_WIDTH)
        
        # Write edge parameters
        edges = n_points - 1
        for i in range(MAX_POINTS - 1):
            if i < edges:
                if hasattr(dut, f'dist_edge_{i}'):
                    getattr(dut, f'dist_edge_{i}').value = clamp_to_width(dists[i], DATA_WIDTH)
                if hasattr(dut, f'heading_edge_{i}'):
                    # Convert signed to 2s comp for HDL
                    val = to_signed(headings[i], DATA_WIDTH)
                    getattr(dut, f'heading_edge_{i}').value = val

        # Trigger
        if has_signal(dut, 'start'):
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            await wait_for_done(dut)
        else:
            # Combinational?
            await Timer(200, units='ns')

        # Check outputs
        if not is_value_defined(dut.done.value):
             raise TestFailure("Done signal undefined")
        
        if has_signal(dut, 'valid'):
            valid = int(dut.valid.value)
        else:
            valid = 1
            
        res = int(dut.result.value)
        
        if valid != expected_valid:
             raise TestFailure(f"Valid mismatch. Exp: {expected_valid}, Got: {valid}")
        
        if valid == 1:
            if res != expected_result:
                raise TestFailure(f"Result mismatch. Exp: {expected_result}, Got: {res}")

    # --- Test Case 1: Sample ---
    # 4 modes, 4 points
    # Modes: (100, 30000), (200, 20000), (300, 10000), (400, 0)
    # Edges: (50, 10000), (75, 20000), (400, -40000)
    t_modes1 = 4
    n_points1 = 4
    dmin1 = [100, 200, 300, 400]
    ang1 = [30000, 20000, 10000, 0]
    dist1 = [50, 75, 400]
    head1 = [10000, 20000, -40000]
    # Expected: 2
    await run_test(t_modes1, n_points1, dmin1, ang1, dist1, head1, 2, 1)

    # --- Test Case 2: Impossible ---
    # 1 mode, 3 points
    # Mode: (20, 50000)
    # Edges: (100, 10000), (10, -60000)
    t_modes2 = 1
    n_points2 = 3
    dmin2 = [20]
    ang2 = [50000]
    dist2 = [100, 10]
    head2 = [10000, -60000]
    # Expected: IMPOSSIBLE (valid=0)
    await run_test(t_modes2, n_points2, dmin2, ang2, dist2, head2, 0, 0)

    # --- Test Case 3: Single Segment ---
    # 1 mode, 2 points
    # Mode: (100, 100)
    # Edges: (150, 50)
    t_modes3 = 1
    n_points3 = 2
    dmin3 = [100]
    ang3 = [100]
    dist3 = [150]
    head3 = [50]
    # Expected: 0
    await run_test(t_modes3, n_points3, dmin3, ang3, dist3, head3, 0, 1)
