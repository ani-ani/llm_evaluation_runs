import cocotb
from cocotb.triggers import Timer, RisingEdge, ClockCycles
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Constants
DATA_WIDTH = 4
ARRAY_SIZE = 16
CLK_NS = 10
MAX_CYCLES = 1000

# Helper functions
def is_value_defined(v):
    try:
        int(v)
        return True
    except (ValueError, TypeError):
        return False

def clamp_to_width(v, width):
    mask = (1 << width) - 1
    return v & mask

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def safe_int(v, default=0):
    try:
        return int(v)
    except (ValueError, TypeError):
        return default

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=1000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

def compute_expected(p_input, K, N):
    """Compute p^K given p (0-indexed)"""
    result = list(range(N))
    temp = list(p_input)
    for _ in range(K):
        new_temp = [0] * N
        for i in range(N):
            new_temp[i] = temp[temp[i]]
        temp = new_temp
    return temp

def compute_kth_root(a, K, N):
    """Compute K-th root of permutation a (0-indexed)"""
    visited = [False] * N
    result = [0] * N
    
    for i in range(N):
        if not visited[i]:
            # Find cycle starting at i
            cycle = []
            curr = i
            while not visited[curr]:
                visited[curr] = True
                cycle.append(curr)
                curr = a[curr]
            
            L = len(cycle)
            if L == 0:
                continue
            
            # Compute K-th root: shift backwards by K mod L
            shift = K % L
            for idx, node in enumerate(cycle):
                root_idx = (idx - shift) % L
                result[node] = cycle[root_idx]
    
    return result

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_permutation_root(dut):
    # Setup clock and reset
    if not has_signal(dut, 'clk'):
        await Timer(100, units='ns')
        return
    
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    await reset_dut(dut)
    
    # Test cases
    test_cases = [
        {
            'name': 'N=6, K=2, shift right by 2',
            'N': 6,
            'K': 2,
            'a_1idx': [3, 4, 5, 6, 1, 2],  # Input permutation (1-indexed)
            'exp_1idx': [5, 6, 1, 2, 3, 4],  # Expected root (1-indexed)
            'should_pass': True
        },
        {
            'name': 'N=4, K=2, shift right by 2',
            'N': 4,
            'K': 2,
            'a_1idx': [3, 4, 1, 2],
            'exp_1idx': [2, 3, 4, 1],
            'should_pass': True
        },
        {
            'name': 'N=2, K=1, identity',
            'N': 2,
            'K': 1,
            'a_1idx': [1, 2],
            'exp_1idx': [1, 2],
            'should_pass': True
        },
        {
            'name': 'N=3, K=1, cycle',
            'N': 3,
            'K': 1,
            'a_1idx': [2, 3, 1],
            'exp_1idx': [2, 3, 1],
            'should_pass': True
        }
    ]
    
    passed = 0
    failed = 0
    
    for test in test_cases:
        cocotb.log.info(f"\nTest: {test['name']}")
        
        try:
            # Convert to 0-indexed
            a_0idx = [x - 1 for x in test['a_1idx']]
            exp_0idx = [x - 1 for x in test['exp_1idx']]
            
            # Verify expected result
            check = compute_expected(exp_0idx, test['K'], test['N'])
            if check != a_0idx:
                cocotb.log.error(f"Test case error: exp root != verification")
            
            # Set inputs
            dut.n.value = clamp_to_width(test['N'], 4)
            dut.k.value = clamp_to_width(test['K'], 8)
            
            for i in range(test['N']):
                dut.a[i].value = clamp_to_width(a_0idx[i] + 1, DATA_WIDTH)
            
            for i in range(test['N'], ARRAY_SIZE):
                dut.a[i].value = 0
            
            # Start computation
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Wait for done
            await wait_for_done(dut, 1000)
            
            # Check valid signal
            if not has_signal(dut, 'valid'):
                valid = True
            else:
                valid = is_value_defined(dut.valid.value) and int(dut.valid.value) == 1
            
            if not valid:
                if test['should_pass']:
                    raise TestFailure(f"Valid=0 but test should pass")
                cocotb.log.info("Correctly returned valid=0")
                passed += 1
                continue
            
            # Read result
            result = []
            for i in range(test['N']):
                val = safe_int(dut.result[i].value)
                result.append(val - 1)  # Convert back to 0-indexed
            
            # Verify
            if result != exp_0idx:
                raise TestFailure(f"Expected {exp_0idx}, got {result}")
            
            passed += 1
            cocotb.log.info(f"PASS: {result}")
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed out of {passed + failed}")
    
    cocotb.log.info(f"All {passed} tests passed!")
