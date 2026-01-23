import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer, RisingEdge
import random

@cocotb.test()
async def test_vacation_planner(dut):
    # Initialize signals
    dut.start.value = 0
    dut.rst_n.value = 1
    dut.N.value = 0
    dut.L.value = 0
    
    # Create clock (10ns period)
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset sequence
    dut.rst_n.value = 0
    await Timer(25, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    print("=== Vacation Planner Tests ===")
    
    # Test Case 1: Sample Input 1 (Adapted)
    # Original: N=3, L=1, matrix [[0,11,9],[1,0,10],[0,0,0]]
    # Expected: T=2
    # Adapted: N=3, L=1, reduce graph size for hardware
    # Use simplified 3x3 matrix with smaller counts
    # Node 0 -> 1 (11) -> 2 (10) is dominant path
    # Probability: Day 1: 11/20=0.55 at node1, 9/20=0.45 at node2
    # Day 2: From node1: 1/11 to node0, 10/11 to node2
    # From node0: 11/20 to node1, 9/20 to node2
    # This is too complex. Let's use a simpler graph for testbench.
    
    # TEST 1: Simple 2-node linear path
    # N=2, L=1, matrix: [[0,1],[0,0]]
    # At day 1: 100% at node 2. Need 95%. No solution.
    # Let's adjust to hit exactly 95%. Use scaling.
    # Graph: 0 -> 1 (count 95), 0 -> 2 (count 5), 1->2 (100)
    # Wait, nodes are 1-indexed in problem, 0-indexed in hardware.
    # Let's create a test case that IS solvable in scaled domain.
    # Use 3 nodes: 0,1,2 (2 is target)
    # Matrix: 0->1: 95, 0->2: 5
    #         1->2: 100
    #         2->(none)
    # Day 1: P(2) = 5/100 = 5%
    # Day 2: P(2) = P(1)*1 + P(2)*1 = 95/100 * 1 + 5/100 * 1 = 100% (since 2 has no out, stays at 2? No, stops.)
    # Problem: 'Once they reach B-ville, they stop.' -> Absorbing state.
    # Correct update: P_new[2] = P_old[2] + sum_i P_old[i]*trans[i->2]
    # P_new[0] = sum_i P_old[i]*trans[i->0]
    
    # Let's try a 4-node graph to get 95% exactly at some day.
    # 0->1 (50), 0->2 (50)
    # 1->3 (100) -> Target
    # 2->3 (100) -> Target
    # Day 1: P(1)=0.5, P(2)=0.5, P(3)=0
    # Day 2: P(3) = 0.5*1 + 0.5*1 = 1.0 (100%)
    # We need 95%. Let's make paths different lengths.
    # 0->1 (100) -> 1->3 (100)
    # 0->2 (100) -> 2->3 (100)
    # Same result.
    # 0->1 (95), 0->3 (5)
    # 1->3 (100)
    # Day 1: P(3)=5%, P(1)=95%
    # Day 2: P(3) = 5% + 95%*1 = 100%
    # Still binary.
    # To get 95% in middle, need mixing.
    # 0->1 (50), 0->2 (50)
    # 1->3 (100)
    # 2->1 (100)
    # 3 is target.
    # Day 1: P(1)=0.5, P(2)=0.5
    # Day 2: P(1) = P(2)*1 = 0.5. P(3) = P(1)*1 = 0.5.
    # Day 3: P(1) = 0.5. P(3) = 0.5 + 0.5 = 1.0.
    # Still hard to get exact decimal.
    # Let's just use the scaled integer arithmetic as designed.
    # Target is 9500.
    # We will construct a graph that hits 9500.
    # Graph: 0->1 (100), 0->2 (0) [start]
    #        1->3 (19), 1->4 (81) [split]
    #        2->3 (100)
    #        3 is target (3).
    # Wait, we need to calculate.
    # Let's use a pre-calculated scenario in the testbench.
    # Scenario: N=4, L=2. Target is node 3 (index 3).
    # Matrix (counts):
    # 0: [0, 95, 5, 0]  -> Total 100.
    # 1: [0, 0, 0, 100] -> Total 100.
    # 2: [0, 0, 0, 100] -> Total 100.
    # 3: [0, 0, 0, 0]   -> Absorbing.
    # Probabilities (x 10000):
    # T[0][1]=9500, T[0][2]=500, T[0][3]=0
    # T[1][3]=10000
    # T[2][3]=10000
    # Day 0: State[0]=10000, others 0.
    # Day 1: S1[1] = 10000*9500/10000 = 9500
    #        S1[2] = 10000*500/10000 = 500
    #        S1[3] = 0
    # Day 2: S2[3] = S1[1]*10000/10000 + S1[2]*10000/10000 + S1[3]
    #        S2[3] = 9500 + 500 = 10000 (100%).
    # Okay, this gives 100% at day 2.
    # We need 9500 at some day >= L.
    # Let's try Day 1. If L=1, Day 1 gives 0 at target.
    # Let's add a direct path.
    # 0->3 (100). Then Day 1 = 10000.
    # To get 9500 at Day 1: 0->3 (95) and 0->1 (5). But then Day 1 has 9500 at 3.
    # Yes!
    # Graph: N=4, L=1. Target 3.
    # 0: [0, 500, 0, 9500] -> Total 10000.
    # 1: [0, 0, 0, 10000]
    # 2: [0, 0, 0, 10000]
    # 3: [0, 0, 0, 0]
    # Wait, counts must be integers. 9500 is huge.
    # Scale down counts. Divide all by 100.
    # 0: [0, 50, 0, 95] -> Total 145.
    # Probabilities: 50/145 = 3448/10000, 95/145 = 6551/10000.
    # Not 9500.
    # To get exactly 9500, sum must be multiple of 10000.
    # Let S = sum. 95/S = 9500/10000 => S=100.
    # So counts must sum to 100 for exact match.
    # 0: [0, 5, 0, 95] (Sum 100).
    # 1: [0, 0, 0, 100] (Sum 100).
    # 2: [0, 0, 0, 100].
    # 3: [0, 0, 0, 0].
    # Day 1: P(3) = 95/100 = 9500.
    # If L=1, T=1 is answer.
    # If L=2, Day 1: P(3)=9500, P(1)=500. Day 2: P(3) = 9500 + 500 = 10000. No 9500.
    # So Test Case 1: N=4, L=1. Matrix as above. Expected T=1.
    # But we need to store matrix in inputs. We have 8x8 inputs.
    # N=4 means we use 0..3.
    # Inputs are 64 signals. We need to map the flattened matrix.
    # adj_matrix[i][j] is adj_matrix_flat[i*8 + j] (since N max 8).
    
    # TEST CASE 1: N=4, L=1, Expect T=1
    dut.N.value = 4
    dut.L.value = 1
    # Matrix 0
    dut.adj_matrix_0_0.value = 0; dut.adj_matrix_0_1.value = 5; dut.adj_matrix_0_2.value = 0; dut.adj_matrix_0_3.value = 95
    dut.adj_matrix_0_4.value = 0; dut.adj_matrix_0_5.value = 0; dut.adj_matrix_0_6.value = 0; dut.adj_matrix_0_7.value = 0
    # Matrix 1
    dut.adj_matrix_1_0.value = 0; dut.adj_matrix_1_1.value = 0; dut.adj_matrix_1_2.value = 0; dut.adj_matrix_1_3.value = 100
    dut.adj_matrix_1_4.value = 0; dut.adj_matrix_1_5.value = 0; dut.adj_matrix_1_6.value = 0; dut.adj_matrix_1_7.value = 0
    # Matrix 2
    dut.adj_matrix_2_0.value = 0; dut.adj_matrix_2_1.value = 0; dut.adj_matrix_2_2.value = 0; dut.adj_matrix_2_3.value = 100
    dut.adj_matrix_2_4.value = 0; dut.adj_matrix_2_5.value = 0; dut.adj_matrix_2_6.value = 0; dut.adj_matrix_2_7.value = 0
    # Matrix 3 (zeros)
    for i in range(3, 8):
        for j in range(8):
            attr = f"adj_matrix_{i}_{j}"
            getattr(dut, attr).value = 0
    
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done (max cycles estimate: N*N updates * 265 days * latency per update)
    # Let's wait for 5000 cycles max
    cycles = 0
    while not dut.done.value and cycles < 5000:
        await RisingEdge(dut.clk)
        cycles += 1
    
    if dut.done.value:
        result = int(dut.result.value)
        print(f"Test 1: N=4, L=1 -> Result: {result}, Expected: 1")
        assert result == 1, f"Test 1 Failed: Expected 1, got {result}"
    else:
        print("Test 1: Timeout")
        assert False, "Test 1 Timeout"

    # TEST CASE 2: No solution
    # Graph where probability jumps from 0 to 100%
    # 0->1 (100)
    # 1->2 (100)
    # N=3, L=1. Target 2.
    # Day 1: P(1)=10000. Day 2: P(2)=10000.
    # T=1 gives 0. T=2 gives 10000. T=3 gives 10000.
    # We need 9500. None found.
    # Reset
    dut.rst_n.value = 0
    await Timer(25, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    dut.N.value = 3
    dut.L.value = 1
    # 0->1: 100
    dut.adj_matrix_0_0.value = 0; dut.adj_matrix_0_1.value = 100; dut.adj_matrix_0_2.value = 0
    # 1->2: 100
    dut.adj_matrix_1_0.value = 0; dut.adj_matrix_1_1.value = 0; dut.adj_matrix_1_2.value = 100
    # 2: 0
    dut.adj_matrix_2_0.value = 0; dut.adj_matrix_2_1.value = 0; dut.adj_matrix_2_2.value = 0
    # Zeros for rest
    for i in range(3, 8):
        for j in range(8):
            attr = f"adj_matrix_{i}_{j}"
            getattr(dut, attr).value = 0
            
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    cycles = 0
    while not dut.done.value and cycles < 5000:
        await RisingEdge(dut.clk)
        cycles += 1
    
    if dut.done.value:
        result = int(dut.result.value)
        print(f"Test 2: N=3, L=1 -> Result: {result}, Expected: -1 (represented as 255)")
        # Module should output 255 for -1
        assert result == 255, f"Test 2 Failed: Expected 255, got {result}"
    else:
        print("Test 2: Timeout")
        assert False, "Test 2 Timeout"

    # TEST CASE 3: Find T=2
    # Graph: 0->1 (95), 0->2 (5). 1->2 (100).
    # N=3, L=2. Target 2.
    # Day 1: P(1)=9500, P(2)=500.
    # Day 2: P(2) = 500 + 9500 = 10000.
    # Still no 9500.
    # Let's try: 0->1 (100), 1->2 (95), 1->3 (5). (But N=3, so max index 2).
    # Okay, let's use 4 nodes. 0->1 (100), 1->2 (95), 1->3 (5). Target 2.
    # Day 1: P(1)=10000.
    # Day 2: P(2)=9500, P(3)=500.
    # If L=2, T=2.
    # Reset
    dut.rst_n.value = 0
    await Timer(25, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    dut.N.value = 4 # Nodes 0,1,2,3. Target 3? No, Target 2. Wait, Target is N-1.
    # If N=4, Target is 3.
    # Let's adjust. Target is 3.
    # 0->1 (100)
    # 1->2 (95), 1->3 (5).
    # Day 1: P(1)=10000.
    # Day 2: P(2)=9500, P(3)=500.
    # We need T where P(Target) = 9500.
    # At Day 2, P(3)=500. Not it.
    # Wait, if we want P(3)=9500, we need 1->3 (95), 1->2 (5).
    # Day 2: P(3)=9500.
    # So: 0->1 (100), 1->3 (95), 1->2 (5).
    # Target is 3. N=4. L=2.
    # Expected T=2.
    dut.N.value = 4
    dut.L.value = 2
    # 0->1: 100
    dut.adj_matrix_0_0.value = 0; dut.adj_matrix_0_1.value = 100; dut.adj_matrix_0_2.value = 0; dut.adj_matrix_0_3.value = 0
    # 1->3: 95, 1->2: 5
    dut.adj_matrix_1_0.value = 0; dut.adj_matrix_1_1.value = 0; dut.adj_matrix_1_2.value = 5; dut.adj_matrix_1_3.value = 95
    # 2->X: 0
    dut.adj_matrix_2_0.value = 0; dut.adj_matrix_2_1.value = 0; dut.adj_matrix_2_2.value = 0; dut.adj_matrix_2_3.value = 0
    # 3->X: 0
    dut.adj_matrix_3_0.value = 0; dut.adj_matrix_3_1.value = 0; dut.adj_matrix_3_2.value = 0; dut.adj_matrix_3_3.value = 0
    # Zeros
    for i in range(4, 8):
        for j in range(8):
            attr = f"adj_matrix_{i}_{j}"
            getattr(dut, attr).value = 0
            
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    cycles = 0
    while not dut.done.value and cycles < 5000:
        await RisingEdge(dut.clk)
        cycles += 1
    
    if dut.done.value:
        result = int(dut.result.value)
        print(f"Test 3: N=4, L=2 -> Result: {result}, Expected: 2")
        assert result == 2, f"Test 3 Failed: Expected 2, got {result}"
    else:
        print("Test 3: Timeout")
        assert False, "Test 3 Timeout"

    print("All tests completed successfully!")
