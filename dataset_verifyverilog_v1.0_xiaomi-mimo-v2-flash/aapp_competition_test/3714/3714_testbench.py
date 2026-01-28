import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

CLK_NS = 10
MAX_CYCLES = 2000
DATA_WIDTH = 8
N_MAX = 100

# Helper functions
def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def safe_int(v, default=0):
    try: return int(v)
    except ValueError: return default

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def gcd(a, b):
    while b:
        a, b = b, a % b
    return a

def lcm(a, b):
    if a == 0 or b == 0:
        return 0
    return abs(a * b) // gcd(a, b)

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if has_signal(dut, 'done') and is_value_defined(dut.done.value):
            if int(dut.done.value) == 1:
                return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

@cocotb.test(timeout_time=2000, timeout_unit="ms")
async def test_finding_t(dut):
    # Check sequential signals
    is_seq = has_signal(dut, 'clk') and has_signal(dut, 'rst_n')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    
    # Test cases
    test_cases = [
        ([2, 3, 1, 4], 3, True, "Example 1: cycles of length 3 and 1"),
        ([4, 4, 4, 4], -1, False, "Example 2: invalid permutation"),
        ([2, 1, 4, 3], 1, True, "Example 3: two 2-cycles"),
        ([1, 2, 3, 4], 1, True, "All self-loops"),
        ([2, 1, 3, 4], 2, True, "One 2-cycle, two self-loops"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (crush, expected, should_be_valid, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc}")
        n = len(crush)
        
        try:
            # Setup inputs
            if has_signal(dut, 'n'):
                dut.n.value = clamp_to_width(n, 7)
            
            # Set crush array
            if hasattr(dut, 'crush') and hasattr(dut.crush, '__len__'):
                # Array port
                for j in range(N_MAX):
                    val = crush[j] if j < n else 0
                    dut.crush[j].value = clamp_to_width(val, DATA_WIDTH)
            else:
                # Individual ports
                for j in range(N_MAX):
                    if hasattr(dut, f'crush_{j}'):
                        val = crush[j] if j < n else 0
                        getattr(dut, f'crush_{j}').value = clamp_to_width(val, DATA_WIDTH)
            
            if is_seq:
                # Start computation
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                await wait_for_done(dut)
                await RisingEdge(dut.clk)
            else:
                await Timer(100, units='ns')
            
            # Read results
            valid_bit = True
            if has_signal(dut, 'valid'):
                if is_value_defined(dut.valid.value):
                    valid_bit = int(dut.valid.value) == 1
            
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result undefined")
            result = int(dut.result.value)
            
            if should_be_valid:
                if not valid_bit:
                    raise TestFailure(f"Expected valid=1, got valid=0")
                if result != expected:
                    raise TestFailure(f"Expected {expected}, got {result}")
            else:
                if valid_bit:
                    raise TestFailure(f"Expected invalid (valid=0), got valid=1")
                # For invalid, result can be 0
                cocotb.log.info(f"  Correctly returned invalid (valid=0)")
            
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL: Test {i+1} ({desc}): {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} tests failed out of {len(test_cases)}")
    
    cocotb.log.info(f"All {passed} tests passed!")

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_random_cases(dut):
    """Test with random valid permutations"""
    is_seq = has_signal(dut, 'clk') and has_signal(dut, 'rst_n')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    
    random.seed(42)
    n_tests = 10
    passed = 0
    
    for test_idx in range(n_tests):
        # Generate random n (3-10 for speed)
        n = random.randint(3, 10)
        
        # Generate permutation
        perm = list(range(1, n + 1))
        random.shuffle(perm)
        
        # Compute expected answer in Python
        def compute_expected(crush_list):
            # Convert to 0-indexed for analysis
            crush = [x - 1 for x in crush_list]
            n_local = len(crush)
            
            # Check if permutation (each node has indegree 1)
            visited = [False] * n_local
            cycle_lengths = []
            
            for i in range(n_local):
                if not visited[i]:
                    cur = i
                    count = 0
                    while not visited[cur]:
                        visited[cur] = True
                        cur = crush[cur]
                        count += 1
                    cycle_lengths.append(count)
            
            # Check all nodes are visited (no dead ends)
            if not all(visited):
                return -1
            
            # Compute adjusted lengths and LCM
            adjusted = []
            for L in cycle_lengths:
                if L % 2 == 0:
                    adjusted.append(L // 2)
                else:
                    adjusted.append(L)
            
            if not adjusted:
                return 1
            
            result = adjusted[0]
            for val in adjusted[1:]:
                result = lcm(result, val)
            
            return result
        
        expected = compute_expected(perm)
        should_be_valid = (expected != -1)
        
        # Run test
        try:
            if has_signal(dut, 'n'):
                dut.n.value = clamp_to_width(n, 7)
            
            # Set crush array
            if hasattr(dut, 'crush') and hasattr(dut.crush, '__len__'):
                for j in range(N_MAX):
                    val = perm[j] if j < n else 0
                    dut.crush[j].value = clamp_to_width(val, DATA_WIDTH)
            else:
                for j in range(N_MAX):
                    if hasattr(dut, f'crush_{j}'):
                        val = perm[j] if j < n else 0
                        getattr(dut, f'crush_{j}').value = clamp_to_width(val, DATA_WIDTH)
            
            if is_seq:
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                await wait_for_done(dut)
                await RisingEdge(dut.clk)
            else:
                await Timer(100, units='ns')
            
            valid_bit = True
            if has_signal(dut, 'valid'):
                if is_value_defined(dut.valid.value):
                    valid_bit = int(dut.valid.value) == 1
            
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result undefined")
            result = int(dut.result.value)
            
            if should_be_valid:
                if not valid_bit:
                    raise TestFailure(f"Expected valid=1, got valid=0")
                if result != expected:
                    raise TestFailure(f"Expected {expected}, got {result}")
            else:
                if valid_bit:
                    raise TestFailure(f"Expected invalid (valid=0), got valid=1")
            
            passed += 1
            cocotb.log.info(f"Random test {test_idx+1}/{n_tests}: n={n}, expected={expected}, result={result} - PASS")
            
        except TestFailure as e:
            cocotb.log.error(f"Random test {test_idx+1}/{n_tests}: n={n}, perm={perm}: {e}")
            if should_be_valid:
                cocotb.log.error(f"  Expected: {expected}")
    
    if passed < n_tests:
        raise TestFailure(f"Only {passed}/{n_tests} random tests passed")
    cocotb.log.info(f"All {n_tests} random tests passed!")
