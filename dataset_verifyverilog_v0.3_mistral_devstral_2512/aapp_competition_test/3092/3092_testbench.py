import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
MAX_CITIES = 8
MAX_EDGES = 16
DATA_WIDTH = 16
CLK_PERIOD_NS = 10
MAX_CYCLES = 2000

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
        return from_signed(max(-((1 << (bits - 1))), min((1 << (bits - 1)) - 1, value)), bits)
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
    
    # Try individual ports
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
    if has_signal(dut, 'compute_start'):
        dut.compute_start.value = 0
    
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
    """Pulse compute_start for one cycle."""
    dut.compute_start.value = 1
    await RisingEdge(dut.clk)
    dut.compute_start.value = 0

# ============================================================================
# GRAPH LOADING HELPER
# ============================================================================

def pack_edge(src, dst, weight):
    """Pack edge data into 24-bit value: src[3:0], dst[3:0], weight[15:0]"""
    return (src << 20) | (dst << 16) | weight

async def load_graph(dut, edges):
    """Load graph edges into DUT."""
    # Reset config interface
    dut.config_valid.value = 0
    await RisingEdge(dut.clk)
    
    # Load each edge
    for i, (src, dst, weight) in enumerate(edges):
        dut.config_edge_index.value = i
        dut.config_src.value = src
        dut.config_dst.value = dst
        dut.config_weight.value = weight
        dut.config_valid.value = 1
        await RisingEdge(dut.clk)
    
    dut.config_valid.value = 0
    # Set number of edges
    dut.num_edges.value = len(edges)
    await RisingEdge(dut.clk)

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_shortest_path_counter(dut):
    """Test shortest path edge counter."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test cases: (edges, expected_counts, description)
    # Format: edges = [(src, dst, weight), ...]
    # Note: Cities are 0-indexed in hardware
    test_cases = [
        # Sample 1: 4 cities, 3 edges (linear chain)
        # 1->2, 2->3, 3->4 (convert to 0-indexed)
        (
            [(0, 1, 5), (1, 2, 5), (2, 3, 5)],
            [3, 4, 3],
            "Linear chain 4 nodes"
        ),
        # Sample 2: 4 cities, 4 edges (with direct shortcut)
        (
            [(0, 1, 5), (1, 2, 5), (2, 3, 5), (0, 3, 8)],
            [2, 3, 2, 1],
            "Chain with shortcut"
        ),
        # Scaled down Sample 3: 5 cities, 8 edges
        (
            [(0, 1, 20), (0, 2, 2), (1, 2, 2), (3, 1, 3), (3, 1, 3), (2, 3, 5), (3, 2, 5), (4, 3, 20)],
            [0, 4, 6, 6, 6, 7, 2, 6],
            "Complex graph"
        ),
        # Additional test: Single edge
        (
            [(0, 1, 10)],
            [1],
            "Single edge"
        ),
        # Additional test: Two parallel edges
        (
            [(0, 1, 5), (0, 1, 5)],
            [1, 1],
            "Parallel edges"
        ),
    ]
    
    passed = 0
    failed = 0
    
    for test_idx, (edges, expected, description) in enumerate(test_cases):
        dut._log.info(f"\n{'='*60}")
        dut._log.info(f"Test {test_idx + 1}: {description}")
        dut._log.info(f"Graph: {len(edges)} edges")
        
        try:
            # Load graph
            await load_graph(dut, edges)
            
            # Start computation
            await start_computation(dut)
            
            # Collect results
            actual_counts = []
            for i in range(len(edges)):
                # Wait for result_valid
                timeout = 0
                while not (is_value_defined(dut.result_valid.value) and int(dut.result_valid.value) == 1):
                    await RisingEdge(dut.clk)
                    timeout += 1
                    if timeout > 500:
                        raise TestFailure(f"Timeout waiting for result_valid for edge {i}")
                
                # Read result
                result_idx = int(dut.result_edge_index.value)
                result_count = int(dut.result_count.value)
                
                # Validate result index matches expected edge
                if result_idx != i:
                    raise TestFailure(f"Result index mismatch: expected {i}, got {result_idx}")
                
                actual_counts.append(result_count)
                
                # Wait for result_valid to go low (if using level-sensitive)
                await RisingEdge(dut.clk)
            
            # Wait for done
            await wait_for_done(dut)
            
            # Compare results
            if actual_counts != expected:
                raise TestFailure(f"\n  Expected: {expected}\n  Got:      {actual_counts}")
            
            dut._log.info(f"  PASS: {actual_counts}")
            passed += 1
            
        except TestFailure as e:
            dut._log.error(f"  FAIL: {e}")
            failed += 1
    
    # Summary
    dut._log.info(f"\n{'='*60}")
    dut._log.info(f"FINAL RESULTS: {passed}/{passed + failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} test(s) failed")