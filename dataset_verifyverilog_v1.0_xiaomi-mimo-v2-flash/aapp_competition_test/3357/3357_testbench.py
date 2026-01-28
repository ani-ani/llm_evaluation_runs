import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import math

# Scaling factors
MAX_N = 16
DATA_WIDTH = 16
FRAC_BITS = 8
CLK_NS = 10
MAX_CYCLES = 3000

def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def safe_int(v, default=0):
    try: return int(v)
    except ValueError: return default

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def pack_array(vals, bits=8):
    r = 0
    for i, v in enumerate(vals):
        r |= (v & ((1<<bits)-1)) << (i*bits)
    return r

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    if has_signal(dut, 'input_done'): dut.input_done.value = 0
    if has_signal(dut, 'input_valid'): dut.input_valid.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=1000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout waiting for done signal after {max_cycles} cycles")

async def wait_for_result(dut, max_cycles=1000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.result_valid.value) and int(dut.result_valid.value) == 1:
            return int(dut.result_index.value), int(dut.result.value)
    raise TestFailure(f"Timeout waiting for result_valid after {max_cycles} cycles")

def calculate_expected(buildings):
    # buildings: list of tuples (x, h)
    # Returns: list of (index, expected_val)
    results = []
    N = len(buildings)
    for i in range(N):
        xi, hi = buildings[i]
        min_angle = 180.0  # Start with full view (180 degrees)
        
        # Check West (j where x < xi)
        for j in range(N):
            if i == j: continue
            xj, hj = buildings[j]
            if xj < xi:
                dx = xi - xj
                dh = hi - hj
                if dh > 0:
                    angle = math.degrees(math.atan2(dh, dx))
                    if angle < min_angle:
                        min_angle = angle
            elif xj > xi:
                dx = xj - xi
                dh = hi - hj
                if dh > 0:
                    angle = math.degrees(math.atan2(dh, dx))
                    if angle < min_angle:
                        min_angle = angle
        
        visible_angle = 180.0 - min_angle
        if visible_angle < 0: visible_angle = 0
        # Scaling: Output is Q8.8
        # Input angle is floating point. 
        # Expected logic: result = visible_angle * 256 (since 180 fits in 8 bits, 8 frac bits)
        # But 180 * 256 = 46080. Max 16-bit is 65535. Safe.
        expected_fixed = int(visible_angle * (1 << FRAC_BITS))
        results.append((i, expected_fixed))
    return results

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_sunlight(dut):
    # Setup clock
    if has_signal(dut, 'clk'):
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    
    # Test inputs
    # Case 1: Sample Input
    input_buildings_1 = [
        (1, 1),
        (2, 2),
        (3, 2),
        (4, 1)
    ]
    # Case 2: Slanted
    input_buildings_2 = [
        (100, 50),
        (125, 75),
        (150, 100),
        (175, 125),
        (200, 25)
    ]
    
    test_cases = [
        input_buildings_1,
        input_buildings_2
    ]
    
    for tc_idx, buildings in enumerate(test_cases):
        cocotb.log.info(f"Running Test Case {tc_idx + 1}")
        
        # 1. Input Phase
        if has_signal(dut, 'start'):
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
        
        for i, (x, h) in enumerate(buildings):
            if has_signal(dut, 'building_x'):
                dut.building_x.value = clamp_to_width(x, DATA_WIDTH)
                dut.building_h.value = clamp_to_width(h, DATA_WIDTH)
                dut.input_valid.value = 1
                await RisingEdge(dut.clk)
                dut.input_valid.value = 0
        
        if has_signal(dut, 'input_done'):
            dut.input_done.value = 1
            await RisingEdge(dut.clk)
            dut.input_done.value = 0
        
        # 2. Processing Phase
        # Wait for results or done
        collected_results = {}
        if has_signal(dut, 'result_valid'):
            # Collect N results
            for _ in range(len(buildings)):
                idx, val = await wait_for_result(dut, MAX_CYCLES)
                collected_results[idx] = val
        else:
            # If no streaming result, check final 'done' and assume synchronous output?
            # Based on spec, usually output is valid when done or streaming.
            # Wait for done
            await wait_for_done(dut, MAX_CYCLES)
            # Check if all results are now available in outputs (maybe one hot?)
            pass
        
        # 3. Verification
        expected = calculate_expected(buildings)
        
        # Tolerance for fixed-point errors
        tolerance = 5  # ~0.02 fixed point error
        
        for exp_idx, exp_val in expected:
            if exp_idx not in collected_results:
                raise TestFailure(f"Test {tc_idx+1}: Building {exp_idx} result missing")
            
            got = collected_results[exp_idx]
            diff = abs(got - exp_val)
            
            # Convert for logging
            exp_float = exp_val / (1 << FRAC_BITS)
            got_float = got / (1 << FRAC_BITS)
            
            if diff > tolerance:
                 raise TestFailure(f"Test {tc_idx+1}, Building {exp_idx}: Expected {exp_float:.4f}, Got {got_float:.4f} (Raw exp: {exp_val}, got: {got})")
            
            cocotb.log.info(f"Building {exp_idx}: Expected {exp_float:.4f}, Got {got_float:.4f} - PASS")

    cocotb.log.info("All tests passed!")