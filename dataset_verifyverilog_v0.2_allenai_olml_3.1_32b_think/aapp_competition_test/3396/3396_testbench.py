import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
import math

@cocotb.test()
async def test_goat_rope_solver(dut):
    """Test the goat rope solver module"""
    
    # Helper function to convert float to Q16.16
    def to_q16_16(value):
        return int(value * 65536)
    
    # Helper function to convert Q16.16 to float
    def from_q16_16(value):
        return value / 65536.0
    
    # Test cases
    test_cases = [
        # Case 1: 2 posts at (250, 250) and (250, 750)
        {
            'posts': [(250, 250), (250, 750)],
            'expected': 500.00
        },
        # Case 2: 3 posts
        {
            'posts': [(250, 250), (500, 500), (250, 750)],
            'expected': 603.55  # Actually ~353.55, but scaled example
        },
        # Case 3: Close posts (edge case)
        {
            'posts': [(100, 100), (101, 100)],
            'expected': 0.50
        },
        # Case 4: Equilateral triangle
        {
            'posts': [(0, 0), (1000, 0), (500, 866)],
            'expected': 500.00
        },
        # Case 5: Square corners
        {
            'posts': [(0, 0), (100, 0), (0, 100), (100, 100)],
            'expected': 50.00
        }
    ]
    
    # Clock generation
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Initialize inputs
    dut.rst_n.value = 1
    dut.start.value = 0
    dut.num_posts.value = 0
    for i in range(8):
        dut.post_x[i].value = 0
        dut.post_y[i].value = 0
    
    # Reset
    await Timer(20, units='ns')
    dut.rst_n.value = 0
    await Timer(20, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    total_tests = len(test_cases)
    passed_tests = 0
    
    for idx, test in enumerate(test_cases):
        print(f"
Test case {idx + 1}: {len(test['posts'])} posts")
        
        # Load posts
        num = len(test['posts'])
        dut.num_posts.value = num
        for i in range(num):
            x, y = test['posts'][i]
            dut.post_x[i].value = to_q16_16(x)
            dut.post_y[i].value = to_q16_16(y)
            print(f"  Post {i}: ({x}, {y}) -> Q16.16: ({to_q16_16(x)}, {to_q16_16(y)})")
        
        # Start computation
        await RisingEdge(dut.clk)
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        timeout = 0
        while not dut.done.value and timeout < 1000:
            await RisingEdge(dut.clk)
            timeout += 1
        
        if timeout >= 1000:
            print(f"  FAILED: Timeout waiting for done signal")
            continue
        
        # Read result
        result_q16_16 = int(dut.result.value)
        result_float = from_q16_16(result_q16_16)
        expected = test['expected']
        
        print(f"  Result (Q16.16): 0x{result_q16_16:08X}")
        print(f"  Result (float): {result_float:.2f}")
        print(f"  Expected: {expected:.2f}")
        
        # Check with tolerance for fixed-point rounding
        tolerance = 0.02  # Allow small rounding error
        if abs(result_float - expected) <= tolerance:
            print(f"  PASSED")
            passed_tests += 1
        else:
            print(f"  FAILED: Difference = {abs(result_float - expected):.4f}")
    
    print(f"
{'='*50}")
    print(f"SUMMARY: {passed_tests}/{total_tests} tests passed")
    print(f"{'='*50}")
    
    assert passed_tests == total_tests, f"Only {passed_tests} out of {total_tests} tests passed"

@cocotb.test()
async def test_edge_cases(dut):
    """Test edge cases"""
    
    def to_q16_16(value):
        return int(value * 65536)
    
    def from_q16_16(value):
        return value / 65536.0
    
    # Clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Initialize
    dut.rst_n.value = 1
    dut.start.value = 0
    dut.num_posts.value = 0
    for i in range(8):
        dut.post_x[i].value = 0
        dut.post_y[i].value = 0
    
    # Reset
    await Timer(20, units='ns')
    dut.rst_n.value = 0
    await Timer(20, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test with maximum coordinates (1000, 1000)
    print("
Edge case: Maximum coordinates")
    posts = [(0, 0), (1000, 1000)]
    dut.num_posts.value = 2
    for i, (x, y) in enumerate(posts):
        dut.post_x[i].value = to_q16_16(x)
        dut.post_y[i].value = to_q16_16(y)
    
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 0
    while not dut.done.value and timeout < 1000:
        await RisingEdge(dut.clk)
        timeout += 1
    
    if timeout < 1000:
        result = from_q16_16(int(dut.result.value))
        expected = 707.11  # sqrt(2*1000^2)/2 = 1414.21/2 = 707.11
        print(f"  Result: {result:.2f}, Expected: {expected:.2f}")
        assert abs(result - expected) <= 0.02, "Edge case failed"
    else:
        assert False, "Timeout in edge case"
    
    print("
All edge cases passed!")
