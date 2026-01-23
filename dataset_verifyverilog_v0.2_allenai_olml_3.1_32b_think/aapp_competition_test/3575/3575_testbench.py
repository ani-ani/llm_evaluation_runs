import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer, FallingEdge
import random

def solve_expected(n, edges, s, t):
    # Build adjacency list
    adj = [[] for _ in range(n)]
    for u, v in edges:
        adj[u].append(v)
        adj[v].append(u)
    
    # Check if they can ever meet
    # If graph has disconnected components containing s and t
    visited = set()
    def dfs(u):
        if u in visited: return
        visited.add(u)
        for v in adj[u]:
            dfs(v)
    dfs(s)
    if t not in visited:
        return None

    # Value iteration
    # E[i][j] is expected time from i, j
    # If i==j, E=0
    E = [[0.0]*n for _ in range(n)]
    
    # If a node has no neighbors and it is not the target (i!=j), it's trapped
    # If both are trapped and not same, infinite.
    # Our DP handles this: if deg(i)==0 or deg(j)==0 and i!=j, sum is 0, deg prod is 0.
    # We need to handle deg=0 case explicitly to avoid div by zero.
    
    for _ in range(200): # Enough iterations for convergence
        max_diff = 0.0
        new_E = [[0.0]*n for _ in range(n)]
        for i in range(n):
            for j in range(n):
                if i == j:
                    new_E[i][j] = 0.0
                    continue
                
                deg_i = len(adj[i])
                deg_j = len(adj[j])
                
                if deg_i == 0 or deg_j == 0:
                    # If one is stuck and not same node, infinite time (or stay at 0 if we want)
                    # Ideally infinite. In fixed point, we represent inf as max value.
                    # But if one is stuck, they never meet unless they started at same node.
                    new_E[i][j] = 1e18 # Mark as large
                    continue
                
                total = 0.0
                for u in adj[i]:
                    for v in adj[j]:
                        total += E[u][v]
                
                new_E[i][j] = 1.0 + total / (deg_i * deg_j)
                max_diff = max(max_diff, abs(new_E[i][j] - E[i][j]))
        
        E = new_E
        if max_diff < 1e-6:
            break
            
    res = E[s][t]
    if res > 1e17:
        return None
    return res

@cocotb.test()
async def test_random_walk(dut):
    # Setup clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.n.value = 0
    dut.s.value = 0
    dut.t.value = 0
    dut.adj_flat.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases
    test_cases = [
        {
            'n': 3,
            'edges': [(0, 1), (1, 2)],
            's': 0,
            't': 2,
            'expected': 'never'
        },
        {
            'n': 3,
            'edges': [(0, 1), (1, 2), (0, 2)],
            's': 0,
            't': 2,
            'expected': 1.0
        },
        {
            'n': 4,
            'edges': [(0, 1), (2, 3)],
            's': 0,
            't': 3,
            'expected': 'never'
        }
    ]
    
    for i, tc in enumerate(test_cases):
        print(f"
Running Test Case {i+1}: {tc}")
        
        # Build adjacency flat matrix
        adj_flat = 0
        for u, v in tc['edges']:
            adj_flat |= (1 << (u * 8 + v))
            adj_flat |= (1 << (v * 8 + u))
        
        dut.n.value = tc['n']
        dut.s.value = tc['s']
        dut.t.value = tc['t']
        dut.adj_flat.value = adj_flat
        
        # Start
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        timeout = 2000
        while not dut.valid.value and timeout > 0:
            await RisingEdge(dut.clk)
            timeout -= 1
        
        if timeout == 0:
            print("Error: Timeout")
            assert False, "Timeout"
            
        # Check result
        if tc['expected'] == 'never':
            assert dut.never_meet.value == 1, f"Expected never_meet=1, got {dut.never_meet.value}"
            print("Correctly identified as never meet")
        else:
            # Read Q16.16 result
            res_val = dut.result.value
            # Convert to float
            if res_val >= 0x80000000: # Negative in 2's complement (shouldn't happen)
                res_val = res_val - (1 << 32)
            float_val = res_val / 65536.0
            
            print(f"Result: {float_val:.6f} (Expected: {tc['expected']:.6f})")
            assert abs(float_val - tc['expected']) < 0.01, f"Mismatch: {float_val} vs {tc['expected']}"
            assert dut.never_meet.value == 0, "Should not be never_meet"
            
    print("
All tests passed!")
