import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 16
ARRAY_SIZE = 4
CLK_PERIOD_NS = 10
MAX_CYCLES = 1000

# ============================================================================
# HELPER FUNCTIONS
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
# ARRAY ACCESS HELPERS
# ============================================================================

async def write_strengths(dut, strengths):
    """Write strengths to individual ports."""
    for i, val in enumerate(strengths):
        port_name = f'strength_{i}'
        if has_signal(dut, port_name):
            getattr(dut, port_name).value = clamp_to_width(val, DATA_WIDTH)
        else:
            raise TestFailure(f"Cannot find signal: {port_name}")

async def read_result(dut):
    """Read max_damage and best_pillar."""
    if not is_value_defined(dut.max_damage.value):
        raise TestFailure("max_damage is undefined")
    if not is_value_defined(dut.best_pillar.value):
        raise TestFailure("best_pillar is undefined")
    return int(dut.max_damage.value), int(dut.best_pillar.value)

# ============================================================================
# SEQUENTIAL MODULE HELPERS
# ============================================================================

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    for cycle in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout: done not asserted after {max_cycles} cycles")

async def start_computation(dut):
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_pillar_collapse(dut):
    """Test pillar collapse module."""
    
    # Setup clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test cases: (n, strengths, expected_damage, expected_pillar, description)
    test_cases = [
        # From example: 5 pillars but we scale to 4 for hardware
        # We'll test simplified cases
        (4, [1341, 2412, 1200, 3112], 3, 1, "Small test 1"),
        (4, [1004, 1003, 1002, 1001], 4, 0, "Small test 2"),
        (3, [1500, 1500, 1500], 2, 1, "Equal strengths"),
        (4, [10000, 1000, 10000, 10000], 2, 1, "Weak middle pillar"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (n, strengths, exp_damage, exp_pillar, description) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {description}")
        
        try:
            # Write strengths
            await write_strengths(dut, strengths)
            
            # Set n
            dut.n.value = n
            
            # Start computation
            await start_computation(dut)
            
            # Wait for done
            await wait_for_done(dut)
            
            # Read results
            max_damage, best_pillar = await read_result(dut)
            
            # Verify
            if max_damage != exp_damage or best_pillar != exp_pillar:
                raise TestFailure(
                    f"Expected (damage={exp_damage}, pillar={exp_pillar}), "
                    f"got (damage={max_damage}, pillar={best_pillar})"
                )
            
            cocotb.log.info(f"  PASS: damage={max_damage}, pillar={best_pillar}")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
        
        # Wait one cycle between tests
        await RisingEdge(dut.clk)
    
    # Summary
    cocotb.log.info(f"{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")
