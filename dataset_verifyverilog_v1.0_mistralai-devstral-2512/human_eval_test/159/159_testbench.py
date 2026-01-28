import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

DATA_WIDTH = 10
RESULT_WIDTH = 11
CLK_NS = 10
MAX_CYCLES = 1000

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

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_eat_module(dut):
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    
    # Test cases from problem
    test_cases = [
        (5, 6, 10, 11, 4, "basic case 1"),
        (4, 8, 9, 12, 1, "basic case 2"),
        (1, 10, 10, 11, 0, "eat all remaining"),
        (2, 11, 5, 7, 0, "not enough remaining"),
        (4, 5, 7, 9, 2, "edge case 1"),
        (4, 5, 1, 5, 0, "edge case 2"),
        (0, 0, 0, 0, 0, "all zeros"),
        (1000, 1000, 1000, 2000, 0, "max values"),
        (0, 1000, 500, 500, 0, "need > remaining"),
        (1000, 500, 1000, 1500, 500, "remaining > need")
    ]
    
    passed = 0
    failed = 0
    
    for i, (num, need, rem, exp_total, exp_rem_after, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc} (num={num}, need={need}, remaining={rem})")
        try:
            # Set inputs
            dut.number.value = clamp_to_width(num, DATA_WIDTH)
            dut.need.value = clamp_to_width(need, DATA_WIDTH)
            dut.remaining.value = clamp_to_width(rem, DATA_WIDTH)
            
            if is_seq:
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                await wait_for_done(dut)
            else:
                await Timer(100, units='ns')
            
            # Check outputs
            if not is_value_defined(dut.total.value):
                raise TestFailure("total output undefined")
            if not is_value_defined(dut.remaining_after.value):
                raise TestFailure("remaining_after output undefined")
            
            total = int(dut.total.value)
            remaining_after = int(dut.remaining_after.value)
            
            if total != exp_total:
                raise TestFailure(f"total: expected {exp_total}, got {total}")
            if remaining_after != exp_rem_after:
                raise TestFailure(f"remaining_after: expected {exp_rem_after}, got {remaining_after}")
            
            passed += 1
            cocotb.log.info(f"PASS: total={total}, remaining_after={remaining_after}")
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL test {i+1}: {e}")
            failed += 1
            
    # Additional random tests
    random_tests = 20
    for i in range(random_tests):
        num = random.randint(0, 1000)
        need = random.randint(0, 1000)
        rem = random.randint(0, 1000)
        
        # Compute expected
        eaten = min(need, rem)
        exp_total = num + eaten
        exp_rem_after = rem - eaten
        
        test_id = f"random_{i}"
        cocotb.log.info(f"Test {test_id}: num={num}, need={need}, remaining={rem}")
        
        try:
            dut.number.value = clamp_to_width(num, DATA_WIDTH)
            dut.need.value = clamp_to_width(need, DATA_WIDTH)
            dut.remaining.value = clamp_to_width(rem, DATA_WIDTH)
            
            if is_seq:
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                await wait_for_done(dut)
            else:
                await Timer(100, units='ns')
            
            total = int(dut.total.value)
            remaining_after = int(dut.remaining_after.value)
            
            if total != exp_total or remaining_after != exp_rem_after:
                raise TestFailure(f"random {i}: expected total={exp_total}, rem={exp_rem_after}; got total={total}, rem={remaining_after}")
            
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL random {i}: {e}")
            failed += 1
    
    total_tests = passed + failed
    cocotb.log.info(f"\nTest Summary: {passed}/{total_tests} passed")
    
    if failed:
        raise TestFailure(f"{failed} tests failed out of {total_tests}")