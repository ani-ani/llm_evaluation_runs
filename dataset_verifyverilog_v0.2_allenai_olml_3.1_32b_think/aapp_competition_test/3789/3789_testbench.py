import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, Timer
from cocotb.result import TestFailure
import random

# Helper to map python integers to verilog logic vectors (2's complement)
def to_twos_complement(val, bits):
    if val < 0:
        return (1 << bits) + val
    return val

@cocotb.test()
async def test_gem_smash_solver(dut):
    """Test the Gem Smash Solver module"""
    
    # Setup Clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.gem_values.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test Cases (Scaled down from original)
    test_cases = [
        # Case 1: Sample Input scaled
        # N=6, [1, 2, -6, 4, 5, 3] -> Answer 12
        # We use N=16, pad with zeros
        [1, 2, -6, 4, 5, 3] + [0]*10,
        
        # Case 2: All positive -> Keep all
        [5]*16,
        
        # Case 3: All negative -> Keep none (earn 0)
        [-5]*16,
        
        # Case 4: Mixed large values
        [100, -100, -100, -100, 100, -100] + [0]*10, # Adapted from inputs
        
        # Case 5: Random values
        [random.randint(-50, 50) for _ in range(16)]
    ]
    
    for i, values in enumerate(test_cases):
        dut._log.info(f"Running Test Case {i+1}: {values[:6]}...")
        
        # Calculate Expected Result (Pure Python)
        # This simulates the max flow/min cut logic
        # Since the Verilog implementation is simplified, we compare against a python implementation
        # of the specific logic we expect the Verilog to implement.
        
        expected = calculate_expected(values)
        
        # Input Data
        packed_val = 0
        for idx, v in enumerate(values):
            v_2c = to_twos_complement(v, 16)
            packed_val |= (v_2c << (idx * 16))
        dut.gem_values.value = packed_val
        
        # Start
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for Done (with timeout)
        cycles = 0
        while not dut.done.value and cycles < 500:
            await RisingEdge(dut.clk)
            cycles += 1
            
        if cycles >= 500:
            raise TestFailure(f"Test {i+1}: Module did not finish in time")
            
        # Check Result
        actual = int(dut.max_earnings.value)
        
        # Allow slight deviations if simplified approximations are used, 
        # but for this benchmark we try to be exact on the scaled problem.
        # Note: The simplified algo in prompt might miss some edge cases vs full max flow,
        # but we check against the full calculation here.
        
        if actual != expected:
             # For debugging specific cases
             dut._log.error(f"Mismatch! Expected {expected}, Got {actual}")
             # In a real benchmark, we might accept close enough, but let's be strict for now
             # Note: If the Verilog implementation is a greedy approximation (heuristic),
             # we might need to relax this. The prompt asks for a "simplified Max Flow".
             # Let's assume we implement a correct (but fixed size) Max Flow.
             
             # Recalculate python max flow to verify expected
             py_max_flow = python_max_flow(values)
             py_total_pos = sum([x for x in values if x > 0])
             expected_min_cut = py_total_pos - py_max_flow
             
             if actual != expected_min_cut:
                 # Re-verify python implementation matches problem statement
                 # If the problem is strictly Min-Cut, then 'actual' should match 'expected_min_cut'
                 # If 'expected' was calculated via heuristic, update it.
                 if expected != expected_min_cut:
                    expected = expected_min_cut
                 
                 if actual != expected:
                    raise TestFailure(f"Test {i+1}: Result mismatch. Exp {expected}, Got {actual}")

# Python Reference Implementation for Verification
def python_max_flow(values):
    # Build graph for N=16
    N = 16
    # Map python list to 1-indexed logic
    A = values
    
    # Using simple Edmonds-Karp for verification
    # Nodes: 0=Source, 1..N=Gems, N+1=Sink
    source = 0
    sink = N + 1
    graph = [[0] * (N+2) for _ in range(N+2)]
    
    for i in range(1, N+1):
        val = A[i-1]
        if val > 0:
            graph[source][i] = val
        elif val < 0:
            graph[i][sink] = -val
            
        # Edges from i to multiples
        if val > 0: # Only relevant if we want to "smash" j if i is smashed (or vice versa)
            # The logic: Smashing x smashes multiples.
            # In min-cut formulation: 
            # Keep node i (no cut i->T) -> Smashed (S->i cut)
            # Cut i->T -> Kept
            # Edge from i to j (mult) with INF capacity.
            # This ensures: If i is NOT smashed (kept, so cut S->i), i is in S-set.
            # If j is smashed (S->j cut), j is in S-set.
            # Wait, let's stick to the standard formulation found in solutions:
            # If gem i is smashed (in S-set), it forces gem j (mult) to be smashed (in S-set).
            # Graph edge: i -> j, INF.
            # If i is in S (smashed) and j is in T (kept), INF edge prevents this.
            # So: 
            # S-set = Smashed
            # T-set = Kept
            # Edge S->i (cap=V_i if V_i > 0) -> Penalty if we smash a positive gem (S->i is cut if smashed? No)
            # Let's use the logic from the sample solutions:
            # Positive gem i: Edge S->i (capacity V_i). 
            # Negative gem i: Edge i->T (capacity -V_i).
            # Edges i->j (INF) for multiples.
            # Min Cut = Min cost.
            # Max Flow = Min Cut cost.
            # Result = Sum(Positive) - MaxFlow.
            
            for j in range(2*i, N+1, i):
                graph[i][j] = 1000000 # Large number
                
    # Edmonds Karp
    def bfs(r_graph):
        q = [(source, [])]
        visited = set([source])
        while q:
            u, path = q.pop(0)
            if u == sink:
                return path + [u]
            for v in range(len(r_graph)):
                if r_graph[u][v] > 0 and v not in visited:
                    visited.add(v)
                    q.append((v, path + [u]))
        return None
        
    flow = 0
    r_graph = [row[:] for row in graph]
    while True:
        path = bfs(r_graph)
        if not path:
            break
        min_cap = min(r_graph[u][v] for u, v in zip(path, path[1:]))
        for u, v in zip(path, path[1:]):
            r_graph[u][v] -= min_cap
            r_graph[v][u] += min_cap
        flow += min_cap
    return flow

def calculate_expected(values):
    py_flow = python_max_flow(values)
    py_sum_pos = sum(x for x in values if x > 0)
    return py_sum_pos - py_flow
