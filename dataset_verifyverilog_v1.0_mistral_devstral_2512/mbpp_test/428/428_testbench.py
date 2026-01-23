import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

DATA_WIDTH = 8
ARRAY_SIZE = 8
CLK_PERIOD_NS = 10
MAX_CYCLES = 1000

def is_value_defined(value):
    try:
        int(value)
        return True
    except ValueError:
        return False

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def clamp_to_width(value, bits):
    max_val = (1 << bits) - 1
    return min(max_val, max(0, value))

async def write_array(dut, values):
    for i in range(ARRAY_SIZE):
        if i < len(values):
            val = clamp_to_width(values[i], DATA_WIDTH)
        else:
            val = 0
        port_name = f"arr_{i}"
        if has_signal(dut, port_name):
            getattr(dut, port_name).value = val

async def read_sorted_array(dut):
    results = []
    for i in range(ARRAY_SIZE):
        port_name = f"sorted_{i}"
        if has_signal(dut, port_name):
            val = getattr(dut, port_name).value
            if is_value_defined(val):
                results.append(int(val))
            else:
                results.append(None)
        else:
            results.append(None)
    return results

async def reset_dut(dut):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(2):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    for cycle in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout: done not asserted after {max_cycles} cycles")

async def start_computation(dut):
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_shell_sort(dut):
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    await reset_dut(dut)
    
    test_cases = [
        ([12, 23, 4, 5, 3, 2, 12, 81], [2, 3, 4, 5, 12, 12, 23, 81], "Test 1"),
        ([24, 22, 39, 34, 87, 73, 68], [22, 24, 34, 39, 68, 73, 87], "Test 2"),
        ([32, 30, 16, 96, 82, 83, 74], [16, 30, 32, 74, 82, 83, 96], "Test 3"),
        ([5, 4, 3, 2, 1], [1, 2, 3, 4, 5], "Reverse"),
        ([1, 2, 3, 4, 5], [1, 2, 3, 4, 5], "Sorted"),
        ([0, 0, 0, 0, 0], [0, 0, 0, 0, 0], "Zeros")
    ]
    
    passed = 0
    failed = 0
    
    for i, (input_list, expected_list, description) in enumerate(test_cases):
        cocotb.log.info(f"\nTest {i+1}: {description}")
        cocotb.log.info(f"  Input: {input_list}")
        
        try:
            await write_array(dut, input_list)
            await start_computation(dut)
            await wait_for_done(dut)
            
            result = await read_sorted_array(dut)
            result_filtered = [r for r in result if r is not None]
            actual = result_filtered[:len(expected_list)]
            
            if actual != expected_list:
                raise TestFailure(f"Expected {expected_list}, got {actual}")
            
            cocotb.log.info(f"  Result: {actual} - PASS")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    cocotb.log.info(f"\n{'='*60}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")