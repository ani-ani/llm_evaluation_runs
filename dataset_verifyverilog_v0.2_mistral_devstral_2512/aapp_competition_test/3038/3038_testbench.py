import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from cocotb.result import TestFailure

@cocotb.test()
async def test_bolt_packer(dut):
    """Test the bolt_packer module with sample inputs"""
    
    # Create clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.config_valid.value = 0
    dut.B.value = 0
    dut.num_companies.value = 0
    dut.company_index.value = 0
    dut.num_packs.value = 0
    for i in range(10):
        dut.pack_size[i].value = 0
    
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test case 1: B=310, should output 300
    print("Test case 1: B=310, companies: [40,65], [100,150], [300,320]")
    await configure_and_solve(dut, 310, [
        [40, 65],
        [100, 150],
        [300, 320]
    ])
    
    if dut.found.value and not dut.impossible.value:
        result = int(dut.min_advertised.value)
        print(f"Result: {result}")
        assert result == 300, f"Expected 300, got {result}"
    else:
        raise TestFailure("Expected found=1, impossible=0")
    
    # Test case 2: B=371, should be impossible
    print("
Test case 2: B=371, same companies")
    dut.rst_n.value = 0
    await Timer(20, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    await configure_and_solve(dut, 371, [
        [40, 65],
        [100, 150],
        [300, 320]
    ])
    
    assert dut.impossible.value == 1, f"Expected impossible=1 for B=371"
    print("Correctly reported impossible")
    
    # Test case 3: B=90, should output 88
    print("
Test case 3: B=90, companies: [20,35], [88,200]")
    dut.rst_n.value = 0
    await Timer(20, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    await configure_and_solve(dut, 90, [
        [20, 35],
        [88, 200]
    ])
    
    if dut.found.value and not dut.impossible.value:
        result = int(dut.min_advertised.value)
        print(f"Result: {result}")
        assert result == 88, f"Expected 88, got {result}"
    else:
        raise TestFailure("Expected found=1, impossible=0")
    
    # Test case 4: B=91, should output 200
    print("
Test case 4: B=91, same companies")
    dut.rst_n.value = 0
    await Timer(20, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    await configure_and_solve(dut, 91, [
        [20, 35],
        [88, 200]
    ])
    
    if dut.found.value and not dut.impossible.value:
        result = int(dut.min_advertised.value)
        print(f"Result: {result}")
        assert result == 200, f"Expected 200, got {result}"
    else:
        raise TestFailure("Expected found=1, impossible=0")
    
    print("
All 4/4 tests passed!")

async def configure_and_solve(dut, B, companies):
    """Helper to configure companies and run solver"""
    # Set B and num companies
    dut.B.value = B
    dut.num_companies.value = len(companies)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for CONFIG state
    await Timer(100, units='ns')
    
    # Load each company's packs
    for company_idx, packs in enumerate(companies):
        dut.company_index.value = company_idx
        dut.num_packs.value = len(packs)
        for i in range(10):
            if i < len(packs):
                dut.pack_size[i].value = packs[i]
            else:
                dut.pack_size[i].value = 0
        
        dut.config_valid.value = 1
        await RisingEdge(dut.clk)
        dut.config_valid.value = 0
        await RisingEdge(dut.clk)
    
    # Wait for completion
    timeout = 0
    while not dut.done.value and timeout < 2000:
        await RisingEdge(dut.clk)
        timeout += 1
    
    if timeout >= 2000:
        raise TestFailure("Timeout - computation did not complete")
