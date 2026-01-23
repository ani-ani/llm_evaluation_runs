import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 20
GRID_SIZE = 8
MSG_LEN = 8
DECIMAL_DIGITS = 6  # per sum
CLK_PERIOD_NS = 10
MAX_CYCLES = 2000

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
    """Clamp value to fit within specified bit width."""
    max_val = (1 << bits) - 1
    if value < 0:
        return from_signed(max(-((1 << (bits-1))), min((1 << (bits-1)) - 1, value)), bits)
    return min(max_val, max(0, value))

# ============================================================================
# CHARACTER CONVERSION
# ============================================================================

def char_to_val(c):
    """Convert character to 0-26 value."""
    if c == ' ':
        return 26
    return ord(c) - ord('A')

def val_to_char(v):
    """Convert 0-26 value to character."""
    if v == 26:
        return ' '
    return chr(ord('A') + v)

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
# ARRAY ACCESS HELPERS
# ============================================================================

async def write_message(dut, message):
    """Write encrypted message to DUT."""
    for i in range(MSG_LEN):
        if i < len(message):
            val = char_to_val(message[i])
        else:
            val = 26  # space
        
        # Try individual port first, then array
        if has_signal(dut, f'encrypted_msg_{i}'):
            getattr(dut, f'encrypted_msg_{i}').value = clamp_to_width(val, 5)
        elif hasattr(dut, 'encrypted_msg'):
            dut.encrypted_msg[i].value = clamp_to_width(val, 5)
        else:
            raise TestFailure(f"Cannot find encrypted_msg port for index {i}")

async def read_decrypted_message(dut):
    """Read decrypted message from DUT."""
    result = []
    for i in range(MSG_LEN):
        if has_signal(dut, f'decrypted_msg_{i}'):
            val = getattr(dut, f'decrypted_msg_{i}').value
        elif hasattr(dut, 'decrypted_msg'):
            val = dut.decrypted_msg[i].value
        else:
            raise TestFailure(f"Cannot find decrypted_msg port for index {i}")
        
        if is_value_defined(val):
            result.append(val_to_char(int(val)))
        else:
            result.append('?')
    return ''.join(result)

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_martian_decryption(dut):
    """Test the Martian decryption module."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test cases: (encrypted_message, expected_output)
    test_cases = [
        ("JQ IRKEYFG EXQ", "THIS IS A TEST"),
        ("BLNAMOTP", "FRIENDS"),  # Scaled down from second example
    ]
    
    for test_num, (encrypted, expected) in enumerate(test_cases):
        cocotb.log.info(f"Test {test_num+1}: '{encrypted}' -> '{expected}'")
        
        # Write encrypted message
        await write_message(dut, encrypted)
        
        # Start computation
        await start_computation(dut)
        
        # Wait for done
        await wait_for_done(dut, max_cycles=MAX_CYCLES)
        
        # Read decrypted message
        result = await read_decrypted_message(dut)
        
        cocotb.log.info(f"  Result: '{result}'")
        
        # Verify (only check first len(encrypted) characters)
        if result[:len(encrypted)] != expected[:len(encrypted)]:
            raise TestFailure(f"Test {test_num+1} failed: expected '{expected[:len(encrypted)]}', got '{result[:len(encrypted)]}'")
        
        cocotb.log.info(f"  PASS")
        
        # Wait before next test
        await RisingEdge(dut.clk)
    
    cocotb.log.info("All tests passed!")

# ============================================================================
# ADDITIONAL TESTS FOR EDGE CASES
# ============================================================================

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_edge_cases(dut):
    """Test edge cases."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test case: all spaces
    cocotb.log.info("Test: All spaces")
    await write_message(dut, "        ")
    await start_computation(dut)
    await wait_for_done(dut)
    result = await read_decrypted_message(dut)
    cocotb.log.info(f"  Result: '{result}'")
    
    # Test case: mixed
    cocotb.log.info("Test: Mixed characters")
    await write_message(dut, "ABCDEFGH")
    await start_computation(dut)
    await wait_for_done(dut)
    result = await read_decrypted_message(dut)
    cocotb.log.info(f"  Result: '{result}'")
    
    cocotb.log.info("Edge case tests completed.")

# ============================================================================
# TESTBENCH TEMPLATE FOR COMBINATIONAL VERSION (IF APPLICABLE)
# ============================================================================

async def wait_for_combinational(dut, timeout_ns=100000):
    """Wait for combinational logic to settle."""
    elapsed = 0
    check_interval = 100
    
    while elapsed < timeout_ns:
        await Timer(check_interval, units='ns')
        elapsed += check_interval
        
        # Check if output is valid
        if is_value_defined(dut.decrypted_msg_0.value):
            return True
    
    raise TestFailure(f"Output not valid after {timeout_ns}ns")

@cocotb.test(timeout_time=2000, timeout_unit="ms")
async def test_combinational_variant(dut):
    """Test if module works without clock (combinational variant)."""
    
    # Check if clock exists
    if has_signal(dut, 'clk'):
        cocotb.log.info("Module has clock - testing sequential version")
        return
    
    # Write inputs
    await write_message(dut, "TEST")
    
    # Wait for propagation
    await wait_for_combinational(dut)
    
    # Read result
    result = await read_decrypted_message(dut)
    cocotb.log.info(f"Combinational result: '{result}'")
    
    # Just verify we got defined results
    for i in range(MSG_LEN):
        if not is_value_defined(getattr(dut, f'decrypted_msg_{i}').value):
            raise TestFailure(f"Output {i} is undefined")
    
    cocotb.log.info("Combinational test passed.")