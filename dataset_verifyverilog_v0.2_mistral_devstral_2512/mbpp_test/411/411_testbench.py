import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from cocotb.result import TestFailure

@cocotb.test()
async def test_snake_to_camel(dut):
    """Test snake_case to CamelCase conversion"""
    
    # Setup clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.char_in.value = 0
    dut.char_index.value = 0
    dut.num_chars.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Helper function to convert string and test
    async def convert_and_check(input_str, expected_str):
        dut._log.info(f"Converting '{input_str}' to '{expected_str}'")
        
        # Remove underscores and count chars
        chars_only = input_str.replace('_', '')
        num_chars = len(chars_only)
        
        # Prepare input sequence
        char_list = list(input_str)
        
        # Set num_chars
        dut.num_chars.value = num_chars
        
        # Start the conversion
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Feed characters one by one and collect output
        output_chars = []
        chars_fed = 0
        max_cycles = 20
        cycles = 0
        
        while cycles < max_cycles:
            # Feed input if we have more characters
            if chars_fed < len(char_list):
                dut.char_in.value = ord(char_list[chars_fed])
                dut.char_index.value = chars_fed
                chars_fed += 1
            else:
                dut.char_in.value = 0
                dut.char_index.value = 0
            
            await RisingEdge(dut.clk)
            cycles += 1
            
            # Check if output is valid
            if dut.done.value == 1:
                break
        
        # Collect output characters (they may appear over multiple cycles)
        # Reset and run again to collect outputs properly
        dut.rst_n.value = 0
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
        
        # Feed all input first
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        output_str = ""
        for i, ch in enumerate(char_list):
            dut.char_in.value = ord(ch)
            dut.char_index.value = i
            await RisingEdge(dut.clk)
            
            # Capture output
            if i < num_chars:
                out_char = chr(int(dut.char_out.value))
                output_str += out_char
        
        # Wait for completion
        for _ in range(10):
            await RisingEdge(dut.clk)
            if dut.done.value == 1:
                break
        
        # Check result
        if output_str != expected_str:
            raise TestFailure(f"Expected '{expected_str}' but got '{output_str}'")
        
        dut._log.info(f"Success: '{input_str}' -> '{output_str}'")
    
    # Test cases
    dut._log.info("Running test cases...")
    
    # Test 1: android_tv -> AndroidTv
    await convert_and_check('android_tv', 'AndroidTv')
    
    # Test 2: google_pixel -> GooglePixel  
    await convert_and_check('google_pixel', 'GooglePixel')
    
    # Test 3: apple_watch -> AppleWatch
    await convert_and_check('apple_watch', 'AppleWatch')
    
    # Test 4: simple_case -> SimpleCase
    await convert_and_check('simple_case', 'SimpleCase')
    
    # Test 5: one_word -> OneWord
    await convert_and_check('one_word', 'OneWord')
    
    dut._log.info("All 5/5 tests passed!")
