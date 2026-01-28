import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 4          # State indices are 4-bit (0-15)
MAX_SUPPLIERS = 8
MAX_FACTORIES = 8
MAX_COMPANIES = 8
MAX_STATES_PER_COMPANY = 8
CLK_PERIOD_NS = 10
MAX_CYCLES = 1000

# State mapping
STATE_MAP = {}
STATE_COUNTER = 0

def get_state_index(state_name):
    """Map state name to integer index (0-15)."""
    global STATE_COUNTER, STATE_MAP
    if state_name not in STATE_MAP:
        if STATE_COUNTER >= 16:
            raise ValueError("Too many states, max 16 allowed")
        STATE_MAP[state_name] = STATE_COUNTER
        STATE_COUNTER += 1
    return STATE_MAP[state_name]

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
# ARRAY WRITE HELPERS
# ============================================================================

async def write_array_1d(dut, array_name, values, element_width):
    """Write values to 1D array."""
    try:
        arr = getattr(dut, array_name)
        for i, val in enumerate(values):
            arr[i].value = clamp_to_width(val, element_width)
    except (AttributeError, TypeError):
        # Try individual ports arr_0, arr_1, ...
        for i, val in enumerate(values):
            port_name = f"{array_name}_{i}"
            if has_signal(dut, port_name):
                getattr(dut, port_name).value = clamp_to_width(val, element_width)

async def write_array_2d(dut, array_name, values_2d, element_width):
    """Write values to 2D array."""
    try:
        arr = getattr(dut, array_name)
        for i, row in enumerate(values_2d):
            for j, val in enumerate(row):
                arr[i][j].value = clamp_to_width(val, element_width)
    except (AttributeError, TypeError):
        # Try individual ports
        for i, row in enumerate(values_2d):
            for j, val in enumerate(row):
                port_name = f"{array_name}_{i}_{j}"
                if has_signal(dut, port_name):
                    getattr(dut, port_name).value = clamp_to_width(val, element_width)

# ============================================================================
# MAX FLOW REFERENCE IMPLEMENTATION
# ============================================================================
def max_flow_reference(suppliers, factories, companies):
    """Compute max flow using Python reference implementation."""
    global STATE_MAP, STATE_COUNTER
    STATE_MAP = {}
    STATE_COUNTER = 0
    
    # Map state names
    supplier_states_idx = [get_state_index(s) for s in suppliers]
    factory_states_idx = [get_state_index(f) for f in factories]
    company_states_idx = []
    for comp in companies:
        states = [get_state_index(s) for s in comp]
        while len(states) < 8:
            states.append(15)  # 15 = invalid
        company_states_idx.append(states)
    
    # Node indices
    NODE_SOURCE = 0
    NODE_SINK = 1
    NODE_SUP_START = 2
    NODE_FACT_START = NODE_SUP_START + len(suppliers)
    NODE_COMP_START = NODE_FACT_START + len(factories)
    
    num_nodes = NODE_COMP_START + len(companies)
    
    # Build adjacency matrix
    cap = [[0] * num_nodes for _ in range(num_nodes)]
    
    # Source to suppliers
    for i in range(len(suppliers)):
        cap[NODE_SOURCE][NODE_SUP_START + i] = 1
    
    # Factories to sink
    for i in range(len(factories)):
        cap[NODE_FACT_START + i][NODE_SINK] = 1
    
    # Suppliers to companies
    for s_idx, s_state in enumerate(supplier_states_idx):
        for c_idx, c_states in enumerate(company_states_idx):
            if s_state in c_states:
                cap[NODE_SUP_START + s_idx][NODE_COMP_START + c_idx] = 1
    
    # Companies to factories
    for c_idx, c_states in enumerate(company_states_idx):
        for f_idx, f_state in enumerate(factory_states_idx):
            if f_state in c_states:
                cap[NODE_COMP_START + c_idx][NODE_FACT_START + f_idx] = 1
    
    # Companies to companies (if they share any state)
    for c1_idx, c1_states in enumerate(company_states_idx):
        for c2_idx, c2_states in enumerate(company_states_idx):
            if c1_idx != c2_idx:
                if any(state in c2_states for state in c1_states if state != 15):
                    cap[NODE_COMP_START + c1_idx][NODE_COMP_START + c2_idx] = 1
    
    # Ford-Fulkerson with BFS
    flow = [[0] * num_nodes for _ in range(num_nodes)]
    max_flow = 0
    
    while True:
        # BFS to find augmenting path
        parent = [-1] * num_nodes
        parent[NODE_SOURCE] = NODE_SOURCE
        queue = [NODE_SOURCE]
        
        found = False
        while queue and not found:
            u = queue.pop(0)
            for v in range(num_nodes):
                if parent[v] == -1 and cap[u][v] > flow[u][v]:
                    parent[v] = u
                    if v == NODE_SINK:
                        found = True
                        break
                    queue.append(v)
        
        if not found:
            break
        
        # Find min capacity on path
        path_flow = float('inf')
        v = NODE_SINK
        while v != NODE_SOURCE:
            u = parent[v]
            path_flow = min(path_flow, cap[u][v] - flow[u][v])
            v = u
        
        # Update flow
        v = NODE_SINK
        while v != NODE_SOURCE:
            u = parent[v]
            flow[u][v] += path_flow
            flow[v][u] -= path_flow
            v = u
        
        max_flow += path_flow
    
    return max_flow

# ============================================================================
# MAIN TESTBENCH
# ============================================================================

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_max_flow_network(dut):
    """Test max flow network module."""
    
    # Setup clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases
    test_cases = [
        # Case 1: 3 suppliers, 3 factories, 3 companies
        {
            'suppliers': ['A', 'B', 'C'],
            'factories': ['D', 'E', 'F'],
            'companies': [['A', 'E', 'G'], ['A', 'C', 'E'], ['B', 'D', 'F']],
            'expected': 2
        },
        # Case 2: 3 suppliers, 3 factories, 4 companies
        {
            'suppliers': ['A', 'B', 'C'],
            'factories': ['D', 'E', 'F'],
            'companies': [['A', 'E', 'G'], ['A', 'C', 'E'], ['B', 'D', 'F'], ['G', 'F']],
            'expected': 3
        },
        # Case 3: Single supplier, single factory, direct connection
        {
            'suppliers': ['A'],
            'factories': ['B'],
            'companies': [['A', 'B']],
            'expected': 1
        },
        # Case 4: No possible connections
        {
            'suppliers': ['A'],
            'factories': ['B'],
            'companies': [['X', 'Y']],
            'expected': 0
        },
        # Case 5: Multiple companies in chain
        {
            'suppliers': ['A'],
            'factories': ['D'],
            'companies': [['A', 'B'], ['B', 'C'], ['C', 'D']],
            'expected': 1
        }
    ]
    
    passed = 0
    failed = 0
    
    for test_idx, test in enumerate(test_cases):
        global STATE_MAP, STATE_COUNTER
        STATE_MAP = {}
        STATE_COUNTER = 0
        
        # Get expected result
        expected = test['expected']
        
        # Prepare input arrays
        num_sup = len(test['suppliers'])
        num_fact = len(test['factories'])
        num_comp = len(test['companies'])
        
        # Map states to indices
        supplier_states = [get_state_index(s) for s in test['suppliers']]
        factory_states = [get_state_index(f) for f in test['factories']]
        company_states = []
        for comp in test['companies']:
            states = [get_state_index(s) for s in comp]
            # Pad to 8 states
            while len(states) < 8:
                states.append(15)  # 15 = invalid
            company_states.append(states)
        
        # Pad company_states to 8x8
        while len(company_states) < 8:
            company_states.append([15] * 8)
        
        # Compute reference result
        ref_result = max_flow_reference(test['suppliers'], test['factories'], test['companies'])
        
        cocotb.log.info(f"\nTest {test_idx + 1}: {num_sup} suppliers, {num_fact} factories, {num_comp} companies")
        cocotb.log.info(f"  Expected: {expected}, Reference: {ref_result}")
        
        # Write inputs to DUT
        # Set configuration
        dut.num_suppliers.value = num_sup
        dut.num_factories.value = num_fact
        dut.num_companies.value = num_comp
        
        # Write supplier states
        await write_array_1d(dut, 'supplier_states', supplier_states, DATA_WIDTH)
        
        # Write factory states
        await write_array_1d(dut, 'factory_states', factory_states, DATA_WIDTH)
        
        # Write company states
        await write_array_2d(dut, 'company_states', company_states, DATA_WIDTH)
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done (with timeout)
        cycles = 0
        while not is_value_defined(dut.done.value) or int(dut.done.value) == 0:
            await RisingEdge(dut.clk)
            cycles += 1
            if cycles > MAX_CYCLES:
                raise TestFailure(f"Timeout waiting for done after {MAX_CYCLES} cycles")
        
        # Read result
        if not is_value_defined(dut.max_flow.value):
            raise TestFailure(f"Result is undefined (X/Z)")
        
        result = int(dut.max_flow.value)
        
        # Verify
        if result != expected:
            cocotb.log.error(f"  FAIL: Expected {expected}, got {result}")
            failed += 1
        else:
            cocotb.log.info(f"  PASS: Got {result}")
            passed += 1
        
        # Wait for done to go low
        await RisingEdge(dut.clk)
    
    # Summary
    cocotb.log.info(f"\n{'='*60}")
    cocotb.log.info(f"Test Summary: {passed}/{passed+failed} passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")