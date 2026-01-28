import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

# Helpers from template
DATA_WIDTH = 8
DP_WIDTH = 16
ARRAY_SIZE = 64
CLK_NS = 10
MAX_CYCLES = 200

Q8_8_SHIFT = 256  # 2^8 for Q8.8

# Helper functions
def is_value_defined(v):
    try:
        int(v)
        return True
    except ValueError:
        return False

def safe_int(v, default=0):
    try:
        return int(v)
    except ValueError:
        return default

def to_signed(val, bits):
    return val - (1 << bits) if val >= (1 << (bits-1)) else val

def from_signed(val, bits):
    return val + (1 << bits) if val < 0 else val

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def clamp_signed(v, bits):
    max_val = (1 << (bits - 1)) - 1
    min_val = -(1 << (bits - 1))
    return min(max(v, min_val), max_val)

def pack_cost_array(cost_grid, N=8, bits=8):
    """Pack 2D cost array into single bit vector for Verilog input"""
    packed = 0
    for i in range(N):
        for j in range(N):
            cost = clamp_signed(cost_grid[i][j], bits)
            idx = i * N + j
            packed |= (from_signed(cost, bits) & ((1 << bits) - 1)) << (idx * bits)
    return packed

def compute_expected(cost_grid, N=8):
    """Compute expected average using Python DP"""
    dp = [[0] * N for _ in range(N)]
    dp[0][0] = cost_grid[0][0]
    
    # First row
    for j in range(1, N):
        dp[0][j] = dp[0][j-1] + cost_grid[0][j]
    
    # First column
    for i in range(1, N):
        dp[i][0] = dp[i-1][0] + cost_grid[i][0]
    
    # Rest of grid
    for i in range(1, N):
        for j in range(1, N):
            dp[i][j] = max(dp[i-1][j], dp[i][j-1]) + cost_grid[i][j]
    
    total_sum = dp[N-1][N-1]
    path_length = 2 * N - 1
    average = total_sum / path_length
    
    # Convert to Q8.8 format
    return int(average * Q8_8_SHIFT)

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=200):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

@cocotb.test(timeout_time=2000, timeout_unit="ms")
async def test_max_path_average(dut):
    # Check if sequential
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    else:
        # Combinational - ensure inputs stable
        await Timer(10, units='ns')
    
    # Test cases
    test_cases = [
        ([[1, 2, 3], [6, 5, 4], [7, 3, 9]], "3x3 test 1"),
        ([[2, 3, 4], [7, 6, 5], [8, 4, 10]], "3x3 test 2"),
        ([[3, 4, 5], [8, 7, 6], [9, 5, 11]], "3x3 test 3"),
        ([[1, 2, 3], [4, 5, 6], [7, 8, 9]], "3x3 test 4"),
    ]
    
    # Create 8x8 test grids (pad 3x3 data with zeros for larger N)
    N = 8
    for idx, (small_grid, name) in enumerate(test_cases):
        # Create 8x8 grid with original data in top-left 3x3
        cost_grid = [[0] * N for _ in range(N)]
        for i in range(3):
            for j in range(3):
                cost_grid[i][j] = small_grid[i][j]
        
        cocotb.log.info(f"Test {idx+1}: {name}")
        
        try:
            # Pack costs
            packed_costs = pack_cost_array(cost_grid, N, DATA_WIDTH)
            
            # Set inputs
            if has_signal(dut, 'cost'):
                dut.cost.value = packed_costs
            
            if is_seq:
                # Set start pulse
                if has_signal(dut, 'valid_input'):
                    dut.valid_input.value = 1
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                if has_signal(dut, 'valid_input'):
                    dut.valid_input.value = 0
                
                # Wait for done
                await wait_for_done(dut)
            else:
                # Combinational - wait for propagation
                await Timer(100, units='ns')
            
            # Read result
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result signal undefined")
            
            result = int(dut.result.value)
            result_val = to_signed(result, 16)  # Convert from unsigned to signed if needed
            
            # Compute expected (only for cells up to 3x3)
            expected = compute_expected(small_grid, 3)
            
            # For full 8x8 with padded zeros, path length changes
            # Recompute for 8x8 grid
            expected_full = compute_expected(cost_grid, N)
            
            cocotb.log.info(f"  Result (Q8.8): {result_val}")
            cocotb.log.info(f"  Expected (Q8.8): {expected_full}")
            
            # Allow some rounding tolerance
            tolerance = 1  # 1/256 ≈ 0.004
            if abs(result_val - expected_full) > tolerance:
                raise TestFailure(f"Mismatch: expected {expected_full}, got {result_val} (diff: {result_val - expected_full})")
            
            # Check overflow flag if present
            if has_signal(dut, 'overflow'):
                if int(dut.overflow.value) == 1:
                    cocotb.log.warning(f"Overflow detected in test {idx+1}")
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL - {name}: {e}")
            raise
    
    cocotb.log.info("All tests passed!")