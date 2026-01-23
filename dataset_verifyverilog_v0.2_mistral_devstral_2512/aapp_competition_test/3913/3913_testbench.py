import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
import random

# Helper to pack string into 128-bit integer
def pack_string(s, length=16):
    val = 0
    for i, c in enumerate(s):
        val |= ord(c) << (8 * i)
    return val

# Helper to pack word list into array of 128-bit integers
def pack_word_list(words, length=16):
    packed = []
    for w in words:
        packed.append(pack_string(w, length))
    # Pad if less than 16
    while len(packed) < 16:
        packed.append(0)
    return packed

@cocotb.test()
async def test_word_guess_solver_basic(dut):
    """Test basic functionality with known cases"""
    
    # Create clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.n.value = 0
    dut.hidden_pattern.value = 0
    dut.m.value = 0
    for i in range(16):
        dut.word_list[i].value = 0
    
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test Case 1: "a**d" with words "abcd", "acbd" -> Expected 2 (b, c)
    dut.n.value = 4
    dut.hidden_pattern.value = pack_string("a**d")
    dut.m.value = 2
    words1 = ["abcd", "acbd"]
    packed_words1 = pack_word_list(words1)
    for i in range(16):
        dut.word_list[i].value = packed_words1[i]
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done (max 20 cycles + safety)
    for _ in range(25):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    
    assert dut.done.value == 1, "Done signal not asserted"
    assert dut.result_count.value == 2, f"Expected 2, got {dut.result_count.value}"
    print("Test 1 Passed: a**d -> 2")
    
    # Reset for next test
    dut.start.value = 0
    await RisingEdge(dut.clk)
    
    # Test Case 2: "lo*er" with words "lover", "loser" -> Expected 0
    dut.n.value = 5
    dut.hidden_pattern.value = pack_string("lo*er")
    dut.m.value = 2
    words2 = ["lover", "loser"]
    packed_words2 = pack_word_list(words2)
    for i in range(16):
        dut.word_list[i].value = packed_words2[i]
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(25):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
            
    assert dut.done.value == 1
    assert dut.result_count.value == 0, f"Expected 0, got {dut.result_count.value}"
    print("Test 2 Passed: lo*er -> 0")
    
    # Reset
    dut.start.value = 0
    await RisingEdge(dut.clk)
    
    # Test Case 3: "a*a" with words "aaa", "aba" -> Expected 1 (b)
    # Note: "aaa" is invalid because middle 'a' is revealed but pattern has '*'
    dut.n.value = 3
    dut.hidden_pattern.value = pack_string("a*a")
    dut.m.value = 2
    words3 = ["aaa", "aba"]
    packed_words3 = pack_word_list(words3)
    for i in range(16):
        dut.word_list[i].value = packed_words3[i]
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(25):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
            
    assert dut.done.value == 1
    assert dut.result_count.value == 1, f"Expected 1, got {dut.result_count.value}"
    print("Test 3 Passed: a*a -> 1")
    
    # Reset
    dut.start.value = 0
    await RisingEdge(dut.clk)
    
    # Test Case 4: Single character hidden "*" with one word "a" -> Expected 1
    dut.n.value = 1
    dut.hidden_pattern.value = pack_string("*")
    dut.m.value = 1
    words4 = ["a"]
    packed_words4 = pack_word_list(words4)
    for i in range(16):
        dut.word_list[i].value = packed_words4[i]
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(25):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
            
    assert dut.done.value == 1
    assert dut.result_count.value == 1, f"Expected 1, got {dut.result_count.value}"
    print("Test 4 Passed: * -> 1")
    
    print("All 4 tests passed!")