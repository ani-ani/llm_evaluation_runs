import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import cocotb.log

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 8
RESULT_WIDTH = 16
CLK_PERIOD_NS = 10
MAX_CYCLES = 100

# ============================================================================
# MANDATORY HELPER FUNCTIONS
# ============================================================================
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

# ============================================================================
# SEQUENTIAL MODULE HELPERS
# ============================================================================
async def reset_dut(dut):
    dut.rst_n.value = 0
    dut.start.value = 0
    for _ in range(2):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    for cycle in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout: done not asserted after {max_cycles} cycles")

async def start_computation(dut, flight_count, flight_seq, ow12, ow21, rt12, rt21):
    dut.flight_count.value = flight_count
    dut.flight_seq.value = flight_seq
    dut.price_ow_12.value = ow12
    dut.price_ow_21.value = ow21
    dut.price_rt_12.value = rt12
    dut.price_rt_21.value = rt21
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

# ============================================================================
# TEST CASES
# ============================================================================
# Test case 1: 2 flights, best is round-trip 1->2
# Flights: 1->2 (dir=0), 2->1 (dir=1)
# Prices: ow12=5, ow21=5, rt12=8, rt21=8
# Expected: 8
TEST_CASES = [
    {
        "name": "Two flights: 1->2 then 2->1",
        "flight_count": 2,
        "flight_seq": 0b00000010,  # bit0=0 (flight0 1->2), bit1=1 (flight1 2->1)
        "ow12": 5,
        "ow21": 5,
        "rt12": 8,
        "rt21": 8,
        "expected": 8
    },
    {
        "name": "Two flights: both 1->2",
        "flight_count": 2,
        "flight_seq": 0b00000000,  # both flights 1->2
        "ow12": 5,
        "ow21": 5,
        "rt12": 8,
        "rt21": 8,
        "expected": 10  # two one-way tickets
    }
]

# ============================================================================
# MAIN TEST
# ============================================================================
@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_min_cost_tour(dut):
    """Test the min_cost_tour module with two test cases."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    passed = 0
    failed = 0
    
    for tc in TEST_CASES:
        dut._log.info(f"Test: {tc['name']}")
        
        try:
            # Start computation
            await start_computation(
                dut,
                tc['flight_count'],
                tc['flight_seq'],
                tc['ow12'],
                tc['ow21'],
                tc['rt12'],
                tc['rt21']
            )
            
            # Wait for done
            await wait_for_done(dut)
            
            # Read result
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result is undefined (X/Z)")
            
            result = int(dut.result.value)
            expected = tc['expected']
            
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            dut._log.info(f"  PASS: result = {result}")
            passed += 1
            
        except TestFailure as e:
            dut._log.error(f"  FAIL: {e}")
            failed += 1
    
    dut._log.info(f"{'='*50}")
    dut._log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")
