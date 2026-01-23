import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import math

# ============================================================================
# CONFIGURATION
# ============================================================================
MAX_N = 8
DATA_WIDTH = 16       # For trans_matrix elements
L_WIDTH = 5           # L is 1-16
T_WIDTH = 6           # T output (0-25 or 63 for -1)
CLK_PERIOD_NS = 10

# ============================================================================
# HELPER FUNCTIONS
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
        return from_signed(max(-((1 << (bits-1))), min((1 << (bits-1)) - 1, value)), bits)
    return min(max_val, max(0, value))

def float_to_q8_8(f):
    """Convert float to Q8.8 fixed-point."""
    return int(f * 256)

def q8_8_to_float(q):
    """Convert Q8.8 fixed-point to float."""
    return q / 256.0

# ============================================================================
# TESTBENCH
# ============================================================================

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_vacation_planner(dut):
    """Main test function for vacation planner."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset sequence
    dut.rst_n.value = 0
    dut.start.value = 0
    for _ in range(2):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases: (N, L, graph, expected_T, description)
    # Graph is N x N matrix of a_ij
    test_cases = [
        # Example 1: N=3, L=1, expected T=2
        (3, 1, [
            [0, 11, 9],
            [1, 0, 10],
            [0, 0, 0]
        ], 2, "Example 1: N=3, L=1"),
        
        # Example 2: N=4, L=3, expected T=-1 (no solution)
        (4, 3, [
            [0, 1, 0, 19],
            [0, 0, 2, 0],
            [0, 5, 0, 3],
            [0, 0, 0, 0]
        ], -1, "Example 2: N=4, L=3, no solution"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (N, L, graph, expected_T, description) in enumerate(test_cases):
        cocotb.log.info(f"\n{'='*60}")
        cocotb.log.info(f"Test {i+1}: {description}")
        cocotb.log.info(f"{'='*60}")
        
        try:
            # Step 1: Compute transition matrix in Q8.8
            trans_matrix_q8 = [0] * (MAX_N * MAX_N)
            
            for i_node in range(N):
                total = sum(graph[i_node])
                if total == 0:
                    # Absorbing state (B-ville)
                    if i_node == N-1:
                        trans_matrix_q8[i_node * MAX_N + i_node] = 256  # 1.0 in Q8.8
                    # else: leave as 0 (shouldn't happen per problem)
                else:
                    for j_node in range(N):
                        if graph[i_node][j_node] > 0:
                            prob = graph[i_node][j_node] / total
                            trans_matrix_q8[i_node * MAX_N + j_node] = float_to_q8_8(prob)
            
            # Step 2: Apply inputs to DUT
            # Set L
            dut.L.value = L
            
            # Set transition matrix
            for idx in range(MAX_N * MAX_N):
                if has_signal(dut, f'trans_matrix_{idx}'):
                    # Individual port naming
                    getattr(dut, f'trans_matrix_{idx}').value = clamp_to_width(trans_matrix_q8[idx], DATA_WIDTH)
                else:
                    # Indexed array access
                    dut.trans_matrix[idx].value = clamp_to_width(trans_matrix_q8[idx], DATA_WIDTH)
            
            # Step 3: Start computation
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Step 4: Wait for done
            timeout_cycles = 1000
            done_found = False
            for cycle in range(timeout_cycles):
                await RisingEdge(dut.clk)
                if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                    done_found = True
                    break
            
            if not done_found:
                raise TestFailure(f"Timeout: done not asserted after {timeout_cycles} cycles")
            
            # Step 5: Read result
            if not is_value_defined(dut.T.value):
                raise TestFailure("Result T is undefined (X/Z)")
            
            result_T = int(dut.T.value)
            
            # Convert from unsigned to signed if needed (6-bit signed)
            if result_T >= 32:  # 6-bit signed: 32-63 represent negative
                result_T = result_T - 64
            
            # Step 6: Verify result
            if result_T != expected_T:
                raise TestFailure(f"Expected {expected_T}, got {result_T}")
            
            cocotb.log.info(f"  PASS: T = {result_T}")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
        
        # Reset between tests
        dut.rst_n.value = 0
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
    
    # Summary
    cocotb.log.info(f"\n{'='*60}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    cocotb.log.info(f"{'='*60}")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")