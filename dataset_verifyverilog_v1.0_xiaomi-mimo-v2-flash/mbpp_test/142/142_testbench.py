import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

DATA_WIDTH = 8
ARRAY_SIZE = 8
CLK_NS = 10
MAX_CYCLES = 100

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

def clamp_to_width(v, bits):
    max_val = (1 << bits) - 1
    return min(max_val, max(0, v))

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

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

async def write_array(dut, arr_name, values, width):
    for i, v in enumerate(values):
        if hasattr(dut, f'{arr_name}_{i}'):
            getattr(dut, f'{arr_name}_{i}').value = clamp_to_width(v, width)
        elif hasattr(dut, arr_name) and hasattr(getattr(dut, arr_name), '__getitem__'):
            getattr(dut, arr_name)[i].value = clamp_to_width(v, width)
        else:
            raise AttributeError(f"Array {arr_name} not found")

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_count_samepair(dut):
    # Setup clock
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    await reset_dut(dut, cycles=3)
    
    # Test cases: (list1, list2, list3, expected_result, description)
    test_cases = [
        ([1,2,3,4,5,6,7,8], [2,2,3,1,2,6,7,9], [2,1,3,1,2,6,7,9], 3, "Test 1: matches at positions 2,4,6"),
        ([1,2,3,4,5,6,7,8], [2,2,3,1,2,6,7,8], [2,1,3,1,2,6,7,8], 4, "Test 2: matches at positions 2,4,5,6"),
        ([1,2,3,4,2,6,7,8], [2,2,3,1,2,6,7,8], [2,1,3,1,2,6,7,8], 5, "Test 3: matches at positions 2,4,5,6,7")
    ]
    
    passed = 0
    failed = 0
    
    for i, (list1, list2, list3, expected, description) in enumerate(test_cases):
        cocotb.log.info(f"Running {description}")
        try:
            # Write arrays
            await write_array(dut, 'list1', list1, DATA_WIDTH)
            await write_array(dut, 'list2', list2, DATA_WIDTH)
            await write_array(dut, 'list3', list3, DATA_WIDTH)
            
            # Start computation
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Wait for done
            await wait_for_done(dut, MAX_CYCLES)
            
            # Read result
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result signal undefined")
            
            result = int(dut.result.value)
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            cocotb.log.info(f"PASS: {description} - Got {result}")
            passed += 1
            
            # Wait one cycle before next test
            await RisingEdge(dut.clk)
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL: Test {i+1} - {e}")
            failed += 1
    
    if failed > 0:
        raise TestFailure(f"{failed} out of {passed + failed} tests failed")
    else:
        cocotb.log.info(f"All {passed} tests passed!")