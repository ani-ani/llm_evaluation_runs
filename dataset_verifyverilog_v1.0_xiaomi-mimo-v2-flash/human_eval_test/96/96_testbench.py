import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

DATA_WIDTH = 8
ARRAY_SIZE = 16
CLK_NS = 10
MAX_CYCLES = 2000

def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_count_up_to(dut):
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    await reset_dut(dut)
    
    test_cases = [
        (5, [2, 3], "n=5"),
        (6, [2, 3, 5], "n=6"),
        (7, [2, 3, 5], "n=7"),
        (10, [2, 3, 5, 7], "n=10"),
        (0, [], "n=0"),
        (22, [2, 3, 5, 7, 11, 13, 17, 19], "n=22"),
        (1, [], "n=1"),
        (18, [2, 3, 5, 7, 11, 13, 17], "n=18"),
        (47, [2, 3, 5, 7, 11, 13, 17, 19, 23, 29, 31, 37, 41, 43], "n=47"),
        (101, [2, 3, 5, 7, 11, 13, 17, 19, 23, 29, 31, 37, 41, 43, 47, 53, 59, 61, 67, 71, 73, 79, 83, 89, 97], "n=101"),
    ]
    
    passed = failed = 0
    
    for i, (n, expected_primes, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc}")
        try:
            dut.n_in.value = clamp_to_width(n, 6)
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            await wait_for_done(dut)
            
            if not is_value_defined(dut.prime_count.value):
                raise TestFailure("prime_count undefined")
            
            prime_count = int(dut.prime_count.value)
            
            result_primes = []
            for j in range(min(prime_count, ARRAY_SIZE)):
                if hasattr(dut.primes, '__getitem__'):
                    val = int(dut.primes[j].value)
                else:
                    bit_slice = int(dut.primes.value) >> (j * DATA_WIDTH)
                    val = bit_slice & ((1 << DATA_WIDTH) - 1)
                if val != 0:
                    result_primes.append(val)
            
            expected = expected_primes[:16]
            if result_primes != expected:
                raise TestFailure(f"Expected {expected}, got {result_primes}")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1
        
        await reset_dut(dut)
    
    if failed:
        raise TestFailure(f"{failed} tests failed")