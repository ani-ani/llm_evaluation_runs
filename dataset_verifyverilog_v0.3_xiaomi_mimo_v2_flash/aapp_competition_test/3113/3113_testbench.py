import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Helper functions from template
def is_value_defined(value):
    try:
        int(value)
        return True
    except ValueError:
        return False

def clamp_to_width(value, bits):
    max_val = (1 << bits) - 1
    return min(max_val, max(0, value))

async def write_triangle_array(dut, array_name, triangles, n):
    """Write triangle array elements individually"""
    for t in range(8):
        for v in range(3):
            for c in range(2):
                port_name = f"{array_name}_{t}_{v}_{c}"
                if hasattr(dut, port_name):
                    if t < n:
                        val = triangles[t][v][c]
                        setattr(dut, port_name, clamp_to_width(val, 6))
                    else:
                        setattr(dut, port_name, 0)
                else:
                    # Fallback to array indexing
                    try:
                        if t < n:
                            val = triangles[t][v][c]
                            getattr(dut, array_name)[t][v][c].value = clamp_to_width(val, 6)
                        else:
                            getattr(dut, array_name)[t][v][c].value = 0
                    except:
                        raise TestFailure(f"Cannot access {array_name}[{t}][{v}][{c}]")

async def wait_for_done(dut, max_cycles=10000):
    """Wait for done signal with timeout"""
    for cycle in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout: done not asserted after {max_cycles} cycles")

async def reset_dut(dut):
    """Standard reset sequence"""
    dut.rst_n.value = 0
    dut.n.value = 0
    dut.m.value = 0
    for _ in range(2):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

# Software model for comparison
def rasterize_triangle(triangle, grid_size=16):
    """Rasterize a single triangle to grid"""
    grid = [[0]*grid_size for _ in range(grid_size)]
    # Scale vertices by 2
    A = (triangle[0][0]*2, triangle[0][1]*2)
    B = (triangle[1][0]*2, triangle[1][1]*2)
    C = (triangle[2][0]*2, triangle[2][1]*2)
    
    for i in range(grid_size):
        for j in range(grid_size):
            # Pixel center at (2*i+1, 2*j+1)
            Px = 2*i + 1
            Py = 2*j + 1
            
            # Check with barycentric method
            def cross(o, a, b):
                return (a[0]-o[0])*(b[1]-o[1]) - (a[1]-o[1])*(b[0]-o[0])
            
            d1 = cross(A, B, (Px, Py))
            d2 = cross(B, C, (Px, Py))
            d3 = cross(C, A, (Px, Py))
            
            has_neg = (d1 < 0) or (d2 < 0) or (d3 < 0)
            has_pos = (d1 > 0) or (d2 > 0) or (d3 > 0)
            
            if not (has_neg and has_pos):
                grid[i][j] = 1
    return grid

def compare_grids(grid1, grid2):
    """Compare two grids"""
    for i in range(16):
        for j in range(16):
            if grid1[i][j] != grid2[i][j]:
                return False
    return True

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_cloud_compare(dut):
    """Main test function"""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test cases: (garry_triangles, jerry_triangles, expected_same, description)
    # Triangles are [x1,y1], [x2,y2], [x3,y3] with coordinates 0-15
    test_cases = [
        # Same single triangle
        ([[[2,2], [14,2], [8,14]]], [[[2,2], [14,2], [8,14]]], True, "Same single triangle"),
        # Different triangles
        ([[[2,2], [14,2], [8,14]]], [[[2,2], [14,2], [8,13]]], False, "Slightly different"),
        # Empty sets
        ([], [], True, "Both empty"),
        # Different number of triangles
        ([[[1,1], [5,1], [3,5]]], [[[1,1], [5,1], [3,5]], [[7,7], [11,7], [9,11]]], False, "Different counts"),
        # Same area, different shape
        ([[[2,2], [10,2], [2,10]]], [[[2,2], [10,2], [10,10]], [[2,2], [10,10], [2,10]]], False, "Split triangle"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (garry, jerry, expected, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc}")
        
        try:
            # Prepare data
            n = len(garry)
            m = len(jerry)
            
            # Scale triangles by 2 for hardware
            garry_scaled = [[[v*2 for v in tri[j]] for j in range(3)] for tri in garry]
            jerry_scaled = [[[v*2 for v in tri[j]] for j in range(3)] for tri in jerry]
            
            # Write inputs
            dut.n.value = n
            dut.m.value = m
            await write_triangle_array(dut, 'garry_triangles', garry_scaled, n)
            await write_triangle_array(dut, 'jerry_triangles', jerry_scaled, m)
            
            # Wait for computation
            await wait_for_done(dut)
            
            # Read result
            if not is_value_defined(dut.same.value):
                raise TestFailure("Result is undefined (X/Z)")
            
            result = bool(int(dut.same.value))
            
            # Software verification
            grid1 = []
            for tri in garry:
                grid1.extend(rasterize_triangle(tri))
            grid2 = []
            for tri in jerry:
                grid2.extend(rasterize_triangle(tri))
            
            # Combine grids (union)
            combined1 = [[0]*16 for _ in range(16)]
            for tri in garry:
                grid = rasterize_triangle(tri)
                for r in range(16):
                    for c in range(16):
                        combined1[r][c] |= grid[r][c]
            
            combined2 = [[0]*16 for _ in range(16)]
            for tri in jerry:
                grid = rasterize_triangle(tri)
                for r in range(16):
                    for c in range(16):
                        combined2[r][c] |= grid[r][c]
            
            software_result = compare_grids(combined1, combined2)
            
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            if result != software_result:
                cocotb.log.warning(f"Hardware/software mismatch: HW={result}, SW={software_result}")
            
            cocotb.log.info(f"  PASS: result={result}")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
        
        # Reset for next test
        await reset_dut(dut)
    
    # Summary
    cocotb.log.info(f"{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")
