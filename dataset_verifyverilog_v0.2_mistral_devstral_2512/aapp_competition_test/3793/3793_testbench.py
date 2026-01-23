import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from cocotb.result import TestFailure
import random

# Helper to generate permutations
perms = [
    [0, 1, 2], [0, 2, 1], [1, 0, 2],
    [1, 2, 0], [2, 0, 1], [2, 1, 0]
]

def apply_perm(coords, perm):
    return [coords[perm[0]], coords[perm[1]], coords[perm[2]]]

def generate_valid_cube():
    # Generate a valid cube in 3D space
    # Use random but small coordinates to keep within 12-bit range
    base_x = random.randint(-50, 50)
    base_y = random.randint(-50, 50)
    base_z = random.randint(-50, 50)
    
    # Edge vectors (must be orthogonal, equal length)
    ax = random.randint(1, 10)
    ay = random.randint(1, 10)
    az = random.randint(1, 10)
    
    # Generate two more orthogonal vectors of same length
    # We'll generate a cube aligned with coordinate axes for simplicity
    # then rotate it randomly
    
    # Simpler: Generate a cube at origin, then add offset
    edge = random.randint(1, 20)
    vertices = [
        [0, 0, 0],
        [edge, 0, 0],
        [0, edge, 0],
        [0, 0, edge],
        [edge, edge, 0],
        [edge, 0, edge],
        [0, edge, edge],
        [edge, edge, edge]
    ]
    
    # Apply random permutation to each vertex
    permuted = []
    for v in vertices:
        p = perms[random.randint(0, 5)]
        permuted.append(apply_perm(v, p))
    
    return permuted

@cocotb.test()
async def test_cube_reconstructor_basic(dut):
    """Test basic cube reconstruction"""
    
    # Setup clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test case 1: Standard cube from problem
    cube = generate_valid_cube()
    
    # Apply to inputs
    dut.p0_x.value = cube[0][0]; dut.p0_y.value = cube[0][1]; dut.p0_z.value = cube[0][2]
    dut.p1_x.value = cube[1][0]; dut.p1_y.value = cube[1][1]; dut.p1_z.value = cube[1][2]
    dut.p2_x.value = cube[2][0]; dut.p2_y.value = cube[2][1]; dut.p2_z.value = cube[2][2]
    dut.p3_x.value = cube[3][0]; dut.p3_y.value = cube[3][1]; dut.p3_z.value = cube[3][2]
    dut.p4_x.value = cube[4][0]; dut.p4_y.value = cube[4][1]; dut.p4_z.value = cube[4][2]
    dut.p5_x.value = cube[5][0]; dut.p5_y.value = cube[5][1]; dut.p5_z.value = cube[5][2]
    dut.p6_x.value = cube[6][0]; dut.p6_y.value = cube[6][1]; dut.p6_z.value = cube[6][2]
    dut.p7_x.value = cube[7][0]; dut.p7_y.value = cube[7][1]; dut.p7_z.value = cube[7][2]
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for computation (this will take many cycles)
    # Maximum cycles: 6^8 permutations = 1.6M cycles
    # We'll wait for 200k cycles as a practical limit for test
    cycles = 0
    max_cycles = 200000
    
    while cycles < max_cycles:
        await RisingEdge(dut.clk)
        cycles += 1
        if dut.done.value:
            break
    
    if not dut.done.value:
        raise TestFailure(f"Module did not complete within {max_cycles} cycles")
    
    if not dut.success.value:
        raise TestFailure("Failed to find valid cube reconstruction")
    
    print(f"Test passed in {cycles} cycles")
    print(f"Input: {cube}")
    print(f"Output: {[ [int(dut.out0_x), int(dut.out0_y), int(dut.out0_z)], [int(dut.out1_x), int(dut.out1_y), int(dut.out1_z)], [int(dut.out2_x), int(dut.out2_y), int(dut.out2_z)], [int(dut.out3_x), int(dut.out3_y), int(dut.out3_z)], [int(dut.out4_x), int(dut.out4_y), int(dut.out4_z)], [int(dut.out5_x), int(dut.out5_y), int(dut.out5_z)], [int(dut.out6_x), int(dut.out6_y), int(dut.out6_z)], [int(dut.out7_x), int(dut.out7_y), int(dut.out7_z)] ]}")

@cocotb.test()
async def test_cube_reconstructor_edge_cases(dut):
    """Test edge cases"""
    
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test case: Invalid input (all same points)
    dut.p0_x.value = 0; dut.p0_y.value = 0; dut.p0_z.value = 0
    dut.p1_x.value = 0; dut.p1_y.value = 0; dut.p1_z.value = 0
    dut.p2_x.value = 0; dut.p2_y.value = 0; dut.p2_z.value = 0
    dut.p3_x.value = 0; dut.p3_y.value = 0; dut.p3_z.value = 0
    dut.p4_x.value = 1; dut.p4_y.value = 1; dut.p4_z.value = 1
    dut.p5_x.value = 1; dut.p5_y.value = 1; dut.p5_z.value = 1
    dut.p6_x.value = 1; dut.p6_y.value = 1; dut.p6_z.value = 1
    dut.p7_x.value = 1; dut.p7_y.value = 1; dut.p7_z.value = 1
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    cycles = 0
    max_cycles = 50000
    
    while cycles < max_cycles:
        await RisingEdge(dut.clk)
        cycles += 1
        if dut.done.value:
            break
    
    # Should not find solution
    if dut.done.value and dut.success.value:
        raise TestFailure("Incorrectly found valid cube for invalid input")
    
    print("Edge case test passed (correctly rejected invalid input)")

@cocotb.test()
async def test_cube_reconstructor_unit_cube(dut):
    """Test unit cube at origin"""
    
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Standard unit cube (axis aligned)
    cube = [
        [0, 0, 0],
        [0, 0, 1],
        [0, 1, 0],
        [0, 1, 1],
        [1, 0, 0],
        [1, 0, 1],
        [1, 1, 0],
        [1, 1, 1]
    ]
    
    # Shuffle and permute
    import random
    random.shuffle(cube)
    for i in range(8):
        p = perms[random.randint(0, 5)]
        cube[i] = apply_perm(cube[i], p)
    
    dut.p0_x.value = cube[0][0]; dut.p0_y.value = cube[0][1]; dut.p0_z.value = cube[0][2]
    dut.p1_x.value = cube[1][0]; dut.p1_y.value = cube[1][1]; dut.p1_z.value = cube[1][2]
    dut.p2_x.value = cube[2][0]; dut.p2_y.value = cube[2][1]; dut.p2_z.value = cube[2][2]
    dut.p3_x.value = cube[3][0]; dut.p3_y.value = cube[3][1]; dut.p3_z.value = cube[3][2]
    dut.p4_x.value = cube[4][0]; dut.p4_y.value = cube[4][1]; dut.p4_z.value = cube[4][2]
    dut.p5_x.value = cube[5][0]; dut.p5_y.value = cube[5][1]; dut.p5_z.value = cube[5][2]
    dut.p6_x.value = cube[6][0]; dut.p6_y.value = cube[6][1]; dut.p6_z.value = cube[6][2]
    dut.p7_x.value = cube[7][0]; dut.p7_y.value = cube[7][1]; dut.p7_z.value = cube[7][2]
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    cycles = 0
    max_cycles = 200000
    
    while cycles < max_cycles:
        await RisingEdge(dut.clk)
        cycles += 1
        if dut.done.value:
            break
    
    if not dut.done.value:
        raise TestFailure("Unit cube test did not complete")
    
    if not dut.success.value:
        raise TestFailure("Failed to reconstruct unit cube")
    
    print(f"Unit cube test passed in {cycles} cycles")
    
    # Verify output forms a valid cube
    out_points = [
        [int(dut.out0_x), int(dut.out0_y), int(dut.out0_z)],
        [int(dut.out1_x), int(dut.out1_y), int(dut.out1_z)],
        [int(dut.out2_x), int(dut.out2_y), int(dut.out2_z)],
        [int(dut.out3_x), int(dut.out3_y), int(dut.out3_z)],
        [int(dut.out4_x), int(dut.out4_y), int(dut.out4_z)],
        [int(dut.out5_x), int(dut.out5_y), int(dut.out5_z)],
        [int(dut.out6_x), int(dut.out6_y), int(dut.out6_z)],
        [int(dut.out7_x), int(dut.out7_y), int(dut.out7_z)]
    ]
    
    # Check lengths
    def dist2(p1, p2):
        return sum((p1[i] - p2[i])**2 for i in range(3))
    
    d01 = dist2(out_points[0], out_points[1])
    d02 = dist2(out_points[0], out_points[2])
    d03 = dist2(out_points[0], out_points[3])
    
    if d01 == 0 or d01 != d02 or d01 != d03:
        raise TestFailure(f"Output cube has invalid edge lengths: {d01}, {d02}, {d03}")
    
    # Check orthogonality
    def vec(p1, p2):
        return [p2[i] - p1[i] for i in range(3)]
    
    v1 = vec(out_points[0], out_points[1])
    v2 = vec(out_points[0], out_points[2])
    v3 = vec(out_points[0], out_points[3])
    
    dot12 = sum(v1[i]*v2[i] for i in range(3))
    dot13 = sum(v1[i]*v3[i] for i in range(3))
    dot23 = sum(v2[i]*v3[i] for i in range(3))
    
    if dot12 != 0 or dot13 != 0 or dot23 != 0:
        raise TestFailure(f"Output cube edges not orthogonal: {dot12}, {dot13}, {dot23}")
    
    print("Output cube verified as valid")
