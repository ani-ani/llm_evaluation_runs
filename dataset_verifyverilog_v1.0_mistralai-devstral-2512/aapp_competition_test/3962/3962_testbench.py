import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

# Constants
N = 16
DATA_WIDTH = 32
CLK_NS = 10
MAX_CYCLES = 5000

def is_value_defined(v):
    try:
        int(v)
        return True
    except ValueError:
        return False

def safe_int(v, default=0):
    try:
        return int(v)
    except ValueError:
        return default

def clamp_to_width(v, bits):
    # Handle negative values if any, but inputs are positive in problem
    # Just mask to bits
    return v & ((1 << bits) - 1)

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    if has_signal(dut, 'load_en'):
        dut.load_en.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def send_inputs(dut, l_list, r_list):
    # Wait for ready
    if has_signal(dut, 'ready'):
        for _ in range(100):
            await RisingEdge(dut.clk)
            if int(dut.ready.value) == 1:
                break
        else:
            raise TestFailure("Module never became ready")
    
    # Send N pairs
    dut.load_en.value = 1
    for i in range(N):
        dut.l_in.value = clamp_to_width(l_list[i], DATA_WIDTH)
        dut.r_in.value = clamp_to_width(r_list[i], DATA_WIDTH)
        await RisingEdge(dut.clk)
    dut.load_en.value = 0
    
    # Start processing
    if has_signal(dut, 'start'):
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_dinner_chairs(dut):
    # Setup clock
    if has_signal(dut, 'clk'):
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    else:
        # Combinational design - just wait a bit
        await Timer(100, units='ns')

    # Test cases: scaled down for N=16
    # We will test with random data and verify against Python logic
    passed = 0
    failed = 0
    
    # Generate random test data
    l_vals = [random.randint(0, 1000) for _ in range(N)]
    r_vals = [random.randint(0, 1000) for _ in range(N)]
    
    # Calculate expected result using Python algorithm (scaled for N=16)
    # The problem logic: sum(max(l_i, r_i)) + n
    sorted_l = sorted(l_vals)
    sorted_r = sorted(r_vals)
    expected = N  # Add n
    for i in range(N):
        expected += max(sorted_l[i], sorted_r[i])
    
    cocotb.log.info(f"Running test with N={N}, expected result={expected}")
    
    try:
        await send_inputs(dut, l_vals, r_vals)
        
        if has_signal(dut, 'done'):
            await wait_for_done(dut)
        else:
            # If no done signal, assume combinational or just wait
            await Timer(5000, units='ns')
        
        # Read result
        if has_signal(dut, 'result'):
            result_val = int(dut.result.value)
            # Handle potential overflow or width issues by masking
            # In this problem, the result should fit in DATA_WIDTH for our scaled inputs
            # But let's check against expected value
            
            if result_val != expected:
                raise TestFailure(f"Result mismatch: Expected {expected}, got {result_val}")
            else:
                cocotb.log.info("Result matches expected value.")
                passed += 1
        else:
            raise TestFailure("Result signal not found")
            
    except TestFailure as e:
        cocotb.log.error(f"Test failed: {e}")
        failed += 1

    if failed > 0:
        raise TestFailure(f"{failed} test(s) failed")
