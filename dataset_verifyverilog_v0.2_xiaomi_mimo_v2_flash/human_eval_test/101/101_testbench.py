import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
import random

@cocotb.test()
async def test_words_string_splitter(dut):
    """Test the words_string_splitter module with various test cases"""
    
    # Setup clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset sequence
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.valid_in.value = 0
    dut.char_in.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    async def process_string(input_str):
        """Helper to process a string and get result"""
        # Start processing
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Stream in characters
        for char in input_str:
            dut.char_in.value = ord(char)
            dut.valid_in.value = 1
            await RisingEdge(dut.clk)
            
        # Send invalid character to mark end
        dut.valid_in.value = 0
        dut.char_in.value = 0
        
        # Wait for done
        timeout = 100
        for _ in range(timeout):
            if dut.done.value:
                break
            await RisingEdge(dut.clk)
        
        # Read results
        word_count = int(dut.word_count.value)
        words = []
        for i in range(word_count):
            word = ""
            for j in range(8):
                char_code = int(dut.words.value[i][j*8 +: 8])
                if char_code != 0 and char_code >= 32:  # printable ASCII
                    word += chr(char_code)
            words.append(word)
            
        return words, word_count
    
    # Test Case 1: "Hi, my name is John"
    dut._log.info("Test 1: Hi, my name is John")
    result, count = await process_string("Hi, my name is John")
    expected = ["Hi", "my", "name", "is", "John"]
    assert count == len(expected), f"Expected {len(expected)} words, got {count}"
    for i, exp in enumerate(expected):
        assert result[i] == exp, f"Word {i}: expected '{exp}', got '{result[i]}'"
    
    # Test Case 2: "One, two, three, four, five, six"
    dut._log.info("Test 2: One, two, three, four, five, six")
    result, count = await process_string("One, two, three, four, five, six")
    expected = ["One", "two", "three", "four", "five", "six"]
    assert count == len(expected), f"Expected {len(expected)} words, got {count}"
    for i, exp in enumerate(expected):
        assert result[i] == exp, f"Word {i}: expected '{exp}', got '{result[i]}'"
    
    # Test Case 3: "Hi, my name"
    dut._log.info("Test 3: Hi, my name")
    result, count = await process_string("Hi, my name")
    expected = ["Hi", "my", "name"]
    assert count == len(expected), f"Expected {len(expected)} words, got {count}"
    for i, exp in enumerate(expected):
        assert result[i] == exp, f"Word {i}: expected '{exp}', got '{result[i]}'"
    
    # Test Case 4: "One,, two, three, four, five, six,"
    dut._log.info("Test 4: One,, two, three, four, five, six,")
    result, count = await process_string("One,, two, three, four, five, six,")
    expected = ["One", "two", "three", "four", "five", "six"]
    assert count == len(expected), f"Expected {len(expected)} words, got {count}"
    for i, exp in enumerate(expected):
        assert result[i] == exp, f"Word {i}: expected '{exp}', got '{result[i]}'"
    
    # Test Case 5: Empty string
    dut._log.info("Test 5: (empty)")
    result, count = await process_string("")
    assert count == 0, f"Expected 0 words for empty string, got {count}"
    
    # Test Case 6: "ahmed     , gamal"
    dut._log.info("Test 6: ahmed     , gamal")
    result, count = await process_string("ahmed     , gamal")
    expected = ["ahmed", "gamal"]
    assert count == len(expected), f"Expected {len(expected)} words, got {count}"
    for i, exp in enumerate(expected):
        assert result[i] == exp, f"Word {i}: expected '{exp}', got '{result[i]}'"
    
    print(f"All tests passed!")
