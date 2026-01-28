import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Helper functions
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

def to_signed(val, bits):
    return val - (1 << bits) if val >= (1 << (bits-1)) else val

def from_signed(val, bits):
    return val + (1 << bits) if val < 0 else val

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=5000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

def even_power_sum_py(n):
    sum_val = 0
    for i in range(1, n + 1):
        j = 2 * i
        sum_val += j ** 5
    return sum_val

@cocotb.test(timeout_time=10, timeout_unit='s')
async def test_even_power_sum(dut):
    CLK_NS = 10
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    await reset_dut(dut)
    
    test_cases = [
        (1, even_power_sum_py(1)),
        (2, even_power_sum_py(2)),
        (3, even_power_sum_py(3)),
        (5, even_power_sum_py(5))  # Additional test for stability
    ]
    
    for n_input, expected in test_cases:
        dut.n.value = clamp_to_width(n_input, 8)
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        await wait_for_done(dut)
        
        if not is_value_defined(dut.result.value):
            raise TestFailure("Result signal undefined")
        
        result = int(dut.result.value)
        if result != expected:
            raise TestFailure(f"For n={n_input}, expected {expected}, got {result}")
        
        cocotb.log.info(f"Test passed for n={n_input}: {result}")
