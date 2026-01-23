import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer, FallingEdge
from cocotb.result import TestFailure

@cocotb.test()
async def test_kenken_section(dut):
    """Test KenKen section solver with scaled inputs."""
    
    # Create clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.write_en.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    # Helper function to load coordinates
    async def load_coords(coords):
        # coords is a list of (r, c) tuples
        dut._log.info(f"Loading coordinates: {coords}")
        for i, (r, c) in enumerate(coords):
            dut.row_addr.value = i
            dut.col_addr.value = i
            dut.row_data_in.value = r
            dut.col_data_in.value = c
            dut.write_en.value = 1
            await RisingEdge(dut.clk)
        dut.write_en.value = 0

    # Helper function to run computation
    async def run_test(n, m, t_float, op_char, coords, expected_count):
        # Map op to binary
        op_map = {'+': 0, '-': 1, '*': 2, '/': 3}
        op_val = op_map[op_char]
        
        # Convert target to Q16.16
        t_fixed = int(t_float * 65536)
        
        dut.n.value = n
        dut.m.value = m
        dut.t_fixed.value = t_fixed
        dut.op.value = op_val
        
        await load_coords(coords)
        
        # Start
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        max_cycles = 1000  # Safety limit
        for _ in range(max_cycles):
            if dut.done.value == 1:
                break
            await RisingEdge(dut.clk)
        
        result = int(dut.count.value)
        dut._log.info(f"Test: n={n}, m={m}, t={t_float}, op={op_char}. Result: {result}, Expected: {expected_count}")
        
        if result != expected_count:
            raise TestFailure(f"Mismatch: got {result}, expected {expected_count}")

    # Test Case 1: 8 2 7 -
    # Inputs: (1,1), (1,2)
    # Scaled: n=4 (arbitrary scale for feasible Verilog), t=7, m=2
    # Valid pairs for n=4: (1,8) invalid, (2,9) invalid. 
    # Wait, the problem says n=8. In Verilog we are constrained.
    # Let's use smaller n that fits the logic (max 15 in 4 bits).
    # However, the Python code handles n=8. The Verilog module uses [3:0] for rows/cols (0-15).
    # So we can test with n=8.
    
    dut._log.info("--- Running Scaled Test Cases ---")
    
    # Case 1: n=8, m=2, t=7, -, coords=(1,1), (1,2)
    # Solutions: (1,8), (8,1), (2,9), (9,2) -> but n=8, so max is 8.
    # Valid: 1+6? 7-0? No, range 1..8.
    # Pairs: (1,8) -> 8-1=7. (8,1) -> 8-1=7. (2,9) invalid. (3,10) invalid.
    # Wait, python output says 2.
    # Let's verify python logic for n=8, t=7. Pairs (a,b) in [1..8] such that |a-b|=7.
    # (1,8) and (8,1). So 2 solutions. Correct.
    await run_test(8, 2, 7.0, '-', [(1, 1), (1, 2)], 2)

    # Case 2: n=9, m=2, t=7, -, coords=(1,1), (1,2)
    # Pairs in [1..9]: (1,8), (8,1), (2,9), (9,2).
    # Total 4.
    await run_test(9, 2, 7.0, '-', [(1, 1), (1, 2)], 4)

    # Case 3: 8 3 6 +
    # n=8, m=3, t=6, +. coords=(5,2), (6,2), (5,1)
    # We need 3 numbers a,b,c in [1..8] summing to 6.
    # Permutations of (1,1,4), (1,2,3), (2,2,2).
    # Constraint: distinct rows and cols.
    # Coords: R1=(5,2), R2=(6,2), R3=(5,1).
    # Rows: 5, 6, 5. -> R1 and R3 share row 5. R2 is row 6.
    # Cols: 2, 2, 1. -> R1 and R2 share col 2. R3 is col 1.
    # So R1 and R3 must be different values (same row).
    # R1 and R2 must be different values (same col).
    # R2 and R3 are independent rows/cols.
    
    # Permutations of sets summing to 6:
    # 1) {1,1,4}: 
    #    Assign to R1, R2, R3. 
    #    R1 != R3, R1 != R2.
    #    Try 1,1,4: 
    #       R1=1, R2=1 (Collision R1-R2), Fail.
    #       R1=1, R2=4: OK. R1=1, R2=4, R3=1? R1=1, R3=1 (Collision R1-R3), Fail.
    #       R1=4, R2=1: OK. R1=4, R2=1, R3=1? R1=4, R3=1 (OK), R2=1, R3=1 (OK).
    #       Wait, R3 is (5,1). R1 is (5,2). Same row. Must be diff. R1=4, R3=1 -> OK.
    #       R2 is (6,2). R1 is (5,2). Same col. Must be diff. R1=4, R2=1 -> OK.
    #       R2 is (6,2). R3 is (5,1). Diff row, diff col. 1,1 OK.
    #       So (4,1,1) is valid.
    #       Check permutations of {1,1,4}: 
    #       (R1,R2,R3):
    #       (1,1,4): R1-R2 collision.
    #       (1,4,1): R1-R3 collision.
    #       (4,1,1): OK.
    #       (4,1,1) -> R1=4, R2=1, R3=1.
    #       (1,1,4) -> R1=1, R2=1, R3=4 -> R1-R2 fail.
    #       (1,4,1) -> R1=1, R2=4, R3=1 -> R1-R3 fail.
    #       So 1 valid from this set.
    
    # 2) {1,2,3}: 
    #    Permutations: 6 total.
    #    R1, R2, R3 constraints: R1!=R2, R1!=R3.
    #    (1,2,3): R1=1, R2=2 (OK), R3=3 (R1!=R3). OK.
    #    (1,3,2): R1=1, R2=3 (OK), R3=2 (R1!=R3). OK.
    #    (2,1,3): R1=2, R2=1 (OK), R3=3 (R1!=R3). OK.
    #    (2,3,1): R1=2, R2=3 (OK), R3=1 (R1!=R3). OK.
    #    (3,1,2): R1=3, R2=1 (OK), R3=2 (R1!=R3). OK.
    #    (3,2,1): R1=3, R2=2 (OK), R3=1 (R1!=R3). OK.
    #    So 6 valid from this set.
    
    # 3) {2,2,2}: 
    #    Permutations: 1.
    #    (2,2,2): R1-R2 collision (col 2). Fail.
    #    0 valid.
    
    # Total: 1 + 6 = 7.
    # Matches sample output.
    await run_test(8, 3, 6.0, '+', [(5, 2), (6, 2), (5, 1)], 7)

    dut._log.info("All tests passed!")
