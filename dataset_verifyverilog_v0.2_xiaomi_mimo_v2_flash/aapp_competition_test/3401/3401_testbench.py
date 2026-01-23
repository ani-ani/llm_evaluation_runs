import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
import math

def calculate_expected(hills, springs, towns, q_max):
    n = len(hills)
    s = len(springs)
    t = len(towns)
    
    # Build adjacency matrix of valid edges
    valid_edges = [[False]*n for _ in range(n)]
    dists = [[0]*n for _ in range(n)]
    
    for i in range(n):
        for j in range(n):
            if i == j: continue
            # Check height
            if hills[i][2] < hills[j][2]: continue # Water flows i->j if i is higher (Spring->Town)
            # Actually, water flows downhill. Spring is source, Town is sink. 
            # If Spring is on hill A, Town on hill B. A->B must be downhill. hills[A] >= hills[B].
            
            dx = hills[i][0] - hills[j][0]
            dy = hills[i][1] - hills[j][1]
            dist_sq = dx*dx + dy*dy
            
            # Distance constraint (q_max)
            # Note: q_max is length, so compare dist_sq with q_max^2
            if dist_sq > q_max*q_max: continue
            
            # Calculate actual length (sqrt)
            dist = math.sqrt(dist_sq)
            valid_edges[i][j] = True
            dists[i][j] = dist
            
    # Try permutations of Spring -> Town assignments
    import itertools
    min_total = float('inf')
    found = False
    
    # Indices for springs and towns
    spring_indices = list(range(s))
    town_indices = list(range(t))
    
    for perm in itertools.permutations(spring_indices):
        total_dist = 0.0
        valid_perm = True
        for k in range(t):
            s_hill = springs[perm[k]]
            t_hill = towns[k]
            
            # Check if edge exists
            if not valid_edges[s_hill][t_hill]:
                valid_perm = False
                break
            total_dist += dists[s_hill][t_hill]
        
        if valid_perm:
            found = True
            if total_dist < min_total:
                min_total = total_dist
    
    if found:
        return min_total
    return -1

@cocotb.test()
async def test_aqueduct_solver(dut):
    # Setup Clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    print("Starting Testbench...")
    
    # --- Test Case 1: Valid ---
    # Input from problem description (scaled)
    # Original: 
    # 0 0 6
    # 3 4 7
    # 0 8 8
    # 6 8 8
    # 6 0 6
    # 6 4 8
    # Springs: 3 4 -> indices 2, 3 (0-indexed)
    # Towns: 1 5 -> indices 0, 4
    # q=8
    
    # We need to map this to 4 hills for our Verilog module. 
    # Let's pick a subset or scale coordinates.
    # Let's use 4 hills: H0(0,0,6), H1(3,4,7), H2(0,8,8), H3(6,4,8)
    # Springs: H1(3,4,7), H2(0,8,8)
    # Towns: H0(0,0,6), H3(6,4,8)
    # Note: H3 height 8, Spring H2 height 8. Height must be strictly higher? Or >= ? Problem says "higher point to a lower". Usually implies >= is okay if tunnelled? But let's assume strict > or >=. In hardware we often do >=. Let's check H2(8) -> H3(8). This is flat. Not downhill. So H2 cannot connect to H3.
    # H1(7) -> H3(8) is uphill (invalid).
    # H1(7) -> H0(6) downhill, distance sqrt((3-0)^2 + (4-0)^2) = 5. < 8.
    # H2(8) -> H0(6) downhill, distance sqrt((0-0)^2 + (8-0)^2) = 8. <= 8.
    # H1(7) -> H3(8) uphill (invalid).
    # H2(8) -> H3(8) flat (invalid? Let's assume invalid for strict downhill).
    # If H2->H3 is invalid, then H1->H0 and H2->H0 are valid? But we need 2 distinct towns. 
    # We only have one town H0 that is lower than both springs. So this set might be impossible with strict downhill.
    
    # Let's craft a valid test case for 4 hills.
    # H0: 0, 0, 10 (Town)
    # H1: 5, 0, 20 (Spring)
    # H2: 0, 10, 15 (Town)
    # H3: 10, 10, 25 (Spring)
    # q = 20 (Squared limit 400)
    # H1->H0: dist 5, height valid. Total 5.
    # H3->H2: dist sqrt(10^2+5^2)=11.18, height valid. Total 16.18.
    # Swapped: H3->H0: dist 14.14. H1->H2: dist 11.18. Total 25.32.
    # Min is 16.18.
    
    # Let's use this simpler geometric case for the testbench.
    # H0: 0,0,10
    # H1: 5,0,20
    # H2: 0,10,15
    # H3: 10,10,25
    # Springs: H1, H3 (indices 1, 3)
    # Towns: H0, H2 (indices 0, 2)
    # q = 12 (squared 144). H3->H2 dist sq = 125 (valid). H1->H0 dist sq = 25 (valid).
    # Min total = sqrt(25) + sqrt(125) = 5 + 11.1803 = 16.1803
    
    dut.hill_x[0].value = 0; dut.hill_y[0].value = 0; dut.hill_h[0].value = 10
    dut.hill_x[1].value = 5; dut.hill_y[1].value = 0; dut.hill_h[1].value = 20
    dut.hill_x[2].value = 0; dut.hill_y[2].value = 10; dut.hill_h[2].value = 15
    dut.hill_x[3].value = 10; dut.hill_y[3].value = 10; dut.hill_h[3].value = 25
    
    dut.spring_idx[0].value = 1
    dut.spring_idx[1].value = 3
    dut.town_idx[0].value = 0
    dut.town_idx[1].value = 2
    
    dut.q_max.value = 12
    
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done
    timeout = 0
    while not dut.done.value and timeout < 100:
        await RisingEdge(dut.clk)
        timeout += 1
    
    if timeout >= 100:
        print("Test 1: Timeout")
        assert False, "Timeout"
        
    # Check result
    # The verilog output is expected to be the sum of lengths. 
    # We need to define if it is scaled (Q16.16) or integer.
    # Given the sqrt is hard in pure integer verilog without floating point, 
    # and the prompt asks for 'minimum total length', we should verify.
    # Let's assume the verilog implementation calculates sqrt accurately or approximates.
    # We'll check against expected 16.1803.
    
    result = int(dut.min_length.value)
    print(f"Test 1 Result: {result} (Expected ~161803 if scaled by 10000, or ~16 if integer)")
    
    # If we used Q16.16: 16.1803 * 65536 = 1,060,317
    # If we used scaled integer (e.g. fixed point 100): 1618
    # Since the problem requires float output, let's assume Q16.16 is the standard.
    # 16.1803 * 65536 = 1060326
    
    expected_fixed = int(16.1803 * 65536)
    assert abs(result - expected_fixed) < 1000, f"Expected {expected_fixed}, got {result}"
    print("Test 1 Passed")
    
    # --- Test Case 2: Impossible ---
    # Make one town higher than all springs
    # H0: 0,0,100 (Town) - Higher than springs
    # H1: 5,0,20 (Spring)
    # H2: 0,10,15 (Town)
    # H3: 10,10,25 (Spring)
    
    dut.hill_h[0].value = 100 # Town too high
    
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 0
    while not dut.done.value and timeout < 100:
        await RisingEdge(dut.clk)
        timeout += 1
        
    result = int(dut.min_length.value)
    # Expect IMPOSSIBLE signal (e.g., 32'hFFFFFFFF)
    print(f"Test 2 Result: {result} (Expected -1)")
    assert result == 0xFFFFFFFF, f"Expected IMPOSSIBLE (0xFFFFFFFF), got {result}"
    print("Test 2 Passed")
    
    print("All tests passed!")
