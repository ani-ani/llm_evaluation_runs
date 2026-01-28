import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

DATA_WIDTH = 8
SUBARRAY_COUNT = 8
MAX_SUBARRAY_LEN = 8
TOTAL_ELEMENTS = SUBARRAY_COUNT * MAX_SUBARRAY_LEN
CLK_NS = 10

# Helper functions
def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def pack_result(arr, width=8):
    packed = 0
    for i, v in enumerate(arr):
        packed |= (v & ((1 << width) - 1)) << (i * width)
    return packed

async def wait_for_done(dut, max_cycles=1000):
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

# Helper to set input arrays
def set_input_arrays(dut, subarrays):
    # subarrays is list of lists, max 8 subarrays, each max 8 elements
    # Zero out all first
    for i in range(SUBARRAY_COUNT):
        # Check if arr[i] is an array
        if hasattr(dut.arr[i], '__iter__'):
            for j in range(MAX_SUBARRAY_LEN):
                dut.arr[i][j].value = 0
        elif hasattr(dut, f'arr_{i}_{0}'):
            for j in range(MAX_SUBARRAY_LEN):
                getattr(dut, f'arr_{i}_{j}').value = 0
        # Also set length
        if hasattr(dut, f'len_{i}'):
            getattr(dut, f'len_{i}').value = 0
        elif hasattr(dut, 'len') and hasattr(dut.len, '__getitem__'):
            dut.len[i].value = 0
    
    # Set actual values
    total_elems = 0
    for i, sub in enumerate(subarrays):
        if i >= SUBARRAY_COUNT:
            break
        sub_len = len(sub) if isinstance(sub, list) else 0
        if sub_len > 0 and sub_len <= MAX_SUBARRAY_LEN:
            # Set elements
            for j, val in enumerate(sub):
                if j < MAX_SUBARRAY_LEN:
                    if hasattr(dut.arr[i], '__getitem__'):
                        dut.arr[i][j].value = clamp_to_width(val, DATA_WIDTH)
                    elif hasattr(dut, f'arr_{i}_{j}'):
                        getattr(dut, f'arr_{i}_{j}').value = clamp_to_width(val, DATA_WIDTH)
            # Set length
            if hasattr(dut, f'len_{i}'):
                getattr(dut, f'len_{i}').value = clamp_to_width(sub_len, 4)
            elif hasattr(dut, 'len') and hasattr(dut.len, '__getitem__'):
                dut.len[i].value = clamp_to_width(sub_len, 4)
            total_elems += sub_len
    return total_elems

@cocotb.test(timeout_time=2000, timeout_unit="ms")
async def test_flatten_list(dut):
    cocotb.log.info("Testing 2D list flattening module")
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test cases: Each is (subarrays, expected_flattened, description)
    test_cases = [
        (
            [[0], [10], [20, 30], [], [40], [50], [60, 70, 80], [90, 100, 110, 120]],
            [0, 10, 20, 30, 0, 0, 0, 0, 40, 0, 0, 0, 0, 0, 0, 0, 50, 0, 0, 0, 0, 0, 0, 0, 60, 70, 80, 0, 0, 0, 0, 0, 90, 100, 110, 120, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
            "Test 1: Mixed nested arrays with zeros"
        ),
        (
            [[10, 20], [40], [30, 56, 25], [10, 20], [33], [40], [], []],
            [10, 20, 0, 0, 0, 0, 0, 0, 40, 0, 0, 0, 0, 0, 0, 0, 30, 56, 25, 0, 0, 0, 0, 0, 10, 20, 0, 0, 0, 0, 0, 0, 33, 0, 0, 0, 0, 0, 0, 0, 40, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
            "Test 2: Another nested structure"
        ),
        (
            [[1, 2, 3], [4, 5, 6], [10, 11, 12], [7, 8, 9], [], [], [], []],
            [1, 2, 3, 0, 0, 0, 0, 0, 4, 5, 6, 0, 0, 0, 0, 0, 10, 11, 12, 0, 0, 0, 0, 0, 7, 8, 9, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
            "Test 3: Equal length subarrays"
        )
    ]
    
    passed = 0
    failed = 0
    
    for idx, (subarrays, expected, desc) in enumerate(test_cases):
        cocotb.log.info(f"Running Test {idx+1}: {desc}")
        
        # Calculate expected total elements
        exp_total = sum(len(sub) for sub in subarrays)
        exp_packed = pack_result(expected)
        
        try:
            # Set input
            set_input_arrays(dut, subarrays)
            
            # Start pulse
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Wait for done
            await wait_for_done(dut)
            
            # Check result
            result_arr = []
            result_packed = 0
            
            # Extract packed result
            if hasattr(dut, 'result'):
                if hasattr(dut.result, '__iter__'):
                    # Unpacked array
                    for i in range(TOTAL_ELEMENTS):
                        if is_value_defined(dut.result[i].value):
                            val = int(dut.result[i].value)
                            result_arr.append(val)
                            result_packed |= (val & 0xFF) << (i * 8)
                        else:
                            result_arr.append(0)
                else:
                    # Packed array
                    if is_value_defined(dut.result.value):
                        result_packed = int(dut.result.value)
                        # Unpack for comparison
                        for i in range(TOTAL_ELEMENTS):
                            result_arr.append((result_packed >> (i * 8)) & 0xFF)
                    else:
                        raise TestFailure("Result signal has undefined value")
            
            # Check count if exists
            if has_signal(dut, 'count') and is_value_defined(dut.count.value):
                actual_count = int(dut.count.value)
                if actual_count != exp_total:
                    raise TestFailure(f"Count mismatch: expected {exp_total}, got {actual_count}")
            
            # Check result values (only up to expected total)
            for i in range(exp_total):
                if i >= len(result_arr):
                    raise TestFailure(f"Result array too short, expected at least {exp_total} elements")
                if result_arr[i] != expected[i]:
                    raise TestFailure(f"Mismatch at index {i}: expected {expected[i]}, got {result_arr[i]}")
            
            # Check zero padding after expected total
            for i in range(exp_total, min(exp_total + 10, TOTAL_ELEMENTS)):
                if i < len(result_arr) and result_arr[i] != 0:
                    raise TestFailure(f"Non-zero at padding index {i}: {result_arr[i]}")
            
            cocotb.log.info(f"Test {idx+1} PASSED")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"Test {idx+1} FAILED: {e}")
            failed += 1
        
        # Reset for next test
        await reset_dut(dut)
    
    if failed:
        raise TestFailure(f"{failed} test(s) failed out of {len(test_cases)}")
    
    cocotb.log.info(f"All {passed} tests passed!")