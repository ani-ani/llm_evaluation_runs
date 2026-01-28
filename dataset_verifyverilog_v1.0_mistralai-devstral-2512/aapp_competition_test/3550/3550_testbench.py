import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

# Constants
CLK_NS = 10
MAX_CYCLES = 10000

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

async def reset_dut(dut, cycles=2):
    if has_signal(dut, 'rst_n'):
        dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    if has_signal(dut, 'char_valid'):
        dut.char_valid.value = 0
    if has_signal(dut, 'line_end'):
        dut.line_end.value = 0
    
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    
    if has_signal(dut, 'rst_n'):
        dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def feed_line(dut, line_str):
    """
    Feeds a line character by character to the DUT.
    Assumes dut.char_in, dut.char_valid, dut.line_end exist.
    """
    # Strip newline if present in the string (usually python string)
    chars = line_str.strip('\n')
    
    for i, char in enumerate(chars):
        dut.char_in.value = ord(char)
        dut.char_valid.value = 1
        await RisingEdge(dut.clk)
        dut.char_valid.value = 0
        # Small delay or ready signal check could go here
        await Timer(1, units='ns') # Minimal propagation
    
    # Send line end
    dut.line_end.value = 1
    await RisingEdge(dut.clk)
    dut.line_end.value = 0
    await RisingEdge(dut.clk) # Give cycle for processing start

def extract_output(dut):
    if is_value_defined(dut.char_out.value):
        return chr(int(dut.char_out.value))
    return ''

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_nenscript(dut):
    # Check basic signals
    if not has_signal(dut, 'clk'):
        cocotb.log.error("DUT missing 'clk' signal")
        return
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    await reset_dut(dut)
    
    # Test Cases
    # Case 1: Basic variable and print
    input_1 = "var a = Gon;\nprint a;\nend.\n"
    expected_1 = "Gon\n"
    
    # Case 2: Nested template
    input_2 = "var a = Gon;\nvar c = `My name is ${a}`;\nprint c;\nend.\n"
    expected_2 = "My name is Gon\n"
    
    # Note: In the provided python example, the inputs use quotes like "Gon" and backticks.
    # However, looking at the problem description:
    # "var a = "Gon";" -> String literal.
    # "var b = a;" -> Variable reference.
    # "var c = `My name is ${a}`;" -> Template literal.
    # My simulator implementation needs to handle the exact ASCII characters.
    
    # Let's use the examples from the prompt exactly.
    inputs = [
        'var a = "Gon";\nvar b = a;\nvar c = `My name is ${a}`;\nprint c;\nprint `My name is ${b}`;\nend.\n',
        'var one = "1";\nvar two = "2";\nvar three = "3";\nprint `${one} + ${two} = ${three}`;\nprint `1${`2${three}2`}1`;\nend.\n'
    ]
    
    outputs = [
        "My name is Gon\nMy name is Gon\n",
        "1 + 2 = 3\n12321\n"
    ]
    
    total_passed = 0
    total_failed = 0
    
    for test_idx, (inp, exp) in enumerate(zip(inputs, outputs)):
        cocotb.log.info(f"Running Test Case {test_idx+1}")
        
        # Clear output capture
        captured_output = ""
        
        # Reset before each test case if needed, or just continuous stream
        # For this FSM, we might need to process line by line.
        # The input string contains multiple lines.
        
        lines = inp.strip().split('\n')
        
        for line in lines:
            if line == "end.":
                line += "\n"
            else:
                line += "\n"
            
            cocotb.log.info(f"Feeding line: {line.strip()}")
            
            # Feed the line
            await feed_line(dut, line)
            
            # Wait for output or done
            # We expect output if the line was 'print ...'
            # If it was a variable declaration, no output.
            
            # Monitor for output characters
            output_done = False
            cycles = 0
            
            # Check if this line generates output
            if line.strip().startswith("print"):
                # Read characters until we assume output is done or line is done
                # The DUT produces char_out_valid pulses
                # We need to wait for valid pulses
                
                line_output = ""
                
                # Wait a bit for processing
                # We'll look for char_out_valid asserted
                # The spec says char_out_valid is 1-cycle pulse
                
                # We expect exactly the characters for this print statement + newline
                # But the expected output 'exp' is the concatenation of ALL prints in the test case.
                
                # To keep it simple, we will read all output until 'done' is asserted for the line
                # or until we match the expected chunk (hard to do dynamically).
                # Better: Run the whole test case input, capture ALL output, compare at end.
                
                pass
        
        # Logic to capture output during the run of 'inp'
        # We need to re-run the input sequence and capture output
        # Since we already ran it above, let's just capture there.
        # Refined loop:
        
    # Re-run logic for capture
    # Because the previous loop was just logging, let's do actual checking.
    
    for test_idx, (inp, exp) in enumerate(zip(inputs, outputs)):
        cocotb.log.info(f"Running Test Case {test_idx+1}")
        
        # Reset DUT to clear state/variables
        await reset_dut(dut, cycles=5)
        
        captured_output = []
        
        lines = inp.strip().split('\n')
        for line in lines:
            if line == "end.":
                line += "\n"
            else:
                line += "\n"
            
            cocotb.log.info(f"Processing: {line.strip()}")
            
            # Feed line characters
            for char in line:
                dut.char_in.value = ord(char)
                dut.char_valid.value = 1
                await RisingEdge(dut.clk)
                dut.char_valid.value = 0
                await RisingEdge(dut.clk) # Wait for char processing
                
                # Check for output
                if has_signal(dut, 'char_out_valid') and is_value_defined(dut.char_out_valid.value):
                    if int(dut.char_out_valid.value) == 1:
                        if is_value_defined(dut.char_out.value):
                            out_char = chr(int(dut.char_out.value))
                            captured_output.append(out_char)
                            cocotb.log.info(f"Output char: '{out_char}' (0x{int(dut.char_out.value):02X})")
            
            # Signal end of line
            dut.line_end.value = 1
            await RisingEdge(dut.clk)
            dut.line_end.value = 0
            
            # Wait for processing of the command (declaration or print)
            # We wait for 'done' signal or a timeout
            # Note: 'done' might indicate the whole line is processed.
            # For print commands, the output should have been generated during processing.
            
            max_wait = 100
            for _ in range(max_wait):
                await RisingEdge(dut.clk)
                if has_signal(dut, 'char_out_valid') and is_value_defined(dut.char_out_valid.value):
                    if int(dut.char_out_valid.value) == 1:
                        if is_value_defined(dut.char_out.value):
                            out_char = chr(int(dut.char_out.value))
                            captured_output.append(out_char)
                            cocotb.log.info(f"Output char (post-line): '{out_char}'")
                
                if has_signal(dut, 'done') and is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                    break
        
        # Convert captured output to string
        result_str = "".join(captured_output)
        
        # Compare
        cocotb.log.info(f"Expected: {repr(exp)}")
        cocotb.log.info(f"Got:      {repr(result_str)}")
        
        if result_str != exp:
            cocotb.log.error(f"Test Case {test_idx+1} Failed!")
            total_failed += 1
        else:
            total_passed += 1
    
    if total_failed > 0:
        raise TestFailure(f"{total_failed} test(s) failed, {total_passed} passed.")
    else:
        cocotb.log.info(f"All {total_passed} tests passed!")
