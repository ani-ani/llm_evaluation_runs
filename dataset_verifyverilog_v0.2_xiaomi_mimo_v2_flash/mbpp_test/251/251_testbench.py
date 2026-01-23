import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
import random

@cocotb.test()
async def test_insert_element(dut):
    """Test insert_element module with various inputs"""
    
    # Setup clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.element.value = 0
    dut.list_len.value = 0
    for i in range(8):
        dut.list_data[i].value = 0
    
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test 1: ['R','e','d'] + 'c' -> ['c','R','c','e','c','d']
    print("
Test 1: ['R','e','d'] + 'c'")
    dut.element.value = ord('c')
    dut.list_data[0].value = ord('R')
    dut.list_data[1].value = ord('e')
    dut.list_data[2].value = ord('d')
    dut.list_len.value = 3
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done (should take 16 cycles)
    timeout = 20
    for _ in range(timeout):
        await RisingEdge(dut.clk)
        if dut.done.value:
            break
    
    # Check result
    expected = [ord('c'), ord('R'), ord('c'), ord('e'), ord('c'), ord('d')]
    result_len = int(dut.result_len.value)
    print(f"Expected length: {len(expected)}, Got: {result_len}")
    assert result_len == len(expected), f"Length mismatch: expected {len(expected)}, got {result_len}"
    
    for i in range(len(expected)):
        actual = int(dut.result[i].value)
        print(f"  result[{i}] = {actual} (expected {expected[i]} = '{chr(expected[i])}')")
        assert actual == expected[i], f"Mismatch at index {i}: expected {expected[i]}, got {actual}"
    
    print("Test 1 PASSED")
    
    # Reset for next test
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test 2: ['p','y','t','h','o','n'] + 'X' (6 elements)
    print("
Test 2: ['p','y','t','h','o','n'] + 'X'")
    dut.element.value = ord('X')
    dut.list_data[0].value = ord('p')
    dut.list_data[1].value = ord('y')
    dut.list_data[2].value = ord('t')
    dut.list_data[3].value = ord('h')
    dut.list_data[4].value = ord('o')
    dut.list_data[5].value = ord('n')
    dut.list_len.value = 6
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 20
    for _ in range(timeout):
        await RisingEdge(dut.clk)
        if dut.done.value:
            break
    
    expected = [ord('X'), ord('p'), ord('X'), ord('y'), ord('X'), ord('t'), ord('X'), ord('h'), ord('X'), ord('o'), ord('X'), ord('n')]
    result_len = int(dut.result_len.value)
    print(f"Expected length: {len(expected)}, Got: {result_len}")
    assert result_len == len(expected)
    
    for i in range(len(expected)):
        actual = int(dut.result[i].value)
        assert actual == expected[i]
    
    print("Test 2 PASSED")
    
    # Reset for next test
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test 3: ['h','a','p','p','y'] + 'Z' (5 elements)
    print("
Test 3: ['h','a','p','p','y'] + 'Z'")
    dut.element.value = ord('Z')
    dut.list_data[0].value = ord('h')
    dut.list_data[1].value = ord('a')
    dut.list_data[2].value = ord('p')
    dut.list_data[3].value = ord('p')
    dut.list_data[4].value = ord('y')
    dut.list_len.value = 5
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 20
    for _ in range(timeout):
        await RisingEdge(dut.clk)
        if dut.done.value:
            break
    
    expected = [ord('Z'), ord('h'), ord('Z'), ord('a'), ord('Z'), ord('p'), ord('Z'), ord('p'), ord('Z'), ord('y')]
    result_len = int(dut.result_len.value)
    print(f"Expected length: {len(expected)}, Got: {result_len}")
    assert result_len == len(expected)
    
    for i in range(len(expected)):
        actual = int(dut.result[i].value)
        assert actual == expected[i]
    
    print("Test 3 PASSED")
    
    # Reset for next test
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test 4: Single element ['A'] + 'B'
    print("
Test 4: ['A'] + 'B'")
    dut.element.value = ord('B')
    dut.list_data[0].value = ord('A')
    dut.list_len.value = 1
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 20
    for _ in range(timeout):
        await RisingEdge(dut.clk)
        if dut.done.value:
            break
    
    expected = [ord('B'), ord('A')]
    result_len = int(dut.result_len.value)
    assert result_len == 2
    assert int(dut.result[0].value) == ord('B')
    assert int(dut.result[1].value) == ord('A')
    print("Test 4 PASSED")
    
    # Reset for next test
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test 5: Empty list
    print("
Test 5: [] + 'X'")
    dut.element.value = ord('X')
    dut.list_len.value = 0
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 20
    for _ in range(timeout):
        await RisingEdge(dut.clk)
        if dut.done.value:
            break
    
    result_len = int(dut.result_len.value)
    assert result_len == 0
    print("Test 5 PASSED")
    
    print("
All 5 tests passed!")