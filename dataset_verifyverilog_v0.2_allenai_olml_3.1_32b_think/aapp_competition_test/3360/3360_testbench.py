import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer, FallingEdge
from cocotb.result import TestFailure
import random

# Helper to encode rule
# Format: [A-Z] -> [a-zA-Z]*
# rule_data[i] = {8 bits head, 8 bits len, 24 bits prod}
def encode_rule(head, prod):
    head_val = ord(head)
    prod_len = len(prod)
    prod_val = 0
    for i, c in enumerate(prod):
        if i < 3:  # Only first 3 chars fit in 24 bits
            prod_val |= (ord(c) << (16 - i*8))
    return (head_val << 32) | (prod_len << 24) | prod_val

@cocotb.test()
async def test_cfg_search_basic(dut):
    """Test basic palindrome grammar """
    # Setup clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.rule_count.value = 0
    for i in range(6):
        setattr(dut, f'rule_data_{i}', 0)
    dut.text_data.value = 0
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await Timer(50, units='ns')
    
    # Grammar: S->aSa, S->bSb, S->a, S->b, S-> (empty)
    # Start symbol is 'S'
    rules = [
        encode_rule('S', 'aSa'),
        encode_rule('S', 'bSb'),
        encode_rule('S', 'a'),
        encode_rule('S', 'b'),
        encode_rule('S', ''),
    ]
    
    # Text: "where are the abaaba palindromes"
    # Looking for "abaaba" (length 6)
    text = "abaaba"
    text_bytes = [ord(c) for c in text] + [0]*(16-len(text))
    text_val = 0
    for i, b in enumerate(text_bytes):
        text_val |= (b << (120 - i*8))
    
    # Load inputs
    dut.rule_count.value = 5
    for i in range(5):
        setattr(dut, f'rule_data_{i}', rules[i])
    for i in range(5, 6):
        setattr(dut, f'rule_data_{i}', 0)
    dut.text_data.value = text_val
    
    # Start
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done
    for _ in range(10000):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    
    # Check results
    if dut.done.value != 1:
        raise TestFailure("Did not complete within 10000 cycles")
    
    # Expected: "abaaba" at position 0, length 6
    if dut.result_length.value != 6:
        raise TestFailure(f"Expected length 6, got {dut.result_length.value}")
    
    print(f"Test 1: Found substring length {dut.result_length.value} at pos {dut.result_start.value}")

@cocotb.test()
async def test_cfg_search_none(dut):
    """Test case with no match """
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.rule_count.value = 0
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await Timer(50, units='ns')
    
    # Same grammar
    rules = [
        encode_rule('S', 'aSa'),
        encode_rule('S', 'bSb'),
        encode_rule('S', 'a'),
        encode_rule('S', 'b'),
        encode_rule('S', ''),
    ]
    
    # Text with no a/b characters
    text = "xyz"
    text_bytes = [ord(c) for c in text] + [0]*(16-len(text))
    text_val = 0
    for i, b in enumerate(text_bytes):
        text_val |= (b << (120 - i*8))
    
    dut.rule_count.value = 5
    for i in range(5):
        setattr(dut, f'rule_data_{i}', rules[i])
    dut.text_data.value = text_val
    
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(10000):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    
    if dut.done.value != 1:
        raise TestFailure("Did not complete")
    
    # Expected: length 0 indicates NONE
    if dut.result_length.value != 0:
        raise TestFailure(f"Expected length 0 (NONE), got {dut.result_length.value}")
    
    print(f"Test 2: No match (length {dut.result_length.value}) - PASS")

@cocotb.test()
async def test_cfg_search_long(dut):
    """Test finding longest in mixed string """
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.rule_count.value = 0
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await Timer(50, units='ns')
    
    # Grammar for palindromes
    rules = [
        encode_rule('S', 'aSa'),
        encode_rule('S', 'bSb'),
        encode_rule('S', 'a'),
        encode_rule('S', 'b'),
        encode_rule('S', ''),
    ]
    
    # Text: "abbaaabb" (should find "abbba" or similar if valid)
    # Actually: "abbaaabb" - palindromes: "a", "b", "abba", "aa"
    # Longest is "abba" or "aabb" if valid? Wait, "aabb" is not palindrome
    # "abba" is valid palindrome (4 chars)
    text = "abbaaabb"
    text_bytes = [ord(c) for c in text] + [0]*(16-len(text))
    text_val = 0
    for i, b in enumerate(text_bytes):
        text_val |= (b << (120 - i*8))
    
    dut.rule_count.value = 5
    for i in range(5):
        setattr(dut, f'rule_data_{i}', rules[i])
    dut.text_data.value = text_val
    
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(10000):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    
    if dut.done.value != 1:
        raise TestFailure("Did not complete")
    
    # Expected: "abba" (length 4) at position 0
    # Or "aa" (length 2) at position 3
    # Longest is 4
    length = dut.result_length.value
    if length < 4:
        raise TestFailure(f"Expected at least length 4, got {length}")
    
    print(f"Test 3: Longest match length {length} at pos {dut.result_start.value}")

@cocotb.test()
async def test_cfg_search_early_tie(dut):
    """Test tie-breaking: earliest position """
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.rule_count.value = 0
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await Timer(50, units='ns')
    
    # Grammar: S->a, S->b (simple terminals)
    rules = [
        encode_rule('S', 'a'),
        encode_rule('S', 'b'),
    ]
    
    # Text: "a a" (with space, but we only see lowercase)
    # Actually text is lowercase only. Let's do "ab"
    # Longest are "a" (pos 0) and "b" (pos 1), both length 1
    # Should pick earliest (pos 0)
    text = "ab"
    text_bytes = [ord(c) for c in text] + [0]*(16-len(text))
    text_val = 0
    for i, b in enumerate(text_bytes):
        text_val |= (b << (120 - i*8))
    
    dut.rule_count.value = 2
    for i in range(2):
        setattr(dut, f'rule_data_{i}', rules[i])
    for i in range(2, 6):
        setattr(dut, f'rule_data_{i}', 0)
    dut.text_data.value = text_val
    
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(10000):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    
    if dut.done.value != 1:
        raise TestFailure("Did not complete")
    
    # Expected: length 1 at position 0
    if dut.result_length.value != 1:
        raise TestFailure(f"Expected length 1, got {dut.result_length.value}")
    if dut.result_start.value != 0:
        raise TestFailure(f"Expected start 0, got {dut.result_start.value}")
    
    print(f"Test 4: Tie broken correctly - pos {dut.result_start.value}, len {dut.result_length.value}")

@cocotb.test()
async def test_cfg_search_empty_rule(dut):
    """Test with only empty production""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.rule_count.value = 0
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await Timer(50, units='ns')
    
    # Grammar: S-> (empty only)
    # Should not match non-empty string
    rules = [
        encode_rule('S', ''),
    ]
    
    text = "abc"
    text_bytes = [ord(c) for c in text] + [0]*(16-len(text))
    text_val = 0
    for i, b in enumerate(text_bytes):
        text_val |= (b << (120 - i*8))
    
    dut.rule_count.value = 1
    setattr(dut, 'rule_data_0', rules[0])
    for i in range(1, 6):
        setattr(dut, f'rule_data_{i}', 0)
    dut.text_data.value = text_val
    
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(10000):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    
    if dut.done.value != 1:
        raise TestFailure("Did not complete")
    
    # Should output length 0
    if dut.result_length.value != 0:
        raise TestFailure(f"Expected length 0 for empty-only grammar, got {dut.result_length.value}")
    
    print(f"Test 5: Empty grammar correctly produces no match")
    print("
All tests completed!")
