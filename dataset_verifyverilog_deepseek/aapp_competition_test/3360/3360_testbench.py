import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
import random

@cocotb.test()
async def test_cfg_matcher(dut):
    # Create clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Helper function to pack rules
    def pack_rule(head, production):
        rule = (ord(head) - ord('A')) & 0x1F
        for i, c in enumerate(production[:4]):
            if c.isupper():
                val = (1 << 6) | ((ord(c) - ord('A')) & 0x1F)
            else:
                val = ((ord(c) - ord('a')) & 0x3F) if c != ' ' else 0
            rule |= val << (7 + i*7)
        return rule
    
    # Test cases (scaled to 16 chars)
    test_cases = [
        { # Test 1: Palindrome grammar (original abaaba)
            'rules': [
                ('S', "aSa"), ('S', "bSb"), ('S', "a"), ('S', "b"), ('S', "")
            ],
            'text': "abaaba palindromes"[:16],
            'expected': "abaaba",
            'valid': True
        },
        { # Test 2: No match
            'rules': [('S', "xyz")],
            'text': "no matches here",
            'expected': "",
            'valid': False
        },
        { # Test 3: Phone number pattern (original nnnxnnnxnnnn)
            'rules': [
                ('P', "AM"), ('A', "NNNx"), ('M', "NNNxNNNN"), ('N', "n")
            ],
            'text': "my nnnxnnnxnnnn here"[:16],
            'expected': "nnnxnnnxnnnn",
            'valid': True
        }
    ]
    
    passed = 0
    for case in test_cases:
        # Reset
        dut.rst_n.value = 0
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
        
        # Pack rules into 264-bit vector
        rules_packed = 0
        for i, (head, prod) in enumerate(case['rules'][:6]):  # Max 8 rules but tested with 6
            rule = pack_rule(head, prod)
            rules_packed |= rule << (i*33)
        dut.rules.value = rules_packed
        
        # Pack text
        text_packed = 0
        for i, c in enumerate(case['text'].ljust(16)[:16]):
            text_packed |= ((ord(c) - ord('a')) & 0x3F) << (i*6) if c != ' ' else 0 
        dut.text_line.value = text_packed
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done (max 300 cycles)
        for _ in range(300):
            await RisingEdge(dut.clk)
            if dut.done.value == 1:
                break
        
        # Check result
        expected_packed = 0
        for i, c in enumerate(case['expected'].ljust(16)[:16]):
            expected_packed |= ((ord(c) - ord('a')) & 0x3F) << (i*6) if c != ' ' else 0 
        
        if dut.valid.value == case['valid'] and 
           dut.longest_substr.value == expected_packed:
            passed += 1
        else:
            dut._log.error(
                f"Test failed: Text='{case['text']}' Expected='{case['expected']}' Valid={case['valid']}" + 
                f" Got='{dut.longest_substr.value}' Valid={dut.valid.value}")
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")