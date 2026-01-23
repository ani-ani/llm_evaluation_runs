import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer, FallingEdge
from cocotb.result import TestFailure
import random

def calculate_expected(N, K, updates, queries):
    seq = [0] * N
    for jump in updates:
        for i in range(0, N, jump):
            seq[i] += 1
    
    # Prefix sums
    prefix = [0] * (N + 1)
    for i in range(N):
        prefix[i+1] = prefix[i] + seq[i]
    
    results = []
    for L, R in queries:
        res = prefix[R+1] - prefix[L]
        results.append(res)
    return results

@cocotb.test()
async def test_array_debug(dut):
    # Constants for scaling
    N = 64
    MAX_K = 32
    MAX_Q = 32
    
    # Create a clock (10ns period)
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.k_val.value = 0
    dut.q_val.value = 0
    dut.update_val.value = 0
    dut.update_valid.value = 0
    dut.query_l.value = 0
    dut.query_r.value = 0
    dut.query_valid.value = 0
    
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases: (K, updates, queries)
    test_cases = [
        (4, [1, 1, 2, 1], [(0, 9), (2, 6), (7, 7)]),
        (3, [3, 7, 10], [(0, 10), (2, 6), (7, 7)]),
    ]
    
    for k, updates, queries in test_cases:
        print(f"Running test case with K={k}, Q={len(queries)}")
        
        # 1. Start
        dut.k_val.value = k
        dut.q_val.value = len(queries)
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # 2. Feed updates
        for i in range(k):
            # Wait for ready
            while not dut.ready_for_update.value:
                await RisingEdge(dut.clk)
            
            dut.update_val.value = updates[i]
            dut.update_valid.value = 1
            await RisingEdge(dut.clk)
            dut.update_valid.value = 0
            
        # 3. Wait for prefix building (internal operation)
        # In the hardware, we need to wait until it's ready for queries.
        # We add a timeout to catch bugs.
        timeout = 0
        while not dut.ready_for_query.value and timeout < 500:
            await RisingEdge(dut.clk)
            timeout += 1
        
        if timeout >= 500:
            raise TestFailure("Timeout waiting for ready_for_query")
            
        # 4. Feed queries and check results
        expected_results = calculate_expected(N, k, updates, queries)
        received_results = []
        
        for q_l, q_r in queries:
            # Wait for ready
            timeout = 0
            while not dut.ready_for_query.value and timeout < 100:
                await RisingEdge(dut.clk)
                timeout += 1
            if timeout >= 100:
                raise TestFailure("Timeout waiting for ready_for_query during queries")
            
            dut.query_l.value = q_l
            dut.query_r.value = q_r
            dut.query_valid.value = 1
            await RisingEdge(dut.clk)
            dut.query_valid.value = 0
            
            # Wait for result. 
            # We need to look at the output 'result' and perhaps a 'result_valid' signal.
            # The prompt specified 'done' for completion, but we need a signal for individual result.
            # Let's assume 'done' goes high for one cycle when a result is ready, or we check 'result' directly.
            # Re-reading prompt: "output reg done // high when all queries are processed"
            # It doesn't explicitly ask for a per-query valid signal.
            # However, in sequential logic, we usually have a valid signal.
            # Let's assume 'done' is per query if not specified, or check if 'result' changes.
            # Actually, let's look for a result valid signal or just check on the next cycle.
            # The hardware design should ideally have a 'result_valid'.
            # If the prompt doesn't specify it, I'll add it to the design in the 'prompt' field implicitly or check 'done' 
            # if 'done' is defined as 'result valid'.
            # Let's check the 'prompt' section again. 
            # "output reg done // high when all queries are processed"
            # Okay, 'done' is for all queries.
            # I will add a 'result_valid' signal to the prompt to make testing feasible.
            # If 'result_valid' isn't in the prompt, I will look for 'done' being high or falling edge.
            # Let's assume the hardware design provides a 'result_valid' or 'done' pulses for each result.
            # I'll modify the prompt to include 'result_valid'.
            
            # Wait for result_valid (assuming I added it to prompt or it's implied)
            # Let's assume the hardware is designed so that 'result' is valid 1 cycle after query input.
            await RisingEdge(dut.clk)
            
            # Read result
            res = int(dut.result.value)
            received_results.append(res)
            
            if res != expected_results.pop(0):
                raise TestFailure(f"Query mismatch: Expected {expected_results[0]}, got {res}")
                
        print(f"Passed test case")
        
    print("All tests passed!")