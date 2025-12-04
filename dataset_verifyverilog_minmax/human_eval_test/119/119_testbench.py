import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock

PAREN_MAP = {'(': 0, ')': 1}

def str_to_bits(s):
    return int(''.join(str(PAREN_MAP[c]) for c in s.ljust(8, '(')[:8]), 2)

@cocotb.test()
async def test_balanced(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    # Test cases (original scaled to 8 chars, padding with '(' which is neutral for balance checking)
    test_cases = [
        (['()(', ')'], 'Yes'),  # '()(    ' + ')      ' / ')      ' + '()(    '
        ([')', ')'], 'No'),     # ')      ' + ')      '
        ([')', '('], 'Yes'),    # ')      ' + '(      ' (swapped order works)
        (['(()(())', '())())'], 'No'),
        (['(()(', '()))()'], 'Yes')
    ]

    dut.rst_n.value = 0
    dut.start.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    passed = 0
    for (strs, expected) in test_cases:
        str1 = strs[0]
        str2 = strs[1]
        dut.str1_bits.value = str_to_bits(str1)
        dut.str2_bits.value = str_to_bits(str2)
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done signal
        while not dut.done.value:
            await RisingEdge(dut.clk)
        
        actual = 'Yes' if dut.result.value == 1 else 'No'
        if actual == expected:
            passed += 1
            dut._log.info(f"PASS: {strs} -> {expected}")
        else:
            dut._log.error(f"FAIL: {strs} -> {actual} (expected {expected})")
        
        await RisingEdge(dut.clk)
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")
    assert passed == len(test_cases)