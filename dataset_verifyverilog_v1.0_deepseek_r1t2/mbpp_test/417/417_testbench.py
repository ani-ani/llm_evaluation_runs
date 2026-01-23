import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 8       # Width of each array element
PAIR_COUNT = 8       # Maximum number of input pairs
GROUP_COUNT = 8      # Maximum number of output groups
CLK_PERIOD_NS = 10
MAX_CYCLES = 200     # Enough for worst-case computation

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

# ============================================================================
# TEST HELPER: Pack pair into element
# ============================================================================
def pack_pair(first, second, bit_width=4):
    """Pack first and second elements into one byte.
       first uses upper bits, second uses lower bits."""
    f = clamp_to_width(first, bit_width)
    s = clamp_to_width(second, bit_width)
    return (f << bit_width) | s

def unpack_pair(packed, bit_width=4):
    """Extract first and second from packed byte."""
    mask = (1 << bit_width) - 1
    second = packed & mask
    first = (packed >> bit_width) & mask
    return first, second

# ============================================================================
# SEQUENTIAL HELPERS
# ============================================================================

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut):
    """Wait for done signal, handling X/Z values."""
    for cycle in range(MAX_CYCLES):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout: done not asserted after {MAX_CYCLES} cycles")

async def start_computation(dut):
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

# ============================================================================
# WRITE/READ ARRAY HELPERS
# ============================================================================

async def write_input_pairs(dut, pairs):
    """Write list of (first, second) tuples to input array."""
    # Try arr_0 style first, then indexed
    for i, (first, second) in enumerate(pairs):
        packed = pack_pair(first, second)
        
        if has_signal(dut, f'arr_{i}'):
            getattr(dut, f'arr_{i}').value = packed
        elif has_signal(dut, 'arr'):
            dut.arr[i].value = packed
        elif has_signal(dut, 'input_pairs'):
            dut.input_pairs[i].value = packed
        else:
            # Try separate first/second arrays
            if has_signal(dut, f'first_{i}'):
                getattr(dut, f'first_{i}').value = first
                getattr(dut, f'second_{i}').value = second
            elif has_signal(dut, 'first') and has_signal(dut, 'second'):
                dut.first[i].value = first
                dut.second[i].value = second
            else:
                raise TestFailure(f"Cannot find input ports for pair {i}")

async def write_valid_count(dut, count):
    """Write valid count."""
    if has_signal(dut, 'valid_count'):
        dut.valid_count.value = count
    elif has_signal(dut, 'len'):
        dut.len.value = count
    else:
        cocotb.log.warning("valid_count signal not found, skipping")

# ============================================================================
# READ OUTPUTS
# ============================================================================

async def read_output_groups(dut):
    """Read output groups and counts."""
    groups = []
    counts = []
    
    # Try output_groups_0 style, then indexed
    for i in range(GROUP_COUNT):
        # Read group value
        if has_signal(dut, f'output_groups_{i}'):
            val = getattr(dut, f'output_groups_{i}').value
            if is_value_defined(val):
                groups.append(int(val))
            else:
                groups.append(None)
        elif has_signal(dut, 'output_groups'):
            val = dut.output_groups[i].value
            if is_value_defined(val):
                groups.append(int(val))
            else:
                groups.append(None)
        else:
            groups.append(None)
        
        # Read group count
        if has_signal(dut, f'group_counts_{i}'):
            val = getattr(dut, f'group_counts_{i}').value
            if is_value_defined(val):
                counts.append(int(val))
            else:
                counts.append(None)
        elif has_signal(dut, 'group_counts'):
            val = dut.group_counts[i].value
            if is_value_defined(val):
                counts.append(int(val))
            else:
                counts.append(None)
        else:
            counts.append(None)
    
    return groups, counts

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_tuple_grouping(dut):
    """Test tuple grouping module."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test cases: (input_pairs, description)
    # Format: list of (first, second) tuples
    test_cases = [
        ([('x', 'y'), ('x', 'z'), ('w', 't')], "Test 1: Two groups"),
        ([('a', 'b'), ('a', 'c'), ('d', 'e')], "Test 2: Two groups"),
        ([('f', 'g'), ('f', 'g'), ('h', 'i')], "Test 3: Duplicate values"),
    ]
    
    # Convert test cases to numeric values (ASCII)
    numeric_tests = []
    for pairs, desc in test_cases:
        numeric_pairs = []
        for first, second in pairs:
            # Use first letter as value
            numeric_pairs.append((ord(first) - ord('a'), ord(second) - ord('a')))
        numeric_tests.append((numeric_pairs, desc))
    
    passed = 0
    failed = 0
    
    for test_idx, (pairs, description) in enumerate(numeric_tests):
        cocotb.log.info(f"\nTest {test_idx+1}: {description}")
        cocotb.log.info(f"  Input: {pairs}")
        
        try:
            # Write inputs
            await write_input_pairs(dut, pairs)
            await write_valid_count(dut, len(pairs))
            
            # Start computation
            await start_computation(dut)
            
            # Wait for done
            await wait_for_done(dut)
            
            # Read outputs
            output_groups, output_counts = await read_output_groups(dut)
            
            # Parse outputs
            # Format: packed {group_id[3:0], value[3:0]}
            # We need to reconstruct groups
            
            actual_groups = {}
            for i in range(GROUP_COUNT):
                if output_groups[i] is not None and output_counts[i] is not None:
                    packed = output_groups[i]
                    count = output_counts[i]
                    
                    if count > 0:
                        group_id = (packed >> 4) & 0xF
                        value = packed & 0xF
                        
                        if group_id not in actual_groups:
                            actual_groups[group_id] = []
                        actual_groups[group_id].append(value)
            
            # Convert to sorted list of tuples for comparison
            result = []
            for gid in sorted(actual_groups.keys()):
                vals = actual_groups[gid]
                result.append(tuple([chr(gid + ord('a'))] + [chr(v + ord('a')) for v in vals]))
            
            # Expected results (from Python logic)
            if test_idx == 0:
                expected = [('x', 'y', 'z'), ('w', 't')]
            elif test_idx == 1:
                expected = [('a', 'b', 'c'), ('d', 'e')]
            elif test_idx == 2:
                expected = [('f', 'g', 'g'), ('h', 'i')]
            
            # Convert expected to same format
            exp_groups = {}
            for tup in expected:
                gid = ord(tup[0]) - ord('a')
                exp_groups[gid] = [ord(v) - ord('a') for v in tup[1:]]
            
            exp_result = []
            for gid in sorted(exp_groups.keys()):
                vals = exp_groups[gid]
                exp_result.append(tuple([chr(gid + ord('a'))] + [chr(v + ord('a')) for v in vals]))
            
            cocotb.log.info(f"  Expected: {exp_result}")
            cocotb.log.info(f"  Got:      {result}")
            
            # Compare
            if result == exp_result:
                cocotb.log.info("  PASS")
                passed += 1
            else:
                cocotb.log.error("  FAIL: Mismatch")
                failed += 1
                
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    # Summary
    cocotb.log.info(f"\n{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")