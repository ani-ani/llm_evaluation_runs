import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Constants
DATA_WIDTH = 4  # Parent array width (0-15)
ARRAY_SIZE = 16
CLK_NS = 10
MAX_CYCLES = 100

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

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_union_find(dut):
    # Setup clock
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    await reset_dut(dut)
    
    # Test cases: (operation_type, a, b, expected_result, description)
    # op_type: 0=join, 1=query
    test_cases = [
        (1, 1, 3, 0, "Initial query: 1 vs 3 -> no"),  # Query
        (0, 1, 8, 0, "Join 1 and 8"),                 # Join
        (0, 3, 8, 0, "Join 3 and 8"),                 # Join
        (1, 1, 3, 1, "Query: 1 vs 3 -> yes"),         # Query
        (1, 0, 7, 0, "Query: 0 vs 7 -> no"),          # Query (separate sets)
        (0, 0, 2, 0, "Join 0 and 2"),                 # Join
        (1, 0, 2, 1, "Query: 0 vs 2 -> yes"),         # Query
    ]
    
    passed = 0
    failed = 0
    
    for i, (op_type, a, b, exp, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc}")
        try:
            # Set inputs
            dut.start.value = 1
            dut.op_type.value = op_type
            dut.a.value = clamp_to_width(a, DATA_WIDTH)
            dut.b.value = clamp_to_width(b, DATA_WIDTH)
            
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Wait for done
            await wait_for_done(dut)
            
            # Read result
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result undefined")
            result = int(dut.result.value)
            
            if result != exp:
                raise TestFailure(f"Expected {exp}, got {result}")
            passed += 1
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} tests failed")