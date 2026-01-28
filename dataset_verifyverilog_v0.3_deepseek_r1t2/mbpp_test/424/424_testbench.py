import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 8
STRING_LENGTH = 8
NUM_STRINGS = 3
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

def has_signal(dut, name):
    """Check if DUT has a signal with given name."""
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def pack_string(s):
    """Pack a string (max 8 chars) into a 64-bit value, LSB = first char."""
    packed = 0
    for i, c in enumerate(s[:STRING_LENGTH]):
        packed |= (ord(c) & 0xFF) << (i * 8)
    return packed

def get_rear_char(s):
    """Get the last character of a string."""
    return ord(s[-1]) if s else 0

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

async def write_string_input(dut, str_idx, packed_value, length):
    """Write a packed string and its length to the DUT."""
    # Determine port names based on str_idx
    if str_idx == 0:
        dut.str_0.value = packed_value
        dut.len_0.value = length
    elif str_idx == 1:
        dut.str_1.value = packed_value
        dut.len_1.value = length
    elif str_idx == 2:
        dut.str_2.value = packed_value
        dut.len_2.value = length
    else:
        raise TestFailure(f"Invalid string index: {str_idx}")

async def read_result(dut):
    """Read the result characters from DUT."""
    results = []
    for i in range(NUM_STRINGS):
        port_name = f'result_{i}'
        if has_signal(dut, port_name):
            val = getattr(dut, port_name).value
            if is_value_defined(val):
                results.append(int(val))
            else:
                results.append(None)
        else:
            results.append(None)
    return results

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_extract_rear(dut):
    """Test extracting rear characters from three strings."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test cases: (input_strings, expected_rear_chars, description)
    test_cases = [
        (["Mers", "for", "Vers"], [ord('s'), ord('r'), ord('s')], "Test 1: Mers,for,Vers"),
        (["Avenge", "for", "People"], [ord('e'), ord('r'), ord('e')], "Test 2: Avenge,for,People"),
        (["Gotta", "get", "go"], [ord('a'), ord('t'), ord('o')], "Test 3: Gotta,get,go"),
    ]
    
    passed = 0
    failed = 0
    
    for test_num, (input_strings, expected, description) in enumerate(test_cases, 1):
        cocotb.log.info(f"\nTest {test_num}: {description}")
        
        try:
            # Pack strings and write inputs
            for i, s in enumerate(input_strings):
                packed = pack_string(s)
                length = len(s)
                await write_string_input(dut, i, packed, length)
                cocotb.log.info(f"  String {i}: '{s}' -> packed=0x{packed:016X}, len={length}")
            
            # Start computation
            await start_computation(dut)
            
            # Wait for completion
            await wait_for_done(dut)
            
            # Read results
            results = await read_result(dut)
            
            # Verify results
            for i, (actual, exp) in enumerate(zip(results, expected)):
                if actual is None:
                    raise TestFailure(f"Result {i} is undefined (X/Z)")
                if actual != exp:
                    raise TestFailure(f"Result {i}: expected {chr(exp) if exp >= 32 else '?'} ({exp}), got {chr(actual) if actual >= 32 else '?'} ({actual})")
                cocotb.log.info(f"  Result {i}: '{chr(actual)}' (0x{actual:02X}) [PASS]")
            
            cocotb.log.info(f"  Test {test_num}: PASS")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  Test {test_num}: FAIL - {e}")
            failed += 1
    
    # Summary
    cocotb.log.info(f"\n{'='*60}")
    cocotb.log.info(f"SUMMARY: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} test(s) failed")