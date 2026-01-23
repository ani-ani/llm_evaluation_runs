import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from cocotb.result import TestFailure

@cocotb.test()
async def test_widget_packing(dut):
    """Test widget packing module with various N values"""
    
    # Create clock (10ns period)
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.N.value = 0
    await Timer(25, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases: (N, expected_empty)
    # N=47: 7x7=49, empty=2 (but 6x8=48, empty=1 with H=6,W=8 constraint: 8≤12? yes, 8≥3? yes)
    # N=523: 23x23=529, empty=6; but 21x25=525 empty=2 (25≤42? yes, 25≥10.5? yes)
    # N=2: 1x2=2, empty=0 (H=1,W=2: 2≤2? yes, 2≥0.5? yes)
    # N=5: 2x3=6, empty=1 (H=2,W=3: 3≤4? yes, 3≥1? yes)
    # N=1: 1x1=1, empty=0
    
    test_cases = [
        (1, 0),
        (2, 0),
        (5, 1),
        (47, 1),
        (523, 2),
        (1000, 0),  # 32x32=1024 or 25x40=1000
        (65535, 1), # 256x256=65536
    ]
    
    passed = 0
    total = len(test_cases)
    
    for N, expected in test_cases:
        dut.N.value = N
        await RisingEdge(dut.clk)
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for completion (max 256*256 cycles = 65536 cycles)
        # But we'll wait up to 70000 cycles to be safe
        cycles = 0
        while not dut.done.value and cycles < 70000:
            await RisingEdge(dut.clk)
            cycles += 1
        
        if not dut.done.value:
            raise TestFailure(f"N={N}: Module did not complete within 70000 cycles")
        
        result = int(dut.min_empty.value)
        if result != expected:
            raise TestFailure(f"N={N}: Expected {expected}, got {result}")
        
        passed += 1
        print(f"Test N={N}: PASSED (empty={result})")
        await RisingEdge(dut.clk)
    
    print(f"
Summary: {passed}/{total} tests passed")
    assert passed == total, f"Only {passed}/{total} tests passed"