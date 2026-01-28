import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

def is_value_defined(value):
    try:
        int(value)
        return True
    except ValueError:
        return False

def safe_int(value, default=0):
    try:
        return int(value)
    except ValueError:
        return default

def to_signed(val, bits):
    if val >= (1 << (bits - 1)):
        return val - (1 << bits)
    return val

def from_signed(val, bits):
    if val < 0:
        return val + (1 << bits)
    return val

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def clamp_to_width(value, bits):
    max_val = (1 << bits) - 1
    if value < 0:
        return from_signed(max(-((1 << (bits-1))), min((1 << (bits-1)) - 1, value)), bits)
    return min(max_val, max(0, value))

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_hunter_exam(dut):
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(10000):
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            break
        await RisingEdge(dut.clk)
    else:
        raise TestFailure("Timeout: done not asserted")
    
    if not is_value_defined(dut.result_max.value):
        raise TestFailure("Result is undefined")
    result = int(dut.result_max.value)
    expected = 16
    
    if result != expected:
        raise TestFailure(f"Expected {expected}, got {result}")