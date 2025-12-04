import cocotb
from cocotb.triggers import RisingEdge, ClockCycles
from cocotb.clock import Clock
import random

@cocotb.test()
async def test_mst(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset sequence
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 2)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test case 1: 3 nodes, 3 edges, needs 2 mix edges
    test_config = {
        'num_nodes': 3,
        'num_edges': 3,
        'num_special': 1,
        'required_mix_edges': 2,
        'special1': 2,
        'special2': 0,
        'special3': 0,
        'edge1_a': 1, 'edge1_b': 2, 'edge1_cost': 2,
        'edge2_a': 1, 'edge2_b': 3, 'edge2_cost': 1,
        'edge3_a': 2, 'edge3_b': 3, 'edge3_cost': 3,
        'expected_cost': 5
    }
    
    # Apply test case
    await apply_test_case(dut, test_config)
    
    # Verify output
    await ClockCycles(dut.clk, 128)
    assert dut.done.value == 1, "Timeout waiting for done"
    if dut.error.value == 0:
        assert dut.total_cost.value == test_config['expected_cost'], "Cost mismatch: %d vs expected %d" % (dut.total_cost.value, test_config['expected_cost'])
    else:
        assert False, "Valid solution should exist"
    
    # Test case 2: Impossible configuration
uut._log.info("Test 2 running...")
    test_config = {
        'num_nodes': 3,
        'num_edges': 1,
        'num_special': 1,
        'required_mix_edges': 1,
        'special1': 2,
        'edge1_a': 1, 'edge1_b': 2, 'edge1_cost': 2,
        'expected_cost': -1
    }
    await apply_test_case(dut, test_config)
    await ClockCycles(dut.clk, 128)
    assert dut.error.value == 1, "Should detect impossible"
    
    # Test case 3: 4 nodes with 2 mix requirement
    test_config = {
        'num_nodes': 4,
        'num_edges': 5,
        'num_special': 2,
        'special1': 1,
        'special2': 2,
        'required_mix_edges': 2,
        'edge1_a': 1, 'edge1_b': 3, 'edge1_cost': 5,
        'edge2_a': 2, 'edge2_b': 4, 'edge2_cost': 10,
        'edge3_a': 3, 'edge3_b': 4, 'edge3_cost': 8,
        'edge4_a': 1, 'edge4_b': 2, 'edge4_cost': 1,
        'edge5_a': 1, 'edge5_b': 4, 'edge5_cost': 3,
        'expected_cost': 16
    }
    await apply_test_case(dut, test_config)
    await ClockCycles(dut.clk, 128)
    if dut.error.value:
        assert False, "Valid solution exists"
    assert dut.total_cost.value == 16, "Cost should be 16"

async def apply_test_case(dut, tc):
    dut.start.value = 0
    await RisingEdge(dut.clk)
    # Set all inputs
    dut.num_nodes.value = tc['num_nodes']
    dut.num_edges.value = tc['num_edges']
    dut.num_special.value = tc['num_special']
    dut.required_mix_edges.value = tc['required_mix_edges']
    dut.special1.value = tc['special1']
    dut.special2.value = tc.get('special2', 0)
    dut.special3.value = tc.get('special3', 0)
    # Map edges 1-8
    for i in range(1, 9):
        if f'edge{i}_a' in tc:
            getattr(dut, f'edge{i}_a').value = tc[f'edge{i}_a']
            getattr(dut, f'edge{i}_b').value = tc[f'edge{i}_b']
            getattr(dut, f'edge{i}_cost').value = tc[f'edge{i}_cost']
        else:
            getattr(dut, f'edge{i}_a').value = 0
            getattr(dut, f'edge{i}_b').value = 0
            getattr(dut, f'edge{i}_cost').value = 0
    # Start pulse
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    await RisingEdge(dut.clk)