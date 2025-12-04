import cocotb
from cocotb.triggers import RisingEdge, ClockCycles
from cocotb.clock import Clock

@cocotb.test()
async def test_sublist(dut):
    # Define helper for preparing test arrays
    def pack_array(arr):
        val = 0
        for i, num in enumerate(arr):
            val |= (num & 0xF) << (i*4)
        return val
    
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Original test cases adapted
    test_cases = [
        ([1,4,3,5], [1,2], 3, 1, False),  # Test 1
        ([1,2,1], [1,2,1], 2, 2, True),    # Test 2
        ([1,0,2,2], [2,2,0], 3, 2, False) # Test 3
    ]
    passed = 0
    total = len(test_cases)
    
    await RisingEdge(dut.clk)
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 2)
    dut.rst_n.value = 1
    
    for A, B, ena, enb, expected in test_cases:
        # Apply test vectors
        dut.array_A.value = pack_array(A)
        dut.array_B.value = pack_array(B)
        dut.ENA.value = ena
        dut.ENB.value = enb
        dut.start.value = 1
        
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait max 4 cycles + 1 for done
        max_wait = 5
        while max_wait > 0 and not dut.done.value:
            await RisingEdge(dut.clk)
            max_wait -= 1
        
        assert max_wait > 0, "Timeout waiting for done"
        
        if dut.found.value == expected:
            passed += 1
            dut._log.info(f"PASS: {A} vs {B} => {expected}")
        else:
            dut._log.error(f"FAIL: {A} vs {B} => {dut.found.value}, expected {expected}")
        
        await RisingEdge(dut.clk)
    
    dut._log.info(f"{passed}/{total} tests passed")
    assert passed == total, "Some tests failed"