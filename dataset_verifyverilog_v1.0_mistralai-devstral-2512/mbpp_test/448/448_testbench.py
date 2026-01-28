import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

DATA_WIDTH = 16
CLK_NS = 10
MAX_CYCLES = 200

def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def safe_int(v, default=0):
    try: return int(v)
    except ValueError: return default

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

# Reference Python implementation for test generation
def cal_sum(n):
    if n == 0:
        return 3
    if n == 1:
        return 3
    if n == 2:
        return 5
    a, b, c = 3, 0, 2
    sum_val = 5
    while n > 2:
        d = a + b
        sum_val = sum_val + d
        a, b, c = b, c, d
        n = n - 1
    return sum_val

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_perrin_sum(dut):
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test cases
    test_cases = [
        (0, 3, "n=0: sum = P(0) = 3"),
        (1, 3, "n=1: sum = P(0)+P(1) = 3"),
        (2, 5, "n=2: sum = P(0)+P(1)+P(2) = 5"),
        (9, 49, "n=9: sum = 49"),
        (10, 66, "n=10: sum = 66"),
        (11, 88, "n=11: sum = 88"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (n_val, expected, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc}")
        try:
            # Wait for idle
            await RisingEdge(dut.clk)
            
            # Set input and start
            dut.n.value = clamp_to_width(n_val, 4)
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Wait for completion
            await wait_for_done(dut)
            
            # Read result
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result signal undefined")
            
            result = int(dut.result.value)
            cocotb.log.info(f"  Result: {result}, Expected: {expected}")
            
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL (test {i+1}): {e}")
            failed += 1
        
        # Small delay between tests
        await Timer(50, units='ns')
    
    # Test reset during computation
    cocotb.log.info("Test reset during computation")
    try:
        await RisingEdge(dut.clk)
        dut.n.value = 10
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        # Reset before completion
        await Timer(50, units='ns')
        await RisingEdge(dut.clk)
        dut.rst_n.value = 0
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
        
        # Check reset worked
        if int(dut.result.value) != 0:
            raise TestFailure(f"Result not zero after reset: {int(dut.result.value)}")
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            raise TestFailure("Done should be 0 after reset")
        
        cocotb.log.info("  Reset during computation: PASS")
        passed += 1
    except TestFailure as e:
        cocotb.log.error(f"FAIL (reset test): {e}")
        failed += 1
    
    # Test consecutive runs
    cocotb.log.info("Test consecutive runs")
    try:
        for test_n in [5, 7]:
            expected = cal_sum(test_n)
            await RisingEdge(dut.clk)
            dut.n.value = clamp_to_width(test_n, 4)
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            await wait_for_done(dut)
            result = int(dut.result.value)
            if result != expected:
                raise TestFailure(f"Consecutive run n={test_n}: expected {expected}, got {result}")
        cocotb.log.info("  Consecutive runs: PASS")
        passed += 1
    except TestFailure as e:
        cocotb.log.error(f"FAIL (consecutive test): {e}")
        failed += 1
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed, {passed} passed")
    else:
        cocotb.log.info(f"All tests passed: {passed} passed")