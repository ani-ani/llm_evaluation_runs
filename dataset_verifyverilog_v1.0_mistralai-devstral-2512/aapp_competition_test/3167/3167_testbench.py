import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Constants
DATA_WIDTH = 1  # Boolean hit (0 or 1)
ADDR_WIDTH = 10
NUM_ELEMENTS = 1 << ADDR_WIDTH  # 1024
CLK_NS = 10
MAX_CYCLES = 2000

def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def clamp_to_width(v, bits):
    max_val = (1 << bits) - 1
    if v < 0: return 0
    if v > max_val: return max_val
    return v

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def write_counts(dut, counts):
    # Write individual bits if arr_0, arr_1... exist
    if has_signal(dut, 'counts_0'):
        for i in range(NUM_ELEMENTS):
            getattr(dut, f'counts_{i}').value = counts[i]
    # Or write to array index
    elif hasattr(dut, 'counts'):
        for i in range(NUM_ELEMENTS):
            dut.counts[i].value = counts[i]
    else:
        raise TestFailure("No counts signal found")

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_range_sum(dut):
    # Setup Clock
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    await reset_dut(dut)
    
    # Helper to compute prefix sum in Python for verification
    def compute_python_prefix(counts):
        ps = [0] * (NUM_ELEMENTS + 1)
        s = 0
        for i in range(NUM_ELEMENTS):
            s += counts[i]
            ps[i+1] = s
        return ps

    # Generate Test Data
    # Test Case 1: Random distribution
    import random
    random.seed(42)
    counts1 = [random.randint(0, 1) for _ in range(NUM_ELEMENTS)]
    
    # Test Case 2: Sparse hits
    counts2 = [0] * NUM_ELEMENTS
    for _ in range(50):
        idx = random.randint(0, NUM_ELEMENTS - 1)
        counts2[idx] = 1

    test_cases = [
        (counts1, 0, NUM_ELEMENTS - 1, "Full range"),
        (counts1, 10, 100, "Sub range 1"),
        (counts2, 0, NUM_ELEMENTS - 1, "Sparse full"),
        (counts2, 5, 50, "Sparse sub")
    ]

    for i, (counts, L, R, desc) in enumerate(test_cases):
        cocotb.log.info(f"Running Test {i+1}: {desc} (L={L}, R={R})")
        
        # 1. Write inputs
        await write_counts(dut, counts)
        dut.L.value = L
        dut.R.value = R
        
        # 2. Start
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # 3. Wait for done
        await wait_for_done(dut)
        
        # 4. Read result
        if not is_value_defined(dut.result.value):
            raise TestFailure("Result undefined")
            
        result = int(dut.result.value)
        
        # 5. Verify
        expected_ps = compute_python_prefix(counts)
        # Range sum is ps[R] - ps[L-1] if 0-indexed elements.
        # If seq[0]...seq[1023], range [L, R] sum is sum(counts[L...R]).
        # Prefix sum ps[i] = sum(counts[0...i-1]).
        # Sum(L..R) = ps[R+1] - ps[L]
        expected = expected_ps[R+1] - expected_ps[L]
        
        if result != expected:
            raise TestFailure(f"Test {desc} Failed: Expected {expected}, got {result}")
        
        cocotb.log.info(f"Test {desc} Passed: {result}")
