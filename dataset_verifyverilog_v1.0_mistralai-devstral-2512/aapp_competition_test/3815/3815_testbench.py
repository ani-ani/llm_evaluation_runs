import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

DATA_WIDTH = 32
MOD = 1000000009
MAX_CYCLES = 2000
CLK_NS = 10

# Helper functions
def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def safe_int(v, default=0):
    try: return int(v)
    except ValueError: return default

def clamp_to_width(v, bits):
    # Handle negative python integers for signed logic if needed, here unsigned
    val = v % (1 << bits) if v < 0 else v
    return val & ((1 << bits) - 1)

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

# Modular arithmetic helpers for Python reference
def mod_pow(base, exp, mod):
    res = 1
    base %= mod
    while exp > 0:
        if exp & 1:
            res = (res * base) % mod
        base = (base * base) % mod
        exp >>= 1
    return res

def mod_inv(x, mod):
    return mod_pow(x, mod - 2, mod)

def python_solver(n, a, b, k, seq_str):
    M = MOD
    # Calculate Q = (b/a)^k mod M
    inv_a = mod_inv(a, M)
    ratio = (b * inv_a) % M
    q = mod_pow(ratio, k, M)
    
    t = (n + 1) // k
    
    # Calculate D = sum_{j=0}^{t-1} q^j
    if q == 1:
        d = t % M
    else:
        num = (mod_pow(q, t, M) - 1)
        den = mod_inv((q - 1) % M, M)
        d = (num * den) % M
    
    # Calculate Period Sum
    base_term = mod_pow(a, n, M)
    c_ratio = (b * inv_a) % M
    period_sum = 0
    
    for i in range(k):
        if seq_str[i] == '+':
            period_sum = (period_sum + base_term) % M
        else:
            period_sum = (period_sum - base_term) % M
        base_term = (base_term * c_ratio) % M
        
    # Final Result: base_term (which is now a^n * (b/a)^k) is actually not used directly in this form.
    # We need a^n * Period_Sum * D.
    # Wait, in the loop we multiplied base_term by c_ratio. 
    # The base_term at the end of the loop is a^n * (b/a)^k.
    # The Python solutions calculate Sum of first K terms, then multiply by D.
    # Sum of first K terms = a^n * [1 - (b/a)^k] / [1 - (b/a)]
    # Total Sum = Sum_{block} ( (b/a)^k )^j * (Sum of block)
    # = Sum_{block} q^j * (a^n * (1 - q) / (1 - ratio) )
    # = a^n * (1 - q) / (1 - ratio) * D
    # Note: The loop implementation in prompt code calculates C = sum of s_i * a^{n-i}b^i for i=0..k-1.
    # Which is a^n * sum(s_i * (b/a)^i).
    
    # Let's re-verify with the prompt's C code logic:
    # C = pow(A, N, mod) -> initial term
    # for i in range(K):
    #   ans += sign * C * D
    #   C = C * B * A^-1
    # This computes: D * a^n * [sum(s_i * (b/a)^i)]
    # Which is exactly what we need.
    
    return (period_sum * d) % M

async def wait_for_done(dut, max_cycles=2000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    dut.start.value = 0
    if has_signal(dut, 'seq'): dut.seq.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def pack_seq(dut, seq_str):
    # seq is packed 8-bit: bit 0 is index 0
    val = 0
    for i, char in enumerate(seq_str):
        if char == '+':
            val |= (1 << i)
    dut.seq.value = val

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_alternating_sum(dut):
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    
    test_cases = [
        (2, 2, 3, 3, "+-+", 7),
        (4, 1, 5, 1, "-", 999999228),
        (1, 1, 4, 2, "-+", 3),
        (3, 1, 4, 4, "+--+", 45),
        (5, 1, 1, 6, "++---+", 0),
    ]
    
    passed = 0
    failed = 0
    
    for n, a, b, k, seq_str, expected in test_cases:
        # Calculate expected using python solver (ground truth)
        calc_expected = python_solver(n, a, b, k, seq_str)
        # Note: The provided expected output for example 2 is 999999228.
        # Python solver: 
        # n=4, a=1, b=5, k=1, seq='-'
        # Q = (5/1)^1 = 5
        # T = (4+1)//1 = 5
        # D = (5^5 - 1)/(5-1) = (3125-1)/4 = 781
        # Period Sum (k=1): -1 * 1^4 = -1
        # Total = -1 * 781 = -781 mod M = 1000000009 - 781 = 999999228. Matches.
        
        cocotb.log.info(f"Test Case: n={n}, a={a}, b={b}, k={k}, seq={seq_str}")
        
        try:
            dut.n.value = n
            dut.a.value = a
            dut.b.value = b
            dut.k.value = k
            await pack_seq(dut, seq_str)
            
            if is_seq:
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                await wait_for_done(dut)
            else:
                await Timer(1000, units='ns')
            
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result undefined")
                
            result = int(dut.result.value)
            # Ensure result is within 32 bits and positive
            result = result & 0xFFFFFFFF
            
            if result != calc_expected:
                raise TestFailure(f"Expected {calc_expected}, got {result}")
            passed += 1
        except TestFailure as e:
            cocotb.log.error(f"FAIL (n={n}, a={a}, b={b}, k={k}, seq={seq_str}): {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} tests failed")
