import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 8
MAX_INPUT_LEN = 16
CLK_PERIOD_NS = 10
MAX_CYCLES = 100

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
    if value < 0:
        return from_signed(max(-((1 << (bits-1))), min((1 << (bits-1)) - 1, value)), bits)
    return min(max_val, max(0, value))

def from_signed(val, bits):
    """Convert signed integer to unsigned for Verilog assignment."""
    if val < 0:
        return val + (1 << bits)
    return val

def to_signed(val, bits):
    """Convert unsigned integer to signed (two's complement)."""
    if val >= (1 << (bits - 1)):
        return val - (1 << bits)
    return val

# ============================================================================
# TEST HELPER FUNCTIONS
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

async def write_array(dut, values, max_len):
    """Write input array elements individually."""
    # Clamp values and write to arr[0..15]
    for i in range(max_len):
        if i < len(values):
            val = clamp_to_width(values[i], DATA_WIDTH)
            dut.arr[i].value = val
        else:
            dut.arr[i].value = 0

async def read_output_and_verify(dut, input_len, expected_groups):
    """Read output and verify against expected groups."""
    
    # Read the output array and out_len
    if not is_value_defined(dut.out_len.value):
        raise TestFailure("out_len is undefined")
    
    out_len_val = int(dut.out_len.value)
    
    # Read raw output data
    raw_output = []
    for i in range(16):
        if is_value_defined(dut.out_arr[i].value):
            raw_output.append(int(dut.out_arr[i].value))
        else:
            raw_output.append(None)
    
    # Parse raw output to reconstruct groups
    # Format: [len1, elem1, elem2, ..., len2, elem1, elem2, ...]
    reconstructed_groups = []
    pos = 0
    
    for group_idx in range(out_len_val):
        if pos >= len(raw_output) or raw_output[pos] is None:
            raise TestFailure(f"Cannot read group {group_idx} length at pos {pos}")
        
        group_len = raw_output[pos]
        pos += 1
        
        if group_len == 0:
            reconstructed_groups.append([])
            continue
        
        if pos + group_len > len(raw_output):
            raise TestFailure(f"Group {group_idx} length {group_len} exceeds available data")
        
        group = []
        for i in range(group_len):
            if raw_output[pos + i] is None:
                raise TestFailure(f"Undefined value in group {group_idx} at index {i}")
            group.append(raw_output[pos + i])
        
        reconstructed_groups.append(group)
        pos += group_len
    
    # Verify against expected
    if len(reconstructed_groups) != len(expected_groups):
        raise TestFailure(f"Group count mismatch: expected {len(expected_groups)}, got {len(reconstructed_groups)}\n  Expected: {expected_groups}\n  Got: {reconstructed_groups}")
    
    for i, (actual, expected) in enumerate(zip(reconstructed_groups, expected_groups)):
        if actual != expected:
            raise TestFailure(f"Group {i} mismatch: expected {expected}, got {actual}")
    
    return reconstructed_groups

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_pack_consecutive_duplicates(dut):
    """Test pack_consecutive_duplicates module."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test cases
    test_cases = [
        {
            'input': [0, 0, 1, 2, 3, 4, 4, 5, 6, 6, 6, 7, 8, 9, 4, 4],
            'expected': [[0, 0], [1], [2], [3], [4, 4], [5], [6, 6, 6], [7], [8], [9], [4, 4]],
            'desc': 'Mixed runs with length 2 and 3'
        },
        {
            'input': [10, 10, 15, 19, 18, 18, 17, 26, 26, 17, 18, 10],
            'expected': [[10, 10], [15], [19], [18, 18], [17], [26, 26], [17], [18], [10]],
            'desc': 'Values with max run length 2'
        },
        {
            'input': [97, 97, 98, 99, 100, 100],  # ASCII for 'a', 'a', 'b', 'c', 'd', 'd'
            'expected': [[97, 97], [98], [99], [100, 100]],
            'desc': 'Character values (ASCII)'
        }
    ]
    
    passed = 0
    failed = 0
    
    for i, test in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {test['desc']}")
        cocotb.log.info(f"  Input: {test['input']}")
        
        try:
            # Write input array
            await write_array(dut, test['input'], MAX_INPUT_LEN)
            
            # Set input length
            dut.input_len.value = len(test['input'])
            
            # Start computation
            await start_computation(dut)
            
            # Wait for done
            await wait_for_done(dut)
            
            # Check for error
            if is_value_defined(dut.error.value) and int(dut.error.value) == 1:
                raise TestFailure("Error flag asserted")
            
            # Read and verify output
            result = await read_output_and_verify(dut, len(test['input']), test['expected'])
            
            cocotb.log.info(f"  Expected: {test['expected']}")
            cocotb.log.info(f"  Got:      {result}")
            cocotb.log.info(f"  Result: PASS")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    # Summary
    cocotb.log.info(f"{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")