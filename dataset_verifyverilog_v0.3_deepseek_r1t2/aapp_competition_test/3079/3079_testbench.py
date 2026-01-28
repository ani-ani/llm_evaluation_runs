import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 8
N = 8
HALF_N = 4
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
# ARRAY ACCESS HELPERS
# ============================================================================

async def write_letters(dut, letters):
    """Write N letters to arr_0..arr_7."""
    for i in range(N):
        port_name = f'arr_{i}'
        if has_signal(dut, port_name):
            # ASCII code of the letter
            ascii_val = ord(letters[i])
            getattr(dut, port_name).value = ascii_val
        else:
            raise TestFailure(f"Signal {port_name} not found")

async def read_word(dut):
    """Read Slavko's word from word_0..word_3."""
    word = []
    for i in range(HALF_N):
        port_name = f'word_{i}'
        if has_signal(dut, port_name):
            val = getattr(dut, port_name).value
            if is_value_defined(val):
                word.append(chr(int(val)))
            else:
                word.append('?')
        else:
            raise TestFailure(f"Signal {port_name} not found")
    return ''.join(word)

async def read_win(dut):
    """Read win signal."""
    if has_signal(dut, 'win'):
        if is_value_defined(dut.win.value):
            return int(dut.win.value) == 1
        else:
            return False
    else:
        raise TestFailure("Signal win not found")

# ============================================================================
# SEQUENTIAL MODULE HELPERS
# ============================================================================

async def reset_dut(dut):
    """Reset the DUT (active-low reset)."""
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(2):
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
async def test_word_game(dut):
    """Main test for WordGame module."""
    
    # Detect if sequential
    is_sequential = has_signal(dut, 'clk') and has_signal(dut, 'done')
    
    if is_sequential:
        # Start clock
        cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
        # Reset
        await reset_dut(dut)
    
    # Define test cases: (input_string, expected_win, expected_word)
    test_cases = [
        ("ne", False, "n"),   # Sample 1: "n" is the only word, Mirko "e", Slavko loses
        ("kava", True, "ak"), # Sample 2
        ("cokolada", True, "acko"), # Sample 3: N=8, word length 4
    ]
    
    passed = 0
    failed = 0
    
    for i, (input_str, exp_win, exp_word) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: input='{input_str}', expected win={exp_win}, word='{exp_word}'")
        
        try:
            # Write inputs
            await write_letters(dut, input_str)
            
            if is_sequential:
                # Start computation
                await start_computation(dut)
                # Wait for done
                await wait_for_done(dut)
            else:
                # Combinational - wait for propagation
                await Timer(100, units='ns')
            
            # Read outputs
            win = await read_win(dut)
            word = await read_word(dut)
            
            # Verify win
            if win != exp_win:
                raise TestFailure(f"Win mismatch: expected {exp_win}, got {win}")
            
            # Verify word
            if word != exp_word:
                raise TestFailure(f"Word mismatch: expected '{exp_word}', got '{word}'")
            
            cocotb.log.info(f"  PASS: win={win}, word='{word}'")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    # Summary
    cocotb.log.info(f"{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")
