import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer, FallingEdge
from cocotb.result import TestFailure
import random

@cocotb.test()
async def test_lucky_permutation(dut):
    """Test Lucky Permutation Triple generation for odd n values"""
    
    # Setup clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset sequence
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.n_in.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases: odd n values (1, 3, 5, 7, 9, 11, 13, 15)
    test_values = [1, 3, 5, 7, 9, 11, 13, 15]
    passed = 0
    total = len(test_values)
    
    for n in test_values:
        dut._log.info(f"Testing n={n}")
        
        # Initialize tracking
        a_vals = []
        b_vals = []
        c_vals = []
        indices = []
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Collect outputs for n cycles
        for i in range(n + 3):  # Extra cycles to catch done signal
            await RisingEdge(dut.clk)
            
            if dut.valid.value == 1:
                a_vals.append(int(dut.a_out.value))
                b_vals.append(int(dut.b_out.value))
                c_vals.append(int(dut.c_out.value))
                indices.append(int(dut.index_out.value))
        
        # Verify results
        try:
            # Check we got exactly n outputs
            assert len(a_vals) == n, f"Expected {n} outputs, got {len(a_vals)}"
            
            # Verify indices
            expected_indices = list(range(n))
            assert indices == expected_indices, f"Indices mismatch: {indices} vs {expected_indices}"
            
            # Verify a is permutation [0, 1, ..., n-1]
            assert a_vals == expected_indices, f"a not identity: {a_vals}"
            
            # Verify b is permutation [0, 1, ..., n-1]
            assert b_vals == expected_indices, f"b not identity: {b_vals}"
            
            # Verify c is permutation and satisfies c[i] = (2*i) % n
            expected_c = [(2 * i) % n for i in range(n)]
            assert c_vals == expected_c, f"c mismatch: {c_vals} vs {expected_c}"
            
            # Verify all values in c are unique (permutation property)
            assert len(set(c_vals)) == n, f"c is not a permutation: duplicates found"
            
            # Verify all values in c are in range [0, n-1]
            assert all(0 <= val < n for val in c_vals), f"c has values outside range: {c_vals}"
            
            # Verify lucky condition: (a[i] + b[i]) % n == c[i]
            for i in range(n):
                assert (a_vals[i] + b_vals[i]) % n == c_vals[i], \
                    f"Lucky condition fails at i={i}: ({a_vals[i]}+{b_vals[i]})%{n}={ (a_vals[i] + b_vals[i]) % n } != {c_vals[i]}"
            
            # Check done signal
            # Done should be high after computation
            done_found = False
            for _ in range(5):
                await RisingEdge(dut.clk)
                if dut.done.value == 1:
                    done_found = True
                    break
            assert done_found, "Done signal not raised"
            
            passed += 1
            dut._log.info(f"  n={n}: PASSED")
            
        except AssertionError as e:
            dut._log.error(f"  n={n}: FAILED - {e}")
            # Reset for next test
            dut.rst_n.value = 0
            await Timer(20, units='ns')
            await RisingEdge(dut.clk)
            dut.rst_n.value = 1
            await RisingEdge(dut.clk)
    
    dut._log.info(f"
=== SUMMARY: {passed}/{total} tests passed ===")
    assert passed == total, f"Only {passed} of {total} tests passed"
