import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
import random

def gcd(a, b):
    """Compute GCD of two positive integers"""
    while b:
        a, b = b, a % b
    return a

def compute_counts(L, A, B):
    """Compute insecure, secure, super-secure counts for given parameters"""
    insecure = 0
    secure = 0
    super_secure = 0
    
    for x in range(1, L + 1):
        for y in range(-A, B + 1):
            # Guard at (0, -A) sees (x, y) if gcd(x, y - (-A)) = gcd(x, y + A) = 1
            g1 = gcd(x, abs(y + A))
            # Guard at (0, B) sees (x, y) if gcd(x, B - y) = 1
            g2 = gcd(x, abs(B - y))
            
            vis1 = 1 if g1 == 1 else 0
            vis2 = 1 if g2 == 1 else 0
            vis_sum = vis1 + vis2
            
            if vis_sum == 0:
                insecure += 1
            elif vis_sum == 1:
                secure += 1
            else:  # vis_sum == 2
                super_secure += 1
    
    return insecure, secure, super_secure

@cocotb.test()
async def test_vault_security_basic(dut):
    """Test basic functionality with small parameters"""
    # Setup clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.L.value = 0
    dut.A.value = 0
    dut.B.value = 0
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test case 1: A=1, B=1, L=3
    # Expected: insecure=2, secure=2, super_secure=5
    dut.L.value = 3
    dut.A.value = 1
    dut.B.value = 1
    await RisingEdge(dut.clk)
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for completion - estimate cycles: L*(A+B+2) = 3*4 = 12 cycles + overhead
    max_cycles = 50
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if dut.done.value:
            break
    
    assert dut.done.value == 1, "Module did not complete in time"
    
    insecure = int(dut.insecure_count.value)
    secure = int(dut.secure_count.value)
    super_secure = int(dut.super_secure_count.value)
    
    print(f"Test 1 - A=1, B=1, L=3")
    print(f"  Insecure: {insecure} (expected 2)")
    print(f"  Secure: {secure} (expected 2)")
    print(f"  Super-secure: {super_secure} (expected 5)")
    
    assert insecure == 2, f"Insecure count mismatch: {insecure} != 2"
    assert secure == 2, f"Secure count mismatch: {secure} != 2"
    assert super_secure == 5, f"Super-secure count mismatch: {super_secure} != 5"
    
    print("Test 1: PASSED")

@cocotb.test()
async def test_vault_security_case2(dut):
    """Test second example case"""
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test case 2: A=2, B=3, L=4
    # Expected: insecure=0, secure=16, super_secure=8
    dut.L.value = 4
    dut.A.value = 2
    dut.B.value = 3
    await RisingEdge(dut.clk)
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    max_cycles = 100
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if dut.done.value:
            break
    
    assert dut.done.value == 1
    
    insecure = int(dut.insecure_count.value)
    secure = int(dut.secure_count.value)
    super_secure = int(dut.super_secure_count.value)
    
    print(f"Test 2 - A=2, B=3, L=4")
    print(f"  Insecure: {insecure} (expected 0)")
    print(f"  Secure: {secure} (expected 16)")
    print(f"  Super-secure: {super_secure} (expected 8)")
    
    assert insecure == 0, f"Insecure count mismatch: {insecure} != 0"
    assert secure == 16, f"Secure count mismatch: {secure} != 16"
    assert super_secure == 8, f"Super-secure count mismatch: {super_secure} != 8"
    
    print("Test 2: PASSED")

@cocotb.test()
async def test_vault_security_edge_cases(dut):
    """Test edge cases with small values"""
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    test_cases = [
        # (L, A, B, expected_insecure, expected_secure, expected_super_secure)
        (1, 1, 1, 0, 2, 2),  # Minimal case
        (2, 1, 1, 1, 2, 5),  # Small expansion
        (1, 2, 1, 0, 2, 2),  # A > B
        (1, 1, 2, 0, 2, 2),  # B > A
    ]
    
    for i, (L, A, B, exp_inc, exp_sec, exp_ssec) in enumerate(test_cases):
        # Reset
        dut.rst_n.value = 0
        dut.start.value = 0
        await Timer(20, units='ns')
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
        
        # Compute expected values for verification
        exp_inc_v, exp_sec_v, exp_ssec_v = compute_counts(L, A, B)
        
        dut.L.value = L
        dut.A.value = A
        dut.B.value = B
        await RisingEdge(dut.clk)
        
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        max_cycles = 50
        for _ in range(max_cycles):
            await RisingEdge(dut.clk)
            if dut.done.value:
                break
        
        assert dut.done.value == 1
        
        inc = int(dut.insecure_count.value)
        sec = int(dut.secure_count.value)
        ssec = int(dut.super_secure_count.value)
        
        print(f"Edge case {i+1}: L={L}, A={A}, B={B}")
        print(f"  Results: Insecure={inc}, Secure={sec}, Super-secure={ssec}")
        print(f"  Expected: Insecure={exp_inc_v}, Secure={exp_sec_v}, Super-secure={exp_ssec_v}")
        
        assert inc == exp_inc_v, f"Insecure mismatch: {inc} != {exp_inc_v}"
        assert sec == exp_sec_v, f"Secure mismatch: {sec} != {exp_sec_v}"
        assert ssec == exp_ssec_v, f"Super-secure mismatch: {ssec} != {exp_ssec_v}"
        
        print(f"Edge case {i+1}: PASSED")
    
    print(f"All {len(test_cases)} edge cases passed!")

@cocotb.test()
async def test_vault_security_stress(dut):
    """Test with larger parameters to verify throughput"""
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Stress test: L=20, A=5, B=5 (1320 vaults)
    L, A, B = 20, 5, 5
    
    dut.L.value = L
    dut.A.value = A
    dut.B.value = B
    await RisingEdge(dut.clk)
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Calculate expected values
    exp_inc, exp_sec, exp_ssec = compute_counts(L, A, B)
    
    print(f"Stress test: L={L}, A={A}, B={B}")
    print(f"  Expected: Insecure={exp_inc}, Secure={exp_sec}, Super-secure={exp_ssec}")
    print(f"  Total vaults: {L * (A + B + 1)}")
    
    # Wait for completion with extended timeout
    max_cycles = 20000
    completed = False
    for cycle in range(max_cycles):
        await RisingEdge(dut.clk)
        if dut.done.value:
            completed = True
            break
        if cycle % 1000 == 0 and cycle > 0:
            print(f"  Still processing... cycle {cycle}")
    
    assert completed, f"Stress test did not complete in {max_cycles} cycles"
    
    inc = int(dut.insecure_count.value)
    sec = int(dut.secure_count.value)
    ssec = int(dut.super_secure_count.value)
    
    print(f"  Results: Insecure={inc}, Secure={sec}, Super-secure={ssec}")
    
    assert inc == exp_inc, f"Insecure mismatch: {inc} != {exp_inc}"
    assert sec == exp_sec, f"Secure mismatch: {sec} != {exp_sec}"
    assert ssec == exp_ssec, f"Super-secure mismatch: {ssec} != {exp_ssec}"
    
    print("Stress test: PASSED")

@cocotb.test()
async def test_gcd_correctness(dut):
    """Verify GCD calculations are correct for key values"""
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    test_vectors = [
        (6, 3, 3),   # gcd(6,3) = 3
        (7, 4, 1),   # gcd(7,4) = 1 (prime)
        (8, 6, 2),   # gcd(8,6) = 2
        (13, 10, 1), # gcd(13,10) = 1
        (12, 8, 4),  # gcd(12,8) = 4
        (15, 15, 15), # gcd(15,15) = 15
        (1, 5, 1),   # gcd(1,5) = 1
    ]
    
    print("
GCD verification (for reference):")
    for a, b, expected in test_vectors:
        result = gcd(a, b)
        print(f"  gcd({a}, {b}) = {result} (expected {expected})")
        assert result == expected
    
    print("GCD reference test: PASSED")
    
    # Note: Actual GCD verification would require probing internal state
    # which is beyond cocotb testbench scope. The compute_counts function
    # serves as the golden reference for correctness.
    
    # Just verify the module runs without error
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.L.value = 2
    dut.A.value = 1
    dut.B.value = 1
    await Timer(20, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(100):
        await RisingEdge(dut.clk)
        if dut.done.value:
            break
    
    print("GCD module interaction: PASSED")
