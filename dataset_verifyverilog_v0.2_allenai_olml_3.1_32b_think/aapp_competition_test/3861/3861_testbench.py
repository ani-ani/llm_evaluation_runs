import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.result import TestFailure
import random
import math

def is_perfect_square(n):
    if n < 0:
        return False
    root = int(math.isqrt(n))
    return root * root == n

@cocotb.test()
async def test_max_non_square(dut):
    """Test the max_non_square module"""
    
    # Create a clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.valid_in.value = 0
    dut.data_in.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases
    test_vectors = [
        # Array of inputs, expected result
        ([4, 2], 2),
        ([1, 2, 4, 8, 16, 32, 64, 576], 32),
        ([-1, -4, -9], -1),
        ([9, 16, 20, 25], 20),
        ([0, 1, 2, 3], 3),
        ([64, 63, 62, 65], 65),
        ([10000, 9801, 10001], 10001), # 9801 = 99^2
        ([-5, -100, 4], -5)
    ]
    
    for inputs, expected in test_vectors:
        dut._log.info(f"Testing array {inputs}, expecting {expected}")
        
        # Initialize max to a very small number (simulate -inf)
        # The module should handle this internally via start/reset signal if implemented.
        # Here we assume 'start' resets the internal max.
        
        dut.valid_in.value = 0
        
        # Send start pulse (if the design requires it, else we rely on first valid)
        # We assume the design resets max when the first valid comes in after idle, 
        # or we assert a 'start' signal. Let's assume a 'start' signal exists.
        # But looking at the prompt logic, it says 'start' resets.
        # Since we don't see a specific 'start' port in the testbench connect, 
        # let's assume the logic: when valid_in comes while in IDLE, it captures the first value.
        
        current_max = -10**9
        
        # Check if there are any non-squares. The problem guarantees at least one.
        # If the array is all squares, what should happen? Problem says guaranteed at least one non-square.
        
        for num in inputs:
            dut.data_in.value = num
            dut.valid_in.value = 1
            await RisingEdge(dut.clk)
            # Wait for output if it's a multi-cycle operation.
            # The prompt suggests a state machine. Let's wait for 'done' or 'valid_out' if it exists.
            # However, to keep the testbench simple and generic, we will assume the module updates 'result' 
            # in the same cycle or next cycle.
            
            # Wait for processing (give it a few cycles)
            # If the design is pipelined, we need to wait. 
            # Let's assume the design processes one number every few cycles or every cycle.
            # We will wait a few cycles for the internal SQRT to finish.
            for _ in range(20): # Sufficient time for sequential sqrt logic
                await RisingEdge(dut.clk)
                if dut.done.value == 1:
                    break
            
            # Latch the result for checking if it's the final result for this number
            # The design might output 'max_out' continuously.
            # We need to verify logic: The module should output the max of processed elements.
            
            dut.valid_in.value = 0
            await RisingEdge(dut.clk) # Allow settle
            
        # After loop, check final result
        final_result = int(dut.result.value)
        if final_result != expected:
            raise TestFailure(f"Mismatch: Inputs {inputs}, Expected {expected}, Got {final_result}")
        
        # Reset for next test case (pulse reset or start)
        dut.rst_n.value = 0
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)

    dut._log.info("All tests passed!")