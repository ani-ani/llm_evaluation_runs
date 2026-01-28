import cocotb
from cocotb.triggers import Timer, RisingEdge, ClockCycles
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Helper functions
def is_value_defined(v):
    try:
        int(v)
        return True
    except ValueError:
        return False

def clamp_to_width(v, bits):
    max_val = (1 << bits) - 1
    return min(max_val, max(0, v))

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

DATA_WIDTH = 8
CLK_NS = 10
MAX_CYCLES = 2000

async def reset_dut(dut):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    if has_signal(dut, 'adjacency_valid'):
        dut.adjacency_valid.value = 0
    for _ in range(2):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def load_adjacency(dut, adjacency_list, n_rooms):
    """
    adjacency_list: list of lists, where inner list contains neighbor indices (0-based)
    """
    # First, wait for start to be consumed or ensure state is ready
    # Here we assume the module has a simple input buffer mechanism.
    # We need to provide data for room 0, then 1, etc.
    for i in range(n_rooms):
        neighbors = adjacency_list[i]
        dut.room_idx.value = i
        dut.degree.value = len(neighbors)
        # Fill connections array (max 8)
        # Assuming connections is a flat array or indexed signal
        # We need to access individual elements or packed value
        # Let's assume individual signals connections[0]..connections[7]
        for j in range(8):
            val = neighbors[j] if j < len(neighbors) else 0
            if has_signal(dut, f'connections_{j}'):
                getattr(dut, f'connections_{j}').value = val
            elif has_signal(dut, 'connections'):
                # If it's an array accessor
                try:
                    dut.connections[j].value = val
                except Exception:
                    pass # Fallback
        
        dut.adjacency_valid.value = 1
        await RisingEdge(dut.clk)
        dut.adjacency_valid.value = 0
        await RisingEdge(dut.clk) # Buffer between room inputs

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_maze_isomorphism(dut):
    # Setup Clock
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    await reset_dut(dut)

    # Test Case 1: Sample Input (simplified for n<=16)
    # Original sample has 13 nodes. We'll map it or use a smaller case.
    # Case 1: Two equivalent pairs
    # Room 0: neighbors [1]
    # Room 1: neighbors [0, 2]
    # Room 2: neighbors [1]
    # Room 3: neighbors [4]
    # Room 4: neighbors [3, 5]
    # Room 5: neighbors [4]
    # Rooms 0,2 are equivalent. Rooms 3,5 are equivalent.
    # Expected output: matches (0,2), (3,5)
    
    adj = [
        [1],      # Room 0
        [0, 2],   # Room 1
        [1],      # Room 2 (Eq to 0)
        [4],      # Room 3
        [3, 5],   # Room 4
        [4],      # Room 5 (Eq to 3)
        []        # Room 6 (Differently connected)
    ]
    n = 7

    # Start processing
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

    # Load Adjacency
    await load_adjacency(dut, adj, n)

    # Collect Results
    matches = {} # Map room -> list of matches
    done_seen = False
    none_seen = False

    for cycle in range(MAX_CYCLES):
        await RisingEdge(dut.clk)
        
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            done_seen = True
            
        if is_value_defined(dut.none.value) and int(dut.none.value) == 1:
            none_seen = True

        if is_value_defined(dut.result_valid.value) and int(dut.result_valid.value) == 1:
            r1 = int(dut.result_room.value)
            r2 = int(dut.result_match.value)
            if r1 not in matches:
                matches[r1] = []
            matches[r1].append(r2)
        
        if done_seen:
            break

    if not done_seen:
        raise TestFailure("Did not see 'done' signal")

    if none_seen:
        raise TestFailure("'none' asserted, but expected matches")

    # Verify Results
    # We expect: 0->2, 2->0 (might be filtered by output logic to 0->2 only)
    # And 3->5, 5->3
    # The spec says "Order the sets by their smallest room numbers."
    # Output format: "result_room result_match"
    # If logic outputs all pairs: (0,2), (2,0), (3,5), (5,3)
    # If logic outputs minimal pairs: (0,2), (3,5)
    
    valid_sets = 0
    if 0 in matches and 2 in matches[0]:
        valid_sets += 1
    if 3 in matches and 5 in matches[3]:
        valid_sets += 1
    
    # Check for (2,0) and (5,3) as well if implementation is symmetric
    if 2 in matches and 0 in matches[2]:
        valid_sets += 1
    if 5 in matches and 3 in matches[5]:
        valid_sets += 1

    # We expect exactly 4 pulses if symmetric, or 2 if minimal pairs.
    # Let's count the unique sets.
    unique_sets = []
    seen_rooms = set()
    
    # Collect all rooms that have matches
    all_match_rooms = set(matches.keys())
    for r in all_match_rooms:
        if r in seen_rooms:
            continue
        # Find connected component
        component = {r}
        queue = [r]
        while queue:
            curr = queue.pop()
            if curr in matches:
                for neighbor in matches[curr]:
                    if neighbor not in component:
                        component.add(neighbor)
                        queue.append(neighbor)
        seen_rooms.update(component)
        if len(component) >= 2:
            unique_sets.append(sorted(list(component)))
    
    unique_sets.sort(key=lambda x: x[0])
    
    # Expected: [[0,2], [3,5]]
    if len(unique_sets) != 2:
        raise TestFailure(f"Expected 2 sets, got {len(unique_sets)}: {unique_sets}")
    
    if unique_sets[0] != [0, 2]:
        raise TestFailure(f"First set mismatch: {unique_sets[0]}")
    if unique_sets[1] != [3, 5]:
        raise TestFailure(f"Second set mismatch: {unique_sets[1]}")

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_maze_isomorphism_none(dut):
    # Setup Clock
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    await reset_dut(dut)

    # Test Case 2: No equivalents
    # Room 0: [1]
    # Room 1: [0, 2]
    # Room 2: [1]
    # Room 3: [1] (Wait, Room 3 has degree 1, but neighbor is 1. Room 0 has degree 1 neighbor 1? No, Room 0 neighbor 1. Room 3 neighbor 1. 
    # Let's make them distinct by degree or structure)
    # Room 0: [1] (deg 1)
    # Room 1: [0, 2] (deg 2)
    # Room 2: [1] (deg 1) -> Symmetric to 0? No, Room 0 connects to Room 1 (deg 2). Room 2 connects to Room 1 (deg 2). 
    # Actually 0 and 2 are symmetric (Root 0 sees deg 2 neighbor, Root 2 sees deg 2 neighbor). 
    # To make them NOT symmetric, we need a longer chain or unique structure.
    # Chain: 0-1-2-3
    # Room 0: [1]
    # Room 1: [0, 2]
    # Room 2: [1, 3]
    # Room 3: [2]
    # 0 sees deg 2 neighbor. 3 sees deg 2 neighbor. 
    # 0 sees root deg 1. 3 sees root deg 1. 
    # 0's neighbor (1) has neighbors [0,2] -> [1, 1] (deg 1, deg 1).
    # 3's neighbor (2) has neighbors [1,3] -> [2, 2] (deg 2, deg 2).
    # Wait, 1 has neighbors 0(deg1) and 2(deg2) -> [1,2].
    # 2 has neighbors 1(deg2) and 3(deg1) -> [2,1] -> sorted [1,2].
    # So 0 and 3 are symmetric in a chain 0-1-2-3? 
    # Usually 0 and 3 are symmetric in a simple path of length 3 (edges). 
    # Let's use a tree: 0-1, 0-2. 1-3, 2-4. 
    # 0: deg 2. 1: deg 2. 2: deg 2. 3: deg 1. 4: deg 1.
    # 1 and 2 might be symmetric? 
    # Let's just use a simple case where no pair exists.
    # Room 0: [1]
    # Room 1: [0, 2]
    # Room 2: [1, 3, 4]
    # Room 3: [2]
    # Room 4: [2]
    # 3 and 4 are symmetric? Yes, both connect to 2 (deg 3).
    # Let's make 4 connect to 2 and 5.
    # Room 5: [4]
    # Now 3 and 5 are symmetric? 
    # 3 sees neighbor 2 (deg 3). 5 sees neighbor 4 (deg 2).
    # Distinct.
    
    adj = [
        [1],          # Room 0
        [0, 2],       # Room 1
        [1, 3, 4],    # Room 2
        [2],          # Room 3
        [2, 5],       # Room 4
        [4]           # Room 5
    ]
    n = 6

    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

    await load_adjacency(dut, adj, n)

    matches = {}
    done_seen = False
    none_seen = False

    for cycle in range(MAX_CYCLES):
        await RisingEdge(dut.clk)
        
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            done_seen = True
            
        if is_value_defined(dut.none.value) and int(dut.none.value) == 1:
            none_seen = True

        if is_value_defined(dut.result_valid.value) and int(dut.result_valid.value) == 1:
            r1 = int(dut.result_room.value)
            r2 = int(dut.result_match.value)
            if r1 not in matches:
                matches[r1] = []
            matches[r1].append(r2)
        
        if done_seen:
            break

    if not done_seen:
        raise TestFailure("Did not see 'done' signal")

    if not none_seen:
        raise TestFailure("'none' not asserted, but expected no matches")
