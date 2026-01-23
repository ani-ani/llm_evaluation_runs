import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from cocotb.result import TestFailure
import random

def check_collapse_2lines(points):
    """Reference Python implementation for test verification"""
    n = len(points)
    if n <= 2:
        return True
    
    def is_collinear(pts):
        if len(pts) <= 2:
            return True
        p0 = pts[0]
        p1 = pts[1]
        for i in range(2, len(pts)):
            p2 = pts[i]
            # (x1-x0)*(y2-y0) == (x2-x0)*(y1-y0)
            lhs = (p1[0] - p0[0]) * (p2[1] - p0[1])
            rhs = (p2[0] - p0[0]) * (p1[1] - p0[1])
            if lhs != rhs:
                return False
        return True

    if is_collinear(points):
        return True
        
    # Try combinations based on first 3 points
    strategies = [
        (0, 1), # Line P0-P1
        (0, 2), # Line P0-P2
        (1, 2)  # Line P1-P2
    ]
    
    for i, j in strategies:
        line_p1 = points[i]
        line_p2 = points[j]
        remaining = []
        for k in range(n):
            # Check if points[k] is on line (line_p1, line_p2)
            # Cross product: (line_p2.x - line_p1.x)*(points[k].y - line_p1.y) == (points[k].x - line_p1.x)*(line_p2.y - line_p1.y)
            lhs = (line_p2[0] - line_p1[0]) * (points[k][1] - line_p1[1])
            rhs = (points[k][0] - line_p1[0]) * (line_p2[1] - line_p1[1])
            if lhs == rhs:
                continue
            remaining.append(points[k])
        
        if len(remaining) <= 1:
            return True
        if is_collinear(remaining):
            return True
            
    return False

@cocotb.test()
async def test_collinear_checker(dut):
    """Test collinear_checker module"""
    
    # Setup clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    for i in range(5):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Define test cases
    test_cases = [
        # Case 1: Sample Input - failure (6 points, not 2 lines)
        {
            "points": [(-1, 0), (0, 0), (1, 0), (-1, 1), (0, 2), (1, 1)],
            "expected": False
        },
        # Case 2: success
        {
            "points": [(1, 1), (3, 5), (0, -1), (1, 0), (5, 0), (0, 0)],
            "expected": True
        },
        # Case 3: failure
        {
            "points": [(1, 1), (3, 5), (0, -1), (1, 0), (5, 0), (0, 1)],
            "expected": False
        },
        # Case 4: failure
        {
            "points": [(6, 1), (3, 5), (0, -1), (1, 0), (6, 0), (0, 0)],
            "expected": False
        },
        # Case 5: All collinear (should be success)
        {
            "points": [(0, 0), (1, 1), (2, 2), (3, 3)],
            "expected": True
        },
        # Case 6: Small N (N=2)
        {
            "points": [(10, 20), (30, 40)],
            "expected": True
        },
        # Case 7: 3 points not collinear (needs 2 lines -> success)
        {
            "points": [(0, 0), (1, 0), (0, 1)],
            "expected": True
        },
        # Case 8: 4 points, cross shape (needs 2 lines -> success)
        {
            "points": [(0, 0), (1, 0), (0, 1), (1, 1)],
            "expected": False  # Actually requires 3 lines (square corners), wait... 
            # Diagonal (0,0)-(1,1) and (0,1)-(1,0) don't hit all. 
            # Any line hits max 2 corners. 2 lines max 4 corners? 
            # (0,0)-(1,1) hits 2. (0,1)-(1,0) hits 2. Total 4. Yes. So Success.
        }
    ]
    
    # Override Case 8 calculation:
    # (0,0), (1,0), (0,1), (1,1). 
    # Strategy: Line (0,0)-(1,1). Remaining (1,0), (0,1). Collinear? No.
    # Strategy: Line (0,0)-(1,0). Remaining (0,1), (1,1). Collinear? No.
    # Strategy: Line (0,0)-(0,1). Remaining (1,0), (1,1). Collinear? No.
    # Strategy: Line (1,0)-(1,1). Remaining (0,0), (0,1). Collinear? No.
    # Strategy: Line (0,1)-(1,1). Remaining (0,0), (1,0). Collinear? No.
    # Strategy: Line (0,1)-(1,0). Remaining (0,0), (1,1). Collinear? No.
    # So Case 8 should be False. 
    test_cases[7]["expected"] = False

    passed = 0
    total = len(test_cases)
    
    for idx, tc in enumerate(test_cases):
        points = tc["points"]
        expected = tc["expected"]
        n = len(points)
        
        # Sanity check scaling
        if n > 16:
            print(f"Skipping case {idx}: N={n} > 16")
            total -= 1
            continue
            
        # Load inputs
        # Since Verilog arrays are packed/unpacked, we need to set carefully.
        # In cocotb, for unpacked arrays like [15:0] [7:0], we set individual elements.
        # Or if using SystemVerilog, direct assignment might work. 
        # We assume the DUT has inputs: point_x [0:15], point_y [0:15]
        
        for i in range(16):
            if i < n:
                # Ensure coordinates fit in 8 bits (signed or unsigned?)
                # Problem says -10^9 to 10^9. We must scale/shift in testbench to fit 8-bit signed (-128 to 127) or unsigned (0-255).
                # Our Verilog spec uses [7:0]. Let's assume unsigned 0-255 or mapped coordinates.
                # To make it work with arbitrary Python inputs, we map them.
                # However, the Python inputs in examples are small (e.g. -1 to 6).
                # Let's map them: x + 100 to make positive? No, [7:0] implies 0-255 unsigned or -128..127 signed.
                # If signed, python -1 is 0xFF.
                # Let's assume signed [7:0]. 
                x, y = points[i]
                # Clamp to 8-bit signed range for safety, though examples fit.
                x = max(-128, min(127, x))
                y = max(-128, min(127, y))
                
                # In cocotb, integer logic is handled. Just assign integer value.
                # If DUT is logic [7:0], it takes lower 8 bits.
                dut.point_x[i].value = x & 0xFF
                dut.point_y[i].value = y & 0xFF
            else:
                dut.point_x[i].value = 0
                dut.point_y[i].value = 0
        
        dut.num_points.value = n
        
        # Start pulse
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        timeout = 50
        for _ in range(timeout):
            await RisingEdge(dut.clk)
            if dut.done.value == 1:
                break
        else:
            raise TestFailure(f"Case {idx}: Timeout waiting for done")
            
        # Check result
        # dut.success should be 1 for True, 0 for False
        result = bool(dut.success.value)
        
        print(f"Case {idx}: Points={points}, Expected={expected}, Got={result}")
        
        if result == expected:
            passed += 1
        else:
            raise TestFailure(f"Case {idx} failed. Expected {expected}, got {result}")
            
    print(f"
Summary: {passed}/{total} tests passed")
