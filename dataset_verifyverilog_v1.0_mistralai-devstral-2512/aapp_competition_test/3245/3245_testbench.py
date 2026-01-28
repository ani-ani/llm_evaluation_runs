import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

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

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_shell_history(dut):
    # Setup clock
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    
    # Reset
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    if has_signal(dut, 'char_valid'): dut.char_valid.value = 0
    if has_signal(dut, 'char_done'): dut.char_done.value = 0
    dut.char_in.value = 0
    
    for _ in range(5):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    # Test cases derived from problem description
    test_cases = [
        {
            "name": "Sample 1",
            "input_lines": [
                "python",
                "p^ main.py",
                "^ -n 10"
            ],
            "expected_lines": [
                "python",
                "python main.py",
                "python main.py -n 10"
            ]
        },
        {
            "name": "Sample 2",
            "input_lines": [
                "python",
                "java",
                "^",
                "^^^",
                "^^^"
            ],
            "expected_lines": [
                "python",
                "java",
                "java",
                "python",
                "java"
            ]
        }
    ]

    for tc in test_cases:
        cocotb.log.info(f"Running test: {tc['name']}")
        
        for line_idx, line_str in enumerate(tc['input_lines']):
            # Start new command
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Process characters
            for char in line_str:
                dut.char_in.value = ord(char)
                dut.char_valid.value = 1
                await RisingEdge(dut.clk)
                dut.char_valid.value = 0
                # Allow some cycles for processing if sequential
                # In this simulation, we assume input is consumed immediately or via handshake
                # If the DUT has 'ready' signal, we'd wait here. 
                # Assuming simple input processing for now.
                
            # End of line
            dut.char_done.value = 1
            await RisingEdge(dut.clk)
            dut.char_done.value = 0
            
            # Read output
            output_chars = []
            cycles_spent = 0
            max_cycles = 1000  # Safety timeout
            
            while cycles_spent < max_cycles:
                await RisingEdge(dut.clk)
                cycles_spent += 1
                
                if has_signal(dut, 'result_valid') and int(dut.result_valid.value) == 1:
                    if has_signal(dut, 'result_char'):
                        char_code = int(dut.result_char.value)
                        output_chars.append(chr(char_code))
                
                if has_signal(dut, 'result_done') and int(dut.result_done.value) == 1:
                    break
            
            output_str = "".join(output_chars)
            expected_str = tc['expected_lines'][line_idx]
            
            if output_str != expected_str:
                raise TestFailure(f"Line {line_idx+1} mismatch. Expected '{expected_str}', got '{output_str}'")
            
            cocotb.log.info(f"  Line {line_idx+1}: '{line_str}' -> '{output_str}' (OK)")

    cocotb.log.info("All tests passed!")