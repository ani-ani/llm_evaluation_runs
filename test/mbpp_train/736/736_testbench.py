import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, Timer

@cocotb.test()
async def test_bisect(dut):
    # Generate clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    # Reset sequence
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    test_cases = [
        # (array, value, expected_index)
        ([1,2,4,5,0,0,0,0], 6, 4),
        ([1,2,4,5,0,0,0,0], 3, 2),
        ([1,2,4,5,0,0,0,0], 7, 4),
        # Edge cases
        ([1,3,5,7,9,11,13,15], 0, 0),
        ([1,3,5,7,9,11,13,15], 16, 8)
    ]

    passed = 0
    for arr, val, exp_idx in test_cases:
        # Load array inputs (flat concatenation)
        dut.array.value = (arr[7] << 28) | (arr[6] << 24) | (arr[5] << 20) | (arr[4] << 16) | 
                         (arr[3] << 12) | (arr[2] << 8)  | (arr[1] << 4)  | arr[0]
        
        dut.start.value = 1
        dut.value.value = val
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait 5 cycles
        for _ in range(5):
            await RisingEdge(dut.clk)
        
        if dut.index.value == exp_idx:
            passed += 1
            dut._log.info(f"PASS: {val}->{exp_idx}")
        else:
            dut._log.error(f"FAIL: {dut.index.value} vs {exp_idx} (value={val})")
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")