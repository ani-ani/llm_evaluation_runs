import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

# Constants
DATA_WIDTH = 16
MAX_ITEMS = 1024
MAX_K = 256
CLK_NS = 10
MAX_CYCLES = 2000

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

async def reset_dut(dut):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(2):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def write_array(dut, name, vals, width):
    # Assuming structure is dut.name[i]
    for i, v in enumerate(vals):
        if hasattr(dut, name):
            getattr(dut, name)[i].value = clamp_to_width(v, width)
        else:
            # Fallback for flattened ports if array access fails
            port = getattr(dut, f"{name}_{i}", None)
            if port:
                port.value = clamp_to_width(v, width)

def compute_expected(p, k):
    ops = 0
    shift = 0
    prev_page = -1
    for idx in p:
        curr_page = (idx - shift) // k
        if curr_page != prev_page:
            ops += 1
            prev_page = curr_page
        shift += 1
    return ops

@cocotb.test(timeout_time=2000, timeout_unit="ms")
async def test_discard_operations(dut):
    # Setup Clock
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    else:
        # Combinational (unlikely for this complexity, but handled)
        await Timer(100, units='ns')

    # Test cases (scaled down from Python examples)
    test_cases = [
        (4, 5, [3, 5, 7, 10]),
        (4, 5, [7, 8, 9, 10]),
        (1, 1, [1]),
        (7, 3, [2, 3, 4, 5, 6, 7, 11]),
        (15, 15, [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15]),
    ]

    passed = 0
    failed = 0

    for m, k, p_list in test_cases:
        # Scale inputs if necessary (though these are small)
        k_val = clamp_to_width(k, 8)
        
        # Pad p_list to MAX_ITEMS if needed (HDL might expect full array)
        # In this spec, we pass m_valid, so p values outside m are ignored (set to 0)
        p_padded = [clamp_to_width(x, 16) for x in p_list] + [0] * (MAX_ITEMS - len(p_list))
        
        expected_ops = compute_expected(p_list, k)
        
        cocotb.log.info(f"Test: m={m}, k={k}, ops_expected={expected_ops}")
        
        try:
            # Write inputs
            if is_seq:
                dut.m_valid.value = m
                dut.k_in.value = k_val
                await write_array(dut, 'p', p_padded, 16)
                
                # Start
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                
                # Wait for done
                await wait_for_done(dut)
                
                # Read result
                result = int(dut.result.value)
                
                if result != expected_ops:
                    raise TestFailure(f"Expected {expected_ops}, got {result}")
                passed += 1
            else:
                # Combinational logic (just update inputs and read)
                dut.m_valid.value = m
                dut.k_in.value = k_val
                await write_array(dut, 'p', p_padded, 16)
                await Timer(10, units='ns')
                result = int(dut.result.value)
                if result != expected_ops:
                    raise TestFailure(f"Expected {expected_ops}, got {result}")
                passed += 1

        except TestFailure as e:
            cocotb.log.error(f"FAIL: m={m}, k={k}: {e}")
            failed += 1

    if failed:
        raise TestFailure(f"{failed} tests failed out of {passed + failed}")
