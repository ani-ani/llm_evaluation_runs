import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

MOD = 1000000007

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

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

# Reference implementation for testing
def solve_python(n, prime_counts):
    fact = [1] * 1005
    for i in range(1, 1005):
        fact[i] = (fact[i-1] * i) % MOD
    
    def nCr(n, r):
        if r < 0 or r > n:
            return 0
        num = fact[n]
        den = (fact[r] * fact[n-r]) % MOD
        return (num * pow(den, MOD - 2, MOD)) % MOD
    
    ans = 1
    for c in prime_counts:
        ans = (ans * nCr(c + n - 1, n - 1)) % MOD
    return ans

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_factorization_count(dut):
    # Setup clock
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    
    # Test cases: (n, prime_counts)
    test_cases = [
        (1, [15]),           # Case 1
        (3, [1, 2]),         # Case 2: 1*1*2 -> primes: 1 count of 2
        (2, [1, 1]),         # Case 3: 5*7 -> primes: 1 count of 5, 1 count of 7
        (2, [1, 1, 1]),      # 5*10 -> primes: 5, 2
        (3, [1, 1]),         # 1*30*1 -> primes: 2, 3, 5 (simplified counts)
        (50, [3, 1]),        # Large N
    ]
    
    passed = 0
    failed = 0
    
    for i, (n, counts) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: N={n}, Counts={counts}")
        
        # Compute expected
        expected = solve_python(n, counts)
        
        try:
            # Reset
            await reset_dut(dut)
            
            # Set inputs
            dut.num_primes.value = len(counts)
            
            # Handle array input. Depending on HDL structure, it might be a vector or individual signals
            # Attempt to detect array structure
            if hasattr(dut, 'prime_counts'):
                if hasattr(dut.prime_counts, '__len__'):
                    # It's an array of signals
                    for idx, val in enumerate(counts):
                        if idx < len(dut.prime_counts):
                            dut.prime_counts[idx].value = clamp_to_width(val, 32)
                else:
                    # It's a single signal? Assume packed array or vector.
                    # For this generic test, we assume unpacked array as per spec.
                    pass
            else:
                # Try accessing as individual signals prime_counts_0, prime_counts_1...
                for idx, val in enumerate(counts):
                    signal_name = f'prime_counts_{idx}'
                    if hasattr(dut, signal_name):
                        getattr(dut, signal_name).value = clamp_to_width(val, 32)
            
            # Start
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Wait for done
            max_cycles = 1000
            done = False
            for _ in range(max_cycles):
                await RisingEdge(dut.clk)
                if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                    done = True
                    break
            
            if not done:
                raise TestFailure(f"Timeout waiting for done signal")
            
            # Check result
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result signal is undefined")
            
            result = int(dut.result.value)
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1
            
    if failed > 0:
        raise TestFailure(f"{failed} tests failed out of {passed + failed}")