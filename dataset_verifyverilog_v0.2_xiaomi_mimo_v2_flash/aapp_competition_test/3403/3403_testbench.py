import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, Timer
from cocotb.result import TestFailure
import random

def calculate_expected_steps(query, db_words):
    """Calculate expected steps for primitive search algorithm"""
    steps = 0
    for word in db_words:
        # Calculate LCP length
        lcp_len = 0
        for i in range(min(len(query), len(word))):
            if query[i] == word[i]:
                lcp_len += 1
            else:
                break
        steps += 1 + lcp_len
        if query == word:
            break
    return steps

def str_to_bytes(s, max_len=8):
    """Convert string to list of bytes (8 chars fixed)"""
    result = [0] * max_len
    for i, c in enumerate(s[:max_len]):
        result[i] = ord(c)
    return result

def int_to_bytes_list(value, length=8):
    """Convert string to bytes list for Verilog input"""
    return str_to_bytes(value, length)

@cocotb.test()
async def test_primitive_search_basic(dut):
    """Test basic primitive search functionality"""
    # Setup clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.db_word_en.value = 0
    await Timer(50, units="ns")
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Load database: hobotnica, robot, hobi, hobit, robi
    db_words = ["hobotnica", "robot", "hobi", "hobit", "robi"]
    for i, word in enumerate(db_words):
        dut.db_word_en.value = 1
        dut.db_word_index.value = i
        dut.db_word.value = str_to_bytes(word)
        await RisingEdge(dut.clk)
    
    # Load empty words for positions 5-7
    dut.db_word_en.value = 1
    for i in range(5, 8):
        dut.db_word_index.value = i
        dut.db_word.value = str_to_bytes("")
        await RisingEdge(dut.clk)
    
    dut.db_word_en.value = 0
    await RisingEdge(dut.clk)
    
    # Test queries
    test_cases = [
        ("robi", 12),
        ("hobi", 10),
        ("hobit", 16),
        ("rakija", 7)
    ]
    
    passed = 0
    total = len(test_cases)
    
    for query, expected in test_cases:
        # Start computation
        dut.query_word.value = str_to_bytes(query)
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        timeout = 200
        for _ in range(timeout):
            if dut.done.value:
                break
            await RisingEdge(dut.clk)
        
        result = int(dut.result.value)
        if result == expected:
            passed += 1
        else:
            print(f"FAIL: Query '{query}' - Expected {expected}, Got {result}")
    
    print(f"Test 1: {passed}/{total} tests passed")
    if passed != total:
        raise TestFailure(f"Only {passed}/{total} tests passed")

@cocotb.test()
async def test_primitive_search_second_set(dut):
    """Test second database set"""
    # Setup clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.db_word_en.value = 0
    await Timer(50, units="ns")
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Load database
    db_words = ["majmunica", "majmun", "majka", "malina", "malinska", "malo", "maleni", "malesnica"]
    for i, word in enumerate(db_words):
        dut.db_word_en.value = 1
        dut.db_word_index.value = i
        dut.db_word.value = str_to_bytes(word)
        await RisingEdge(dut.clk)
    
    dut.db_word_en.value = 0
    await RisingEdge(dut.clk)
    
    # Test queries
    test_cases = [
        ("krampus", 8),
        ("malnar", 29),
        ("majmun", 14)
    ]
    
    passed = 0
    total = len(test_cases)
    
    for query, expected in test_cases:
        dut.query_word.value = str_to_bytes(query)
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        timeout = 200
        for _ in range(timeout):
            if dut.done.value:
                break
            await RisingEdge(dut.clk)
        
        result = int(dut.result.value)
        if result == expected:
            passed += 1
        else:
            print(f"FAIL: Query '{query}' - Expected {expected}, Got {result}")
    
    print(f"Test 2: {passed}/{total} tests passed")
    if passed != total:
        raise TestFailure(f"Only {passed}/{total} tests passed")

@cocotb.test()
async def test_primitive_search_edge_cases(dut):
    """Test edge cases"""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.db_word_en.value = 0
    await Timer(50, units="ns")
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Database: first match, middle match, last match
    db_words = ["aaaa", "bbbb", "cccc", "dddd", "eeee", "ffff", "gggg", "hhhh"]
    for i, word in enumerate(db_words):
        dut.db_word_en.value = 1
        dut.db_word_index.value = i
        dut.db_word.value = str_to_bytes(word)
        await RisingEdge(dut.clk)
    
    dut.db_word_en.value = 0
    await RisingEdge(dut.clk)
    
    # Test: match at first word
    dut.query_word.value = str_to_bytes("aaaa")
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 100
    for _ in range(timeout):
        if dut.done.value:
            break
        await RisingEdge(dut.clk)
    
    result = int(dut.result.value)
    expected = 1 + 4  # 1 + LCP(4)
    if result != expected:
        raise TestFailure(f"Edge case 1: Expected {expected}, Got {result}")
    
    # Test: no match
    dut.query_word.value = str_to_bytes("xyz")
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(timeout):
        if dut.done.value:
            break
        await RisingEdge(dut.clk)
    
    result = int(dut.result.value)
    expected = 8 * (1 + 0)  # 8 words, each LCP=0
    if result != expected:
        raise TestFailure(f"Edge case 2: Expected {expected}, Got {result}")
    
    print("Test 3: Edge cases passed")

@cocotb.test()
async def test_primitive_search_last_word(dut):
    """Test matching last word in database"""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.db_word_en.value = 0
    await Timer(50, units="ns")
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Database
    db_words = ["word1", "word2", "word3", "word4", "word5", "word6", "word7", "target"]
    for i, word in enumerate(db_words):
        dut.db_word_en.value = 1
        dut.db_word_index.value = i
        dut.db_word.value = str_to_bytes(word)
        await RisingEdge(dut.clk)
    
    dut.db_word_en.value = 0
    await RisingEdge(dut.clk)
    
    # Search for last word
    dut.query_word.value = str_to_bytes("target")
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 100
    for _ in range(timeout):
        if dut.done.value:
            break
        await RisingEdge(dut.clk)
    
    result = int(dut.result.value)
    # Steps: word1(1+0) + word2(1+0) + ... + word7(1+0) + target(1+6) = 7*1 + 7
    expected = 7 * 1 + 7
    if result != expected:
        raise TestFailure(f"Last word match: Expected {expected}, Got {result}")
    
    print("Test 4: Last word match passed")

@cocotb.test()
async def test_primitive_search_partial_prefix(dut):
    """Test with partial prefixes"""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.db_word_en.value = 0
    await Timer(50, units="ns")
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Database with varying prefix lengths
    db_words = ["abcxyz", "abcpqr", "abd", "ac"]
    for i, word in enumerate(db_words):
        dut.db_word_en.value = 1
        dut.db_word_index.value = i
        dut.db_word.value = str_to_bytes(word)
        await RisingEdge(dut.clk)
    
    # Fill rest with empty
    for i in range(4, 8):
        dut.db_word_en.value = 1
        dut.db_word_index.value = i
        dut.db_word.value = str_to_bytes("")
        await RisingEdge(dut.clk)
    
    dut.db_word_en.value = 0
    await RisingEdge(dut.clk)
    
    # Query: abcdef
    # LCPs: 3, 3, 2, 0 (then stop at word 3)
    dut.query_word.value = str_to_bytes("abcdef")
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 100
    for _ in range(timeout):
        if dut.done.value:
            break
        await RisingEdge(dut.clk)
    
    result = int(dut.result.value)
    expected = (1 + 3) + (1 + 3) + (1 + 2)  # abd has LCP=2, no match
    if result != expected:
        raise TestFailure(f"Partial prefix: Expected {expected}, Got {result}")
    
    print("Test 5: Partial prefix passed")