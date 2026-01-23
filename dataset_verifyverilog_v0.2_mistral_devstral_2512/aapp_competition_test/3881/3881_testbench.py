import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, Timer
from cocotb.result import TestFailure
import random

@cocotb.test()
async def test_polar_bear_compress(dut):
    """Test polar bear string compression problem"""
    
    # Initialize signals
    dut.rst_n.value = 1
    dut.start.value = 0
    dut.q.value = 0
    dut.n.value = 0
    
    # Initialize operation arrays to 0
    for i in range(36):
        dut.op_a_idx[i].value = 0
        dut.op_b_idx[i].value = 0
        dut.op_dest[i].value = 0
    
    # Start clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test Case 1: n=3, q=5, expected=4
    # Operations: ab->a, cc->c, ca->a, ee->c, ff->d
    # Valid strings: abb, cab, cca, eea
    dut.n.value = 3
    dut.q.value = 5
    
    # Map: a=0,b=1,c=2,d=3,e=4,f=5
    # ab a -> a_idx=0, b_idx=1, dest=0
    dut.op_a_idx[0].value = 0
    dut.op_b_idx[0].value = 1
    dut.op_dest[0].value = 0
    
    # cc c -> a_idx=2, b_idx=2, dest=2
    dut.op_a_idx[1].value = 2
    dut.op_b_idx[1].value = 2
    dut.op_dest[1].value = 2
    
    # ca a -> a_idx=2, b_idx=0, dest=0
    dut.op_a_idx[2].value = 2
    dut.op_b_idx[2].value = 0
    dut.op_dest[2].value = 0
    
    # ee c -> a_idx=4, b_idx=4, dest=2
    dut.op_a_idx[3].value = 4
    dut.op_b_idx[3].value = 4
    dut.op_dest[3].value = 2
    
    # ff d -> a_idx=5, b_idx=5, dest=3
    dut.op_a_idx[4].value = 5
    dut.op_b_idx[4].value = 5
    dut.op_dest[4].value = 3
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done
    timeout = 50
    for _ in range(timeout):
        if dut.done.value == 1:
            break
        await RisingEdge(dut.clk)
    
    result = int(dut.result.value)
    if result != 4:
        raise TestFailure(f"Test 1 failed: expected 4, got {result}")
    print(f"Test 1 passed: result={result}")
    
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    
    # Test Case 2: n=2, q=8, expected=1
    # Operations include eb->a, which is the only valid 2-char string
    dut.n.value = 2
    dut.q.value = 8
    
    # Clear and set new operations
    for i in range(36):
        dut.op_a_idx[i].value = 0
        dut.op_b_idx[i].value = 0
        dut.op_dest[i].value = 0
    
    # af e, dc d, cc f, bc b, da b, eb a, bb b, ff c
    ops = [(0,5,4), (3,2,3), (2,2,5), (1,2,1), (3,0,1), (4,1,0), (1,1,1), (5,5,2)]
    for i, (a,b,d) in enumerate(ops):
        dut.op_a_idx[i].value = a
        dut.op_b_idx[i].value = b
        dut.op_dest[i].value = d
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 50
    for _ in range(timeout):
        if dut.done.value == 1:
            break
        await RisingEdge(dut.clk)
    
    result = int(dut.result.value)
    if result != 1:
        raise TestFailure(f"Test 2 failed: expected 1, got {result}")
    print(f"Test 2 passed: result={result}")
    
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    
    # Test Case 3: n=6, q=2, expected=0
    # Operations: bb->a, ba->a
    # Cannot reach length 6 from 'a' in reverse
    dut.n.value = 6
    dut.q.value = 2
    
    for i in range(36):
        dut.op_a_idx[i].value = 0
        dut.op_b_idx[i].value = 0
        dut.op_dest[i].value = 0
    
    # bb a -> idx 1,1,0
    dut.op_a_idx[0].value = 1
    dut.op_b_idx[0].value = 1
    dut.op_dest[0].value = 0
    
    # ba a -> idx 1,0,0
    dut.op_a_idx[1].value = 1
    dut.op_b_idx[1].value = 0
    dut.op_dest[1].value = 0
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 50
    for _ in range(timeout):
        if dut.done.value == 1:
            break
        await RisingEdge(dut.clk)
    
    result = int(dut.result.value)
    if result != 0:
        raise TestFailure(f"Test 3 failed: expected 0, got {result}")
    print(f"Test 3 passed: result={result}")
    
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    
    # Test Case 4: n=5, q=5, expected=1 (from inputs)
    # Same operations as test 1 but n=5
    dut.n.value = 5
    dut.q.value = 5
    
    for i in range(36):
        dut.op_a_idx[i].value = 0
        dut.op_b_idx[i].value = 0
        dut.op_dest[i].value = 0
    
    dut.op_a_idx[0].value = 0
    dut.op_b_idx[0].value = 1
    dut.op_dest[0].value = 0
    
    dut.op_a_idx[1].value = 2
    dut.op_b_idx[1].value = 2
    dut.op_dest[1].value = 2
    
    dut.op_a_idx[2].value = 2
    dut.op_b_idx[2].value = 0
    dut.op_dest[2].value = 0
    
    dut.op_a_idx[3].value = 4
    dut.op_b_idx[3].value = 4
    dut.op_dest[3].value = 2
    
    dut.op_a_idx[4].value = 5
    dut.op_b_idx[4].value = 5
    dut.op_dest[4].value = 3
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 50
    for _ in range(timeout):
        if dut.done.value == 1:
            break
        await RisingEdge(dut.clk)
    
    result = int(dut.result.value)
    if result != 1:
        raise TestFailure(f"Test 4 failed: expected 1, got {result}")
    print(f"Test 4 passed: result={result}")
    
    print("All tests passed!")
