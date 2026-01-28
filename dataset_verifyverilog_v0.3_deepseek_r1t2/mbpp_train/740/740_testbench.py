import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 8
TUPLE_SIZE = 6
MAX_PAIRS = 3
CLK_PERIOD_NS = 10
MAX_CYCLES = 100

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

def is_value_defined(value):
    try:
        int(value)
        return True
    except ValueError:
        return False

def safe_int(value, default=0):
    try:
        return int(value)
    except ValueError:
        return default

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def clamp_to_width(value, bits):
    max_val = (1 << bits) - 1
    return min(max_val, max(0, value))

async def write_tuple(dut, values):
    """Write tuple values to input array."""
    # Ensure we have exactly TUPLE_SIZE elements
    padded = list(values) + [0] * (TUPLE_SIZE - len(values))
    
    # Handle both indexed and individual port styles
    for i in range(TUPLE_SIZE):
        val = clamp_to_width(padded[i], DATA_WIDTH)
        try:
            # Try indexed array first
            dut.tuple_data[i].value = val
        except (AttributeError, TypeError):
            # Try individual ports
            port_name = f"tuple_data_{i}"
            if has_signal(dut, port_name):
                getattr(dut, port_name).value = val
            else:
                raise TestFailure(f"Cannot access tuple_data[{i}] or {port_name}")

async def read_results(dut):
    """Read keys, values, and valid_pairs from output."""
    keys = []
    values = []
    
    # Read valid_pairs
    valid_pairs = 0
    if is_value_defined(dut.valid_pairs.value):
        valid_pairs = int(dut.valid_pairs.value)
    
    # Read keys array
    for i in range(MAX_PAIRS):
        try:
            key_val = dut.keys[i].value
            if is_value_defined(key_val):
                keys.append(int(key_val))
            else:
                keys.append(None)
        except (AttributeError, TypeError):
            port_name = f"keys_{i}"
            if has_signal(dut, port_name):
                val = getattr(dut, port_name).value
                keys.append(int(val) if is_value_defined(val) else None)
            else:
                keys.append(None)
    
    # Read values array
    for i in range(MAX_PAIRS):
        try:
            val_val = dut.values[i].value
            if is_value_defined(val_val):
                values.append(int(val_val))
            else:
                values.append(None)
        except (AttributeError, TypeError):
            port_name = f"values_{i}"
            if has_signal(dut, port_name):
                val = getattr(dut, port_name).value
                values.append(int(val) if is_value_defined(val) else None)
            else:
                values.append(None)
    
    return keys, values, valid_pairs

async def reset_dut(dut):
    """Reset the DUT."""
    dut.rst_n.value = 0
    dut.start.value = 0
    for _ in range(2):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    """Wait for done signal."""
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout: done not asserted after {max_cycles} cycles")

async def start_computation(dut):
    """Pulse start signal."""
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_tuple_to_dict(dut):
    """Test tuple to dictionary conversion."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units="ns").start())
    
    # Reset
    await reset_dut(dut)
    
    # Test cases: (input_tuple, expected_key_value_pairs)
    # Format: [key, value, key, value, ...]
    test_cases = [
        ((1, 5, 7, 10, 13, 5), [(1, 5), (7, 10), (13, 5)], "Test 1: {1:5, 7:10, 13:5}"),
        ((1, 2, 3, 4, 5, 6), [(1, 2), (3, 4), (5, 6)], "Test 2: {1:2, 3:4, 5:6}"),
        ((7, 8, 9, 10, 11, 12), [(7, 8), (9, 10), (11, 12)], "Test 3: {7:8, 9:10, 11:12}"),
    ]
    
    passed = 0
    failed = 0
    
    for test_idx, (input_tuple, expected_pairs, description) in enumerate(test_cases):
        cocotb.log.info(f"\nRunning {description}")
        
        try:
            # Write input tuple
            await write_tuple(dut, input_tuple)
            
            # Start computation
            await start_computation(dut)
            
            # Wait for done
            await wait_for_done(dut)
            
            # Read results
            keys, values, valid_pairs = await read_results(dut)
            
            # Verify valid_pairs
            expected_count = len(expected_pairs)
            if valid_pairs != expected_count:
                raise TestFailure(f"valid_pairs mismatch: expected {expected_count}, got {valid_pairs}")
            
            # Verify each key-value pair
            for i, (expected_key, expected_value) in enumerate(expected_pairs):
                if i >= len(keys) or i >= len(values):
                    raise TestFailure(f"Pair {i}: missing from output")
                
                if keys[i] != expected_key:
                    raise TestFailure(f"Pair {i}: key mismatch - expected {expected_key}, got {keys[i]}")
                
                if values[i] != expected_value:
                    raise TestFailure(f"Pair {i}: value mismatch - expected {expected_value}, got {values[i]}")
            
            cocotb.log.info(f"  PASS: Result = {dict(zip(keys[:valid_pairs], values[:valid_pairs]))}")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    # Summary
    cocotb.log.info(f"\n{'='*60}")
    cocotb.log.info(f"Test Results: {passed}/{passed+failed} passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")
