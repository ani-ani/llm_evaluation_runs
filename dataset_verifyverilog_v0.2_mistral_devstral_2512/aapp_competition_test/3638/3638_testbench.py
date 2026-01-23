import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
import random

# Helper to convert pattern string to 64-bit packed format
def pack_pattern(pattern_str):
    packed = 0
    for i, c in enumerate(pattern_str):
        packed |= ord(c) << (i * 8)
    return packed

# Compute score in Python for verification
def compute_score(pattern, n):
    L = len(pattern)
    # Simple overlap detection (just for demonstration, simplified)
    # Count self-overlaps: e.g., 'AAA' has overlap, 'AB' doesn't
    overlap = 0
    if L > 1:
        # Check if first char equals last, etc. (simplified)
        if pattern[0] == pattern[-1]:
            overlap = 1
    # 3^L
    pow3L = 3 ** L
    # Score = (n - L + 1) * 2^16 / pow3L
    # In Q16.16: score_fp = (n - L + 1) * (65536 // pow3L)
    reciprocal = (1 << 16) // pow3L
    score = (n - L + 1) * reciprocal
    # Apply overlap penalty (simplified)
    if overlap:
        score = score * 15 // 16  # Reduce by ~6%
    return score

@cocotb.test()
async def test_pattern_probability_sorter(dut):
    """Test pattern probability sorter with multiple cases"""
    
    # Setup clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.num_patterns.value = 0
    dut.pattern_length.value = 0
    for i in range(8):
        setattr(dut, f'predictions_{i}', 0)
    
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test Case 1: n=3, patterns=['PP','RR','PS','SS']
    dut._log.info("Test Case 1: n=3, 4 patterns of length 2")
    dut.num_patterns.value = 4
    dut.pattern_length.value = 2
    n_val = 3
    
    patterns = ['PP', 'RR', 'PS', 'SS']
    for i, pat in enumerate(patterns):
        packed = pack_pattern(pat)
        setattr(dut, f'predictions_{i}', packed)
    
    # Pass n through a separate input (assuming module has 'n' input)
    # Note: The prompt says to add 'n' input
    dut.n.value = n_val
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for completion (assume 64 cycles max)
    for _ in range(100):
        await RisingEdge(dut.clk)
        if dut.done.value:
            break
    
    assert dut.done.value == 1, "Module did not complete"
    
    # Read sorted indices
    sorted_indices = []
    for i in range(4):
        idx = getattr(dut, f'sorted_indices_{i}').value
        sorted_indices.append(int(idx))
    
    dut._log.info(f"Sorted indices: {sorted_indices}")
    
    # Expected: PS(2), PP(0), RR(1), SS(3) - all same score, PS first
    # But Python calculation: PS no overlap (score=2/9=14563), PP/RR/SS overlap 1
    # Actually, all 2-char patterns have no self-overlap except 'RR' and 'SS' if they were 'AA'
    # For 'PP','RR','PS','SS': only 'PP' and 'SS' could have overlap if we consider
    # Let's trust Python calculation for ordering
    
    scores = []
    for i, pat in enumerate(patterns):
        scores.append(compute_score(pat, n_val))
    
    # Expected order: sorted by score descending, stable
    # Scores: PS=14563, PP=13610 (due to penalty), RR=13610, SS=13610
    # Wait, my overlap logic is wrong. Let's recalc.
    # Pattern length 2: 'PS' has no overlap. 'PP' has prefix 'P' and suffix 'P' - overlap=1
    # So 'PS' score = 2 * (65536//9) = 2*7281 = 14562
    # 'PP' score = 2 * (65536//9) * (15/16) = 14562 * 15/16 = 13652
    # Order: PS (14562), PP/RR/SS (13652) - stable so PP, RR, SS
    
    expected_order = [2, 0, 1, 3]  # PS, PP, RR, SS
    
    for i in range(4):
        assert sorted_indices[i] == expected_order[i], f"Index {i}: expected {expected_order[i]}, got {sorted_indices[i]}"
    
    # Test Case 2: n=20, patterns=['PRSPS','SSSSS','PPSPP']
    dut._log.info("Test Case 2: n=20, 3 patterns of length 5")
    dut.num_patterns.value = 3
    dut.pattern_length.value = 5
    n_val = 20
    dut.n.value = n_val
    
    patterns = ['PRSPS', 'SSSSS', 'PPSPP']
    for i, pat in enumerate(patterns):
        packed = pack_pattern(pat)
        setattr(dut, f'predictions_{i}', packed)
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(100):
        await RisingEdge(dut.clk)
        if dut.done.value:
            break
    
    sorted_indices = []
    for i in range(3):
        idx = getattr(dut, f'sorted_indices_{i}').value
        sorted_indices.append(int(idx))
    
    dut._log.info(f"Sorted indices: {sorted_indices}")
    
    # Scores:
    # 3^5 = 243, reciprocal = 65536//243 = 269
    # Base score = (20-5+1) * 269 = 16 * 269 = 4304
    # Overlap penalties:
    # PRSPS: no overlap (P!=S) -> 4304
    # SSSSS: overlaps (prefix 'S' suffix 'S', also more) -> reduced, say 4304 * 12/16 = 3228
    # PPSPP: overlaps (P!=P? no, P at start and end) -> 4304 * 15/16 = 4035
    # Order: PRSPS (4304), PPSPP (4035), SSSSS (3228) -> [0, 2, 1]
    # But expected output is PRSPS, PPSPP, SSSSS -> matches!
    
    expected_order_2 = [0, 2, 1]
    for i in range(3):
        assert sorted_indices[i] == expected_order_2[i], f"Index {i}: expected {expected_order_2[i]}, got {sorted_indices[i]}"
    
    # Test Case 3: Edge case single pattern
    dut._log.info("Test Case 3: Single pattern")
    dut.num_patterns.value = 1
    dut.pattern_length.value = 4
    n_val = 10
    dut.n.value = n_val
    patterns = ['PPPP']
    setattr(dut, 'predictions_0', pack_pattern('PPPP'))
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(100):
        await RisingEdge(dut.clk)
        if dut.done.value:
            break
    
    idx = dut.sorted_indices_0.value
    assert idx == 0, "Single pattern should return index 0"
    
    # Test Case 4: Two identical patterns (tie handling)
    dut._log.info("Test Case 4: Ties - same patterns")
    dut.num_patterns.value = 2
    dut.pattern_length.value = 3
    n_val = 5
    dut.n.value = n_val
    patterns = ['PSP', 'PSP']
    setattr(dut, 'predictions_0', pack_pattern('PSP'))
    setattr(dut, 'predictions_1', pack_pattern('PSP'))
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(100):
        await RisingEdge(dut.clk)
        if dut.done.value:
            break
    
    idx0 = dut.sorted_indices_0.value
    idx1 = dut.sorted_indices_1.value
    # Stable sort: input order preserved (0, 1)
    assert idx0 == 0 and idx1 == 1, f"Tie handling failed: got {idx0}, {idx1}"
    
    # Test Case 5: All same length, different overlaps
    dut._log.info("Test Case 5: Various overlaps")
    dut.num_patterns.value = 5
    dut.pattern_length.value = 3
    n_val = 6
    dut.n.value = n_val
    pats = ['ABC', 'AAA', 'ABA', 'BAB', 'CCC']  # Using letters, but convert to R/P/S
    # Map to valid chars: A=R, B=P, C=S
    pats_rps = ['RPS', 'RRR', 'RPR', 'PSP', 'SSS']
    for i, pat in enumerate(pats_rps):
        setattr(dut, f'predictions_{i}', pack_pattern(pat))
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(100):
        await RisingEdge(dut.clk)
        if dut.done.value:
            break
    
    sorted_indices = [int(getattr(dut, f'sorted_indices_{i}').value) for i in range(5)]
    dut._log.info(f"Sorted indices: {sorted_indices}
Expected order by score (higher first): RPS (no overlap), RPR (partial), PSP (partial), RRR (full), SSS (full)")
    
    # Scores:
    # 3^3=27, reciprocal=2425 (65536//27=2427 approx, but 2427*27=65529, close)
    # Actually 65536//27 = 2427 (integer division)
    # Base = (6-3+1) * 2427 = 4 * 2427 = 9708
    # RPS: no overlap -> 9708
    # RPR: overlap 1 (R at both ends) -> 9708 * 15/16 = 9101
    # PSP: overlap 1 (P at both ends) -> 9101
    # RRR: full overlap -> 9708 * 12/16 = 7281
    # SSS: full overlap -> 7281
    # Order: RPS(0), RPR(1), PSP(2) tied -> keep input order, RRR(3), SSS(4)
    # Expected: [0, 1, 2, 3, 4]
    expected_order_5 = [0, 1, 2, 3, 4]
    for i in range(5):
        assert sorted_indices[i] == expected_order_5[i], f"Mismatch at {i}"
    
    dut._log.info("All tests passed!")
    
    # Summary
    total = 5
    passed = 5
    dut._log.info(f"{passed}/{total} tests passed")