import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, Timer, ReadOnly
from cocotb.result import TestFailure
import random

# Helper to check if value is defined (not X or Z)
def is_value_defined(value):
    try:
        int(value)
        return True
    except ValueError:
        return False

# Helper to pack string into buffer loading
def load_string(dut, s):
    """Loads a string into the DUT buffer character by character."""
    dut._log.info(f"Loading string: {s}")
    dut.load.value = 1
    dut.start.value = 0
    dut.char_in.value = ord(' ') # Default
    
    chars = list(s)
    if len(chars) > 16:
        dut._log.warning("String too long, truncating to 16 chars")
        chars = chars[:16]
        
    for char in chars:
        dut.char_in.value = ord(char)
        yield RisingEdge(dut.clk)
        
    dut.load.value = 0
    # Wait one cycle to ensure state settles
    yield RisingEdge(dut.clk)

# Helper to extract groups from output stream
def extract_groups(dut):
    """Monitors output stream and returns list of strings."""
    groups = []
    current_group = ""
    
    # We will monitor for a few cycles after start
    # The DUT outputs characters one by one with result_valid high
    
    # We need to know when start is triggered. 
    # This function should be called after start is asserted.
    
    # Let's scan for a reasonable amount of time (e.g., 20 cycles)
    # or until done is high.
    
    # Actually, we will integrate this into the test loop.
    return groups

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_separate_paren_groups(dut):
    """Test the parenthesis group separator module."""
    
    # Setup Clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.load.value = 0
    dut.start.value = 0
    dut.char_in.value = 0
    await Timer(20, units="ns")
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test Cases
    # Format: (input_string, list of expected groups)
    test_cases = [
        ('( ) (( )) (( )( ))', ['()', '(())', '(()())']),
        ('(()()) ((())) () ((())()())', ['(()())', '((()))', '()', '((())()())']),
        ('() (()) ((())) (((())))', ['()', '(())', '((()))', '(((())))']),
        ('(()(())((())))', ['(()(())((())))']),
        ('( ) (( )) (( )( ))', ['()', '(())', '(()())']),
    ]
    
    for i, (input_str, expected_groups) in enumerate(test_cases):
        dut._log.info(f"--- Running Test Case {i+1}: {input_str} ---")
        
        # 1. Load String
        dut.load.value = 1
        dut.start.value = 0
        chars = list(input_str)
        if len(chars) > 16:
            chars = chars[:16]
        
        for char in chars:
            dut.char_in.value = ord(char)
            await RisingEdge(dut.clk)
        
        dut.load.value = 0
        await RisingEdge(dut.clk)
        
        # 2. Start Processing
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # 3. Capture Output Stream
        captured_groups = []
        current_group = ""
        
        # We expect the output stream to be sequential.
        # We need to wait for result_valid to go high.
        # We will wait for 'done' or timeout of reasonable cycles (e.g., 30 cycles)
        
        max_cycles = 30
        cycles_elapsed = 0
        
        while cycles_elapsed < max_cycles:
            await RisingEdge(dut.clk)
            
            # Check if result is valid
            if is_value_defined(dut.result_valid.value) and dut.result_valid.value == 1:
                if is_value_defined(dut.result_char.value):
                    char = chr(int(dut.result_char.value))
                    current_group += char
            else:
                # result_valid is low, meaning we might be between groups or finished a group
                if current_group:
                    captured_groups.append(current_group)
                    current_group = ""
            
            # Check for done signal
            if is_value_defined(dut.done.value) and dut.done.value == 1:
                # Capture any remaining group if logic holds it until next cycle or end
                # Usually done implies stream is finished.
                # Let's check the current state of valid/char one last time or just rely on loop logic
                # But 'done' is often asserted when scan is complete.
                # The loop will break.
                pass
            
            # Break if done is high (and we've processed this cycle's output)
            if is_value_defined(dut.done.value) and dut.done.value == 1:
                # We might need to wait a bit more or just break
                # Let's break after this cycle
                break
                
            cycles_elapsed += 1
            
        # One last check for trailing group
        if current_group:
            captured_groups.append(current_group)
            
        # 4. Verify Results
        dut._log.info(f"Captured groups: {captured_groups}")
        if captured_groups != expected_groups:
            raise TestFailure(f"Test case {i+1} failed! Expected {expected_groups}, got {captured_groups}")
        
        dut._log.info(f"Test case {i+1} passed [OK]")
        
        # Wait for DONE state to reset or cooldown
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)
        
    dut._log.info("All tests passed!")