import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

# --- Helpers ---
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

# --- Reference Model (Python) ---
def get_expected(a, b, l, r):
    # Minimal Python implementation of the logic derived from the problem analysis
    # This handles the periodic nature and distinct counting
    
    # Determine the periodic pattern (simplified logic based on provided snippets)
    # The period is 2*(a+b). The distinct letters in the period is a+1 for optimal strategies.
    
    period = 2 * (a + b)
    distinct_in_period = a + 1
    
    # If the range covers a full period (or more), the distinct count is fixed
    # However, we need to be careful about edge cases where specific segments have fewer.
    # The problem asks for the *minimum* possible number.
    
    # Given the complexity of exact optimal generation simulation, 
    # we will verify against the expected outputs from the provided test suite.
    # For the HDL, we implement the logic derived from the code snippets which is:
    # 1. Construct sequence of length 2a+2b based on a,b.
    # 2. Count distinct in segment.
    
    # Let's implement a generator matching the logic in the provided Python solutions
    # to ensure our HDL follows a concrete, implementable algorithm.
    
    # Construct sequence logic (hybrid of provided solutions)
    seq = []
    # First half (Mister B's turn simulation)
    # Initial letters 1..a
    for i in range(a):
        seq.append(i + 1)
    # B's appended letters
    for i in range(b):
        seq.append(a) # He can always append 'a' (or max letter) to minimize variety?
        # Actually, the logic in the snippets is specific.
        # Let's use the logic from the second snippet (main function) which seems more structured.
        
    # We will use the logic provided in the "Example Python code" block.
    # To ensure we match the HDL implementation, we should implement the exact sequence logic.
    
    # Simplified sequence generation based on the prompt's logic:
    # The optimal strategy creates a repeating pattern with a+1 distinct letters.
    # We need to map position to letter ID.
    
    # Re-implementing the logic from the provided code:
    _A = []
    if b >= a:
        _A = [i+1 for i in range(a)]
        _A += [a] * b
        _A += [i+1 for i in range(a)]
        _A[2*a+b-1] += 1
        _A += [_A[2*a+b-1]] * b
        for i in range(2*a + 2*b):
            _A.append(_A[i])
    else: # b < a
        _A = [i+1 for i in range(a)]
        _A += [a] * b
        for i in range(a):
            if i+1 <= b:
                _A.append(i+1)
            else:
                _A.append(a + i - b + 2)
        _A += [_A[2*a+b-1]] * b
        for i in range(2*a + 2*b):
            _A.append(_A[i])
            
    # Adjust indices for 1-based l, r
    # The sequence _A in code seems to be 1-indexed or constructed specifically.
    # Let's try to treat _A as the periodic sequence of letters (IDs).
    # We need to match the indices l-1 and r-1 (0-based).
    
    effective_l = l
    effective_r = r
    
    # If the range is very long, we might be able to optimize, 
    # but for testing we'll calculate exactly over the range (clamped for sanity if needed, 
    # but the HDL handles large ranges via modulo).
    
    # Since l and r can be huge, we must use modulo arithmetic.
    period_seq = _A[:2*(a+b)]
    
    # Normalize start and end relative to the period
    # The sequence generation logic in the code might have a startup offset.
    # But usually, it settles into a cycle.
    # Let's assume the sequence is periodic with period 2(a+b) starting from index 1.
    
    start_idx = (l - 1) % (2*(a+b))
    end_idx = (r - 1) % (2*(a+b))
    
    count = 0
    seen = set()
    
    # If range spans multiple periods, answer is simply distinct count in period
    if r - l + 1 >= 2*(a+b):
        return a + 1
        
    # Handle circular range
    if start_idx <= end_idx:
        for i in range(start_idx, end_idx + 1):
            seen.add(period_seq[i])
    else:
        for i in range(start_idx, 2*(a+b)):
            seen.add(period_seq[i])
        for i in range(0, end_idx + 1):
            seen.add(period_seq[i])
            
    return len(seen)

# --- Testbench ---

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=10000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

@cocotb.test(timeout_time=10, timeout_unit="ms")
async def test_alien_game(dut):
    # Setup Clock
    if has_signal(dut, 'clk'):
        clock = Clock(dut.clk, 10, units='ns')
        cocotb.start_soon(clock.start())
        await reset_dut(dut)
    else:
        # Combinational circuit
        await Timer(10, units='ns')

    # Test cases extracted from the prompt
    test_cases = [
        (1, 1, 1, 8, 2),
        (4, 2, 2, 6, 3),
        (3, 7, 4, 6, 1),
        (4, 5, 1, 1, 1),
        (12, 12, 1, 1000, 13),
        (12, 1, 1000, 1000, 1),
        (3, 4, 701, 703, 3),
        (12, 12, 13, 1000000000, 13),
        (3, 4, 999999999, 1000000000, 1),
        (5, 6, 1000000000, 1000000000, 1)
    ]

    passed = 0
    failed = 0

    for i, (a, b, l, r, expected) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: a={a}, b={b}, l={l}, r={r}")
        
        try:
            # Inputs
            dut.a_in.value = a
            dut.b_in.value = b
            dut.l_in.value = l
            dut.r_in.value = r
            
            if has_signal(dut, 'start'):
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                await wait_for_done(dut)
            else:
                await Timer(100, units='ns')
            
            # Check result
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result signal undefined")
            
            result = int(dut.result.value)
            
            # For the provided test case "4 5 1 1", the expected output is 1.
            # Our reference model logic (get_expected) needs to match this.
            # The provided Python code is complex and slightly different between examples.
            # We will use the expected output from the provided test suite as the ground truth.
            
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            passed += 1
            cocotb.log.info(f"PASS: {result}")

        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1

    if failed:
        raise TestFailure(f"{failed} tests failed")
