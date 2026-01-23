import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer, FallingEdge
from cocotb.result import TestFailure
import random

def compute_lcs_3(X, Y, Z):
    """Python reference for 3-string LCS"""
    m, n, o = len(X), len(Y), len(Z)
    L = [[[0 for i in range(o+1)] for j in range(n+1)] for k in range(m+1)]
    for i in range(m+1):
        for j in range(n+1):
            for k in range(o+1):
                if i == 0 or j == 0 or k == 0:
                    L[i][j][k] = 0
                elif X[i-1] == Y[j-1] and X[i-1] == Z[k-1]:
                    L[i][j][k] = L[i-1][j-1][k-1] + 1
                else:
                    L[i][j][k] = max(L[i-1][j][k], L[i][j-1][k], L[i][j][k-1])
    return L[m][n][o]

@cocotb.test()
async def test_lcs_3strings(dut):
    """Test LCS for 3 strings"""
    
    # Create clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.char_valid.value = 0
    await Timer(25, units="ns")
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases
    test_cases = [
        ('AGGT12', '12TXAYB', '12XBA', 2),
        ('Reels', 'Reelsfor', 'ReelsforReels', 5),
        ('abcd1e2', 'bc12ea', 'bd1ea', 3)
    ]
    
    passed = 0
    total = len(test_cases)
    
    for X, Y, Z, expected in test_cases:
        # Pad strings to 8 chars with null (0) if needed
        X_pad = (X + '\x00' * 8)[:8]
        Y_pad = (Y + '\x00' * 8)[:8]
        Z_pad = (Z + '\x00' * 8)[:8]
        
        # Compute reference
        ref = compute_lcs_3(X, Y, Z)
        print(f"Test: X='{X}', Y='{Y}', Z='{Z}' -> Expected: {expected}, Ref: {ref}")
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for ready to load characters
        # In our design, we'll load characters via parallel feed
        # For simplicity, we'll simulate feeding all 8 chars per string
        
        # Load characters for string X
        for i in range(8):
            dut.char_x.value = ord(X_pad[i])
            dut.char_y.value = 0
            dut.char_z.value = 0
            dut.idx_x.value = i
            dut.idx_y.value = 0
            dut.idx_z.value = 0
            dut.char_valid.value = 1
            await RisingEdge(dut.clk)
        
        # Load characters for string Y
        for i in range(8):
            dut.char_x.value = 0
            dut.char_y.value = ord(Y_pad[i])
            dut.char_z.value = 0
            dut.idx_x.value = 0
            dut.idx_y.value = i
            dut.idx_z.value = 0
            dut.char_valid.value = 1
            await RisingEdge(dut.clk)
        
        # Load characters for string Z
        for i in range(8):
            dut.char_x.value = 0
            dut.char_y.value = 0
            dut.char_z.value = ord(Z_pad[i])
            dut.idx_x.value = 0
            dut.idx_y.value = 0
            dut.idx_z.value = i
            dut.char_valid.value = 1
            await RisingEdge(dut.clk)
        
        dut.char_valid.value = 0
        
        # Wait for completion
        timeout = 0
        while not dut.done.value and timeout < 1000:
            await RisingEdge(dut.clk)
            timeout += 1
        
        if timeout >= 1000:
            raise TestFailure(f"Test {X},{Y},{Z} timed out!")
        
        # Read result
        result = int(dut.result.value)
        
        if result == expected:
            passed += 1
            print(f"  PASSED: Result = {result}")
        else:
            print(f"  FAILED: Result = {result}, Expected = {expected}")
    
    print(f"
{passed}/{total} tests passed")
    
    if passed < total:
        raise TestFailure(f"Only {passed} out of {total} tests passed")

@cocotb.test()
async def test_lcs_edge_cases(dut):
    """Test edge cases for LCS"""
    
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.char_valid.value = 0
    await Timer(25, units="ns")
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases: all same char, no match, single char
    edge_cases = [
        ('aaaaaaaa', 'aaaaaaaa', 'aaaaaaaa', 8),  # All match
        ('abcdefgh', 'ijklmnop', 'qrstuvwx', 0),   # No match
        ('a', 'a', 'a', 1),                        # Single char
        ('aaaa', 'aa', 'aaaa', 2),                 # Different lengths
    ]
    
    passed = 0
    total = len(edge_cases)
    
    for X, Y, Z, expected in edge_cases:
        # Pad to 8 chars
        X_pad = (X + '\x00' * 8)[:8]
        Y_pad = (Y + '\x00' * 8)[:8]
        Z_pad = (Z + '\x00' * 8)[:8]
        
        print(f"Edge: X='{X}', Y='{Y}', Z='{Z}' -> Expected: {expected}")
        
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Load strings
        for i in range(8):
            dut.char_x.value = ord(X_pad[i])
            dut.char_y.value = ord(Y_pad[i])
            dut.char_z.value = ord(Z_pad[i])
            dut.idx_x.value = i
            dut.idx_y.value = i
            dut.idx_z.value = i
            dut.char_valid.value = 1
            await RisingEdge(dut.clk)
        
        dut.char_valid.value = 0
        
        # Wait for completion
        timeout = 0
        while not dut.done.value and timeout < 1000:
            await RisingEdge(dut.clk)
            timeout += 1
        
        if timeout >= 1000:
            raise TestFailure(f"Edge case {X},{Y},{Z} timed out!")
        
        result = int(dut.result.value)
        
        if result == expected:
            passed += 1
            print(f"  PASSED: Result = {result}")
        else:
            print(f"  FAILED: Result = {result}, Expected = {expected}")
    
    print(f"
{passed}/{total} edge tests passed")
    
    if passed < total:
        raise TestFailure(f"Only {passed} out of {total} edge tests passed")
