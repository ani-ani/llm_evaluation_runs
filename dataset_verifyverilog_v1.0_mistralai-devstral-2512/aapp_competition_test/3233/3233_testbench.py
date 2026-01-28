import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

DATA_WIDTH = 4
ARRAY_SIZE = 16
MAX_VAL = 16
CLK_NS = 10
MAX_CYCLES = 100

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

def count_scary_python(arr):
    """Count scary subarrays in Python for verification"""
    n = len(arr)
    count = 0
    for l in range(n):
        for r in range(l, n):
            length = r - l + 1
            if length % 2 == 0:
                continue  # Even length can't be scary with distinct elements
            # Find median: need to count elements less than arr[l]
            left_val = arr[l]
            less = 0
            greater = 0
            for i in range(l, r + 1):
                if arr[i] < left_val:
                    less += 1
                elif arr[i] > left_val:
                    greater += 1
            if less == greater:
                count += 1
    return count

def generate_test_case():
    """Generate a random permutation of 1..16"""
    arr = list(range(1, 17))
    random.shuffle(arr)
    return arr

async def write_array(dut, vals):
    """Write array values to individual inputs"""
    for i, v in enumerate(vals):
        if hasattr(dut, f'p_{i}'):
            getattr(dut, f'p_{i}').value = clamp_to_width(v, DATA_WIDTH)
        elif hasattr(dut, 'p') and hasattr(dut.p, '__getitem__'):
            dut.p[i].value = clamp_to_width(v, DATA_WIDTH)
        else:
            raise TestFailure(f"Cannot access p[{i}]")

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    """Wait for done signal or timeout"""
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def reset_dut(dut, cycles=2):
    """Reset the DUT"""
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_scary_subarrays(dut):
    """Test scary subarray counter"""
    
    # Setup clock and reset if sequential
    is_seq = has_signal(dut, 'clk') and has_signal(dut, 'rst_n')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    else:
        # Combinational - just set inputs
        dut.rst_n.value = 1
    
    # Test cases
    test_cases = [
        ([1, 2, 3, 4, 5] + [0] * 11, 5, "sorted increasing"),
        ([3, 2, 1, 6, 4, 5] + [0] * 10, 8, "sample 2 truncated"),
    ]
    
    # Add a few random test cases
    random.seed(42)
    for _ in range(3):
        arr = generate_test_case()
        expected = count_scary_python(arr)
        test_cases.append((arr, expected, f"random permutation"))
    
    passed = 0
    failed = 0
    
    for i, (inp, exp, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc}")
        try:
            # Write array inputs
            await write_array(dut, inp)
            
            if is_seq:
                if has_signal(dut, 'start'):
                    dut.start.value = 1
                    await RisingEdge(dut.clk)
                    dut.start.value = 0
                    await wait_for_done(dut)
                else:
                    await RisingEdge(dut.clk)
                    await RisingEdge(dut.clk)
            else:
                await Timer(100, units='ns')
            
            # Read result
            result_signal = None
            if has_signal(dut, 'scary_count'):
                result_signal = dut.scary_count
            elif has_signal(dut, 'result'):
                result_signal = dut.result
            else:
                raise TestFailure("No result output found")
            
            if not is_value_defined(result_signal.value):
                raise TestFailure("Result undefined")
            
            result = int(result_signal.value)
            
            if result != exp:
                raise TestFailure(f"Expected {exp}, got {result}")
            
            passed += 1
            cocotb.log.info(f"  PASS: {desc} - {result}")
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} out of {passed + failed} tests failed")

@cocotb.test(timeout_time=2000, timeout_unit="ms")
async def test_edge_cases(dut):
    """Test edge cases: all same (impossible with distinct), single element"""
    
    is_seq = has_signal(dut, 'clk') and has_signal(dut, 'rst_n')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    else:
        dut.rst_n.value = 1
    
    # Test single element being scary (length 1 always scary)
    # With N=16, test case where only first element is non-zero
    # Actually, all values must be 1-16 per problem statement
    
    # Test with reverse sorted
    arr = list(range(16, 0, -1))  # 16, 15, ..., 1
    expected = count_scary_python(arr)
    
    await write_array(dut, arr)
    
    if is_seq:
        if has_signal(dut, 'start'):
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            await wait_for_done(dut)
        else:
            await RisingEdge(dut.clk)
    else:
        await Timer(100, units='ns')
    
    result_signal = dut.scary_count if has_signal(dut, 'scary_count') else dut.result
    if not is_value_defined(result_signal.value):
        raise TestFailure("Result undefined")
    
    result = int(result_signal.value)
    if result != expected:
        raise TestFailure(f"Reverse sorted: Expected {expected}, got {result}")
    
    cocotb.log.info(f"Edge case test passed: {result} scary subarrays")
