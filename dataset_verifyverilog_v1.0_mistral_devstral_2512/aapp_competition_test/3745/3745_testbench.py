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
    """Clamp value to fit within specified bit width (unsigned)."""
    max_val = (1 << bits) - 1
    return min(max_val, max(0, value))

# ============================================================================
# TEST CONFIGURATION
# ============================================================================

CLK_PERIOD_NS = 10
MAX_CYCLES = 500

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_graph_solver(dut):
    """Test graph_solver module with various test cases."""
    
    # Detect interface
    has_clk = has_signal(dut, 'clk')
    has_rst = has_signal(dut, 'rst_n')
    has_start = has_signal(dut, 'start')
    has_done = has_signal(dut, 'done')
    has_valid = has_signal(dut, 'valid')
    has_result = has_signal(dut, 'result')
    has_n = has_signal(dut, 'n')
    
    # Collect row ports
    rows = []
    for i in range(8):
        if has_signal(dut, f'row{i}'):
            rows.append(getattr(dut, f'row{i}'))
        else:
            break
    if not rows:
        raise TestFailure("No row ports found (row0..row7)")
    
    # Start clock if sequential
    if has_clk:
        cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    async def reset_dut():
        if not has_rst:
            return
        dut.rst_n.value = 0
        if has_start:
            dut.start.value = 0
        for _ in range(2):
            if has_clk:
                await RisingEdge(dut.clk)
            else:
                await Timer(CLK_PERIOD_NS, units='ns')
        dut.rst_n.value = 1
        if has_clk:
            await RisingEdge(dut.clk)
        else:
            await Timer(CLK_PERIOD_NS, units='ns')
    
    async def start_computation(n_val, adj_matrix):
        # n_val: int, adj_matrix: list of 8 lists of 8 ints (0/1)
        if has_n:
            dut.n.value = n_val
        for i in range(8):
            if i < len(rows):
                rows[i].value = adj_matrix[i]
        if has_start:
            dut.start.value = 1
            if has_clk:
                await RisingEdge(dut.clk)
            else:
                await Timer(CLK_PERIOD_NS, units='ns')
            dut.start.value = 0
    
    async def wait_for_done():
        if not has_done:
            await Timer(100, units='ns')
            return
        for cycle in range(MAX_CYCLES):
            if has_clk:
                await RisingEdge(dut.clk)
            else:
                await Timer(CLK_PERIOD_NS, units='ns')
            if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                return
        raise TestFailure(f"Timeout: done not asserted after {MAX_CYCLES} cycles")
    
    async def read_result():
        if not has_valid or not has_result:
            return None
        valid = int(dut.valid.value)
        result = int(dut.result.value)
        return valid, result
    
    def pack_string(s):
        """Pack string like 'aa' into 16-bit result."""
        result = 0
        for i, ch in enumerate(s):
            if ch == 'a':
                code = 0
            elif ch == 'b':
                code = 1
            elif ch == 'c':
                code = 2
            else:
                code = 0
            result |= code << (2*i)
        return result
    
    def unpack_result(result, n):
        """Unpack 16-bit result to string of length n."""
        s = []
        for i in range(n):
            code = (result >> (2*i)) & 3
            if code == 0:
                s.append('a')
            elif code == 1:
                s.append('b')
            elif code == 2:
                s.append('c')
            else:
                s.append('?')
        return ''.join(s)
    
    # Define test cases: (n, edges, expected_valid, expected_string)
    # edges: list of (u,v) 1-indexed
    test_cases = [
        (2, [(1,2)], True, "aa"),
        (4, [(1,2),(1,3),(1,4)], False, None),
        (4, [(1,2),(1,3),(1,4),(3,4)], True, "bacc"),
        (1, [], True, "a"),
        (8, [], True, "aaaaaaaa"),  # will be replaced with complete graph
        (4, [(4,3),(2,4),(2,3)], True, "accc"),
        (4, [(4,3),(1,2)], True, "aacc"),
        (5, [(1,2),(1,3),(4,5)], False, None),
    ]
    
    # Generate complete graph edges for n=8
    complete_edges = []
    for i in range(1,9):
        for j in range(i+1,9):
            complete_edges.append((i,j))
    test_cases[4] = (8, complete_edges, True, "aaaaaaaa")
    
    # Run tests
    for idx, (n, edges, exp_valid, exp_str) in enumerate(test_cases):
        cocotb.log.info(f"--- Test case {idx+1}: n={n}, edges={edges} ---")
        
        # Build adjacency matrix (8x8)
        adj_matrix = [[0]*8 for _ in range(8)]
        for (u,v) in edges:
            u_idx = u-1
            v_idx = v-1
            adj_matrix[u_idx][v_idx] = 1
            adj_matrix[v_idx][u_idx] = 1
        
        # Reset
        await reset_dut()
        
        # Start computation
        await start_computation(n, [row for row in adj_matrix])
        
        # Wait for done
        await wait_for_done()
        
        # Read result
        valid, result = await read_result()
        
        # Verify
        if exp_valid:
            if not valid:
                raise TestFailure(f"Test {idx+1}: Expected valid but got invalid")
            got_str = unpack_result(result, n)
            if got_str != exp_str:
                raise TestFailure(f"Test {idx+1}: Expected string {exp_str}, got {got_str}")
            cocotb.log.info(f"Test {idx+1} PASS: string = {got_str}")
        else:
            if valid:
                raise TestFailure(f"Test {idx+1}: Expected invalid but got valid")
            cocotb.log.info(f"Test {idx+1} PASS: correctly invalid")
        
        await Timer(100, units='ns')
    
    cocotb.log.info("All tests passed!")
