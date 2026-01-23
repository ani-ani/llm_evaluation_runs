import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Configuration
DATA_WIDTH = 8
ARRAY_SIZE = 4
RESULT_WIDTH = 32
CLK_PERIOD_NS = 10
MAX_CYCLES = 1000

# Helper functions
def is_value_defined(value):
    try:
        int(value)
        return True
    except ValueError:
        return False

def safe_int(value, default=0):
    try:
        return int(value)
    except ValueError:
        return default

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

async def reset_dut(dut):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(2):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    for cycle in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout: done not asserted after {max_cycles} cycles")

async def start_computation(dut):
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

# Compute expected max_product in Python
def compute_max_product(N, prob):
    dp = [0] * (1 << N)
    dp[0] = 1
    for agent in range(N):
        for mask in range(1 << N):
            if bin(mask).count('1') == agent:
                for mission in range(N):
                    if not (mask & (1 << mission)):
                        new_mask = mask | (1 << mission)
                        product = dp[mask] * prob[agent][mission]
                        if product > dp[new_mask]:
                            dp[new_mask] = product
    return dp[(1 << N) - 1]

# Set probabilities into 128-bit input
async def set_probabilities(dut, prob_matrix):
    packed = 0
    for i in range(4):
        for j in range(4):
            value = prob_matrix[i][j] if i < len(prob_matrix) and j < len(prob_matrix[i]) else 0
            packed |= (value << (8 * (4*i + j)))
    dut.prob.value = packed

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_bond_assignment(dut):
    """Test bond assignment module with multiple cases"""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test cases: (N, prob_matrix, expected_percentage)
    test_cases = [
        (2, [[100,100],[50,50]], 50.0),
        (2, [[0,50],[50,0]], 25.0),
        (3, [[25,60,100],[13,0,50],[12,70,90]], 9.1),
    ]
    
    results = []
    
    for i, (N, prob_matrix, expected_percentage) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: N={N}")
        
        # Set inputs
        dut.N.value = N
        await set_probabilities(dut, prob_matrix)
        
        # Start computation
        await start_computation(dut)
        
        # Wait for done
        await wait_for_done(dut)
        
        # Read max_product
        if not is_value_defined(dut.max_product.value):
            raise TestFailure(f"Result is undefined (X/Z)")
        max_product = int(dut.max_product.value)
        
        # Verify max_product
        expected_max = compute_max_product(N, prob_matrix)
        if max_product != expected_max:
            raise TestFailure(f"Max product mismatch: expected {expected_max}, got {max_product}")
        
        # Convert to percentage
        percentage = max_product / (100 ** (N-1))
        
        # Check percentage accuracy
        if abs(percentage - expected_percentage) > 1e-6:
            raise TestFailure(f"Percentage mismatch: expected {expected_percentage}, got {percentage}")
        
        cocotb.log.info(f"  Result: {percentage}")
        results.append(percentage)
    
    # Summary
    cocotb.log.info(f"{'='*50}")
    for i, (N, _, expected) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: N={N}, Result={results[i]}, Expected={expected}")
    
    cocotb.log.info(f"All tests passed!")
