import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

# Configuration
DATA_WIDTH = 4  # 4 bits per digit (0-9)
DIGIT_COUNT_MAX = 8
CLK_PERIOD_NS = 10
MAX_CYCLES = 1000

def is_value_defined(value):
    try:
        int(value)
        return True
    except ValueError:
        return False

def safe_int(value, default=0):
    try:
        return int(value)
    except ValueError:
        return default

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def clamp_to_width(value, bits):
    max_val = (1 << bits) - 1
    if value < 0:
        return from_signed(max(-((1 << (bits-1))), min((1 << (bits-1)) - 1, value)), bits)
    return min(max_val, max(0, value))

def from_signed(val, bits):
    if val < 0:
        return val + (1 << bits)
    return val

def to_signed(val, bits):
    if val >= (1 << (bits - 1)):
        return val - (1 << bits)
    return val

def pack_number(number_str):
    """Pack digits into 32-bit number (8 digits x 4 bits each)"""
    num = int(number_str)
    digits = [int(d) for d in str(num)]
    packed = 0
    for i, d in enumerate(digits):
        packed |= (d & 0xF) << (i * 4)
    return packed, len(digits)

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    for cycle in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout: done not asserted after {max_cycles} cycles")

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_hill_number_counter(dut):
    """Test hill number counter module"""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test cases: (number_string, expected_is_hill, expected_count_if_hill)
    test_cases = [
        ("10", True, 10),
        ("55", True, 55),
        ("101", False, -1),
        ("1234321", True, 94708),
        ("1000", True, 715),
        ("1", True, 1),
        ("9", True, 9),
        ("12", True, 12),
        ("21", True, 21),
        ("123", True, 123),
        ("132", False, -1),
        ("121", False, -1),
    ]
    
    passed = 0
    failed = 0
    
    for number_str, expected_is_hill, expected_count in test_cases:
        cocotb.log.info(f"Testing: {number_str}")
        
        try:
            # Pack the number
            packed_num, digit_count = pack_number(number_str)
            
            # Assign inputs
            dut.number.value = packed_num
            dut.digit_count.value = digit_count
            
            # Start computation
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Wait for done
            await wait_for_done(dut)
            
            # Read result
            result = int(dut.result.value)
            
            if expected_is_hill:
                if result != expected_count:
                    raise TestFailure(f"Expected {expected_count}, got {result}")
            else:
                if result != 0xFFFFFFFF:  # -1 in 32-bit two's complement
                    raise TestFailure(f"Expected -1, got {result}")
            
            cocotb.log.info(f"  PASS: result = {result}")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    # Summary
    cocotb.log.info(f"{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")
