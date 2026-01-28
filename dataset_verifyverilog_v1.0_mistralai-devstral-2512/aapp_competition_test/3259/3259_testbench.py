import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

# Helpers
def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def safe_int(v, default=0):
    try: return int(v)
    except ValueError: return default

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

DATA_WIDTH = 16
ARRAY_SIZE = 1024  # 1024 x 16 bits
CLK_NS = 10
MAX_CYCLES = 5000

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
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

# Helper to calculate expected modulo result
def calc_modulo(k, A, B):
    val = k * A
    if val >= B:
        val = val - B  # Simplified single-subtraction modulo (fits problem constraints for small B usually)
    return val

@cocotb.test(timeout_time=10, timeout_unit="ms")
async def test_aladin_machine(dut):
    # Setup Clock
    if has_signal(dut, 'clk'):
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    else:
        # Combinatorial
        await Timer(100, units='ns')

    dut._log.info("Starting Testbench")
    
    # Test Case 1: Update range, then Query
    # Setup signals
    op_type = dut.op_type if has_signal(dut, 'op_type') else None
    L = dut.L if has_signal(dut, 'L') else None
    R = dut.R if has_signal(dut, 'R') else None
    A = dut.A if has_signal(dut, 'A') else None
    B = dut.B if has_signal(dut, 'B') else None
    start = dut.start if has_signal(dut, 'start') else None
    result = dut.result if has_signal(dut, 'result') else None
    done = dut.done if has_signal(dut, 'done') else None
    
    if not all([op_type, L, R, A, B, start, result, done]):
        raise TestFailure("Missing required signals in DUT")

    # --- Test 1: Update [0, 4] (mapped from 1,5) with A=1, B=2 ---
    # Expected: [1%2, 2%2, 3%2, 4%2, 5%2] = [1, 0, 1, 0, 1]
    dut._log.info("Test 1: Update Range [0,4] A=1 B=2")
    op_type.value = 0 # Update
    L.value = 0       # 1-1
    R.value = 4       # 5-1
    A.value = 1
    B.value = 2
    
    start.value = 1
    await RisingEdge(dut.clk)
    start.value = 0
    
    # Wait for done (should take 5 cycles)
    for i in range(6):
        await RisingEdge(dut.clk)
        if is_value_defined(done.value) and int(done.value) == 1:
            dut._log.info(f"Done received at cycle {i+1}")
            break
    else:
        raise TestFailure("Update operation did not finish in time")

    # --- Test 2: Query [0, 4] ---
    dut._log.info("Test 2: Query Range [0,4]")
    op_type.value = 1 # Query
    L.value = 0
    R.value = 4
    
    start.value = 1
    await RisingEdge(dut.clk)
    start.value = 0
    
    await wait_for_done(dut)
    
    # Check result
    val = int(result.value)
    dut._log.info(f"Result: {val}")
    
    # Expected sum: 1+0+1+0+1 = 3
    if val != 3:
        raise TestFailure(f"Expected sum 3, got {val}")
        
    # --- Test 3: Update [0, 3] (mapped 1,4) with A=3, B=4 ---
    # Expected: 1*3=3%4=3, 2*3=6%4=2, 3*3=9%4=1, 4*3=12%4=0
    # Accumulated on previous values? No, new update overwrites.
    dut._log.info("Test 3: Update Range [0,3] A=3 B=4")
    op_type.value = 0
    L.value = 0
    R.value = 3
    A.value = 3
    B.value = 4
    
    start.value = 1
    await RisingEdge(dut.clk)
    start.value = 0
    
    for i in range(6):
        await RisingEdge(dut.clk)
        if is_value_defined(done.value) and int(done.value) == 1:
            break
    else:
        raise TestFailure("Update operation 2 did not finish")

    # --- Test 4: Query [0, 3] ---
    dut._log.info("Test 4: Query Range [0,3]")
    op_type.value = 1
    L.value = 0
    R.value = 3
    
    start.value = 1
    await RisingEdge(dut.clk)
    start.value = 0
    
    await wait_for_done(dut)
    
    val = int(result.value)
    dut._log.info(f"Result: {val}")
    
    # Expected sum: 3 + 2 + 1 + 0 = 6
    if val != 6:
        raise TestFailure(f"Expected sum 6, got {val}")
        
    # --- Test 5: Query [3, 3] (Single element) ---
    dut._log.info("Test 5: Query Range [3,3]")
    op_type.value = 1
    L.value = 3
    R.value = 3
    
    start.value = 1
    await RisingEdge(dut.clk)
    start.value = 0
    
    await wait_for_done(dut)
    
    val = int(result.value)
    dut._log.info(f"Result: {val}")
    
    # Expected sum: 0
    if val != 0:
        raise TestFailure(f"Expected sum 0, got {val}")

    dut._log.info("All tests passed!")
