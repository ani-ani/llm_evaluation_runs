import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 8
STR_LEN = 4
N_MAX = 4
CLK_PERIOD_NS = 10
MAX_CYCLES = 1000

# ============================================================================
# HELPER FUNCTIONS
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
    return min(max_val, max(0, value))

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
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_teleportation(dut):
    """Main test for teleportation module."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Define test cases: (N, strings_list, expected_result, description)
    # strings_list: list of tuples (string, length)
    test_cases = [
        # Test case 1: Chain of length 4
        (
            4,
            [("A", 1), ("AA", 2), ("AAA", 3), ("AAAA", 4)],
            4,
            "Chain of 4 A's"
        ),
        # Test case 2: Chain of length 2
        (
            4,
            [("AB", 2), ("ABAB", 4), ("AB", 2), ("ABAB", 4)],
            2,
            "Chain of AB -> ABAB"
        ),
        # Test case 3: Chain of length 4 for B
        (
            4,
            [("B", 1), ("BB", 2), ("BBB", 3), ("BBBB", 4)],
            4,
            "Chain of 4 B's"
        ),
    ]
    
    passed = 0
    failed = 0
    
    for i, (N, strings, expected, description) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {description}")
        
        try:
            # Set N
            dut.N.value = N
            
            # Set strings
            for idx, (s, length) in enumerate(strings):
                # Fill up to STR_LEN characters
                for char_pos in range(STR_LEN):
                    if char_pos < length:
                        char_val = ord(s[char_pos])
                    else:
                        char_val = 0
                    # Set the corresponding signal
                    signal_name = f"str{idx}_char{char_pos}"
                    getattr(dut, signal_name).value = char_val
                # Set length
                len_signal_name = f"len{idx}"
                getattr(dut, len_signal_name).value = length
            
            # For any unused string indices (if N < 4), set their length to 0
            for idx in range(N, N_MAX):
                len_signal_name = f"len{idx}"
                if has_signal(dut, len_signal_name):
                    getattr(dut, len_signal_name).value = 0
            
            # Wait a bit for inputs to settle
            await Timer(100, units='ns')
            
            # Start computation
            await start_computation(dut)
            
            # Wait for done
            await wait_for_done(dut)
            
            # Read result
            if not is_value_defined(dut.result.value):
                raise TestFailure(f"Result is undefined (X/Z)")
            
            result = int(dut.result.value)
            
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            cocotb.log.info(f"  PASS: result = {result}")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    # Summary
    cocotb.log.info(f"{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")