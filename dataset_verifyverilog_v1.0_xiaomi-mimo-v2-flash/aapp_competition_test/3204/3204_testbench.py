import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Helpers
def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.load_en.value = 0
    dut.N.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def load_boat_times(dut, times):
    dut.N.value = len(times)
    await RisingEdge(dut.clk)
    for t in times:
        dut.boat_time_in.value = clamp_to_width(t, 16)
        dut.load_en.value = 1
        await RisingEdge(dut.clk)
        dut.load_en.value = 0
        await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=2000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

@cocotb.test(timeout_time=5000, timeout_unit='ms')
async def test_bridge(dut):
    # Setup clock
    if has_signal(dut, 'clk'):
        cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
        await reset_dut(dut)
    
    test_cases = [
        ([100, 200], 160),
        ([100, 200, 2010], 250),
        ([100, 200, 2100], 300)
    ]

    for i, (times, expected) in enumerate(test_cases):
        cocotb.log.info(f"Running Test Case {i+1}: times={times}, expected={expected}")
        
        # Load data
        await load_boat_times(dut, times)
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for completion
        await wait_for_done(dut)
        
        # Check result
        if not is_value_defined(dut.result.value):
            raise TestFailure("Result signal is undefined")
            
        result = int(dut.result.value)
        if result != expected:
            raise TestFailure(f"Test {i+1} Failed: Expected {expected}, got {result}")
        
        # Small delay between tests
        await Timer(100, units='ns')
        await reset_dut(dut)