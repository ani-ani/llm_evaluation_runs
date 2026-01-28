import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

DATA_WIDTH = 8
ARRAY_SIZE = 16
CLK_NS = 10
MAX_CYCLES = 20

def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

async def wait_for_done(dut, max_cycles=100):
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

async def write_array(dut, name, values, width):
    for i, v in enumerate(values):
        dut.__getattr__(name)[i].value = clamp_to_width(v, width)

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_unique_element_checker(dut):
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    
    test_cases = [
        ([1,1,1], 3, 1, "all same 3 elements"),
        ([1,2,1,2], 4, 0, "two distinct elements"),
        ([1,2,3,4,5], 5, 0, "five distinct elements"),
        ([7,7], 2, 1, "two identical"),
        ([42], 1, 1, "single element"),
        ([1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1], 16, 1, "all same 16 elements"),
        ([5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,6], 16, 0, "15 same, 1 different"),
        ([0,0,0,0], 4, 1, "zeros"),
        ([128,128,128], 3, 1, "large numbers"),
        ([100,101,100], 3, 0, "near numbers different")
    ]
    
    passed = failed = 0
    
    for i, (arr_vals, length, expected, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc} - arr={arr_vals}, len={length}")
        try:
            await write_array(dut, 'arr', arr_vals, DATA_WIDTH)
            
            if is_seq:
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                await wait_for_done(dut, MAX_CYCLES)
            else:
                await Timer(100, units='ns')
            
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result undefined")
            
            result = int(dut.result.value)
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            if is_seq:
                if not is_value_defined(dut.done.value) or int(dut.done.value) != 1:
                    raise TestFailure("done signal not 1 when result valid")
            
            passed += 1
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} tests failed out of {passed + failed}")
    
    cocotb.log.info(f"All {passed} tests passed")