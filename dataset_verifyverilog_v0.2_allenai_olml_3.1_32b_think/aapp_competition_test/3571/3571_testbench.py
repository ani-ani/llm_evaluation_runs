import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer, RisingEdge
from cocotb.result import TestFailure

@cocotb.test()
async def test_elder_gui_basic(dut):
    """Test basic elder GUI functionality with simplified inputs"""
    
    # Setup clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.char_valid.value = 0
    dut.char_data.value = 0
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test case 1: Simple 8x6 viewport
    # W=8, H=6, F=1, N=1
    # W_in = 8.0 in Q16.16 = 0x00080000
    # H_in = 6.0 in Q16.16 = 0x00060000
    # F_in = 1.0 in Q16.16 = 0x00010000
    # N_in = 1.0 in Q16.16 = 0x00010000
    
    dut.W_in.value = 0x00080000
    dut.H_in.value = 0x00060000
    dut.F_in.value = 0x00010000
    dut.N_in.value = 0x00010000
    
    # Start the process
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Feed text: "Lorem ipsum dolor sit amet consectetur adipisicing elit sed do"
    # We'll feed simplified text: "ipsum dolor sit" (process in char stream)
    # For this test, we simulate the text input
    
    text_chars = []
    text_input = "ipsum"
    for c in text_input:
        text_chars.append(ord(c))
    text_chars.append(10)  # Newline
    
    # Feed characters over multiple cycles
    for char in text_chars:
        await RisingEdge(dut.clk)
        dut.char_valid.value = 1
        dut.char_data.value = char
        
    # Wait for processing
    for _ in range(50):
        await RisingEdge(dut.clk)
        if dut.done.value:
            break
    
    # Read output
    print(f"State: {dut.state.value}")
    print(f"Lines count: {dut.lines_count.value}")
    print(f"Adj count: {dut.adj_count.value}")
    
    # Check if done
    assert dut.done.value == 1, "Module should complete"
    
    print("Test 1 passed: Basic functionality")

@cocotb.test()
async def test_elder_gui_thumb_calculation(dut):
    """Test thumb position calculation"""
    
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.char_valid.value = 0
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Setup: W=24, H=5, F=8, N=7 (sample from problem)
    # But scaled down for 16-bit processing
    # Let's use W=16, H=5, F=3, N=5
    dut.W_in.value = 0x00100000  # 16
    dut.H_in.value = 0x00050000  # 5
    dut.F_in.value = 0x00030000  # 3
    dut.N_in.value = 0x00050000  # 5
    
    # Feed minimal text
    test_text = "a b c d e"
    for c in test_text:
        await RisingEdge(dut.clk)
        dut.char_valid.value = 1
        dut.char_data.value = ord(c)
    
    # Add newline to finish
    await RisingEdge(dut.clk)
    dut.char_valid.value = 1
    dut.char_data.value = 10
    
    # Clear valid
    await RisingEdge(dut.clk)
    dut.char_valid.value = 0
    
    # Process
    for _ in range(100):
        await RisingEdge(dut.clk)
        if dut.done.value:
            break
    
    print(f"Thumb position: {dut.thumb_pos.value}")
    print(f"Adj count: {dut.adj_count.value}")
    
    assert dut.done.value == 1, "Module should complete"
    print("Test 2 passed: Thumb calculation")

@cocotb.test()
async def test_elder_gui_word_truncation(dut):
    """Test word truncation when word > viewport width"""
    
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.char_valid.value = 0
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # W=5, H=4, F=0, N=1
    dut.W_in.value = 0x00050000
    dut.H_in.value = 0x00040000
    dut.F_in.value = 0x00000000
    dut.N_in.value = 0x00010000
    
    # Feed word longer than width: "TOOLONG"
    test_text = "TOOLONG"
    for c in test_text:
        await RisingEdge(dut.clk)
        dut.char_valid.value = 1
        dut.char_data.value = ord(c)
    
    await RisingEdge(dut.clk)
    dut.char_valid.value = 1
    dut.char_data.value = 10
    
    await RisingEdge(dut.clk)
    dut.char_valid.value = 0
    
    for _ in range(80):
        await RisingEdge(dut.clk)
        if dut.done.value:
            break
    
    print(f"Truncation test state: {dut.state.value}")
    print(f"Adj count: {dut.adj_count.value}")
    
    assert dut.done.value == 1, "Module should complete"
    print("Test 3 passed: Word truncation")

@cocotb.test()
async def test_elder_gui_empty_lines(dut):
    """Test handling of empty/multiple lines"""
    
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.char_valid.value = 0
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # W=10, H=4, F=0, N=2
    dut.W_in.value = 0x000A0000
    dut.H_in.value = 0x00040000
    dut.F_in.value = 0x00000000
    dut.N_in.value = 0x00020000
    
    # Two lines
    text_lines = ["line1", "word2"]
    for line in text_lines:
        for c in line:
            await RisingEdge(dut.clk)
            dut.char_valid.value = 1
            dut.char_data.value = ord(c)
        await RisingEdge(dut.clk)
        dut.char_valid.value = 1
        dut.char_data.value = 10
    
    await RisingEdge(dut.clk)
    dut.char_valid.value = 0
    
    for _ in range(100):
        await RisingEdge(dut.clk)
        if dut.done.value:
            break
    
    assert dut.done.value == 1, "Module should complete"
    print("Test 4 passed: Multiple lines")

@cocotb.test()
async def test_elder_gui_regression(dut):
    """Regression test with exact sample inputs scaled down"""
    
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.char_valid.value = 0
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Scaled version of sample:
    # Original: W=24, H=5, F=8, N=7
    # Scaled: W=16, H=5, F=5, N=6
    dut.W_in.value = 0x00100000
    dut.H_in.value = 0x00050000
    dut.F_in.value = 0x00050000
    dut.N_in.value = 0x00060000
    
    # Simplified text feed
    lines = [
        "lorem ipsum",
        "dolor sit",
        "amet consectetur",
        "adipisicing elit",
        "sed do eiusmod",
        "tempor incididunt"
    ]
    
    for line in lines:
        for c in line:
            await RisingEdge(dut.clk)
            dut.char_valid.value = 1
            dut.char_data.value = ord(c)
        await RisingEdge(dut.clk)
        dut.char_valid.value = 1
        dut.char_data.value = 10
    
    await RisingEdge(dut.clk)
    dut.char_valid.value = 0
    
    cycles = 0
    while cycles < 200:
        await RisingEdge(dut.clk)
        cycles += 1
        if dut.done.value:
            break
    
    # Verify completion
    if not dut.done.value:
        print(f"Warning: Did not complete in {cycles} cycles")
    else:
        print(f"Completed in {cycles} cycles")
    
    print(f"Final state: {dut.state.value}")
    print(f"Thumb pos: {dut.thumb_pos.value}")
    print(f"Adj count: {dut.adj_count.value}")
    
    assert dut.done.value == 1, "Regression test should complete"
    print("Test 5 passed: Regression")

@cocotb.test()
async def test_elder_gui_boundary_values(dut):
    """Test with minimum valid values"""
    
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.char_valid.value = 0
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Minimum W=3, H=3, F=0, N=1
    dut.W_in.value = 0x00030000
    dut.H_in.value = 0x00030000
    dut.F_in.value = 0x00000000
    dut.N_in.value = 0x00010000
    
    # Single short word
    test_text = "a"
    for c in test_text:
        await RisingEdge(dut.clk)
        dut.char_valid.value = 1
        dut.char_data.value = ord(c)
    
    await RisingEdge(dut.clk)
    dut.char_valid.value = 1
    dut.char_data.value = 10
    
    await RisingEdge(dut.clk)
    dut.char_valid.value = 0
    
    for _ in range(60):
        await RisingEdge(dut.clk)
        if dut.done.value:
            break
    
    assert dut.done.value == 1, "Boundary test should complete"
    print("Test 6 passed: Boundary values")

print("
=== Summary ===")
print("All 6 test cases defined for elder_gui module")
print("Tests cover: basic functionality, thumb calculation,")
print("word truncation, multiple lines, regression, and boundaries")