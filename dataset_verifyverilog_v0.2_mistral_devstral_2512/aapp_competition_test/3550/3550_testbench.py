import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer, RisingEdge
from cocotb.result import TestFailure
import random

@cocotb.test()
async def test_nenscript_evaluator(dut):
    """Test the NenScript evaluator with variable declarations and print statements"""
    
    # Setup clock
    clock = Clock(dut.clk, 20, units='ns')  # 50 MHz
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.cmd_type.value = 0
    dut.line_buffer.value = 0
    dut.line_length.value = 0
    await Timer(100, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    print("
=== NenScript Evaluator Test ===")
    
    # Test 1: Simple variable reference
    print("
Test 1: Simple variable reference")
    cmd = b'var a = "Gon";'
    await run_command(dut, cmd, cmd_type=0)
    
    cmd = b'var b = a;'
    await run_command(dut, cmd, cmd_type=0)
    
    cmd = b'print b;'
    result = await run_command(dut, cmd, cmd_type=1)
    expected = b'Gon'
    assert result == expected, f"Test 1 failed: got {result}, expected {expected}"
    print(f"  PASS: {result.decode()}")
    
    # Reset before next test
    dut.rst_n.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test 2: Template literal
    print("
Test 2: Template literal")
    cmd = b'var a = "Gon";'
    await run_command(dut, cmd, cmd_type=0)
    
    cmd = b'print `My name is ${a}`;'
    result = await run_command(dut, cmd, cmd_type=1)
    expected = b'My name is Gon'
    assert result == expected, f"Test 2 failed: got {result}, expected {expected}"
    print(f"  PASS: {result.decode()}")
    
    # Reset before next test
    dut.rst_n.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test 3: Nested template literals
    print("
Test 3: Nested template literals")
    cmd = b'var one = "1";'
    await run_command(dut, cmd, cmd_type=0)
    
    cmd = b'var two = "2";'
    await run_command(dut, cmd, cmd_type=0)
    
    cmd = b'print `1${`2${two}2`}1`;'
    result = await run_command(dut, cmd, cmd_type=1)
    expected = b'1221'
    assert result == expected, f"Test 3 failed: got {result}, expected {expected}"
    print(f"  PASS: {result.decode()}")
    
    # Reset before next test
    dut.rst_n.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test 4: Multiple variables and print
    print("
Test 4: Multiple variables")
    cmd = b'var a = "Gon";'
    await run_command(dut, cmd, cmd_type=0)
    cmd = b'var b = a;'
    await run_command(dut, cmd, cmd_type=0)
    cmd = b'var c = `My name is ${a}`;'
    await run_command(dut, cmd, cmd_type=0)
    cmd = b'print c;'
    result = await run_command(dut, cmd, cmd_type=1)
    expected = b'My name is Gon'
    assert result == expected, f"Test 4 failed: got {result}, expected {expected}"
    print(f"  PASS: {result.decode()}")
    
    cmd = b'print `My name is ${b}`;'
    result = await run_command(dut, cmd, cmd_type=1)
    expected = b'My name is Gon'
    assert result == expected, f"Test 4b failed: got {result}, expected {expected}"
    print(f"  PASS: {result.decode()}")
    
    print("
=== All tests passed! ===")

async def run_command(dut, cmd_bytes, cmd_type):
    """Helper to send a command and wait for result"""
    # Load command into line_buffer
    dut.line_buffer.value = int.from_bytes(cmd_bytes.ljust(256, b'\0'), 'little')
    dut.line_length.value = len(cmd_bytes)
    dut.cmd_type.value = cmd_type
    
    # Start command
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done
    timeout = 0
    while not dut.done.value and timeout < 1000:
        await RisingEdge(dut.clk)
        timeout += 1
    
    if timeout >= 1000:
        raise TestFailure(f"Timeout waiting for done signal")
    
    # Read result
    result_len = dut.result_length.value
    result_data = dut.result.value
    
    # Convert integer to bytes
    result_bytes = result_data.to_bytes(256, 'little')[:result_len]
    
    return result_bytes
