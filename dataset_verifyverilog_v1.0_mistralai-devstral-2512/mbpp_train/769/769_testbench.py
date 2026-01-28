import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

DATA_WIDTH = 8
ARRAY_SIZE = 16
OUTPUT_SIZE = 32
CLK_NS = 10
MAX_CYCLES = 500

# MANDATORY HELPERS
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

# ARRAY WRITERS
def write_array_fixed(dut, name, values, size, width):
    """Write to array with fixed indexing (arr_0, arr_1...)"""
    for i in range(size):
        if i < len(values):
            attr = getattr(dut, f"{name}_{i}")
            attr.value = clamp_to_width(values[i], width)
        else:
            attr = getattr(dut, f"{name}_{i}")
            attr.value = 0

def write_array_indexed(dut, name, values, size, width):
    """Write to array with bit indexing (arr[i])"""
    arr = getattr(dut, name)
    for i in range(size):
        if i < len(values):
            arr[i].value = clamp_to_width(values[i], width)
        else:
            arr[i].value = 0

# PYTHON DIFF FUNCTION (for reference)
def compute_diff(li1, li2):
    """Python reference implementation"""
    set1 = list(set(li1))
    set2 = list(set(li2))
    result = []
    # Elements in set1 but not set2
    for x in set1:
        if x not in set2:
            result.append(x)
    # Elements in set2 but not set1
    for x in set2:
        if x not in set1:
            result.append(x)
    # Sort result
    result.sort()
    return result

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_diff_module(dut):
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    else:
        # Combinational or single cycle
        await Timer(100, units='ns')
    
    # Test cases
    test_cases = [
        ([10, 15, 20, 25, 30, 35, 40], [25, 40, 35], "Example 1"),
        ([1, 2, 3, 4, 5], [6, 7, 1], "Example 2"),
        ([1, 2, 3], [6, 7, 1], "Example 3"),
        ([], [], "Empty arrays"),
        ([5, 5, 5], [5, 5, 5], "All duplicates"),
        ([0, 1, 2], [3, 4, 5], "No overlap"),
    ]
    
    passed = 0
    failed = 0
    
    for test_idx, (arr1_vals, arr2_vals, desc) in enumerate(test_cases, 1):
        cocotb.log.info(f"\nTest {test_idx}: {desc}")
        cocotb.log.info(f"  Input1: {arr1_vals}")
        cocotb.log.info(f"  Input2: {arr2_vals}")
        
        try:
            # Compute expected result
            expected = compute_diff(arr1_vals, arr2_vals)
            cocotb.log.info(f"  Expected: {expected} (len={len(expected)})")
            
            # Write inputs to DUT
            if is_seq:
                # Check if arrays are packed or individual signals
                if has_signal(dut, 'arr1_0'):
                    # Individual signals (arr1_0, arr1_1...)
                    write_array_fixed(dut, 'arr1', arr1_vals, ARRAY_SIZE, DATA_WIDTH)
                    write_array_fixed(dut, 'arr2', arr2_vals, ARRAY_SIZE, DATA_WIDTH)
                elif has_signal(dut, 'arr1'):
                    # Packed array (arr1[0:15])
                    write_array_indexed(dut, 'arr1', arr1_vals, ARRAY_SIZE, DATA_WIDTH)
                    write_array_indexed(dut, 'arr2', arr2_vals, ARRAY_SIZE, DATA_WIDTH)
                else:
                    raise TestFailure("No array signals found")
                
                # Set lengths
                dut.len1.value = clamp_to_width(len(arr1_vals), 4)
                dut.len2.value = clamp_to_width(len(arr2_vals), 4)
                
                # Start operation
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                
                # Wait for completion
                await wait_for_done(dut)
                
                # Read result
                if not is_value_defined(dut.result_len.value):
                    raise TestFailure("result_len undefined")
                result_len = int(dut.result_len.value)
                
                if result_len > OUTPUT_SIZE:
                    raise TestFailure(f"result_len={result_len} exceeds OUTPUT_SIZE={OUTPUT_SIZE}")
                
                # Read result array
                result_values = []
                for i in range(result_len):
                    if has_signal(dut, f'result_{i}'):
                        val = int(getattr(dut, f'result_{i}').value)
                    elif has_signal(dut, 'result'):
                        val = int(dut.result[i].value)
                    else:
                        raise TestFailure("No result signals found")
                    result_values.append(val)
                
                # Compare
                if result_len != len(expected):
                    raise TestFailure(f"Length mismatch: expected {len(expected)}, got {result_len}")
                
                if result_values != expected:
                    raise TestFailure(f"Values mismatch: expected {expected}, got {result_values}")
                
                cocotb.log.info(f"  Result: {result_values}")
                cocotb.log.info(f"  Status: PASS")
                passed += 1
            
            else:
                # Combinational - give time to settle
                await Timer(1000, units='ns')
                
                # Check result length
                if not is_value_defined(dut.result_len.value):
                    raise TestFailure("result_len undefined")
                result_len = int(dut.result_len.value)
                
                # Read result array
                result_values = []
                for i in range(result_len):
                    if has_signal(dut, f'result_{i}'):
                        val = int(getattr(dut, f'result_{i}').value)
                    elif has_signal(dut, 'result'):
                        val = int(dut.result[i].value)
                    else:
                        raise TestFailure("No result signals found")
                    result_values.append(val)
                
                # Compare
                if result_len != len(expected):
                    raise TestFailure(f"Length mismatch: expected {len(expected)}, got {result_len}")
                
                if result_values != expected:
                    raise TestFailure(f"Values mismatch: expected {expected}, got {result_values}")
                
                cocotb.log.info(f"  Result: {result_values}")
                cocotb.log.info(f"  Status: PASS")
                passed += 1
        
        except TestFailure as e:
            cocotb.log.error(f"Test {test_idx} FAILED: {e}")
            failed += 1
            if is_seq:
                await reset_dut(dut)
    
    # Summary
    cocotb.log.info(f"\n=== SUMMARY ===")
    cocotb.log.info(f"Passed: {passed}/{len(test_cases)}")
    cocotb.log.info(f"Failed: {failed}/{len(test_cases)}")
    
    if failed > 0:
        raise TestFailure(f"{failed} test(s) failed")