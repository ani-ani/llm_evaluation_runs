import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

# ============================================================================
# CONFIGURATION
# ============================================================================
N = 8
DEG_W = 4
SIG_W = 32
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
    """Clamp value to fit within specified bit width (unsigned)."""
    max_val = (1 << bits) - 1
    return min(max_val, max(0, value))

# ============================================================================
# ARRAY WRITE HELPERS (CRITICAL - FOLLOW RULE B2)
# ============================================================================

async def write_degree_array(dut, degrees):
    """Write degrees to DUT using element-wise assignment."""
    for i in range(N):
        # Try individual ports first: degree_0, degree_1, ...
        port_name = f'degree_{i}'
        if has_signal(dut, port_name):
            getattr(dut, port_name).value = clamp_to_width(degrees[i], DEG_W)
        else:
            # Fallback to indexed array
            try:
                dut.degree[i].value = clamp_to_width(degrees[i], DEG_W)
            except (AttributeError, TypeError):
                raise TestFailure(f"Cannot access degree[{i}] or {port_name}")

async def write_adj_matrix(dut, adj):
    """Write adjacency matrix to DUT using element-wise assignment."""
    for i in range(N):
        for j in range(N):
            # Try individual port: adj_0_0, adj_0_1, ...
            port_name = f'adj_{i}_{j}'
            if has_signal(dut, port_name):
                getattr(dut, port_name).value = adj[i][j]
            else:
                # Fallback to 2D array
                try:
                    dut.adj[i][j].value = adj[i][j]
                except (AttributeError, TypeError):
                    raise TestFailure(f"Cannot access adj[{i}][{j}] or {port_name}")

async def read_signature_array(dut):
    """Read signatures from DUT, return list of values."""
    signatures = []
    for i in range(N):
        # Try individual ports: signature_0, signature_1, ...
        port_name = f'signature_{i}'
        if has_signal(dut, port_name):
            val = getattr(dut, port_name).value
            if is_value_defined(val):
                signatures.append(int(val))
            else:
                signatures.append(None)
        else:
            # Fallback to indexed array
            try:
                val = dut.signature[i].value
                if is_value_defined(val):
                    signatures.append(int(val))
                else:
                    signatures.append(None)
            except (AttributeError, TypeError):
                signatures.append(None)
    return signatures

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
# MAZE EQUIVALENCE LOGIC
# ============================================================================

def compute_expected_signature(degrees, adj, room_idx):
    """Compute expected signature for a room."""
    own_deg = degrees[room_idx]
    neighbor_sum = 0
    
    for neighbor in range(N):
        if adj[room_idx][neighbor] == 1:
            neighbor_sum += degrees[neighbor]
    
    # Signature = own_degree + (neighbor_sum << 4)
    signature = own_deg + (neighbor_sum << 4)
    return signature

def group_rooms_by_signature(signatures):
    """Group rooms with same signature, ignoring singletons."""
    # Create dictionary: signature -> list of rooms
    sig_to_rooms = {}
    for room, sig in enumerate(signatures):
        if sig is not None:
            if sig not in sig_to_rooms:
                sig_to_rooms[sig] = []
            sig_to_rooms[sig].append(room + 1)  # 1-indexed for output
    
    # Filter out singletons and sort
    groups = [sorted(rooms) for rooms in sig_to_rooms.values() if len(rooms) > 1]
    groups.sort(key=lambda g: g[0])  # Sort by smallest room
    
    return groups

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_maze_analyzer(dut):
    """Main test for MazeAnalyzer module."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test Case 1: Sample Input (scaled to 8 rooms max)
    # Original: 13 rooms -> scaled to 8 rooms
    # Grouping: 2,4 (same), 5,6 (same), 7-13 (same) -> scaled
    
    # Define test cases: (degrees, adjacency_matrix, description)
    # Adjacency is symmetric and unweighted
    
    test_cases = [
        (
            # 4 rooms: room 0-1 same, room 2-3 same
            [2, 2, 1, 1],  # degrees
            [
                [0, 1, 1, 0],  # room 0 connects to 1,2
                [1, 0, 0, 1],  # room 1 connects to 0,3
                [1, 0, 0, 0],  # room 2 connects to 0
                [0, 1, 0, 0],  # room 3 connects to 1
            ],
            "Two pairs of equivalent rooms"
        ),
        (
            # 3 rooms: all same
            [2, 2, 2],
            [
                [0, 1, 1],
                [1, 0, 1],
                [1, 1, 0],
            ],
            "Three equivalent rooms"
        ),
        (
            # 2 rooms: not equivalent
            [1, 0],
            [
                [0, 1],
                [1, 0],
            ],
            "No equivalence (singletons)"
        ),
        (
            # 8 rooms: complex pattern
            [3, 3, 2, 2, 2, 2, 2, 2],
            [
                [0, 1, 1, 0, 0, 0, 0, 1],  # room 0
                [1, 0, 0, 1, 0, 0, 1, 0],  # room 1
                [1, 0, 0, 0, 1, 0, 0, 0],  # room 2
                [0, 1, 0, 0, 0, 1, 0, 0],  # room 3
                [0, 0, 1, 0, 0, 0, 1, 0],  # room 4
                [0, 0, 0, 1, 0, 0, 0, 1],  # room 5
                [0, 1, 0, 0, 1, 0, 0, 0],  # room 6
                [1, 0, 0, 0, 0, 1, 0, 0],  # room 7
            ],
            "8-room maze with multiple groups"
        ),
    ]
    
    for test_idx, (degrees, adj, description) in enumerate(test_cases):
        cocotb.log.info(f"\n{'='*60}")
        cocotb.log.info(f"Test Case {test_idx + 1}: {description}")
        cocotb.log.info(f"{'='*60}")
        
        # Write inputs
        await write_degree_array(dut, degrees)
        await write_adj_matrix(dut, adj)
        
        # Wait 2 cycles for propagation
        for _ in range(2):
            await RisingEdge(dut.clk)
        
        # Start computation
        await start_computation(dut)
        
        # Wait for completion
        await wait_for_done(dut)
        
        # Read signatures
        signatures = await read_signature_array(dut)
        
        # Verify signatures are defined
        undefined = [i for i, s in enumerate(signatures) if s is None]
        if undefined:
            raise TestFailure(f"Test {test_idx+1}: Undefined signatures at indices {undefined}")
        
        # Compute expected signatures
        expected_sigs = []
        for room_idx in range(len(degrees)):
            sig = compute_expected_signature(degrees, adj, room_idx)
            expected_sigs.append(sig)
        
        # Compare
        mismatches = []
        for i, (actual, expected) in enumerate(zip(signatures, expected_sigs)):
            if actual != expected:
                mismatches.append((i, actual, expected))
        
        if mismatches:
            raise TestFailure(
                f"Test {test_idx+1}: Signature mismatches: "
                f"{[(i, act, exp) for i, act, exp in mismatches]}"
            )
        
        # Log signatures
        cocotb.log.info("Computed signatures:")
        for i, sig in enumerate(signatures):
            cocotb.log.info(f"  Room {i+1}: {sig} (0x{sig:08X})")
        
        # Group rooms
        groups = group_rooms_by_signature(signatures)
        
        # Log groups
        if groups:
            cocotb.log.info("Equivalent room groups:")
            for group in groups:
                cocotb.log.info(f"  {group}")
        else:
            cocotb.log.info("No equivalent rooms (all singletons)")
        
        cocotb.log.info(f"Test {test_idx+1}: PASS")
    
    cocotb.log.info(f"\n{'='*60}")
    cocotb.log.info("ALL TESTS PASSED")
    cocotb.log.info(f"{'='*60}")

# ============================================================================
# RANDOMIZED STRESS TEST
# ============================================================================

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_maze_stress(dut):
    """Stress test with random mazes."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    await reset_dut(dut)
    
    random.seed(42)  # Deterministic randomness
    
    for stress_iter in range(5):  # 5 random mazes
        # Generate random valid maze
        n = random.randint(3, N)  # 3 to 8 rooms
        degrees = []
        adj = [[0]*N for _ in range(N)]
        
        # Generate random degrees (0-3 for small graphs)
        for i in range(n):
            deg = random.randint(0, 3)
            degrees.append(deg)
        
        # Generate connections (ensure symmetry)
        for i in range(n):
            if degrees[i] > 0:
                # Connect to random other rooms
                possible = [j for j in range(n) if j != i]
                if len(possible) >= degrees[i]:
                    neighbors = random.sample(possible, degrees[i])
                    for nb in neighbors:
                        adj[i][nb] = 1
                        adj[nb][i] = 1  # Ensure symmetry
        
        # Fix degrees to match actual connections
        for i in range(n):
            degrees[i] = sum(adj[i])
        
        cocotb.log.info(f"\nStress Test {stress_iter+1}: {n} rooms")
        
        # Write inputs
        await write_degree_array(dut, degrees)
        await write_adj_matrix(dut, adj)
        
        # Wait and compute
        for _ in range(2):
            await RisingEdge(dut.clk)
        
        await start_computation(dut)
        await wait_for_done(dut)
        signatures = await read_signature_array(dut)
        
        # Verify all signatures defined
        for i, sig in enumerate(signatures):
            if sig is None:
                raise TestFailure(f"Stress {stress_iter+1}: Undefined signature at room {i}")
        
        # Compute expected and compare
        for room_idx in range(n):
            expected = compute_expected_signature(degrees, adj, room_idx)
            if signatures[room_idx] != expected:
                raise TestFailure(
                    f"Stress {stress_iter+1}: Room {room_idx} sig mismatch: "
                    f"got {signatures[room_idx]}, expected {expected}"
                )
        
        cocotb.log.info(f"  All {n} rooms computed correctly")
    
    cocotb.log.info("\nStress tests completed successfully")
