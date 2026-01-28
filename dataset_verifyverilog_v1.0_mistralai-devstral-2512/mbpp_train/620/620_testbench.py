import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

# Constants
DATA_WIDTH = 16
ARRAY_SIZE = 16
RESULT_WIDTH = 5
CLK_NS = 10
MAX_CYCLES = 2000

# Helper functions
def is_value_defined(v):
    try:
        int(v)
        return True
    except ValueError:
        return False

def safe_int(v, default=0):
    try:
        return int(v)
    except ValueError:
        return default

def clamp_to_width(v, bits):
    max_val = (1 << bits) - 1
    return min(max_val, max(0, v))

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

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

def largest_subset_python(a):
    n = len(a)
    if n == 0:
        return 0
    dp = [0] * n
    dp[n - 1] = 1
    for i in range(n - 2, -1, -1):
        mxm = 0
        for j in range(i + 1, n):
            if a[j] % a[i] == 0 or a[i] % a[j] == 0:
                mxm = max(mxm, dp[j])
        dp[i] = 1 + mxm
    return max(dp)

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_largest_subset(dut):
    # Setup clock if sequential
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    else:
        await Timer(100, units='ns')

    # Test cases
    test_vectors = [
        ([1, 3, 6, 13, 17, 18], 4, "Test 1"),
        ([10, 5, 3, 15, 20], 3, "Test 2"),
        ([18, 1, 3, 6, 13, 17], 4, "Test 3"),
        ([1, 1, 1, 1], 4, "All ones"),
        ([2, 4, 8, 16], 4, "Powers of two"),
        ([1], 1, "Single element"),
        ([], 0, "Empty array"),
        ([100, 50, 25, 12, 6, 3], 6, "Divisible chain"),
    ]

    passed = 0
    failed = 0

    for idx, (arr, expected, desc) in enumerate(test_vectors):
        # Clamp array elements to 16-bit
        clamped_arr = [clamp_to_width(x, DATA_WIDTH) for x in arr]
        
        if is_seq:
            # Write array to DUT
            # Handle different array access methods
            if hasattr(dut, 'arr') and hasattr(dut.arr, '__len__'):
                # Packed array or memory
                if len(dut.arr) >= len(clamped_arr):
                    for i, val in enumerate(clamped_arr):
                        dut.arr[i].value = val
            else:
                # Individual ports arr_0, arr_1...
                for i in range(ARRAY_SIZE):
                    attr_name = f'arr_{i}'
                    if hasattr(dut, attr_name):
                        if i < len(clamped_arr):
                            getattr(dut, attr_name).value = clamped_arr[i]
                        else:
                            getattr(dut, attr_name).value = 0
            
            # Set length
            if hasattr(dut, 'length'):
                dut.length.value = len(arr)
            
            # Start
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Wait for done
            try:
                await wait_for_done(dut, max_cycles=MAX_CYCLES)
            except TestFailure as e:
                cocotb.log.error(f"{desc} - {e}")
                failed += 1
                continue
            
            # Read result
            if not is_value_defined(dut.result.value):
                cocotb.log.error(f"{desc} - Result undefined")
                failed += 1
                continue
            
            result = int(dut.result.value)
            
        else:
            # Combinational logic
            # Assign inputs directly
            if hasattr(dut, 'arr'):
                for i in range(min(len(clamped_arr), len(dut.arr))):
                    dut.arr[i].value = clamped_arr[i]
            
            if hasattr(dut, 'length'):
                dut.length.value = len(arr)
            
            await Timer(100, units='ns')
            
            if not is_value_defined(dut.result.value):
                cocotb.log.error(f"{desc} - Result undefined")
                failed += 1
                continue
            
            result = int(dut.result.value)

        # Compare
        if result != expected:
            cocotb.log.error(f"Test {idx+1} ({desc}) FAILED: Expected {expected}, got {result}")
            failed += 1
        else:
            cocotb.log.info(f"Test {idx+1} ({desc}) PASSED: {result}")
            passed += 1

    if failed > 0:
        raise TestFailure(f"{failed} tests failed out of {passed + failed}")
