import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

DATA_WIDTH = 8
ARRAY_SIZE = 8
CLK_NS = 10
MAX_CYCLES = 2000

# Helpers
def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def safe_int(v, default=0):
    try: return int(v)
    except ValueError: return default

def from_signed(val, bits):
    return val + (1 << bits) if val < 0 else val

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

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

async def write_array(dut, vals, width):
    for i, v in enumerate(vals):
        dut.data_in[i].value = clamp_to_width(v, width)

async def read_result(dut):
    keys = []
    values = []
    for i in range(4):
        k = safe_int(getattr(dut, f'key_{i}').value)
        v = safe_int(getattr(dut, f'value_{i}').value)
        keys.append(k)
        values.append(v)
    return keys, values

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_tuple_to_dict(dut):
    # Setup clock
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    
    # Test cases: (input_array, expected_keys, expected_values)
    test_cases = [
        ([1, 5, 7, 10, 13, 5, 0, 0], [1, 7, 13, 0], [5, 10, 5, 0], "Test 1: (1,5,7,10,13,5)"),
        ([1, 2, 3, 4, 5, 6, 0, 0], [1, 3, 5, 0], [2, 4, 6, 0], "Test 2: (1,2,3,4,5,6)"),
        ([7, 8, 9, 10, 11, 12, 0, 0], [7, 9, 11, 0], [8, 10, 12, 0], "Test 3: (7,8,9,10,11,12)"),
        ([255, 255, 128, 64, 32, 16, 8, 4], [255, 128, 32, 8], [255, 64, 16, 4], "Test 4: Edge values"),
        ([0, 0, 0, 0, 0, 0, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0], "Test 5: All zeros"),
    ]
    
    passed = failed = 0
    
    for i, (inp, exp_keys, exp_vals, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc}")
        try:
            if is_seq:
                await write_array(dut, inp, DATA_WIDTH)
                await RisingEdge(dut.clk)
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                await wait_for_done(dut)
                
                if not is_value_defined(dut.result_valid.value):
                    raise TestFailure("Result valid undefined")
                
                result_valid = int(dut.result_valid.value)
                if result_valid != 1:
                    raise TestFailure(f"Result valid not asserted (got {result_valid})")
                
                keys, values = await read_result(dut)
            else:
                await write_array(dut, inp, DATA_WIDTH)
                await Timer(100, units='ns')
                keys, values = await read_result(dut)
            
            if keys != exp_keys or values != exp_vals:
                raise TestFailure(f"Expected keys={exp_keys}, values={exp_vals}, got keys={keys}, values={values}")
            
            passed += 1
            cocotb.log.info(f"  PASS: keys={keys}, values={values}")
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} out of {len(test_cases)} tests failed")
