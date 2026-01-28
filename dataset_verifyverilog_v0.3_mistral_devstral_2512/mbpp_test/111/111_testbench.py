import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

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
    return min((1 << bits) - 1, max(0, value))

async def reset_dut(dut):
    dut.rst_n.value = 0
    dut.start.value = 0
    for _ in range(2):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut):
    for _ in range(100):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return
    raise TestFailure("Timeout waiting for done")

async def start_computation(dut):
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

def set_array(dut, prefix, values):
    for i in range(8):
        port_name = f"{prefix}_{i}"
        if has_signal(dut, port_name):
            val = values[i] if i < len(values) else 0
            getattr(dut, port_name).value = clamp_to_width(val, 8)

def get_result(dut):
    if not is_value_defined(dut.result.value) or not is_value_defined(dut.result_count.value):
        return []
    packed = int(dut.result.value)
    count = int(dut.result_count.value)
    return [(packed >> (i * 8)) & 0xFF for i in range(count)]

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_common_in_nested_lists(dut):
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    await reset_dut(dut)
    
    test_cases = [
        ([12, 18, 23, 25, 45], [7, 12, 18, 24, 28], [1, 5, 8, 12, 15, 16, 18], [12, 18]),
        ([12, 5, 23, 25, 45], [7, 11, 5, 23, 28], [1, 5, 8, 18, 23, 16], [5, 23]),
        ([2, 3, 4, 1], [4, 5], [6, 4, 8], [4])
    ]
    
    passed = 0
    failed = 0
    
    for i, (list0, list1, list2, expected) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}")
        try:
            set_array(dut, "arr0", list0)
            set_array(dut, "arr1", list1)
            set_array(dut, "arr2", list2)
            dut.len0.value = len(list0)
            dut.len1.value = len(list1)
            dut.len2.value = len(list2)
            
            await Timer(10, units='ns')
            await start_computation(dut)
            await wait_for_done(dut)
            
            result = get_result(dut)
            result_set = set(result)
            expected_set = set(expected)
            
            if result_set != expected_set:
                raise TestFailure(f"Expected {expected_set}, got {result_set}")
            
            cocotb.log.info(f"  PASS")
            passed += 1
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")