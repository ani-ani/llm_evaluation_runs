import cocotb
 cocotbb.clock cocotb.triggers
from cocotb.triggers import RisingEdge Timer

@cocotb.test()
async def test_road_assignment(dut):
    """Test the simplified road assignment module."""
    # Create a clock
    clock = cocotb.clock.Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.city_a.value = 0
    dut.city_b.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    # Test Case 1: Example from prompt (adapted for 8 nodes, but we will use 4 for simplicity here)
    # Input: 4 edges: (1,2), (2,3), (3,1), (4,1)
    # We need to map these to the 8-slot inputs. Unused slots can be 0.
    # Note: City IDs are 1-based. 0 is invalid.
    
    # Setup Inputs
    # Edge 0: 1-2
    # Edge 1: 2-3
    # Edge 2: 3-1
    # Edge 3: 4-1
    # Edges 4-7: 0 (unused)
    
    # Create arrays for the 8 inputs
    # dut.city_a is a packed array or structure depending on simulator, but we treat it as indexable in cocotb
    # Since the prompt says input [3:0] city_a [0:7], we assign individual elements
    
    # Helper to set the array
    def set_edges(a_list, b_list):
        for i in range(8):
            if i < len(a_list):
                dut.city_a[i].value = a_list[i]
                dut.city_b[i].value = b_list[i]
            else:
                dut.city_a[i].value = 0
                dut.city_b[i].value = 0

    # Test Case 1: 4 roads
    a_in = [1, 2, 3, 4]
    b_in = [2, 3, 1, 1]
    set_edges(a_in, b_in)
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

    # Collect outputs
    outputs = []
    
    # Run for enough cycles (8 cities * checking 8 edges = 64, plus overhead)
    for _ in range(100):
        await RisingEdge(dut.clk)
        if dut.out_valid.value == 1:
            city = int(dut.out_city.value)
            road = int(dut.out_road_end.value)
            outputs.append((city, road))
            print(f"Found assignment: City {city} built road to {road}")
        if dut.out_done.value == 1:
            print("Computation done.")
            break
    
    # Verification
    # Expected: 1, 2, 3, 4 all assigned. Order depends on algorithm.
    # Valid assignments are: 1->2, 1->3; 2->1, 2->3; 3->1, 3->2; 4->1
    # We just check that we got 4 assignments and they are consistent.
    
    assert len(outputs) == 4, f"Expected 4 assignments, got {len(outputs)}"
    
    # Verify that each city appears exactly once as the builder
    builders = [x[0] for x in outputs]
    assert sorted(builders) == [1, 2, 3, 4], f"Builders mismatch: {builders}"
    
    # Verify edges exist in input
    for b, e in outputs:
        edge_found = False
        for i in range(len(a_in)):
            if (a_in[i] == b and b_in[i] == e) or (a_in[i] == e and b_in[i] == b):
                edge_found = True
                break
        assert edge_found, f"Edge ({b}, {e}) not in input"

    print("Test Case 1 Passed")

    # Reset for next test
    dut.rst_n.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    # Test Case 2: 2 cities, 2 roads (both between 1 and 2)
    # Input: 1-2, 1-2
    a_in = [1, 1]
    b_in = [2, 2]
    set_edges(a_in, b_in)

    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

    outputs = []
    for _ in range(50):
        await RisingEdge(dut.clk)
        if dut.out_valid.value == 1:
            outputs.append((int(dut.out_city.value), int(dut.out_road_end.value)))
        if dut.out_done.value == 1:
            break
    
    assert len(outputs) == 2, f"Expected 2 assignments, got {len(outputs)}"
    builders = sorted([x[0] for x in outputs])
    assert builders == [1, 2], f"Builders should be 1 and 2, got {builders}"
    print("Test Case 2 Passed")

    print(f"Summary: 2/2 tests passed")