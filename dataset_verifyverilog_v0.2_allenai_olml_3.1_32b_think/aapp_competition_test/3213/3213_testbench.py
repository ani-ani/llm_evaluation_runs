import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer, RisingEdge
from cocotb.result import TestFailure
import random

def compute_max_power(step_types, mask):
    power = 1
    for i in range(8):
        if mask & (1 << i):
            if step_types & (1 << i):  # 'x'
                power = (power * 2) % 8
            else:  # '+'
                power = (power + 1) % 8
    return power

def find_optimal_mask(step_types):
    max_p = 0
    best_mask = 0
    for mask in range(256):
        p = compute_max_power(step_types, mask)
        if p > max_p:
            max_p = p
            best_mask = mask
    return max_p, best_mask

@cocotb.test()
async def test_spell_optimizer(dut):
    """Test spell optimizer with multiple cases"""
    # Create clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases
    test_cases = [
        # Case 1: ++xx+x++ -> ++xx+o++
        # step_types: 00011001 (x=1, +=0 from left to right)
        (0b00011001, "++xx+x++"),
        # Case 2: xxxxxxxx -> xxoooooo
        (0b11111111, "xxxxxxxx"),
        # Case 3: xx+x+x++xx -> oooooooo
        (0b1101010011, "xx+x+x++xx"),  # Actually 10 chars, but we use 8
        # Adjusted case 3: use first 8 chars: xx+x+x++
        (0b11010100, "xx+x+x++"),
    ]
    
    for idx, (step_types, original_str) in enumerate(test_cases):
        print(f"
Test case {idx+1}: {original_str}")
        
        # Expected results
        exp_max, exp_mask = find_optimal_mask(step_types)
        
        # Start computation
        dut.step_types.value = step_types
        await RisingEdge(dut.clk)
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done (256 cycles + some overhead)
        timeout = 300
        for _ in range(timeout):
            await RisingEdge(dut.clk)
            if dut.done.value:
                break
        else:
            raise TestFailure(f"Test {idx+1}: Timeout waiting for done")
        
        # Check results
        actual_max = int(dut.max_power.value)
        actual_mask = int(dut.best_mask.value)
        
        print(f"  Expected max_power: {exp_max}, Got: {actual_max}")
        print(f"  Expected mask: {exp_mask:08b} (0x{exp_mask:02x})")
        print(f"  Got mask:      {actual_mask:08b} (0x{actual_mask:02x})")
        
        if actual_max != exp_max:
            raise TestFailure(f"Test {idx+1}: max_power mismatch. Expected {exp_max}, got {actual_max}")
        
        # The mask must yield the same max_power (multiple solutions possible)
        result_power = compute_max_power(step_types, actual_mask)
        if result_power != exp_max:
            raise TestFailure(f"Test {idx+1}: Computed power {result_power} != max {exp_max} using mask {actual_mask:08b}")
            
    print("
All tests passed!")