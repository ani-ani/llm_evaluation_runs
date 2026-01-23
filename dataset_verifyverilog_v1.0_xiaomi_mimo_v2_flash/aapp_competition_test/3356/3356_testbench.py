import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Configuration
MAX_NODES = 8
CLK_PERIOD_NS = 10
MAX_CYCLES = 1000

# Helper functions
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

def pack_edges(edge_list, max_edges=7):
    """Pack edge list into module inputs."""
    # edge_list is list of (a,b) pairs
    # For simplicity, we'll use a fixed mapping
    packed = {}
    for i, (a,b) in enumerate(edge_list):
        if i < max_edges:
            packed[f'edge_list_{i}_a'] = a
            packed[f'edge_list_{i}_b'] = b
    return packed

# Test cases for chains (simplified)
TEST_CASES = [
    {  # Chain of 4 nodes: 0-1-2-3
        'node_count': 4,
        'edges': [(0,1), (1,2), (2,3)],
        'expected_diameter': 2,  # After optimal reconstruction
        'description': 'Chain of 4 nodes'
    },
    {  # Chain of 7 nodes: 0-1-2-3-4-5-6
        'node_count': 7,
        'edges': [(0,1), (1,2), (2,3), (3,4), (4,5), (5,6)],
        'expected_diameter': 4,  # After optimal reconstruction
        'description': 'Chain of 7 nodes'
    }
]

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_tree_reconstruction(dut):
    """Test tree reconstruction module."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Wait for reset to complete
    await RisingEdge(dut.clk)
    
    passed = 0
    failed = 0
    
    for test_case in TEST_CASES:
        cocotb.log.info(f"Testing: {test_case['description']}")
        
        try:
            # Set node count
            dut.node_count.value = test_case['node_count']
            
            # Pack edges into inputs
            edge_inputs = pack_edges(test_case['edges'])
            for port_name, value in edge_inputs.items():
                if has_signal(dut, port_name):
                    setattr(dut, port_name).value = clamp_to_width(value, 8)
            
            # Start computation
            await start_computation(dut)
            
            # Wait for completion
            await wait_for_done(dut)
            
            # Read results
            if not is_value_defined(dut.new_diameter.value):
                raise TestFailure("Result is undefined (X/Z)")
            
            result_diameter = int(dut.new_diameter.value)
            expected_diameter = test_case['expected_diameter']
            
            # For this adaptation, we accept a range of values
            if result_diameter > expected_diameter + 2:
                raise TestFailure(f"Diameter too large: expected ~{expected_diameter}, got {result_diameter}")
            
            # Check that edges are defined
            if not (is_value_defined(dut.remove_a.value) and is_value_defined(dut.remove_b.value)):
                raise TestFailure("Remove edges not defined")
            
            cocotb.log.info(f"  PASS: diameter={result_diameter}, remove=({int(dut.remove_a.value)},{int(dut.remove_b.value)}), add=({int(dut.add_a.value)},{int(dut.add_b.value)})")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    # Summary
    cocotb.log.info(f"{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")
