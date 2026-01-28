import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Constants
CLK_NS = 10
MAX_CYCLES = 1000
DATA_WIDTH = 4
PAIRS_MAX = 12

# Helper functions
def is_value_defined(v):
    try:
        int(v)
        return True
    except ValueError:
        return False

def safe_int(v, default=0):
    try:
        return int(v)
    except ValueError:
        return default

def to_signed(val, bits):
    return val - (1 << bits) if val >= (1 << (bits-1)) else val

def from_signed(val, bits):
    return val + (1 << bits) if val < 0 else val

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

# Problem-specific helper
def pack_pairs(pairs, num_pairs):
    packed = 0
    for i in range(num_pairs):
        a, b = pairs[i]
        packed |= (clamp_to_width(a, 4) << (2*i*4 + 4))
        packed |= (clamp_to_width(b, 4) << (2*i*4))
    return packed

def solve_python(n, m, p1_list, p2_list):
    # Helper to parse list to pairs
    def to_pairs(lst):
        return [(lst[2*i], lst[2*i+1]) for i in range(len(lst)//2)]
    
    p1_pairs = to_pairs(p1_list)
    p2_pairs = to_pairs(p2_list)
    
    possible_shared = set()
    
    # Step 1: Find all possible shared numbers
    for i in range(n):
        for j in range(m):
            p1 = set(p1_pairs[i])
            p2 = set(p2_pairs[j])
            intersect = p1 & p2
            if len(intersect) == 1:
                possible_shared.add(intersect.pop())
    
    # Case 1: Exactly one possible shared number
    if len(possible_shared) == 1:
        return list(possible_shared)[0]
    
    # Check if both participants definitely know the number (but we don't)
    # For every pair a in p1, the intersection with valid p2 pairs must be constant (and size 1)
    # Similarly for p2.
    
    p1_knows = True
    for a in p1_pairs:
        candidates = set()
        for b in p2_pairs:
            inter = set(a) & set(b)
            if len(inter) == 1:
                candidates.add(inter.pop())
        if len(candidates) != 1:
            p1_knows = False
            break
            
    p2_knows = True
    for b in p2_pairs:
        candidates = set()
        for a in p1_pairs:
            inter = set(a) & set(b)
            if len(inter) == 1:
                candidates.add(inter.pop())
        if len(candidates) != 1:
            p2_knows = False
            break
            
    if p1_knows and p2_knows:
        return 0
    
    return -1

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_shared_number(dut):
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        dut.rst_n.value = 0
        dut.start.value = 0
        for _ in range(2):
            await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
    else:
        # Combinational
        await Timer(10, units='ns')

    # Test cases: (n, m, p1_list, p2_list, expected_output)
    # Output mapping: -1 -> 15, 0 -> 0, 1-9 -> 1-9
    test_cases = [
        (2, 2, [1, 2, 3, 4], [1, 5, 3, 4], 1),
        (2, 2, [1, 2, 3, 4], [1, 5, 6, 4], 0),
        (2, 3, [1, 2, 4, 5], [1, 2, 1, 3, 2, 3], 15),
        (2, 1, [1, 2, 1, 3], [1, 2], 1),
        (4, 4, [1, 2, 3, 4, 5, 6, 7, 8], [2, 3, 4, 5, 6, 7, 8, 1], 15),
        (3, 3, [1, 2, 5, 6, 7, 8], [2, 3, 4, 5, 8, 9], 0),
        (2, 2, [1, 2, 2, 3], [2, 3, 3, 4], 15),
        (2, 2, [1, 2, 1, 3], [1, 2, 1, 3], 0),
    ]

    passed = 0
    failed = 0

    for i, (n, m, p1_list, p2_list, expected) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: n={n}, m={m}")
        
        # Prepare inputs
        p1_packed = pack_pairs(p1_list, n)
        p2_packed = pack_pairs(p2_list, m)
        
        try:
            if is_seq:
                dut.n.value = n
                dut.m.value = m
                # Assign 48-bit vectors
                dut.p1_in.value = p1_packed
                dut.p2_in.value = p2_packed
                
                # Start pulse
                await RisingEdge(dut.clk)
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                
                # Wait for done
                cycles = 0
                while cycles < MAX_CYCLES:
                    if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                        break
                    await RisingEdge(dut.clk)
                    cycles += 1
                    if cycles >= MAX_CYCLES:
                        raise TestFailure(f"Timeout after {MAX_CYCLES} cycles")
                
                # Read result
                if not is_value_defined(dut.result.value):
                    raise TestFailure("Result undefined")
                result = int(dut.result.value)
            else:
                # Combinational
                dut.n.value = n
                dut.m.value = m
                dut.p1_in.value = p1_packed
                dut.p2_in.value = p2_packed
                await Timer(50, units='ns')
                if not is_value_defined(dut.result.value):
                    raise TestFailure("Result undefined")
                result = int(dut.result.value)

            # Verify
            # Map signed if needed (though output is 4-bit unsigned usually, -1 is 1111)
            # Expected: 15 for -1, 0 for 0
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            passed += 1
        except TestFailure as e:
            cocotb.log.error(f"FAIL Test {i+1}: {e}")
            failed += 1

    if failed > 0:
        raise TestFailure(f"{failed} tests failed")
