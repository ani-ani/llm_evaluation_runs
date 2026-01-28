import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

DATA_WIDTH = 8
ARRAY_SIZE = 8
CLK_NS = 10
MAX_CYCLES = 300

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

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def clamp_to_width(v, bits):
    max_val = (1 << bits) - 1
    return min(max_val, max(0, v))

def count_frequencies(arr, max_len):
    """Python helper to compute expected frequencies"""
    from collections import Counter
    truncated = arr[:max_len]
    cnt = Counter(truncated)
    # Sort by key
    sorted_items = sorted(cnt.items())
    return sorted_items

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def write_array(dut, name, vals, width):
    """Write to individual array elements"""
    for i in range(ARRAY_SIZE):
        val = vals[i] if i < len(vals) else 0
        arr_elem = getattr(dut, name)[i]
        arr_elem.value = clamp_to_width(val, width)

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_freq_counter(dut):
    # Setup
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    await reset_dut(dut)
    
    # Test cases: input array and expected (key, count) pairs
    test_cases = [
        ([10, 10, 10, 10, 20, 20, 20, 20], [(10, 4), (20, 4)]),
        ([1, 2, 3, 4, 3, 2, 4, 1], [(1, 2), (2, 2), (3, 2), (4, 2)]),
        ([5, 6, 7, 4, 9, 10, 4, 5], [(4, 2), (5, 2), (6, 1), (7, 1), (9, 1), (10, 1)]),
        ([0, 0, 0], [(0, 3)]),
        ([255, 255, 255], [(255, 3)]),
        ([], []),
    ]
    
    passed = 0
    failed = 0
    
    for idx, (inp, expected) in enumerate(test_cases):
        desc = f"Case {idx+1}: {inp[:4]}..." if len(inp) > 4 else f"Case {idx+1}: {inp}"
        cocotb.log.info(f"Testing {desc}")
        
        try:
            # Prepare input length and array
            dut_len = len(inp)
            dut.len.value = clamp_to_width(dut_len, 4)
            
            # Write input array (fill with 0 for unused slots)
            write_vals = inp + [0] * (ARRAY_SIZE - len(inp))
            await write_array(dut, 'arr', write_vals, DATA_WIDTH)
            
            # Start
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Wait for done
            await wait_for_done(dut)
            
            # Read results
            if not (is_value_defined(dut.done.value) and int(dut.done.value) == 1):
                raise TestFailure(f"done signal not asserted")
            
            # Read valid_pairs
            valid_pairs = int(dut.valid_pairs.value)
            
            # Read result arrays
            result_keys = []
            result_counts = []
            for i in range(ARRAY_SIZE):
                key_val = int(dut.result_keys[i].value)
                count_val = int(dut.result_counts[i].value)
                # Only consider first valid_pairs entries
                if i < valid_pairs:
                    result_keys.append(key_val)
                    result_counts.append(count_val)
            
            # Build result dictionary
            result_dict = dict(zip(result_keys, result_counts))
            expected_dict = dict(expected)
            
            # Compare
            if result_dict != expected_dict:
                raise TestFailure(f"Expected {expected_dict}, got {result_dict}")
            
            passed += 1
            cocotb.log.info(f"PASS: {desc}")
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {desc} - {e}")
            failed += 1
        
        # Small delay between tests
        await Timer(10, units='ns')
        await reset_dut(dut, cycles=2)
    
    if failed:
        raise TestFailure(f"{failed} out of {passed+failed} tests failed")
    else:
        cocotb.log.info(f"All {passed} tests passed")
