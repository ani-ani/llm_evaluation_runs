import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

DATA_WIDTH = 4
ARRAY_SIZE = 9  # 3x3
CLK_NS = 10
MAX_CYCLES = 1000

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
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=1000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value)==1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_monotonic_subgrids(dut):
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    else:
        raise TestFailure("Module must be sequential (requires clock)")
    
    # Test with example 3x3 grid
    # Expected: 49 monotonic subgrids
    test_cases = [
        (49, "Example 3x3 grid")
    ]
    
    passed = 0
    for exp, desc in test_cases:
        cocotb.log.info(f"Test: {desc}, expected {exp}")
        try:
            # Start the computation
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Wait for done
            await wait_for_done(dut, max_cycles=256)
            
            # Read result
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result undefined")
            result = int(dut.result.value)
            
            if result != exp:
                raise TestFailure(f"Expected {exp}, got {result}")
            passed += 1
            cocotb.log.info(f"PASS: {result}")
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            raise
    
    cocotb.log.info(f"All {passed} tests passed")