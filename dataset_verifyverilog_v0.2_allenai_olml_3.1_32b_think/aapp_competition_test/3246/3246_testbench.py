import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer, FallingEdge
from cocotb.result import TestFailure, TestSuccess

def char_to_hex(c):
    """Convert ASCII char to hex value"""
    return ord(c)

def string_to_bytes(s, max_len=16):
    """Convert string to byte array, padded with 0xFF"""
    arr = [0xFF] * max_len
    for i, c in enumerate(s[:max_len]):
        arr[i] = ord(c)
    return arr

def dict_to_bytes(dict_words, max_words=8, max_len=8):
    """Convert dictionary to 2D byte array"""
    arr = [[0xFF]*max_len for _ in range(max_words)]
    for i, word in enumerate(dict_words[:max_words]):
        for j, c in enumerate(word[:max_len]):
            arr[i][j] = ord(c)
    return arr

@cocotb.test()
async def test_decipher_unique(dut):
    """Test case 1: Unique deciphering"""
    # Setup
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Load input: "tihssnetnceemkaesprfecetsesne" (16 chars max, we'll use subset)
    # Actually let's use: "tihssnetncee" (12 chars) for makes perfect sense
    # But keep it simple: use "tihss" (5 chars) + dictionary
    input_str = "tihss"
    input_bytes = string_to_bytes(input_str)
    dut.input_length.value = len(input_str)
    
    # Load dictionary: ["this", "ss"] 
    dict_words = ["this", "ss"]
    dict_arr = dict_to_bytes(dict_words)
    dut.dict_size.value = len(dict_words)
    
    # Feed dictionary
    for i in range(8):
        for j in range(8):
            dut.dict_word[i][j].value = dict_arr[i][j]
    
    # Feed input string character by character
    for i in range(len(input_str)):
        dut.char_in.value = input_bytes[i]
        await RisingEdge(dut.clk)
    
    # Start processing
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for completion (with timeout)
    timeout = 200
    for _ in range(timeout):
        if dut.done.value:
            break
        await RisingEdge(dut.clk)
    
    # Check result
    if not dut.done.value:
        raise TestFailure(f"Timeout! Did not complete in {timeout} cycles")
    
    if dut.status.value != 1:
        raise TestFailure(f"Expected unique (status=1), got {dut.status.value}")
    
    # Read result string
    result_chars = []
    for i in range(32):
        val = int(dut.result[i].value)
        if val != 0xFF and val != 0:
            result_chars.append(chr(val))
        elif val == 0 and len(result_chars) > 0:
            break
    result_str = ''.join(result_chars)
    
    expected = "this ss"  # Our simplified test
    if result_str != expected:
        raise TestFailure(f"Expected '{expected}', got '{result_str}'")
    
    print(f"Test 1 PASSED: '{result_str}'")

@cocotb.test()
async def test_decipher_impossible(dut):
    """Test case 2: Impossible deciphering"""
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Input: "abc" (not in dictionary)
    input_str = "abc"
    dut.input_length.value = len(input_str)
    input_bytes = string_to_bytes(input_str)
    
    # Dictionary: ["def", "xyz"]
    dict_words = ["def", "xyz"]
    dict_arr = dict_to_bytes(dict_words)
    dut.dict_size.value = len(dict_words)
    
    for i in range(8):
        for j in range(8):
            dut.dict_word[i][j].value = dict_arr[i][j]
    
    for i in range(len(input_str)):
        dut.char_in.value = input_bytes[i]
        await RisingEdge(dut.clk)
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 200
    for _ in range(timeout):
        if dut.done.value:
            break
        await RisingEdge(dut.clk)
    
    if not dut.done.value:
        raise TestFailure(f"Timeout")
    
    if dut.status.value != 2:
        raise TestFailure(f"Expected impossible (status=2), got {dut.status.value}")
    
    print("Test 2 PASSED: correctly detected impossible")

@cocotb.test()
async def test_decipher_ambiguous(dut):
    """Test case 3: Ambiguous deciphering"""
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Input: "ab" which could be "ab" or "a" + "b" (if both in dict)
    input_str = "ab"
    dut.input_length.value = len(input_str)
    input_bytes = string_to_bytes(input_str)
    
    # Dictionary: ["ab", "a", "b"] - multiple ways
    dict_words = ["ab", "a", "b"]
    dict_arr = dict_to_bytes(dict_words)
    dut.dict_size.value = len(dict_words)
    
    for i in range(8):
        for j in range(8):
            dut.dict_word[i][j].value = dict_arr[i][j]
    
    for i in range(len(input_str)):
        dut.char_in.value = input_bytes[i]
        await RisingEdge(dut.clk)
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 200
    for _ in range(timeout):
        if dut.done.value:
            break
        await RisingEdge(dut.clk)
    
    if not dut.done.value:
        raise TestFailure(f"Timeout")
    
    if dut.status.value != 3:
        raise TestFailure(f"Expected ambiguous (status=3), got {dut.status.value}")
    
    print("Test 3 PASSED: correctly detected ambiguous")

@cocotb.test()
async def test_decipher_edge_short(dut):
    """Test case 4: Single character word"""
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    input_str = "a"
    dut.input_length.value = 1
    input_bytes = string_to_bytes(input_str)
    
    dict_words = ["a"]
    dict_arr = dict_to_bytes(dict_words)
    dut.dict_size.value = 1
    
    for i in range(8):
        for j in range(8):
            dut.dict_word[i][j].value = dict_arr[i][j]
    
    dut.char_in.value = input_bytes[0]
    await RisingEdge(dut.clk)
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 200
    for _ in range(timeout):
        if dut.done.value:
            break
        await RisingEdge(dut.clk)
    
    if not dut.done.value:
        raise TestFailure(f"Timeout")
    
    if dut.status.value != 1:
        raise TestFailure(f"Expected unique, got {dut.status.value}")
    
    # Read result
    result_chars = []
    for i in range(32):
        val = int(dut.result[i].value)
        if val != 0xFF and val != 0:
            result_chars.append(chr(val))
    result_str = ''.join(result_chars)
    
    if result_str != "a":
        raise TestFailure(f"Expected 'a', got '{result_str}'")
    
    print("Test 4 PASSED: short word handled")

@cocotb.test()
async def test_decipher_shuffled_middle(dut):
    """Test case 5: Word with shuffled middle letters"""
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Input: "tihss" = "this" + "ss" (first/last fixed)
    input_str = "tihss"
    dut.input_length.value = 5
    input_bytes = string_to_bytes(input_str)
    
    # Dictionary: ["this", "ss"]
    dict_words = ["this", "ss"]
    dict_arr = dict_to_bytes(dict_words)
    dut.dict_size.value = 2
    
    for i in range(8):
        for j in range(8):
            dut.dict_word[i][j].value = dict_arr[i][j]
    
    for i in range(5):
        dut.char_in.value = input_bytes[i]
        await RisingEdge(dut.clk)
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 200
    for _ in range(timeout):
        if dut.done.value:
            break
        await RisingEdge(dut.clk)
    
    if not dut.done.value:
        raise TestFailure(f"Timeout")
    
    if dut.status.value != 1:
        raise TestFailure(f"Expected unique, got {dut.status.value}")
    
    # Read and verify result
    result_chars = []
    for i in range(32):
        val = int(dut.result[i].value)
        if val != 0xFF and val != 0:
            result_chars.append(chr(val))
    result_str = ''.join(result_chars)
    
    if result_str != "this ss":
        raise TestFailure(f"Expected 'this ss', got '{result_str}'")
    
    print("Test 5 PASSED: shuffled middle letters handled")

print("
=== Summary ===")
print("All 5 test cases designed for scaled-down text decipher module")
print("Tests verify: unique, impossible, ambiguous, edge cases, shuffled letters")
print("
Note: Actual module implementation requires:")
print("- Fixed-point format: Not needed (integer only)")
print("- State machine: IDLE, LOAD, PROCESS, BUILD, DONE")
print("- Word matching: first/last + sorted middle comparison")
print("- DP array for path counting and reconstruction")