import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer, RisingEdge
from cocotb.result import TestFailure

@cocotb.test()
async def test_splitter_network(dut):
    """Test box splitter network construction"""
    
    # Test Case 1: 2 3 -> 3 2 (swap)
    dut.A.value = 2
    dut.B.value = 3
    dut.C.value = 3
    dut.D.value = 2
    await Timer(10, units='ns')
    
    n = dut.n.value
    assert n == 1, f"Test 1: Expected n=1, got {n}"
    assert dut.l[0].value == 0xFE, f"Test 1: Expected l[0]=-2 (0xFE), got {dut.l[0].value}"
    assert dut.r[0].value == 0xFF, f"Test 1: Expected r[0]=-1 (0xFF), got {dut.r[0].value}"
    print(f"Test 1 passed: 2:3 -> 3:2 swap")
    
    # Test Case 2: 1 2 -> 3 4
    dut.A.value = 1
    dut.B.value = 2
    dut.C.value = 3
    dut.D.value = 4
    await Timer(10, units='ns')
    
    n = dut.n.value
    assert n == 3, f"Test 2: Expected n=3, got {n}"
    # Check connections
    assert dut.l[0].value == 0xFF, f"Test 2: l[0] should be -1"
    assert dut.r[0].value == 1, f"Test 2: r[0] should be 1"
    assert dut.l[1].value == 2, f"Test 2: l[1] should be 2"
    assert dut.r[1].value == 1, f"Test 2: r[1] should be 1"
    assert dut.l[2].value == 0, f"Test 2: l[2] should be 0"
    assert dut.r[2].value == 0xFE, f"Test 2: r[2] should be -2"
    print(f"Test 2 passed: 1:2 -> 3:4")
    
    # Test Case 3: 1 2 -> 1 2 (identity)
    dut.A.value = 1
    dut.B.value = 2
    dut.C.value = 1
    dut.D.value = 2
    await Timer(10, units='ns')
    
    n = dut.n.value
    assert n == 3, f"Test 3: Expected n=3, got {n}"
    assert dut.l[0].value == 0xFE, f"Test 3: l[0] should be -2"
    assert dut.r[0].value == 1, f"Test 3: r[0] should be 1"
    assert dut.l[1].value == 2, f"Test 3: l[1] should be 2"
    assert dut.r[1].value == 0, f"Test 3: r[1] should be 0"
    assert dut.l[2].value == 1, f"Test 3: l[2] should be 1"
    assert dut.r[2].value == 0xFF, f"Test 3: r[2] should be -1"
    print(f"Test 3 passed: 1:2 -> 1:2")
    
    print(f"
All 3/3 tests passed!")