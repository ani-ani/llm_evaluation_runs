import cocotb
from cocotb.triggers import Timer
import struct

def float_to_q16(f):
    return int(f * (1<<16)) & 0xFFFFFFFF

@cocotb.test()
async def test_top_n(dut):
    passed = 0
    
    # Test 1: n=1 (2 items)
    items = [float_to_q16(101.1), float_to_q16(555.22), 0, 0]
    expected = [float_to_q16(555.22), 0, 0]
    dut.item_prices.value = (items[3] << 96) | (items[2] << 64) | (items[1] << 32) | items[0]
    dut.n.value = 1
    await Timer(1, 'ns')
    result = dut.top_prices.value
    top = [(result >> 64) & 0xFFFFFFFF, (result >> 32) & 0xFFFFFFFF, result & 0xFFFFFFFF]
    if top == expected:
        passed +=1
        dut._log.info("PASS Test 1")
    else:
        dut._log.error(f"FAIL Test 1: Got {top} expected {expected}")
    
    # Test 2: n=2 (3 items)
    items = [float_to_q16(101.1), float_to_q16(555.22), float_to_q16(45.09), 0]
    expected = [float_to_q16(555.22), float_to_q16(101.1), 0]
    dut.item_prices.value = (items[3] << 96) | (items[2] << 64) | (items[1] << 32) | items[0]
    dut.n.value = 2
    await Timer(1, 'ns')
    result = dut.top_prices.value
    top = [(result >> 64) & 0xFFFFFFFF, (result >> 32) & 0xFFFFFFFF, result & 0xFFFFFFFF]
    if top == expected:
        passed +=1
        dut._log.info("PASS Test 2")
    else:
        dut._log.error(f"FAIL Test 2: Got {top} expected {expected}")
    
    # Test 3: n=1 (4 items)
    items = [float_to_q16(101.1), float_to_q16(555.22), float_to_q16(45.09), float_to_q16(22.75)]
    expected = [float_to_q16(555.22), 0, 0]
    dut.item_prices.value = (items[3] << 96) | (items[2] << 64) | (items[1] << 32) | items[0]
    dut.n.value = 1
    await Timer(1, 'ns')
    result = dut.top_prices.value
    top = [(result >> 64) & 0xFFFFFFFF, (result >> 32) & 0xFFFFFFFF, result & 0xFFFFFFFF]
    if top == expected:
        passed +=1
        dut._log.info("PASS Test 3")
    else:
        dut._log.error(f"FAIL Test 3: Got {top} expected {expected}")
    
    # Edge Case: All zeros
    items = [0,0,0,0]
    expected = [0,0,0]
    dut.item_prices.value = 0
    dut.n.value = 3
    await Timer(1, 'ns')
    result = dut.top_prices.value
    top = [(result >> 64) & 0xFFFFFFFF, (result >> 32) & 0xFFFFFFFF, result & 0xFFFFFFFF]
    if top == expected:
        passed +=1
        dut._log.info("PASS Edge Case")
    else:
        dut._log.error(f"FAIL Edge Case: Got {top} expected {expected}")
    
    dut._log.info(f"{passed}/4 tests passed")
