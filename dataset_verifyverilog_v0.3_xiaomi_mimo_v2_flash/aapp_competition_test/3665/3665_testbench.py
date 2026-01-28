import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import numpy as np

# ============================================================================
# CONFIGURATION
# ============================================================================
N = 2          # Number of numbers
M = 3          # Number of digits per number
DIGIT_WIDTH = 4
CLK_PERIOD_NS = 10
MAX_CYCLES = 1000

# ============================================================================
# HELPER FUNCTIONS (as per guidelines)
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
    """Clamp value to fit within specified bit width (unsigned)."""
    max_val = (1 << bits) - 1
    return min(max_val, max(0, value))

# ============================================================================
# ARRAY ACCESS HELPERS
# ============================================================================

def pack_number(digits):
    """Pack a list of M digits into a single integer (most significant first)."""
    result = 0
    for i, d in enumerate(digits):
        result |= (d & 0xF) << ((M - 1 - i) * DIGIT_WIDTH)
    return result

def unpack_number(value):
    """Unpack a single integer into a list of M digits."""
    digits = []
    for i in range(M):
        d = (value >> ((M - 1 - i) * DIGIT_WIDTH)) & 0xF
        digits.append(d)
    return digits

def pack_array(numbers):
    """Pack a list of N numbers (each a list of digits) into a list of integers."""
    return [pack_number(num) for num in numbers]

# ============================================================================
# OPTIMAL SOLVER (Python reference)
# ============================================================================

def compute_optimal(numbers, m):
    """
    Compute the minimal changes to make the sequence sorted.
    For n=2, m=3, we can brute-force all possibilities.
    But for general small n,m, we use DP.
    """
    n = len(numbers)
    # Convert to list of digit strings
    orig = [[int(c) for c in num] for num in numbers]
    
    # DP over digit positions and state
    # state is a bitmask of (n-1) bits indicating ordered pairs
    max_state = 1 << (n-1)
    INF = 10**9
    
    # dp[j][state] = minimal cost for first j digits
    dp = [[INF] * max_state for _ in range(m+1)]
    dp[0][0] = 0
    
    # backtrack[j][state] = (prev_state, chosen_digits_for_each_row)
    backtrack = [[None] * max_state for _ in range(m+1)]
    
    for j in range(m):
        for state in range(max_state):
            if dp[j][state] == INF:
                continue
            # Determine segments based on state
            # For each segment, we need to assign digits non-decreasing
            # We'll enumerate all possible assignments for the segment
            # For simplicity, we'll brute-force all digit assignments for the whole row
            # Since n=2, we can enumerate all 100 possibilities
            if n == 2:
                for d0 in range(10):
                    for d1 in range(10):
                        # Check constraint
                        if state == 0:  # equal so far
                            if d0 > d1:
                                continue
                        # cost
                        cost = (1 if d0 != orig[0][j] else 0) + (1 if d1 != orig[1][j] else 0)
                        new_state = state
                        if state == 0 and d0 < d1:
                            new_state = 1
                        # update
                        new_cost = dp[j][state] + cost
                        if new_cost < dp[j+1][new_state]:
                            dp[j+1][new_state] = new_cost
                            backtrack[j+1][new_state] = (state, [d0, d1])
            else:
                # For n>2, we would need segment DP, but we skip for testbench
                pass
    
    # Find best final state
    best_state = 0
    best_cost = INF
    for state in range(max_state):
        if dp[m][state] < best_cost:
            best_cost = dp[m][state]
            best_state = state
    
    # Reconstruct solution
    result_digits = [[] for _ in range(n)]
    current_state = best_state
    for j in range(m, 0, -1):
        prev_state, digits = backtrack[j][current_state]
        for i in range(n):
            result_digits[i].insert(0, digits[i])
        current_state = prev_state
    
    # Convert to strings
    result = [''.join(str(d) for d in digits) for digits in result_digits]
    return result, best_cost

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_lossy_sorter(dut):
    """Test the LossySorter module."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    for _ in range(2):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases: (input_numbers, expected_output)
    # Each number is a string of M digits
    test_cases = [
        # Original problem example scaled to 2 numbers: 111, 001 -> optimal 111, 111
        (['111', '001'], ['111', '111']),
    ]
    
    for i, (input_strs, expected_strs) in enumerate(test_cases):
        dut._log.info(f"Test case {i+1}: inputs {input_strs}, expected {expected_strs}")
        
        # Convert to digit lists
        input_digits = [[int(c) for c in s] for s in input_strs]
        expected_digits = [[int(c) for c in s] for s in expected_strs]
        
        # Compute reference using Python (for verification)
        ref_output, ref_cost = compute_optimal(input_digits, M)
        dut._log.info(f"  Reference output: {ref_output}, cost: {ref_cost}")
        
        # Pack inputs into the format expected by DUT
        # For N=2, we have two separate ports? In our spec, we use packed array.
        # In cocotb, we need to assign each element of the packed array.
        # For simplicity, we'll assume the DUT has separate ports num0, num1, etc.
        # But our module uses packed array [N-1:0][M*DIGIT_WIDTH-1:0] numbers_in
        # In cocotb, we can assign as:
        packed_inputs = pack_array(input_digits)
        for i_num in range(N):
            # Assign to the packed vector index
            dut.numbers_in[i_num].value = packed_inputs[i_num]
        
        # Assert start for one cycle
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        cycles = 0
        while not (is_value_defined(dut.done.value) and int(dut.done.value) == 1):
            await RisingEdge(dut.clk)
            cycles += 1
            if cycles > MAX_CYCLES:
                raise TestFailure(f"Timeout waiting for done")
        
        # Read outputs
        outputs = []
        for i_num in range(N):
            val = dut.numbers_out[i_num].value
            if is_value_defined(val):
                digits = unpack_number(int(val))
                outputs.append(''.join(str(d) for d in digits))
            else:
                raise TestFailure(f"Output {i_num} is undefined")
        
        # Verify
        if outputs != expected_strs and outputs != ref_output:
            raise TestFailure(f"Output mismatch: got {outputs}, expected {expected_strs} or {ref_output}")
        
        dut._log.info(f"  PASS: outputs = {outputs}")
    
    dut._log.info("All tests passed!")
