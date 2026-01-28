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

def pack_adj_matrix(matrix, n, bits=1):
    # Flatten 2D adjacency matrix into 1D list for setting individual signals
    result = []
    for i in range(16):
        for j in range(16):
            if i < n and j < n:
                result.append(1 if matrix[i][j] == 'Y' else 0)
            else:
                result.append(0)
    return result

async def write_adj_matrix(dut, matrix, n):
    flat = pack_adj_matrix(matrix, n)
    idx = 0
    for i in range(16):
        for j in range(16):
            sig_name = f'adj_{i}_{j}'
            if has_signal(dut, sig_name):
                getattr(dut, sig_name).value = flat[idx]
            idx += 1

async def read_matchings(dut, n, k):
    matchings = []
    for m in range(k):
        matching = []
        for j in range(n):
            sig_name = f'matching_{m}_{j}'
            if has_signal(dut, sig_name):
                val = int(getattr(dut, sig_name).value)
                matching.append(val)
            else:
                matching.append(0)
        matchings.append(matching)
    return matchings

async def wait_for_done(dut, max_cycles=5000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

# Test cases
def parse_test_case(input_str):
    lines = input_str.strip().split('\n')
    n = int(lines[0])
    matrix = []
    for i in range(n):
        matrix.append(list(lines[i+1]))
    return n, matrix

def verify_matchings(input_str, output_str):
    n, matrix = parse_test_case(input_str)
    if output_str.strip() == '0':
        return 0, []
    lines = output_str.strip().split('\n')
    k = int(lines[0])
    matchings = []
    for i in range(k):
        parts = list(map(int, lines[i+1].split()))
        matchings.append(parts)
    return k, matchings

def validate_matching(n, matrix, matching):
    # Check if matching is valid: each button j assigned to person matching[j]
    # person i must be allowed on button j (matrix[i][j] == 'Y')
    # All assigned persons distinct, all buttons assigned
    used_persons = set()
    for j in range(n):
        person = matching[j]
        if person < 1 or person > n:
            return False
        if person in used_persons:
            return False
        if matrix[person-1][j] != 'Y':
            return False
        used_persons.add(person)
    return len(used_persons) == n

def validate_disjoint(matchings):
    if len(matchings) == 0:
        return True
    n = len(matchings[0])
    for i in range(len(matchings)):
        for j in range(i+1, len(matchings)):
            for k in range(n):
                if matchings[i][k] == matchings[j][k]:
                    return False
    return True

async def run_test_case(dut, input_str, expected_output_str):
    n, matrix = parse_test_case(input_str)
    expected_k, expected_matchings = verify_matchings(input_str, expected_output_str)
    
    if n > 16:
        cocotb.log.warning(f"Skipping test case with n={n} > 16 (hardware limit)")
        return
    
    await reset_dut(dut)
    
    # Set n
    if has_signal(dut, 'n'):
        dut.n.value = n
    
    # Set adjacency matrix
    await write_adj_matrix(dut, matrix, n)
    
    # Start
    if has_signal(dut, 'start'):
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
    
    # Wait for done
    await wait_for_done(dut, max_cycles=5000)
    
    # Read results
    if has_signal(dut, 'k'):
        result_k = int(dut.k.value)
    else:
        result_k = 0
    
    cocotb.log.info(f"Expected k={expected_k}, Got k={result_k}")
    
    if result_k != expected_k:
        raise TestFailure(f"Mismatch in k: expected {expected_k}, got {result_k}")
    
    if result_k > 0:
        result_matchings = await read_matchings(dut, n, result_k)
        
        # Validate matchings
        for i in range(result_k):
            if not validate_matching(n, matrix, result_matchings[i]):
                raise TestFailure(f"Matching {i+1} is invalid: {result_matchings[i]}")
        
        if not validate_disjoint(result_matchings):
            raise TestFailure(f"Matchings are not disjoint")
        
        # For expected test cases, check exact matchings (with permutations allowed)
        # Since problem allows non-unique outputs, we just validate correctness
        cocotb.log.info(f"Generated {result_k} valid disjoint matchings")
    else:
        if expected_k == 0:
            cocotb.log.info("Correctly found 0 matchings")
        else:
            raise TestFailure(f"Expected {expected_k} matchings but got 0")

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_maximum_matchings(dut):
    # Check if sequential
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    
    # Test case 1
    input1 = "3\nYYY\nNYY\nYNY\n"
    expected1 = "2\n1 2 3\n3 1 2\n"
    
    # Test case 2  
    input2 = "2\nYN\nYN\n"
    expected2 = "0\n"
    
    # Additional test case - perfect matching possible twice
    input3 = "2\nYY\nYY\n"
    expected3 = "2\n1 2\n2 1\n"
    
    # Run tests
    await run_test_case(dut, input1, expected1)
    await run_test_case(dut, input2, expected2)
    await run_test_case(dut, input3, expected3)
    
    cocotb.log.info("All tests passed!")
