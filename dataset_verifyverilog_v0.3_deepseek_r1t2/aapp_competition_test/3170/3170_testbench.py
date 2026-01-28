import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

def is_value_defined(value):
    try:
        int(value)
        return True
    except ValueError:
        return False

def safe_int(value, default=0):
    try:
        return int(value)
    except ValueError:
        return default

def char_to_val(c):
    if c == 'A': return 0
    if c == 'J': return 10
    if c == 'Q': return 11
    if c == 'K': return 12
    if c == 'T': return 9
    return int(c) - 2

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_trash_game(dut):
    # Start clock
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    
    # Reset
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases
    test_cases = [
        ("23456789TJ23456789TJA89Q66JK37T2A4AQK3AK5T8Q24K97JQ5", 1),
        ("89724TJTA67K4J87Q8T6Q7J2324T558KA99A3KA356QJ6523QK49", 1),
        ("6Q4K476722745A9A9875A2TT3JA6K5K34JKQQTQ235T9868J893J", 0),
    ]
    
    for i, (deck_str, expected) in enumerate(test_cases):
        # Convert deck string to 208-bit integer
        deck_int = 0
        for idx, char in enumerate(deck_str.strip()):
            if idx >= 52: break
            val = char_to_val(char)
            deck_int |= (val << ((51 - idx) * 4))
        
        dut.deck.value = deck_int
        
        # Start pulse
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        done = False
        for _ in range(10000):
            await RisingEdge(dut.clk)
            if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                done = True
                break
        
        if not done:
            raise TestFailure(f"Test {i+1}: Done not asserted")
        
        winner_val = int(dut.winner.value)
        if winner_val != expected:
            raise TestFailure(f"Test {i+1}: Expected {expected}, got {winner_val}")
        
        # Reset for next test
        dut.rst_n.value = 0
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
