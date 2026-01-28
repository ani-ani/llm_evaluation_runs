import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

DATA_WIDTH = 8
MAX_INPUT_LEN = 16
MAX_OUTPUT_LEN = 32
CLK_NS = 10
MAX_CYCLES = 500

# Helper functions
def is_value_defined(v):
    try:
        int(v); return True
    except (ValueError, TypeError):
        return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def has_signal(dut, name):
    try:
        getattr(dut, name); return True
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

async def send_string_and_collect(dut, input_str):
    """Send characters one by one and collect output"""
    output = []
    
    # Send input characters
    for i, char in enumerate(input_str):
        dut.char_in.value = ord(char) & 0xFF
        dut.len.value = len(input_str)
        if i == 0:
            dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
    
    # Wait for processing
    await wait_for_done(dut)
    
    # Collect output characters
    max_collect = MAX_OUTPUT_LEN * 2  # Safety multiplier
    for i in range(max_collect):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.valid.value) and int(dut.valid.value) == 1:
            if is_value_defined(dut.char_out.value):
                char_val = int(dut.char_out.value)
                if char_val > 0:
                    output.append(chr(char_val))
    
    return ''.join(output)

@cocotb.test(timeout_time=2000, timeout_unit="ms")
async def test_capital_words_spaces(dut):
    # Check if sequential
    is_seq = has_signal(dut, 'clk')
    
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    else:
        # Combinational simulation
        await Timer(100, units='ns')
    
    test_cases = [
        ("Python", "Python", "Single word, no spaces"),
        ("PythonProgrammingExamples", "Python Programming Examples", "CamelCase with spaces"),
        ("GetReadyToBeCodingFreak", "Get Ready To Be Coding Freak", "Multi-word CamelCase"),
        ("XMLParser", "XML Parser", "Acronym followed by word"),
        ("CamelCaseTest", "Camel Case Test", "Basic test case"),
        ("aBcDeF", "a B c D e F", "Alternating case"),
        ("ABC", "ABC", "All uppercase"),
        ("abc", "abc", "All lowercase"),
        ("a", "a", "Single char lowercase"),
        ("A", "A", "Single char uppercase"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (input_str, expected_output, description) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {description}")
        cocotb.log.info(f"  Input: '{input_str}'")
        cocotb.log.info(f"  Expected: '{expected_output}'")
        
        try:
            if is_seq:
                result = await send_string_and_collect(dut, input_str)
            else:
                # For combinational, we would need a different interface
                # Skip for now as spec is sequential
                cocotb.log.info("  Skipping (combinational not implemented)")
                continue
            
            cocotb.log.info(f"  Got: '{result}'")
            
            if result != expected_output:
                raise TestFailure(f"Mismatch: expected '{expected_output}', got '{result}'")
            
            passed += 1
            cocotb.log.info("  PASS")
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
        
        # Reset between tests
        if is_seq and i < len(test_cases) - 1:
            await reset_dut(dut)
    
    cocotb.log.info(f"\nResults: {passed} passed, {failed} failed")
    
    if failed:
        raise TestFailure(f"{failed} test(s) failed")
