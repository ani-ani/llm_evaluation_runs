import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 8
MAX_SUBLISTS = 8
MAX_SUBLIST_LEN = 8
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
    """Clamp value to fit within specified bit width."""
    max_val = (1 << bits) - 1
    if value < 0:
        return from_signed(max(-((1 << (bits-1))), min((1 << (bits-1)) - 1, value)), bits)
    return min(max_val, max(0, value))

# ============================================================================
# ARRAY WRITE HELPER
# ============================================================================

def write_2d_array(dut, sublist_idx, values, element_width):
    """Write a single sublist to the DUT."""
    for i, val in enumerate(values):
        port_name = f"arr_{sublist_idx}_{i}"
        if has_signal(dut, port_name):
            getattr(dut, port_name).value = clamp_to_width(val, element_width)
        else:
            raise TestFailure(f"Port {port_name} not found")

def write_lengths(dut, lengths):
    """Write sublist lengths."""
    for i, length in enumerate(lengths):
        port_name = f"len_{i}"
        if has_signal(dut, port_name):
            getattr(dut, port_name).value = clamp_to_width(length, 4)
        else:
            raise TestFailure(f"Port {port_name} not found")

# ============================================================================
# SEQUENTIAL HELPERS
# ============================================================================

async def reset_dut(dut):
    """Reset the DUT."""
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(2):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut):
    """Wait for done signal."""
    for cycle in range(MAX_CYCLES):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout: done not asserted")

async def start_computation(dut):
    """Pulse start signal."""
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

# ============================================================================
# READ RESULT
# ============================================================================

def read_result(dut):
    """Read max_len and max_list from DUT."""
    if not is_value_defined(dut.max_len.value):
        raise TestFailure("max_len is undefined")
    
    max_len = int(dut.max_len.value)
    max_list = []
    
    for i in range(MAX_SUBLIST_LEN):
        port_name = f"max_list_{i}"
        if has_signal(dut, port_name):
            val = getattr(dut, port_name).value
            if is_value_defined(val):
                max_list.append(int(val))
            else:
                max_list.append(None)
        else:
            max_list.append(None)
    
    return max_len, max_list

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_max_length(dut):
    """Test max_length module."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test cases: (sublists_data, lengths, expected_len, expected_list)
    # Each sublist has max 8 elements
    test_cases = [
        (
            [[0], [1, 3], [5, 7], [9, 11], [13, 15, 17]],
            [1, 2, 2, 2, 3],
            3,
            [13, 15, 17]
        ),
        (
            [[1], [5, 7], [10, 12, 14, 15]],
            [1, 2, 4],
            4,
            [10, 12, 14, 15]
        ),
        (
            [[5], [15, 20, 25]],
            [1, 3],
            3,
            [15, 20, 25]
        )
    ]
    
    passed = 0
    failed = 0
    
    for test_idx, (sublists, lengths, expected_len, expected_list) in enumerate(test_cases):
        cocotb.log.info(f"\nTest {test_idx + 1}: sublists={sublists}")
        
        try:
            # Pad sublists to 8 elements, zero-pad to 8
            padded_sublists = []
            for sl in sublists:
                padded = sl + [0] * (8 - len(sl))
                padded_sublists.append(padded[:8])
            
            # Pad to 8 sublists
            while len(padded_sublists) < 8:
                padded_sublists.append([0] * 8)
                lengths.append(0)
            
            # Write all sublists
            for i, sublist in enumerate(padded_sublists):
                write_2d_array(dut, i, sublist, DATA_WIDTH)
            
            # Write lengths
            write_lengths(dut, lengths)
            
            # Start computation
            await start_computation(dut)
            
            # Wait for done
            await wait_for_done(dut)
            
            # Read result
            result_len, result_list = read_result(dut)
            
            # Build expected padded list
            expected_padded = expected_list + [0] * (8 - len(expected_list))
            
            # Verify
            if result_len != expected_len:
                raise TestFailure(f"Length mismatch: expected {expected_len}, got {result_len}")
            
            for i in range(len(expected_padded)):
                if result_list[i] != expected_padded[i]:
                    raise TestFailure(f"Element {i} mismatch: expected {expected_padded[i]}, got {result_list[i]}")
            
            cocotb.log.info(f"  PASS: max_len={result_len}, max_list={result_list[:expected_len]}")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    cocotb.log.info(f"\n{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")
