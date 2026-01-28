import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import math

DATA_WIDTH = 16
ARRAY_SIZE = 10
CLK_NS = 10
MAX_CYCLES = 300

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

def float_to_fixed_q8_8(f):
    return int(round(f * 256))

def fixed_to_float_q8_8(v):
    return v / 256.0

def pack_array(vals, bits=16):
    r = 0
    for i, v in enumerate(vals):
        r |= (v & ((1 << bits) - 1)) << (i * bits)
    return r

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_striker_count(dut):
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    else:
        await Timer(100, units='ns')

    test_cases = [
        {
            'circles': [
                (5.0, 0.0, 1.0),
                (10.0, 0.0, 1.0),
                (0.0, 5.0, 1.0),
                (0.0, -5.0, 1.0),
                (-5.0, 0.0, 1.0)
            ],
            'expected': 2,
            'desc': 'Sample 1: 5 circles on axes'
        },
        {
            'circles': [
                (2.0, 2.0, 2.0),
                (6.0, 2.0, 1.0),
                (10.0, 2.0, 1.0),
                (2.0, 6.0, 1.0),
                (6.0, 6.0, 1.0),
                (2.0, 10.0, 1.0)
            ],
            'expected': 3,
            'desc': 'Sample 2: 6 circles in cluster'
        }
    ]

    passed = 0
    failed = 0

    for tc in test_cases:
        cocotb.log.info(f"Test: {tc['desc']}")
        try:
            n = len(tc['circles'])
            x_vals = []
            y_vals = []
            r_vals = []
            for (x, y, r) in tc['circles']:
                x_vals.append(float_to_fixed_q8_8(x))
                y_vals.append(float_to_fixed_q8_8(y))
                r_vals.append(float_to_fixed_q8_8(r))

            # Write inputs individually (no array assignment)
            for i in range(ARRAY_SIZE):
                dut_x = getattr(dut, f'x_arr_{i}')
                dut_y = getattr(dut, f'y_arr_{i}')
                dut_r = getattr(dut, f'r_arr_{i}')
                if i < n:
                    dut_x.value = clamp_to_width(x_vals[i], DATA_WIDTH)
                    dut_y.value = clamp_to_width(y_vals[i], DATA_WIDTH)
                    dut_r.value = clamp_to_width(r_vals[i], DATA_WIDTH)
                else:
                    dut_x.value = 0
                    dut_y.value = 0
                    dut_r.value = 0
            
            if is_seq:
                dut.n.value = n
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                await wait_for_done(dut)
            else:
                await Timer(100, units='ns')

            if not is_value_defined(dut.result.value):
                raise TestFailure("Result undefined")
            
            result = int(dut.result.value)
            expected = tc['expected']
            
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            passed += 1
            cocotb.log.info(f"PASS: {result} hits")
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1

    if failed:
        raise TestFailure(f"{failed} tests failed")

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_corner_case(dut):
    """Test single circle"""
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    else:
        await Timer(100, units='ns')

    try:
        n = 1
        x_vals = [float_to_fixed_q8_8(10.0)]
        y_vals = [float_to_fixed_q8_8(0.0)]
        r_vals = [float_to_fixed_q8_8(1.0)]

        for i in range(ARRAY_SIZE):
            dut_x = getattr(dut, f'x_arr_{i}')
            dut_y = getattr(dut, f'y_arr_{i}')
            dut_r = getattr(dut, f'r_arr_{i}')
            if i == 0:
                dut_x.value = clamp_to_width(x_vals[0], DATA_WIDTH)
                dut_y.value = clamp_to_width(y_vals[0], DATA_WIDTH)
                dut_r.value = clamp_to_width(r_vals[0], DATA_WIDTH)
            else:
                dut_x.value = 0
                dut_y.value = 0
                dut_r.value = 0

        if is_seq:
            dut.n.value = n
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            await wait_for_done(dut)
        else:
            await Timer(100, units='ns')

        result = int(dut.result.value)
        expected = 1
        if result != expected:
            raise TestFailure(f"Expected {expected}, got {result}")
        cocotb.log.info("PASS: Single circle test")
    except TestFailure as e:
        cocotb.log.error(f"FAIL: {e}")
        raise
