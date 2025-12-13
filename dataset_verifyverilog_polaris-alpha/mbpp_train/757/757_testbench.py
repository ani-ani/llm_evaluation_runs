import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
import binascii

@cocotb.test()
async def test_rev_pairs(dut):
    # Test cases adapted to 8x8 max size
    test_cases = [
        # Test 1 (original: ["julia", "best", "tseb", "for", "ailuj"] -> pad to 8 chars)
        {"strings": [
            binascii.unhexlify('6a756c6961000000'),  # julia\u0000\u0000\u0000
            binascii.unhexlify('6265737400000000'),  # best\u0000...
            binascii.unhexlify('7473656200000000'),  # tseb...
            binascii.unhexlify('666f720000000000'),  # for...
            binascii.unhexlify('61696c756a000000'),  # ailuj...
            0,0,0  # padding
        ],
        "n": 5,
        "expected": 2},
        
        # Test 2
        {"strings": [
            binascii.unhexlify('6765656b73000000'),
            binascii.unhexlify('6265737400000000'),
            binascii.unhexlify('666f720000000000'),
            binascii.unhexlify('736b656567000000'),
            0,0,0,0
        ],
        "n": 4,
        "expected": 1},
        
        # Test 3
        {"strings": [
            binascii.unhexlify('6d616b6573000000'),
            binascii.unhexlify('6265737400000000'),
            binascii.unhexlify('73656b616d000000'),
            binascii.unhexlify('666f720000000000'),
            binascii.unhexlify('726f660000000000'),
            0,0,0
        ],
        "n": 5,
        "expected": 2},
        
        # Edge case: Empty input
        {"strings": [0,0,0,0,0,0,0,0], "n": 0, "expected": 0}
    ]
    
    # Create clock
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    
    passed = 0
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    for case in test_cases:
        dut.start.value = 0
        dut.n_strings.value = case["n"]
        
        # Load strings
        for i in range(8):
            dut.strings[i].value = case["strings"][i]
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        while not dut.done.value:
            await RisingEdge(dut.clk)
        
        # Check result
        if dut.count.value == case["expected"]:
            passed += 1
            dut._log.info(f"PASS: Expected {case['expected']}, got {int(dut.count.value)}")
        else:
            dut._log.error(f"FAIL: Expected {case['expected']}, got {int(dut.count.value)}")
        
        await RisingEdge(dut.clk)
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")
    assert passed == len(test_cases)