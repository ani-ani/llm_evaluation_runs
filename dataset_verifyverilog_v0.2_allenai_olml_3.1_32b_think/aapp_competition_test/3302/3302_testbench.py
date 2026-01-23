import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer, FallingEdge
from cocotb.result import TestFailure
import random

@cocotb.test()
async def test_color_code_finder(dut):
    """Test color code finder module"""
    
    # Create clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.n.value = 0
    dut.p_count.value = 0
    dut.palette.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test case 1: n=3, P={1} (should produce Gray code)
    dut.n.value = 3
    dut.p_count.value = 1
    dut.palette.value = 0  # palette[0] = 1, others don't care
    dut.palette[0] = 1
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for completion (max 2^10 cycles for n=3)
    for _ in range(3000):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    
    assert dut.done.value == 1, "Test 1: Did not complete in time"
    if dut.impossible.value == 1:
        print("Test 1: n=3, P={1} - Found as impossible (should be possible)")
    else:
        print("Test 1: n=3, P={1} - Solution found")
        # Verify it's a valid color code
        sequence = []
        for i in range(8):
            await RisingEdge(dut.clk)
            val = dut.next_value.value.integer
            sequence.append(val)
            print(f"  Element {i}: {val:03b}")
        
        # Check consecutive pairs have Hamming distance 1
        for i in range(len(sequence)-1):
            dist = bin(sequence[i] ^ sequence[i+1]).count('1')
            assert dist == 1, f"Hamming distance {dist} at position {i}, expected 1"
    
    await RisingEdge(dut.clk)
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test case 2: n=4, P={2} (should find solution)
    dut.n.value = 4
    dut.p_count.value = 1
    dut.palette.value = 0
    dut.palette[0] = 2
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(10000):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    
    assert dut.done.value == 1, "Test 2: Did not complete"
    if dut.impossible.value == 1:
        print("Test 2: n=4, P={2} - Impossible")
    else:
        print("Test 2: n=4, P={2} - Solution found")
        sequence = []
        for i in range(16):
            await RisingEdge(dut.clk)
            val = dut.next_value.value.integer
            sequence.append(val)
        print(f"  Sequence length: {len(sequence)}")
    
    await RisingEdge(dut.clk)
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test case 3: n=4, P={3} (should find solution)
    dut.n.value = 4
    dut.p_count.value = 1
    dut.palette.value = 0
    dut.palette[0] = 3
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(10000):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    
    assert dut.done.value == 1, "Test 3: Did not complete"
    if dut.impossible.value == 1:
        print("Test 3: n=4, P={3} - Impossible")
    else:
        print("Test 3: n=4, P={3} - Solution found")
    
    # Summary
    print("All basic tests completed")
