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
# GEOMETRY AND ADJACENCY COMPUTATION
# ============================================================================

def is_visible(ax, ay, bx, by, mountains):
    """Check if line segment (ax,ay)-(bx,by) is not blocked by any mountain."""
    dx = bx - ax
    dy = by - ay
    len2 = dx*dx + dy*dy
    for (cx, cy, r) in mountains:
        dxc = cx - ax
        dyc = cy - ay
        dot = dxc*dx + dyc*dy
        if dot <= 0:
            # Closest to A
            dist2 = dxc*dxc + dyc*dyc
            if dist2 < r*r:
                return False
        elif dot >= len2:
            # Closest to B
            dxb = cx - bx
            dyb = cy - by
            dist2 = dxb*dxb + dyb*dyb
            if dist2 < r*r:
                return False
        else:
            # Closest to line segment
            cross = dx*dyc - dy*dxc
            if cross*cross < r*r * len2:
                return False
    return True

def compute_adjacency(n, beacons, mountains):
    """Compute adjacency matrix (n x n) as list of n integers (each 8-bit)."""
    adj = [0] * n
    for i in range(n):
        for j in range(i+1, n):
            if is_visible(beacons[i][0], beacons[i][1], beacons[j][0], beacons[j][1], mountains):
                # Set both directions
                adj[i] |= (1 << j)
                adj[j] |= (1 << i)
    return adj

def pack_adjacency(adj):
    """Pack adjacency matrix (list of n 8-bit ints) into 64-bit integer."""
    packed = 0
    for i, row in enumerate(adj):
        packed |= (row << (8*i))
    return packed

def compute_expected_riders(n, adj):
    """Compute number of riders needed = number of components - 1."""
    parent = list(range(n))
    def find(x):
        while parent[x] != x:
            parent[x] = parent[parent[x]]  # Path compression
            x = parent[x]
        return x
    def union(x, y):
        rx, ry = find(x), find(y)
        if rx != ry:
            parent[ry] = rx
    for i in range(n):
        for j in range(i+1, n):
            if (adj[i] >> j) & 1:
                union(i, j)
    roots = {find(i) for i in range(n)}
    components = len(roots)
    return components - 1

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

async def wait_for_done(dut, max_cycles=1000):
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
async def test_beacon_connectivity(dut):
    """Main test function for beacon connectivity module."""
    
    # Detect module type (sequential)
    is_sequential = has_signal(dut, 'clk')
    
    if is_sequential:
        # Start clock
        cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
        # Reset
        await reset_dut(dut)
    
    # Define test cases: (input_string, expected_output)
    test_cases = [
        (
            "6 3\n1 8\n5 4\n7 7\n9 2\n16 6\n17 10\n4 7 2\n6 3 1\n12 6 3\n",
            "2\n"
        ),
        (
            "4 4\n0 4\n8 4\n4 0\n4 8\n2 2 1\n6 2 1\n2 6 1\n6 6 1\n",
            "1\n"
        ),
    ]
    
    passed = 0
    failed = 0
    
    for idx, (input_str, expected_str) in enumerate(test_cases):
        cocotb.log.info(f"\nTest case {idx+1}")
        
        # Parse input
        lines = input_str.strip().split('\n')
        first_line = lines[0].split()
        n = int(first_line[0])
        m = int(first_line[1])
        
        beacons = []
        for i in range(1, 1+n):
            x, y = map(int, lines[i].split())
            beacons.append((x, y))
        
        mountains = []
        for i in range(1+n, 1+n+m):
            cx, cy, r = map(int, lines[i].split())
            mountains.append((cx, cy, r))
        
        # Compute adjacency matrix and expected riders
        adj = compute_adjacency(n, beacons, mountains)
        expected_riders = compute_expected_riders(n, adj)
        expected_riders_check = int(expected_str.strip())
        
        if expected_riders != expected_riders_check:
            cocotb.log.error(f"Consistency error: computed {expected_riders} vs expected {expected_riders_check}")
            failed += 1
            continue
        
        # Pack adjacency matrix
        packed_matrix = pack_adjacency(adj)
        cocotb.log.info(f"  Packed matrix: 0x{packed_matrix:016X}")
        
        # Drive DUT
        if is_sequential:
            # Assign inputs
            dut.num_beacons.value = n
            dut.adj_matrix.value = packed_matrix
            
            # Start computation
            await start_computation(dut)
            
            # Wait for done
            try:
                await wait_for_done(dut, max_cycles=5000)
            except TestFailure as e:
                cocotb.log.error(f"  FAIL: {e}")
                failed += 1
                continue
            
            # Read result
            if not is_value_defined(dut.result.value):
                cocotb.log.error("  FAIL: Result is undefined (X/Z)")
                failed += 1
                continue
            
            result = int(dut.result.value)
        else:
            # Combinational module (not expected)
            await Timer(100, units='ns')
            if not is_value_defined(dut.result.value):
                cocotb.log.error("  FAIL: Result is undefined (X/Z)")
                failed += 1
                continue
            result = int(dut.result.value)
        
        # Verify
        if result != expected_riders:
            cocotb.log.error(f"  FAIL: Expected {expected_riders}, got {result}")
            failed += 1
        else:
            cocotb.log.info(f"  PASS: result = {result}")
            passed += 1
    
    # Summary
    cocotb.log.info(f"\n{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")