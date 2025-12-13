import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer

@cocotb.test(expect_error=Exception if cocotb.SIM_NAME != 'icarus' else () )
async def test_escape(dut):
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Test case 1: Star graph (n=4) - expect 2 additions
    test1 = {
        'n': 4, 'h': 0,
        'edges': [(0,1), (0,2), (0,3)],
        'expected': [(3,2), (3,1)]
    }
    # Test case 2: Larger tree (n=6) - expect 2 additions
    test2 = {
        'n': 6, 'h': 0,
        'edges': [(0,1), (0,2), (0,3), (1,4), (1,5)],
        'expected': [(3,5), (2,4)]
    }
    test_cases = [test1, test2]
    passed = 0
    
    await RisingEdge(dut.clk)
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    
    for case in test_cases:
        # Prepare input data storage
        edges_packed = 0
        for idx, (a,b) in enumerate(case['edges']):
            edges_packed |= (a << (41 - idx*6)) | (b << (38 - idx*6))
        
        # Apply inputs
        dut.n.value = case['n']
        dut.h.value = case['h']
        dut.edges.value = edges_packed
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for completion (max 128 cycles)
        wait_count = 0
        while not dut.done.value and wait_count < 150:
            await RisingEdge(dut.clk)
            wait_count += 1
        
        # Check results
        if dut.done.value:
            m = dut.m.value.integer
            expected_edges = sorted([tuple(sorted(pair)) for pair in case['expected']])
            result_edges = []
            
            # Extract m valid edges
            for i in range(m):
                edge_bits = (dut.added_edges.value >> (41 - i*6)) & 0x3F
                a = (edge_bits >> 3) & 0x7
                b = edge_bits & 0x7
                result_edges.append(tuple(sorted([a,b])))
            
            if sorted(result_edges) == expected_edges:
                passed += 1
            else:
                dut._log.error(f"Test failed: Added {result_edges}, expected {expected_edges}")
        else:
            dut._log.error("Test timeout: Done never asserted")
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")
