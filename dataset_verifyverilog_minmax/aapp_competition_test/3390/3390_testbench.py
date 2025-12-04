import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock

@cocotb.test()
async def test_longest_path(dut):
    # Generate clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Test cases (scaled-down from problem examples)
    test_cases = [
        # Test case 1: Original sample input (n=4, edges 1->2,2->3,2->4)
        {
            "n": 4, "adj": (15 << 1) | (15 << 10) | (15 << 11),
            "expected": 3
        },
        # Test case 2: 7-node chain (paths limited by input n)
        {
            "n": 7,
            "adj": (0x7F << 1) | (0x7F << 9) | (0x7F << 17) | (0x7F << 25) | \
                      (0x7F << 33) | (0x7F << 41) | (0x7F << 49),
            "expected": 7 # Straight line path length matches node count
        },
        # Test case 3: Fully disconnected graph (max path=1)
        {
            "n": 5,
            "adj": 0,
            "expected": 1
        }
    ]
    
    passed = 0
    for case in test_cases:
        # Reset device
        dut.rst_n.value = 0
        dut.start.value = 0
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
        
        # Load inputs
        dut.n.value = case["n"]
        dut.adjacency.value = case["adj"]
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for completion
        while not dut.done.value:
            await RisingEdge(dut.clk)
        
        # Verify result
        if dut.max_path_length.value == case["expected"]:
            passed += 1
        else:
            dut._log.error(f"Failed: n={case['n']} adj=0x{case['adj']:X} \
                Got:{dut.max_path_length.value} Expected:{case['expected']}")
    
    dut._log.info(f"{passed}/{len(test_cases)} test cases passed")
