import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Constants
DATA_WIDTH = 16
ARRAY_SIZE = 16
CLK_NS = 10
MAX_CYCLES = 2048

# Helper functions
def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def safe_int(v, default=0):
    try: return int(v)
    except ValueError: return default

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

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def read_result(dut):
    """Read result array and length from DUT."""
    length = int(dut.result_len.value)
    values = []
    for i in range(length):
        if has_signal(dut, f'result_{i}'):
            val = getattr(dut, f'result_{i}').value
            if is_value_defined(val):
                values.append(int(val))
            else:
                raise TestFailure(f"Result bit {i} undefined")
        else:
            raise TestFailure(f"Signal result_{i} not found")
    return values

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_odd_collatz(dut):
    """Test the odd Collatz numbers generator."""
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    await reset_dut(dut)
    
    # Test cases: (input, expected sorted odd list)
    test_cases = [
        (1, [1]),
        (5, [1, 5]),
        (12, [1, 3, 5]),
        (14, [1, 5, 7, 11, 13, 17]),
    ]
    
    passed = 0
    failed = 0
    
    for i, (n_in, exp) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: n_in={n_in}")
        try:
            # Set input
            dut.n_in.value = n_in
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Wait for completion
            await wait_for_done(dut)
            
            # Read result
            result = await read_result(dut)
            
            # Compare
            if result != exp:
                raise TestFailure(f"Expected {exp}, got {result}")
            
            passed += 1
        except TestFailure as e:
            cocotb.log.error(f"FAIL: Test {i+1}: {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} tests failed, {passed} passed")