import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

# ============================================================================
# CONFIGURATION
# ============================================================================
N = 2
M = 2
DATA_WIDTH = 3  # enough for p <= 7
CLK_PERIOD_NS = 10
MAX_CYCLES = 1000

# ============================================================================
# MANDATORY HELPER FUNCTIONS
# ============================================================================

def is_value_defined(value):
    """Check if a cocotb value is defined (not X or Z)."""
    try:
        int(value)
        return True
    except ValueError:
        return False

def safe_int(value, default=0):
    """Safely convert cocotb value to int, returning default if X/Z."""
    try:
        return int(value)
    except ValueError:
        return default

def to_signed(val, bits):
    """Convert unsigned integer to signed (two's complement)."""
    if val >= (1 << (bits - 1)):
        return val - (1 << bits)
    return val

def from_signed(val, bits):
    """Convert signed integer to unsigned for Verilog assignment."""
    if val < 0:
        return val + (1 << bits)
    return val

def has_signal(dut, name):
    """Check if DUT has a signal with given name."""
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def clamp_to_width(value, bits):
    """Clamp value to fit within specified bit width."""
    max_val = (1 << bits) - 1
    if value < 0:
        # Handle signed values
        return from_signed(max(-((1 << (bits-1))), min((1 << (bits-1)) - 1, value)), bits)
    return min(max_val, max(0, value))

# ============================================================================
# ARRAY ACCESS HELPERS
# ============================================================================

async def write_board(dut, values):
    """Write board values to individual ports."""
    for i, val in enumerate(values):
        port = getattr(dut, f'board_{i}')
        port.value = clamp_to_width(val, DATA_WIDTH)

async def read_counts(dut):
    """Read move counts from individual ports."""
    counts = []
    for i in range(N*M):
        port = getattr(dut, f'count_{i}')
        if is_value_defined(port.value):
            counts.append(int(port.value))
        else:
            counts.append(None)
    return counts

# ============================================================================
# SEQUENTIAL MODULE HELPERS
# ============================================================================

async def reset_dut(dut, cycles=2):
    """Reset the DUT (active-low reset)."""
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    """Wait for done signal with timeout."""
    for cycle in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout: done not asserted after {max_cycles} cycles")

async def start_computation(dut):
    """Pulse start signal for one cycle."""
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

# ============================================================================
# PYTHON REFERENCE SOLVER
# ============================================================================

def mod_inverse(a, p):
    """Return modular inverse of a modulo p (p prime, a != 0)."""
    for i in range(1, p):
        if (a * i) % p == 1:
            return i
    return 0  # should not happen for a != 0

def solve_system(p, board):
    """Solve 2x2 system over GF(p). Returns list of 4 counts or None if no solution."""
    SIZE = 4
    A = [[0]*SIZE for _ in range(SIZE)]
    d = [(p - board[i]) % p for i in range(SIZE)]
    
    # Build matrix: equations for each cell (r,c) in row-major order
    for r in range(N):
        for c in range(M):
            row = r*M + c
            for i in range(N):
                for j in range(M):
                    col = i*M + j
                    if i == r or j == c:
                        A[row][col] = 1
                    else:
                        A[row][col] = 0
    
    # Gaussian elimination
    col = 0
    row = 0
    pivot_rows = [-1]*SIZE  # mapping from variable to pivot row
    
    for col in range(SIZE):
        # Find pivot row
        pivot = -1
        for r in range(row, SIZE):
            if A[r][col] != 0:
                pivot = r
                break
        if pivot == -1:
            # free variable, set to 0
            continue
        
        # Swap rows
        if pivot != row:
            A[row], A[pivot] = A[pivot], A[row]
            d[row], d[pivot] = d[pivot], d[row]
        
        # Normalize pivot row
        inv = mod_inverse(A[row][col], p)
        for j in range(col, SIZE):
            A[row][j] = (A[row][j] * inv) % p
        d[row] = (d[row] * inv) % p
        
        # Eliminate other rows
        for r in range(SIZE):
            if r != row and A[r][col] != 0:
                factor = A[r][col]
                for j in range(col, SIZE):
                    A[r][j] = (A[r][j] - factor * A[row][j]) % p
                d[r] = (d[r] - factor * d[row]) % p
        
        pivot_rows[col] = row
        row += 1
    
    # Check consistency and back-substitute
    x = [0]*SIZE
    for col in range(SIZE-1, -1, -1):
        if pivot_rows[col] != -1:
            r = pivot_rows[col]
            x[col] = d[r]
            for j in range(col+1, SIZE):
                x[col] = (x[col] - A[r][j] * x[j]) % p
        else:
            x[col] = 0  # free variable
    
    # Verify solution
    for r in range(SIZE):
        sum_val = 0
        for c in range(SIZE):
            sum_val = (sum_val + A[r][c] * x[c]) % p
        if sum_val != d[r]:
            return None
    return x

def apply_moves(board, counts, p):
    """Apply move counts to board and return resulting board."""
    N = 2; M = 2
    new_board = board[:]
    for idx, cnt in enumerate(counts):
        if cnt == 0:
            continue
        r = idx // M
        c = idx % M
        for i in range(N):
            for j in range(M):
                if i == r or j == c:
                    new_board[i*M + j] = (new_board[i*M + j] + cnt) % p
                    if new_board[i*M + j] == 0:
                        new_board[i*M + j] = p
    return new_board

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_primonimo(dut):
    """Main test function."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Generate test cases
    random.seed(0)
    test_cases = []
    
    # Helper to generate a random board
    def random_board(p):
        return [random.randint(1, p) for _ in range(4)]
    
    # Generate solvable cases for p=5,7
    for p_val in [5, 7]:
        for _ in range(2):
            while True:
                board = random_board(p_val)
                sol = solve_system(p_val, board)
                if sol is not None:
                    test_cases.append((p_val, board, sol))
                    break
    
    # Generate unsolvable case for p=3
    for _ in range(2):
        while True:
            board = random_board(3)
            sol = solve_system(3, board)
            if sol is None:
                test_cases.append((3, board, None))
                break
    
    # Run tests
    passed = 0
    failed = 0
    
    for i, (p_val, board, expected_counts) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: p={p_val}, board={board}")
        
        try:
            # Feed inputs
            dut.p.value = p_val
            await write_board(dut, board)
            
            # Start computation
            await start_computation(dut)
            await wait_for_done(dut)
            
            # Read outputs
            solution_exists = int(dut.solution_exists.value)
            counts = await read_counts(dut)
            
            if expected_counts is None:
                if solution_exists != 0:
                    raise TestFailure(f"Expected no solution, but DUT reported solution_exists=1")
                cocotb.log.info(f"  PASS: correctly detected no solution")
                passed += 1
            else:
                if solution_exists == 0:
                    raise TestFailure(f"DUT reported no solution, but one exists")
                
                # Verify counts are within range
                for idx, cnt in enumerate(counts):
                    if cnt is None or cnt < 0 or cnt >= p_val:
                        raise TestFailure(f"Invalid count {cnt} at index {idx}")
                
                # Apply moves and check final board
                final_board = apply_moves(board, counts, p_val)
                if any(val != p_val for val in final_board):
                    raise TestFailure(f"Move counts did not solve the board. Final board: {final_board}")
                
                cocotb.log.info(f"  PASS: solution verified")
                passed += 1
                
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    # Summary
    cocotb.log.info(f"{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")
