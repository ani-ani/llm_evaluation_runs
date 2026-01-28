import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

# Constants
MAX_N = 16
DATA_WIDTH = 2  # 2-bit for belt direction (0,1,2)
CLK_NS = 10
MAX_CYCLES = 1000

# Helpers
def is_value_defined(v):
    try:
        int(v)
        return True
    except (ValueError, TypeError):
        return False

def safe_int(v, default=0):
    try:
        return int(v)
    except (ValueError, TypeError):
        return default

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

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

# Main Test
@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_snake_exhibition(dut):
    # Setup clock if sequential
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    else:
        # Combinational logic assumed to settle within 100ns
        dut.rst_n.value = 1

    # Define test cases (input string, expected result)
    # Mapping: '>':0, '<':1, '-':2
    test_cases = [
        ("-><-", 3),   # 4 rooms, mixed
        (">>>>>", 5),  # 5 rooms, all >
        ("<--", 3),    # 3 rooms, mixed
        ("<>", 0),     # 2 rooms, mixed
        ("----", 4),   # 4 rooms, all - (mixed is true, check belts)
        ("-><-<", 4),  # 5 rooms
    ]

    passed = 0
    failed = 0

    for s, expected in test_cases:
        n = len(s)
        cocotb.log.info(f"Testing n={n}, s='{s}', expected={expected}")
        
        # Drive inputs
        dut.n.value = n
        
        # Map string to belt signals
        # Assuming belt_0, belt_1... exist or belt[0] syntax
        # We will check belt_0 style first, fallback to belt[0]
        is_array = has_signal(dut, 'belt_0')
        
        belt_map = {'>': 0, '<': 1, '-': 2}
        for i in range(MAX_N):
            val = 0  # Default
            if i < n:
                val = belt_map.get(s[i], 0)
            
            if is_array:
                getattr(dut, f'belt_{i}').value = val
            elif has_signal(dut, 'belt'):
                # Assume array access dut.belt[i].value
                # Check if dut.belt is iterable or an array
                try:
                    dut.belt[i].value = val
                except Exception:
                    # Fallback: if packed, handle differently, but prompt implies individual signals
                    pass
        
        if is_seq:
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            await wait_for_done(dut)
        else:
            await Timer(100, units='ns')

        # Read result
        if has_signal(dut, 'result'):
            result = int(dut.result.value)
            if result == expected:
                cocotb.log.info(f"PASS: Got {result}")
                passed += 1
            else:
                cocotb.log.error(f"FAIL: Expected {expected}, got {result}")
                failed += 1
        else:
            cocotb.log.error("Result signal not found")
            failed += 1

    if failed > 0:
        raise TestFailure(f"{failed} tests failed, {passed} passed")
