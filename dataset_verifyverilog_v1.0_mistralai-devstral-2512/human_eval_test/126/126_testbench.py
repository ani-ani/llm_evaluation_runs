import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

DATA_WIDTH = 8
ARRAY_SIZE = 8
CLK_NS = 10
MAX_CYCLES = 100

def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

async def wait_for_done(dut, max_cycles=1000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value)==1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def write_array(dut, name, vals, width):
    for i, v in enumerate(vals):
        getattr(dut, name)[i].value = clamp_to_width(v, width)

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_is_sorted(dut):
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    
    test_cases = [
        ([5], True, "single element"),
        ([1, 2, 3, 4, 5], True, "sorted ascending"),
        ([1, 3, 2, 4, 5], False, "unsorted at position 1"),
        ([1, 2, 2, 3, 3, 4], True, "with 2 duplicates"),
        ([1, 2, 2, 2, 3, 4], False, "with 3 duplicates"),
        ([], True, "empty array"),
        ([1], True, "single element 1"),
        ([3, 2, 1], False, "decreasing"),
        ([1, 2, 3, 4], True, "4 elements sorted"),
    ]
    
    passed = failed = 0
    
    for i, (inp, exp, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc}")
        try:
            await write_array(dut, 'arr', inp, DATA_WIDTH)
            if is_seq:
                dut.length.value = len(inp)
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                await wait_for_done(dut)
            else:
                await Timer(100, units='ns')
            
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result undefined")
            result = int(dut.result.value)
            exp_int = 1 if exp else 0
            if result != exp_int:
                raise TestFailure(f"Expected {exp_int}, got {result}")
            passed += 1
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}"); failed += 1
    
    if failed:
        raise TestFailure(f"{failed} tests failed")