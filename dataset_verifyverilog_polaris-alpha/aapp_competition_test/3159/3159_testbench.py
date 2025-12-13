import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
import numpy as np

@cocotb.test()
async def test_ad_remover(dut):
    # Create 16x16 test grids (0-padded if smaller)
    test_inputs = [
        # Test 1: Single ad (scaled from sample 1)
        np.array([
            [32]*16,  # Space row
            list(b"  apples!      ") + [32]*2,
            list(b"++++++++++++++") + [32]*2,
            list(b"+invalid# ad+") + [32]*2,
            list(b"++++++++++++++") + [32]*2,
            [32]*16,
            [32]*16,
            [32]*14 + list(b"!!")  # Rest of grid is spaces...
        ] + [[32]*16 for _ in range(8)]),
        # Test 2: Full removal (scaled sample 2)
        np.array([
            list(b"++++++++") + [32]*8,
            list(b"+  =  +") + [32]*8,
            list(b"+ +++ +") + [32]*8,
            list(b"+ + + +") + [32]*8,
            list(b"+ +++ +") + [32]*8,
            list(b"+     +") + [32]*8,
            list(b"++++++++") + [32]*8,
            [32]*16 for _ in range(9)]),
        # Test 3: Nested ads (modified sample 3)
        np.array([
            list(b"++++++++") + [32]*8,
            list(b"+     +") + [32]*8,
            list(b"+ +++ +") + [32]*8,
            list(b"+ +=+ +") + [32]*8,
            list(b"+ +++ +") + [32]*8,
            list(b"+     +") + [32]*8,
            list(b"++++++++") + [32]*8,
            [32]*16 for _ in range(9)])
    ]
    expected_outputs = [
        # Test 1: Whole ad removed
        np.array([[32]*16 for _ in range(16)]),
        # Test 2: Entire grid cleared
        np.array([[32]*16 for _ in range(16)]),
        # Test 3: Only inner ad removed (outer preserved)
        np.array([
            list(b"++++++++") + [32]*8,
            list(b"+     +") + [32]*8,
            list(b"+     +") + [32]*8,
            list(b"+     +") + [32]*8,
            list(b"+     +") + [32]*8,
            list(b"+     +") + [32]*8,
            list(b"++++++++") + [32]*8,
            [32]*16 for _ in range(9)])
    ]
    
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    passed = 0
    for i in range(len(test_inputs)):
        dut.rst_n.value = 0
        dut.start.value = 0
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        
        # Load grid into dut (row-major)
        for r in range(16):
            for c in range(16):
                dut.grid[r][c].value = int(test_inputs[i][r][c])
        
        # Start processing
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for completion (max 300 cycles)
        for _ in range(300):
            await RisingEdge(dut.clk)
            if dut.done.value == 1:
                break
        else:
            assert False, "Timeout waiting for done"
        
        # Verify output
        match = True
        for r in range(16):
            for c in range(16):
                actual = dut.out_grid[r][c].value
                expected = expected_outputs[i][r][c]
                if actual != expected:
                    dut._log.error(f"Row {r}, Col {c}: Expected {chr(expected)} (ASCII {expected}), got {chr(actual.signed_integer)} (ASCII {actual})")
                    match = False
        
        if match:
            passed += 1
            dut._log.info(f"Test {i+1} passed")
        else:
            dut._log.error(f"Test {i+1} failed")
    
    dut._log.info(f"{passed}/{len(test_inputs)} tests passed")
