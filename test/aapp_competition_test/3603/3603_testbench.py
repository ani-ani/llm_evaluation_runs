import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
import random

@cocotb.test()
async def test_translator_pairing(dut):
    # Create clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset procedure
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test Case 1: Sample input (scaled M=6)
    test_input = {
        "M": 6,
        "N": 5,
        "lang1": [0,0,1,2,1,4],
        "lang2": [1,2,3,3,2,3]
    }
    await apply_test_case(dut, test_input)
    
    # Test Case 2: Impossible case (odd translators)
    test_input = {
        "M": 3,
        "N": 3,
        "lang1": [0,1,2],
        "lang2": [1,2,0]
    }
    await apply_test_case(dut, test_input)
    
    # Test Case 3: Edge case (M=max=8)
    test_input = {
        "M": 8,
        "N": 5,
        "lang1": [0,0,1,2,1,4,3,2],
        "lang2": [1,2,3,3,2,3,4,4]
    }
    await apply_test_case(dut, test_input)
    
    dut._log.info("All tests complete")

async def apply_test_case(dut, test_case):
    """Apply test case and verify results"""
    # Load inputs
    dut.M.value = test_case["M"]
    dut.N.value = test_case["N"]
    for i in range(8):
        if i < len(test_case["lang1"]):
            dut.lang1[i].value = test_case["lang1"][i]
            dut.lang2[i].value = test_case["lang2"][i]
        else:
            dut.lang1[i].value = 0
            dut.lang2[i].value = 0
    
    # Start processing
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    pairs = []
    expected_pairs = test_case["M"] // 2 if test_case["M"] % 2 == 0 else 0
    timeout = 20
    
    if test_case["M"] == 3:  # Impossible case
        while timeout > 0:
            await RisingEdge(dut.clk)
            timeout -= 1
            if dut.impossible.value == 1:
                break
        assert dut.impossible.value == 1, "Failed to detect impossible pairing"
        dut._log.info("Test passed: Correctly identified impossible case")
        return
    
    # Wait for outputs
    while len(pairs) < expected_pairs and timeout > 0:
        await RisingEdge(dut.clk)
        timeout -= 1
        if dut.done.value == 1:
            pairs.append((int(dut.pair1.value), int(dut.pair2.value)))
    
    assert len(pairs) == expected_pairs, f"Incorrect number of pairs: got {len(pairs)}, expected {expected_pairs}"
    
    # Verify pairs
    valid_pair = True
    paired_ids = set()
    for p1, p2 in pairs:
        # Check duplicates
        assert p1 not in paired_ids, f"Duplicate translator {p1}"
        assert p2 not in paired_ids, f"Duplicate translator {p2}"
        paired_ids.add(p1)
        paired_ids.add(p2)
        
        # Check shared language
        lang1_p1 = test_case["lang1"][p1]
        lang2_p1 = test_case["lang2"][p1]
        lang1_p2 = test_case["lang1"][p2]
        lang2_p2 = test_case["lang2"][p2]
        
        shared = (lang1_p1 == lang1_p2) or (lang1_p1 == lang2_p2) or \
                 (lang2_p1 == lang1_p2) or (lang2_p1 == lang2_p2)
        valid_pair = valid_pair and shared
    
    assert valid_pair, "Found pair without shared language"
    dut._log.info(f"Test passed: Found valid pairing {pairs}")
