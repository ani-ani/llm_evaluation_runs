import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# MANDATORY HELPER FUNCTIONS
# ============================================================================

def is_value_defined(value):
    try:
        int(value)
        return True
    except ValueError:
        return False

def safe_int(value, default=0):
    try:
        return int(value)
    except ValueError:
        return default

def to_signed(val, bits):
    if val >= (1 << (bits - 1)):
        return val - (1 << bits)
    return val

def from_signed(val, bits):
    if val < 0:
        return val + (1 << bits)
    return val

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def clamp_to_width(value, bits):
    max_val = (1 << bits) - 1
    if value < 0:
        return from_signed(max(-((1 << (bits-1))), min((1 << (bits-1)) - 1, value)), bits)
    return min(max_val, max(0, value))

# ============================================================================
# TEST HELPER FUNCTIONS
# ============================================================================

def pack_array(values, element_bits=8):
    """Pack list of values into single integer, LSB first."""
    result = 0
    for i, val in enumerate(values):
        result |= (val & ((1 << element_bits) - 1)) << (i * element_bits)
    return result

async def reset_dut(dut, cycles=2):
    """Standard reset sequence (no reset in this design, just wait)"""
    await Timer(10, units='ns')

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_minimize_shift(dut):
    """Test the minimize_shift module with multiple test cases"""
    
    # Helper to set inputs
    def set_inputs(n_val, m_val, h_val, u_vals, clients_vals):
        dut.n.value = n_val
        dut.m.value = m_val
        dut.h.value = h_val
        
        # Pack u array: 4 data centers, each 3 bits
        u_packed = 0
        for i, val in enumerate(u_vals):
            u_packed |= (val & 0x7) << (i * 3)
        dut.u.value = u_packed
        
        # Pack clients: 4 clients, each 4 bits (2 indices of 2 bits)
        clients_packed = 0
        for i, (c1, c2) in enumerate(clients_vals):
            clients_packed |= (c1 & 0x3) << (i * 4)
            clients_packed |= (c2 & 0x3) << (i * 4 + 2)
        dut.clients.value = clients_packed
    
    # Helper to check outputs
    async def check_outputs(expected_k, expected_list):
        await Timer(10, units='ns')  # Let combinational logic settle
        
        if not is_value_defined(dut.k.value):
            raise TestFailure("Output k is undefined (X/Z)")
        
        actual_k = int(dut.k.value)
        if actual_k != expected_k:
            raise TestFailure(f"k: expected {expected_k}, got {actual_k}")
        
        # Read list outputs (4 positions, each 2 bits)
        actual_list = []
        for i in range(4):
            val = (dut.list.value >> (i*2)) & 0x3
            if val != 0:
                actual_list.append(val)
        
        # Compare sorted (order doesn't matter)
        actual_list.sort()
        expected_list.sort()
        if actual_list != expected_list:
            raise TestFailure(f"List: expected {expected_list}, got {actual_list}")
    
    # Test Cases
    # Format: (n, m, h, u_list, clients_list, expected_k, expected_list)
    test_cases = [
        # Original example 1 (scaled down to 3 DCs)
        (
            2, 3, 5,  # n=2 means 3 DCs? Let's use: n=3 -> encoded as 2 (since 2'b10 = 3)
            [4, 4, 0],  # u values
            [(0,2), (2,1), (2,0)],  # clients (0-indexed: DC1=0, DC2=1, DC3=2)
            1, [3]  # expected: 1 DC, index 3 (1-indexed)
        ),
        # Original example 2 (scaled to 4 DCs)
        (
            3, 4, 4,  # n=3 -> 4 DCs? Use n=3 (2'b11=4)
            [2, 1, 0, 3],
            [(3,2), (2,1), (0,1), (0,3), (0,2)],
            4, [1,2,3,4]
        ),
        # Additional test: single DC shift works
        (
            1, 1, 2,  # n=1 -> 2 DCs
            [0, 1],
            [(0,1)],
            1, [2]  # Shift DC2
        ),
        # Test with no shift needed (should output smallest possible)
        (
            1, 1, 3,
            [0, 2],  # Different maintenance times
            [(0,1)],
            1, [1]  # Can shift either, pick smallest index
        )
    ]
    
    passed = 0
    failed = 0
    
    for i, (n_val, m_val, h_val, u_vals, clients_vals, exp_k, exp_list) in enumerate(test_cases):
        dut._log.info(f"Test case {i+1}: n={n_val+1}, m={m_val}, h={h_val}")
        
        # Convert n from input format (0->1, 1->2, 2->3, 3->4)
        n_encoded = n_val
        
        set_inputs(n_encoded, m_val, h_val, u_vals, clients_vals)
        
        try:
            await check_outputs(exp_k, exp_list)
            dut._log.info(f"  PASS")
            passed += 1
        except TestFailure as e:
            dut._log.error(f"  FAIL: {e}")
            failed += 1
    
    # Summary
    dut._log.info(f"{'='*50}")
    dut._log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")
