import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

DATA_WIDTH, ARRAY_SIZE, CLK_NS, MAX_CYCLES = 8, 16, 10, 1000

def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def safe_int(v, default=0):
    try: return int(v)
    except ValueError: return default

def to_signed(val, bits):
    return val - (1 << bits) if val >= (1 << (bits-1)) else val

def from_signed(val, bits):
    return val + (1 << bits) if val < 0 else val

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

async def write_array(dut, name, vals, width):
    for i, v in enumerate(vals):
        dut.__getattr__(name)[i].value = clamp_to_width(v, width)

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=1000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value)==1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def test_case(dut, input_list, expected):
    """Test one case"""
    arr_len = len(input_list)
    
    # Write input array
    for i in range(ARRAY_SIZE):
        if i < arr_len:
            dut.arr[i].value = clamp_to_width(input_list[i], DATA_WIDTH)
        else:
            dut.arr[i].value = 0
    
    # Write arr_len
    dut.arr_len.value = clamp_to_width(arr_len, 4)
    
    # Start
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done
    await wait_for_done(dut, 100)
    
    # Read result
    result = []
    for i in range(ARRAY_SIZE):
        if is_value_defined(dut.result[i].value):
            val = int(dut.result[i].value)
            result.append(val)
        else:
            result.append(0)
    
    return result

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_move_zeroes(dut):
    # Setup
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    await reset_dut(dut)
    
    # Define test cases
    test_cases = [
        ([1, 0, 2, 0, 3, 4], [1, 2, 3, 4, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0], "Basic mixed"),
        ([2, 3, 2, 0, 0, 4, 0, 5, 0], [2, 3, 2, 4, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0], "Multiple zeros"),
        ([0, 1, 0, 1, 1], [1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0], "Leading zeros"),
        ([0, 0, 0, 0], [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0], "All zeros"),
        ([1, 2, 3, 4, 5], [1, 2, 3, 4, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0], "No zeros")
    ]
    
    passed = failed = 0
    
    for i, (inp, exp, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc}")
        try:
            result = await test_case(dut, inp, exp)
            if result != exp:
                raise TestFailure(f"Expected {exp}, got {result}")
            passed += 1
            cocotb.log.info(f"  PASS: {result}")
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} tests failed, {passed} passed")
    
    cocotb.log.info(f"All {passed} tests passed!")
