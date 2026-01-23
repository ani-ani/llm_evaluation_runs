import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock

# Helper to convert string to ASCII list
def str_to_ascii(s):
    return [ord(c) for c in s]

# Helper to check result_is_count logic
def is_count_mode(txt):
    has_space = ' ' in txt
    has_comma = ',' in txt
    return not (has_space or has_comma)

def count_odd_lower(txt):
    count = 0
    for c in txt:
        if 'a' <= c <= 'z':
            if (ord(c) - ord('a')) % 2 == 1:
                count += 1
    return count

@cocotb.test()
async def test_split_words(dut):
    """Test split_words module with various string inputs."""
    # Setup Clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.char_in.value = 0
    dut.str_len.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test Cases
    test_cases = [
        ("Hello world!", "split_space"),
        ("Hello,world!", "split_comma"),
        ("Hello world,!", "split_space"),
        ("Hello,Hello,world !", "split_space"),
        ("abcdef", "count"),
        ("aaabb", "count"),
        ("aaaBb", "count"),
        ("", "count"),
        ("a,b,c", "split_comma"),
    ]
    
    passed = 0
    total = len(test_cases)
    
    for txt, expected_type in test_cases:
        dut._log.info(f"Testing: '{txt}'")
        
        # Feed string char by char
        dut.start.value = 1
        dut.str_len.value = len(txt)
        await RisingEdge(dut.clk)
        dut.start.value = 0 # Pulse start
        
        # Feed characters
        ascii_vals = str_to_ascii(txt)
        for i, val in enumerate(ascii_vals):
            dut.char_in.value = val
            await RisingEdge(dut.clk)
        
        # Pad with zeros if len < 16 (just for safety in this test, though spec says str_len controls it)
        for _ in range(len(txt), 16):
            dut.char_in.value = 0
            await RisingEdge(dut.clk)
            
        # Wait for DONE
        timeout = 0
        while not dut.done.value and timeout < 20:
            await RisingEdge(dut.clk)
            timeout += 1
            
        if not dut.done.value:
            dut._log.error(f"Timeout for '{txt}'")
            continue
            
        # Verify
        if expected_type == "count":
            if not dut.result_is_count.value:
                dut._log.error(f"Expected COUNT mode for '{txt}' but got LIST")
            elif dut.result_count.value != count_odd_lower(txt):
                dut._log.error(f"Count mismatch: expected {count_odd_lower(txt)}, got {dut.result_count.value}")
            else:
                dut._log.info(f"PASS: '{txt}' -> Count {dut.result_count.value}")
                passed += 1
        else:
            if dut.result_is_count.value:
                dut._log.error(f"Expected LIST mode for '{txt}' but got COUNT")
            else:
                # Parse expected words
                delimiter = ' ' if ' ' in txt else ','
                expected_words = txt.split(delimiter)
                # Check outputs
                matches = True
                for i in range(4):
                    if i < len(expected_words):
                        exp = expected_words[i]
                        # Read 128-bit word as bytes
                        word_val = 0
                        if i == 0: word_val = dut.dut.word0.value
                        elif i == 1: word_val = dut.dut.word1.value
                        elif i == 2: word_val = dut.dut.word2.value
                        elif i == 3: word_val = dut.dut.word3.value
                        
                        # Convert word_val to bytes (Little Endian assumption usually in Python/Cocotb for easy indexing)
                        # Actually Verilog arrays are usually packed. Let's assume byte 0 is char 0.
                        # If word0 is 128 bits [127:0], index 0 is bits [7:0].
                        
                        # Extract bytes from the signal value (which is an integer)
                        extracted_chars = []
                        for b in range(len(exp)):
                            byte = (word_val >> (b * 8)) & 0xFF
                            extracted_chars.append(chr(byte))
                        
                        extracted_str = "".join(extracted_chars)
                        
                        if extracted_str != exp:
                            matches = False
                            dut._log.error(f"Word {i} mismatch: expected '{exp}', got '{extracted_str}'")
                
                if matches:
                    dut._log.info(f"PASS: '{txt}' -> Split {expected_words}")
                    passed += 1
                    
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)

    dut._log.info(f"
Summary: {passed}/{total} tests passed")
    assert passed == total
