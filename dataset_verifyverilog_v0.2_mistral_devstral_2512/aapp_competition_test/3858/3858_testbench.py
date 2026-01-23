import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from cocotb.result import TestFailure
import random

MOD = 998244353

def calculate_score(n, points):
    """
    Python reference for the testbench.
    Calculates sum of scores for convex polygons.
    Formula: 2^N - 1 - N - sum_over_lines(2^k - k - 1)
    """
    if n == 0:
        return 0
    
    # Total subsets excluding empty set = 2^N - 1
    # We want to subtract subsets that are NOT convex polygons.
    # Non-convex subsets are: 
    # 1. Empty set (but we started with 2^N - 1, so empty is already excluded)
    # 2. Single points (N of them)
    # 3. Collinear subsets of size >= 2.
    
    ans = pow(2, n, MOD)
    ans = (ans - 1 - n) % MOD  # Remove empty and single points
    
    used = [[False] * n for _ in range(n)]
    
    for i in range(n):
        for j in range(i + 1, n):
            if used[i][j]:
                continue
            
            # Find collinear points for line i-j
            collinear = []
            collinear.append(i)
            collinear.append(j)
            
            xi, yi = points[i]
            xj, yj = points[j]
            
            dx = xj - xi
            dy = yj - yi
            
            for k in range(n):
                if k == i or k == j:
                    continue
                xk, yk = points[k]
                # Check if k is on line i-j using cross product
                # (xj - xi) * (yk - yi) == (xk - xi) * (yj - yi)
                if dx * (yk - yi) == (xk - xi) * dy:
                    collinear.append(k)
            
            v = len(collinear)
            if v > 2:
                # Subtract (2^v - v - 1) because these subsets are collinear (not convex)
                # Note: We also need to subtract subsets of these collinear points that are smaller?
                # The formula applies to all collinear subsets. 
                # If we have v collinear points, there are 2^v subsets total.
                # We subtract subsets of size 0 (already removed), size 1 (already removed).
                # We subtract subsets of size >= 2.
                # So subtract (2^v - 1 - v).
                to_sub = (pow(2, v, MOD) - 1 - v) % MOD
                ans = (ans - to_sub) % MOD
                
                # Mark all pairs in this set as used to avoid recounting
                for u in collinear:
                    for w in collinear:
                        if u < w:
                            used[u][w] = True
            else:
                # v=2 (just the line segment), it is a convex polygon of 2? No, 2 points don't form a polygon with area.
                # It is already excluded by the -N term (single points) and 2 points are not polygons.
                # But wait, the problem states "convex polygon with positive area".
                # So size 2 sets are not counted. 
                # The term (2^2 - 2 - 1) = 1. This would subtract the pair itself.
                # The pair {i, j} is NOT a valid convex polygon (needs > 2 points).
                # Is it excluded by "-N"? No, "-N" excludes singletons.
                # So we MUST subtract pairs as well.
                # However, pairs are subsets of size 2. They have area 0. 
                # So yes, we should subtract them.
                # The formula (2^v - v - 1) for v=2 is 1. Correct.
                
                # But wait, in the sample N=4 (square):
                # Ans = 2^4 - 1 - 4 = 16 - 1 - 4 = 11.
                # Lines? No collinear points (no 3 on line). 
                # So ans = 11? But sample output is 5.
                # Why? Because triangles (size 3) and square (size 4) are valid.
                # Total subsets = 16. 
                # Valid convex subsets: 4 triangles + 1 square = 5.
                # Non-convex: Empty (1), Single (4), Pairs (C(4,2)=6). Total 11.
                # Ah! Pairs are ALWAYS non-convex (no area).
                # My formula `2^N - 1 - N - sum(2^k - k - 1)` counts pairs as non-convex because I subtract them in the loop?
                # If I loop over pairs (i, j) and v=2, I subtract 1.
                # There are 6 pairs. I subtract 6.
                # Current ans = 11 - 6 = 5. Correct!
                
                # So we must process ALL pairs. 
                # If v=2, we subtract 1 and mark used.
                
                # To optimize, we can just subtract N*(N-1)/2 for pairs if no collinearity? 
                # But we need to handle collinearity correctly.
                # If v>2, we subtracted (2^v - v - 1) which includes the pairs.
                # If v=2, we subtract 1.
                
                # So the logic holds.
                # However, we must ensure we don't double count.
                # The `used` array handles this.
                
                # So for v=2:
                ans = (ans - 1) % MOD
                used[i][j] = True
                
    return ans % MOD

@cocotb.test()
async def test_convex_scoring(dut):
    """Test the convex scoring module"""
    
    # Setup clock (50MHz)
    clock = Clock(dut.clk, 20, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(100, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # We can't easily test with N=200 because of input interface limits in simulation
    # We will test with small N <= 16 as per our adaptation.
    
    test_cases = [
        # N, [(x,y), ...]
        (4, [(0,0), (0,1), (1,0), (1,1)]), # Square -> 5
        (3, [(0,0), (1,0), (0,1)]), # Triangle -> 1
        (3, [(0,0), (1,0), (2,0)]), # Collinear -> 0
        (5, [(0,0), (0,1), (0,2), (0,3), (1,1)]), # Collinear + one off -> 5 (triangles with (1,1) and two of the line) + square? No. 
        # Pts: 0,1,2,3 on line, 4 off.
        # Valid polygons: Must have area.
        # Any 3 pts: If 3 from line -> 0 area (invalid). 
        # If 2 from line + off -> valid.
        # Number of such sets: C(4,2) * 1 = 6.
        # Any 4 pts: 3 line + off -> area > 0? Yes. 
        # 3 line + off is a triangle. (4 sets).
        # 2 line + off + ... only 1 off. So only triangles.
        # Any 5 pts: All 5. Area > 0. Valid. (1 set).
        # Total valid: 6 + 4 + 1 = 11. (Sample 2 output is 11).
        (5, [(0,0), (0,1), (0,2), (0,3), (1,1)]),
        (0, []), # Edge case
        (1, [(10,10)]), # Edge case
    ]
    
    for n, points in test_cases:
        if n > 16:
            print(f"Skipping N={n} > 16")
            continue
            
        dut.N.value = n
        
        # In Verilog, we assume inputs are registered. 
        # Since we have N inputs, we might need a way to load them.
        # For this testbench, let's assume the module has a generic input mechanism.
        # Actually, the prompt implies a fixed interface. 
        # To make this work, let's assume the module has ports:
        # input [15:0] x_i, y_i (and we iterate index i)
        # OR a memory interface. 
        # Given the prompt constraints, let's assume a simple interface:
        # inputs are fed into the DUT directly if N is small.
        
        # Let's assume the DUT has a 'points_x' and 'points_y' array input of size 16.
        # We will populate it.
        
        for i in range(16):
            if i < n:
                dut.points_x[i].value = points[i][0]
                dut.points_y[i].value = points[i][1]
            else:
                dut.points_x[i].value = 0
                dut.points_y[i].value = 0
                
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        timeout = 10000
        for _ in range(timeout):
            await RisingEdge(dut.clk)
            if dut.done.value == 1:
                break
        else:
            raise TestFailure(f"Timeout for N={n}")
            
        # Check result
        expected = calculate_score(n, points)
        actual = int(dut.result.value)
        
        print(f"N={n}, Expected={expected}, Actual={actual}")
        if actual != expected:
            raise TestFailure(f"Result mismatch: {actual} != {expected}")
            
    print(f"Passed {len(test_cases)}/{len(test_cases)} tests")
