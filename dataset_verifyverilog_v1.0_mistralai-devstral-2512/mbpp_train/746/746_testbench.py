import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import math

DATA_WIDTH = 16
CLK_NS = 10
MAX_CYCLES = 1000

# Fixed-point constants
PI_Q16_16 = int(math.pi * (1 << 16))  # 0x3243F
INV_360_Q16_16 = int((1/360) * (1 << 16))  # 0x15E
MAX_ANGLE_FIXED = 360 * (1 << 16)  # 0x01680000

def is_value_defined(v):
    try:
        int(v)
        return True
    except ValueError:
        return False

def safe_int(v, default=0):
    try:
        return int(v)
    except ValueError:
        return default

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

async def wait_for_done(dut, max_cycles=1000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
        if is_value_defined(dut.error.value) and int(dut.error.value) == 1:
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

async def compute_expected(r_q16_16, a_q16_16):
    if a_q16_16 > MAX_ANGLE_FIXED:
        return None
    # area = (π * r^2 * a) / 360
    r = r_q16_16 / (1 << 16)
    a = a_q16_16 / (1 << 16)
    area = (math.pi * r * r) * (a / 360)
    return int(area * (1 << 16))

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_sector_area(dut):
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    
    test_cases = [
        (int(4.0 * (1 << 16)), int(45.0 * (1 << 16)), "r=4, a=45"),
        (int(9.0 * (1 << 16)), int(45.0 * (1 << 16)), "r=9, a=45"),
        (int(9.0 * (1 << 16)), int(361.0 * (1 << 16)), "r=9, a=361 (invalid)"),
        (int(0.0 * (1 << 16)), int(0.0 * (1 << 16)), "r=0, a=0"),
        (int(255.0 * (1 << 16)), int(360.0 * (1 << 16)), "max values"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (r_q16, a_q16, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc}")
        try:
            if is_seq:
                dut.radius.value = r_q16
                dut.angle.value = a_q16
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                await wait_for_done(dut)
                await RisingEdge(dut.clk)
            else:
                await Timer(100, units='ns')
            
            if not is_value_defined(dut.error.value):
                raise TestFailure("Error signal undefined")
            error = int(dut.error.value)
            
            if a_q16 > MAX_ANGLE_FIXED:
                if error != 1:
                    raise TestFailure(f"Expected error for angle >360, got error={error}")
                if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                    raise TestFailure("Done should be 0 on error")
                passed += 1
            else:
                if error != 0:
                    raise TestFailure(f"Unexpected error for valid input, error={error}")
                if not is_value_defined(dut.done.value) or int(dut.done.value) != 1:
                    raise TestFailure("Done should be 1 for valid result")
                
                if not is_value_defined(dut.result.value):
                    raise TestFailure("Result undefined")
                result = int(dut.result.value)
                expected = await compute_expected(r_q16, a_q16)
                if result != expected:
                    raise TestFailure(f"Expected {expected}, got {result}")
                passed += 1
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} tests failed")