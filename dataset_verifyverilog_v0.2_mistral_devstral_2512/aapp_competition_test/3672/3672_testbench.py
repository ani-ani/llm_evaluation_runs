import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer

@cocotb.test()
async def test_el_garizm_coexistence(dut):
    """Test coexistence detection for 8 islands, 8 resources"""
    
    # Helper function to compute expected result
    def compute_expected(island_resources):
        # Build resource to islands mapping
        resource_to_islands = {}
        for island_idx, resources in enumerate(island_resources):
            for r in resources:
                if r not in resource_to_islands:
                    resource_to_islands[r] = []
                resource_to_islands[r].append(island_idx)
        
        # Build adjacency list for conflicts (must be opposite)
        adj = [[] for _ in range(8)]
        for r, islands in resource_to_islands.items():
            if len(islands) == 2:
                i1, i2 = islands[0], islands[1]
                adj[i1].append(i2)
                adj[i2].append(i1)
        
        # Try all 2^8 assignments
        for assignment in range(256):
            valid = True
            for r, islands in resource_to_islands.items():
                if len(islands) == 2:
                    i1, i2 = islands[0], islands[1]
                    # Check if islands are in opposite sets
                    bit1 = (assignment >> i1) & 1
                    bit2 = (assignment >> i2) & 1
                    if bit1 == bit2:  # Must be opposite
                        valid = False
                        break
            if valid:
                return 1
        return 0
    
    # Test cases
    test_cases = [
        {
            "island_resources": [
                [],      # Island 0: empty
                [2, 4],  # Island 1: resources 2, 4
                [1, 8],  # Island 2: resources 1, 8
                [8, 5],  # Island 3: resources 8, 5
                [4, 3, 7],  # Island 4: resources 4, 3, 7
                [5, 2, 6],  # Island 5: resources 5, 2, 6
                [1, 6],  # Island 6: resources 1, 6
                [7, 3]   # Island 7: resources 7, 3
            ],
            "expected": 1
        },
        {
            "island_resources": [
                [4, 3],  # Island 0
                [6],     # Island 1
                [1, 2, 6, 5, 4],  # Island 2
                [2, 5, 1, 3]  # Island 3
            ],
            "expected": 0
        },
        {
            "island_resources": [
                [1], [1], [2], [2], [], [], [], []
            ],
            "expected": 1
        },
        {
            "island_resources": [
                [1, 2], [1, 2], [], [], [], [], [], []
            ],
            "expected": 0
        },
        {
            "island_resources": [
                [1, 2], [1, 3], [2, 3], [], [], [], [], []
            ],
            "expected": 0
        }
    ]
    
    # Initialize signals
    dut.clk.value = 0
    dut.rst_n.value = 1
    dut.start.value = 0
    dut.resource_valid.value = 0
    dut.input_done.value = 0
    dut.island_idx.value = 0
    dut.resource_idx.value = 0
    
    # Start clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    for i, test in enumerate(test_cases):
        dut._log.info(f"Running test case {i+1}: Expected {test['expected']}")
        
        # Reset
        dut.rst_n.value = 0
        await Timer(25, units='ns')
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
        
        # Input phase
        for island_idx, resources in enumerate(test['island_resources']):
            for r in resources:
                # Map 1-8 to 0-7
                r_adj = r - 1
                dut.island_idx.value = island_idx
                dut.resource_idx.value = r_adj
                dut.resource_valid.value = 1
                await RisingEdge(dut.clk)
        
        dut.resource_valid.value = 0
        dut.input_done.value = 1
        await RisingEdge(dut.clk)
        dut.input_done.value = 0
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done (max 256 cycles + overhead)
        timeout = 300
        for _ in range(timeout):
            if dut.done.value == 1:
                break
            await RisingEdge(dut.clk)
        
        # Check result
        assert dut.done.value == 1, f"Test {i+1}: Done signal not asserted within timeout"
        
        actual = int(dut.result.value)
        dut._log.info(f"Test {i+1}: Result={actual}, Expected={test['expected']}")
        assert actual == test['expected'], f"Test {i+1}: Expected {test['expected']}, got {actual}"
    
    dut._log.info(f"All {len(test_cases)} tests passed!")
