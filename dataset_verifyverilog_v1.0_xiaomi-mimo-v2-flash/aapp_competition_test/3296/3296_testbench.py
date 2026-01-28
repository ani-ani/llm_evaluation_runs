import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

DATA_WIDTH = 32
CLK_NS = 10
MAX_CYCLES = 1000
P = (1 << 31) - 1

# Helper functions from rules
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

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=1000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

# Python reference for test cases
def count_permutations_mod_p(N, K, P):
    # Cycle decomposition, N ≤ 16
    from math import gcd
    from functools import reduce
    
    def lcm(a, b): return a // gcd(a, b) * b
    
    # Precompute factorials mod P
    fact = [1] * (N + 1)
    for i in range(2, N + 1):
        fact[i] = (fact[i-1] * i) % P
    
    # Precompute modular inverses for numbers up to N (needed for denominators)
    # Since P is prime, use Fermat's little theorem: a^(P-2) mod P
    def modinv(a, mod=P):
        return pow(a, mod-2, mod)
    
    # Enumerate all cycle length partitions of N
    def partitions(n, max_len):
        if n == 0:
            yield []
            return
        for i in range(1, min(n, max_len) + 1):
            for p in partitions(n - i, i):
                yield [i] + p
    
    total = 0
    # For each partition, compute count
    for part in partitions(N, N):
        # Check if LCM of part equals K
        if reduce(lcm, part, 1) != K:
            continue
        
        # Count cycles of each length
        from collections import Counter
        counts = Counter(part)
        
        # Compute multinomial coefficient: N! / prod(len^c * c!)
        denom = 1
        for length, c in counts.items():
            # length^c * c!
            term = (pow(length, c, P) * fact[c]) % P
            denom = (denom * term) % P
        
        # Numerator is fact[N]
        num = fact[N]
        
        # Multiply by modular inverse of denom
        count_val = (num * modinv(denom)) % P
        total = (total + count_val) % P
    
    return total

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_permutation_count(dut):
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    
    # Test cases: (N, K, expected_output)
    test_cases = [
        (3, 2, 3),
        (6, 6, 240),
        (15, 12, 1789014075)
    ]
    
    passed = failed = 0
    
    for i, (N, K, exp) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: N={N}, K={K}, expected={exp}")
        try:
            # Set inputs
            dut.N.value = clamp_to_width(N, 6)  # 6 bits for N≤16
            dut.K.value = clamp_to_width(K, 32)
            
            if is_seq:
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                await wait_for_done(dut)
            else:
                await Timer(100, units='ns')
            
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result undefined")
            
            result = int(dut.result.value)
            if result != exp:
                raise TestFailure(f"Expected {exp}, got {result}")
            passed += 1
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} tests failed")