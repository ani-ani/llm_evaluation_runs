import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

# ============================================================================
# MANDATORY HELPER FUNCTIONS
# ============================================================================

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

def to_signed(val, bits):
    if val >= (1 << (bits - 1)):
        return val - (1 << bits)
    return val

def from_signed(val, bits):
    if val < 0:
        return val + (1 << bits)
    return val

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

# ============================================================================
# TESTBENCH
# ============================================================================

def generate_expected_output(A, B):
    expected = "100 100\n"
    for i in range(100):
        row = []
        for j in range(100):
            if i < 50:
                if i % 2 == 1 and j % 2 == 1:
                    idx = ((i - 1) // 2) * 50 + ((j - 1) // 2)
                    if idx < (B - 1):
                        row.append('#')
                    else:
                        row.append('.')
                else:
                    row.append('.')
            else:
                if i >= 51 and i <= 97 and i % 2 == 1 and j % 2 == 1:
                    idx = ((i - 51) // 2) * 50 + ((j - 1) // 2)
                    if idx < (A - 1):
                        row.append('.')
                    else:
                        row.append('#')
                else:
                    row.append('#')
        expected += ''.join(row) + '\n'
    return expected

@cocotb.test(timeout_time=20000, timeout_unit="ms")
async def test_grid_generator(dut):
    """Test the grid generator for multiple test cases"""
    
    # Define test cases: (A, B)
    test_cases = [
        (2, 3),
        (7, 8),
        (1, 1),
        (3, 14),
        (209, 499),
        (218, 93),
        (276, 36),
        (484, 451),
        (111, 28),
        (1, 500),
        (123, 456),
        (499, 97),
        (135, 5),
        (233, 233),
        (101, 102),
        (60, 57),
        (100, 2),
        (3, 4),
        (8, 11),
        (100, 8),
        (500, 500),
        (500, 2),
        (500, 499),
        (480, 499),
        (1, 50),
        (100, 2),
        (2, 150),
        (200, 1),
        (500, 498),
        (497, 500),
        (495, 499),
        (1, 20),
        (15, 2),
        (3, 5),
        (4, 4),
        (4, 7),
        (125, 345),
        (20, 98),
        (230, 225),
        (365, 44),
        (473, 70),
        (193, 449),
        (274, 3),
        (204, 323)
    ]
    
    # Setup clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.A.value = 0
    dut.B.value = 0
    await Timer(100, units="ns")
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    passed = 0
    failed = 0
    
    for idx, (A, B) in enumerate(test_cases):
        dut._log.info(f"Test {idx+1}: A={A}, B={B}")
        
        # Start the module
        dut.A.value = A
        dut.B.value = B
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Collect output characters
        output_chars = []
        
        # We know the expected length: 10108 characters (8 header + 100*101 grid)
        # We'll collect until done is high and valid_out is low
        # But we know exactly how many characters to expect, so we can count
        
        for _ in range(10108):  # 8 header + 100 rows * (100 chars + newline) = 8 + 100*101 = 10108
            await RisingEdge(dut.clk)
            if is_value_defined(dut.valid_out.value) and int(dut.valid_out.value) == 1:
                char = chr(int(dut.char_out.value))
                output_chars.append(char)
        
        output_str = ''.join(output_chars)
        
        # Generate expected output
        expected_str = generate_expected_output(A, B)
        
        if output_str == expected_str:
            dut._log.info(f"  PASS: Output matches expected")
            passed += 1
        else:
            dut._log.error(f"  FAIL: Output mismatch")
            dut._log.error(f"  Expected length: {len(expected_str)}, Got: {len(output_str)}")
            # Log first difference
            for i, (e, o) in enumerate(zip(expected_str, output_str)):
                if e != o:
                    dut._log.error(f"  First difference at position {i}: expected {repr(e)}, got {repr(o)}")
                    break
            failed += 1
    
    # Summary
    dut._log.info(f"\nTest Summary: {passed} passed, {failed} failed out of {len(test_cases)}")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")
