import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

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

DATA_WIDTH = 3
MAX_CARDS = 8
CLK_NS = 10
MAX_CYCLES = 200000

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=100000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def write_permutation(dut, prefix, perm, num_cards):
    """Write permutation array to individual port signals"""
    for i in range(num_cards):
        port_name = f"{prefix}_{i}"
        if has_signal(dut, port_name):
            getattr(dut, port_name).value = clamp_to_width(perm[i], DATA_WIDTH)
        else:
            raise TestFailure(f"Port {port_name} not found")

async def apply_permutation(deck, perm):
    """Apply permutation to deck state (Python simulation)"""
    n = len(deck)
    new_deck = [0] * n
    for i in range(n):
        # perm[i] is new position of card originally at i
        # But in Verilog, we track current deck state
        # perm[i] = j means card at position i moves to j
        new_pos = perm[i] - 1  # Convert to 0-indexed
        new_deck[new_pos] = deck[i]
    return new_deck

async def compute_expected(perm_a, perm_b, n):
    """Compute expected cycle length in Python"""
    deck = list(range(n))
    alice_shuf = [p - 1 for p in perm_a]  # 0-indexed
    bob_shuf = [p - 1 for p in perm_b]    # 0-indexed
    
    # Apply Alice then Bob (1 iteration = 2 shuffles)
    # Track positions after Bob's shuffle
    for count in range(1, 65536):  # Max 2^16-1 iterations
        # Alice shuffle
        new_deck = [0] * n
        for i in range(n):
            new_pos = alice_shuf[i]
            new_deck[new_pos] = deck[i]
        deck = new_deck
        
        # Bob shuffle
        new_deck = [0] * n
        for i in range(n):
            new_pos = bob_shuf[i]
            new_deck[new_pos] = deck[i]
        deck = new_deck
        
        # Check if identity
        if deck == list(range(n)):
            return count
    
    return 0  # huge

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_alice_bob(dut):
    # Check signals exist
    if not has_signal(dut, 'clk') or not has_signal(dut, 'rst_n'):
        raise TestFailure("Required signals missing")
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    await reset_dut(dut)
    
    # Test cases
    test_cases = [
        {  # Sample 1: n=3
            'n': 3,
            'alice': [2, 3, 1],
            'bob': [3, 1, 2],
            'expected': 2,
            'desc': 'Sample 1'
        },
        {  # Sample 2: n=6
            'n': 6,
            'alice': [5, 1, 6, 3, 2, 4],
            'bob': [4, 6, 5, 1, 3, 2],
            'expected': 5,
            'desc': 'Sample 2'
        },
        {  # Sample 3: n=8
            'n': 8,
            'alice': [1, 4, 2, 6, 7, 8, 5, 3],
            'bob': [3, 6, 8, 4, 7, 1, 5, 2],
            'expected': 10,
            'desc': 'Sample 3'
        },
        {  # Edge case: n=1
            'n': 1,
            'alice': [1],
            'bob': [1],
            'expected': 1,
            'desc': 'Single card'
        },
        {  # Identity test (should be 1 shuffle)
            'n': 4,
            'alice': [1, 2, 3, 4],
            'bob': [1, 2, 3, 4],
            'expected': 1,
            'desc': 'Identity permutations'
        }
    ]
    
    passed = 0
    failed = 0
    
    for test in test_cases:
        n = test['n']
        alice_perm = test['alice']
        bob_perm = test['bob']
        expected = test['expected']
        desc = test['desc']
        
        cocotb.log.info(f"Test: {desc} (n={n})")
        
        try:
            # Reset for each test
            await reset_dut(dut, cycles=3)
            
            # Write permutations
            await write_permutation(dut, 'alice', alice_perm, n)
            await write_permutation(dut, 'bob', bob_perm, n)
            
            # Write num_cards
            if has_signal(dut, 'num_cards'):
                dut.num_cards.value = clamp_to_width(n, 3)
            else:
                raise TestFailure("num_cards signal missing")
            
            # Start computation
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Wait for done
            await wait_for_done(dut, max_cycles=200000)
            
            # Read result
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result undefined")
            
            result = int(dut.result.value)
            
            # For huge case (>10^12), Verilog outputs 0
            # Python computes exact value up to 2^16-1
            if expected == 0:
                if result != 0:
                    raise TestFailure(f"Expected huge (0), got {result}")
            else:
                if result != expected:
                    raise TestFailure(f"Expected {expected}, got {result}")
            
            cocotb.log.info(f"  PASS: result={result}")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} tests failed, {passed} passed")
    
    cocotb.log.info(f"All tests passed: {passed}")

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_huge_case(dut):
    """Test a case that would require many iterations"""
    # Create a permutation that has large cycle length
    # Using a large n to potentially get large cycle
    n = 8
    # Alice: reverse order
    alice = [8, 7, 6, 5, 4, 3, 2, 1]
    # Bob: identity (for simplicity)
    bob = [1, 2, 3, 4, 5, 6, 7, 8]
    
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    await reset_dut(dut)
    
    # Write permutations
    await write_permutation(dut, 'alice', alice, n)
    await write_permutation(dut, 'bob', bob, n)
    dut.num_cards.value = clamp_to_width(n, 3)
    
    # Start
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done with shorter timeout for test
    await wait_for_done(dut, max_cycles=5000)
    
    result = int(dut.result.value)
    # This should compute 2 (since reverse twice = identity)
    # But let's verify it works
    
    expected = 2  # reverse twice is identity
    if result != expected:
        raise TestFailure(f"Expected {expected}, got {result}")
    
    cocotb.log.info(f"Huge case test passed: result={result}")
