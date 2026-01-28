import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

# Helpers
def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def safe_int(v, default=0):
    try: return int(v)
    except ValueError: return default

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

def to_signed(val, bits):
    return val - (1 << bits) if val >= (1 << (bits-1)) else val

def from_signed(val, bits):
    return val + (1 << bits) if val < 0 else val

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    if has_signal(dut, 'valid_in'): dut.valid_in.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=100000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_wcd_module(dut):
    # Setup Clock
    if has_signal(dut, 'clk'):
        cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    else:
        await Timer(100, units='ns') # Combinational fallback

    # Reset
    if has_signal(dut, 'rst_n'):
        await reset_dut(dut)
    
    # Define test cases (simplified for HDL constraints)
    # We scale inputs to fit 32-bit range and limit n to 16 for simulation speed
    test_cases = [
        {
            "pairs": [(17, 18), (15, 24), (12, 15)],
            "expected": [2, 3, 5, 6], # Any valid answer acceptable
            "n": 3
        },
        {
            "pairs": [(10, 16), (7, 17)],
            "expected": [-1],
            "n": 2
        },
        {
            "pairs": [(90, 108), (45, 105), (75, 40), (165, 175), (33, 30)],
            "expected": [3, 5],
            "n": 5
        },
        {
            "pairs": [(6, 35), (10, 21), (2, 2)], # From custom cases
            "expected": [2],
            "n": 3
        },
        {
            "pairs": [(2, 3), (6, 4)],
            "expected": [2],
            "n": 2
        }
    ]

    for tc_idx, tc in enumerate(test_cases):
        cocotb.log.info(f"Running Test Case {tc_idx+1}: {tc['pairs']}")
        
        # Send Start
        if has_signal(dut, 'start'):
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            await RisingEdge(dut.clk)
        
        # Check Ready (if exists)
        if has_signal(dut, 'ready'):
            for _ in range(100): # Wait for ready
                if safe_int(dut.ready.value) == 1:
                    break
                await RisingEdge(dut.clk)
        
        # Send 'len' (number of pairs)
        if has_signal(dut, 'len'):
            dut.len.value = tc['n']
        
        # Stream pairs
        pairs_sent = 0
        for a, b in tc['pairs']:
            # Clamp to 32-bit
            a_val = a & 0xFFFFFFFF
            b_val = b & 0xFFFFFFFF
            
            if has_signal(dut, 'a_in'): dut.a_in.value = a_val
            if has_signal(dut, 'b_in'): dut.b_in.value = b_val
            
            if has_signal(dut, 'valid_in'):
                dut.valid_in.value = 1
                await RisingEdge(dut.clk)
                # Wait for handshake if ready exists
                if has_signal(dut, 'ready'):
                    while safe_int(dut.ready.value) == 0:
                        await RisingEdge(dut.clk)
                dut.valid_in.value = 0
            else:
                # Assume combinational processing or fixed latency
                await RisingEdge(dut.clk)
            
            # Small delay between inputs if needed
            await Timer(10, units='ns')
            pairs_sent += 1
        
        # Wait for Done
        await wait_for_done(dut)
        
        # Read Result
        result_val = 0
        if has_signal(dut, 'result'):
            result_val = safe_int(dut.result.value)
            # If signed, convert
            if result_val > 0x7FFFFFFF: # Assuming 32-bit signed output
                result_val = result_val - 0x100000000
        else:
            raise TestFailure("Result signal not found")
        
        # Check Result
        if result_val in tc['expected']:
            cocotb.log.info(f"PASS: Got {result_val}, expected {tc['expected']}")
        elif -1 in tc['expected'] and result_val == -1:
             cocotb.log.info(f"PASS: Got -1 as expected")
        else:
            raise TestFailure(f"Result mismatch. Got {result_val}, expected one of {tc['expected']}")

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_random_cases(dut):
    # Test with random inputs within HDL limits
    if has_signal(dut, 'clk'):
        cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    if has_signal(dut, 'rst_n'):
        await reset_dut(dut)
    
    # Generate a simple random case
    n = 3
    pairs = []
    for _ in range(n):
        # Small numbers for easier verification
        a = random.randint(2, 100)
        b = random.randint(2, 100)
        pairs.append((a, b))
    
    # Compute WCD in Python (brute force for small numbers)
    def get_wcd_py(pairs):
        # Get all primes from first pair
        def factors(num):
            f = set()
            d = 2
            temp = num
            while d * d <= temp:
                while temp % d == 0:
                    f.add(d)
                    temp //= d
                d += 1
            if temp > 1:
                f.add(temp)
            return f
        
        if not pairs:
            return -1
        
        candidates = factors(pairs[0][0]).union(factors(pairs[0][1]))
        if not candidates:
            return -1
            
        for a, b in pairs[1:]:
            to_remove = set()
            for p in candidates:
                if a % p != 0 and b % p != 0:
                    to_remove.add(p)
            candidates -= to_remove
            if not candidates:
                return -1
        return candidates.pop()

    expected = get_wcd_py(pairs)
    
    cocotb.log.info(f"Random Test: n={n}, pairs={pairs}, expected={expected}")
    
    # Send to DUT
    if has_signal(dut, 'start'):
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        await RisingEdge(dut.clk)
    
    if has_signal(dut, 'len'):
        dut.len.value = n
        
    for a, b in pairs:
        if has_signal(dut, 'a_in'): dut.a_in.value = a
        if has_signal(dut, 'b_in'): dut.b_in.value = b
        if has_signal(dut, 'valid_in'):
            dut.valid_in.value = 1
            await RisingEdge(dut.clk)
            dut.valid_in.value = 0
        else:
            await RisingEdge(dut.clk)
        await Timer(10, units='ns')
        
    await wait_for_done(dut)
    
    result_val = safe_int(dut.result.value)
    if result_val > 0x7FFFFFFF:
        result_val -= 0x100000000
    
    if expected != -1 and result_val != expected:
        raise TestFailure(f"Random test failed. Got {result_val}, Expected {expected}")
    elif expected == -1 and result_val != -1:
        raise TestFailure(f"Random test failed. Got {result_val}, Expected -1")
    else:
        cocotb.log.info(f"Random test PASS: {result_val}")
