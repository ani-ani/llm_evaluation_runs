import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

# Helper functions
def is_value_defined(v):
    try:
        int(v)
        return True
    except ValueError:
        return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def wait_for_done(dut, max_cycles=2000):
    return RisingEdge(dut.done)  # Cocotb can wait for the signal directly

def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(cycles):
        yield RisingEdge(dut.clk)
    dut.rst_n.value = 1
    yield RisingEdge(dut.clk)

def pack_string(s, width=16, char_width=5):
    """Pack a string into a 16-bit integer (5 bits per char)"""
    val = 0
    for i, char in enumerate(s):
        if i >= width: break
        ascii_val = ord(char) - 65  # 'A' = 0
        val |= (ascii_val & ((1 << char_width) - 1)) << (i * char_width)
    return val

@cocotb.test(timeout_time=2000, timeout_unit="ms")
async def test_loda(dut):
    # Setup Clock
    clk = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clk.start())
    
    await reset_dut(dut)
    
    # Test Cases
    test_cases = [
        {
            "strings": ["A", "B", "AA", "BBB", "AAA"],
            "expected": 3
        },
        {
            "strings": ["A", "ABA", "BBB", "ABABA", "AAAAAB"],
            "expected": 3
        },
        {
            "strings": ["A", "B", "A", "B", "A", "B"],
            "expected": 3
        }
    ]
    
    for idx, tc in enumerate(test_cases):
        cocotb.log.info(f"Running Test Case {idx + 1}: {tc['strings']}")
        
        # Prepare inputs
        strings = tc['strings']
        n = len(strings)
        
        # Clear inputs first (optional but good practice)
        for i in range(16):
            getattr(dut, f'strings_in_{i}').value = 0
            getattr(dut, f'valid_inputs_{i}').value = 0
            
        # Set inputs
        for i, s in enumerate(strings):
            packed = pack_string(s)
            getattr(dut, f'strings_in_{i}').value = packed
            getattr(dut, f'valid_inputs_{i}').value = 1
            
        # Start
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        done_countdown = 0
        max_wait = 500
        while not int(dut.done.value):
            await RisingEdge(dut.clk)
            done_countdown += 1
            if done_countdown > max_wait:
                raise TestFailure(f"Timeout waiting for done in test case {idx+1}")
                
        # Check result
        if not is_value_defined(dut.result.value):
            raise TestFailure("Result signal is undefined")
            
        result = int(dut.result.value)
        expected = tc['expected']
        
        if result != expected:
            raise TestFailure(f"Test Case {idx+1} Failed: Expected {expected}, Got {result}")
            
        # Wait one cycle before next test to ensure stability
        await RisingEdge(dut.clk)

    cocotb.log.info("All tests passed!")