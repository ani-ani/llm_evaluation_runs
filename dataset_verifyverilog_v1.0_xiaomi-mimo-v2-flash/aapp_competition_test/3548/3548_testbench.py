import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

DATA_WIDTH = 8
CLK_NS = 10
MAX_CYCLES = 1000
MOD = 10**9 + 7

# Helper functions
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

async def wait_for_done(dut, max_cycles=1000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

# Python reference implementation
def solve_python(N, adj_matrix):
    # N is count of ingredients (1 to 16)
    # adj_matrix is N x N boolean
    dp = [0] * (N + 1)
    dp[0] = 1
    
    for i in range(1, N + 1):
        for j in range(i - 1, -1, -1):
            # Check if segment [j, i-1] is valid
            valid = True
            for u in range(j, i):
                for v in range(u + 1, i):
                    if adj_matrix[u][v]:
                        valid = False
                        break
                if not valid:
                    break
            
            if valid:
                dp[i] = (dp[i] + dp[j]) % MOD
    return dp[N]

@cocotb.test(timeout_time=10, timeout_unit="ms")
async def test_partition(dut):
    # Setup clock
    clock = Clock(dut.clk, CLK_NS, units='ns')
    cocotb.start_soon(clock.start())
    
    await reset_dut(dut)
    
    # Test cases
    test_cases = []
    
    # Case 1: N=5, bad pairs (1,3), (4,5), (2,4) -> 0-indexed (0,2), (3,4), (1,3)
    # Expected output: 5
    N1 = 5
    adj1 = [[0]*16 for _ in range(16)]
    adj1[0][2] = 1; adj1[2][0] = 1
    adj1[3][4] = 1; adj1[4][3] = 1
    adj1[1][3] = 1; adj1[3][1] = 1
    test_cases.append((N1, adj1, 5))
    
    # Case 2: N=5, no bad pairs -> 2^(N-1) = 16
    N2 = 5
    adj2 = [[0]*16 for _ in range(16)]
    test_cases.append((N2, adj2, 16))
    
    # Case 3: N=1, no pairs -> 1
    N3 = 1
    adj3 = [[0]*16 for _ in range(16)]
    test_cases.append((N3, adj3, 1))

    for i, (N, adj, expected) in enumerate(test_cases):
        cocotb.log.info(f"Running test case {i+1}: N={N}, Expected={expected}")
        
        # Verify reference
        ref_res = solve_python(N, adj)
        if ref_res != expected:
             cocotb.log.error(f"Reference mismatch! Ref: {ref_res}, Exp: {expected}")
             continue
        
        # Prepare inputs
        # N is 4-bit
        dut.N.value = N
        
        # Fill adjacency matrix
        # Assuming input is named 'adjacency_matrix' and is a 1D array of 256 bits or similar structure.
        # If it's a 2D port array adj[16][16]:
        has_2d = False
        try:
            # Try accessing as 2D array (Verilog style reg [0:15] [0:15] adj)
            dut.adjacency_matrix[0][0]
            has_2d = True
        except (AttributeError, TypeError):
            pass
            
        if has_2d:
             for r in range(16):
                 for c in range(16):
                     dut.adjacency_matrix[r][c].value = adj[r][c]
        else:
            # Try flat array 'adjacency_matrix'
            try:
                # If it's a single logic vector or array of bits, we might need to flatten it
                # Or if it's just a logic vector, we need to pack it.
                # Let's assume it's a logic vector [255:0] where bit [r*16 + c] is adj[r][c]
                flat = 0
                for r in range(16):
                    for c in range(16):
                        if adj[r][c]:
                            flat |= (1 << (r * 16 + c))
                dut.adjacency_matrix.value = flat
            except Exception as e:
                cocotb.log.error(f"Could not set adjacency matrix: {e}")
                raise TestFailure("Input format mismatch")

        # Start
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        await wait_for_done(dut)
        
        # Check result
        if not is_value_defined(dut.result.value):
            raise TestFailure("Result undefined")
            
        result = int(dut.result.value)
        if result != expected:
            raise TestFailure(f"Test {i+1} failed: Expected {expected}, got {result}")
            
        cocotb.log.info(f"Test {i+1} passed: {result}")
