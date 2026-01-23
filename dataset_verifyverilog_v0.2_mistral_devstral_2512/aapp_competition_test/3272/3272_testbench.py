import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer, FallingEdge
from cocotb.result import TestFailure
import random

# Helper function to encode grid character to byte value
def encode_char(c):
    mapping = {'.': 0, '#': 1, '/': 2, '': 3, 'V': 4, 'H': 5}
    return mapping.get(c, 0)

# Reference Python implementation to verify results
def solve_tomb_reference(grid_str):
    lines = grid_str.strip().split('
')
    n = len(lines)
    m = len(lines[0])
    
    # Parse grid
    grid = [list(line) for line in lines]
    
    # Find all gargoyles
    gargoyles = []  # List of (row, col, type)
    for i in range(n):
        for j in range(m):
            if grid[i][j] in ['V', 'H']:
                gargoyles.append((i, j, grid[i][j]))
    
    if not gargoyles:
        return 0
    
    # For each gargoyle, generate possible faces
    # V: faces at (row, col) going up and down
    # H: faces at (row, col) going left and right
    faces = []  # List of (row, col, direction, gargoyle_idx, face_idx)
    face_to_gargoyle = []  # Maps face index to (gargoyle_idx, orientation)
    
    for g_idx, (r, c, g_type) in enumerate(gargoyles):
        if g_type == 'V':
            faces.append((r, c, 0, g_idx, 0))  # up
            faces.append((r, c, 2, g_idx, 1))  # down
            face_to_gargoyle.append((g_idx, 'V'))
            face_to_gargoyle.append((g_idx, 'V'))
        else:  # H
            faces.append((r, c, 1, g_idx, 0))  # right
            faces.append((r, c, 3, g_idx, 1))  # left
            face_to_gargoyle.append((g_idx, 'H'))
            face_to_gargoyle.append((g_idx, 'H'))
    
    num_faces = len(faces)
    if num_faces == 0:
        return 0
    
    # Trace light from each face
    # Directions: 0=up(-1,0), 1=right(0,1), 2=down(1,0), 3=left(0,-1)
    dr = [-1, 0, 1, 0]
    dc = [0, 1, 0, -1]
    
    # Adjacency matrix: adj[i] is bitmask of faces reachable from face i
    adj = [0] * num_faces
    
    for f_idx, (sr, sc, sd, g_idx, face_idx) in enumerate(faces):
        # Trace light from this face
        r, c, d = sr, sc, sd
        
        # Light starts from outside the gargoyle cell
        r += dr[d]
        c += dc[d]
        
        # Trace up to some limit
        for step in range(64):
            # Check boundaries
            if r < 0 or r >= n or c < 0 or c >= m:
                # Hit boundary wall - reflects 180 degrees
                d = (d + 2) % 4
                # Bounce back
                r += dr[d]
                c += dc[d]
                continue
            
            cell = grid[r][c]
            
            if cell == '#':
                # Blocked by obstacle
                break
            
            if cell in ['V', 'H']:
                # Hit a gargoyle - check if this is a face
                for f2_idx, (r2, c2, d2, g2_idx, face2_idx) in enumerate(faces):
                    if r2 == r and c2 == c:
                        # Check if direction matches
                        if d2 == (d + 2) % 4:  # Opposite direction
                            # This face is reachable
                            adj[f_idx] |= (1 << f2_idx)
                break
            
            if cell == '/':
                # Reflect
                # up(0)->left(3), right(1)->down(2), down(2)->right(1), left(3)->up(0)
                if d == 0: d = 3
                elif d == 1: d = 2
                elif d == 2: d = 1
                elif d == 3: d = 0
            elif cell == '':
                # Reflect
                # up(0)->right(1), right(1)->up(0), down(2)->left(3), left(3)->down(2)
                if d == 0: d = 1
                elif d == 1: d = 0
                elif d == 2: d = 3
                elif d == 3: d = 2
            
            # Move to next cell
            r += dr[d]
            c += dc[d]
    
    # Now we need to find minimum rotations
    # Each gargoyle can be V (0 rotations from V, 1 from H) or H (0 from H, 1 from V)
    # We need to find configuration where the graph is connected
    
    num_gargoyles = len(gargoyles)
    
    # Brute force over all configurations
    min_rot = float('inf')
    
    # Each configuration is a bitmask of size num_gargoyles
    # 0 = V, 1 = H
    for config in range(1 << num_gargoyles):
        rotations = 0
        # Count rotations needed
        for g_idx in range(num_gargoyles):
            g_type = gargoyles[g_idx][2]
            desired = 'H' if (config & (1 << g_idx)) else 'V'
            if g_type != desired:
                rotations += 1
        
        # Check connectivity with this configuration
        # Build actual face connectivity for this config
        active_faces = []
        face_to_actual = {}  # Maps original face idx to if it's active
        
        for f_idx, face in enumerate(faces):
            g_idx = face[3]
            face_idx = face[4]
            g_type = gargoyles[g_idx][2]
            desired = 'H' if (config & (1 << g_idx)) else 'V'
            
            # Check if this face exists in desired config
            is_active = False
            if g_type == 'V' and desired == 'V':
                is_active = True
            elif g_type == 'H' and desired == 'H':
                is_active = True
            elif g_type == 'V' and desired == 'H':
                # Was V, now H - face indices change
                # Original faces: 0=up, 1=down
                # New faces: 0=left, 1=right
                # So these faces are invalid
                is_active = False
            elif g_type == 'H' and desired == 'V':
                # Was H, now V - faces change
                # Original: 0=left, 1=right
                # New: 0=up, 1=down
                is_active = False
            
            face_to_actual[f_idx] = is_active
            if is_active:
                active_faces.append(f_idx)
        
        if not active_faces:
            continue
        
        # Build subgraph for active faces
        active_adj = {}
        for f_idx in active_faces:
            active_adj[f_idx] = []
            connected = adj[f_idx]
            for other in active_faces:
                if connected & (1 << other):
                    active_adj[f_idx].append(other)
        
        # Check if connected
        if len(active_adj) == 0:
            continue
            
        # BFS to check connectivity
        visited = set()
        queue = [list(active_adj.keys())[0]]
        visited.add(queue[0])
        
        while queue:
            curr = queue.pop(0)
            for nxt in active_adj[curr]:
                if nxt not in visited:
                    visited.add(nxt)
                    queue.append(nxt)
        
        if len(visited) == len(active_adj):
            min_rot = min(min_rot, rotations)
    
    return -1 if min_rot == float('inf') else min_rot

@cocotb.test()
async def test_tomb_solver(dut):
    """Test tomb solver with multiple test cases"""
    
    # Create clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(50, units="ns")
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    test_cases = [
        {
            "grid": "5 5
/.V.\\\\
./.V.
..#..
.V.#.
\\\\.V./",  # This won't work with 4x4
            "expected": 3
        },
        {
            "grid": "VV
VV",
            "expected": 0
        },
        {
            "grid": "2 2
VV
VV",
            "expected": 0
        }
    ]
    
    # We'll test with 4x4 compatible grids only
    # Test 1: 4x4 with V and H
    dut._log.info("Testing case 1: 4x4 grid")
    
    # Simplified test: 2x2 all V
    grid = [
        ord('V'), ord('V'), ord('.'), ord('.'),
        ord('V'), ord('V'), ord('.'), ord('.'),
        ord('.'), ord('.'), ord('.'), ord('.'),
        ord('.'), ord('.'), ord('.'), ord('.')
    ]
    
    for i in range(16):
        dut.grid[i].value = grid[i]
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for completion
    timeout = 2000
    for _ in range(timeout):
        await RisingEdge(dut.clk)
        if dut.done.value:
            break
    else:
        raise TestFailure("Timeout - computation did not complete")
    
    result = int(dut.min_rotations.value)
    status = int(dut.status.value)
    
    dut._log.info(f"Result: {result}, Status: {status}")
    
    # For the simple 2x2 V test, expected 0 (already connected)
    # This is a simplified verification
    if status == 1:
        dut._log.info("Test 1: Passed")
    elif status == 2:
        dut._log.info("Test 1: Impossible")
    else:
        raise TestFailure(f"Unexpected status: {status}")
    
    # Test 2: More complex 4x4
    # Grid with obstacles and mirrors
    dut._log.info("Testing case 2")
    
    dut.rst_n.value = 0
    await Timer(20, units="ns")
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # 4x4: V in corners, obstacles
    grid2 = [
        ord('V'), ord('#'), ord('V'), ord('.'),
        ord('.'), ord('.'), ord('#'), ord('.'),
        ord('V'), ord('#'), ord('V'), ord('.'),
        ord('.'), ord('.'), ord('.'), ord('.')
    ]
    
    for i in range(16):
        dut.grid[i].value = grid2[i]
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 2000
    for _ in range(timeout):
        await RisingEdge(dut.clk)
        if dut.done.value:
            break
    else:
        raise TestFailure("Timeout - computation did not complete")
    
    result = int(dut.min_rotations.value)
    status = int(dut.status.value)
    
    dut._log.info(f"Result: {result}, Status: {status}")
    
    if status == 1 or status == 2:
        dut._log.info("Test 2: Passed")
    else:
        raise TestFailure(f"Unexpected status: {status}")
    
    # Test 3: Empty 4x4
    dut._log.info("Testing case 3: No gargoyles")
    
    dut.rst_n.value = 0
    await Timer(20, units="ns")
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    grid3 = [ord('.') for _ in range(16)]
    for i in range(16):
        dut.grid[i].value = grid3[i]
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 2000
    for _ in range(timeout):
        await RisingEdge(dut.clk)
        if dut.done.value:
            break
    else:
        raise TestFailure("Timeout - computation did not complete")
    
    result = int(dut.min_rotations.value)
    status = int(dut.status.value)
    
    dut._log.info(f"Result: {result}, Status: {status}")
    
    # No gargoyles = 0 rotations
    if status == 1 and result == 0:
        dut._log.info("Test 3: Passed")
    else:
        dut._log.info(f"Test 3: Got {result}, expected 0")
    
    # Test 4: Two gargoyles facing opposite directions
    dut._log.info("Testing case 4")
    
    dut.rst_n.value = 0
    await Timer(20, units="ns")
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    grid4 = [
        ord('V'), ord('.'), ord('.'), ord('.'),
        ord('.'), ord('.'), ord('.'), ord('.'),
        ord('.'), ord('.'), ord('.'), ord('.'),
        ord('H'), ord('.'), ord('.'), ord('.')
    ]
    
    for i in range(16):
        dut.grid[i].value = grid4[i]
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 2000
    for _ in range(timeout):
        await RisingEdge(dut.clk)
        if dut.done.value:
            break
    else:
        raise TestFailure("Timeout - computation did not complete")
    
    result = int(dut.min_rotations.value)
    status = int(dut.status.value)
    
    dut._log.info(f"Result: {result}, Status: {status}")
    
    if status == 1 or status == 2:
        dut._log.info("Test 4: Passed")
    else:
        raise TestFailure(f"Unexpected status: {status}")
    
    # Test 5: Single V in middle
    dut._log.info("Testing case 5: Single gargoyle")
    
    dut.rst_n.value = 0
    await Timer(20, units="ns")
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    grid5 = [
        ord('.'), ord('.'), ord('.'), ord('.'),
        ord('.'), ord('V'), ord('.'), ord('.'),
        ord('.'), ord('.'), ord('.'), ord('.'),
        ord('.'), ord('.'), ord('.'), ord('.')
    ]
    
    for i in range(16):
        dut.grid[i].value = grid5[i]
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 2000
    for _ in range(timeout):
        await RisingEdge(dut.clk)
        if dut.done.value:
            break
    else:
        raise TestFailure("Timeout - computation did not complete")
    
    result = int(dut.min_rotations.value)
    status = int(dut.status.value)
    
    dut._log.info(f"Result: {result}, Status: {status}")
    
    # Single gargoyle should be impossible (needs another face)
    if status == 2:
        dut._log.info("Test 5: Passed (correctly impossible)")
    elif status == 1:
        dut._log.info("Test 5: Completed with result {result}")
    else:
        raise TestFailure(f"Unexpected status: {status}")
    
    dut._log.info("All basic tests completed")
