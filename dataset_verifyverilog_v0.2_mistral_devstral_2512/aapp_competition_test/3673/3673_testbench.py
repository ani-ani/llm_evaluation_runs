import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
import random

def get_permutation_power(A, K, N):
    # Compute A^K
    res = [0] * N
    curr = list(range(N))
    # A is given as a list of integers 1..N in problem text, but here we handle 0..N-1
    # The problem input is a_i. If dancer i moves to position of a_i.
    # Let's use 0-indexed for internal logic.
    # If input is [3, 4, 5, 6, 1, 2] for N=6 (1-based)
    # This means 1->3, 2->4, 3->5, 4->6, 5->1, 6->2.
    # In 0-based: 0->2, 1->3, 2->4, 3->5, 4->0, 5->1.
    # We need P such that P^K = A.
    
    # Let's implement exponentiation by squaring for permutation
    result_perm = list(range(N))
    base_perm = list(A)
    
    # Handle 1-based vs 0-based. The testbench will convert 1-based input to 0-based for HDL.
    # HDL expects 0..N-1.
    
    while K > 0:
        if K % 2 == 1:
            # result_perm = result_perm * base_perm
            temp = [0] * N
            for i in range(N):
                temp[i] = base_perm[result_perm[i]]
            result_perm = temp
        # base_perm = base_perm * base_perm
        temp = [0] * N
        for i in range(N):
            temp[i] = base_perm[base_perm[i]]
        base_perm = temp
        K //= 2
    return result_perm

def gcd(a, b):
    while b:
        a, b = b, a % b
    return a

def solve_permutation(N, K, A):
    # A is 0-indexed array of size N
    # Returns P (0-indexed) or None if impossible
    
    visited = [False] * N
    P = [-1] * N
    
    for i in range(N):
        if visited[i]:
            continue
        
        # Find cycle in A starting at i
        cycle = []
        curr = i
        while not visited[curr]:
            visited[curr] = True
            cycle.append(curr)
            curr = A[curr]
        
        L = len(cycle)
        G = gcd(L, K)
        M = L // G
        
        # For each split cycle in P
        for offset in range(G):
            for j in range(M):
                idx = (offset + j * K) % L
                next_idx = (offset + (j + 1) * K) % L
                u = cycle[idx]
                v = cycle[next_idx]
                if P[u] != -1:
                    return None # Conflict
                P[u] = v
    
    return P

@cocotb.test()
async def test_dance_solver(dut):
    # Create clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.N.value = 0
    dut.K.value = 0
    for i in range(8):
        dut.A_in[i].value = 0
    
    await RisingEdge(dut.clk)
    await Timer(1, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases (scaled for N<=8, K<=255)
    # Case 1: N=6, K=2
    # Input (1-based): 3 4 5 6 1 2
    # 0-based: 2 3 4 5 0 1
    # Solution (1-based): 5 6 1 2 3 4 -> 0-based: 4 5 0 1 2 3
    N1 = 6
    K1 = 2
    A1 = [2, 3, 4, 5, 0, 1]
    P1_expected = [4, 5, 0, 1, 2, 3]
    
    # Case 2: N=4, K=2
    # Input: 3 4 1 2 -> 0-based: 2 3 0 1
    # Solution: 2 3 4 1 -> 0-based: 1 2 3 0
    N2 = 4
    K2 = 2
    A2 = [2, 3, 0, 1]
    P2_expected = [1, 2, 3, 0]

    # Case 3: N=3, K=2 (Check gcd logic)
    # A = [2, 0, 1] (Cycle 0->2->1->0, length 3)
    # K=2. gcd(3,2)=1. Length in P is 3.
    # P = [1, 2, 0] (P^2 = [2, 0, 1])
    N3 = 3
    K3 = 2
    A3 = [2, 0, 1]
    P3_expected = [1, 2, 0]

    test_cases = [
        (N1, K1, A1, P1_expected),
        (N2, K2, A2, P2_expected),
        (N3, K3, A3, P3_expected)
    ]

    passed = 0
    total = len(test_cases)

    for N, K, A, P_expected in test_cases:
        dut.N.value = N
        dut.K.value = K
        for i in range(8):
            if i < N:
                dut.A_in[i].value = A[i]
            else:
                dut.A_in[i].value = 0
        
        # Start
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        timeout = 0
        while not dut.done.value and timeout < 200:
            await RisingEdge(dut.clk)
            timeout += 1
        
        if not dut.done.value:
            print(f"Timeout for N={N}, K={K}")
            continue
            
        # Check result
        if dut.possible.value == 1:
            # Construct P from output
            P_out = []
            for i in range(N):
                P_out.append(int(dut.P_out[i].value))
            
            # Verify P^K == A
            # Compute P^K
            P_power = get_permutation_power(P_out, K, N)
            
            if P_power == A:
                passed += 1
                print(f"Test passed for N={N}, K={K}")
            else:
                print(f"Test failed: P^K != A. Got {P_power}, Expected {A}")
                print(f"Computed P: {P_out}")
        else:
            print(f"Result marked impossible for N={N}, K={K}")

    print(f"
Summary: {passed}/{total} tests passed")
    assert passed == total, f"Only {passed}/{total} tests passed"
