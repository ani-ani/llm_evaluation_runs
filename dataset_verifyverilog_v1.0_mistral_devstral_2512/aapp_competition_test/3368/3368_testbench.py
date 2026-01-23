import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
MAX_NODES = 8
MAX_EDGES = 16
CLK_PERIOD_NS = 10

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
    """Clamp value to fit within specified bit width (unsigned)."""
    max_val = (1 << bits) - 1
    return min(max_val, max(0, value))

# ============================================================================
# ARRAY ACCESS HELPERS
# ============================================================================

async def write_array(dut, array_name, values, element_width):
    """Write values to array, handling different interface styles."""
    # Try 2D array first
    try:
        arr = getattr(dut, array_name)
        for i, val in enumerate(values):
            arr[i].value = clamp_to_width(val, element_width)
        return
    except (AttributeError, TypeError):
        pass
    
    # Try individual ports (arr_0, arr_1, ...)
    for i, val in enumerate(values):
        port_name = f"{array_name}_{i}"
        if has_signal(dut, port_name):
            getattr(dut, port_name).value = clamp_to_width(val, element_width)
        else:
            raise TestFailure(f"Cannot find array port: {array_name}[{i}] or {port_name}")

async def read_array(dut, array_name, size):
    """Read array values, handling different interface styles."""
    results = []
    
    # Try 2D array first
    try:
        arr = getattr(dut, array_name)
        for i in range(size):
            if is_value_defined(arr[i].value):
                results.append(int(arr[i].value))
            else:
                results.append(None)
        return results
    except (AttributeError, TypeError):
        pass
    
    # Try individual ports
    for i in range(size):
        port_name = f"{array_name}_{i}"
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

async def wait_for_done(dut, max_cycles=500):
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
# TEST CASE GENERATION
# ============================================================================

def generate_edges_from_original(original_input):
    """Parse original problem input and generate edge list (src, dst) for misplaced animals.
    Returns (num_nodes, edges) where edges is list of (src, dst) tuples."""
    lines = original_input.strip().split('\n')
    n, m = map(int, lines[0].split())
    
    # Map animal types to node IDs
    animal_to_node = {}
    node_to_animal = {}
    
    # First pass: map each enclosure's correct animal to its node ID
    enclosures = []
    for i in range(1, 1 + n):
        tokens = lines[i].split()
        correct_animal = tokens[0]
        animal_to_node[correct_animal] = i-1
        node_to_animal[i-1] = correct_animal
        enclosures.append(tokens)
    
    edges = []
    # Second pass: for each enclosure, for each animal, if animal != correct, add edge
    for i in range(n):
        tokens = enclosures[i]
        correct_animal = tokens[0]
        num_animals = int(tokens[1])
        for j in range(num_animals):
            animal = tokens[2 + j]
            if animal != correct_animal:
                src = i
                dst = animal_to_node[animal]
                edges.append((src, dst))
    
    return n, edges

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_euler_animal_check(dut):
    """Main test function for euler_animal_check module."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Define test cases (original input strings)
    test_cases = [
        (
            """3 6
monkey 2 lion penguin
lion 3 monkey penguin lion
penguin 1 monkey""",
            "POSSIBLE"
        ),
        (
            """2 4
giraffe 3 elephant elephant elephant
elephant 1 giraffe""",
            "IMPOSSIBLE"
        ),
        (
            """2 2
giraffe 1 giraffe
elephant 1 elephant""",
            "FALSE ALARM"
        ),
    ]
    
    passed = 0
    failed = 0
    
    for test_idx, (original_input, expected_output) in enumerate(test_cases):
        dut._log.info(f"\n{'='*60}")
        dut._log.info(f"Test {test_idx + 1}: {expected_output}")
        dut._log.info(f"{'='*60}")
        
        # Parse input to get edges
        n, edges = generate_edges_from_original(original_input)
        m = len(edges)
        
        dut._log.info(f"Nodes: {n}, Misplaced animals: {m}")
        if m > 0:
            dut._log.info(f"Edges: {edges}")
        
        # Prepare arrays (pad to MAX_EDGES with zeros)
        src_vals = [0] * MAX_EDGES
        dst_vals = [0] * MAX_EDGES
        for i, (src, dst) in enumerate(edges):
            src_vals[i] = src
            dst_vals[i] = dst
        
        # Write inputs
        dut.n.value = n
        dut.m.value = m
        
        # Write src and dst arrays element-wise
        for i in range(MAX_EDGES):
            if has_signal(dut, f'src_{i}'):
                getattr(dut, f'src_{i}').value = src_vals[i]
                getattr(dut, f'dst_{i}').value = dst_vals[i]
            elif has_signal(dut, 'src'):
                # Assume 2D array
                dut.src[i].value = src_vals[i]
                dut.dst[i].value = dst_vals[i]
            else:
                raise TestFailure("Cannot find src/dst signals")
        
        # Start computation
        await start_computation(dut)
        
        # Wait for done
        try:
            await wait_for_done(dut, max_cycles=500)
        except TestFailure as e:
            dut._log.error(f"  FAIL: {e}")
            failed += 1
            continue
        
        # Read result
        if not is_value_defined(dut.result.value):
            dut._log.error("  FAIL: Result is undefined (X/Z)")
            failed += 1
            continue
        
        result_val = int(dut.result.value)
        
        # Decode result
        if result_val == 0:
            result_str = "FALSE ALARM"
        elif result_val == 1:
            result_str = "POSSIBLE"
        elif result_val == 2:
            result_str = "IMPOSSIBLE"
        else:
            dut._log.error(f"  FAIL: Invalid result value {result_val}")
            failed += 1
            continue
        
        # Check against expected
        if result_str == expected_output:
            dut._log.info(f"  PASS: Result = {result_str}")
            passed += 1
        else:
            dut._log.error(f"  FAIL: Expected {expected_output}, got {result_str}")
            failed += 1
    
    # Summary
    dut._log.info(f"\n{'='*60}")
    dut._log.info(f"SUMMARY: {passed}/{passed+failed} tests passed")
    dut._log.info(f"{'='*60}")
    
    if failed > 0:
        raise TestFailure(f"{failed} test(s) failed")
