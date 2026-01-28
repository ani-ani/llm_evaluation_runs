import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

DATA_WIDTH = 8
MAX_CYCLES = 1000
CLK_NS = 10

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

async def wait_for_done(dut, max_cycles=1000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value)==1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

# Write bottle volumes (assuming up to 4 bottles)
def write_volumes(dut, volumes):
    for i, v in enumerate(volumes):
        if i < 4 and has_signal(dut, f'vol_{i}'):
            getattr(dut, f'vol_{i}').value = clamp_to_width(v, DATA_WIDTH)

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_ice_cream_bfs(dut):
    # Check if sequential
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    
    # Test cases (scaled)
    # Case 1: 2 bottles [7,8], T=10 -> possible (fill 8, transfer to 7, discard 7, etc.)
    # Scaled down for test: bottles [4,5], T=3 (impossible with gcd=1? 4-5-3=1 -> possible)
    # Actually, 4 and 5, T=1: 5-4=1 -> fill 5, transfer to 4, discard 4 -> 1 left in 5
    test_cases = [
        (2, [4, 5], 1, 1, "Two bottles 4,5 to get 1"),
        (2, [4, 6], 3, 1, "Two bottles 4,6 to get 3 (gcd=2, 3%2=1 -> impossible)"),
        (3, [2, 3, 5], 1, 1, "Three bottles to get 1"),
        (3, [2, 4, 8], 1, 0, "Two bottles 2,4 to get 1 (impossible)"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (num_bottles, volumes, target, exp_res, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc}")
        try:
            if is_seq:
                await reset_dut(dut)
                write_volumes(dut, volumes)
                # Set target
                if has_signal(dut, 'target_t'):
                    dut.target_t.value = clamp_to_width(target, DATA_WIDTH)
                
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                await wait_for_done(dut)
            else:
                # Combinational logic assumed
                write_volumes(dut, volumes)
                if has_signal(dut, 'target_t'):
                    dut.target_t.value = clamp_to_width(target, DATA_WIDTH)
                await Timer(100, units='ns')
            
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result undefined")
            
            result = int(dut.result.value)
            if result != exp_res:
                raise TestFailure(f"Expected {exp_res}, got {result}")
            passed += 1
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} tests failed")
