import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
MAX_N = 8
MAX_EDGES = 7
MAX_ADDED = 4
DATA_WIDTH = 3  # for node IDs (0-7)
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
async def test_escape_routes(dut):
    """Test the EscapeRoutes module with sample inputs."""
    
    # Detect module type (should be sequential)
    is_sequential = has_signal(dut, 'clk') and has_signal(dut, 'done')
    if not is_sequential:
        raise TestFailure("DUT must be sequential with clk and done signals")
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Define test cases
    test_cases = [
        # Test case 1: n=4, h=0, edges: 0-1,0-2,0-3
        {
            'n': 4,
            'h': 0,
            'edges': [(0,1), (0,2), (0,3)],
            'expected_m': 2,
            'expected_edges': [(3,2), (3,1)]
        },
        # Test case 2: n=6, h=0, edges: 0-1,0-2,0-3,1-4,1-5
        {
            'n': 6,
            'h': 0,
            'edges': [(0,1), (0,2), (0,3), (1,4), (1,5)],
            'expected_m': 2,
            'expected_edges': [(3,5), (2,4)]
        }
    ]
    
    passed = 0
    failed = 0
    
    for idx, tc in enumerate(test_cases):
        cocotb.log.info(f"--- Test Case {idx+1}: n={tc['n']}, h={tc['h']} ---")
        
        try:
            # Set n and h
            dut.n.value = tc['n']
            dut.h.value = tc['h']
            
            # Clear edge arrays (set all to 0)
            for i in range(MAX_EDGES):
                if has_signal(dut, f'edge_u_{i}'):
                    getattr(dut, f'edge_u_{i}').value = 0
                    getattr(dut, f'edge_v_{i}').value = 0
                else:
                    dut.edge_u[i].value = 0
                    dut.edge_v[i].value = 0
            
            # Set the valid edges
            for i, (u, v) in enumerate(tc['edges']):
                if has_signal(dut, f'edge_u_{i}'):
                    getattr(dut, f'edge_u_{i}').value = u
                    getattr(dut, f'edge_v_{i}').value = v
                else:
                    dut.edge_u[i].value = u
                    dut.edge_v[i].value = v
            
            # Start computation
            await start_computation(dut)
            
            # Wait for done
            await wait_for_done(dut)
            
            # Read m
            if not is_value_defined(dut.m.value):
                raise TestFailure("Output m is undefined")
            m = int(dut.m.value)
            
            # Verify m
            if m != tc['expected_m']:
                raise TestFailure(f"Expected m={tc['expected_m']}, got {m}")
            
            # Read added edges
            added_u = []
            added_v = []
            for i in range(m):
                if has_signal(dut, f'added_u_{i}'):
                    u = int(getattr(dut, f'added_u_{i}').value)
                    v = int(getattr(dut, f'added_v_{i}').value)
                else:
                    u = int(dut.added_u[i].value)
                    v = int(dut.added_v[i].value)
                added_u.append(u)
                added_v.append(v)
            
            # Construct list of added edges as tuples
            added_edges = []
            for i in range(m):
                added_edges.append((added_u[i], added_v[i]))
            
            # For comparison, we need to consider that order may differ and edges are undirected.
            # Convert each edge to a canonical form (sorted tuple).
            def canonical(edges):
                return sorted([(min(a,b), max(a,b)) for a,b in edges])
            
            expected_canonical = canonical(tc['expected_edges'])
            actual_canonical = canonical(added_edges)
            
            if actual_canonical != expected_canonical:
                raise TestFailure(f"Expected edges {expected_canonical}, got {actual_canonical}")
            
            cocotb.log.info(f"  PASS: m={m}, edges={added_edges}")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    # Summary
    cocotb.log.info(f"{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")
