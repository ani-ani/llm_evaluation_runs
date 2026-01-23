import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Helper functions
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
    return min(max_val, max(0, value))

async def reset_dut(dut):
    dut.rst_n.value = 0
    dut.start.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def start_computation(dut):
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

async def wait_for_done(dut, max_cycles=10000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout: done not asserted after {max_cycles} cycles")

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_data_collection(dut):
    # Start clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Test cases
    test_cases = [
        ("1 1 2 3 1 0\n2 4 20", 3),
        ("1 1 2 3 1 0\n15 27 26", 2),
        ("1 1 2 3 1 0\n2 2 1", 0),
        # Additional cases would be added here
    ]
    
    for test_input, expected in test_cases:
        lines = test_input.strip().split('\n')
        params = list(map(int, lines[0].split()))
        inputs = list(map(int, lines[1].split()))
        
        # Write inputs to DUT
        dut.x0.value = params[0]
        dut.y0.value = params[1]
        dut.ax.value = params[2]
        dut.ay.value = params[3]
        dut.bx.value = params[4]
        dut.by.value = params[5]
        dut.xs.value = inputs[0]
        dut.ys.value = inputs[1]
        dut.t.value = inputs[2]
        
        await reset_dut(dut)
        await start_computation(dut)
        await wait_for_done(dut)
        
        if not is_value_defined(dut.result.value):
            raise TestFailure("Result is undefined (X/Z)")
        
        result = int(dut.result.value)
        if result != expected:
            raise TestFailure(f"Expected {expected}, got {result}")
        
        dut._log.info(f"Test passed: {result} == {expected}")
