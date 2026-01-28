import cocotb
from cocotb.triggers import Timer
from cocotb.result import TestFailure

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

# Test configuration
DATA_WIDTH = 5
ARRAY_SIZE = 16

# Test cases: (N, A, B, expected_perm or -1)
TEST_CASES = [
    (9, 2, 5, [2, 1, 4, 3, 6, 7, 8, 9, 5]),
    (3, 2, 1, [1, 2, 3]),
    (7, 4, 4, -1),
    (1, 1, 1, [1]),
    (4, 3, 2, [2, 1, 4, 3]),
    (5, 4, 5, [2, 3, 4, 5, 1]),
    (5, 3, 4, -1),
    (10, 3, 4, -1),
    (6, 2, 3, [2, 1, 4, 3, 6, 5]),
    (8, 3, 3, [2, 3, 1, 5, 6, 4, 8, 7]),
    (15, 5, 6, [2, 3, 4, 5, 1, 7, 8, 9, 10, 11, 6, 13, 14, 15, 12]),
    (0, 1, 1, -1),  # Edge case: N=0
    (16, 4, 4, [2, 3, 4, 1, 6, 7, 8, 5, 10, 11, 12, 9, 14, 15, 16, 13]),
    (2, 2, 2, [2, 1]),
    (16, 8, 8, [2, 3, 4, 5, 6, 7, 8, 1, 10, 11, 12, 13, 14, 15, 16, 9]),
]

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_permutation_generator(dut):
    """Test permutation generator with scaled inputs."""
    
    # Initialize inputs
    dut.N.value = 0
    dut.A.value = 0
    dut.B.value = 0
    
    for i, (n, a, b, expected) in enumerate(TEST_CASES):
        cocotb.log.info(f"Test {i+1}: N={n}, A={a}, B={b}")
        
        # Set inputs
        dut.N.value = n
        dut.A.value = a
        dut.B.value = b
        
        # Combinational propagation delay
        await Timer(10, units='ns')
        
        # Read valid flag
        valid = safe_int(dut.valid.value)
        
        if expected == -1:
            # Check for invalid case
            if valid != 0:
                raise TestFailure(f"Test {i+1}: Expected invalid (valid=0), got valid={valid}")
            
            # Check perm[0] is 31 (5'b11111)
            if is_value_defined(dut.perm[0].value):
                perm0 = int(dut.perm[0].value)
                if perm0 != 31:
                    raise TestFailure(f"Test {i+1}: Expected perm[0]=31 (-1), got {perm0}")
            cocotb.log.info(f"  PASS: Invalid case correctly handled")
        else:
            # Valid case checks
            if valid != 1:
                raise TestFailure(f"Test {i+1}: Expected valid=1, got {valid}")
            
            # Read permutation (first n elements)
            perm_vals = []
            for j in range(n):
                if is_value_defined(dut.perm[j].value):
                    val = int(dut.perm[j].value)
                    perm_vals.append(val)
                else:
                    raise TestFailure(f"Test {i+1}: Undefined value at perm[{j}]")
            
            # Verify permutation properties
            # 1. Must contain exactly 1..n
            if sorted(perm_vals) != list(range(1, n+1)):
                raise TestFailure(f"Test {i+1}: Invalid permutation. Got {perm_vals}, expected 1..{n}")
            
            # 2. Must match expected output (problem specifies exact permutations)
            if perm_vals != expected:
                raise TestFailure(f"Test {i+1}: Permutation mismatch.\nGot:      {perm_vals}\nExpected: {expected}")
            
            cocotb.log.info(f"  PASS: Valid permutation: {perm_vals}")
    
    cocotb.log.info("All tests completed successfully")