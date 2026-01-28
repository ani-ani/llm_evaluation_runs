import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

DATA_WIDTH = 9
MAX_COORD = 100
SCALE_OFFSET = 100
CLK_NS = 10
MAX_CYCLES = 200

def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def safe_int(v, default=0):
    try: return int(v)
    except ValueError: return default

def clamp_to_width(v, bits):
    # Signed clamping for simulation
    min_val = -(1 << (bits - 1))
    max_val = (1 << (bits - 1)) - 1
    if v < min_val: return min_val
    if v > max_val: return max_val
    return v

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

async def wait_for_done(dut, max_cycles=100):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done) and int(dut.done) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

def write_vertex(dut, prefix, idx, x, y):
    # Helper to write a single vertex
    # Assuming structured access or individual signals. 
    # If the prompt specifies sq_a_x[0]... sq_a_y[0] syntax:
    try:
        getattr(dut, f'{prefix}_x_{idx}').value = clamp_to_width(x + SCALE_OFFSET, DATA_WIDTH)
        getattr(dut, f'{prefix}_y_{idx}').value = clamp_to_width(y + SCALE_OFFSET, DATA_WIDTH)
    except AttributeError:
        # Fallback for array access if VPI supports it, but individual is safer per rules
        pass

@cocotb.test(timeout_time=2000, timeout_unit="ms")
async def test_square_intersection(dut):
    # Setup clock
    if has_signal(dut, 'clk'):
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    else:
        # Combinational logic fallback (not expected based on prompt)
        await Timer(100, units='ns')

    # Test Cases: (sq_a_vertices, sq_b_vertices, expected_result)
    # Format: list of (x,y) tuples
    test_cases = [
        (
            [(0,0), (6,0), (6,6), (0,6)],  # Axis Aligned
            [(1,3), (3,5), (5,3), (3,1)],   # Rotated (diamond)
            1  # YES
        ),
        (
            [(0,0), (6,0), (6,6), (0,6)],
            [(7,3), (9,5), (11,3), (9,1)],
            0  # NO
        ),
        (
            [(6,0), (6,6), (0,6), (0,0)],
            [(7,4), (4,7), (7,10), (10,7)],
            1  # YES (Corner intersection)
        ),
        (
            [(0,0), (4,0), (4,4), (0,4)],
            [(6,0), (10,0), (10,4), (6,4)],
            0  # NO (Disjoint axis aligned)
        ),
        (
            [(-5,-5), (5,-5), (5,5), (-5,5)],
            [(-5,7), (0,2), (5,7), (0,12)],
            1  # YES (Overlapping)
        )
    ]

    for i, (sq_a, sq_b, expected) in enumerate(test_cases):
        cocotb.log.info(f"Running Test Case {i+1}: Expected {'YES' if expected else 'NO'}")
        
        # Write inputs based on prompt interface hint (sq_a_x[0:3], sq_a_y[0:3])
        # We attempt to write to flattened names or array indices
        for idx in range(4):
            try:
                # Accessing as individual signals (safer for most simulators)
                getattr(dut, f'sq_a_x_{idx}').value = clamp_to_width(sq_a[idx][0] + SCALE_OFFSET, DATA_WIDTH)
                getattr(dut, f'sq_a_y_{idx}').value = clamp_to_width(sq_a[idx][1] + SCALE_OFFSET, DATA_WIDTH)
                getattr(dut, f'sq_b_x_{idx}').value = clamp_to_width(sq_b[idx][0] + SCALE_OFFSET, DATA_WIDTH)
                getattr(dut, f'sq_b_y_{idx}').value = clamp_to_width(sq_b[idx][1] + SCALE_OFFSET, DATA_WIDTH)
            except AttributeError:
                # Fallback for array syntax if VPI allows
                if has_signal(dut, 'sq_a_x'):
                    dut.sq_a_x[idx].value = clamp_to_width(sq_a[idx][0] + SCALE_OFFSET, DATA_WIDTH)
                    dut.sq_a_y[idx].value = clamp_to_width(sq_a[idx][1] + SCALE_OFFSET, DATA_WIDTH)
                    dut.sq_b_x[idx].value = clamp_to_width(sq_b[idx][0] + SCALE_OFFSET, DATA_WIDTH)
                    dut.sq_b_y[idx].value = clamp_to_width(sq_b[idx][1] + SCALE_OFFSET, DATA_WIDTH)

        # Trigger
        if has_signal(dut, 'start'):
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            await wait_for_done(dut)
        else:
            # Combinational mode
            await Timer(100, units='ns')

        # Read result
        if not is_value_defined(dut.result):
            raise TestFailure(f"Case {i+1}: Result signal undefined")
        
        result_val = int(dut.result)
        if result_val != expected:
            raise TestFailure(f"Case {i+1}: Expected {expected}, got {result_val}")
