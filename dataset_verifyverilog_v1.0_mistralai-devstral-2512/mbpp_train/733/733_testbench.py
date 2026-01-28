import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def safe_int(v, default=0):
    try: return int(v)
    except ValueError: return default

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

DATA_WIDTH = 8
ARRAY_SIZE = 10
CLK_NS = 10
MAX_CYCLES = 100

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=100):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_find_first_occurrence(dut):
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    
    # Test case 1: [2, 5, 5, 5, 6, 6, 8, 9, 9, 9], x=5, expected=1
    test_cases = [
        (list(range(ARRAY_SIZE)), 0, 0, "First element"),
        (list(range(ARRAY_SIZE)), 9, 9, "Last element"),
        ([2, 5, 5, 5, 6, 6, 8, 9, 9, 9], 5, 1, "First occurrence of 5"),
        ([2, 3, 5, 5, 6, 6, 8, 9, 9, 9], 5, 2, "First occurrence of 5 (position 2)"),
        ([2, 4, 1, 5, 6, 6, 8, 9, 9, 9], 6, 4, "First occurrence of 6 (position 4)"),
        ([1, 2, 3, 4, 5, 6, 7, 8, 9, 10], 15, 255, "Value not found"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (arr_vals, x_val, exp_idx, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc}")
        try:
            # Set array values
            for j in range(ARRAY_SIZE):
                port_name = f'arr_{j}'
                if hasattr(dut, port_name):
                    val = arr_vals[j] if j < len(arr_vals) else 0
                    getattr(dut, port_name).value = clamp_to_width(val, DATA_WIDTH)
            
            # Set search value and length
            if has_signal(dut, 'x'):
                dut.x.value = clamp_to_width(x_val, DATA_WIDTH)
            if has_signal(dut, 'len'):
                dut.len.value = clamp_to_width(len(arr_vals), 4)
            
            if is_seq:
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                await wait_for_done(dut)
            else:
                await Timer(100, units='ns')
            
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result signal undefined")
            
            result = int(dut.result.value)
            if result != exp_idx:
                raise TestFailure(f"Expected index {exp_idx}, got {result}")
            
            passed += 1
            cocotb.log.info(f"PASS: {desc} - Result={result}")
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {desc} - {e}")
            failed += 1
    
    if failed > 0:
        raise TestFailure(f"{failed} out of {passed+failed} tests failed")
