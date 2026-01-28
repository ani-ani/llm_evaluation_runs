import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Helpers
def is_value_defined(v):
    try:
        int(v)
        return True
    except ValueError:
        return False

def safe_int(v, default=0):
    try:
        return int(v)
    except ValueError:
        return default

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_remove_vowels(dut):
    # Check for required signals
    if not all([has_signal(dut, 'clk'), has_signal(dut, 'rst_n'), has_signal(dut, 'start'),
                has_signal(dut, 'char_in'), has_signal(dut, 'valid_in'), has_signal(dut, 'done_in'),
                has_signal(dut, 'char_out'), has_signal(dut, 'valid_out'), has_signal(dut, 'done'),
                has_signal(dut, 'busy')]):
        raise TestFailure("Missing required signals")
    
    # Setup clock
    CLK_NS = 10
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    
    # Reset DUT
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.valid_in.value = 0
    dut.done_in.value = 0
    dut.char_in.value = 0
    for _ in range(2):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases
    test_cases = [
        ("", "", "empty string"),
        ("abcdef\nghijklm", "bcdf\nghjklm", "mixed with newline"),
        ("abcdef", "bcdf", "all lowercase"),
        ("aaaaa", "", "all vowels"),
        ("aaBAA", "B", "mixed case vowels"),
        ("zbcd", "zbcd", "no vowels"),
        ("EEEEE", "", "all uppercase vowels"),
        ("EcBOO", "cB", "mixed case with vowels"),
        ("ybcd", "ybcd", "no vowels case"),
        ("fedcba", "fdcb", "reverse order"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (input_str, expected_output, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc} - Input: '{input_str}' Expected: '{expected_output}'")
        
        try:
            # Start processing
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Check busy signal goes high
            if int(dut.busy.value) != 1:
                raise TestFailure(f"busy signal not high after start")
            
            # Feed input characters serially
            for char in input_str:
                # Wait for ready if needed, but simplified: assume we can write immediately
                # In real hardware, might need input buffer check. We'll assume enough buffer.
                dut.char_in.value = ord(char)
                dut.valid_in.value = 1
                await RisingEdge(dut.clk)
                dut.valid_in.value = 0
                
                # Small delay to allow processing
                await Timer(CLK_NS//2, units='ns')
            
            # Send done_in signal
            dut.done_in.value = 1
            await RisingEdge(dut.clk)
            dut.done_in.value = 0
            
            # Collect output characters
            output_chars = []
            max_cycles = 50  # Sufficient for 16 chars
            
            for _ in range(max_cycles):
                await RisingEdge(dut.clk)
                
                # Check if output valid
                if is_value_defined(dut.valid_out.value) and int(dut.valid_out.value) == 1:
                    if is_value_defined(dut.char_out.value):
                        c = int(dut.char_out.value)
                        # Handle printable range only
                        if 32 <= c <= 126 or c == 10:  # 10 is newline
                            output_chars.append(chr(c))
                        else:
                            output_chars.append('?')
                    else:
                        raise TestFailure("char_out undefined when valid_out high")
                
                # Check done signal
                if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                    # Done pulse detected
                    break
                
                # Check if busy dropped without done (error)
                if int(dut.busy.value) == 0 and int(dut.done.value) == 0:
                    # Might be waiting, continue
                    pass
            
            # Verify results
            result_str = "".join(output_chars)
            if result_str != expected_output:
                raise TestFailure(f"Expected '{expected_output}', got '{result_str}'")
            
            # Verify done signal was high in last cycle
            if not (is_value_defined(dut.done.value) and int(dut.done.value) == 1):
                raise TestFailure("Done signal not asserted")
            
            passed += 1
            cocotb.log.info(f"PASS: Output '{result_str}'")
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL Test {i+1}: {e}")
            failed += 1
        
        # Reset for next test
        dut.rst_n.value = 0
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
    
    if failed > 0:
        raise TestFailure(f"{failed} test(s) failed")
