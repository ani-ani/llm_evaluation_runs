import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from cocotb.result import TestFailure

@cocotb.test()
async def test_swimming_hall(dut):
    """Test swimming hall dimension solver with various n values"""
    
    # Create clock (10ns period = 100MHz)
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.n.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases scaled for 8-bit input (max 255)
    test_cases = [
        # (n, expected_m, expected_k, expected_valid)
        (7, 4, 3, True),    # 4^2 - 3^2 = 16 - 9 = 7
        (10, 0, 0, False),  # impossible
        (15, 4, 1, True),   # 4^2 - 1^2 = 16 - 1 = 15  
        (1, 1, 0, True),    # 1^2 - 0^2 = 1
        (3, 2, 1, True),    # 2^2 - 1^2 = 4 - 1 = 3
        (4, 2, 0, True),    # 2^2 - 0^2 = 4 - 0 = 4
        (2, 0, 0, False),   # impossible
        (8, 3, 1, True),    # 3^2 - 1^2 = 9 - 1 = 8
        (12, 4, 2, True),   # 4^2 - 2^2 = 16 - 4 = 12
        (21, 11, 10, True), # 11^2 - 10^2 = 121 - 100 = 21
        (24, 5, 1, True),   # 5^2 - 1^2 = 25 - 1 = 24
        (25, 5, 0, True),   # 5^2 - 0^2 = 25 - 0 = 25
        (27, 6, 3, True),   # 6^2 - 3^2 = 36 - 9 = 27
        (30, 0, 0, False),  # impossible (odd prime factor of form 4k+3)
        (64, 8, 0, True),   # 8^2 - 0^2 = 64 - 0 = 64
        (63, 8, 1, True),   # 8^2 - 1^2 = 64 - 1 = 63
        (65, 9, 4, True),   # 9^2 - 4^2 = 81 - 16 = 65
        (99, 10, 1, True),  # 10^2 - 1^2 = 100 - 1 = 99
        (100, 10, 0, True), # 10^2 - 0^2 = 100 - 0 = 100
        (255, 16, 1, True), # 16^2 - 1^2 = 256 - 1 = 255
    ]
    
    passed = 0
    total = len(test_cases)
    
    for n_val, exp_m, exp_k, exp_valid in test_cases:
        # Load input
        dut.n.value = n_val
        await RisingEdge(dut.clk)
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for completion (with timeout)
        timeout = 300  # cycles
        for _ in range(timeout):
            await RisingEdge(dut.clk)
            if dut.done.value == 1:
                break
        else:
            raise TestFailure(f"Timeout for n={n_val}")
        
        # Check results
        if exp_valid:
            if dut.valid.value != 1:
                raise TestFailure(f"n={n_val}: Expected valid=1, got {dut.valid.value}")
            if dut.impossible.value != 0:
                raise TestFailure(f"n={n_val}: Expected impossible=0, got {dut.impossible.value}")
            m_val = int(dut.m.value)
            k_val = int(dut.k.value)
            # Verify the equation: m^2 - k^2 == n
            if (m_val*m_val - k_val*k_val) != n_val:
                raise TestFailure(f"n={n_val}: Invalid result m={m_val}, k={k_val} (m^2-k^2={m_val*m_val-k_val*k_val})")
            # Verify non-negative and m > k
            if m_val < 0 or k_val < 0:
                raise TestFailure(f"n={n_val}: Negative values m={m_val}, k={k_val}")
            if m_val <= k_val:
                raise TestFailure(f"n={n_val}: m must be > k, got m={m_val}, k={k_val}")
            print(f"PASS n={n_val}: m={m_val}, k={k_val} (valid solution)")
            passed += 1
        else:
            if dut.impossible.value != 1:
                raise TestFailure(f"n={n_val}: Expected impossible=1, got {dut.impossible.value}")
            if dut.valid.value != 0:
                raise TestFailure(f"n={n_val}: Expected valid=0, got {dut.valid.value}")
            print(f"PASS n={n_val}: correctly determined impossible")
            passed += 1
        
        await RisingEdge(dut.clk)
    
    print(f"
=== Summary: {passed}/{total} tests passed ===")
    assert passed == total, f"Only {passed}/{total} tests passed"
