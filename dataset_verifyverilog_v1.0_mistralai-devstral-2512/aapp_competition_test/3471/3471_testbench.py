import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Helpers
def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def safe_int(v, default=0):
    try: return int(v)
    except ValueError: return default

def to_signed(val, bits):
    return val - (1 << bits) if val >= (1 << (bits-1)) else val

def from_signed(val, bits):
    return val + (1 << bits) if val < 0 else val

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

DATA_WIDTH = 8
ARRAY_SIZE = 8
CLK_NS = 10
MAX_CYCLES = 2000

# Python reference for xorbonacci and query
def xorbonacci_reference(init_terms, l, r, k):
    # Generate sequence until r
    # init_terms is list of ints (scaled)
    # Returns xor sum from l to r
    
    if r == 0: return 0
    
    # We need terms 1 to r (1-indexed)
    # We only need to keep last k terms for computation
    
    seq = []
    for i in range(k):
        seq.append(init_terms[i])
    
    if r <= k:
        # Just slice the initial terms
        val = 0
        for i in range(l-1, r):
            val ^= seq[i]
        return val
    
    # Compute up to r
    current_xor = 0
    # Calculate prefix xor up to k
    for i in range(k):
        if i+1 <= r:
            if i+1 >= l:
                current_xor ^= seq[i]
    
    # Compute subsequent terms
    # We only need the last k terms to compute next
    # History buffer
    history = seq.copy() # length k
    
    for n in range(k+1, r+1):
        # x_n = x_{n-1} ^ ... ^ x_{n-k}
        next_val = 0
        for val in history:
            next_val ^= val
        
        # Shift history
        history.pop(0)
        history.append(next_val)
        
        if n >= l:
            current_xor ^= next_val
            
    return current_xor

# Python implementation of the Verilog logic (Matrix Exponentiation)
def compute_xor_sum_matrix(init_terms, l, r, k):
    # If K is 0, result is 0
    if k == 0: return 0
    
    # Handle small ranges directly without matrix exponentiation
    if r <= k:
        val = 0
        for i in range(l-1, r):
            val ^= init_terms[i]
        return val
    
    # Matrix Exponentiation approach for large N
    # State vector V_n = [x_n, x_{n-1}, ..., x_{n-k+1}]^T (length k)
    # Transition Matrix T: 
    #   Row 0: [1, 1, ..., 1] (XOR sum)
    #   Row 1: [1, 0, ..., 0]
    #   Row 2: [0, 1, ..., 0]
    #   ...
    #   Row k-1: [0, ..., 1, 0]
    
    # T is a k x k binary matrix
    def mat_mul(A, B, size):
        # Matrix mult over GF(2)
        C = [[0] * size for _ in range(size)]
        for i in range(size):
            for j in range(size):
                val = 0
                for m in range(size):
                    if A[i][m] and B[m][j]:
                        val ^= 1
                C[i][j] = val
        return C

    def mat_pow(T, n, size):
        # T^n
        result = [[0] * size for _ in range(size)]
        for i in range(size):
            result[i][i] = 1
        base = T
        
        while n > 0:
            if n % 2 == 1:
                result = mat_mul(result, base, size)
            base = mat_mul(base, base, size)
            n //= 2
        return result

    def mat_vec_mul(M, v, size):
        res = [0] * size
        for i in range(size):
            val = 0
            for j in range(size):
                if M[i][j] and v[j]:
                    val ^= 1
            res[i] = val
        return res

    # Build T
    T = [[0] * k for _ in range(k)]
    T[0] = [1] * k # Top row is all 1s (XOR)
    for i in range(1, k):
        T[i][i-1] = 1
        
    # Helper to get x_n for n > k
    def get_x_n(n):
        if n <= k:
            return init_terms[n-1]
        
        power = mat_pow(T, n - k, k)
        # Initial state vector for n = k: [x_k, x_{k-1}, ..., x_1]
        v_init = [init_terms[k-1]] + init_terms[k-2::-1]
        v_final = mat_vec_mul(power, v_init, k)
        return v_final[0]

    # Compute Prefix(r) = x_1 ^ ... ^ x_r
    # Efficiently, we can compute the linear transformation of the prefix sum.
    # However, iterative update is safer for correctness in this verification.
    # Given the constraints (r <= 10^18 in Python, but scaled in HDL to 64-bit),
    # we must use the matrix exponentiation for efficiency in Python reference,
    # but the HDL will use iterative exponentiation.
    
    # For the HDL verification, we will stick to the iterative logic or 
    # simplified matrix logic. The Python reference here is strictly for validation.
    # Since r is up to 2^64 in the prompt, we use the matrix method.
    
    # To compute Prefix(r):
    # We need S(n) = XOR_{i=1}^n x_i
    # S(n) = S(n-1) ^ x_n
    # This is not directly linear in V_n because of the sum. 
    # Wait, the query asks for XOR sum of a range. 
    # Result = Prefix(r) ^ Prefix(l-1).
    
    # Let's verify with a simple generator for smaller numbers if matrix fails,
    # but for 10^18, we MUST use matrix or cycle properties.
    
    # Actually, for K=8, the state vector is size 8. 
    # To get the prefix sum efficiently, we can augment the state vector.
    # State: [S_n, x_n, x_{n-1}, ..., x_{n-k+1}] (size k+1)
    # S_n = S_{n-1} ^ x_n
    # x_n = x_{n-1} ^ ... ^ x_{n-k}
    
    # Transition Matrix T_aug (size k+1):
    # S_n: [1, 1, 0, ..., 0] (S_{n-1} + x_n)
    # x_n: [0, 1, 1, ..., 1] (XOR sum of previous k terms)
    # x_{n-1}: [0, 1, 0, ..., 0]
    # ...
    
    size = k + 1
    T_aug = [[0] * size for _ in range(size)]
    # S_n = S_{n-1} ^ x_n
    T_aug[0][0] = 1
    T_aug[0][1] = 1
    # x_n = x_{n-1} ^ ... ^ x_{n-k}
    # x_n depends on old x_{n-1} ... x_{n-k} which are at indices 2 to k+1 in previous state
    # Wait, previous state: [S_{n-1}, x_{n-1}, x_{n-2}, ..., x_{n-k}]
    # New state: [S_n, x_n, x_{n-1}, ..., x_{n-k+1}]
    
    # Row 0 (S_n):
    T_aug[0][0] = 1 # S_{n-1}
    T_aug[0][1] = 1 # x_n (but x_n is computed in this step)
    # Oops, x_n is the *new* value. 
    # x_n = XOR of old state elements 1..k (x_{n-1} down to x_{n-k})
    # So row 1 (x_n):
    for i in range(1, size):
        T_aug[1][i] = 1
    # Shift rows for x_{n-1} ...
    for i in range(2, size):
        T_aug[i][i-1] = 1
        
    # Initial state at n=k:
    # S_k = x_1 ^ ... ^ x_k
    # V_k = [x_k, x_{k-1}, ..., x_1]
    S_k = 0
    for term in init_terms:
        S_k ^= term
    
    v_init = [S_k] + init_terms[k-1::-1] # [S_k, x_k, x_{k-1}, ..., x_1]
    
    def get_prefix(n):
        if n <= k:
            val = 0
            for i in range(n):
                val ^= init_terms[i]
            return val
        
        power = mat_pow(T_aug, n - k, size)
        v_final = mat_vec_mul(power, v_init, size)
        return v_final[0]

    prefix_r = get_prefix(r)
    prefix_lm1 = get_prefix(l - 1)
    return prefix_r ^ prefix_lm1

@cocotb.test(timeout_time=10, timeout_unit="ms")
async def test_xorbonacci(dut):
    # Setup
    has_clk = has_signal(dut, 'clk')
    if has_clk:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        dut.rst_n.value = 0
        if has_signal(dut, 'start'): dut.start.value = 0
        for _ in range(2):
            await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
    else:
        await Timer(100, units='ns')

    # Test cases
    # Scale inputs to fit 8-bit width for the HDL spec requirement
    test_cases = [
        # K=4, Init=[1,3,5,7], Queries: [2,2], [2,5], [1,5]
        {
            "k": 4,
            "init": [1, 3, 5, 7],
            "queries": [(2, 2), (2, 5), (1, 5)],
            "expected": [3, 1, 0]
        },
        # K=5, Init=[3,3,4,3,2], Queries: [1,2], [1,3], [5,6], [7,9]
        {
            "k": 5,
            "init": [3, 3, 4, 3, 2],
            "queries": [(1, 2), (1, 3), (5, 6), (7, 9)],
            "expected": [0, 4, 7, 4]
        }
    ]

    k_width = 4
    data_width = 8
    addr_width = 64 # For L and R

    for tc_idx, tc in enumerate(test_cases):
        k = tc["k"]
        init = tc["init"]
        queries = tc["queries"]
        expected = tc["expected"]

        # Write K
        if has_signal(dut, 'k'):
            dut.k.value = clamp_to_width(k, k_width)
        
        # Write Init Vector (Concatenated)
        # Spec says 64-bit init. For K=8, 8*8=64 bits.
        # The prompt implies 'init' is the initial terms concatenated.
        # If K < 8, we can pad with 0s.
        if has_signal(dut, 'init'):
            packed_init = 0
            for i, val in enumerate(init):
                packed_init |= (clamp_to_width(val, data_width) << (i * data_width))
            dut.init.value = packed_init

        # Process Queries
        for q_idx, (l, r) in enumerate(queries):
            # Calculate expected in Python (using the matrix logic to match HDL)
            exp_val = xorbonacci_reference(init, l, r, k)
            # Sanity check with matrix ref
            mat_val = compute_xor_sum_matrix(init, l, r, k)
            if exp_val != mat_val:
                cocotb.log.warning(f"Reference mismatch: {exp_val} vs {mat_val}. Using matrix ref.")
                exp_val = mat_val

            cocotb.log.info(f"Test {tc_idx+1}.{q_idx+1}: K={k}, L={l}, R={r}, Expected={exp_val}")

            # Drive Inputs
            if has_signal(dut, 'l'): dut.l.value = l
            if has_signal(dut, 'r'): dut.r.value = r
            
            # Start
            if has_clk:
                if has_signal(dut, 'start'):
                    dut.start.value = 1
                    await RisingEdge(dut.clk)
                    dut.start.value = 0
                
                # Wait for done
                done = False
                for _ in range(MAX_CYCLES):
                    await RisingEdge(dut.clk)
                    if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                        done = True
                        break
                
                if not done:
                    raise TestFailure(f"Timeout on query {q_idx+1}")
            else:
                await Timer(1000, units='ns') # Combinational delay

            # Check Result
            if is_value_defined(dut.result.value):
                res = int(dut.result.value)
                # Handle overflow/clamping if necessary (though 64-bit should be fine)
                if res != exp_val:
                    raise TestFailure(f"Query {q_idx+1}: Expected {exp_val}, got {res}")
                else:
                    cocotb.log.info(f"Pass: Got {res}")
            else:
                raise TestFailure("Result signal undefined")
