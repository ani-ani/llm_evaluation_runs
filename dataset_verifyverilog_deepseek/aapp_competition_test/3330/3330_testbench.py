import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, Timer

# Fixed-point conversion helpers
def float_to_q16_16(val):
    return int(val * 65536)

@cocotb.test()
async def test_potato(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    
    # Test case 1: Original sample scaled down
    test_inputs = {
        "N": 3,   
        "L": 1,
        "a": [3, 2, 1, 0],  # Zero-pad
        "c": [1, 2, 3, 0]   # Prices scaled down by 1e6
    }
    expected = float_to_q16_16(0.556)  # ~0.556

    # Apply inputs
    dut.N.value = test_inputs["N"]
    dut.L.value = test_inputs["L"]
    for i in range(4):
        dut.a[i].value = test_inputs["a"][i]
        dut.c[i].value = test_inputs["c"][i]
    
    # Start computation
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for completion (max 98 cycles)
    await FallingEdge(dut.done)
    await RisingEdge(dut.done)
    
    # Verification
    assert dut.min_product.value == expected, f"Test 1 failed: Got {dut.min_product.value}, expected {expected}"
    
    # Test case 2: Sample input 2
    test_inputs2 = {
        "N": 3,
        "L": 2,
        "a": [2,2,2,0],
        "c": [3,3,3,0]
    }
    expected2 = float_to_q16_16(2.25)
    
    # Apply inputs
    dut.N.value = test_inputs2["N"]
    dut.L.value = test_inputs2["L"]
    for i in range(4):
        dut.a[i].value = test_inputs2["a"][i]
        dut.c[i].value = test_inputs2["c"][i]
    
    # Start computation
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for completion
    while not dut.done.value:
        await RisingEdge(dut.clk)
    
    # Verification
    assert dut.min_product.value == expected2, f"Test 2 failed: Got {dut.min_product.value}, expected {expected2}"
    
    # Summary
    dut._log.info("2/2 tests passed")