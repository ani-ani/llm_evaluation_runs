import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import math

# Constants
DATA_WIDTH = 16
COORD_WIDTH = 16
CLK_NS = 10

# Helpers
def clamp(v, bits):
    max_val = (1 << bits) - 1
    return max(0, min(max_val, v))

def to_signed(v, bits):
    if v >= (1 << (bits - 1)):
        return v - (1 << bits)
    return v

def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

async def reset_dut(dut):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(2): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

# Exact Python Reference for Validation (Fixed-point compatible logic)
def calculate_expected(L, x1, y1, x2, y2):
    # Line equation: ax + by + c = 0
    # a = y1 - y2, b = x2 - x1
    a = y1 - y2
    b = x2 - x1
    c = x1*y2 - x2*y1
    
    # Distance from (0,0) to line: |c| / sqrt(a^2 + b^2)
    dist_numer = abs(c)
    dist_denom = math.sqrt(a*a + b*b)
    D = dist_numer / dist_denom
    
    # Binary search for R
    low, high = 1, 100
    best = high
    
    while low <= high:
        R = (low + high) // 2
        if D >= R:
            area = math.pi * R * R
        else:
            # Area of circular segment (larger part)
            # Area = R^2 * acos(D/R) - D * sqrt(R^2 - D^2)
            theta = 2 * math.acos(D / R)
            # Area of segment = 0.5 * R^2 * (theta - sin(theta))
            # We want the larger part: Circle Area - Segment
            # Or directly: 0.5 * R^2 * (2*pi - (theta - sin(theta)))
            # Let's stick to the standard clipped area formula:
            # Area = R^2 * acos(D/R) - D * sqrt(R^2 - D^2)
            # Note: This formula gives the area of the CAP (small part). 
            # The accessible area is the rest of the circle (unless the wall is on one side only).
            # The problem implies the wall blocks access. 
            # The problem says "William can not cross the wall".
            # Usually, this implies he is on one side.
            # Let's assume the accessible area is the half-circle or clipped part depending on D.
            # Actually, standard interpretation: The dog is at (0,0). The wall is a line.
            # The dog can access the half-plane defined by the line (assuming arbitrary side).
            # Area = 0.5 * pi * R^2 if D=0.
            # Area = pi * R^2 if D >> R.
            # Area of intersection of circle and half-plane.
            # If D >= 0 (distance from center to line):
            # Area = R^2 * acos(D/R) - D * sqrt(R^2 - D^2)  <-- This is the area of the CAP (cut off).
            # The accessible area is the rest of the circle? Or the cap?
            # "Minimize the area he can cover while still being able to cover the whole lawn."
            # "Guard the lawn from trespassers."
            # The wall blocks the dog. The lawn is on the other side.
            # The dog covers the area accessible to him (half-space clipped by circle).
            # Accessible area = Circle Area - Cap Area.
            # = pi*R^2 - (R^2 * acos(D/R) - D * sqrt(R^2 - D^2))
            # = R^2 * (pi - acos(D/R)) + D * sqrt(R^2 - D^2)
            # 
            # Wait, standard formula for area of circle cut by a line at distance D:
            # Sector area: R^2 * acos(D/R)
            # Triangle area: D * sqrt(R^2 - D^2)
            # The CAP area (the small part cut off) = Sector - Triangle.
            # The accessible area (large part) = Circle Area - Cap Area.
            # = pi*R^2 - (R^2 * acos(D/R) - D * sqrt(R^2 - D^2))
            # = R^2 * (pi - acos(D/R)) + D * sqrt(R^2 - D^2)
            #
            # Let's verify with D=0 (line through center).
            # Accessible area should be 0.5 * pi * R^2.
            # Formula: R^2 * (pi - acos(0)) + 0 = R^2 * (pi - pi/2) = 0.5 * pi * R^2. Correct.
            #
            # However, the sample input:
            # L=4, Wall x=-10 (vertical line at -10, 0).
            # Origin is at 0,0. Distance D = 10.
            # R=2. D=10. D > R. No intersection.
            # Accessible area = pi * R^2 = 4*pi = ~12.56.
            # 12.56 > 4. Correct.
            #
            # Sample 2:
            # L=314. Wall line through (100,100) and (-100,-100). Line y=x.
            # Distance from (0,0) to y=x is 0.
            # Accessible area = 0.5 * pi * R^2 >= 314
            # R^2 >= 2 * 314 / pi = 200
            # R >= sqrt(200) = 14.14. So R=15. Correct.
            
            acos_D_R = math.acos(D / R)
            sqrt_part = math.sqrt(R*R - D*D)
            cap_area = R*R * acos_D_R - D * sqrt_part
            circle_area = math.pi * R * R
            accessible_area = circle_area - cap_area
            area = accessible_area
            
        if area >= L:
            best = R
            high = R - 1
        else:
            low = R + 1
    return best

@cocotb.test(timeout_time=2000, timeout_unit="ms")
async def test_dog_chain(dut):
    # Setup Clock
    clock = Clock(dut.clk, CLK_NS, units="ns")
    cocotb.start_soon(clock.start())
    await reset_dut(dut)
    
    # Test cases
    test_vectors = [
        (4, -10, 0, -10, 10),
        (314, 100, 100, -100, -100)
    ]
    
    for L, x1, y1, x2, y2 in test_vectors:
        # Calculate Expected
        expected_R = calculate_expected(L, x1, y1, x2, y2)
        cocotb.log.info(f"Testing L={L}, Wall ({x1},{y1})-({x2},{y2}). Expected R={expected_R}")
        
        # Drive Inputs
        dut.L.value = L
        dut.x1.value = x1 & 0xFFFF
        dut.y1.value = y1 & 0xFFFF
        dut.x2.value = x2 & 0xFFFF
        dut.y2.value = y2 & 0xFFFF
        
        # Start
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for Done
        done = False
        for _ in range(1000):
            await RisingEdge(dut.clk)
            if has_signal(dut, 'done') and is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                done = True
                break
        
        if not done:
            raise TestFailure("Timeout waiting for done")
            
        # Read Result
        if not has_signal(dut, 'R'):
             raise TestFailure("Signal 'R' missing")
             
        result = int(dut.R.value)
        cocotb.log.info(f"Result R={result}")
        
        if result != expected_R:
            raise TestFailure(f"Mismatch: Expected {expected_R}, Got {result}")
