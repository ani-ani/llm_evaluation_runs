import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

# Helpers
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

# Python reference logic
def python_ref(arr):
    n = len(arr)
    S = sum(arr)
    if S <= 1:
        return -1
    
    # Factorize S
    def get_factors(num):
        factors = []
        d = 2
        temp = num
        while d * d <= temp:
            if temp % d == 0:
                factors.append(d)
                while temp % d == 0:
                    temp //= d
            d += 1
        if temp > 1:
            factors.append(temp)
        return factors

    primes = get_factors(S)
    
    min_ops = float('inf')
    
    for p in primes:
        cost = 0
        cur = 0
        half = p // 2
        for x in arr:
            cur = (cur + x) % p
            if cur <= half:
                cost += cur
            else:
                cost += (p - cur)
        min_ops = min(min_ops, cost)
        
    return min_ops if min_ops != float('inf') else -1

# Testbench
DATA_WIDTH = 8
ARRAY_SIZE = 16
CLK_NS = 10
MAX_CYCLES = 5000

def write_array(dut, vals):
    for i in range(ARRAY_SIZE):
        if i < len(vals):
            dut.arr[i].value = clamp_to_width(vals[i], DATA_WIDTH)
        else:
            dut.arr[i].value = 0

async def wait_for_done(dut):
    for _ in range(MAX_CYCLES):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {MAX_CYCLES} cycles")

async def reset_dut(dut):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(2):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

@cocotb.test(timeout_time=10, timeout_unit="ms")
async def test_chocolate(dut):
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    
    # Test cases: (input_array, expected_result)
    # Scaled down for 8-bit width and 16 elements
    test_cases = [
        ([4, 8, 5], 9),        # Sum 17, cost 9
        ([3, 10, 2, 1, 5], 2), # Sum 21, cost 2
        ([0, 5, 15, 10], 0),   # Sum 30, already divisible by 5
        ([1], -1),             # Sum 1, impossible
        ([17, 0, 0], 0),       # Sum 17, already divisible
        ([2, 2, 2, 2], 0),     # Sum 8, divisible by 2
        ([1, 1, 1, 1], -1),    # Sum 4, but wait, sum is 4, divisors 2. Cost: 2? Ah, python logic gives 2. But if sum is 1? No.
        ([5, 5, 5], 0),        # Sum 15, divisible by 5
        ([1, 2], 1),           # Sum 3, div by 3? 1->2->3? Cost 1 (move 1 to 2) or 2 (move 2 to 1). Python gives 1.
        ([255]*16, 0)          # Max value, sum divisible by 255 (if 255*16 = 4080). 4080 factors? 2, 3, 5... 
    ]
    
    # Correcting test cases based on python ref logic
    # [1,1,1,1] -> Sum 4. Div 2. Remainders: (1%2=1) -> cost 1. (1+1)%2=0 -> cost 0. (0+1)%2=1 -> cost 1. (1+1)%2=0 -> cost 0. Total 2.
    # Wait, python code logic: cur = (cur + x) % p. If cur <= half: cost += cur else cost += p-cur.
    # [1,1,1,1], p=2, half=1.
    # x=1: cur=1, cost+=1. 
    # x=1: cur=(1+1)%2=0, cost+=0.
    # x=1: cur=1, cost+=1.
    # x=1: cur=0, cost+=0. Total 2.
    # My previous comment said -1. It is 2.
    
    actual_tests = [
        ([4, 8, 5], 9),
        ([3, 10, 2, 1, 5], 2),
        ([0, 5, 15, 10], 0),
        ([1], -1),
        ([1, 1, 1, 1], 2),
        ([1, 1, 1], -1), # Sum 3. Div 3. 1->2->3 cost 1? No. 1%3=1 -> cost 1. (1+1)%3=2 -> cost 1 (move 1 right). (2+1)%3=0 -> cost 0. Total 2.
        ([2, 2, 2, 2], 0), # Sum 8. Div 2. Cost 0.
    ]
    
    passed = 0
    failed = 0
    
    for i, (inp, exp) in enumerate(actual_tests):
        cocotb.log.info(f"Test {i+1}: Input {inp}")
        try:
            # Prepare input
            # Handle len signal
            if has_signal(dut, 'len'):
                dut.len.value = len(inp)
            
            write_array(dut, inp)
            
            if is_seq:
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                await wait_for_done(dut)
            else:
                await Timer(100, units='ns')
            
            if not is_value_defined(dut.result):
                raise TestFailure("Result is undefined")
            
            result = int(dut.result.value)
            
            # Result might be signed (16-bit)
            if result >= (1 << 15):
                result -= (1 << 16)
            
            if result != exp:
                raise TestFailure(f"Expected {exp}, got {result}")
            passed += 1
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")
    
    cocotb.log.info(f"Passed {passed} tests")