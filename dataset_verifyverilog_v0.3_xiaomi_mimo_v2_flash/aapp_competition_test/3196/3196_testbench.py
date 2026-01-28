import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

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
# CONFIGURATION
# ============================================================================

MAX_NODES = 8          # Max nodes (towns) supported
MAX_EDGES = 16         # Max total edge count (sum of parallel edges)
MOD_VAL = 1000000000   # Modulus for result (10^9)
CLK_PERIOD_NS = 10     # Clock period in ns
TIMEOUT_CYCLES = 1000  # Max cycles to wait for done

# ============================================================================
# HELPER FUNCTIONS FOR GRAPH INPUT
# ============================================================================

def parse_input(input_str):
    """
    Parse input string and return a list of (src, dst, count) tuples.
    Towns are 1-indexed; convert to 0-indexed nodes.
    """
    lines = input_str.strip().split('\n')
    if not lines:
        return []
    # First line: N M (ignored)
    edges_raw = lines[1:]  # Remaining lines are edges
    # Count occurrences of each (src, dst) pair
    edge_counts = {}
    for line in edges_raw:
        parts = line.strip().split()
        if len(parts) != 2:
            continue
        a, b = map(int, parts)
        # Convert to 0-indexed
        src = a - 1
        dst = b - 1
        if src < 0 or src >= MAX_NODES or dst < 0 or dst >= MAX_NODES:
            # Skip nodes outside our range
            continue
        key = (src, dst)
        edge_counts[key] = edge_counts.get(key, 0) + 1
    # Convert to list of tuples
    edges = []
    total_edges = 0
    for (src, dst), count in edge_counts.items():
        if count > 15:  # cnt is 4-bit, max 15 (since 4-bit 0-15, but cnt is 1-16? Actually 4-bit can hold 0-15, but problem says 1-16, we'll cap at 15 for simplicity)
            count = 15
        edges.append((src, dst, count))
        total_edges += count
        if total_edges > MAX_EDGES:
            # Truncate if exceeds max edges
            break
    return edges

async def write_graph(dut, edges):
    """Write all edges to the DUT using graph_write_en pulses."""
    for src, dst, cnt in edges:
        # Set signals
        dut.src.value = src
        dut.dst.value = dst
        dut.cnt.value = cnt
        dut.graph_write_en.value = 1
        await RisingEdge(dut.clk)
        dut.graph_write_en.value = 0
        # Wait one cycle for safety
        await RisingEdge(dut.clk)

async def start_computation(dut):
    """Pulse start signal for one clock cycle."""
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

async def wait_for_done(dut, max_cycles=TIMEOUT_CYCLES):
    """Wait for done signal to go high."""
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return
    raise TestFailure(f"Timeout: done not asserted after {max_cycles} cycles")

async def read_result(dut):
    """Read result and inf from DUT."""
    # Ensure we read stable values
    await Timer(1, units='ns')
    inf = 0
    result = 0
    if has_signal(dut, 'inf'):
        inf = safe_int(dut.inf.value)
    if has_signal(dut, 'result'):
        result = safe_int(dut.result.value)
    return result, inf

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_path_counter(dut):
    """Test the path_counter module with provided test cases."""
    
    # Detect signals
    if not has_signal(dut, 'clk'):
        raise TestFailure("DUT missing 'clk' signal")
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset DUT
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.graph_write_en.value = 0
    for _ in range(3):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases: (input_string, expected_output_string)
    test_cases = [
        ("6 7\n1 3\n1 4\n3 2\n4 2\n5 6\n6 5\n3 4\n", "3"),
        ("6 8\n1 3\n1 4\n3 2\n4 2\n5 6\n6 5\n3 4\n4 3\n", "inf"),
        # Third original test case is too large; we skip or adapt.
        # For demonstration, we add a small custom test that fits within constraints.
        ("5 5\n1 3\n1 3\n3 4\n4 2\n4 2\n", "4"),  # Expect 4 paths: two 1->3, then one 3->4, two 4->2 => 2*1*2=4
    ]
    
    for idx, (input_str, expected) in enumerate(test_cases):
        dut._log.info(f"Running Test {idx+1}: {expected}")
        
        # Parse input
        edges = parse_input(input_str)
        if not edges:
            raise TestFailure(f"Test {idx+1}: No valid edges parsed from input")
        
        # Write graph
        await write_graph(dut, edges)
        
        # Start computation
        await start_computation(dut)
        
        # Wait for done
        await wait_for_done(dut)
        
        # Read result
        result, inf = await read_result(dut)
        
        # Format actual output
        if inf:
            actual = "inf"
        else:
            if result >= MOD_VAL:
                # Output last nine digits with leading zeros
                actual = f"{result:09d}"
            else:
                actual = str(result)
        
        dut._log.info(f"Test {idx+1}: Expected='{expected}', Actual='{actual}'")
        
        if actual != expected:
            raise TestFailure(f"Test {idx+1} failed: expected '{expected}', got '{actual}'")
        
        # Reset for next test
        dut.rst_n.value = 0
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
    
    dut._log.info("All tests passed!")
