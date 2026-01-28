import cocotb
from cocotb.triggers import Timer, RisingEdge, Join
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

DATA_WIDTH = 8
N_MAX = 100
K_MAX = 10
CLK_NS = 10
MAX_CYCLES = 3000

def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def safe_int(v, default=0):
    try: return int(v)
    except ValueError: return default

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value)==1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

# Helper: compute target rotations and expected counts for given N,K,target_seq
def compute_expected_counts(N, K, target_seq):
    # target_seq: list of 0/1, length N
    # Convert to list of 0/1
    seq = target_seq[:N]
    
    # Compute all rotations
    rotations = []
    for r in range(N):
        rot = [seq[(i+r)%N] for i in range(N)]
        # Check if unique
        is_new = True
        for existing in rotations:
            if rot == existing:
                is_new = False
                break
        if is_new:
            rotations.append(rot)
    
    # For each rotation, compute number of preimages under T^K
    # T is linear: new[i] = old[i-1] XOR old[i+1]
    # T^K is T multiplied by itself K times
    
    # Build T matrix as list of bit masks (rows)
    def build_T(N):
        T = []
        for i in range(N):
            row = 0
            row |= 1 << ((i-1) % N)  # left neighbor
            row |= 1 << ((i+1) % N)  # right neighbor
            T.append(row)
        return T
    
    def mat_mult(A, B, N):
        # A and B are list of row bit masks, C = A * B
        C = [0] * N
        for i in range(N):
            row = 0
            for j in range(N):
                if (A[i] >> j) & 1:
                    row ^= B[j]
            C[i] = row
        return C
    
    def mat_pow(T, K, N):
        # Compute T^K using binary exponentiation
        # Result is list of row bit masks
        result = [0] * N
        for i in range(N):
            result[i] = 1 << i  # identity
        base = T[:]
        
        exp = K
        while exp > 0:
            if exp & 1:
                result = mat_mult(result, base, N)
            base = mat_mult(base, base, N)
            exp >>= 1
        return result
    
    def gauss_elim(A, b, N):
        # Solve A*x = b over GF(2)
        # A is N x N matrix (list of row masks), b is N-bit mask
        # Returns (has_solution, rank, null_space_dim)
        mat = A[:]
        rhs = b
        
        rank = 0
        # Gaussian elimination
        for col in range(N):
            # Find pivot
            pivot = -1
            for row in range(rank, N):
                if (mat[row] >> col) & 1:
                    pivot = row
                    break
            if pivot == -1:
                continue
            
            # Swap rows
            mat[rank], mat[pivot] = mat[pivot], mat[rank]
            if pivot == rank:
                rhs_pivot = (rhs >> rank) & 1
            else:
                rhs_pivot = (rhs >> pivot) & 1
                # Swap rhs bits
                rhs = (rhs & ~(1 << rank)) | (rhs_pivot << rank)
            
            # Eliminate
            for row in range(N):
                if row != rank and ((mat[row] >> col) & 1):
                    mat[row] ^= mat[rank]
                    rhs ^= (rhs_pivot << row)
            
            rank += 1
        
        # Check consistency
        # After elimination, if any row has all 0s in A but rhs bit is 1, no solution
        for row in range(rank, N):
            if mat[row] == 0 and ((rhs >> row) & 1):
                return False, rank, N - rank
        
        return True, rank, N - rank
    
    T_mat = build_T(N)
    TK = mat_pow(T_mat, K, N)
    
    total_count = 0
    counted_targets = []
    
    for target in rotations:
        # Check if we already counted this target
        if target in counted_targets:
            continue
        counted_targets.append(target)
        
        # Convert target to bit mask
        b = 0
        for i in range(N):
            if target[i]:
                b |= 1 << i
        
        # Solve TK * x = b
        has_sol, rank, null_dim = gauss_elim(TK, b, N)
        if has_sol:
            total_count += 1 << null_dim
    
    return total_count

def seq_to_bits(seq_str):
    # Convert 'B','W' to 0,1
    return [1 if c=='B' else 0 for c in seq_str]

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_pebble_circles(dut):
    # Check required signals
    required = ['clk', 'rst_n', 'start', 'done']
    for sig in required:
        if not has_signal(dut, sig):
            raise TestFailure(f"Missing required signal: {sig}")
    
    if not has_signal(dut, 'N') or not has_signal(dut, 'K') or not has_signal(dut, 'target_seq') or not has_signal(dut, 'result'):
        raise TestFailure("Missing required I/O signals")
    
    # Setup clock
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    await reset_dut(dut)
    
    # Test cases
    test_cases = [
        (3, 1, "BBW"),
        (6, 2, "WBWWBW")
    ]
    
    for (N, K, target_str) in test_cases:
        cocotb.log.info(f"Testing N={N}, K={K}, target={target_str}")
        
        # Compute expected
        target_bits = seq_to_bits(target_str)
        expected = compute_expected_counts(N, K, target_bits)
        cocotb.log.info(f"Expected result: {expected}")
        
        # Set inputs
        dut.N.value = clamp_to_width(N, 7)
        dut.K.value = clamp_to_width(K, 4)
        
        # Set target_seq (100-bit)
        target_val = 0
        for i in range(min(N, 100)):
            if target_bits[i]:
                target_val |= 1 << i
        dut.target_seq.value = target_val
        
        # Start
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        await wait_for_done(dut, 2000)
        
        # Read result
        if not is_value_defined(dut.result.value):
            raise TestFailure("Result undefined")
        
        result = int(dut.result.value)
        cocotb.log.info(f"Got result: {result}")
        
        if result != expected:
            raise TestFailure(f"Expected {expected}, got {result}")
        
        # Reset for next test
        await reset_dut(dut)
    
    cocotb.log.info("All tests passed!")
