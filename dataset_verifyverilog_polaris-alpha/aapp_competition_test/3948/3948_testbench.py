import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer

@cocotb.test()
async def test_hedgehog(dut):
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    test_cases = [
        # Test 1: Valid 2-multihedgehog (scaled version)
        {'n':14, 'k':2, 'adj':(
            '0b' + '0'*208 + 
            '1'*4 + '0'*12 + '0001' + '0'*12 + '0001' + '0'*12 + '0001' + '0'*12 +  # nodes 1-4 connected to 13
            '00000000010000100000000000000000'*8  # lower nodes connections
        ), 'exp':1},
        # Test 2: Invalid 1-multihedgehog (center degree=2)
        {'n':3, 'k':1, 'adj':(
            '0b0000000000000010' + '0'*240 +  # node1 connected to 3
            '0b0000000000000100' + '0'*240 +  # node2 connected to 3
            '0b0000000000000011' + '0'*240     # node3 has two edges
        ), 'exp':0},
        # Test 3: Valid 1-multihedgehog (4 edges from center)
        {'n':5, 'k':1, 'adj':(
            '0b0000000000000001' + '0'*240 +  # node1 connected to 5
            '0b0000000000000010' + '0'*240 +  # node2 connected to 5
            '0b0000000000000100' + '0'*240 +  # node3 connected to 5
            '0b0000000000001000' + '0'*240 +  # node4 connected to 5
            '0b1111000000000000' + '0'*240     # node5 has four edges
        ), 'exp':1},
    ]
    passed = 0
    dut.rst_n.value = 0
    await Timer(15, units='ns')
    dut.rst_n.value = 1
    for test in test_cases:
        dut.start.value = 0
        dut.num_nodes.value = test['n']
        dut.k_value.value = test['k']
        dut.adjacency.value = int(test['adj'],2)
        await RisingEdge(dut.clk)
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        await cocotb.triggers.ReadOnly()
        while not dut.done.value:
            await RisingEdge(dut.clk)
        if dut.result.value == test['exp']:
            passed += 1
        else:
            dut._log.error(f"Test failed: n={test['n']}, k={test['k']} -> {dut.result.value}, expected {test['exp']}")
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")
