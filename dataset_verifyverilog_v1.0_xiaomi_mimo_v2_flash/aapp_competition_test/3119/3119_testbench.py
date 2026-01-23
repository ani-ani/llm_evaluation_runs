import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 4        # 4-bit time values
MAX_TIME = 15         # Maximum time value
CLK_PERIOD_NS = 10
MAX_CYCLES = 1000

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
    return min(max_val, max(0, value))

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
async def test_guitar_hero_max_score(dut):
    """Test guitar_hero_max_score module."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Define test cases: (num_notes, notes_list, num_phrases, phrases_list, expected_score, description)
    # notes_list: up to 4 values
    # phrases_list: list of (start, end) tuples
    test_cases = [
        (3, [0,10,20], 1, [(0,10)], 4, "Example 1: one phrase, charge full, activate after phrase"),
        (4, [0,5,10,15], 2, [(0,5), (10,15)], 5, "Two short phrases, protect both, activation after"),
        (4, [0,5,10,15], 0, [], 4, "No phrases, no doubling"),
        (4, [0,1,2,3], 2, [(0,3), (5,10)], 4, "Long phrase, protect first, activation after"),
        (4, [0,1,2,3], 1, [(0,15)], 4, "Single long phrase, protect it, activation after"),
        (4, [0,1,2,3], 1, [(0,0)], 4, "Zero-duration phrase (should not affect)"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (num_notes, notes, num_phrases, phrases, expected, description) in enumerate(test_cases):
        dut._log.info(f"\nTest {i+1}: {description}")
        
        # Set inputs
        dut.num_notes.value = num_notes
        dut.note0.value = notes[0] if len(notes) > 0 else 0
        dut.note1.value = notes[1] if len(notes) > 1 else 0
        dut.note2.value = notes[2] if len(notes) > 2 else 0
        dut.note3.value = notes[3] if len(notes) > 3 else 0
        
        dut.num_phrases.value = num_phrases
        if num_phrases > 0:
            dut.phrase0_start.value = phrases[0][0]
            dut.phrase0_end.value = phrases[0][1]
        else:
            dut.phrase0_start.value = 0
            dut.phrase0_end.value = 0
        
        if num_phrases > 1:
            dut.phrase1_start.value = phrases[1][0]
            dut.phrase1_end.value = phrases[1][1]
        else:
            dut.phrase1_start.value = 0
            dut.phrase1_end.value = 0
        
        # Wait for previous done to be low
        await FallingEdge(dut.done) if has_signal(dut, 'done') else Timer(1, units='ns')
        
        # Start computation
        await start_computation(dut)
        
        # Wait for done
        if has_signal(dut, 'done'):
            await wait_for_done(dut)
        else:
            # Combinational module - wait for propagation
            await Timer(100, units='ns')
        
        # Read result
        if not is_value_defined(dut.max_score.value):
            raise TestFailure(f"Result is undefined (X/Z)")
        
        result = int(dut.max_score.value)
        
        if result != expected:
            dut._log.error(f"  FAIL: Expected {expected}, got {result}")
            failed += 1
        else:
            dut._log.info(f"  PASS: result = {result}")
            passed += 1
    
    # Summary
    dut._log.info(f"{'='*50}")
    dut._log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")