import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, Timer
import random

def get_edges_from_matrix(matrix):
    # matrix is a list of lists, lower triangular
    # returns list of (u, v, w)
    edges = []
    n = len(matrix) + 1
    for i in range(n):
        for j in range(i + 1, n):
            # Input format: i-th line has n-i integers. i starts at 1 in problem, 0 in code
            # row i, col j. Value is matrix[i][j-i-1]
            if i < len(matrix) and (j-i-1) < len(matrix[i]):
                w = matrix[i][j-i-1]
                if w is not None:
                    edges.append({'u': i, 'v': j, 'w': w})
    return edges

def solve_heuristic(edges):
    # Sort edges descending by weight
    edges.sort(key=lambda x: x['w'], reverse=True)
    
    # Assignment: 0=none, 1=A, 2=B
    assignment = [0] * 16
    max_a = 0
    max_b = 0
    
    for e in edges:
        u, v, w = e['u'], e['v'], e['w']
        
        # If edge connects nodes in opposite groups, it's a conflict and cannot be used for disparity
        if assignment[u] != 0 and assignment[v] != 0 and assignment[u] != assignment[v]:
            continue
            
        # If both in A, update max_a
        if assignment[u] == 1 and assignment[v] == 1:
            max_a = max(max_a, w)
            continue
            
        # If both in B, update max_b
        if assignment[u] == 2 and assignment[v] == 2:
            max_b = max(max_b, w)
            continue
            
        # If one is assigned, assign the other to the same group
        if assignment[u] == 1 or assignment[v] == 1:
            target = 1
        elif assignment[u] == 2 or assignment[v] == 2:
            target = 2
        else:
            # Both unassigned: pick group with smaller current max
            if max_a <= max_b:
                target = 1
            else:
                target = 2
        
        # Perform assignment and update max
        if target == 1:
            assignment[u] = 1
            assignment[v] = 1
            max_a = max(max_a, w)
        else:
            assignment[u] = 2
            assignment[v] = 2
            max_b = max(max_b, w)
            
    return max_a + max_b

@cocotb.test()
async def test_ore_partitioner(dut):
    # Setup Clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.valid_in.value = 0
    dut.dist_in.value = 0
    dut.row_idx.value = 0
    dut.col_idx.value = 0
    await Timer(50, units="ns")
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    # Test Case 1 (N=5 scaled to 4x4 matrix logic, we use 4x4 subset or full 4x4)
    # Let's use a 4x4 specific test case designed for the heuristic
    # 4x4 Matrix: 
    # 0: 10, 5, 1
    # 1: 2, 4, 8
    # 2: 3, 6
    # 3: 9
    # Edges: (0,1,10), (0,2,5), (0,3,1), (1,2,2), (1,3,4), (2,3,3)
    
    input_matrix = [
        [10, 5, 1],
        [2, 4, 8],
        [3, 6],
        [9]
    ]
    
    edges = get_edges_from_matrix(input_matrix)
    # Limit to N=4 (indices 0,1,2,3). Filter edges to keep only relevant ones.
    # Actually we will just feed all edges from the matrix generator
    
    dut._log.info("Starting Input Sequence...")
    
    # Feed edges
    for e in edges:
        dut.row_idx.value = e['u']
        dut.col_idx.value = e['v']
        dut.dist_in.value = e['w']
        dut.valid_in.value = 1
        await RisingEdge(dut.clk)
    
    dut.valid_in.value = 0
    
    # Start computation
    dut._log.info("Asserting Start...")
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done
    dut._log.info("Waiting for Done...")
    timeout = 0
    while dut.done.value == 0:
        await RisingEdge(dut.clk)
        timeout += 1
        if timeout > 5000:
            raise TimeoutError("Module did not finish in time")
            
    result = int(dut.result.value)
    dut._log.info(f"Result: {result}")
    
    # Verify result
    # Manual Calculation for Test Case:
    # Edges sorted desc: 10, 9, 8, 6, 5, 4, 3, 2, 1
    # Note: Our input N=4 is small, so we might miss some edges if we strictly follow 4x4 logic.
    # Let's assume the module handles exactly the N specified by input stream length or internal param.
    # For this test, we assume N=4 (indices 0,1,2,3).
    # Edges: (0,1,10), (0,2,5), (0,3,1), (1,2,2), (1,3,4), (2,3,3)
    # Wait, input matrix is upper triangular. 
    # row 0: cols 1,2,3 -> 10, 5, 1
    # row 1: cols 2,3 -> 2, 4
    # row 2: cols 3 -> 3
    # row 3: none
    # Missing 8 and 9 and 6 from my manual list above? Ah, I copied sample matrix incorrectly for N=4.
    # Let's use a simpler logic check: 
    # Just check if result is reasonable. We will run the python solver to be sure.
    
    expected = solve_heuristic(edges)
    
    assert result == expected, f"Expected {expected}, got {result}"
    
    # Test Case 2: Random small matrix
    await Timer(100, units='ns')
    # Reset for next test
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Generate random edges for N=4
    import random
    random.seed(42)
    edges2 = []
    for i in range(4):
        for j in range(i+1, 4):
            w = random.randint(1, 100)
            edges2.append({'u': i, 'v': j, 'w': w})
            
    for e in edges2:
        dut.row_idx.value = e['u']
        dut.col_idx.value = e['v']
        dut.dist_in.value = e['w']
        dut.valid_in.value = 1
        await RisingEdge(dut.clk)
    dut.valid_in.value = 0
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 0
    while dut.done.value == 0:
        await RisingEdge(dut.clk)
        timeout += 1
        if timeout > 5000:
            raise TimeoutError("Module did not finish")
            
    result2 = int(dut.result.value)
    expected2 = solve_heuristic(edges2)
    
    dut._log.info(f"Test 2: Result {result2}, Expected {expected2}")
    assert result2 == expected2, f"Expected {expected2}, got {result2}"
