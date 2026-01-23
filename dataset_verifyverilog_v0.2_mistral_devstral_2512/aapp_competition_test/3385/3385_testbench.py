import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from cocotb.result import TestFailure

@cocotb.test()
async def test_costume_solver(dut):
    """Test costume_solver module with various inputs"""
    
    # Helper function to compute expected result
    def compute_expected(n, constraints):
        """Compute expected number of solutions using Python"""
        MOD = 10**9 + 7
        
        if n == 0:
            return 1
        
        # Build matrix over GF(2)
        # Variables: c_0, c_1, ..., c_{n-1}
        # Equations: sum of window = x_i (mod 2)
        matrix = [[0] * (n + 1) for _ in range(n)]  # n equations, n vars + augmented
        
        for i, (l, r, x) in enumerate(constraints):
            # Set bits for window [i-l, i+r] mod n
            for j in range(-l, r + 1):
                idx = (i + j) % n
                matrix[i][idx] = 1
            matrix[i][n] = x  # augmented column
        
        # Gaussian elimination over GF(2)
        rank = 0
        pivot_cols = []
        
        for col in range(n):
            # Find pivot
            pivot = -1
            for row in range(rank, n):
                if matrix[row][col] == 1:
                    pivot = row
                    break
            
            if pivot == -1:
                continue
            
            # Swap
            matrix[rank], matrix[pivot] = matrix[pivot], matrix[rank]
            
            # Eliminate
            for row in range(n):
                if row != rank and matrix[row][col] == 1:
                    for c in range(col, n + 1):
                        matrix[row][c] ^= matrix[rank][c]
            
            pivot_cols.append(col)
            rank += 1
        
        # Check consistency
        for row in range(rank, n):
            if matrix[row][n] == 1:
                return 0  # Inconsistent
        
        # Solutions = 2^(n-rank) mod MOD
        return pow(2, n - rank, MOD)
    
    # Initialize
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.n.value = 0
    dut.i.value = 0
    dut.l.value = 0
    dut.r.value = 0
    dut.x.value = 0
    
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    await Timer(20, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test Case 1: n=5, inconsistent constraints
    n = 5
    constraints = [
        (1, 0, 0),
        (1, 0, 1),
        (3, 0, 1),
        (3, 0, 0),
        (3, 0, 1)
    ]
    
    dut.n.value = n
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Load constraints
    for idx, (l_val, r_val, x_val) in enumerate(constraints):
        dut.i.value = idx
        dut.l.value = l_val
        dut.r.value = r_val
        dut.x.value = x_val
        await RisingEdge(dut.clk)
    
    # Wait for completion
    timeout = 0
    while not dut.done.value and timeout < 500:
        await RisingEdge(dut.clk)
        timeout += 1
    
    if timeout >= 500:
        raise TestFailure("Test 1: Timeout waiting for done")
    
    expected = compute_expected(n, constraints)
    result = int(dut.result.value)
    impossible = int(dut.impossible.value)
    
    if expected == 0:
        if not impossible:
            raise TestFailure(f"Test 1: Expected impossible=1, got 0. Result={result}")
    else:
        if impossible:
            raise TestFailure(f"Test 1: Expected impossible=0, got 1. Result={result}")
        if result != expected:
            raise TestFailure(f"Test 1: Result {result} != expected {expected}")
    
    print(f"Test 1 passed: n={n}, result={result}, impossible={impossible}")
    
    # Reset for next test
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test Case 2: n=5, consistent constraints, 4 solutions
    n = 5
    constraints = [
        (3, 1, 1),
        (0, 3, 1),
        (1, 3, 1),
        (1, 2, 1),
        (0, 4, 1)
    ]
    
    dut.n.value = n
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for idx, (l_val, r_val, x_val) in enumerate(constraints):
        dut.i.value = idx
        dut.l.value = l_val
        dut.r.value = r_val
        dut.x.value = x_val
        await RisingEdge(dut.clk)
    
    timeout = 0
    while not dut.done.value and timeout < 500:
        await RisingEdge(dut.clk)
        timeout += 1
    
    if timeout >= 500:
        raise TestFailure("Test 2: Timeout waiting for done")
    
    expected = compute_expected(n, constraints)
    result = int(dut.result.value)
    impossible = int(dut.impossible.value)
    
    if expected == 0:
        if not impossible:
            raise TestFailure(f"Test 2: Expected impossible=1, got 0. Result={result}")
    else:
        if impossible:
            raise TestFailure(f"Test 2: Expected impossible=0, got 1. Result={result}")
        if result != expected:
            raise TestFailure(f"Test 2: Result {result} != expected {expected}")
    
    print(f"Test 2 passed: n={n}, result={result}, impossible={impossible}")
    
    # Test Case 3: n=1, single child, odd parity
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    n = 1
    constraints = [(0, 0, 1)]  # Child 0 must be pumpkin
    
    dut.n.value = n
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    dut.i.value = 0
    dut.l.value = 0
    dut.r.value = 0
    dut.x.value = 1
    await RisingEdge(dut.clk)
    
    timeout = 0
    while not dut.done.value and timeout < 500:
        await RisingEdge(dut.clk)
        timeout += 1
    
    if timeout >= 500:
        raise TestFailure("Test 3: Timeout")
    
    expected = compute_expected(n, constraints)
    result = int(dut.result.value)
    impossible = int(dut.impossible.value)
    
    if expected != 1:
        raise TestFailure(f"Test 3: Expected 1, got {expected}")
    if result != 1:
        raise TestFailure(f"Test 3: Result {result} != expected 1")
    if impossible:
        raise TestFailure(f"Test 3: Should not be impossible")
    
    print(f"Test 3 passed: n={n}, result={result}")
    
    # Test Case 4: n=2, both constraints same (redundant)
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    n = 2
    constraints = [
        (0, 1, 1),  # c0 + c1 = 1
        (0, 1, 1)   # c0 + c1 = 1 (redundant)
    ]
    
    dut.n.value = n
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for idx, (l_val, r_val, x_val) in enumerate(constraints):
        dut.i.value = idx
        dut.l.value = l_val
        dut.r.value = r_val
        dut.x.value = x_val
        await RisingEdge(dut.clk)
    
    timeout = 0
    while not dut.done.value and timeout < 500:
        await RisingEdge(dut.clk)
        timeout += 1
    
    if timeout >= 500:
        raise TestFailure("Test 4: Timeout")
    
    expected = compute_expected(n, constraints)
    result = int(dut.result.value)
    impossible = int(dut.impossible.value)
    
    if expected != 2:
        raise TestFailure(f"Test 4: Expected 2, got {expected}")
    if result != 2:
        raise TestFailure(f"Test 4: Result {result} != expected 2")
    if impossible:
        raise TestFailure(f"Test 4: Should not be impossible")
    
    print(f"Test 4 passed: n={n}, result={result}")
    
    # Test Case 5: n=3, inconsistent (sum of all equations = 0 but RHS sum = 1)
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    n = 3
    constraints = [
        (0, 2, 1),  # c0+c1+c2 = 1
        (0, 2, 1),  # c0+c1+c2 = 1
        (0, 2, 0)   # c0+c1+c2 = 0 (contradicts!)
    ]
    
    dut.n.value = n
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for idx, (l_val, r_val, x_val) in enumerate(constraints):
        dut.i.value = idx
        dut.l.value = l_val
        dut.r.value = r_val
        dut.x.value = x_val
        await RisingEdge(dut.clk)
    
    timeout = 0
    while not dut.done.value and timeout < 500:
        await RisingEdge(dut.clk)
        timeout += 1
    
    if timeout >= 500:
        raise TestFailure("Test 5: Timeout")
    
    expected = compute_expected(n, constraints)
    result = int(dut.result.value)
    impossible = int(dut.impossible.value)
    
    if expected != 0:
        raise TestFailure(f"Test 5: Expected 0, got {expected}")
    if not impossible:
        raise TestFailure(f"Test 5: Should be impossible")
    if result != 0:
        raise TestFailure(f"Test 5: Result should be 0, got {result}")
    
    print(f"Test 5 passed: n={n}, result={result}, impossible={impossible}")
    
    print("
All 5 tests passed!")
