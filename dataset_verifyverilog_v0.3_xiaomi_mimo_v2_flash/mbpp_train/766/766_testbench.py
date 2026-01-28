import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 8
MAX_ARRAY_SIZE = 8
PAIR_WIDTH = 16
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
    return min(max_val, max(0, value))

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

async def write_array(dut, values, len_val):
    """Write array values and length."""
    # Write array elements
    for i in range(MAX_ARRAY_SIZE):
        if i < len(values):
            port_name = f"arr_{i}"
            if has_signal(dut, port_name):
                getattr(dut, port_name).value = clamp_to_width(values[i], DATA_WIDTH)
            elif has_signal(dut, 'arr'):
                dut.arr[i].value = clamp_to_width(values[i], DATA_WIDTH)
        else:
            # Write zeros for unused elements
            port_name = f"arr_{i}"
            if has_signal(dut, port_name):
                getattr(dut, port_name).value = 0
            elif has_signal(dut, 'arr'):
                dut.arr[i].value = 0
    
    # Write length
    if has_signal(dut, 'len'):
        dut.len.value = clamp_to_width(len_val, 4)

async def start_computation(dut):
    """Pulse start signal for one cycle."""
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

async def collect_pairs(dut, num_pairs):
    """Collect all pairs from DUT."""
    pairs = []
    indices = []
    
    for i in range(num_pairs):
        await RisingEdge(dut.clk)
        
        # Wait for pair_valid
        timeout = 0
        while (not is_value_defined(dut.pair_valid.value) or 
               int(dut.pair_valid.value) == 0) and timeout < 50:
            await RisingEdge(dut.clk)
            timeout += 1
        
        if timeout >= 50:
            raise TestFailure(f"pair_valid not asserted for pair {i}")
        
        # Read pair
        if is_value_defined(dut.pair_valid.value) and int(dut.pair_valid.value) == 1:
            pair_val = int(dut.pair_out.value)
            first = (pair_val >> 8) & 0xFF
            second = pair_val & 0xFF
            pairs.append((first, second))
            
            if is_value_defined(dut.pair_index.value):
                indices.append(int(dut.pair_index.value))
    
    return pairs, indices

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_pair_wise(dut):
    """Test pair_wise module with various test cases."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Define test cases: (input_list, expected_pairs, description)
    test_cases = [
        ([1, 1, 2, 3, 3, 4, 4, 5], [(1, 1), (1, 2), (2, 3), (3, 3), (3, 4), (4, 4), (4, 5)], "Test 1: Mixed sequence"),
        ([1, 5, 7, 9, 10], [(1, 5), (5, 7), (7, 9), (9, 10)], "Test 2: Increasing sequence"),
        ([5, 1, 9, 7, 10], [(5, 1), (1, 9), (9, 7), (7, 10)], "Test 3: Alternating sequence"),
        ([1, 2, 3, 4, 5, 6, 7, 8], [(1, 2), (2, 3), (3, 4), (4, 5), (5, 6), (6, 7), (7, 8)], "Test 4: First 8 of full sequence"),
        ([1, 2], [(1, 2)], "Test 5: Minimal case"),
        ([42, 99], [(42, 99)], "Test 6: Two values"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (input_list, expected_pairs, description) in enumerate(test_cases):
        cocotb.log.info(f"\\nTest {i+1}: {description}")
        cocotb.log.info(f"  Input: {input_list}")
        cocotb.log.info(f"  Expected: {expected_pairs}")
        
        try:
            # Write inputs
            await write_array(dut, input_list, len(input_list))
            
            # Start computation
            await start_computation(dut)
            
            # Collect pairs
            num_pairs = len(input_list) - 1
            actual_pairs, indices = collect_pairs(dut, num_pairs)
            
            # Wait for done
            done_timeout = 0
            while True:
                await RisingEdge(dut.clk)
                if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                    break
                done_timeout += 1
                if done_timeout > 20:
                    raise TestFailure("Done signal not asserted")
            
            # Verify results
            if len(actual_pairs) != len(expected_pairs):
                raise TestFailure(f"Expected {len(expected_pairs)} pairs, got {len(actual_pairs)}")
            
            for j, (actual, expected) in enumerate(zip(actual_pairs, expected_pairs)):
                if actual != expected:
                    raise TestFailure(f"Pair {j}: expected {expected}, got {actual} (index: {indices[j] if j < len(indices) else 'N/A'})")
            
            cocotb.log.info(f"  PASS: All {len(actual_pairs)} pairs correct")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
        
        # Reset for next test
        await reset_dut(dut)
    
    # Summary
    cocotb.log.info(f"\\n{'='*60}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")