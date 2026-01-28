import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Helpers
def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def clamp_to_width(v, bits):
    max_val = (1 << bits) - 1
    if v < 0: return 0
    if v > max_val: return max_val
    return v

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=2000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

# Python reference implementation for verification
def solve_python(N, times, adj_matrix):
    # adj_matrix[i][j] = 1 if j depends on i
    min_total = 0xFFFFFFFF
    
    # Original times (copy to avoid modification issues)
    original_times = list(times)
    
    for remove_idx in range(N):
        # DP for longest path
        # dp[i] = longest time from step 0 to step i
        dp = [0] * N
        
        # Iterate in topological order (0 to N-1)
        for i in range(N):
            if i == remove_idx:
                continue
            
            # Time for this node (0 if removed, but handled by skip logic)
            # Actually, if we remove step remove_idx, we set its duration to 0
            # But we must also ensure dependencies are respected.
            # The problem says "reduce time to 0", which effectively means it takes 0 time.
            # It still exists for dependencies? 
            # "eliminate exactly one" vs "reduce to 0". 
            # If reduced to 0, it still "exists" as a step, just instant.
            # So we just set time[remove_idx] = 0.
            
            current_time = 0 if i == remove_idx else original_times[i]
            
            # Find max predecessor
            max_pred = 0
            for p in range(N):
                if p == remove_idx: 
                    # Predecessor is instant, but that's fine, we take its dp value
                    pass
                if adj_matrix[p][i] == 1:
                    # p is a predecessor
                    if dp[p] > max_pred:
                        max_pred = dp[p]
            
            # If no dependencies (step 0), max_pred is 0
            dp[i] = max_pred + current_time
            
        # Total time is dp[N-1] (step N)
        total = dp[N-1]
        if total < min_total:
            min_total = total
            
    return min_total

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_airplane_construction(dut):
    # Setup Clock
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    await reset_dut(dut)
    
    # Test Cases: N, times, adj_matrix (flattened), expected result
    # Note: adj_matrix[i][j] = 1 means j depends on i
    
    test_cases = [
        # Case 1: N=2, times=[15, 20], 1 depends on nothing, 2 depends on 1
        (2, [15, 20], [[0,1],[0,0]], 15),
        # Case 2: N=4, times=[10, 40, 70, 10]
        # 1: none
        # 2: depends on 1
        # 3: depends on 1
        # 4: depends on 2, 3
        # Path 1->2->4: 10+40+10 = 60
        # Path 1->3->4: 10+70+10 = 90
        # Max = 90. Removing 3 gives 60. Removing 2 gives 80. Removing 1 gives 80. Removing 4 gives 80.
        (4, [10, 40, 70, 10], [[0,1,1,0], [0,0,0,1], [0,0,0,1], [0,0,0,0]], 60)
    ]
    
    for idx, (N, times, adj, expected) in enumerate(test_cases):
        cocotb.log.info(f"Running Test Case {idx+1}: N={N}, Expected={expected}")
        
        # Write Inputs
        dut.N.value = N
        
        # Write Step Times (0-indexed for array access)
        for i in range(N):
            dut.step_time[i].value = clamp_to_width(times[i], 16)
            
        # Write Adjacency Matrix
        for r in range(N):
            for c in range(N):
                dut.adj_matrix[r][c].value = adj[r][c]
                
        # Start
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        await wait_for_done(dut)
        
        # Read Result
        if not is_value_defined(dut.result.value):
            raise TestFailure("Result signal is undefined")
            
        result = int(dut.result.value)
        cocotb.log.info(f"Result: {result}")
        
        if result != expected:
            raise TestFailure(f"Test {idx+1} Failed: Expected {expected}, got {result}")
