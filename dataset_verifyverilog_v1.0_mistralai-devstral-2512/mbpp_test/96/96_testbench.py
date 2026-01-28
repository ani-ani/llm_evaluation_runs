import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

DATA_WIDTH = 8
OUTPUT_WIDTH = 4
CLK_NS = 10
MAX_CYCLES = 300

def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def safe_int(v, default=0):
    try: return int(v)
    except ValueError: return default

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

# Helper to count divisors in Python
def count_divisors(n):
    if n <= 0: return 0
    count = 0
    for i in range(1, n + 1):
        if n % i == 0:
            count += 1
    return count

@cocotb.test(timeout_time=10, timeout_unit="ms")
async def test_divisor_counter(dut):
    # Setup clock and reset
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    await reset_dut(dut)
    
    # Test cases: (input_n, expected_divisors, description)
    test_cases = [
        (15, 4, "15 has 4 divisors: 1,3,5,15"),
        (12, 6, "12 has 6 divisors: 1,2,3,4,6,12"),
        (9, 3, "9 has 3 divisors: 1,3,9"),
        (1, 1, "1 has 1 divisor: 1"),
        (7, 2, "7 has 2 divisors: 1,7 (prime)"),
        (16, 5, "16 has 5 divisors: 1,2,4,8,16"),
        (0, 0, "0 should return 0"),
        (240, 20, "240 has 20 divisors (limited to 16 in output)"),
    ]
    
    passed = failed = 0
    
    for i, (n_in, exp, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc} (n={n_in})")
        try:
            # Clamp input to 8 bits
            n_clamped = clamp_to_width(n_in, DATA_WIDTH)
            dut.n_in.value = n_clamped
            
            # Start calculation
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Wait for completion
            await wait_for_done(dut)
            
            # Read result
            if not is_value_defined(dut.div_count.value):
                raise TestFailure("Result undefined")
            
            result = int(dut.div_count.value)
            
            # Expected value (clamped to 4-bit output)
            expected_clamped = clamp_to_width(exp, OUTPUT_WIDTH)
            
            if result != expected_clamped:
                raise TestFailure(f"Expected {expected_clamped}, got {result} (raw: {exp})")
            
            passed += 1
            cocotb.log.info(f"  PASS: div_count = {result}")
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
        
        # Small delay between tests
        await Timer(100, units='ns')
        
        # Reset for next test
        await reset_dut(dut)
    
    # Final summary
    cocotb.log.info(f"\nTest Summary: {passed} passed, {failed} failed")
    if failed > 0:
        raise TestFailure(f"{failed} test(s) failed")