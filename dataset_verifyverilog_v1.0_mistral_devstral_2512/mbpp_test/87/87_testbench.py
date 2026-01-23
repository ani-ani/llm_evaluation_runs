import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 8
KEY_WIDTH = 8
VAL_WIDTH = 8
ARRAY_SIZE = 8
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
    """Clamp value to fit within specified bit width."""
    max_val = (1 << bits) - 1
    return min(max_val, max(0, value))

# ============================================================================
# ARRAY ACCESS HELPERS
# ============================================================================

async def write_dict(dut, dict_prefix, key_vals):
    """Write dictionary to DUT (dict1, dict2, or dict3)."""
    valid_mask = 0
    max_len = min(len(key_vals), 8)
    
    # Set valid mask
    for i in range(max_len):
        valid_mask |= (1 << i)
    
    valid_sig = getattr(dut, f"{dict_prefix}_valid")
    valid_sig.value = valid_mask
    
    # Write keys and values
    keys_array = getattr(dut, f"{dict_prefix}_keys")
    vals_array = getattr(dut, f"{dict_prefix}_vals")
    
    for i in range(max_len):
        key, val = key_vals[i]
        keys_array[i].value = ord(key[0]) if isinstance(key, str) and len(key) > 0 else 0
        vals_array[i].value = ord(val[0]) if isinstance(val, str) and len(val) > 0 else 0
    
    # Zero out remaining entries
    for i in range(max_len, 8):
        keys_array[i].value = 0
        vals_array[i].value = 0

async def read_merged_result(dut):
    """Read merged dictionary result."""
    keys = []
    vals = []
    
    count = int(dut.out_count.value)
    overflow = int(dut.overflow.value)
    
    for i in range(8):
        if i < count:
            key_char = chr(int(dut.out_keys[i].value))
            val_char = chr(int(dut.out_vals[i].value))
            keys.append(key_char)
            vals.append(val_char)
        else:
            keys.append(None)
            vals.append(None)
    
    return keys, vals, count, overflow

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
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_merge_three_dictionaries(dut):
    """Test merging three dictionaries with priority resolution."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Helper to convert dict to list of key-value tuples
    def dict_to_list(d):
        return [(k, v) for k, v in d.items()]
    
    # Test cases: (dict1, dict2, dict3, expected_merged_dict)
    test_cases = [
        (
            {"R": "Red", "B": "Black", "P": "Pink"},
            {"G": "Green", "W": "White"},
            {"O": "Orange", "W": "White", "B": "Black"},
            {"B": "Black", "R": "Red", "P": "Pink", "G": "Green", "W": "White", "O": "Orange"}
        ),
        (
            {"R": "Red", "B": "Black", "P": "Pink"},
            {"G": "Green", "W": "White"},
            {"L": "lavender", "B": "Blue"},
            {"W": "White", "P": "Pink", "B": "Black", "R": "Red", "G": "Green", "L": "lavender"}
        ),
        (
            {"R": "Red", "B": "Black", "P": "Pink"},
            {"L": "lavender", "B": "Blue"},
            {"G": "Green", "W": "White"},
            {"B": "Black", "P": "Pink", "R": "Red", "G": "Green", "L": "lavender", "W": "White"}
        )
    ]
    
    passed = 0
    failed = 0
    
    for i, (d1, d2, d3, expected) in enumerate(test_cases):
        cocotb.log.info(f"\nTest {i+1}:")
        cocotb.log.info(f"  Dict1: {d1}")
        cocotb.log.info(f"  Dict2: {d2}")
        cocotb.log.info(f"  Dict3: {d3}")
        cocotb.log.info(f"  Expected: {expected}")
        
        try:
            # Write input dictionaries
            await write_dict(dut, "dict1", dict_to_list(d1))
            await write_dict(dut, "dict2", dict_to_list(d2))
            await write_dict(dut, "dict3", dict_to_list(d3))
            
            # Start computation
            await start_computation(dut)
            
            # Wait for done
            await wait_for_done(dut)
            
            # Read result
            keys, vals, count, overflow = await read_merged_result(dut)
            
            # Build result dictionary
            result_dict = {}
            for k, v in zip(keys[:count], vals[:count]):
                if k is not None and v is not None:
                    result_dict[k] = v
            
            # Verify
            if result_dict != expected:
                raise TestFailure(f"Mismatch: expected {expected}, got {result_dict}")
            
            if overflow:
                # In these tests, overflow shouldn't happen
                cocotb.log.warning(f"  Warning: overflow flag was set")
            
            cocotb.log.info(f"  Result: {result_dict}")
            cocotb.log.info(f"  PASS")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    # Summary
    cocotb.log.info(f"\n{'='*60}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")