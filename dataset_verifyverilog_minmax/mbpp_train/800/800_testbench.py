import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
import random

@cocotb.test()
async def test_space_remover(dut):
    # Generate 48MHz clock
    clock = Clock(dut.clk, 20.83, units="ns")  # ~48MHz
    cocotb.start_soon(clock.start())
    
    # Reset sequence
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases adapted for 16-byte limit
    test_cases = [
        {'input': b'python  program\\x00',  'len':13, 'expected':b'pythonprogram\\x00'},
        {'input': b'   py\\x00',            'len':5,  'expected':b'py\\x00'},
        {'input': b'a       b          c\\x00', 'len':16, 'expected':b'abc\\x00'},
        {'input': b'nospaceshere\\x00',     'len':12, 'expected':b'nospaceshere\\x00'},
        {'input': b'    \\x00',             'len':4,  'expected':b''}
    ]
    
    passed = 0
    for test in test_cases:
        # Initialize
        dut.start.value = 0
        await RisingEdge(dut.clk)
        
        # Apply test case
        dut.start.value = 1
        input_str = test['input']
        expected = test['expected']
        dut.len.value = test['len']
        
        # Feed characters one per cycle
        for i in range(test['len']):
            dut.data.value = input_str[i]
            await RisingEdge(dut.clk)
            dut.start.value = 0  # Only first start matters
        
        # Wait for completion
        while not dut.done.value:
            await RisingEdge(dut.clk)
        
        # Verify output
        result_bytes = dut.result.value.buff
        out_len = dut.out_len.value.integer
        expected_bytes = expected.ljust(16, b'\\x00')
        
        # Compare only relevant length
        result_valid = result_bytes[0:out_len] == expected_bytes[0:out_len]
        
        if result_valid and (out_len == len(expected)):
            passed +=1
            dut._log.info(f"PASS: {input_str.decode('ascii')} -> {expected.decode('ascii')}")
        else:
            dut._log.error(f"FAIL: In: '{input_str.decode('ascii')}' Out: '{result_bytes[0:out_len].decode('ascii')}' Exp: '{expected.decode('ascii')}'")
        
        # Wait a cycle between tests
        await RisingEdge(dut.clk)
    
    dut._log.info(f"TEST SUMMARY: {passed}/{len(test_cases)} tests passed")