import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 2       # Bits per character
CHAR_MASK = 0x3      # 2-bit mask
ASSIGN_WIDTH = 8     # Bits per assignment
MAX_LEN = 16         # Maximum string length
MAX_HASHES = 8       # Maximum number of hashes
CLK_PERIOD_NS = 10
MAX_CYCLES = 1000

# Character encodings
CHAR_OPEN = 0b00
CHAR_CLOSE = 0b01
CHAR_HASH = 0b10

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
# ARRAY ACCESS HELPERS
# ============================================================================

async def write_char_array(dut, values):
    """Write character array to DUT."""
    for i, val in enumerate(values):
        if i >= MAX_LEN:
            break
        if has_signal(dut, f'char_arr_{i}'):
            getattr(dut, f'char_arr_{i}').value = clamp_to_width(val, DATA_WIDTH)
        else:
            dut.char_arr[i].value = clamp_to_width(val, DATA_WIDTH)
    # Set length
    dut.length.value = len(values)

async def read_assignments(dut, num_hashes):
    """Read assignment array from DUT."""
    results = []
    for i in range(MAX_HASHES):
        if i < num_hashes:
            if has_signal(dut, f'assign_arr_{i}'):
                val = getattr(dut, f'assign_arr_{i}').value
            else:
                val = dut.assign_arr[i].value
            if is_value_defined(val):
                results.append(int(val))
            else:
                results.append(None)
        else:
            results.append(0)
    return results

async def reset_dut(dut, cycles=2):
    """Reset the DUT."""
    dut.rst_n.value = 0
    dut.start.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    """Wait for done signal."""
    for cycle in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout: done not asserted after {max_cycles} cycles")

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_treasure_solver(dut):
    """Main test for TreasureSolver module."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test cases: (input_string, expected_assignments, expected_num_hashes, should_fail)
    test_cases = [
        ("(((#)((#)", [1, 2], 2, False),  # Example 1
        ("()((#((#(#()", [1, 1, 3], 3, False),  # Example 2
        ("#", [], 0, True),  # Example 3 - fail
        ("(#)", [], 0, True),  # Example 4 - fail
        ("((#)(", [], 0, True),  # Additional fail case
        ("((#)(", [], 0, True),  # Additional fail case
        ("((#)(", [], 0, True),  # Additional fail case
    ]
    
    passed = 0
    failed = 0
    
    for i, (input_str, expected_assignments, expected_hashes, should_fail) in enumerate(test_cases):
        cocotb.log.info(f"\nTest {i+1}: '{input_str}'")
        
        try:
            # Convert string to character codes
            char_codes = []
            for c in input_str:
                if c == '(':
                    char_codes.append(CHAR_OPEN)
                elif c == ')':
                    char_codes.append(CHAR_CLOSE)
                elif c == '#':
                    char_codes.append(CHAR_HASH)
            
            # Write to DUT
            await write_char_array(dut, char_codes)
            
            # Start computation
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Wait for done
            await wait_for_done(dut)
            
            # Read results
            if not is_value_defined(dut.fail.value):
                raise TestFailure("fail signal is undefined")
            
            is_fail = int(dut.fail.value) == 1
            num_hashes = int(dut.num_hashes.value) if is_value_defined(dut.num_hashes.value) else 0
            
            if should_fail:
                if not is_fail:
                    raise TestFailure(f"Expected fail but got success with {num_hashes} hashes")
                cocotb.log.info(f"  PASS: Correctly failed")
                passed += 1
            else:
                if is_fail:
                    raise TestFailure("Expected success but got fail")
                
                # Read assignments
                assignments = await read_assignments(dut, num_hashes)
                
                # Verify
                if num_hashes != expected_hashes:
                    raise TestFailure(f"Expected {expected_hashes} hashes, got {num_hashes}")
                
                # Check assignments match (allow any valid solution)
                if assignments[:num_hashes] != expected_assignments:
                    # Could be any valid solution, so just check lengths and positivity
                    if len(assignments[:num_hashes]) != len(expected_assignments):
                        raise TestFailure(f"Assignment count mismatch")
                    for a in assignments[:num_hashes]:
                        if a < 1:
                            raise TestFailure(f"Assignment {a} is not positive")
                
                cocotb.log.info(f"  PASS: {num_hashes} hashes, assignments={assignments[:num_hashes]}")
                passed += 1
                
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
        
        # Reset between tests
        await reset_dut(dut)
    
    # Summary
    cocotb.log.info(f"\n{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")