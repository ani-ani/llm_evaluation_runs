import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer, FallingEdge
from cocotb.result import TestFailure

@cocotb.test()
async def test_bell_number(dut):
    """Test Bell number computation for N=0 to N=8"""
    
    # Create clock (10ns period = 100MHz)
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset sequence
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.n.value = 0
    await Timer(25, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Expected Bell numbers for N=0 to N=8
    expected = [1, 1, 2, 5, 15, 52, 203, 877, 4140]
    
    passed = 0
    total = len(expected)
    
    for n_val, exp_val in enumerate(expected):
        # Set inputs
        dut.n.value = n_val
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for computation to complete
        timeout = 20  # max cycles to wait
        for _ in range(timeout):
            if dut.done.value == 1:
                break
            await RisingEdge(dut.clk)
        else:
            raise TestFailure(f"N={n_val}: Done signal not asserted within {timeout} cycles")
        
        # Check result
        result = int(dut.result.value)
        if result == exp_val:
            print(f"N={n_val}: PASS (result={result})")
            passed += 1
        else:
            print(f"N={n_val}: FAIL (expected={exp_val}, got={result})")
            raise TestFailure(f"N={n_val}: Expected {exp_val}, got {result}")
        
        await RisingEdge(dut.clk)
    
    # Test invalid input (N=15 > 8)
    dut.n.value = 15
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    await RisingEdge(dut.clk)
    timeout = 20
    for _ in range(timeout):
        if dut.done.value == 1:
            break
        await RisingEdge(dut.clk)
    
    result = int(dut.result.value)
    if result == 0:
        print(f"N=15 (invalid): PASS (result=0 as expected)")
        passed += 1
    else:
        print(f"N=15 (invalid): FAIL (expected=0, got={result})")
    
    total += 1
    
    print(f"
{passed}/{total} tests passed")
    assert passed == total, f"Test failed: {passed}/{total} passed"
