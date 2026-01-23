import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Helper functions (see above for complete implementation)
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

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=1000):
    for cycle in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout: done not asserted after {max_cycles} cycles")

async def start_computation(dut):
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_coin_ways(dut):
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    await reset_dut(dut)
    
    test_cases = [
        (1, [], [4], 2, 1, "Single type"),
        (2, [1], [4,4], 2, 3, "Same denomination"),
        (3, [3,3], [10,10,10], 17, 6, "Hierarchical"),
        (2, [2], [20,10], 34567, 17284, "Scaled numbers"),
    ]
    
    passed = 0
    for n, a_vals, b_vals, m_val, expected, desc in test_cases:
        dut.n.value = n
        for i in range(8):
            dut.a[i].value = a_vals[i] if i < len(a_vals) else 0
            dut.b[i].value = b_vals[i] if i < len(b_vals) else 0
        dut.m.value = m_val
        await RisingEdge(dut.clk)
        await start_computation(dut)
        await wait_for_done(dut)
        result = int(dut.result.value)
        assert result == expected, f"{desc}: expected {expected}, got {result}"
        passed += 1
    
    cocotb.log.info(f"All {passed} tests passed")