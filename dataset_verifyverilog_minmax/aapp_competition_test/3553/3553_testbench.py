import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, Timer

@cocotb.test()
async def test_subarray_finder(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset sequence
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test case 1: Original sample scaled
    test_queries = [
        # Query 2
        {'type':1, 'pos':0, 'val':0, 'expected': 3},
        
        # Update p=3 (0-indexed) to 3
        {'type':0, 'pos':2, 'val':3},
        
        # Query 2
        {'type':1, 'pos':0, 'val':0, 'expected':15},
        
        # Update p=1 to 1
        {'type':0, 'pos':0, 'val':1},
        
        # Query 2
        {'type':1, 'pos':0, 'val':0, 'expected':4}
    ]
    
    passed = 0
    dut.start.value = 0
    await RisingEdge(dut.clk)
    
    # Initial array setup (2,3,1,2)
    for i,val in enumerate([2,3,1,2]):
        dut.query_type.value = 0
        dut.position.value = i
        dut.value.value = val
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        await RisingEdge(dut.done)
        await RisingEdge(dut.clk)
    
    for i,q in enumerate(test_queries):
        dut.query_type.value = q['type']
        dut.position.value = q.get('pos',0)
        dut.value.value = q.get('val',0)
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        await RisingEdge(dut.done)
        
        if 'expected' in q:
            if dut.result.value == q['expected']:
                passed += 1
            else:
                dut._log.error(f"TEST {i} FAILED: Got {dut.result.value}, Expected {q['expected']}")
        await RisingEdge(dut.clk)
    
    # Test summary
    total_queries = len([q for q in test_queries if 'expected' in q])
    dut._log.info(f"PASSED {passed}/{total_queries} tests")
    assert passed == total_queries, f"Failed {total_queries-passed} tests"