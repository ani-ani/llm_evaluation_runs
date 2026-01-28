import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

DATA_WIDTH = 8
ARRAY_SIZE = 8
CLK_PERIOD_NS = 10
MAX_CYCLES = 100

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

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    for cycle in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout: done not asserted after {max_cycles} cycles")

@cocotb.test(timeout_time=2000, timeout_unit="ms")
async def test_check_min_heap(dut):
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    await reset_dut(dut)
    
    test_cases = [
        ([1, 2, 3, 4, 5, 6], 6, True, "Valid min heap [1,2,3,4,5,6]"),
        ([2, 3, 4, 5, 10, 15], 6, True, "Valid min heap [2,3,4,5,10,15]"),
        ([2, 10, 4, 5, 3, 15], 6, False, "Invalid heap [2,10,4,5,3,15]"),
        ([1], 1, True, "Single element"),
        ([5, 1, 2], 3, False, "Root larger than left child"),
        ([1, 2, 1], 3, True, "Root smaller than both children"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (arr_values, length, expected, description) in enumerate(test_cases):
        cocotb.log.info(f"\nTest {i+1}: {description}")
        
        try:
            arr_padded = arr_values + [0] * (8 - len(arr_values))
            
            dut.arr_0.value = arr_padded[0]
            dut.arr_1.value = arr_padded[1]
            dut.arr_2.value = arr_padded[2]
            dut.arr_3.value = arr_padded[3]
            dut.arr_4.value = arr_padded[4]
            dut.arr_5.value = arr_padded[5]
            dut.arr_6.value = arr_padded[6]
            dut.arr_7.value = arr_padded[7]
            dut.len.value = length
            
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            await wait_for_done(dut)
            
            if not is_value_defined(dut.is_heap.value):
                raise TestFailure("Result is undefined")
            
            result = bool(int(dut.is_heap.value))
            
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            cocotb.log.info(f"  PASS: is_heap = {result}")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
        
        await RisingEdge(dut.clk)
    
    cocotb.log.info(f"{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")