import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from cocotb.result import TestFailure

# Helper function to convert string to 32-bit ASCII (little-endian)
def str_to_ascii(s):
    if len(s) > 4:
        s = s[:4]
    padded = s.ljust(4, '\0')
    result = 0
    for i, c in enumerate(padded):
        result |= ord(c) << (i * 8)
    return result

@cocotb.test()
async def test_min_k_records(dut):
    """Test min_k_records module with various inputs"""
    
    # Create clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.K.value = 0
    dut.name_0.value = 0
    dut.name_1.value = 0
    dut.name_2.value = 0
    dut.name_3.value = 0
    dut.score_0.value = 0
    dut.score_1.value = 0
    dut.score_2.value = 0
    dut.score_3.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases adapted from Python
    test_cases = [
        # Test 1: K=2
        {
            'name': 'Test 1: K=2',
            'records': [('Akash', 2), ('Akshat', 4), ('Manjeet', 10), ('Nikhil', 8)],
            'K': 2,
            'expected': [('Akash', 2), ('Akshat', 4), None, None]
        },
        # Test 2: K=3  
        {
            'name': 'Test 2: K=3',
            'records': [('Akash', 3), ('Angat', 5), ('Nepin', 9), ('Sanjeev', 11)],
            'K': 3,
            'expected': [('Akash', 3), ('Angat', 5), ('Nepin', 9), None]
        },
        # Test 3: K=1
        {
            'name': 'Test 3: K=1',
            'records': [('Ayesha', 9), ('Amer', 11), ('tanmay', 14), ('SKD', 16)],
            'K': 1,
            'expected': [('Ayesha', 9), None, None, None]
        },
        # Test 4: K=4 (all records)
        {
            'name': 'Test 4: K=4',
            'records': [('Z', 1), ('Y', 2), ('X', 3), ('W', 4)],
            'K': 4,
            'expected': [('Z', 1), ('Y', 2), ('X', 3), ('W', 4)]
        },
    ]
    
    passed = 0
    total = len(test_cases)
    
    for tc in test_cases:
        dut._log.info(f"Running {tc['name']}")
        
        # Prepare inputs
        names = [str_to_ascii(r[0]) for r in tc['records']]
        scores = [r[1] for r in tc['records']]
        
        dut.name_0.value = names[0]
        dut.name_1.value = names[1]
        dut.name_2.value = names[2]
        dut.name_3.value = names[3]
        dut.score_0.value = scores[0]
        dut.score_1.value = scores[1]
        dut.score_2.value = scores[2]
        dut.score_3.value = scores[3]
        dut.K.value = tc['K']
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        timeout = 20
        cycles = 0
        while not dut.done.value and cycles < timeout:
            await RisingEdge(dut.clk)
            cycles += 1
        
        if cycles >= timeout:
            dut._log.error(f"{tc['name']}: Timeout waiting for done")
            continue
            
        # Check outputs
        output_names = [dut.out_name_0.value, dut.out_name_1.value, dut.out_name_2.value, dut.out_name_3.value]
        output_scores = [dut.out_score_0.value, dut.out_score_1.value, dut.out_score_2.value, dut.out_score_3.value]
        
        success = True
        for i in range(4):
            expected = tc['expected'][i]
            if expected is None:
                if output_names[i] != 0 or output_scores[i] != 0:
                    dut._log.error(f"{tc['name']} pos {i}: Expected 0, got name={output_names[i]}, score={output_scores[i]}")
                    success = False
            else:
                expected_name = str_to_ascii(expected[0])
                expected_score = expected[1]
                if output_names[i] != expected_name or output_scores[i] != expected_score:
                    dut._log.error(f"{tc['name']} pos {i}: Expected {expected}, got name={output_names[i]}, score={output_scores[i]}")
                    success = False
        
        if success:
            passed += 1
            dut._log.info(f"{tc['name']}: PASSED")
        else:
            dut._log.error(f"{tc['name']}: FAILED")
        
        await RisingEdge(dut.clk)
    
    dut._log.info(f"
=== SUMMARY: {passed}/{total} tests passed ===")
    assert passed == total, f"Only {passed}/{total} tests passed"
