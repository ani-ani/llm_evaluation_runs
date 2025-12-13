import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
import random

def array_to_str(arr):
    return '[' + ', '.join([str(x) for x in arr]) + ']'

@cocotb.test()
async def test_common(dut):
    # Test cases
    tests = [
        # Original scaled cases
        {'l1': [1,4,3,34,653,2,5,0], 'len1':7, 'l2': [5,7,1,5,9,653,121,0], 'len2':7, 'expected': [1,5,653]},
        {'l1': [5,3,2,8,0,0,0,0], 'len1':4, 'l2': [3,2,0,0,0,0,0,0], 'len2':2, 'expected': [2,3]},
        # Additional cases
        {'l1': [4,3,2,8,0,0,0,0], 'len1':4, 'l2': [3,2,4,0,0,0,0,0], 'len2':3, 'expected': [2,3,4]},
        {'l1': [4,3,2,8,0,0,0,0], 'len1':4, 'l2': [0,0,0,0,0,0,0,0], 'len2':0, 'expected': []},
        # Max test
        {'l1': [65535]*8, 'len1':0, 'l2': [65535]*8, 'len2':0, 'expected': []},        
    ]

    passed = 0
    failed_log = []
    dut._log.info("Starting testing")
    
    # Generate clock
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    
    for i, test in enumerate(tests):
        # Reset
        dut.rst_n.value = 0
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
        
        # Setup inputs
        for j in range(8):
            dut.l1[j].value = test['l1'][j]
            dut.l2[j].value = test['l2'][j]
        dut.len1.value = test['len1']
        dut.len2.value = test['len2']
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        while not dut.done.value:
            await RisingEdge(dut.clk)
        
        # Check results
        expected = sorted(test['expected'])
        result = []
        for j in range(int(dut.result_len.value)):
            result.append(int(dut.result[j].value))
            
        if expected == sorted(result):
            passed += 1
            dut._log.info(f"Test {i+1} PASS: Expected {expected}, Got {result}")
        else:
            fail_msg = f"Test {i+1} FAIL: Input1 {test['l1'][:test['len1']]} ({test['len1']}) | Input2 {test['l2'][:test['len2']]} ({test['len2']}) | Expected {expected}, Got {result}"
            failed_log.append(fail_msg)
            dut._log.error(fail_msg)
        
    dut._log.info(f"Results: {passed}/{len(tests)} tests passed")
    assert passed == len(tests), f"{len(tests)-passed} tests failed
" + '
'.join(failed_log)