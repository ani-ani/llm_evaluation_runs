import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from cocotb.result import TestFailure
import random

MODULO = 1000000007

def compute_expected(N, K, f):
    """Compute expected result for the graph coloring problem."""
    if K == 0:
        return 0
    
    # Convert f to 0-indexed internal representation, mark self-loops as -1
    f_internal = []
    for i in range(N):
        val = f[i]
        if val == i + 1:  # f_i = i
            f_internal.append(-1)  # No constraint
        else:
            f_internal.append(val - 1)  # 0-indexed constraint
    
    visited = [False] * N
    result = 1
    
    for start in range(N):
        if visited[start]:
            continue
        if f_internal[start] == -1:
            # No constraints on this node
            visited[start] = True
            result = (result * K) % MODULO
            continue
        
        # Find the component by following the chain
        path = []
        node = start
        while not visited[node] and f_internal[node] != -1:
            visited[node] = True
            path.append(node)
            node = f_internal[node]
        
        # Check if we found a cycle
        if node in path:
            # Find cycle length
            cycle_start = path.index(node)
            cycle_length = len(path) - cycle_start
            component_size = len(path)
        else:
            # This node was already processed in another component
            component_size = len(path)
            cycle_length = 0
            for i in range(component_size):
                visited[path[i]] = True
        
        if cycle_length == 0:
            # No cycle (shouldn't happen in functional graph except singletons)
            continue
        
        # Compute P(C_L, K) = (K-1)^L + (-1)^L * (K-1)
        K1 = K - 1
        if K1 < 0:
            K1 = 0
        
        # Compute (K-1)^cycle_length
        power = pow(K1, cycle_length, MODULO)
        
        if cycle_length % 2 == 0:
            P_cycle = (power + K1) % MODULO
        else:
            P_cycle = (power - K1) % MODULO
        
        # Compute (K-1)^(component_size - cycle_length)
        tree_power = pow(K1, component_size - cycle_length, MODULO)
        
        contrib = (P_cycle * tree_power) % MODULO
        result = (result * contrib) % MODULO
    
    return result

@cocotb.test()
async def test_graph_coloring(dut):
    """Test graph coloring module with multiple test cases."""
    
    # Create clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.N.value = 0
    dut.K.value = 0
    for i in range(8):
        dut.f[i].value = 0
    
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases
    test_cases = [
        # (N, K, f_array, expected_result)
        (2, 3, [2, 1], 6),
        (3, 4, [2, 3, 1], 24),
        (3, 4, [2, 1, 1], 36),
    ]
    
    passed = 0
    total = len(test_cases)
    
    for idx, (N, K, f_arr, expected) in enumerate(test_cases):
        print(f"
Running test case {idx + 1}: N={N}, K={K}, f={f_arr}")
        
        # Set inputs
        dut.N.value = N
        dut.K.value = K
        for i in range(8):
            if i < N:
                dut.f[i].value = f_arr[i]
            else:
                dut.f[i].value = 0
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        timeout = 500
        cycles = 0
        while not dut.done.value and cycles < timeout:
            await RisingEdge(dut.clk)
            cycles += 1
        
        if cycles >= timeout:
            raise TestFailure(f"Test {idx + 1}: Timeout waiting for done")
        
        # Check result
        result = int(dut.result.value)
        
        if result == expected:
            print(f"  PASS: result = {result}")
            passed += 1
        else:
            print(f"  FAIL: expected {expected}, got {result}")
            raise TestFailure(f"Test {idx + 1}: Expected {expected}, got {result}")
        
        # Small delay between tests
        await Timer(100, units='ns')
        await RisingEdge(dut.clk)
    
    print(f"
=== SUMMARY: {passed}/{total} tests passed ===")
    if passed == total:
        print("All tests passed successfully!")