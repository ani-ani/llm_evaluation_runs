import cocotb
from cocotb.triggers import RisingEdge, FallingEdge, Timer
from cocotb.clock import Clock
import random

@cocotb.test()
async def test_photo_filter(dut):
    clock = Clock(dut.clk, 10, units="ns")  
    cocotb.start_soon(clock.start())
    
    # Test cases (adapted to 16 elements max)
    test_photos = [
        # Test 1: Valid case (Sample Input 1)
        {'n': 3, 'heights': [2,1,3], 'expected': 1},
        # Test 2: Valid photo from Sample 2 (Photo 2: 15,24,38,9,30 - valid at i=1 (24), left=15 (<24 false!), need correction)
        # Corrected test case to match problem logic
        {'n': 5, 'heights': [30,15,38,24,9], 'expected': 1},  # i=2 (38): left_max=30<38? no. i=3: left_max=38>24, right_max=9<38→invalid
        # Photo 4 from Sample 2: 170,230,320,180,250,210 → valid
        {'n': 6, 'heights': [170,230,320,180,250,210], 'expected': 1},  # i=3 (180): left_max=320>180→false; i=4: left_max=320>250→no. Actually valid at i=0, but Alice must be taller than me. Fix test data:
        {'n': 6, 'heights': [180,230,320,170,250,210], 'expected': 0},  # No valid position
        # Additional test cases
        {'n': 4, 'heights': [10,20,5,30], 'expected': 1},  # i=1 (20): left=10<20→invalid. i=2 (5): left_max=20>5, right_max=30>20→VALID
        {'n': 4, 'heights': [40,30,20,10], 'expected': 0}   # Decreasing order→invalid
    ]
    
    # Reset sequence
    dut.rst_n.value = 0
    dut.start.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    passed = 0
    for idx, test in enumerate(test_photos):
        # Load test data
        dut.start.value = 1
        dut.n.value = test['n']
        for i in range(16):
            if i < len(test['heights']):
                dut.heights[i].value = test['heights'][i]
            else:
                dut.heights[i].value = 0  
        
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for processing to complete (16 cycles)
        for _ in range(16):
            await RisingEdge(dut.clk)
        
        # Check result
        if dut.valid.value == test['expected']:
            passed += 1
        else:
            dut._log.error(f"Test {idx} failed: n={test['n']} heights={test['heights']}
                Expected {test['expected']} Got {dut.valid.value}")
        
        # Wait a few cycles between tests
        for _ in range(2):
            await RisingEdge(dut.clk)
    
    dut._log.info(f"{passed}/{len(test_photos)} tests passed")
