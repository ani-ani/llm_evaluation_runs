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
# ARRAY ACCESS HELPERS
# ============================================================================

async def write_adj_matrix(dut, n, adj):
    """Write adjacency matrix to dut.adj[i] for i in 0..MAX_N-1."""
    MAX_N = 8
    for i in range(MAX_N):
        if i < n:
            # Only lowest n bits are used, but we assign full 8-bit value
            dut.adj[i].value = clamp_to_width(adj[i], 8)
        else:
            dut.adj[i].value = 0

async def read_group_ids(dut, n):
    """Read group_id array for nodes 0..n-1."""
    group_ids = []
    for i in range(n):
        if is_value_defined(dut.group_id[i].value):
            group_ids.append(int(dut.group_id[i].value))
        else:
            group_ids.append(None)
    return group_ids

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

async def wait_for_done(dut, max_cycles=10000):
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
# PARTITION VALIDATION
# ============================================================================

def validate_partition(n, p, q, adj, group_ids):
    """Check if the partition satisfies the constraints."""
    if any(g is None for g in group_ids[:n]):
        return False, "Some group IDs are undefined"
    
    groups = {}
    for i in range(n):
        gid = group_ids[i]
        if gid not in groups:
            groups[gid] = []
        groups[gid].append(i)
    
    # Check group size
    for gid, members in groups.items():
        if len(members) > p:
            return False, f"Group {gid} size {len(members)} > p={p}"
    
    # Check cross-edges
    for gid, members in groups.items():
        cross = 0
        for u in members:
            for v in range(n):
                if v not in members:  # outside group
                    # Check if u is friends with v (symmetric, but we check both directions)
                    if (adj[u] >> v) & 1:
                        cross += 1
        if cross > q:
            return False, f"Group {gid} has {cross} cross-edges > q={q}"
    
    return True, "Valid partition"

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_friend_group_checker(dut):
    """Test the friend_group_checker module with the given examples."""
    
    # Configuration
    MAX_N = 8
    CLK_PERIOD_NS = 10
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test cases: (n, p, q, adj_matrix, expected_result, description)
    # adj_matrix is a list of n integers, each is an 8-bit bitmask of friends
    test_cases = [
        (
            4, 2, 1,
            [
                0b00000010,  # 0: friends with 1
                0b00000101,  # 1: friends with 0,2
                0b00001010,  # 2: friends with 1,3
                0b00000100,  # 3: friends with 2
            ],
            True,
            "Sample 1: home"
        ),
        (
            5, 2, 1,
            [
                0b00000010,  # 0: friends with 1
                0b00000101,  # 1: friends with 0,2
                0b00001010,  # 2: friends with 1,3
                0b00010100,  # 3: friends with 2,4
                0b00001000,  # 4: friends with 3
            ],
            False,
            "Sample 2: detention"
        ),
        (
            3, 3, 3,
            [
                0b00000110,  # 0: friends with 1,2
                0b00000101,  # 1: friends with 0,2
                0b00000011,  # 2: friends with 0,1
            ],
            False,
            "Sample 3: detention"
        ),
    ]
    
    for idx, (n, p, q, adj, expected_home, description) in enumerate(test_cases):
        cocotb.log.info(f"\n{'='*60}")
        cocotb.log.info(f"Test {idx+1}: {description}")
        cocotb.log.info(f"  n={n}, p={p}, q={q}")
        
        # Write inputs
        dut.n.value = n
        dut.p.value = p
        dut.q.value = q
        await write_adj_matrix(dut, n, adj)
        
        # Start computation
        await start_computation(dut)
        
        # Wait for done
        await wait_for_done(dut, max_cycles=20000)
        
        # Read outputs
        if not is_value_defined(dut.valid.value):
            raise TestFailure(f"Valid signal is undefined (X/Z)")
        
        valid = bool(int(dut.valid.value))
        
        # Check expected result
        if valid != expected_home:
            if expected_home:
                raise TestFailure(f"Expected valid=1 (home), got valid=0 (detention)")
            else:
                raise TestFailure(f"Expected valid=0 (detention), got valid=1 (home)")
        
        if valid:
            # Read group IDs
            group_ids = await read_group_ids(dut, n)
            cocotb.log.info(f"  Group IDs: {group_ids}")
            
            # Validate partition
            ok, msg = validate_partition(n, p, q, adj, group_ids)
            if not ok:
                raise TestFailure(f"Invalid partition: {msg}")
            
            cocotb.log.info(f"  PASS: {msg}")
        else:
            cocotb.log.info(f"  PASS: correctly detected no valid partition (detention)")
    
    cocotb.log.info(f"\n{'='*60}")
    cocotb.log.info("All tests passed!")
