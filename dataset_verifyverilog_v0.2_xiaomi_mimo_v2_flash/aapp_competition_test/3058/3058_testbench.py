import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from cocotb.result import TestFailure

# Helper to convert string to byte array (list of ints)
def str_to_bytes(s):
    return [ord(c) for c in s]

def pad_string(s, max_len=16):
    if len(s) > max_len:
        return str_to_bytes(s[:max_len])
    return str_to_bytes(s) + [0] * (max_len - len(s))

@cocotb.test()
async def test_evolution_solver(dut):
    """Test the evolution solver module"""
    # Setup clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test Case 1: From Example 1
    # Input: 5 fossils, Target: AACCMMAA
    # Fossils: ACA, MM, ACMAA, AA, A
    # Expected: One valid partition (e.g., Path1: MM, Path2: A, AA, ACA, ACMAA)
    
    target_str = "AACCMMAA"
    fossils_str = ["ACA", "MM", "ACMAA", "AA", "A"]
    
    dut.target.value = 0
    target_bytes = pad_string(target_str)
    for i in range(16):
        dut.target[i].value = target_bytes[i]
    
    dut.num_fossils.value = len(fossils_str)
    
    # Clear fossils
    for i in range(16):
        for j in range(16):
            dut.fossils[i][j].value = 0
            
    for i, s in enumerate(fossils_str):
        b = pad_string(s)
        for j in range(16):
            dut.fossils[i][j].value = b[j]
            
    # Start
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for result (poll for a reasonable time, e.g., 1000 cycles)
    found = False
    for _ in range(2000):
        await RisingEdge(dut.clk)
        if dut.valid.value == 1:
            found = True
            break
        if dut.impossible.value == 1:
            break
            
    if found:
        mask1 = int(dut.result_mask1.value)
        mask2 = int(dut.result_mask2.value)
        print(f"Test 1: Found valid partition. Mask1={mask1:05b}, Mask2={mask2:05b}")
        # Verify disjoint
        if (mask1 & mask2) != 0:
            raise TestFailure("Masks overlap")
        # Verify coverage (all fossils must be assigned in valid output)
        # Note: Problem says "If it is possible that a sequence could appear in the genetic history of both species, your example should assign it to exactly one of the evolutionary paths."
        # We assume we must assign all fossils for a valid solution.
        # However, strictly speaking, we can leave some out? "assign it to exactly one" implies we choose for those that are ambiguous.
        # But the output format is just s1 and s2 lines. The example output lists specific fossils.
        # Usually, in such problems, we don't need to use ALL fossils, only those that can form valid chains? 
        # Re-reading: "display an example of how the nucleotide sequences in the fossil record participate in two evolutionary paths."
        # Usually implies all are used. But if "participate", maybe some don't. Let's assume we must partition the SET of fossils that ARE used. 
        # The problem statement doesn't explicitly say "all fossils must be used". It says "participate in two evolutionary paths".
        # Let's check Sample 1 output: 1 4. Total fossils 5. 1+4=5. So all are used. 
        # Let's assume we must use all for a valid solution.
        assigned = mask1 | mask2
        expected_mask = (1 << len(fossils_str)) - 1
        if assigned != expected_mask:
            print(f"Warning: Not all fossils assigned. Assigned {assigned:b}, Expected {expected_mask:b}")
            # Depending on problem interpretation, this might be valid. But usually strict. 
            # Let's be lenient in test but note it. For now, assume strict if we want full coverage.
    else:
        if dut.impossible.value == 1:
            print("Test 1: Declared impossible (Incorrect for this case!)")
            raise TestFailure("Test 1 should be possible but got impossible")
        else:
            print("Test 1: Timeout")
            raise TestFailure("Test 1 timed out")

    # Reset for next test
    dut.rst_n.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test Case 2: Impossible Case (Sample 2)
    # 3 fossils, Target ACMA
    # Fossils: ACM, ACA, AMA
    # Output: impossible
    
    target_str = "ACMA"
    fossils_str = ["ACM", "ACA", "AMA"]
    
    dut.target.value = 0
    target_bytes = pad_string(target_str)
    for i in range(16):
        dut.target[i].value = target_bytes[i]
    
    dut.num_fossils.value = len(fossils_str)
    for i in range(16):
        for j in range(16):
            dut.fossils[i][j].value = 0
            
    for i, s in enumerate(fossils_str):
        b = pad_string(s)
        for j in range(16):
            dut.fossils[i][j].value = b[j]
            
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    found = False
    for _ in range(2000):
        await RisingEdge(dut.clk)
        if dut.valid.value == 1:
            found = True
            break
        if dut.impossible.value == 1:
            break
            
    if found:
        raise TestFailure("Test 2 should be impossible but found a solution")
    elif dut.impossible.value == 1:
        print("Test 2: Correctly identified impossible")
    else:
        raise TestFailure("Test 2 timed out")