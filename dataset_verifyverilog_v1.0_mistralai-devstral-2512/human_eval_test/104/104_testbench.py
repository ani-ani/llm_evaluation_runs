import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

DATA_WIDTH, MAX_INPUTS, CLK_NS, MAX_CYCLES = 8, 8, 10, 256

# Helper functions
def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

def safe_int(v, default=0):
    try: return int(v)
    except ValueError: return default

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def write_inputs(dut, values):
    for i in range(MAX_INPUTS):
        if i < len(values):
            dut.__getattr__(f'input_{i}').value = clamp_to_width(values[i], DATA_WIDTH)
        else:
            dut.__getattr__(f'input_{i}').value = 0
    dut.input_len.value = clamp_to_width(len(values), 4)

def read_outputs(dut):
    length = int(dut.output_len.value)
    return [int(dut.__getattr__(f'output_{i}').value) for i in range(length)]

def has_even_digit(num):
    if num == 0:
        return True
    n = num
    while n > 0:
        digit = n % 10
        if digit % 2 == 0:
            return True
        n //= 10
    return False

def filter_unique_digits(input_list):
    result = [n for n in input_list if not has_even_digit(n)]
    result.sort()
    return result

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_unique_digits(dut):
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    else:
        raise TestFailure("Sequential design required")
    
    test_cases = [
        ([15, 33, 1422, 1], [1, 15, 33]),
        ([152, 323, 1422, 10], []),
        ([12345, 2033, 111, 151], [111, 151]),
        ([135, 103, 31], [31, 135]),
        ([1, 3, 5, 7, 9], [1, 3, 5, 7, 9]),
        ([2, 4, 6, 8, 10], []),
        ([11, 33, 55, 77, 99], [11, 33, 55, 77, 99]),
        ([12, 34, 56], []),
        ([], []),
        ([123, 234, 345, 456, 567, 678, 789, 890], [])
    ]
    
    passed = 0
    failed = 0
    
    for i, (inp, exp) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: Input={inp}, Expected={exp}")
        try:
            await write_inputs(dut, inp)
            await Timer(5, units='ns')
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            await wait_for_done(dut)
            
            result = read_outputs(dut)
            if result != exp:
                raise TestFailure(f"Expected {exp}, got {result}")
            passed += 1
            cocotb.log.info(f"  PASS")
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} tests failed")
    
    cocotb.log.info(f"\nAll tests passed: {passed}/{passed + failed}")