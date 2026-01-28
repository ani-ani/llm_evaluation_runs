import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
CHAR_WIDTH = 2
MAX_STRING_LEN = 8
NUM_FOSSILS = 8
DATA_WIDTH = CHAR_WIDTH * MAX_STRING_LEN
INDEX_WIDTH = 3
CLK_PERIOD_NS = 10
MAX_CYCLES = 50000  # Allow sufficient time for all 256 assignments

# Character encoding
CHAR_MAP = {'A': 0, 'C': 1, 'M': 2}

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
    """Clamp value to fit within specified bit width."""
    max_val = (1 << bits) - 1
    return min(max_val, max(0, value))

def string_to_packed(string, max_len=MAX_STRING_LEN, char_width=CHAR_WIDTH):
    """Convert string to packed integer representation."""
    result = 0
    for i, char in enumerate(string[:max_len]):
        code = CHAR_MAP.get(char, 0)
        result |= code << (i * char_width)
    return result

def get_length(string, max_len=MAX_STRING_LEN):
    """Get actual length of string (up to max_len)."""
    return min(len(string), max_len)

# ============================================================================
# ARRAY ACCESS HELPERS
# ============================================================================

async def write_array(dut, array_name, values, element_width):
    """Write values to array, handling 2D array interface."""
    try:
        arr = getattr(dut, array_name)
        for i, val in enumerate(values):
            arr[i].value = clamp_to_width(val, element_width)
        return
    except (AttributeError, TypeError) as e:
        raise TestFailure(f"Cannot access {array_name}: {e}")

async def write_fossil_strings(dut, strings):
    """Write fossil strings to DUT."""
    packed_values = [string_to_packed(s) for s in strings]
    await write_array(dut, 'fossils', packed_values, DATA_WIDTH)

async def write_fossil_lengths(dut, strings):
    """Write fossil lengths to DUT."""
    lengths = [get_length(s) for s in strings]
    await write_array(dut, 'fossil_lengths', lengths, INDEX_WIDTH)

async def read_assignment(dut):
    """Read the assignment vector from DUT."""
    if not is_value_defined(dut.assignment.value):
        raise TestFailure("Assignment signal is undefined")
    return int(dut.assignment.value)

# ============================================================================
# SEQUENTIAL MODULE HELPERS
# ============================================================================

async def reset_dut(dut, cycles=2):
    """Reset the DUT."""
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
# VERIFICATION FUNCTIONS
# ============================================================================

def is_subsequence(sub, sup, sub_len, sup_len):
    """Check if sub is subsequence of sup (Python reference)."""
    if sub_len > sup_len:
        return False
    i = 0
    for j in range(sup_len):
        if i < sub_len and sub[i] == sup[j]:
            i += 1
    return i == sub_len

def check_chain(fossils, lengths, assignment, chain_bit, current_species, current_len):
    """Check if a chain is valid (Python reference)."""
    chain_indices = [i for i in range(NUM_FOSSILS) if ((assignment >> i) & 1) == chain_bit]
    
    if not chain_indices:
        # Empty chain is valid if we consider the current species as the final step
        return True
    
    # Sort by length
    sorted_chain = sorted(chain_indices, key=lambda i: lengths[i])
    
    # Check each consecutive pair
    for k in range(len(sorted_chain) - 1):
        i, j = sorted_chain[k], sorted_chain[k + 1]
        if lengths[i] >= lengths[j]:
            return False  # Should not happen due to sorting
        # Check if fossils[i] is subsequence of fossils[j]
        if not is_subsequence(fossils[i], fossils[j], lengths[i], lengths[j]):
            return False
    
    # Check last fossil vs current species
    last_idx = sorted_chain[-1]
    if not is_subsequence(fossils[last_idx], current_species, lengths[last_idx], current_len):
        return False
    
    return True

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_evolutionary_paths(dut):
    """Test the EvolutionaryPaths module."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test cases: (current_species, fossil_strings, description, expected_possible)
    test_cases = [
        (
            "AACCMMAA",
            ["ACA", "MM", "ACMAA", "AA", "A"],
            "Sample 1: Should be possible",
            True
        ),
        (
            "ACMA",
            ["ACM", "ACA", "AMA"],
            "Sample 2: Should be impossible",
            False
        ),
        (
            "AM",
            ["MA"],
            "Sample 3: Should be impossible",
            False
        ),
        (
            "AAAAAA",
            ["AA", "AAA", "A", "AAAAA"],
            "Sample 4: Should be possible (empty chain1)",
            True
        ),
    ]
    
    for i, (current_str, fossils_str, description, expected_possible) in enumerate(test_cases):
        cocotb.log.info(f"\nTest {i+1}: {description}")
        
        # Prepare inputs
        current_packed = string_to_packed(current_str)
        current_len = get_length(current_str)
        
        # Write to DUT
        dut.current_species.value = current_packed
        dut.current_length.value = current_len
        await write_fossil_strings(dut, fossils_str)
        await write_fossil_lengths(dut, fossils_str)
        
        # Start computation
        await start_computation(dut)
        await wait_for_done(dut)
        
        # Read results
        possible = int(dut.possible.value) if is_value_defined(dut.possible.value) else 0
        assignment = await read_assignment(dut) if possible else 0
        
        # Verify
        if possible != expected_possible:
            raise TestFailure(f"Test {i+1}: Expected possible={expected_possible}, got {possible}")
        
        if possible:
            # Verify the assignment actually works
            fossils_packed = [string_to_packed(s) for s in fossils_str]
            fossils_len = [get_length(s) for s in fossils_str]
            
            # Unpack fossils for subsequence checking
            def unpack_fossil(packed):
                chars = []
                for j in range(MAX_STRING_LEN):
                    char_val = (packed >> (j * CHAR_WIDTH)) & ((1 << CHAR_WIDTH) - 1)
                    if char_val == 0:
                        chars.append('A')
                    elif char_val == 1:
                        chars.append('C')
                    elif char_val == 2:
                        chars.append('M')
                    else:
                        chars.append('?')
                return chars
            
            current_unpacked = unpack_fossil(current_packed)[:current_len]
            fossils_unpacked = [unpack_fossil(p)[:l] for p, l in zip(fossils_packed, fossils_len)]
            
            # Check both chains
            chain0_valid = check_chain(fossils_unpacked, fossils_len, assignment, 0, current_unpacked, current_len)
            chain1_valid = check_chain(fossils_unpacked, fossils_len, assignment, 1, current_unpacked, current_len)
            
            if not (chain0_valid and chain1_valid):
                raise TestFailure(f"Test {i+1}: Assignment {assignment:08b} is invalid")
            
            cocotb.log.info(f"  PASS: possible=1, assignment={assignment:08b}")
        else:
            cocotb.log.info(f"  PASS: possible=0 (impossible)")
    
    cocotb.log.info(f"\n{'='*50}")
    cocotb.log.info("All tests passed!")
