import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
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

# Precompute primes up to 100
def sieve_primes(limit):
    is_prime = [True] * (limit+1)
    is_prime[0] = is_prime[1] = False
    for i in range(2, int(limit**0.5)+1):
        if is_prime[i]:
            for j in range(i*i, limit+1, i):
                is_prime[j] = False
    return set(i for i, prime in enumerate(is_prime) if prime)

PRIMES = sieve_primes(100)

# Function to compute expected X
def compute_expected_X(K, M, L, bound=100):
    for X in range(1, bound+1):
        count = 0
        for n in range(X, X+K):
            if n <= M or n in PRIMES:
                count += 1
        if count == L:
            return X
    return -1

# Main test
@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_module(dut):
    '''Test all combinations of K=1..3, M=1..3, L=0..K.'''
    
    # No clock needed for combinational design
    
    # Loop over all combinations
    passed = 0
    failed = 0
    
    for K in range(1, 4):  # 1 to 3 inclusive
        for M in range(1, 4):  # 1 to 3
            for L in range(0, K+1):  # 0 to K inclusive
                # Compute expected X
                expected = compute_expected_X(K, M, L)
                
                # Set inputs
                dut.K.value = K
                dut.M.value = M
                dut.L.value = L
                
                # Wait for combinational propagation
                await Timer(10, units="ns")
                
                # Read output
                if not is_value_defined(dut.X.value):
                    raise TestFailure(f"Output X is undefined for K={K}, M={M}, L={L}")
                
                actual = int(dut.X.value)
                
                # Check against expected
                if expected == -1:
                    # Expect 16'hFFFF which is 65535 in decimal
                    expected_val = 65535
                else:
                    expected_val = expected
                
                if actual != expected_val:
                    raise TestFailure(f"Mismatch for K={K}, M={M}, L={L}: expected {expected_val}, got {actual}")
                
                cocotb.log.info(f"K={K}, M={M}, L={L}: PASS (X={actual})")
                passed += 1
    
    cocotb.log.info(f"{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")