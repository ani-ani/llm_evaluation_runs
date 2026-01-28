import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

DATA_WIDTH = 16
ARRAY_SIZE = 16
CLK_NS = 10
MAX_CYCLES = 1000

def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def safe_int(v, default=0):
    try: return int(v)
    except ValueError: return default

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def sum_digits(n):
    s = 0
    while n > 0:
        s += n % 10
        n //= 10
    return s

def is_prime(n):
    if n <= 1: return False
    if n <= 3: return True
    if n % 2 == 0 or n % 3 == 0: return False
    i = 5
    while i * i <= n:
        if n % i == 0 or n % (i + 2) == 0:
            return False
        i += 6
    return True

def python_solve(lst):
    max_prime = 0
    for x in lst:
        if is_prime(x) and x > max_prime:
            max_prime = x
    return sum_digits(max_prime)

async def write_array(dut, vals):
    for i in range(ARRAY_SIZE):
        val = vals[i] if i < len(vals) else 0
        getattr(dut, f'arr_{i}').value = clamp_to_width(val, DATA_WIDTH)

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=500):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_skjkasdkd(dut):
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    else:
        # Combinational testbench logic
        pass

    test_cases = [
        ([0,3,2,1,3,5,7,4,5,5,5,2,181,32,4,32], 10),
        ([1,0,1,8,2,4597,2,1,3,40,1,2,1,2,4,2], 25),
        ([1,3,1,32,5107,34,83278,109,163,23,2323,32,30,1,9,3], 13),
        ([0,724,32,71,99,32,6,0,5,91,83,0,5,6], 11),
        ([0,81,12,3,1,21], 3),
        ([0,8,1,2,1,7], 7),
        ([8191], 19),
        ([8191, 123456, 127, 7], 19),
        ([127, 97, 8192], 10)
    ]

    passed = 0
    failed = 0

    for idx, (inp, exp) in enumerate(test_cases):
        cocotb.log.info(f"Test {idx+1}: Input={inp}, Expected={exp}")
        try:
            await write_array(dut, inp)
            dut.len.value = len(inp)

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
            if result != exp:
                raise TestFailure(f"Expected {exp}, got {result}")

            passed += 1

        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1

    if failed:
        raise TestFailure(f"{failed} tests failed, {passed} passed")