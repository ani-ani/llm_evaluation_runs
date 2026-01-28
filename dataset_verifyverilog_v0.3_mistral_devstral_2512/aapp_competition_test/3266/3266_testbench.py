import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import warnings

# ============================================================================
# CONFIGURATION
# ============================================================================
MAX_NODES = 8
DATA_WIDTH = 32
NODE_WIDTH = 3
CLK_PERIOD_NS = 10
MAX_CYCLES = 5000

# ============================================================================
# MANDATORY HELPER FUNCTIONS
# ============================================================================

def is_value_defined(value):
    """Check if a cocotb value is defined (not X or Z)."""
    try:
        int(value)
        return True
    except (ValueError, TypeError):
        return False

def safe_int(value, default=0):
    """Safely convert cocotb value to int, returning default if X/Z."""
    try:
        return int(value)
    except (ValueError, TypeError):
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

# ============================================================================
# TESTBENCH HELPER FUNCTIONS
# ============================================================================

async def reset_dut(dut):
    """Reset the DUT."""
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.load_edge.value = 0
    dut.src_node.value = 0
    dut.dst_node.value = 0
    
    for _ in range(2):
        await RisingEdge(dut.clk)
    
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def load_edge(dut, u, v, cap):
    """Load a single edge into the capacity matrix."""
    dut.edge_u.value = clamp_to_width(u, NODE_WIDTH)
    dut.edge_v.value = clamp_to_width(v, NODE_WIDTH)
    dut.edge_cap.value = clamp_to_width(cap, DATA_WIDTH)
    dut.load_edge.value = 1
    await RisingEdge(dut.clk)
    dut.load_edge.value = 0
    await RisingEdge(dut.clk)

async def start_computation(dut):
    """Pulse start signal."""
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    """Wait for done signal."""
    for cycle in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return
    raise TestFailure(f"Timeout: done not asserted after {max_cycles} cycles")

async def collect_flows(dut):
    """Collect all non-zero edge flows from the module."""
    flows = []
    max_cycles = MAX_CYCLES
    
    # Wait for flow output to start
    for cycle in range(max_cycles):
        await RisingEdge(dut.clk)
        
        # Check for flow valid
        if is_value_defined(dut.flow_valid.value) and int(dut.flow_valid.value) == 1:
            if is_value_defined(dut.flow_amount.value):
                amount = int(dut.flow_amount.value)
                if amount > 0:
                    src = int(dut.flow_src.value) if is_value_defined(dut.flow_src.value) else 0
                    dst = int(dut.flow_dst.value) if is_value_defined(dut.flow_dst.value) else 0
                    flows.append((src, dst, amount))
        
        # Check for flow done
        if is_value_defined(dut.flow_done.value) and int(dut.flow_done.value) == 1:
            break
    
    return flows

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_max_flow_solver(dut):
    """Test max flow solver with multiple test cases."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Test case definitions
    test_cases = [
        {
            "name": "Example 1: Multi-path flow",
            "src": 0,
            "dst": 3,
            "edges": [(0,1,10), (1,2,1), (1,3,1), (0,2,1), (2,3,10)],
            "expected_flow": 3,
            "expected_flows": [(0,1,2), (0,2,1), (1,2,1), (1,3,1), (2,3,2)]
        },
        {
            "name": "Example 2: Single edge large capacity",
            "src": 0,
            "dst": 1,
            "edges": [(0,1,100000)],
            "expected_flow": 100000,
            "expected_flows": [(0,1,100000)]
        },
        {
            "name": "Example 3: No path (reverse direction)",
            "src": 1,
            "dst": 0,
            "edges": [(0,1,100000)],
            "expected_flow": 0,
            "expected_flows": []
        }
    ]
    
    for i, test in enumerate(test_cases):
        cocotb.log.info(f"\n{'='*60}")
        cocotb.log.info(f"Test {i+1}: {test['name']}")
        cocotb.log.info(f"{'='*60}")
        
        # Reset DUT
        await reset_dut(dut)
        
        # Configure source and destination
        dut.src_node.value = clamp_to_width(test['src'], NODE_WIDTH)
        dut.dst_node.value = clamp_to_width(test['dst'], NODE_WIDTH)
        await RisingEdge(dut.clk)
        
        # Load all edges
        cocotb.log.info("Loading edges...")
        for u, v, cap in test['edges']:
            await load_edge(dut, u, v, cap)
            cocotb.log.info(f"  Loaded edge {u} -> {v} with capacity {cap}")
        
        # Start computation
        cocotb.log.info("Starting computation...")
        await start_computation(dut)
        
        # Wait for completion
        await wait_for_done(dut)
        cocotb.log.info("Computation done")
        
        # Check max flow
        if not is_value_defined(dut.max_flow.value):
            raise TestFailure(f"Test {i+1}: max_flow is undefined (X/Z)")
        
        max_flow = int(dut.max_flow.value)
        expected_flow = test['expected_flow']
        
        cocotb.log.info(f"Max flow result: {max_flow} (expected: {expected_flow})")
        
        if max_flow != expected_flow:
            raise TestFailure(
                f"Test {i+1}: Expected max_flow={expected_flow}, got {max_flow}"
            )
        
        # Collect edge flows
        flows = await collect_flows(dut)
        
        cocotb.log.info(f"Collected {len(flows)} edge flows:")
        for src, dst, amount in flows:
            cocotb.log.info(f"  {src} -> {dst}: {amount}")
        
        # Verify flows match expected
        expected_flows_sorted = sorted(test['expected_flows'])
        flows_sorted = sorted(flows)
        
        if len(flows_sorted) != len(expected_flows_sorted):
            raise TestFailure(
                f"Test {i+1}: Expected {len(expected_flows_sorted)} flow edges, "
                f"got {len(flows_sorted)}"
            )
        
        for j, (actual, expected) in enumerate(zip(flows_sorted, expected_flows_sorted)):
            if actual != expected:
                raise TestFailure(
                    f"Test {i+1}, flow {j}: Expected {expected}, got {actual}"
                )
        
        cocotb.log.info(f"Test {i+1} PASSED")
    
    cocotb.log.info(f"\n{'='*60}")
    cocotb.log.info("ALL TESTS PASSED!")
    cocotb.log.info(f"{'='*60}")
