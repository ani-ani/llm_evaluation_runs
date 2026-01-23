import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer, RisingEdge
import random

def calculate_game_outcome(points):
    """
    Determines if Mirko wins the game.
    The game is played on a bipartite graph.
    We can use memoization (DP on state) to solve for small N.
    State: (current_node, visited_mask)
    Nodes are: 0..X-1 for X-coords, X..X+Y-1 for Y-coords.
    """
    # Collect unique X and Y
    xs = sorted(list(set(p[0] for p in points)))
    ys = sorted(list(set(p[1] for p in points)))
    
    # Map to indices 0..num_x-1 and 0..num_y-1
    x_map = {val: i for i, val in enumerate(xs)}
    y_map = {val: i for i, val in enumerate(ys)}
    
    num_x = len(xs)
    num_y = len(ys)
    total_nodes = num_x + num_y
    
    # Adjacency list: nodes 0..num_x-1 are X, nodes num_x..num_x+num_y-1 are Y
    adj = [[] for _ in range(total_nodes)]
    
    # We also need to track which edges (points) are used.
    # But the rule is: "No single line must be drawn twice".
    # In graph terms, we traverse edges. We cannot traverse an edge twice.
    # So we need to track visited edges.
    # However, the game is usually played on nodes: you are at a node, you choose an edge to a neighbor.
    # The constraint "No single line must be drawn twice" means edges cannot be reused.
    # So state is: (current_node, visited_edges_mask).
    # Number of edges is N (points). N <= 16 is manageable.
    
    # Let's re-index edges 0..N-1.
    edge_list = []
    for p in points:
        u = x_map[p[0]]
        v = num_x + y_map[p[1]]
        edge_list.append((u, v))
        # Adjacency is needed to find edges from a node
    
    # Precompute for each node, which edges connect to it
    node_edges = [[] for _ in range(total_nodes)]
    for i, (u, v) in enumerate(edge_list):
        node_edges[u].append(i)
        node_edges[v].append(i)
        adj[u].append(v)
        adj[v].append(u)

    # Memoization: dp[current_node][mask]
    # current_node: 0..total_nodes-1
    # mask: bitfield of visited edges (up to 16 bits)
    # Value: 1 if winning position, 0 if losing
    
    memo = {}
    
    def can_win(current_node, visited_mask):
        state = (current_node, visited_mask)
        if state in memo:
            return memo[state]
        
        # Check all edges connected to current_node
        for edge_idx in node_edges[current_node]:
            if not (visited_mask & (1 << edge_idx)):
                # Try this move
                # The edge connects u and v. The other node is the target.
                u, v = edge_list[edge_idx]
                next_node = v if u == current_node else u
                
                # If opponent cannot win from next state, we win
                if not can_win(next_node, visited_mask | (1 << edge_idx)):
                    memo[state] = 1
                    return 1
        
        memo[state] = 0
        return 0

    # Mirko can start at ANY point. 
    # In graph terms, he selects an edge (point) first.
    # Wait, rules: "He draws a line... passing through one of the N points."
    # "In following moves... passes through one of the N points located on the line drawn in the previous move."
    # This implies: 
    # 1. Mirko chooses a point P1 (x1, y1).
    # 2. This effectively selects the X-axis line y=y1 or Y-axis line x=x1? 
    # No, "draws a straight line which is parallel to one of the axes... and passes through one of the N points."
    # "... located on the line drawn in the previous move."
    # This means: 
    # Move 1 (Mirko): Select point P1. Draw line L1 (x=x1 or y=y1).
    # Move 2 (Slavko): Must select a point P2 that lies on L1. 
    #    If Mirko drew x=x1, Slavko picks P2=(x1, y2).
    #    If Mirko drew y=y1, Slavko picks P2=(x2, y1).
    #    But wait, can Mirko choose which line orientation?
    #    "draws a straight line... parallel to one of the axes... and passes through one of the N points."
    #    Yes, he chooses the point AND the orientation (horizontal or vertical).
    #    However, the point must be on the line.
    #    So if he picks point (1,2), he can draw x=1 OR y=2.
    #    Let's call the line L1.
    #    Next player (Slavko) must draw a line L2 parallel to axis, passing through a point P2 on L1.
    #    L2 intersects L1 at P2.
    #    Then Mirko must draw L3 passing through a point P3 on L2.
    #    This sequence of lines.
    #    "No single line must be drawn twice."
    #    So we are trading lines.
    #    If L is a vertical line x=k, it covers all points with x=k.
    #    If L is a horizontal line y=k, it covers all points with y=k.
    
    # Let's re-read carefully.
    # "He draws a straight line... parallel to one of the axes... and passes through one of the N points."
    # "In the following moves, the player draws a straight line... parallel to one of the axes... and passes through one of the N points located on the line drawn in the previous move of the opponent."
    # This implies the line must pass through a point that is on the PREVIOUS line.
    # But the line being drawn itself can be vertical or horizontal, independently of the previous line's orientation?
    # If previous line was x=1 (vertical), it passes through points (1, y).
    # The current player must draw a line passing through one of these points, say (1, 5).
    # He can draw x=1 (vertical) or y=5 (horizontal).
    # But "No single line must be drawn twice."
    # So he cannot draw x=1 again.
    # So he must draw y=5.
    # This means the line orientation is forced if the previous line was of the other type.
    # BUT, if the previous line was x=1, and there are multiple points (1, 2) and (1, 5),
    # the player chooses a point P on the line.
    # If P is (1, 2), he must draw x=1 or y=2. x=1 is forbidden (drawn previously). So he draws y=2.
    # If P is (1, 5), he must draw x=1 or y=5. x=1 is forbidden. So he draws y=5.
    # The choice is essentially which point P on the current line to pick, which determines the NEW line (the perpendicular one).
    # What if the previous line was x=1, and there is also a line y=2 drawn previously?
    # If the player picks P=(1, 2), he cannot draw x=1 (used) nor y=2 (used). Game over.
    
    # So the state is: (current_line, history_of_used_lines).
    # Since coordinates are small (0-15), lines are x=0..15 or y=0..15.
    # Total 32 lines.
    # But we only care about lines that contain points.
    # Let's extract lines.
    # Vert lines: set of X values.
    # Horiz lines: set of Y values.
    # Nodes in graph: Lines.
    # Edges: A point (x, y) connects Line X and Line Y.
    # The game:
    # 1. Mirko picks an edge (point). This effectively selects the two incident lines (X and Y).
    #    But he must draw ONE line.
    #    Does he choose which one?
    #    "He draws a straight line... parallel to one of the axes... and passes through one of the N points."
    #    Yes, he chooses the line (x=x_val or y=y_val).
    #    So from edge (x, y), he can start at Line X or Line Y.
    # 2. Slavko must pick an edge incident to the current line, but which goes to an UNVISITED line.
    #    (Since drawing a line on a used line is forbidden, and we assume drawing the same line twice is forbidden).
    #    Actually, "No single line must be drawn twice."
    #    So visited nodes are lines.
    #    Edges are points.
    #    A move consists of:
    #    - Currently at line L_u.
    #    - Select an incident edge e to line L_v.
    #    - Check if L_v is unvisited.
    #    - Draw L_v.
    #    - Move to L_v.
    #    - Mark e as used? 
    #    The rule is about lines, not points. "No single line must be drawn twice."
    #    The text says: "passes through one of the N points located on the line drawn in the previous move."
    #    It doesn't say points cannot be reused as intersection points, only lines cannot be reused.
    #    So the graph is:
    #    Nodes: Vertical Lines (X_i) and Horizontal Lines (Y_j).
    #    Edges: Points (x, y) connecting X_x and Y_y.
    #    Moves: From current node (line), choose an incident edge to a NEW node (line).
    #    We cannot visit a node (line) twice.
    #    This is a node traversal game on the bipartite graph of lines.
    
    # Let's verify with sample:
    # Points: (1,1), (1,2), (1,3).
    # Vert lines: {1}. Horiz lines: {1, 2, 3}.
    # Nodes: V1, H1, H2, H3.
    # Edges: (V1, H1), (V1, H2), (V1, H3).
    # Mirko goes first.
    # He can draw V1 or H1 or H2 or H3 (any line passing through a point).
    # If Mirko draws V1:
    #   Slavko must draw a line passing through a point on V1.
    #   Points on V1: (1,1), (1,2), (1,3).
    #   Lines passing through these: H1, H2, H3. (V1 is forbidden).
    #   Slavko draws H1 (or H2 or H3).
    #   Then Mirko must draw a line passing through a point on H1.
    #   Points on H1: (1,1).
    #   Lines: V1 (used), H1 (used). No moves. Mirko loses.
    #   Wait, sample output is "Mirko". So Mirko wins.
    #   If Mirko draws V1, he loses. So he shouldn't draw V1.
    #   If Mirko draws H1:
    #     Slavko must draw line through point on H1. Point (1,1).
    #     Lines: V1, H1. H1 used. Only V1.
    #     Slavko draws V1.
    #     Mirko must draw line through point on V1.
    #     Points: (1,1), (1,2), (1,3).
    #     Lines: H1 (used), H2, H3.
    #     Mirko draws H2.
    #     Slavko must draw line through point on H2. Point (1,2).
    #     Lines: V1 (used), H2 (used). No moves. Slavko loses. Mirko wins.
    #   So Mirko wins by starting on H1 (or H2 or H3).
    #   So the graph nodes are lines, edges are points.
    #   Mirko picks a node. 
    #   Then players alternate moving to adjacent nodes via edges.
    #   Cannot revisit nodes.
    #   This is a standard "Geography" like game on a graph.

    # Let's extract lines.
    xs = sorted(list(set(p[0] for p in points)))
    ys = sorted(list(set(p[1] for p in points)))
    
    # Map lines to indices 0..num_x-1 (vertical) and num_x..num_x+num_y-1 (horizontal)
    v_map = {val: i for i, val in enumerate(xs)}
    h_map = {val: i + len(xs) for i, val in enumerate(ys)}
    
    num_v = len(xs)
    num_h = len(ys)
    num_nodes = num_v + num_h
    
    # Edges: points connect v_node and h_node
    edge_list = []
    node_edges = [[] for _ in range(num_nodes)]
    
    for p in points:
        u = v_map[p[0]]
        v = h_map[p[1]]
        edge_idx = len(edge_list)
        edge_list.append((u, v))
        node_edges[u].append(edge_idx)
        node_edges[v].append(edge_idx)

    # Memoization for game states
    # State: (current_node, visited_nodes_mask)
    # visited_nodes_mask: bitmask of size num_nodes
    memo = {}

    def can_win_game(current_node, visited_nodes_mask):
        state = (current_node, visited_nodes_mask)
        if state in memo:
            return memo[state]
        
        # Look for a move to a neighbor node that is not visited
        # We need to use an edge that hasn't been used? 
        # The problem says "No single line must be drawn twice".
        # It doesn't explicitly forbid reusing a point (edge) if it's on the line.
        # But typically in these games, edges are not restricted, only nodes (lines).
        # Let's check: 
        # Example: (1,1), (2,1), (2,2).
        # Mirko: x=1. Slavko: y=1. Mirko: x=2. Slavko: y=2. Mirko: x=2 (used) or y=1 (used). Mirko loses.
        # If edges are not restricted: 
        # Mirko: x=1 (via (1,1)). Slavko: y=1 (via (1,1)). Mirko: x=2 (via (2,1)). Slavko: y=2 (via (2,2)). Mirko stuck.
        # If edges are restricted: 
        # Mirko: x=1. Slavko: y=1 (uses edge (1,1)). Mirko: x=2 (must use (2,1)). Slavko: y=2 (must use (2,2)).
        # Same outcome.
        # Generally, we don't need to track edges separately if we just track visited nodes.
        # Because from a node, we can reach neighbors. If a neighbor is visited, we can't go there.
        # Is it possible to go to a neighbor via a different edge if the first one is used?
        # If we are at V1, neighbors are H1, H2...
        # To go to H1, we need edge (V1, H1).
        # If we later return to V1 (impossible if nodes are visited), or if we used edge (V1, H1) to go V1->H1.
        # Can we use (V1, H1) again to go H1->V1? No, H1 is visited.
        # So simply tracking visited nodes is sufficient for this graph traversal game.
        
        # Iterate over all edges connected to current_node
        for edge_idx in node_edges[current_node]:
            u, v = edge_list[edge_idx]
            neighbor = v if u == current_node else u
            
            # Check if neighbor node is already visited
            if not (visited_nodes_mask & (1 << neighbor)):
                # Valid move: go to neighbor
                if not can_win_game(neighbor, visited_nodes_mask | (1 << neighbor)):
                    memo[state] = 1
                    return 1
        
        memo[state] = 0
        return 0

    # Mirko starts first.
    # He can choose ANY starting node (any line passing through a point).
    # So he can pick any node 0..num_nodes-1.
    # If there exists a starting node that is a winning position for the first player (Mirko), he wins.
    # Wait, in the recursive function `can_win_game(current_node, ...)`, it returns True if the player 
    # whose turn it is to move from `current_node` can force a win.
    # So Mirko picks a node `n`. Then Slavko moves from `n`.
    # So Mirko wins if `can_win_game(n, visited_mask)` is FALSE (because Slavko loses).
    # Mirko wins if there exists a node `n` such that `can_win_game(n, 1<<n)` is 0.
    
    for i in range(num_nodes):
        # Mirko picks node i. Mask starts with node i visited.
        # Now it's Slavko's turn to move from i.
        # If Slavko cannot win (can_win_game returns 0), Mirko wins.
        if not can_win_game(i, 1 << i):
            return 1 # Mirko wins
    return 0

@cocotb.test()
async def test_coordinate_game(dut):
    """Test the coordinate game solver"""
    
    # Setup clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.points_x.value = 0
    dut.points_y.value = 0
    dut.num_points.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases
    test_cases = [
        # Case 1: 3 points, Mirko wins
        {
            "points": [(1, 1), (1, 2), (1, 3)],
            "expected_mirko_wins": 1
        },
        # Case 2: 4 points, Mirko loses
        {
            "points": [(1, 1), (1, 2), (2, 1), (2, 2)],
            "expected_mirko_wins": 0
        },
        # Case 3: Single point, Mirko wins (he draws line, Slavko must draw same line but it's forbidden? 
        # Rule: "No single line must be drawn twice."
        # Mirko draws x=1. Slavko must draw line passing through (1,1). x=1 used, y=1 available.
        # Slavko draws y=1. Mirko must draw line through (1,1). Both used. Mirko loses.
        # So single point = Mirko loses.)
        {
            "points": [(5, 5)],
            "expected_mirko_wins": 0
        },
        # Case 4: 2 points, not connected
        {
            "points": [(1, 1), (2, 2)],
            "expected_mirko_wins": 0 # Mirko picks (1,1) -> Slavko loses? No. 
            # Mirko picks x=1. Slavko has y=1. Slavko picks y=1. Mirko stuck. Mirko loses.
            # Mirko picks x=2. Slavko picks y=2. Mirko stuck. 
            # So 0.
        },
        # Case 5: 3 points forming a Z-shape (Ladder)
        {
            "points": [(1, 1), (1, 2), (2, 2)],
            "expected_mirko_wins": 1
            # Nodes: V1, V2, H1, H2.
            # Mirko picks V2 (x=2). Slavko must go H2 (y=2). Mirko goes V1 (x=1). Slavko stuck.
            # So 1.
        }
    ]

    passed = 0
    total = len(test_cases)

    for i, tc in enumerate(test_cases):
        # Prepare inputs
        points = tc["points"]
        expected = tc["expected_mirko_wins"]
        
        # Pack points into 32-bit vectors. Each point uses 4 bits for X and 4 bits for Y.
        # We assume inputs X, Y are in range 0-15 (scaled down).
        # Original constraints are 1-500, we will map them 1-to-1 to 0-15 if small enough, 
        # or just assume the test cases use small values.
        # We need to handle scaling. 
        # The prompt says "limit the coordinate range. Inputs will represent a maximum of 16 distinct X values (0-15)."
        # So we will scale inputs if necessary or just use small values.
        # For this testbench, let's assume the provided points are already in range 0-15 or just use a simple mapping.
        # To be safe, we'll extract unique coords and map them to 0..15.
        
        xs = sorted(list(set(p[0] for p in points)))
        ys = sorted(list(set(p[1] for p in points)))
        
        # Check limits
        if len(xs) > 16 or len(ys) > 16 or len(points) > 16:
            # Scale down: map values to 0..15
            # This is just for the testbench to work with the module.
            # We assume the module expects values 0..15.
            # So let's map them.
            x_map = {val: i for i, val in enumerate(xs)}
            y_map = {val: i for i, val in enumerate(ys)}
            mapped_points = [(x_map[p[0]], y_map[p[1]]) for p in points]
        else:
            # Use original values, but subtract min or just use them if < 16.
            # Let's standardize to 0-based indices for the module.
            # We assume the module interprets inputs as identifiers.
            # If the inputs are 1-based, we shift.
            # Let's map 0..15.
            x_map = {val: i for i, val in enumerate(xs)}
            y_map = {val: i for i, val in enumerate(ys)}
            mapped_points = [(x_map[p[0]], y_map[p[1]]) for p in points]
            
        # Pack into vectors
        points_x_vec = 0
        points_y_vec = 0
        for idx, (mx, my) in enumerate(mapped_points):
            points_x_vec |= (mx << (4 * idx))
            points_y_vec |= (my << (4 * idx))
        
        dut.points_x.value = points_x_vec
        dut.points_y.value = points_y_vec
        dut.num_points.value = len(mapped_points)
        
        # Start
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        timeout = 0
        while not dut.done.value and timeout < 100:
            await RisingEdge(dut.clk)
            timeout += 1
            
        if timeout >= 100:
            dut._log.error(f"Test {i+1}: Timeout waiting for done")
            continue
            
        # Check result
        result = int(dut.mirko_wins.value)
        
        if result == expected:
            dut._log.info(f"Test {i+1} PASSED: Points={points}, Mirko Wins={result}")
            passed += 1
        else:
            dut._log.error(f"Test {i+1} FAILED: Points={points}, Expected={expected}, Got={result}")

    dut._log.info(f"
Summary: {passed}/{total} tests passed")
    assert passed == total
