import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Configuration
DATA_WIDTH = 24
POINT_COUNT = 8
COORD_COUNT = 3

# Helper functions
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

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

# Write point to DUT
def write_point(dut, point_idx, coords):
    for coord_idx in range(COORD_COUNT):
        port_name = f'in{point_idx}_{coord_idx}'
        if has_signal(dut, port_name):
            val = coords[coord_idx]
            if val < 0:
                val = val + (1 << DATA_WIDTH)  # Convert to unsigned
            setattr(dut, port_name, val)
        else:
            raise TestFailure(f"Signal {port_name} not found")

# Read point from DUT
def read_point(dut, point_idx):
    coords = []
    for coord_idx in range(COORD_COUNT):
        port_name = f'out{point_idx}_{coord_idx}'
        if has_signal(dut, port_name):
            val = getattr(dut, port_name).value
            if is_value_defined(val):
                coord_val = int(val)
                if coord_val >= (1 << (DATA_WIDTH-1)):  # Signed
                    coord_val -= (1 << DATA_WIDTH)
                coords.append(coord_val)
            else:
                coords.append(None)
        else:
            raise TestFailure(f"Signal {port_name} not found")
    return coords

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_cube_checker(dut):
    """Test cube detection with valid and invalid cases"""
    
    # Test case 1: Valid cube (unit cube in correct order)
    valid_cube = [
        [0, 0, 0],
        [1, 0, 0],
        [0, 1, 0],
        [1, 1, 0],
        [0, 0, 1],
        [1, 0, 1],
        [0, 1, 1],
        [1, 1, 1]
    ]
    
    # Test case 2: Invalid case (all points at origin)
    invalid_case = [[0,0,0] for _ in range(8)]
    
    # Test case 3: Valid cube but permuted (should work if input is correct)
    permuted_cube = [
        [0, 0, 0],
        [0, 0, 1],
        [0, 1, 0],
        [1, 0, 0],
        [0, 1, 1],
        [1, 0, 1],
        [1, 1, 0],
        [1, 1, 1]
    ]
    
    test_cases = [
        (valid_cube, True, "Unit cube"),
        (invalid_case, False, "All zeros"),
        (permuted_cube, True, "Permuted unit cube")
    ]
    
    for idx, (points, expected, desc) in enumerate(test_cases):
        dut._log.info(f"Test {idx+1}: {desc}")
        
        # Write inputs
        for p_idx, coords in enumerate(points):
            write_point(dut, p_idx, coords)
        
        # Allow combinational propagation
        await Timer(100, units='ns')
        
        # Read results
        result = int(dut.is_cube.value)
        
        if result != expected:
            # On failure, read outputs for debugging
            output_points = [read_point(dut, i) for i in range(8)]
            dut._log.error(f"Output points: {output_points}")
            raise TestFailure(f"Test {idx+1} failed: Expected {expected}, got {result}")
        
        dut._log.info(f"  PASS: is_cube={result}")
    
    dut._log.info("All tests completed successfully!")
