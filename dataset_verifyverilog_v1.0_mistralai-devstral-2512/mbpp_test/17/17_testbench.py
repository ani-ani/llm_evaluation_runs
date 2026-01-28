import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Helper functions
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

async def wait_for_done(dut, max_cycles=100):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout waiting for done signal after {max_cycles} cycles")

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_square_perimeter(dut):
    # Setup clock
    if has_signal(dut, 'clk'):
        cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    else:
        raise TestFailure("Module requires 'clk' input")
    
    # Reset
    await reset_dut(dut)
    
    # Test cases from prompt
    test_cases = [
        (10, 40),
        (5, 20),
        (4, 16)
    ]
    
    for side, expected_perimeter in test_cases:
        # Sample start and side input
        dut.start.value = 1
        dut.side_in.value = clamp_to_width(side, 8)
        await RisingEdge(dut.clk)
        
        # Deassert start
        dut.start.value = 0
        
        # Wait for done signal
        await wait_for_done(dut)
        
        # Read result
        if not is_value_defined(dut.perimeter_out.value):
            raise TestFailure(f"perimeter_out is undefined for side {side}")
        
        result = int(dut.perimeter_out.value)
        if result != expected_perimeter:
            raise TestFailure(f"For side {side}, expected {expected_perimeter}, got {result}")
        
        cocotb.log.info(f"Test passed: side={side}, perimeter={result}")
        
        # Wait one cycle to ensure done goes low before next test
        await RisingEdge(dut.clk)
        if int(dut.done.value) != 0:
            raise TestFailure("done signal did not go low after one cycle")