import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

DATA_WIDTH = 8
MAX_LEN = 16
CLK_NS = 10
MAX_CYCLES = 1000

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

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=1000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def write_array_to_dut(dut, arr):
    """Write array elements to individual arr_0..arr_15 ports"""
    n = len(arr)
    for i in range(MAX_LEN):
        port_name = f'arr_{i}'
        if hasattr(dut, port_name):
            if i < n:
                getattr(dut, port_name).value = clamp_to_width(arr[i], DATA_WIDTH)
            else:
                getattr(dut, port_name).value = 0
    dut.len.value = clamp_to_width(n, 4)

# Python reference implementation for verification
def move_one_ball_ref(arr):
    """Reference implementation from problem statement"""
    if not arr:
        return True
    n = len(arr)
    if n <= 1:
        return True
    
    # Find minimum element's index
    min_val = arr[0]
    min_idx = 0
    for i in range(1, n):
        if arr[i] < min_val:
            min_val = arr[i]
            min_idx = i
    
    # Check if circularly sorted from minimum
    for i in range(n):
        curr = arr[(min_idx + i) % n]
        next_val = arr[(min_idx + i + 1) % n]
        if curr > next_val:
            return False
    return True

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_move_one_ball(dut):
    """Test move_one_ball with various test cases"""
    
    # Setup clock and reset
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    await reset_dut(dut)
    
    # Test cases
    test_cases = [
        ([3, 4, 5, 1, 2], True, "Example 1: rotation of sorted"),
        ([3, 5, 10, 1, 2], True, "Example 2: sorted rotation with gap"),
        ([4, 3, 1, 2], False, "Example 3: not a rotation"),
        ([3, 5, 4, 1, 2], False, "Example 4: mixed order"),
        ([], True, "Edge case: empty array"),
        ([1], True, "Edge case: single element"),
        ([1, 2, 3, 4, 5], True, "Already sorted"),
        ([5, 1, 2, 3, 4], True, "Complete rotation"),
        ([2, 3, 4, 5, 1], True, "Rotation by 1"),
        ([1, 3, 2, 4], False, "Not sorted or rotation"),
        ([1, 2, 4, 3], False, "Out of order"),
        ([1, 2, 2, 3], True, "Non-strict sorted (allowed)"),
        ([2, 2, 2, 2], True, "All equal"),
        # Random test cases
    ]
    
    # Add some random test cases
    random.seed(42)
    for _ in range(5):
        n = random.randint(0, 8)
        if n == 0:
            arr = []
        else:
            arr = list(range(1, n+1))
            random.shuffle(arr)
            # 50% chance to be sortable by rotation
            if random.random() < 0.5:
                # Make it a rotation of sorted
                if n > 1:
                    split = random.randint(1, n-1)
                    arr = arr[split:] + arr[:split]
        exp = move_one_ball_ref(arr)
        test_cases.append((arr, exp, f"Random {n} elements"))
    
    passed = 0
    failed = 0
    
    for i, (arr, expected, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc} - Input: {arr}")
        
        try:
            # Write array to DUT
            await write_array_to_dut(dut, arr)
            
            # Start computation
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Wait for completion
            await wait_for_done(dut, max_cycles=200)
            
            # Read result
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result signal undefined")
            
            result = int(dut.result.value)
            
            # Verify result matches expected
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            passed += 1
            cocotb.log.info(f"  PASS: result={result}")
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
            
        # Small delay between tests
        await Timer(10, units='ns')
        await RisingEdge(dut.clk)
    
    # Final report
    cocotb.log.info(f"\n=== Test Summary ===")
    cocotb.log.info(f"Passed: {passed}/{len(test_cases)}")
    cocotb.log.info(f"Failed: {failed}/{len(test_cases)}")
    
    if failed > 0:
        raise TestFailure(f"{failed} out of {len(test_cases)} tests failed")