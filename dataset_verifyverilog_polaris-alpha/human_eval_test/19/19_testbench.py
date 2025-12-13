import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
import random

WORD_TO_CODE = {'zero':0, 'one':1, 'two':2, 'three':3, 'four':4,
                'five':5, 'six':6, 'seven':7, 'eight':8, 'nine':9}
CODE_TO_WORD = {v:k for k,v in WORD_TO_CODE.items()}

def pack_numbers(words):
    nums = [WORD_TO_CODE[w] for w in words] if words else []
    packed = 0
    for i, num in enumerate(nums):
        packed |= num << (4*i)
    return packed, len(nums)

def unpack_numbers(packed, count):
    return [CODE_TO_WORD[(packed >> (4*i)) & 0xF] for i in range(count)]

@cocotb.test()
async def test_sorter(dut):
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    test_cases = [
        ('', ''),
        ('three', 'three'),
        ('three five nine', 'three five nine'),
        ('five zero four seven nine eight', 'zero four five seven eight nine'),
        ('six five four three two one zero', 'zero one two three four five six')
    ]
    
    passed = 0
    for input_str, expected_str in test_cases:
        input_words = input_str.split() if input_str else []
        exp_words = expected_str.split() if expected_str else []
        
        # Convert to test vectors
        packed_input, count = pack_numbers(input_words)
        exp_packed, _ = pack_numbers(exp_words)
        
        # Apply inputs
        dut.numbers.value = packed_input
        dut.count.value = count
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for completion
        while not dut.done.value:
            await RisingEdge(dut.clk)
        
        # Verify output
        result_words = unpack_numbers(int(dut.sorted.value), count)
        result_str = ' '.join(result_words)
        
        if result_str == expected_str:
            passed += 1
            dut._log.info(f"PASS: '{input_str}' -> '{result_str}'")
        else:
            dut._log.error(f"FAIL: '{input_str}' -> '{result_str}' (expected '{expected_str}')")
        
        await RisingEdge(dut.clk)  # extra cycle
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")
    assert passed == len(test_cases), "Some tests failed"