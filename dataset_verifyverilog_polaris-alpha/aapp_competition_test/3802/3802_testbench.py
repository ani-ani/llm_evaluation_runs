import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
import random

@cocotb.test()
async def test_virus_lcs(dut):
    # Generate clock
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    await Timer(20, units='ns')
    
    # Test cases (scaled to 8 chars)
    test_cases = [
        # Original: AJKEQSLOBSROFGZ -> AJKEQSLO, OVGURWZLWVLUXTH -> OVGURWZL
        { 
            's1': b'AJKEQSLO', 
            's2': b'OVGURWZL', 
            'virus': b'OZ', 
            'expected': b'ORZ', 
            'valid': 1 
        },
        { 
            's1': b'AA', 
            's2': b'A', 
            'virus': b'A', 
            'expected': b'', 
            'valid': 0 
        },
        { 
            's1': b'ABABABB', 
            's2': b'ABABABB', 
            'virus': b'ABABB', 
            'expected': b'ABABAB', 
            'valid': 1 
        },
        { 
            's1': b'BCBCBC', 
            's2': b'BCBCBC', 
            'virus': b'BC', 
            'expected': b'CCCCCC', 
            'valid': 1 
        },
        { # Empty case 
            's1': b'ABCDEFGH', 
            's2': b'IJKLMNOP', 
            'virus': b'', 
            'expected': b'', 
            'valid': 0 
        }
    ]
    
    passed = 0
    for case in test_cases:
        # Reset module
        dut.rst_n.value = 0
        dut.start.value = 0
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
        
        # Load inputs
        for i in range(8):
            dut.s1[i].value = case['s1'][i] if i < len(case['s1']) else 0
            dut.s2[i].value = case['s2'][i] if i < len(case['s2']) else 0
            dut.virus[i].value = case['virus'][i] if i < len(case['virus']) else 0
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for completion (max 600 cycles)
        for _ in range(600):
            await RisingEdge(dut.clk)
            if dut.done.value == 1:
                break
        
        # Verify outputs
        if dut.valid.value != case['valid']:
            dut._log.error(f"Valid mismatch: Got {dut.valid.value}, Expected {case['valid']}")
        else:
            if case['valid']:
                result_bytes = bytes([dut.result.value >> (i*8) & 0xFF for i in range(8)])
                result_str = result_bytes.rstrip(b'\\x00').decode('ascii')
                if result_str == case['expected'].decode('ascii'):
                    passed += 1
                else:
                    dut._log.error(f"Result mismatch: Got '{result_str}', Expected '{case['expected'].decode('ascii')}'")
            else:
                passed += 1
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")