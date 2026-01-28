import cocotb
from cocotb.triggers import Timer
from cocotb.result import TestFailure

# Helper to check if a signal is defined (not X/Z)
def is_value_defined(value):
    try:
        int(value)
        return True
    except ValueError:
        return False

# Helper to check if a signal exists
def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

# Python reference for circumsphere center
def compute_center(p0, p1, p2, p3):
    """Compute circumsphere center of tetrahedron."""
    u = [p1[i] - p0[i] for i in range(3)]
    v = [p2[i] - p0[i] for i in range(3)]
    w = [p3[i] - p0[i] for i in range(3)]
    dot_u = u[0]*u[0] + u[1]*u[1] + u[2]*u[2]
    dot_v = v[0]*v[0] + v[1]*v[1] + v[2]*v[2]
    dot_w = w[0]*w[0] + w[1]*w[1] + w[2]*w[2]
    cross_vw = [v[1]*w[2] - v[2]*w[1],
                v[2]*w[0] - v[0]*w[2],
                v[0]*w[1] - v[1]*w[0]]
    cross_wu = [w[1]*u[2] - w[2]*u[1],
                w[2]*u[0] - w[0]*u[2],
                w[0]*u[1] - w[1]*u[0]]
    cross_uv = [u[1]*v[2] - u[2]*v[1],
                u[2]*v[0] - u[0]*v[2],
                u[0]*v[1] - u[1]*v[0]]
    num = [dot_u*cross_vw[0] + dot_v*cross_wu[0] + dot_w*cross_uv[0],
           dot_u*cross_vw[1] + dot_v*cross_wu[1] + dot_w*cross_uv[1],
           dot_u*cross_vw[2] + dot_v*cross_wu[2] + dot_w*cross_uv[2]]
    denom = 2 * (u[0]*cross_vw[0] + u[1]*cross_vw[1] + u[2]*cross_vw[2])
    X = [num[i] / denom for i in range(3)]
    center = [p0[i] + X[i] for i in range(3)]
    return center

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_circumsphere(dut):
    """Test circumsphere module with example test cases."""
    test_cases = [
        [(0,0,0), (1,0,0), (0,1,0), (0,0,1)],
        [(-1,0,0), (1,0,0), (0,1,0), (0,0,1)],
        [(0,0,0), (7,0,0), (0,6,0), (1,-2,-3)]
    ]
    expected_centers = [
        [0.5, 0.5, 0.5],
        [0.0, 0.0, 0.0],
        [3.5, 3.0, -3.1666666666666665]
    ]
    TOL = 1e-4
    for idx, (points, expected) in enumerate(zip(test_cases, expected_centers)):
        cocotb.log.info(f"Test {idx+1}: points={points}")
        # Write inputs
        for i, pt in enumerate(points):
            for j, coord in enumerate(['x', 'y', 'z']):
                port_name = f'p{i}_{coord}'
                if has_signal(dut, port_name):
                    val = pt[j]
                    if val > 127: val = 127
                    if val < -128: val = -128
                    getattr(dut, port_name).value = val
                else:
                    raise TestFailure(f"Port {port_name} not found")
        # Wait for combinational logic
        await Timer(10, units='ns')
        # Read outputs
        if not all(has_signal(dut, 'x_c'), has_signal(dut, 'y_c'), has_signal(dut, 'z_c')):
            raise TestFailure("Output signals x_c, y_c, z_c not found")
        x_c_raw = int(dut.x_c.value)
        y_c_raw = int(dut.y_c.value)
        z_c_raw = int(dut.z_c.value)
        x_c_float = x_c_raw / 65536.0
        y_c_float = y_c_raw / 65536.0
        z_c_float = z_c_raw / 65536.0
        error = ((x_c_float - expected[0])**2 + (y_c_float - expected[1])**2 + (z_c_float - expected[2])**2)**0.5
        if error >= TOL:
            raise TestFailure(f"Test {idx+1} failed: error={error}, expected={expected}, got=({x_c_float}, {y_c_float}, {z_c_float})")
        cocotb.log.info(f"  PASS: center = ({x_c_float:.6f}, {y_c_float:.6f}, {z_c_float:.6f})")
    cocotb.log.info("All tests passed!")