import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.result import TestFailure
import random

@cocotb.test()
async def test_bitstring_constructor(dut):
    """Test bit string constructor for subsequence counts"""
    
    # Setup clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.a.value = 0
    dut.b.value = 0
    dut.c.value = 0
    dut.d.value = 0
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await Timer(50, units='ns')
    
    # Helper function to count subsequences
    def count_subseqs(s):
        c00 = c01 = c10 = c11 = 0
        n = len(s)
        for i in range(n):
            for j in range(i+1, n):
                if s[i] == '0' and s[j] == '0': c00 += 1
                if s[i] == '0' and s[j] == '1': c01 += 1
                if s[i] == '1' and s[j] == '0': c10 += 1
                if s[i] == '1' and s[j] == '1': c11 += 1
        return c00, c01, c10, c11
    
    # Helper to run one test
    async def run_test(a, b, c, d, expected_valid, test_name):
        dut.a.value = a
        dut.b.value = b
        dut.c.value = c
        dut.d.value = d
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        timeout = 0
        while not dut.done.value and timeout < 200:
            await RisingEdge(dut.clk)
            timeout += 1
        
        if timeout >= 200:
            raise TestFailure(f"{test_name}: Timeout waiting for done")
        
        # Check validity
        if dut.valid.value != expected_valid:
            raise TestFailure(f"{test_name}: Expected valid={expected_valid}, got {dut.valid.value}")
        
        if dut.valid.value:
            # Decode result
            length = int(dut.result_length.value)
            result_bits = int(dut.result_string.value)
            
            if length > 8:
                raise TestFailure(f"{test_name}: Length {length} exceeds 8")
            
            # Convert to string
            s = ''
            for i in range(length):
                bit = (result_bits >> i) & 1
                s += str(bit)
            
            print(f"{test_name}: Generated '{s}' (length {length})")
            
            # Verify subsequence counts
            c00, c01, c10, c11 = count_subseqs(s)
            if c00 != a or c01 != b or c10 != c or c11 != d:
                raise TestFailure(f"{test_name}: Count mismatch. Got 00={c00},01={c01},10={c10},11={c11}. Expected 00={a},01={b},10={c},11={d}")
            print(f"  Verified: 00={c00}, 01={c01}, 10={c10}, 11={c11}")
        else:
            print(f"{test_name}: Marked as impossible (correctly or incorrectly)")
    
    # Test case 1: 3 4 2 1
    # C(3,2)=3, C(2,2)=1, 3*2=6 (but input has 4 and 2)
    # Wait, 01001 has 3 zeros, 2 ones: C(3,2)=3, C(2,2)=1, 3*2=6
    # But example says b=4, c=2. Let's recheck.
    # 01001: indices 0,1,2,3,4
    # 00: (0,2), (0,3), (1,3) = 3 ✓
    # 01: (0,1), (0,4), (2,4), (3,4) = 4 ✓
    # 10: (1,2), (1,3) = 2 ✓
    # 11: (1,4) = 1 ✓
    # So k=3, l=2. b=4, c=2. Notice b != c here! 
    # Wait, standard relation is b = k*l for all-0-then-all-1.
    # For 01001: zeros at 0,2,3; ones at 1,4. 
    # Pairings: (0,1), (0,4), (2,4), (3,4) -> 4 pairs 01.
    # (1,2), (1,3) -> 2 pairs 10.
    # So the formula b=k*l only works for 00...011...1.
    # This means we need a more complex construction logic.
    # Let's just verify the specific test case manually.
    
    await run_test(3, 4, 2, 1, True, "Test 1: 3 4 2 1")
    
    # Test case 2: 5 0 0 5
    # Need 5 zeros, 5 ones. C(5,2)=10 ≠ 5. Impossible.
    await run_test(5, 0, 0, 5, False, "Test 2: 5 0 0 5")
    
    # Test case 3: 1 0 0 0 (one zero)
    # C(1,2)=0 ≠ 1. Impossible.
    await run_test(1, 0, 0, 0, False, "Test 3: 1 0 0 0")
    
    # Test case 4: 0 0 0 1 (one one)
    # C(1,2)=0 ≠ 1. Impossible.
    await run_test(0, 0, 0, 1, False, "Test 4: 0 0 0 1")
    
    # Test case 5: 0 0 0 0 (empty or single char)
    # But problem says non-empty string. 
    # With 1 char: all counts 0. Valid.
    # We can output "0" or "1".
    await run_test(0, 0, 0, 0, True, "Test 5: 0 0 0 0")
    
    # Test case 6: 3 6 6 3 (standard 000111)
    # 3 zeros, 3 ones. C(3,2)=3, 3*3=9 ≠ 6.
    # Wait, for 000111: 00 pairs = C(3,2)=3. 11 pairs = C(3,2)=3.
    # 01 pairs = 3*3 = 9. 10 pairs = 0.
    # So 3 9 0 3. Let's try 3 6 6 3.
    # This requires a different pattern.
    # Let's use 3 9 0 3 as a valid test case.
    await run_test(3, 9, 0, 3, True, "Test 6: 3 9 0 3")
