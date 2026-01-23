import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer, FallingEdge
from cocotb.result import TestFailure
import random

@cocotb.test()
async def test_knight_generator(dut):
    """Test the knight coordinate generation pattern"""
    
    # Create a 10ns period clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Initialize signals
    dut.rst_n.value = 1
    dut.start.value = 0
    dut.n.value = 0
    
    # Reset
    await RisingEdge(dut.clk)
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test function to generate expected coordinates
    def generate_expected_coords(n_val):
        coords = []
        for idx in range(n_val):
            block = idx // 3
            pos = idx % 3
            if pos == 0:
                x = 2 * block
                y = 0
            elif pos == 1:
                x = 2 * block + 1
                y = 0
            else:  # pos == 2
                x = 2 * block + 1
                y = 3
            coords.append((x, y))
        return coords
    
    # Test cases from problem
    test_ns = [1, 4, 7, 10, 13, 16, 19, 22, 25, 28, 31]
    
    passed = 0
    total = len(test_ns)
    
    for n_val in test_ns:
        dut._log.info(f"Testing n={n_val}")
        
        # Expected coordinates
        expected = generate_expected_coords(n_val)
        
        # Start generation
        dut.n.value = n_val
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Collect generated coordinates
        generated = []
        
        # Wait for first valid or done
        timeout = 0
        while timeout < 1000:
            if dut.valid.value == 1:
                x = int(dut.x.value)
                y = int(dut.y.value)
                generated.append((x, y))
            if dut.done.value == 1:
                break
            await RisingEdge(dut.clk)
            timeout += 1
        
        # Check results
        if len(generated) != n_val:
            raise TestFailure(f"n={n_val}: Expected {n_val} knights, got {len(generated)}")
        
        for i, (exp_x, exp_y) in enumerate(expected):
            if i >= len(generated):
                raise TestFailure(f"n={n_val}: Missing knight {i}")
            gen_x, gen_y = generated[i]
            if gen_x != exp_x or gen_y != exp_y:
                raise TestFailure(f"n={n_val}: Knight {i} mismatch. Expected ({exp_x},{exp_y}), got ({gen_x},{gen_y})")
        
        passed += 1
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)
    
    dut._log.info(f"Tests passed: {passed}/{total}")
    assert passed == total, f"Only {passed}/{total} tests passed"
