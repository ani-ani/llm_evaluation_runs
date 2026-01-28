import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

DATA_WIDTH = 16
CLK_NS = 10
MAX_CYCLES = 2000

# Helper functions

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

# Python reference function
def divisible_by_digits(startnum, endnum):
    result = []
    for n in range(startnum, endnum + 1):
        s = str(n)
        valid = True
        for char in s:
            d = int(char)
            if d == 0 or n % d != 0:
                valid = False
                break
        if valid:
            result.append(n)
    return result

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_divisible_by_digits(dut):
    # Setup clock and reset
    if not has_signal(dut, 'clk'):
        raise TestFailure("Missing required signal: clk")
    
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    await reset_dut(dut)
    
    # Test cases from specification
    test_cases = [
        (1, 22, [1, 2, 3, 4, 5, 6, 7, 8, 9, 11, 12, 15, 22]),
        (1, 15, [1, 2, 3, 4, 5, 6, 7, 8, 9, 11, 12, 15]),
        (20, 25, [22, 24]),
        (30, 33, []),  # Edge case: no matches
        (0, 9, [1, 2, 3, 4, 5, 6, 7, 8, 9]),  # Edge case: single digits
        (99, 100, [99])  # 100 has a zero digit
    ]
    
    passed = 0
    failed = 0
    
    for i, (start, end, expected_list) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: Range [{start}, {end}], Expected: {expected_list}")
        
        # Set inputs
        dut.startnum.value = clamp_to_width(start, DATA_WIDTH)
        dut.endnum.value = clamp_to_width(end, DATA_WIDTH)
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Collect results
        results = []
        # We need to wait for done for each found number
        # The module should output multiple pulses for multiple matches
        max_found = 20  # Reasonable max
        for _ in range(max_found):
            await wait_for_done(dut)
            if is_value_defined(dut.result.value):
                r = int(dut.result.value)
                results.append(r)
                # Check if this was the last number in range
                if r == end or r == 0:  # 0 is output when no matches
                    # Wait one more cycle to ensure done pulse clears if needed
                    await RisingEdge(dut.clk)
                    break
            else:
                raise TestFailure("Result undefined when done is high")
        else:
            raise TestFailure(f"Exceeded max_found for range {start}-{end}")
        
        # Verify results
        if sorted(results) != sorted(expected_list):
            cocotb.log.error(f"FAIL: Test {i+1} - Expected {expected_list}, got {results}")
            failed += 1
        else:
            cocotb.log.info(f"PASS: Test {i+1}")
            passed += 1
        
        # Reset for next test
        dut.rst_n.value = 0
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
    
    if failed > 0:
        raise TestFailure(f"{failed} out of {passed+failed} tests failed")
