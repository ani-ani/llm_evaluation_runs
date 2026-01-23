import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
import math

@cocotb.test()
async def test_triangular_index(dut):
    """Test triangular index calculation for n=1 to 4"""
    
    # Setup clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.n.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Expected results
    test_cases = [
        (1, 1),  # sqrt(2*10^0) = sqrt(2) ≈ 1.414
        (2, 4),  # sqrt(2*10^1) = sqrt(20) ≈ 4.472
        (3, 14), # sqrt(2*10^2) = sqrt(200) ≈ 14.142
        (4, 45), # sqrt(2*10^3) = sqrt(2000) ≈ 44.721
    ]
    
    passed = 0
    total = len(test_cases)
    
    for n, expected in test_cases:
        dut.n.value = n
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done signal
        timeout = 100
        for _ in range(timeout):
            if dut.done.value == 1:
                break
            await RisingEdge(dut.clk)
        
        actual = int(dut.result.value)
        print(f"n={n}: Expected={expected}, Got={actual}")
        assert actual == expected, f"Test failed for n={n}: expected {expected}, got {actual}"
        passed += 1
        await RisingEdge(dut.clk)
    
    print(f"
{passed}/{total} tests passed")