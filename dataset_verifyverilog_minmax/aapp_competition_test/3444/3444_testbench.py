import cocotb
from cocotb.triggers import RisingEdge, ClockCycles
from cocotb.clock import Clock
import struct

@cocotb.test()
async def test_ski_path(dut):
    # Fixed-point helper functions
    def float_to_q16_16(f):
        return int(f * (1 << 16)) & 0xFFFFFFFF
    
    def q16_16_to_float(q):
        if q >= 0x80000000: # Handle negative (not needed here)
            q = q - 0x100000000
        return q / (1 << 16)
    
    # Test cases (N, M, adjacency_matrix, expected_results[4] as floats)
    test_cases = [
        (
            # Input 1: 2 cabins, 1 piste (0->1 with 0.5 fall)
            2, 1,
            [
                # Cabin 0→1: 0.5 fall (0.5 survival)
                (0, 1, 0.5), # Only 0->1 valid path (downhill)
                (1, 0, 1.0), # Reverse would be walkable but hasn't fall chance
            ],
            [0.5, 1.0, 1.0, 1.0] # k=0: 0.5, k≥1: walk reverse with 1.0 survival
        ),
        (
            # Input 2: 3 cabins scenario
            3, 2,
            [
                (0, 1, 0.2), # 80% survival
                (1, 2, 0.3), # 70% survival
            ],
            [
                0.8*0.7,         # k=0: path 0→1→2 (0.56)
                1.0,             # k=1: walk 1→2 edge (0.8 * 1.0)
                1.0,             # k=2: same as k=1
                1.0              # k=3: same
            ]
        ),
        (
            # Invalid path case (topologically separated without walks)
            3, 1,
            [
                (0, 2, 0.4), # Direct path
            ],
            [
                0.6, # k=0: take 0→2 (60% survival)
                1.0, # k=1: walk possible even for direct path?
                1.0,
                1.0
            ]
        )
    ]
    
    # Setup clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    passed = 0
    
    for (N, M, edges, expected) in test_cases:
        # Initialize
        dut.rst_n.value = 0
        dut.start.value = 0
        await ClockCycles(dut.clk, 2)
        dut.rst_n.value = 1
        
        # Build adjacency matrix (4×4)×32b = 32×32 = 1024b → actually 4x4=16 entries ×32b=512b
        adj_matrix = 0
        for a in range(4):
            for b in range(4):
                prob_fall = 1.0 # Default: invalid edge (no connection)
                for (src, dest, fall_prob) in edges:
                    if src == a and dest == b:
                        prob_fall = fall_prob
                adj_matrix = (adj_matrix << 32) | float_to_q16_16(prob_fall)
        
        # Apply inputs
        dut.num_cabins.value = N - 1 # Since 0-based indexing
        dut.num_pistes.value = M
        dut.adjacency_input.value = adj_matrix & ((1 << 288) - 1) # Truncate to 288b for max 4x4
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done - 20 cycles
        await ClockCycles(dut.clk, 20)
        
        # Check results
        all_passed = True
        results_val = dut.results.value
        for k in range(4):
            q_val = (results_val >> (32 * (3 - k))) & 0xFFFFFFFF # Extract 32-bit slot
            exp_val = expected[k] if k < N else 1.0 # Default unused to 1.0
            if exp_val != -1: # Skip -1 cases
                exp_q = float_to_q16_16(exp_val)
                if q_val != exp_q:
                    actual_float = q16_16_to_float(q_val)
                    dut._log.error(f"For N={N}, k={k}: Expected {exp_val:.4f} ({exp_q:#x}), got {actual_float:.4f} ({q_val:#x})")
                    all_passed = False
        
        if all_passed:
            passed += 1
        
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")