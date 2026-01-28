import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

DATA_WIDTH = 8
MAX_LEN = 8
CLK_NS = 10
MAX_CYCLES = 100

# Helper functions
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

async def write_tuple_array(dut, name, values, width, length):
    """Write array of values to DUT input array pins."""
    if has_signal(dut, name):
        arr = getattr(dut, name)
        for i in range(length):
            if i < len(values):
                arr[i].value = clamp_to_width(values[i], width)
            else:
                arr[i].value = 0

async def read_tuple_array(dut, name, width, length):
    """Read array of values from DUT output array pins."""
    if has_signal(dut, name):
        arr = getattr(dut, name)
        result = []
        for i in range(length):
            v = arr[i].value
            if is_value_defined(v):
                result.append(int(v))
            else:
                result.append(0)
        return result
    return []

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_element_wise_modulo(dut):
    """Test element-wise modulo operation on tuples."""
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    
    # Define test cases: (arr1, arr2, expected_results, description)
    test_cases = [
        ([10, 4, 5, 6], [5, 6, 7, 5], [0, 4, 5, 1], "Test 1"),
        ([11, 5, 6, 7], [6, 7, 8, 6], [5, 5, 6, 1], "Test 2"),
        ([12, 6, 7, 8], [7, 8, 9, 7], [5, 6, 7, 1], "Test 3"),
        ([0, 0, 0, 0], [1, 2, 3, 4], [0, 0, 0, 0], "Zeros"),
        ([15, 15, 15, 15], [1, 1, 1, 1], [0, 0, 0, 0], "Max"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (arr1, arr2, expected, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc}")
        try:
            # Write input arrays
            await write_tuple_array(dut, 'arr1_in', arr1, DATA_WIDTH, MAX_LEN)
            await write_tuple_array(dut, 'arr2_in', arr2, DATA_WIDTH, MAX_LEN)
            
            # Set length
            if has_signal(dut, 'len'):
                dut.len.value = len(arr1)
            
            # Start operation
            if is_seq:
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                await wait_for_done(dut)
            else:
                await Timer(100, units='ns')
            
            # Read results
            result = await read_tuple_array(dut, 'result_out', DATA_WIDTH, len(arr1))
            
            # Verify
            if not result:
                raise TestFailure("Result array is empty or undefined")
            
            for j, (r, e) in enumerate(zip(result, expected)):
                if r != e:
                    raise TestFailure(f"Index {j}: Expected {e}, got {r}")
            
            cocotb.log.info(f"  Result: {result} matches expected: {expected}")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    cocotb.log.info(f"Total: {passed} passed, {failed} failed")
    if failed:
        raise TestFailure(f"{failed} tests failed")
