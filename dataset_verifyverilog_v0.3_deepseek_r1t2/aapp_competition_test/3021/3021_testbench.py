import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION - Match HDL parameters
# ============================================================================
ALPHABET_SIZE = 5
MAX_WORDS = 4
MAX_WORD_LEN = 8
CLK_PERIOD_NS = 10
MAX_CYCLES = 1000

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
    return min(max_val, max(0, value))

# ============================================================================
# ARRAY ACCESS HELPERS
# ============================================================================

async def write_words(dut, words_list, lengths_list):
    """Write words to DUT interface, handling 3D array access."""
    # words is 3D: [word_index][char_index][7:0]
    for i, word in enumerate(words_list):
        for j, char in enumerate(word):
            dut.words[i][j].value = ord(char)
        # Set unused characters to 0
        for j in range(len(word), MAX_WORD_LEN):
            dut.words[i][j].value = 0
        # Set length
        dut.word_lengths[i].value = len(word)
    # Set unused words to zero
    for i in range(len(words_list), MAX_WORDS):
        for j in range(MAX_WORD_LEN):
            dut.words[i][j].value = 0
        dut.word_lengths[i].value = 0

async def read_result(dut):
    """Read result order from DUT output."""
    result = []
    for i in range(ALPHABET_SIZE):
        if is_value_defined(dut.result_order[i].value):
            char_code = int(dut.result_order[i].value)
            if char_code != 0:
                result.append(chr(char_code))
            else:
                result.append('?')  # Placeholder for unconstrained
        else:
            result.append('?')
    return ''.join(result)

async def read_status(dut):
    """Read status and convert to string."""
    if not is_value_defined(dut.status.value):
        return "UNDEFINED"
    status_val = int(dut.status.value)
    if status_val == 0:
        return "IMPOSSIBLE"
    elif status_val == 1:
        return "AMBIGUOUS"
    elif status_val == 2:
        return "UNIQUE"
    else:
        return f"UNKNOWN({status_val})"

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
async def test_alphabet_solver(dut):
    """Main test function for AlphabetSolver."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test cases: (words_list, expected_status, expected_order_or_none)
    # Note: For AMBIGUOUS and IMPOSSIBLE, expected_order_or_none is ignored
    test_cases = [
        # Test 1: Unique order
        (
            ["ab", "bc", "cd", "de"],
            "UNIQUE",
            "abcde"
        ),
        # Test 2: Multiple orders (ambiguity due to unconstrained letters)
        (
            ["ab", "ac", "ad", "ae"],
            "AMBIGUOUS",
            None
        ),
        # Test 3: Cycle (impossible)
        (
            ["ab", "bc", "ca"],
            "IMPOSSIBLE",
            None
        ),
        # Test 4: Prefix violation (impossible)
        (
            ["abc", "ab"],
            "IMPOSSIBLE",
            None
        ),
    ]
    
    passed = 0
    failed = 0
    
    for i, (words_list, expected_status, expected_order) in enumerate(test_cases):
        dut._log.info(f"\nTest {i+1}: {words_list}")
        
        # Write inputs
        await write_words(dut, words_list, [len(w) for w in words_list])
        dut.N.value = len(words_list)
        
        # Start computation
        await start_computation(dut)
        
        # Wait for done
        try:
            await wait_for_done(dut)
        except TestFailure as e:
            dut._log.error(f"  FAIL: {e}")
            failed += 1
            continue
        
        # Read results
        status = await read_status(dut)
        
        if status != expected_status:
            dut._log.error(f"  FAIL: Expected status {expected_status}, got {status}")
            failed += 1
            continue
        
        if expected_status == "UNIQUE":
            result_order = await read_result(dut)
            # The result_order may contain '?' for unconstrained letters, but we expect exact order
            # Remove '?' for comparison (they shouldn't appear in unique case if all letters constrained)
            clean_result = result_order.replace('?', '')
            if clean_result != expected_order:
                dut._log.error(f"  FAIL: Expected order {expected_order}, got {clean_result}")
                failed += 1
                continue
            dut._log.info(f"  PASS: Status={status}, Order={result_order}")
        else:
            dut._log.info(f"  PASS: Status={status}")
        
        passed += 1
        
        # Reset for next test
        await reset_dut(dut)
    
    # Summary
    dut._log.info(f"\n{'='*50}")
    dut._log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")