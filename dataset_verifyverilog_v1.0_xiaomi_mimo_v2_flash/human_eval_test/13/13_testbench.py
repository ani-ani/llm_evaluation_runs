import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

def is_value_defined(value):
    """Check if a cocotb value is defined (not X or Z)."""
    try:
        int(value)
        return True
    except ValueError:
        return False

async def wait_for_done(dut, timeout_cycles=50):
    """Wait for done signal to go high."""
    for cycle in range(timeout_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and dut.done.value == 1:
            return True
    return False

def gcd_reference(a, b):
    """Reference GCD implementation for verification."""
    while b != 0:
        a, b = b, a % b
    return a

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_gcd_basic(dut):
    """Test basic GCD calculations."""
    # Create clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.a.value = 0
    dut.b.value = 0
    await Timer(50, units="ns")
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases from problem
    test_cases = [
        (3, 5, 1),
        (25, 15, 5),
        (49, 14, 7),
        (144, 60, 12),
        (3, 7, 1),
        (10, 15, 5),
    ]
    
    for i, (a, b, expected) in enumerate(test_cases):
        dut._log.info(f"Test case {i}: gcd({a}, {b}) = {expected}")
        
        # Set inputs
        dut.a.value = a
        dut.b.value = b
        await RisingEdge(dut.clk)
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        done_ok = await wait_for_done(dut)
        if not done_ok:
            raise TestFailure(f"Test {i}: Timeout waiting for done signal")
        
        # Check result
        if not is_value_defined(dut.result.value):
            raise TestFailure(f"Test {i}: Result is undefined (X/Z)")
        
        result = int(dut.result.value)
        if result != expected:
            raise TestFailure(f"Test {i}: Expected {expected}, got {result}")
        
        dut._log.info(f"  Result: {result} [OK]")
        
        # Wait for done to go low
        await RisingEdge(dut.clk)
    
    dut._log.info(f"All {len(test_cases)} basic tests passed")

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_gcd_edge_cases(dut):
    """Test edge cases."""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.a.value = 0
    dut.b.value = 0
    await Timer(50, units="ns")
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Edge cases
    edge_cases = [
        (5, 5, 5),      # Equal numbers
        (7, 0, 7),      # Zero divisor
        (0, 7, 7),      # Zero dividend
        (1, 123, 1),    # GCD is 1
        (65535, 32768, 1),  # Max 16-bit values with GCD 1
    ]
    
    for i, (a, b, expected) in enumerate(edge_cases):
        dut._log.info(f"Edge test {i}: gcd({a}, {b}) = {expected}")
        
        dut.a.value = a
        dut.b.value = b
        await RisingEdge(dut.clk)
        
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        done_ok = await wait_for_done(dut)
        if not done_ok:
            raise TestFailure(f"Edge test {i}: Timeout")
        
        if not is_value_defined(dut.result.value):
            raise TestFailure(f"Edge test {i}: Result undefined")
        
        result = int(dut.result.value)
        if result != expected:
            raise TestFailure(f"Edge test {i}: Expected {expected}, got {result}")
        
        dut._log.info(f"  Result: {result} [OK]")
        await RisingEdge(dut.clk)
    
    dut._log.info(f"All {len(edge_cases)} edge tests passed")

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_gcd_random(dut):
    """Test with random values."""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(50, units="ns")
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    random.seed(42)
    num_tests = 5
    
    for i in range(num_tests):
        a = random.randint(1, 1000)
        b = random.randint(1, 1000)
        expected = gcd_reference(a, b)
        
        dut._log.info(f"Random test {i}: gcd({a}, {b}) = {expected}")
        
        dut.a.value = a
        dut.b.value = b
        await RisingEdge(dut.clk)
        
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        done_ok = await wait_for_done(dut)
        if not done_ok:
            raise TestFailure(f"Random test {i}: Timeout")
        
        if not is_value_defined(dut.result.value):
            raise TestFailure(f"Random test {i}: Result undefined")
        
        result = int(dut.result.value)
        if result != expected:
            raise TestFailure(f"Random test {i}: Expected {expected}, got {result}")
        
        dut._log.info(f"  Result: {result} [OK]")
        await RisingEdge(dut.clk)
    
    dut._log.info(f"All {num_tests} random tests passed")

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_gcd_throughput(dut):
    """Test multiple consecutive operations."""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(50, units="ns")
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    operations = [
        (100, 50, 50),
        (17, 13, 1),
        (256, 192, 64),
        (36, 48, 12),
    ]
    
    for i, (a, b, expected) in enumerate(operations):
        dut._log.info(f"Throughput test {i}: gcd({a}, {b}) = {expected}")
        
        dut.a.value = a
        dut.b.value = b
        await RisingEdge(dut.clk)
        
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        done_ok = await wait_for_done(dut)
        if not done_ok:
            raise TestFailure(f"Throughput test {i}: Timeout")
        
        if not is_value_defined(dut.result.value):
            raise TestFailure(f"Throughput test {i}: Result undefined")
        
        result = int(dut.result.value)
        if result != expected:
            raise TestFailure(f"Throughput test {i}: Expected {expected}, got {result}")
        
        dut._log.info(f"  Result: {result} [OK]")
        await RisingEdge(dut.clk)
    
    dut._log.info(f"All {len(operations)} throughput tests passed")
