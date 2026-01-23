import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer, FallingEdge
from cocotb.result import TestFailure
import random

def is_valid_sequence(seq, n):
    """Check if sequence has no contiguous subarray sum divisible by n"""
    length = len(seq)
    for i in range(length):
        current_sum = 0
        for j in range(i, length):
            current_sum += seq[j]
            if current_sum % n == 0:
                return False
    return True

def generate_kth_sequence(n, k):
    """Generate kth valid sequence in lexicographical order"""
    valid_seqs = []
    # Generate all sequences of length n-1 with values 1 to n-1
    def generate(current, target_len):
        if len(current) == target_len:
            if is_valid_sequence(current, n):
                valid_seqs.append(current[:])
            return
        for val in range(1, n):
            current.append(val)
            generate(current, target_len)
            current.pop()
    
    generate([], n-1)
    valid_seqs.sort()  # Lexicographical order
    return valid_seqs[k-1]

@cocotb.test()
async def test_kth_sequence(dut):
    """Test kth_sequence module with multiple test cases"""
    # Setup clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.k.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases scaled for n=5
    test_cases = [
        (1, [1, 1, 1, 1]),   # k=1, first valid sequence
        (2, [1, 1, 1, 2]),   # k=2
        (3, [1, 1, 1, 3]),   # k=3
        (5, [1, 1, 2, 1]),   # k=5
        (10, [1, 1, 3, 3]),  # k=10
        (20, [1, 2, 4, 3]),  # k=20
    ]
    
    for k_input, expected_seq in test_cases:
        dut._log.info(f"Testing k={k_input}, expected={expected_seq}")
        
        # Start computation
        dut.k.value = k_input
        await RisingEdge(dut.clk)
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        timeout = 0
        while not dut.done.value and timeout < 10000:
            await RisingEdge(dut.clk)
            timeout += 1
        
        if timeout >= 10000:
            raise TestFailure(f"Timeout waiting for done, k={k_input}")
        
        # Read result - result is 4-bit concatenated
        result_val = int(dut.result.value)
        # Extract 4 elements: [3:0], [7:4], [11:8], [15:12]
        actual_seq = []
        for i in range(4):
            elem = (result_val >> (i*4)) & 0xF
            actual_seq.append(elem)
        
        dut._log.info(f"Actual: {actual_seq}")
        
        # Verify sequence validity
        assert is_valid_sequence(actual_seq, 5), f"Invalid sequence generated: {actual_seq}"
        
        # Verify it matches expected
        if actual_seq != expected_seq:
            # If exact match fails, at least verify it's the kth valid sequence
            # by generating all and checking
            generated = generate_kth_sequence(5, k_input)
            if actual_seq != generated:
                raise TestFailure(f"k={k_input}: expected {expected_seq}, got {actual_seq}. Generated correct: {generated}")
    
    dut._log.info("All tests passed!")
