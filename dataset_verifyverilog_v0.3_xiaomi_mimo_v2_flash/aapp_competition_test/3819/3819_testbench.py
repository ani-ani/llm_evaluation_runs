import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 8
ARRAY_SIZE = 8
RESULT_WIDTH = 8
CLK_PERIOD_NS = 10
MAX_CYCLES = 200

# ============================================================================
# MANDATORY HELPER FUNCTIONS
# ============================================================================

def is_value_defined(value):
    """Check if a cocotb value is defined (not X or Z)."""
    try:
        int(value)
        return True
    except ValueError:
        return False

def safe_int(value, default=0):
    """Safely convert cocotb value to int, returning default if X/Z."""
    try:
        return int(value)
    except ValueError:
        return default

def to_signed(val, bits):
    """Convert unsigned integer to signed (two's complement)."""
    if val >= (1 << (bits - 1)):
        return val - (1 << bits)
    return val

def from_signed(val, bits):
    """Convert signed integer to unsigned for Verilog assignment."""
    if val < 0:
        return val + (1 << bits)
    return val

def has_signal(dut, name):
    """Check if DUT has a signal with given name."""
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def clamp_to_width(value, bits):
    """Clamp value to fit within specified bit width (unsigned)."""
    max_val = (1 << bits) - 1
    if value < 0:
        return from_signed(max(-((1 << (bits-1))), min((1 << (bits-1)) - 1, value)), bits)
    return min(max_val, max(0, value))

# ============================================================================
# ARRAY ACCESS HELPERS
# ============================================================================

def write_card(dut, port_name, value):
    """Write single card value to DUT port."""
    if has_signal(dut, port_name):
        getattr(dut, port_name).value = clamp_to_width(value, DATA_WIDTH)
    else:
        raise TestFailure(f"Port {port_name} not found")

# ============================================================================
# SEQUENTIAL MODULE HELPERS
# ============================================================================

async def reset_dut(dut, cycles=2):
    """Reset the DUT (active-low reset)."""
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    """Wait for done signal with timeout."""
    for cycle in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout: done not asserted after {max_cycles} cycles")

async def start_computation(dut):
    """Pulse start signal for one cycle."""
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

# ============================================================================
# TEST CASES
# ============================================================================

def solve_python(n, hand, pile):
    """Reference Python implementation of the algorithm."""
    # Find positions of cards in pile
    pos = {}
    for i, card in enumerate(pile):
        if card != 0:
            pos[card] = i + 1  # 1-indexed
    
    # Check if there's a sequential chain starting from 1
    if 1 in pos:
        start_pos = pos[1]
        # Check if we have 1,2,3,... in sequence
        chain_len = 0
        for i in range(1, n + 1):
            if i in pos and pos[i] == start_pos + i - 1:
                chain_len = i
            else:
                break
        
        # Check if remaining cards can be played
        if chain_len == n - start_pos + 1:
            valid = True
            for i in range(1, start_pos):
                if i in pos:
                    if pos[i] > i:
                        valid = False
                        break
            if valid:
                return n - chain_len
    
    # General case: compute max(pos[i] - i + 1 + n)
    max_ops = 0
    for i in range(1, n + 1):
        if i in pos:
            ops = pos[i] - i + 1 + n
            if ops > max_ops:
                max_ops = ops
        else:
            # Card in hand, need to wait
            ops = 1 + n
            if ops > max_ops:
                max_ops = ops
    
    return max_ops

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_nauuo_cards(dut):
    """Test the Nauuo Cards module."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test cases: (hand, pile, expected_result, description)
    test_cases = [
        # Original examples scaled to n=3
        ([0, 2, 0], [3, 0, 1], 2, "Example 1: n=3"),
        ([0, 2, 0], [1, 0, 3], 4, "Example 2: n=3"),
        
        # Edge cases
        ([0, 0, 0, 0, 0, 0, 0, 0], [1, 2, 3, 4, 5, 6, 7, 8], 0, "Already sorted"),
        ([0, 0, 0, 0, 0, 0, 0, 0], [8, 1, 2, 3, 4, 5, 6, 7], 1, "Shifted by 1"),
        ([1, 0, 0, 0, 0, 0, 0, 0], [0, 2, 3, 4, 5, 6, 7, 8], 0, "1 in hand"),
        ([0, 0, 0, 0, 0, 0, 0, 0], [0, 0, 0, 0, 0, 0, 0, 0], 8, "All empty in pile"),
        ([0, 0, 0, 0, 0, 0, 0, 0], [2, 3, 4, 5, 6, 7, 8, 1], 7, "1 at bottom"),
        
        # Additional test cases
        ([0, 0, 0, 0, 0, 0, 0, 0], [0, 1, 0, 2, 0, 3, 0, 4], 11, "Scattered with gaps"),
        ([0, 0, 0, 0, 0, 0, 0, 0], [4, 5, 6, 7, 8, 0, 0, 0], 5, "Partial sequence at start"),
        ([0, 0, 0, 0, 0, 0, 0, 0], [0, 0, 0, 0, 0, 1, 2, 3], 11, "Sequence at end"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (hand, pile, expected, description) in enumerate(test_cases):
        cocotb.log.info(f"\nTest {i+1}: {description}")
        cocotb.log.info(f"  Hand: {hand}")
        cocotb.log.info(f"  Pile: {pile}")
        cocotb.log.info(f"  Expected: {expected}")
        
        try:
            # Write hand cards
            write_card(dut, 'hand_0', hand[0])
            write_card(dut, 'hand_1', hand[1])
            write_card(dut, 'hand_2', hand[2])
            write_card(dut, 'hand_3', hand[3])
            write_card(dut, 'hand_4', hand[4])
            write_card(dut, 'hand_5', hand[5])
            write_card(dut, 'hand_6', hand[6])
            write_card(dut, 'hand_7', hand[7])
            
            # Write pile cards
            write_card(dut, 'pile_0', pile[0])
            write_card(dut, 'pile_1', pile[1])
            write_card(dut, 'pile_2', pile[2])
            write_card(dut, 'pile_3', pile[3])
            write_card(dut, 'pile_4', pile[4])
            write_card(dut, 'pile_5', pile[5])
            write_card(dut, 'pile_6', pile[6])
            write_card(dut, 'pile_7', pile[7])
            
            # Start computation
            await start_computation(dut)
            await wait_for_done(dut)
            
            # Read result
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result is undefined (X/Z)")
            
            result = int(dut.result.value)
            
            # Verify against Python reference
            expected_python = solve_python(8, hand, pile)
            if expected_python != expected:
                cocotb.log.warning(f"  Python reference mismatch: got {expected_python}, expected {expected}")
            
            if result != expected and result != expected_python:
                raise TestFailure(f"Expected {expected} (or {expected_python}), got {result}")
            
            cocotb.log.info(f"  PASS: result = {result}")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    # Summary
    cocotb.log.info(f"\n{'='*60}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")
