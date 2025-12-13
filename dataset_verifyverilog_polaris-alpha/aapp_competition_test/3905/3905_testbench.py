import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock

@cocotb.test()
async def test_min_data(dut):
    # Generate clock
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())
    
    # Test case 1: Sample input 1 scaled down
    test1_input = {
        'n': 3,
        'm': 3,
        'h': 5,
        'u_array': [4, 4, 0, 0, 0, 0, 0, 0], # Elements 0-2 used
        'client_pairs': [0x0301, 0x0203, 0x0103] + [0]*13 # Pairs (1,3),(3,2),(3,1)
    }
    test1_expected = {
        'k': 1,
        'solution_set': 0x08 # Center 3 (bit 3)
    }
    
    # Test case 2: Verification of constraints
    test2_input = {
        'n': 2,
        'm': 1,
        'h': 2,
        'u_array': [1,0,0,0,0,0,0,0],
        'client_pairs': [0x0102] + [0]*15
    }
    test2_expected = {'k': 2, 'solution_set': 0x03}
    
    tests = [
        (test1_input, test1_expected),
        (test2_input, test2_expected)
    ]
    passed = 0
    
    for idx, (inputs, expected) in enumerate(tests):
        # Apply reset
        dut.rst_n.value = 0
        dut.start.value = 0
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
        
        # Load inputs
        dut.n.value = inputs['n']
        dut.m.value = inputs['m']
        dut.h.value = inputs['h']
        for i in range(8):
            dut.u_array[i].value = inputs['u_array'][i]
        for i in range(16):
            dut.client_pairs[i].value = inputs['client_pairs'][i]
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for completion (max 256 cycles)
        timeout = 0
        while not dut.done.value and timeout < 300:
            await RisingEdge(dut.clk)
            timeout += 1
        
        if timeout >= 300:
            dut._log.error("Test %d timed out" % idx)
            continue
        
        # Check results
        success = True
        if dut.k.value != expected['k']:
            dut._log.error("Test %d: k=%d, expected %d" % (idx, dut.k.value, expected['k']))
            success = False
        if dut.solution_set.value != expected['solution_set']:
            dut._log.error("Test %d: solution_set=0x%x, expected 0x%x" % (idx, dut.solution_set.value, expected['solution_set']))
            success = False
        
        if success:
            passed += 1
            dut._log.info("Test %d passed" % idx)
    
    dut._log.info("%d/%d tests passed" % (passed, len(tests)))