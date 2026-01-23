import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer, FallingEdge
from cocotb.result import TestFailure

def char_to_ascii(c):
    """Convert character to ASCII byte"""
    return ord(c)

def is_vowel(c):
    """Check if character is a vowel"""
    return c.lower() in 'aeiou'

@cocotb.test()
async def test_remove_vowels(dut):
    """Test remove_vowels module with various test cases"""
    
    # Create clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.char_in.value = 0
    dut.length.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    async def process_string(input_str):
        """Process a string through the DUT"""
        length = len(input_str)
        dut.length.value = length
        
        # Collect output
        output_chars = []
        
        # Start processing
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Feed characters and collect outputs
        char_idx = 0
        output_idx = 0
        timeout = 50
        cycles = 0
        
        while cycles < timeout:
            await RisingEdge(dut.clk)
            cycles += 1
            
            # Feed next character if available
            if char_idx < length:
                dut.char_in.value = char_to_ascii(input_str[char_idx])
                char_idx += 1
            else:
                dut.char_in.value = 0
            
            # Check outputs
            if dut.out_valid.value:
                output_chars.append(chr(int(dut.char_out.value)))
                output_idx += 1
            
            # Check if done
            if dut.done.value:
                break
        
        return ''.join(output_chars)
    
    # Test cases
    test_cases = [
        ('', ''),
        ('abcdef
ghijklm', 'bcdf
ghjklm'),
        ('fedcba', 'fdcb'),
        ('eeeee', ''),
        ('acBAA', 'cB'),
        ('EcBOO', 'cB'),
        ('ybcd', 'ybcd'),
    ]
    
    passed = 0
    total = len(test_cases)
    
    for input_str, expected in test_cases:
        result = await process_string(input_str)
        if result == expected:
            passed += 1
            dut._log.info(f"PASS: '{input_str}' -> '{result}' (expected '{expected}')")
        else:
            dut._log.error(f"FAIL: '{input_str}' -> '{result}' (expected '{expected}')")
    
    print(f"
{passed}/{total} tests passed")
    
    if passed < total:
        raise TestFailure(f"Only {passed}/{total} tests passed")
