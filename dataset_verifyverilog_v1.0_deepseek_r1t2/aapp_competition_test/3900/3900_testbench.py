import cocotb
from cocotb.triggers import Timer
from cocotb.result import TestFailure

# ============================================================================
# MANDATORY HELPER FUNCTIONS
# ============================================================================
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

def to_signed(val, bits):
    if val >= (1 << (bits - 1)):
        return val - (1 << bits)
    return val

def from_signed(val, bits):
    if val < 0:
        return val + (1 << bits)
    return val

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def clamp_to_width(value, bits):
    max_val = (1 << bits) - 1
    return min(max_val, max(0, value))

# ============================================================================
# TEST CASES
# ============================================================================
# Input strings and expected outputs (n <= 10 for all)
test_inputs = [
    "4 2\n2 3\n1 4\n1 4\n2 1\n",
    "8 6\n5 6\n5 7\n5 8\n6 2\n2 1\n7 3\n1 3\n1 4\n",
    "3 2\n2 3\n3 1\n2 1\n",
    "4 1\n3 2\n4 1\n4 2\n1 2\n",
    "4 2\n3 4\n4 3\n4 2\n3 1\n",
    "4 3\n3 2\n4 3\n2 4\n3 2\n",
    "4 4\n2 3\n3 4\n2 4\n2 1\n",
    "5 1\n4 2\n4 5\n5 1\n5 1\n4 2\n",
    "5 2\n4 3\n1 3\n4 2\n1 2\n1 4\n",
    "5 3\n5 3\n5 1\n2 1\n5 3\n1 4\n",
    "5 5\n3 2\n3 4\n2 5\n3 2\n4 3\n",
    "10 1\n4 9\n8 9\n7 6\n1 5\n3 6\n4 3\n4 6\n10 1\n1 8\n7 9\n",
    "10 2\n10 2\n9 3\n9 4\n7 2\n4 6\n10 1\n9 2\n3 10\n7 1\n5 1\n",
    "10 3\n6 3\n6 10\n2 5\n5 7\n6 2\n9 2\n8 1\n10 5\n5 10\n7 6\n",
    "10 4\n8 7\n1 5\n7 4\n7 8\n3 2\n10 8\n3 6\n9 7\n8 7\n4 1\n",
    "8 8\n6 5\n1 6\n1 6\n1 6\n1 6\n1 2\n1 3\n6 4\n",
    "5 5\n3 2\n3 4\n1 2\n1 2\n1 2\n",
    "8 7\n7 8\n7 8\n1 6\n1 6\n1 2\n1 3\n6 4\n6 5\n",
    "6 5\n5 6\n5 6\n5 6\n5 6\n1 2\n3 4\n",
    "10 10\n5 6\n1 4\n1 4\n1 2\n1 2\n1 2\n1 3\n1 3\n1 3\n1 4\n",
    "6 4\n2 3\n3 1\n1 2\n5 6\n6 4\n4 5\n",
    "5 5\n4 5\n4 5\n4 5\n1 2\n1 2\n",
    "5 3\n3 4\n3 4\n1 2\n1 2\n1 2\n",
    "4 4\n3 4\n3 4\n1 2\n1 2\n",
    "4 4\n3 4\n4 3\n1 2\n2 1\n",
    "4 3\n3 4\n3 4\n1 2\n1 2\n",
    "8 5\n5 6\n5 7\n5 8\n6 2\n2 1\n7 3\n1 3\n1 4\n",
    "6 6\n5 6\n5 6\n5 6\n1 2\n1 3\n3 4\n",
    "4 4\n2 3\n4 3\n2 1\n2 3\n"
]

test_outputs = [
    6, 1, 3, 6, 6, 5, 2, 10, 10, 9, 3, 45, 43, 34, 19, 1, 3, 0, 8, 2, 9, 4, 7, 4, 4, 4, 5, 0, 3
]

# Helper to parse a test case string
def parse_test_case(input_str):
    lines = input_str.strip().split('\n')
    n, p = map(int, lines[0].split())
    pairs = []
    for i in range(1, n+1):
        x, y = map(int, lines[i].split())
        pairs.append((x, y))
    return n, p, pairs

@cocotb.test(timeout_time=1000, timeout_unit='ms')
async def test_suspect_pair_counter(dut):
    '''Test the suspect pair counter module with all provided test cases.'''

    # Run each test case
    for idx, (input_str, expected) in enumerate(zip(test_inputs, test_outputs)):
        n, p, pairs = parse_test_case(input_str)

        # Set n and p
        dut.n.value = n
        dut.p.value = p

        # Set x_i, y_i for i = 0..9 (our module has ports up to 9)
        for i in range(10):
            if i < n:
                x, y = pairs[i]
            else:
                x, y = 0, 0
            # Use getattr to access ports x0..x9, y0..y9
            getattr(dut, f'x{i}').value = x
            getattr(dut, f'y{i}').value = y

        # Wait for combinational propagation
        await Timer(100, units='ns')

        # Read result
        if not is_value_defined(dut.result.value):
            raise TestFailure(f'Test {idx}: result is undefined (X/Z)')

        result = int(dut.result.value)
        if result != expected:
            raise TestFailure(f'Test {idx}: expected {expected}, got {result}')

        dut._log.info(f'Test {idx} passed: result = {result}')

    dut._log.info('All tests passed!')