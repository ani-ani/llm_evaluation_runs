import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

# Constants
MAX_M = 200
MAX_N = 100
DATA_WIDTH = 8
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

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    if has_signal(dut, 'config_mode'): dut.config_mode.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=5000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def configure_translators(dut, translators):
    # translators is list of (lang_a, lang_b)
    dut.config_mode.value = 0
    await RisingEdge(dut.clk)
    
    for i, (l1, l2) in enumerate(translators):
        # Send l1
        dut.data_in.value = l1
        dut.data_valid.value = 1
        await RisingEdge(dut.clk)
        # Send l2
        dut.data_in.value = l2
        dut.data_valid.value = 1
        await RisingEdge(dut.clk)
    
    dut.data_valid.value = 0
    dut.config_mode.value = 1
    await RisingEdge(dut.clk)

async def read_matches(dut, M):
    # Expect M/2 pairs
    matches = []
    # Wait for result
    if has_signal(dut, 'status'):
        # Wait for status to be 2 (Match Found) or 3 (Impossible)
        for _ in range(100):
            await RisingEdge(dut.clk)
            if int(dut.status.value) == 2:
                break
            elif int(dut.status.value) == 3:
                return None # Impossible
    
    # Read pairs
    pairs_needed = M // 2
    for _ in range(pairs_needed):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.match_out.value):
            val = int(dut.match_out.value)
            t_a = (val >> 8) & 0xFF
            t_b = val & 0xFF
            matches.append((t_a, t_b))
    return matches

@cocotb.test(timeout_time=10, timeout_unit="ms")
async def test_translator_matcher(dut):
    # Setup
    if has_signal(dut, 'clk'):
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    
    # Test Case 1: Sample Input
    # 5 6
    # 0 1
    # 0 2
    # 1 3
    # 2 3
    # 1 2
    # 4 3
    # Expected: Any valid matching of 6 translators (3 pairs)
    
    translators = [
        (0, 1), (0, 2), (1, 3), (2, 3), (1, 2), (4, 3)
    ]
    M = 6
    
    cocotb.log.info("Configuring translators...")
    await configure_translators(dut, translators)
    
    # Start matching
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    cocotb.log.info("Waiting for matching to complete...")
    await wait_for_done(dut)
    
    # Read results
    cocotb.log.info("Reading matches...")
    matches = await read_matches(dut, M)
    
    if matches is None:
        raise TestFailure("Expected a matching but got Impossible")
    
    cocotb.log.info(f"Found {len(matches)} pairs: {matches}")
    
    # Validate matching
    # 1. All translators used exactly once
    used = set()
    for a, b in matches:
        if a in used or b in used or a == b:
            raise TestFailure(f"Invalid matching: duplicate or self-pair {a}, {b}")
        used.add(a)
        used.add(b)
        
    if len(used) != M:
        raise TestFailure(f"Not all translators matched. Used: {len(used)} vs {M}")
        
    # 2. Check compatibility (same language)
    # We need to verify edges. We can infer edges from translators list.
    for a, b in matches:
        lang_a = translators[a]
        lang_b = translators[b]
        # Check intersection
        common = set(lang_a).intersection(set(lang_b))
        if not common:
            raise TestFailure(f"Incompatible pair: {a} {lang_a} and {b} {lang_b}")
            
    cocotb.log.info("Test passed!")

@cocotb.test(timeout_time=10, timeout_unit="ms")
async def test_impossible_case(dut):
    if has_signal(dut, 'clk'):
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    
    # 3 3
    # 0 1
    # 1 2
    # 2 0
    # Odd cycle, 3 nodes (odd number) -> Impossible for perfect matching
    
    translators = [
        (0, 1), (1, 2), (2, 0)
    ]
    M = 3
    
    await configure_translators(dut, translators)
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    await wait_for_done(dut)
    
    matches = await read_matches(dut, M)
    
    if matches is not None:
        raise TestFailure(f"Expected Impossible but got {matches}")
    
    cocotb.log.info("Correctly detected impossible case")
