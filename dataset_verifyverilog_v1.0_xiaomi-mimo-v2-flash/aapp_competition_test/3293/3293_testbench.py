import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

DATA_WIDTH = 16
IDX_WIDTH = 4
MAX_N = 16
CLK_NS = 10
MAX_CYCLES = 10000

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
    if has_signal(dut, 'start'):
        dut.start.value = 0
    if has_signal(dut, 'cfg_en'):
        dut.cfg_en.value = 0
    if has_signal(dut, 'clk'):
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    if has_signal(dut, 'clk'):
        await RisingEdge(dut.clk)

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_vending_machine(dut):
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    else:
        await Timer(100, units='ns')

    test_cases = [
        {
            "nodes": [
                {"f": 0, "p": 2, "m": 3, "s": 1},
            ],
            "expected": 1
        },
        {
            "nodes": [
                {"f": 1, "p": 1, "m": 5, "s": 3},
                {"f": 0, "p": 1, "m": 4, "s": 3},
            ],
            "expected": 21
        },
        {
            "nodes": [
                {"f": 1, "p": 10, "m": 5, "s": 1},
                {"f": 0, "p": 10, "m": 5, "s": 1},
            ],
            "expected": 0
        },
        {
            "nodes": [
                {"f": 1, "p": 2, "m": 3, "s": 1},
                {"f": 2, "p": 2, "m": 3, "s": 1},
                {"f": 2, "p": 2, "m": 3, "s": 1},
            ],
            "expected": 3
        }
    ]

    for tc_idx, tc in enumerate(test_cases):
        cocotb.log.info(f"Running Test Case {tc_idx + 1}")
        
        N = len(tc["nodes"])
        if N > MAX_N:
            cocotb.log.warning(f"Skipping case with N={N} (Max {MAX_N})")
            continue
            
        for i, node in enumerate(tc["nodes"]):
            if has_signal(dut, 'cfg_en'):
                dut.cfg_en.value = 1
                dut.cfg_idx.value = i
                dut.cfg_f.value = node["f"]
                dut.cfg_p.value = node["p"]
                dut.cfg_m.value = node["m"]
                dut.cfg_s.value = node["s"]
                await RisingEdge(dut.clk)
        
        if has_signal(dut, 'cfg_en'):
            dut.cfg_en.value = 0
            await RisingEdge(dut.clk)

        # Start calculation
        if has_signal(dut, 'start'):
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
        
        # Wait for done
        done = False
        for _ in range(MAX_CYCLES):
            await RisingEdge(dut.clk)
            if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                done = True
                break
        
        if not done:
            raise TestFailure(f"Test {tc_idx+1}: Timeout waiting for done signal")
        
        # Check result
        if not is_value_defined(dut.result.value):
            raise TestFailure(f"Test {tc_idx+1}: Result is undefined")
            
        result = int(dut.result.value)
        expected = tc["expected"]
        
        if result != expected:
            raise TestFailure(f"Test {tc_idx+1}: Expected {expected}, got {result}")
        
        cocotb.log.info(f"Test {tc_idx+1} Passed: Result {result}")
        
        # Reset for next test
        if is_seq:
            await reset_dut(dut)