import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.result import TestFailure

# Helper function to convert string to bytes
def str_to_bytes(s):
    return [ord(c) for c in s]

@cocotb.test()
async def test_interleaving_verifier(dut):
    """Test interleaving verification with multiple test cases"""
    
    # Create clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.len_s.value = 0
    dut.len_s1.value = 0
    dut.len_s2.value = 0
    for i in range(16):
        dut.s[i].value = 0
    for i in range(8):
        dut.s1[i].value = 0
        dut.s2[i].value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test case 1: "aabcad" with "aba" and "acd" -> YES
    # s = a a b c a d
    # s1 = a b a
    # s2 = a c d
    # Valid interleaving: s1[0]=a, s2[0]=a, s1[1]=b, s2[1]=c, s1[2]=a, s2[2]=d
    # Indices: 0,2,4 for s1; 1,3,5 for s2
    dut.len_s.value = 6
    dut.len_s1.value = 3
    dut.len_s2.value = 3
    s_bytes = str_to_bytes("aabcad")
    s1_bytes = str_to_bytes("aba")
    s2_bytes = str_to_bytes("acd")
    for i in range(6):
        dut.s[i].value = s_bytes[i]
    for i in range(3):
        dut.s1[i].value = s1_bytes[i]
        dut.s2[i].value = s2_bytes[i]
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done (max 50 cycles)
    for _ in range(50):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    
    if dut.done.value != 1:
        raise TestFailure("Test case 1: Done not asserted within 50 cycles")
    
    if dut.result.value != 1:
        raise TestFailure(f"Test case 1: Expected result=1 (yes), got {dut.result.value}")
    
    dut._log.info("Test case 1 passed: aabcad, aba, acd -> yes")
    
    # Test case 2: "aabcad" with "acb" and "aad" -> NO
    # s1 = a c b
    # s2 = a a d
    # s = a a b c a d
    # Cannot form s because s1 needs 'c' but 'c' is at index 3, s1[0]=a at 0, s1[1]=c needs >0, s2 needs a a d
    dut.len_s.value = 6
    dut.len_s1.value = 3
    dut.len_s2.value = 3
    s_bytes = str_to_bytes("aabcad")
    s1_bytes = str_to_bytes("acb")
    s2_bytes = str_to_bytes("aad")
    for i in range(6):
        dut.s[i].value = s_bytes[i]
    for i in range(3):
        dut.s1[i].value = s1_bytes[i]
        dut.s2[i].value = s2_bytes[i]
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(50):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    
    if dut.done.value != 1:
        raise TestFailure("Test case 2: Done not asserted within 50 cycles")
    
    if dut.result.value != 0:
        raise TestFailure(f"Test case 2: Expected result=0 (no), got {dut.result.value}")
    
    dut._log.info("Test case 2 passed: aabcad, acb, aad -> no")
    
    # Test case 3: "aabcad" with "acb" and "acd" -> NO
    # s1 = a c b
    # s2 = a c d
    # Cannot form s because s1[2]=b is needed, but after s1[1]=c, b is not available after c
    dut.len_s.value = 6
    dut.len_s1.value = 3
    dut.len_s2.value = 3
    s_bytes = str_to_bytes("aabcad")
    s1_bytes = str_to_bytes("acb")
    s2_bytes = str_to_bytes("acd")
    for i in range(6):
        dut.s[i].value = s_bytes[i]
    for i in range(3):
        dut.s1[i].value = s1_bytes[i]
        dut.s2[i].value = s2_bytes[i]
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(50):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    
    if dut.done.value != 1:
        raise TestFailure("Test case 3: Done not asserted within 50 cycles")
    
    if dut.result.value != 0:
        raise TestFailure(f"Test case 3: Expected result=0 (no), got {dut.result.value}")
    
    dut._log.info("Test case 3 passed: aabcad, acb, acd -> no")
    
    # Test case 4: "ab" with "a" and "b" -> YES
    # s = a b
    # s1 = a
    # s2 = b
    dut.len_s.value = 2
    dut.len_s1.value = 1
    dut.len_s2.value = 1
    s_bytes = str_to_bytes("ab")
    s1_bytes = str_to_bytes("a")
    s2_bytes = str_to_bytes("b")
    for i in range(2):
        dut.s[i].value = s_bytes[i]
    for i in range(1):
        dut.s1[i].value = s1_bytes[i]
        dut.s2[i].value = s2_bytes[i]
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(50):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    
    if dut.done.value != 1:
        raise TestFailure("Test case 4: Done not asserted within 50 cycles")
    
    if dut.result.value != 1:
        raise TestFailure(f"Test case 4: Expected result=1 (yes), got {dut.result.value}")
    
    dut._log.info("Test case 4 passed: ab, a, b -> yes")
    
    # Test case 5: "aaa" with "aa" and "a" -> YES
    # s = a a a
    # s1 = a a
    # s2 = a
    dut.len_s.value = 3
    dut.len_s1.value = 2
    dut.len_s2.value = 1
    s_bytes = str_to_bytes("aaa")
    s1_bytes = str_to_bytes("aa")
    s2_bytes = str_to_bytes("a")
    for i in range(3):
        dut.s[i].value = s_bytes[i]
    for i in range(2):
        dut.s1[i].value = s1_bytes[i]
    dut.s2[0].value = s2_bytes[0]
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(50):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    
    if dut.done.value != 1:
        raise TestFailure("Test case 5: Done not asserted within 50 cycles")
    
    if dut.result.value != 1:
        raise TestFailure(f"Test case 5: Expected result=1 (yes), got {dut.result.value}")
    
    dut._log.info("Test case 5 passed: aaa, aa, a -> yes")
    
    dut._log.info("All 5 tests passed!")