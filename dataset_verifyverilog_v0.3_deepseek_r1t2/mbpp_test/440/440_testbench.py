import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 8
MAX_SENTENCE_LEN = 256
MAX_ADVERB_LEN = 16
CLK_PERIOD_NS = 10
MAX_CYCLES = 300

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
    if has_signal(dut, 'char_valid'):
        dut.char_valid.value = 0
    if has_signal(dut, 'sentence_end'):
        dut.sentence_end.value = 0
    
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

async def feed_sentence(dut, sentence):
    """Feed sentence characters one per cycle."""
    # Convert string to ASCII codes
    chars = [ord(c) for c in sentence]
    
    for i, ascii_val in enumerate(chars):
        dut.char_in.value = ascii_val
        dut.char_valid.value = 1
        dut.sentence_end.value = 0
        await RisingEdge(dut.clk)
    
    # Signal end of sentence
    dut.char_valid.value = 0
    dut.sentence_end.value = 1
    await RisingEdge(dut.clk)
    dut.sentence_end.value = 0

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_adverb_finder(dut):
    """Test the adverb position finder module."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test cases: (sentence, expected_start, expected_end, expected_adverb)
    test_cases = [
        ("clearly!! we can see the sky", 0, 7, "clearly"),
        ("seriously!! there are many roses", 0, 9, "seriously"),
        ("unfortunately!! sita is going to home", 0, 13, "unfortunately"),
        ("we clearly see", 3, 10, "clearly"),
        ("no adverbs here", None, None, None),
        ("quickly running fast", 0, 8, "quickly"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (sentence, exp_start, exp_end, exp_adverb) in enumerate(test_cases):
        cocotb.log.info(f"\nTest {i+1}: Sentence = '{sentence}'")
        
        try:
            # Start computation
            await start_computation(dut)
            
            # Feed sentence
            await feed_sentence(dut, sentence)
            
            # Wait for completion
            await wait_for_done(dut)
            
            # Read results
            found = safe_int(dut.found.value)
            
            if exp_adverb is None:
                # Expected: no adverb found
                if found != 0:
                    raise TestFailure(f"Expected no adverb, but found={found}")
                
                # Check error flag if exists
                if has_signal(dut, 'error'):
                    error = safe_int(dut.error.value)
                    if error != 1:
                        raise TestFailure(f"Expected error=1, got {error}")
                
                cocotb.log.info(f"  PASS: No adverb found (as expected)")
            else:
                # Expected: adverb found
                if found != 1:
                    raise TestFailure(f"Expected found=1, got {found}")
                
                start_pos = safe_int(dut.start_pos.value)
                end_pos = safe_int(dut.end_pos.value)
                
                if start_pos != exp_start:
                    raise TestFailure(f"Start pos: expected {exp_start}, got {start_pos}")
                
                if end_pos != exp_end:
                    raise TestFailure(f"End pos: expected {exp_end}, got {end_pos}")
                
                # Read adverb buffer
                adverb_chars = []
                for j in range(MAX_ADVERB_LEN):
                    char_sig = getattr(dut, f'adverb_{j}', None)
                    if char_sig is None:
                        char_sig = getattr(dut, 'adverb')[j] if hasattr(dut, 'adverb') else None
                    
                    if char_sig is not None and is_value_defined(char_sig.value):
                        val = int(char_sig.value)
                        if val != 0:
                            adverb_chars.append(chr(val))
                        else:
                            break
                    else:
                        break
                
                adverb_str = ''.join(adverb_chars)
                
                if adverb_str != exp_adverb:
                    raise TestFailure(f"Adverb: expected '{exp_adverb}', got '{adverb_str}'")
                
                cocotb.log.info(f"  PASS: '{adverb_str}' at [{start_pos}:{end_pos}]")
            
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
            # Reset before next test
            await reset_dut(dut)
    
    # Summary
    cocotb.log.info(f"\n{'='*60}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")