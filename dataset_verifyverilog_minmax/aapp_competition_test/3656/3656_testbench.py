import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, Timer

@cocotb.test()
async def test_bug_fix(dut):
    # Create clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Test cases (scaled from originals with B=2/T=2)
    test_cases = [
        # Test 1: 1 bug, 2 hours (converted to B=2 with p2=0/s2=0)
        {'f': 0.95, 'p': [0.7, 0.0], 's': [50, 0], 'expected': 44.975},
        # Test 2: 2 bugs, 2 hours (using sample input)
        {'f': 0.5, 'p': [0.75, 0.75], 's': [100, 20], 'expected': 95.625}
    ]
    
    passed = 0
    for idx, test in enumerate(test_cases):
        # Reset
        dut.rst_n.value = 0
        dut.start.value = 0
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
        
        # Convert inputs to Q16.16 format
        f_fixed = int(test['f'] * (1 << 16))
        p_fixed = [int(x * (1 << 16)) for x in test['p']]
        
        # Load inputs
        dut.f.value = f_fixed
        for i in range(2):
            dut.p[i].value = p_fixed[i]
            dut.s[i].value = test['s'][i]
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done (4 cycles + 1 for output)
        for _ in range(5):
            await RisingEdge(dut.clk)
        
        # Convert output back to float
        result = dut.expected_severity.value.integer / (1 << 16)
        
        # Check with 0.1% tolerance
        expected = test['expected']
        if abs(result - expected)/expected < 0.001:
            passed += 1
        else:
            dut._log.error(f"Test {idx} failed: Expected {expected}, got {result}")
    
    # Summary
    total = len(test_cases)
    dut._log.info(f"{passed}/{total} tests passed")
    if passed < total:
        raise cocotb.result.TestFailure()