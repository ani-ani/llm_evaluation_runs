import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

DATA_WIDTH = 8
ARRAY_SIZE = 8
RESULT_SIZE = 16
CLK_NS = 10
MAX_CYCLES = 50

def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def write_array(dut, name, vals, length, width):
    # Initialize all elements to 0 first
    for i in range(ARRAY_SIZE):
        getattr(dut, f"{name}_{i}").value = 0
    # Write actual values
    for i, v in enumerate(vals):
        if i < ARRAY_SIZE:
            getattr(dut, f"{name}_{i}").value = clamp_to_width(v, width)
    # Set length
    getattr(dut, f"len_{name}").value = clamp_to_width(length, 4)

async def read_result_array(dut, name, width, result_size):
    values = []
    for i in range(result_size):
        if has_signal(dut, f"{name}_{i}"):
            val = getattr(dut, f"{name}_{i}").value
            if is_value_defined(val):
                values.append(int(val))
    return values

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_find_dissimilar(dut):
    # Check if sequential
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    else:
        # Combinational: assume all inputs stable
        await Timer(10, units='ns')
    
    # Test cases: (arr_a, arr_b, expected_result, expected_len, description)
    test_cases = [
        ([3, 4, 5, 6], [5, 7, 4, 10], [3, 6, 7, 10], 4, "Basic test 1"),
        ([1, 2, 3, 4], [7, 2, 3, 9], [1, 4, 7, 9], 4, "Basic test 2"),
        ([21, 11, 25, 26], [26, 34, 21, 36], [34, 36, 11, 25], 4, "Basic test 3"),
        ([1, 1, 2, 2], [3, 3, 4, 4], [1, 2, 3, 4], 4, "Duplicates in tuples"),
        ([], [1, 2, 3], [1, 2, 3], 3, "Empty first tuple"),
        ([1, 2, 3], [], [1, 2, 3], 3, "Empty second tuple"),
        ([], [], [], 0, "Both empty"),
        ([0, 0, 0, 0], [1, 1, 1, 1], [1], 1, "With padding zeros"),
        ([1, 2, 3, 4, 5, 6, 7, 8], [8, 7, 6, 5, 4, 3, 2, 1], [], 0, "Same elements reversed"),
    ]
    
    passed = failed = 0
    
    for idx, (arr_a, arr_b, expected, exp_len, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {idx+1}: {desc}")
        try:
            # Write inputs
            await write_array(dut, 'arr_a', arr_a, len(arr_a), DATA_WIDTH)
            await write_array(dut, 'arr_b', arr_b, len(arr_b), DATA_WIDTH)
            
            # Pulse start
            if is_seq:
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                await wait_for_done(dut)
            else:
                await Timer(100, units='ns')
            
            # Read result
            if has_signal(dut, 'result_len'):
                result_len = int(dut.result_len.value)
            else:
                # If no result_len, estimate from non-zero values
                result_vals = await read_result_array(dut, 'result', DATA_WIDTH, RESULT_SIZE)
                result_len = len([v for v in result_vals if v != 0])
                # For empty result, ensure result_len is 0
                if not result_vals:
                    result_len = 0
            
            # Read actual result values
            result_vals = await read_result_array(dut, 'result', DATA_WIDTH, RESULT_SIZE)
            
            # Filter out trailing zeros and validate
            actual = []
            for v in result_vals:
                if v != 0:
                    actual.append(v)
            actual = actual[:result_len]
            
            # Check length
            if result_len != exp_len:
                raise TestFailure(f"Length mismatch: expected {exp_len}, got {result_len}")
            
            # Check content (order may vary due to symmetric difference)
            if sorted(actual) != sorted(expected):
                raise TestFailure(f"Content mismatch: expected {expected}, got {actual}")
            
            passed += 1
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1
        except Exception as e:
            cocotb.log.error(f"ERROR: {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} tests failed out of {passed+failed}")
    else:
        cocotb.log.info(f"All {passed} tests passed")