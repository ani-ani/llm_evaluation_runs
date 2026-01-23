import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from cocotb.result import TestFailure

# Helper to pack string into 8-byte array
# Strings are limited to 8 chars, padded with 0x00
def pack_string(s):
    b = bytearray(8)
    encoded = s.encode('ascii')
    if len(encoded) > 8:
        encoded = encoded[:8]
    b[:len(encoded)] = encoded
    return b

@cocotb.test()
async def test_loda_basic(dut):
    """Test basic case: A, AA, AAA -> Length 3"""
    # Setup Clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.num_strings.value = 0
    for i in range(8):
        dut.strings[i].value = 0
    
    await Timer(20, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Input: 5 strings: A, B, AA, BBB, AAA
    # Subsequence: A -> AA -> AAA (Length 3)
    # Strings: 
    # 0: A (0x41)
    # 1: B (0x42)
    # 2: AA (0x41 0x41)
    # 3: BBB (0x42 0x42 0x42)
    # 4: AAA (0x41 0x41 0x41)
    
    s_list = ["A", "B", "AA", "BBB", "AAA"]
    dut.num_strings.value = 5
    
    for i, s in enumerate(s_list):
        dut.strings[i].value = pack_string(s)
        
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done
    cycles = 0
    while dut.done.value == 0 and cycles < 500:
        await RisingEdge(dut.clk)
        cycles += 1
        
    if dut.done.value != 1:
        raise TestFailure("Module did not assert done in time")
        
    if int(dut.result.value) != 3:
        raise TestFailure(f"Expected result 3, got {int(dut.result.value)}")

@cocotb.test()
async def test_loda_complex(dut):
    """Test complex case: A, ABA, BBB, ABABA, AAAAAB -> Length 3 (A -> ABA -> ABABA)"""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.num_strings.value = 0
    for i in range(8):
        dut.strings[i].value = 0
    
    await Timer(20, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Input: A, ABA, BBB, ABABA, AAAAAB
    # Valid chain: A -> ABA -> ABABA
    s_list = ["A", "ABA", "BBB", "ABABA", "AAAAAB"]
    dut.num_strings.value = 5
    
    for i, s in enumerate(s_list):
        dut.strings[i].value = pack_string(s)
        
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    cycles = 0
    while dut.done.value == 0 and cycles < 500:
        await RisingEdge(dut.clk)
        cycles += 1
        
    if dut.done.value != 1:
        raise TestFailure("Module did not assert done in time")
        
    if int(dut.result.value) != 3:
        raise TestFailure(f"Expected result 3, got {int(dut.result.value)}")

@cocotb.test()
async def test_loda_repeats(dut):
    """Test case with repeats: A, B, A, B, A, B -> Length 3"""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.num_strings.value = 0
    for i in range(8):
        dut.strings[i].value = 0
    
    await Timer(20, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Input: A, B, A, B, A, B
    # Valid chains: A -> A -> A (length 3) or B -> B -> B (length 3)
    s_list = ["A", "B", "A", "B", "A", "B"]
    dut.num_strings.value = 6
    
    for i, s in enumerate(s_list):
        dut.strings[i].value = pack_string(s)
        
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    cycles = 0
    while dut.done.value == 0 and cycles < 500:
        await RisingEdge(dut.clk)
        cycles += 1
        
    if dut.done.value != 1:
        raise TestFailure("Module did not assert done in time")
        
    if int(dut.result.value) != 3:
        raise TestFailure(f"Expected result 3, got {int(dut.result.value)}")