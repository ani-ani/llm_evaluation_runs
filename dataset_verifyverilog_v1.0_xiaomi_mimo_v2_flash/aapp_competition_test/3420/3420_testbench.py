import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION - Adjust these to match your HDL design
# ============================================================================
MAX_BOYS = 4
MAX_GIRLS = 4
MAX_EDGES = 16
DATA_WIDTH = 4          # For boy/girl indices
EDGE_COUNT_WIDTH = 6    # For edge count
CLK_PERIOD_NS = 10
MAX_CYCLES = 1000000    # Large enough for worst-case computation

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
# INPUT PARSING
# ============================================================================

def parse_input_to_edges(input_str):
    """Parse the input string and return B, G, list of (boy_idx, girl_idx)."""
    lines = input_str.strip().split('\n')
    # First line: B G
    first_line = lines[0].split()
    B = int(first_line[0])
    G = int(first_line[1])
    
    # Dictionary to store book -> boy and book -> girl
    book_to_boy = {}
    book_to_girl = {}
    
    # Next B lines: boys
    line_idx = 1
    for boy_idx in range(B):
        parts = lines[line_idx].split()
        line_idx += 1
        # Format: boy_name N_i book1 book2 ...
        N_i = int(parts[1])
        for book in parts[2:2+N_i]:
            book_to_boy[book] = boy_idx
    
    # Next G lines: girls
    for girl_idx in range(G):
        parts = lines[line_idx].split()
        line_idx += 1
        N_i = int(parts[1])
        for book in parts[2:2+N_i]:
            book_to_girl[book] = girl_idx
    
    # Build edge list
    edges = []
    for book, boy_idx in book_to_boy.items():
        if book in book_to_girl:
            girl_idx = book_to_girl[book]
            edges.append((boy_idx, girl_idx))
    
    return B, G, edges

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_book_presentation_minimizer(dut):
    """Test the BookPresentationMinimizer module."""
    
    # Detect if sequential (has clk)
    is_sequential = has_signal(dut, 'clk')
    
    if is_sequential:
        # Start clock
        cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
        # Reset
        await reset_dut(dut)
    else:
        # Combinational - wait for propagation
        dut.rst_n.value = 1
    
    # Define test cases
    test_cases = [
        # Example 1: 2 boys, 2 girls, 4 books (2 edges)
        (
            "2 2\n"
            "kenny 1 harrypotter1\n"
            "charlie 1 lordoftherings\n"
            "jenny 1 harrypotter1\n"
            "laura 1 lordoftherings\n",
            2
        ),
        # Example 2: 1 boy, 2 girls, 2 books (2 edges)
        (
            "1 2\n"
            "kenny 2 harrypotter1 lordoftherings\n"
            "emma 1 lordoftherings\n"
            "jenny 1 harrypotter1\n",
            1
        ),
        # Additional test: triangle graph (2 boys, 2 girls, 3 edges)
        (
            "2 2\n"
            "boy0 2 bookA bookB\n"
            "boy1 1 bookC\n"
            "girl0 2 bookA bookC\n"
            "girl1 1 bookB\n",
            2
        ),
        # Additional test: single edge (1 boy, 1 girl, 1 book)
        (
            "1 1\n"
            "boy0 1 bookX\n"
            "girl0 1 bookX\n",
            1
        ),
    ]
    
    passed = 0
    failed = 0
    
    for i, (input_str, expected_result) in enumerate(test_cases):
        cocotb.log.info(f"\nTest {i+1}: Parsing input and computing...")
        
        try:
            # Parse input to extract edges
            B, G, edges = parse_input_to_edges(input_str)
            
            cocotb.log.info(f"  B={B}, G={G}, edges={len(edges)}: {edges}")
            
            # Check if we exceed maximums
            if B > MAX_BOYS or G > MAX_GIRLS or len(edges) > MAX_EDGES:
                cocotb.log.warning(f"  Test case exceeds limits, skipping")
                continue
            
            # Write inputs to DUT
            # Set B, G, edge_count
            if has_signal(dut, 'B'):
                dut.B.value = clamp_to_width(B, 4)
            if has_signal(dut, 'G'):
                dut.G.value = clamp_to_width(G, 4)
            if has_signal(dut, 'edge_count'):
                dut.edge_count.value = clamp_to_width(len(edges), EDGE_COUNT_WIDTH)
            
            # Write edges arrays
            edge_boys = [e[0] for e in edges]
            edge_girls = [e[1] for e in edges]
            
            # Pad arrays to MAX_EDGES with zeros
            edge_boys += [0] * (MAX_EDGES - len(edges))
            edge_girls += [0] * (MAX_EDGES - len(edges))
            
            await write_array(dut, 'edges_boy', edge_boys, DATA_WIDTH)
            await write_array(dut, 'edges_girl', edge_girls, DATA_WIDTH)
            
            if is_sequential:
                # Start computation and wait for done
                await start_computation(dut)
                await wait_for_done(dut)
            else:
                # Combinational - wait for propagation
                await Timer(100, units='ns')
            
            # Read result
            result_signal = dut.result if has_signal(dut, 'result') else None
            if result_signal is None:
                raise TestFailure("DUT has no 'result' signal")
            
            if not is_value_defined(result_signal.value):
                raise TestFailure("Result is undefined (X/Z)")
            
            result = int(result_signal.value)
            
            if result != expected_result:
                raise TestFailure(f"Expected {expected_result}, got {result}")
            
            cocotb.log.info(f"  PASS: result = {result}")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    # Summary
    cocotb.log.info(f"\n{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")
