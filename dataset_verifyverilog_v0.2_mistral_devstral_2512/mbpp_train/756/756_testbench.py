import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
import random

@cocotb.test()
async def test_pattern_matcher(dut):
    """Test pattern matcher for 'ab+' regex"""
    
    # Setup clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.str_in.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases
    test_cases = [
        # (string, expected_match, description)
        ("ac      ", False, "Test 1: ac - no b after a"),
        ("dc      ", False, "Test 2: dc - no a at all"),
        ("abbbba  ", True,  "Test 3: abbbba - a followed by b's"),
        ("dsabbbba", True,  "Test 4: dsabbbba - a followed by b's in middle"),
        ("asbbbba ", False, "Test 5: asbbbba - a followed by s, not b"),
        ("abaaa   ", True,  "Test 6: abaaa - ab pattern at start"),
        ("bbba    ", False, "Edge: bbba - a not followed by b"),
        ("ab      ", True,  "Edge: ab - minimal pattern"),
        ("a       ", False, "Edge: a - single a, no b"),
        ("ba      ", False, "Edge: ba - a at end, no b after"),
        ("        ", False, "Edge: empty string"),
        ("axb     ", False, "Edge: axb - a followed by x, not b"),
    ]
    
    passed = 0
    total = len(test_cases)
    
    for i, (test_str, expected_match, description) in enumerate(test_cases):
        print(f"
Test {i+1}: {description}")
        
        # Convert string to bytes for verilog input
        str_bytes = [ord(c) for c in test_str]
        padded = str_bytes + [0] * (8 - len(str_bytes))
        
        # Pack into verilog format
        dut.str_in.value = 0
        for j in range(8):
            dut.str_in.value |= (padded[j] << (j * 8))
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done signal
        timeout = 20
        cycles = 0
        while not dut.done.value and cycles < timeout:
            await RisingEdge(dut.clk)
            cycles += 1
        
        if cycles >= timeout:
            print(f"  FAIL: Timeout waiting for done signal")
            continue
        
        # Check result
        actual = bool(dut.match.value)
        
        if actual == expected_match:
            print(f"  PASS: match={actual}, expected={expected_match}")
            passed += 1
        else:
            print(f"  FAIL: match={actual}, expected={expected_match}")
            # Debug: print string
            print(f"  String: '{test_str}'")
    
    print(f"
{passed}/{total} tests passed")
    assert passed == total, f"Only {passed}/{total} tests passed"
