import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

CLK_NS = 10
MAX_CYCLES = 1000
DATA_WIDTH = 32
D_WIDTH = 5

# Helper functions
def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def safe_int(v, default=0):
    try: return int(v)
    except ValueError: return default

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

def left_rotate(n, d, bits=32):
    """Reference Python implementation"""
    d = d % bits
    if d == 0:
        return n
    return ((n << d) | (n >> (bits - d))) & ((1 << bits) - 1)

@cocotb.test(timeout_time=2000, timeout_unit="ms")
async def test_left_rotate(dut):
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    await reset_dut(dut)
    
    # Test cases from problem
    test_cases = [
        (16, 2, 64, "Test 1"),
        (10, 2, 40, "Test 2"),
        (99, 3, 792, "Test 3"),
        (0b0001, 3, 0b1000, "Test 4"),
        (0b0101, 3, 0b101000, "Test 5"),
        (0b11101, 3, 0b11101000, "Test 6"),
        (0, 0, 0, "Zero input, zero rotation"),
        (0xFFFFFFFF, 1, 0xFFFFFFFE, "Max value, rotate 1"),
        (0x12345678, 16, 0x56781234, "Rotate 16 bits"),
        (0xAAAAAAAA, 4, 0xAAAAAAAA, "Pattern match"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (num_in, d_in, expected, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc}")
        cocotb.log.info(f"  Input: num_in=0x{num_in:08X}, d_in={d_in}, Expected: 0x{expected:08X}")
        
        try:
            # Apply inputs
            dut.num_in.value = num_in & ((1 << DATA_WIDTH) - 1)
            dut.d_in.value = d_in & ((1 << D_WIDTH) - 1)
            
            # Assert start pulse
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Wait for completion
            await wait_for_done(dut)
            
            # Read result
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result signal undefined")
            
            result = int(dut.result.value)
            
            # Compare
            if result != expected:
                raise TestFailure(f"Expected 0x{expected:08X}, got 0x{result:08X}")
            
            passed += 1
            cocotb.log.info(f"  ✓ Got: 0x{result:08X}")
            
        except TestFailure as e:
            cocotb.log.error(f"  ✗ FAIL: {e}")
            failed += 1
    
    # Additional random tests
    cocotb.log.info("Running random tests...")
    for i in range(20):
        num_in = random.randint(0, (1 << DATA_WIDTH) - 1)
        d_in = random.randint(0, (1 << D_WIDTH) - 1)
        expected = left_rotate(num_in, d_in, DATA_WIDTH)
        
        try:
            dut.num_in.value = num_in
            dut.d_in.value = d_in
            
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            await wait_for_done(dut)
            
            result = int(dut.result.value)
            if result != expected:
                raise TestFailure(f"Random {i}: Expected 0x{expected:08X}, got 0x{result:08X}")
            
            passed += 1
        except TestFailure as e:
            cocotb.log.error(f"Random {i}: {e}")
            failed += 1
    
    cocotb.log.info(f"\nResults: {passed} passed, {failed} failed")
    
    if failed:
        raise TestFailure(f"{failed} tests failed")