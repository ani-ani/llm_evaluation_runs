import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
import struct

def float_to_q1616(value):
    """Convert float to Q16.16 fixed-point representation"""
    return int(value * 65536) & 0xFFFFFFFF

def q1616_to_float(value):
    """Convert Q16.16 fixed-point to float"""
    if value & 0x80000000:  # Negative number
        return (value - 0x100000000) / 65536.0
    else:
        return value / 65536.0

@cocotb.test()
async def test_bandwidth_allocator_basic(dut):
    """Test basic case with 3 species, equal demand, no constraints"""
    # Setup clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test case 1: 3 species, t=10, equal demand
    # In Q16.16: t=655360, d_i=65536
    dut.num_species.value = 3
    dut.total_bandwidth.value = float_to_q1616(10.0)
    
    # Species 0-2: a=0, b=10, d=1
    for i in range(8):
        if i < 3:
            dut.a_min[i].value = float_to_q1616(0.0)
            dut.b_max[i].value = float_to_q1616(10.0)
            dut.demand[i].value = float_to_q1616(1.0)
        else:
            dut.a_min[i].value = 0
            dut.b_max[i].value = 0
            dut.demand[i].value = 1  # Non-zero to avoid div by zero
    
    # Start computation
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done
    timeout = 0
    while not dut.done.value and timeout < 200:
        await RisingEdge(dut.clk)
        timeout += 1
    
    # Check results
    print(f"Test 1: 3 species equal demand")
    for i in range(3):
        alloc = q1616_to_float(int(dut.x_alloc[i].value))
        expected = 10.0 / 3.0
        print(f"  Species {i}: got {alloc:.8f}, expected {expected:.8f}")
        assert abs(alloc - expected) < 0.0001, f"Species {i} mismatch"
    
    print("Test 1 passed!")

@cocotb.test()
async def test_bandwidth_allocator_constrained(dut):
    """Test case with constraints - species 0 capped at 1"""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test case 2: 3 species, t=10
    # Species 0: a=0, b=1, d=1000 (huge demand, capped at b=1)
    # Species 1: a=2, b=8, d=2
    # Species 2: a=2, b=8, d=1
    dut.num_species.value = 3
    dut.total_bandwidth.value = float_to_q1616(10.0)
    
    # Species 0
    dut.a_min[0].value = float_to_q1616(0.0)
    dut.b_max[0].value = float_to_q1616(1.0)
    dut.demand[0].value = float_to_q1616(1000.0)
    
    # Species 1
    dut.a_min[1].value = float_to_q1616(2.0)
    dut.b_max[1].value = float_to_q1616(8.0)
    dut.demand[1].value = float_to_q1616(2.0)
    
    # Species 2
    dut.a_min[2].value = float_to_q1616(2.0)
    dut.b_max[2].value = float_to_q1616(8.0)
    dut.demand[2].value = float_to_q1616(1.0)
    
    # Clear others
    for i in range(3, 8):
        dut.a_min[i].value = 0
        dut.b_max[i].value = 1000000
        dut.demand[i].value = 1
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 0
    while not dut.done.value and timeout < 200:
        await RisingEdge(dut.clk)
        timeout += 1
    
    print(f"
Test 2: Constrained allocation")
    
    # Expected: species 0 = 1.0 (capped), remaining 9 distributed 2:1
    # Total demand for remaining = 2+1=3, so species 1 gets 2/3*9=6, species 2 gets 1/3*9=3
    expected = [1.0, 6.0, 3.0]
    for i in range(3):
        alloc = q1616_to_float(int(dut.x_alloc[i].value))
        print(f"  Species {i}: got {alloc:.8f}, expected {expected[i]:.8f}")
        assert abs(alloc - expected[i]) < 0.0001, f"Species {i} mismatch"
    
    print("Test 2 passed!")

@cocotb.test()
async def test_bandwidth_allocator_all_bounds(dut):
    """Test where all species are at their bounds"""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # 3 species, total bandwidth = 7
    # Species 0: a=1, b=2, d=1 -> fair share 2.33, so at b=2
    # Species 1: a=2, b=4, d=1 -> at b=4 would be too much, fair share 2.33, in range
    # Species 2: a=1, b=2, d=1 -> at b=2
    # But wait, if we sum bounds: 2+4+2=8 > 7, so we need to check feasibility
    
    # Let's use: t=5, bounds: a=[1,2,1], b=[2,3,2], d=[1,1,1]
    # Fair shares: 1.67 each. Species 0 at b=2, species 1 at in_range=1.67, species 2 at b=2
    # Sum: 2+1.67+2=5.67 > 5... doesn't work
    
    # Let's use: t=5, bounds: a=[1,1,1], b=[2,2,2], d=[1,1,1]
    # Fair shares: 1.67 each. All at in_range. Sum=5, perfect.
    
    dut.num_species.value = 3
    dut.total_bandwidth.value = float_to_q1616(5.0)
    
    for i in range(3):
        dut.a_min[i].value = float_to_q1616(1.0)
        dut.b_max[i].value = float_to_q1616(2.0)
        dut.demand[i].value = float_to_q1616(1.0)
    
    for i in range(3, 8):
        dut.a_min[i].value = 0
        dut.b_max[i].value = 0
        dut.demand[i].value = 1
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 0
    while not dut.done.value and timeout < 200:
        await RisingEdge(dut.clk)
        timeout += 1
    
    print(f"
Test 3: All in range")
    
    # Expected: 1.67 each
    for i in range(3):
        alloc = q1616_to_float(int(dut.x_alloc[i].value))
        expected = 5.0 / 3.0
        print(f"  Species {i}: got {alloc:.8f}, expected {expected:.8f}")
        assert abs(alloc - expected) < 0.0001, f"Species {i} mismatch"
    
    print("Test 3 passed!")

@cocotb.test()
async def test_bandwidth_allocator_edge_case(dut):
    """Test edge case with one species needing minimum"""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # 3 species, t=5
    # Species 0: a=4, b=5, d=1 -> fair 1.67, so at a=4
    # Species 1: a=0, b=5, d=1 -> fair 1.67, in range
    # Species 2: a=0, b=5, d=1 -> fair 1.67, in range
    # Sum at min: 4 + 0 + 0 = 4, remaining 1
    # Distribute among species 1,2 with equal demand -> 0.5 each
    
    dut.num_species.value = 3
    dut.total_bandwidth.value = float_to_q1616(5.0)
    
    dut.a_min[0].value = float_to_q1616(4.0)
    dut.b_max[0].value = float_to_q1616(5.0)
    dut.demand[0].value = float_to_q1616(1.0)
    
    dut.a_min[1].value = float_to_q1616(0.0)
    dut.b_max[1].value = float_to_q1616(5.0)
    dut.demand[1].value = float_to_q1616(1.0)
    
    dut.a_min[2].value = float_to_q1616(0.0)
    dut.b_max[2].value = float_to_q1616(5.0)
    dut.demand[2].value = float_to_q1616(1.0)
    
    for i in range(3, 8):
        dut.a_min[i].value = 0
        dut.b_max[i].value = 0
        dut.demand[i].value = 1
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 0
    while not dut.done.value and timeout < 200:
        await RisingEdge(dut.clk)
        timeout += 1
    
    print(f"
Test 4: Species 0 at minimum")
    
    expected = [4.0, 0.5, 0.5]
    for i in range(3):
        alloc = q1616_to_float(int(dut.x_alloc[i].value))
        print(f"  Species {i}: got {alloc:.8f}, expected {expected[i]:.8f}")
        assert abs(alloc - expected[i]) < 0.0001, f"Species {i} mismatch"
    
    print("Test 4 passed!")

@cocotb.test()
async def test_bandwidth_allocator_all_at_bounds(dut):
    """Test where solution has all species exactly at bounds"""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # 2 species, t=3
    # Species 0: a=1, b=2, d=100 -> fair share ~3 (above max), so b=2
    # Species 1: a=1, b=2, d=1 -> fair share ~0.03 (below min), so a=1
    # Sum = 3, perfect
    
    dut.num_species.value = 2
    dut.total_bandwidth.value = float_to_q1616(3.0)
    
    dut.a_min[0].value = float_to_q1616(1.0)
    dut.b_max[0].value = float_to_q1616(2.0)
    dut.demand[0].value = float_to_q1616(100.0)
    
    dut.a_min[1].value = float_to_q1616(1.0)
    dut.b_max[1].value = float_to_q1616(2.0)
    dut.demand[1].value = float_to_q1616(1.0)
    
    for i in range(2, 8):
        dut.a_min[i].value = 0
        dut.b_max[i].value = 0
        dut.demand[i].value = 1
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 0
    while not dut.done.value and timeout < 200:
        await RisingEdge(dut.clk)
        timeout += 1
    
    print(f"
Test 5: All at bounds")
    
    expected = [2.0, 1.0]
    for i in range(2):
        alloc = q1616_to_float(int(dut.x_alloc[i].value))
        print(f"  Species {i}: got {alloc:.8f}, expected {expected[i]:.8f}")
        assert abs(alloc - expected[i]) < 0.0001, f"Species {i} mismatch"
    
    print("Test 5 passed!")
    print("
=== All tests passed! ===")
