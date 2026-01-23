import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.result import TestFailure
import struct

@cocotb.test()
async def test_adverb_detector_basic(dut):
    """Test basic adverb detection: 'clearly'"""
    # Setup clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.char_in.value = 0
    dut.char_valid.value = 0
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Input string: "clearly!! we can " (16 chars)
    # 'c','l','e','a','r','l','y','!','!',' ','w','e',' ','c','a','n'
    input_chars = [ord('c'), ord('l'), ord('e'), ord('a'), ord('r'), ord('l'), ord('y'), 
                   ord('!'), ord('!'), ord(' '), ord('w'), ord('e'), ord(' '), 
                   ord('c'), ord('a'), ord('n')]
    
    # Start processing
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Feed characters
    for i, char_val in enumerate(input_chars):
        dut.char_in.value = char_val
        dut.char_valid.value = 1
        await RisingEdge(dut.clk)
    
    # Wait for completion
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    
    # Check results
    if dut.found.value != 1:
        raise TestFailure(f"Expected found=1, got {int(dut.found.value)}")
    if dut.done.value != 1:
        raise TestFailure(f"Expected done=1, got {int(dut.done.value)}")
    if dut.start_pos.value != 0:
        raise TestFailure(f"Expected start_pos=0, got {int(dut.start_pos.value)}")
    if dut.end_pos.value != 6:
        raise TestFailure(f"Expected end_pos=6, got {int(dut.end_pos.value)}")
    
    # Check word_out: "clear\0" = 0x636C617200
    expected_word = (ord('c') << 32) | (ord('l') << 24) | (ord('e') << 16) | (ord('a') << 8) | ord('r')
    if int(dut.word_out.value) != expected_word:
        raise TestFailure(f"Expected word_out=0x{expected_word:010X}, got 0x{int(dut.word_out.value):010X}")
    
    dut._log.info("Test 1 (clearly) passed")

@cocotb.test()
async def test_adverb_detector_serious(dut):
    """Test adverb detection: 'seriously'"""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.char_in.value = 0
    dut.char_valid.value = 0
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Input: "seriously!! there" (16 chars)
    input_chars = [ord('s'), ord('e'), ord('r'), ord('i'), ord('o'), ord('u'), ord('s'), ord('l'), ord('y'),
                   ord('!'), ord('!'), ord(' '), ord('t'), ord('h'), ord('e'), ord('r')]
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for i, char_val in enumerate(input_chars):
        dut.char_in.value = char_val
        dut.char_valid.value = 1
        await RisingEdge(dut.clk)
    
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    
    if dut.found.value != 1 or dut.done.value != 1:
        raise TestFailure(f"Expected found=1, done=1, got found={int(dut.found.value)}, done={int(dut.done.value)}")
    if dut.start_pos.value != 0 or dut.end_pos.value != 8:
        raise TestFailure(f"Expected positions (0,8), got ({int(dut.start_pos.value)},{int(dut.end_pos.value)})")
    
    # Check word_out: "serio" (first 5 chars of "seriously")
    expected_word = (ord('s') << 32) | (ord('e') << 24) | (ord('r') << 16) | (ord('i') << 8) | ord('o')
    if int(dut.word_out.value) != expected_word:
        raise TestFailure(f"Expected word_out=0x{expected_word:010X}, got 0x{int(dut.word_out.value):010X}")
    
    dut._log.info("Test 2 (seriously) passed")

@cocotb.test()
async def test_adverb_detector_unfortunately(dut):
    """Test adverb detection: 'unfortunately'"""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.char_in.value = 0
    dut.char_valid.value = 0
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Input: "unfortunately!! si" (16 chars)
    input_chars = [ord('u'), ord('n'), ord('f'), ord('o'), ord('r'), ord('t'), ord('u'), ord('n'), 
                   ord('a'), ord('t'), ord('e'), ord('l'), ord('y'), ord('!'), ord('!'), ord(' ')]
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for i, char_val in enumerate(input_chars):
        dut.char_in.value = char_val
        dut.char_valid.value = 1
        await RisingEdge(dut.clk)
    
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    
    if dut.found.value != 1 or dut.done.value != 1:
        raise TestFailure(f"Expected found=1, done=1, got found={int(dut.found.value)}, done={int(dut.done.value)}")
    if dut.start_pos.value != 0 or dut.end_pos.value != 12:
        raise TestFailure(f"Expected positions (0,12), got ({int(dut.start_pos.value)},{int(dut.end_pos.value)})")
    
    # Check word_out: "unfor" (first 5 chars of "unfortunately")
    expected_word = (ord('u') << 32) | (ord('n') << 24) | (ord('f') << 16) | (ord('o') << 8) | ord('r')
    if int(dut.word_out.value) != expected_word:
        raise TestFailure(f"Expected word_out=0x{expected_word:010X}, got 0x{int(dut.word_out.value):010X}")
    
    dut._log.info("Test 3 (unfortunately) passed")

@cocotb.test()
async def test_adverb_detector_no_match(dut):
    """Test case with no adverb"""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.char_in.value = 0
    dut.char_valid.value = 0
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Input: "hello world test!!" (16 chars)
    input_chars = [ord('h'), ord('e'), ord('l'), ord('l'), ord('o'), ord(' '), 
                   ord('w'), ord('o'), ord('r'), ord('l'), ord('d'), ord(' '), 
                   ord('t'), ord('e'), ord('s'), ord('t')]
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for i, char_val in enumerate(input_chars):
        dut.char_in.value = char_val
        dut.char_valid.value = 1
        await RisingEdge(dut.clk)
    
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    
    if dut.found.value != 0:
        raise TestFailure(f"Expected found=0, got {int(dut.found.value)}")
    if dut.done.value != 1:
        raise TestFailure(f"Expected done=1, got {int(dut.done.value)}")
    
    dut._log.info("Test 4 (no match) passed")

@cocotb.test()
async def test_adverb_detector_skip_spaces(dut):
    """Test skipping leading spaces"""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.char_in.value = 0
    dut.char_valid.value = 0
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Input: "  clearly!! test" (16 chars)
    input_chars = [ord(' '), ord(' '), ord('c'), ord('l'), ord('e'), ord('a'), ord('r'), ord('l'), 
                   ord('y'), ord('!'), ord('!'), ord(' '), ord('t'), ord('e'), ord('s'), ord('t')]
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for i, char_val in enumerate(input_chars):
        dut.char_in.value = char_val
        dut.char_valid.value = 1
        await RisingEdge(dut.clk)
    
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    
    if dut.found.value != 1:
        raise TestFailure(f"Expected found=1, got {int(dut.found.value)}")
    if dut.start_pos.value != 2:
        raise TestFailure(f"Expected start_pos=2, got {int(dut.start_pos.value)}")
    if dut.end_pos.value != 8:
        raise TestFailure(f"Expected end_pos=8, got {int(dut.end_pos.value)}")
    
    dut._log.info("Test 5 (skip spaces) passed")

@cocotb.test()
async def test_adverb_detector_partial_word(dut):
    """Test 'ly' not at end of word is ignored"""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.char_in.value = 0
    dut.char_valid.value = 0
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Input: "c lyly!! test" (16 chars)
    input_chars = [ord('c'), ord(' '), ord('l'), ord('y'), ord('l'), ord('y'), ord('!'), ord('!'), 
                   ord(' '), ord('t'), ord('e'), ord('s'), ord('t'), ord(' '), ord(' '), ord(' ')]
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for i, char_val in enumerate(input_chars):
        dut.char_in.value = char_val
        dut.char_valid.value = 1
        await RisingEdge(dut.clk)
    
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    
    # Should find 'lyly' which ends with 'ly' -> valid
    if dut.found.value != 1:
        raise TestFailure(f"Expected found=1, got {int(dut.found.value)}")
    
    dut._log.info("Test 6 (partial word) passed")
    
    # Print summary
    dut._log.info("All tests completed!")