import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, Timer

@cocotb.test()
async def test_chemical_minimizer(dut):
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    test_cases = [
        # Test 1: 2x2 grid with 3 elements (scaled to 16x16)
        {'n':16, 'm':16, 'q':3, 'elements':[(15,15), (0,15), (15,0)], 'expected':0},
        # Test 2: 1x5 grid with 3 elements (1x16)
        {'n':16, 'm':1, 'q':3, 'elements':[(0,0), (0,0), (0,0)], 'expected':14}, // All same, still need 14
        # Test 3: 4x3 grid with 6 elements (16x16)
        {'n':16, 'm':3, 'q':6, 'elements':[(15,1), (15,2), (14,1), (14,2), (13,0), (13,2)], 'expected':0}
    ]
    
    passed = 0
    dut._log.info(f'Starting {len(test_cases)} tests')
    
    for case in test_cases:
        # Reset sequence
        dut.rst_n.value = 0
        dut.start.value = 0
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
        
        # Load inputs
        dut.n.value = case['n']
        dut.m.value = case['m']
        dut.q.value = case['q']
        
        # Flatten element array (pack row/col into 10 bits per element)
        for i in range(32):
            if i < case['q']:
                r = case['elements'][i][0]
                c = case['elements'][i][1]
                dut.elements[i].value = (r << 5) | c
            else:
                dut.elements[i].value = 0
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for completion (34 cycles)
        for _ in range(34):
            await RisingEdge(dut.clk)
        
        # Check result
        if dut.done.value == 1:
            result = dut.minimal_purchases.value
            if int(result) == case['expected']:
                passed += 1
            else:
                dut._log.error(f"Test failed: Expected {case['expected']}, got {result}
Test params: n={case['n']}, m={case['m']}, q={case['q']}")
        else:
            dut._log.error(f"Done signal not asserted after 34 cycles")
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")