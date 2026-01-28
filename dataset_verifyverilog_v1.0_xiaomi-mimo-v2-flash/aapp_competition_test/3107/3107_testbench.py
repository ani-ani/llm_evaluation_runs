import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import itertools

# Helper functions
def is_value_defined(v):
    try:
        int(v)
        return True
    except ValueError:
        return False

def safe_int(v, default=0):
    try:
        return int(v)
    except ValueError:
        return default

def clamp_to_width(v, bits):
    max_val = (1 << bits) - 1
    return min(max_val, max(0, v))

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

# --- Simulation Logic ---
def simulate_encounters(truck_a, truck_b):
    """
    truck_a: list of city coordinates [x0, x1, ...]
    truck_b: list of city coordinates [y0, y1, ...]
    Returns count of meetings.
    """
    count = 0
    
    def get_segments(route):
        segments = []
        t = 0
        for i in range(len(route) - 1):
            p1 = route[i]
            p2 = route[i+1]
            dist = abs(p2 - p1)
            if dist == 0:
                # Should not happen per problem logic (non-zero movement), but skip to avoid div by zero
                continue
            # Time duration is distance
            # Segment: (start_time, start_pos, end_time, end_pos)
            segments.append((t, p1, t + dist, p2))
            t += dist
        return segments

    segs_a = get_segments(truck_a)
    segs_b = get_segments(truck_b)

    for (t1, p1, t2, p2) in segs_a:
        for (t3, p3, t4, p4) in segs_b:
            # Segment A: pos = p1 + (p2-p1)/(t2-t1) * (t - t1)
            # Segment B: pos = p3 + (p4-p3)/(t4-t3) * (t - t3)
            # Intersection: p1 + vA * (t - t1) = p3 + vB * (t - t3)
            # where vA = (p2-p1)/(t2-t1), vB = (p4-p3)/(t4-t3)
            
            dt_a = t2 - t1
            dt_b = t4 - t3
            dp_a = p2 - p1
            dp_b = p4 - p3

            # Check parallel: dp_a/dt_a == dp_b/dt_b  => dp_a*dt_b == dp_b*dt_a
            if dp_a * dt_b == dp_b * dt_a:
                # Parallel lines. Check if collinear.
                # If p1 + vA*(t3-t1) == p3, then collinear.
                # Check relative position at t3
                val = p1 * dt_a + dp_a * (t3 - t1)
                if val == p3 * dt_a:
                    # Collinear. 
                    # Problem guarantees no meetings at endpoints or turns.
                    # So we only count if they share a strictly internal point.
                    # Since they are collinear and move continuously, if intervals (t1, t2) and (t3, t4) overlap,
                    # they meet for a duration, but usually "meeting" implies a point.
                    # Given problem constraints "won't be at same place... turning", implies we only count crossing intersections.
                    # Or strict interior overlaps.
                    # Given constraints "they won't be at same place in initial moment or turn", 
                    # if collinear, they might meet in the middle.
                    # However, typical interpretation for this problem class (IOI style) is counting intersection points.
                    # Collinear overlap implies infinite points. But problem constraints likely prevent this or count it as 1 event if restricted.
                    # Given constraints "only pairs we want to know..." (guarantees no weird collisions), 
                    # we assume non-parallel or strict crossing.
                    # We will assume standard intersection logic.
                    pass
                continue

            # Intersection time t
            # t = (p3 - p1 + vA*t1 - vB*t3) / (vA - vB)
            # Using cross-multiply to avoid float:
            # (t - t1) * dp_a * dt_b = (p3 - p1) * dt_a * dt_b - dp_b * dt_a * (t - t3)
            # Let's use the formula derived from linear equation:
            # (p1 - p3) * dt_a * dt_b = (t - t1) * dp_a * dt_b - (t - t3) * dp_b * dt_a
            # This is getting messy. Let's use standard cross product method.
            
            # Line 1: (t1, p1) to (t2, p2)
            # Line 2: (t3, p3) to (t4, p4)
            # Intersection check:
            # (t2 - t1) * (p3 - p1) ?
            # Let's use the standard 2D segment intersection test for lines parameterized by time.
            # P = P1 + (P2-P1)*(t-t1)/(t2-t1)
            # We want P1 + dA * u = P3 + dB * v where u, v in (0, 1)
            # dA = (p2-p1, t2-t1), dB = (p4-p3, t4-t3)
            # (p1-p3, t1-t3) cross (dB) = u * (dA cross dB)
            
            # Cross product of dA and dB (in 2D: x dy - y dx)
            # Here x is position, y is time.
            cp = dp_a * dt_b - dt_a * dp_b  # dA x dB
            
            if cp == 0:
                continue

            # Check if intersection lies within segments
            # U = (p3 - p1) * dt_b - (t3 - t1) * dp_b
            # V = (p3 - p1) * dt_a - (t3 - t1) * dp_a
            # Note: signs depend on vector directions. 
            # Intersection point relative to A: (p3 - p1, t3 - t1) x dB
            # u = ((p3-p1)*dt_b - (t3-t1)*dp_b) / cp
            
            num_u = (p3 - p1) * dt_b - (t3 - t1) * dp_b
            num_v = (p1 - p3) * dt_a - (t1 - t3) * dp_a  # relative to B: (p1-p3, t1-t3) x dA

            # We need intersection strictly inside (0,1) for parameters u and v
            # i.e. 0 < num_u < cp  (assuming cp > 0) or cp < num_u < 0 (if cp < 0)
            # Same for v.
            # Since we want strictly inside, we check 0 < num_u < cp or cp < num_u < 0
            # Equivalent to: num_u * cp > 0 and abs(num_u) < abs(cp)
            
            if (num_u * cp > 0) and (abs(num_u) < abs(cp)) and \
               (num_v * cp > 0) and (abs(num_v) < abs(cp)):
                count += 1
                
    return count

@cocotb.test(timeout_time=2000, timeout_unit="ms")
async def test_truck_encounters(dut):
    # Setup Clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.config_en.value = 0
    dut.data_in.value = 0
    dut.addr_in.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test Case 1 from Sample
    # 3 Trucks
    # Truck 0: 3 1 3 1  -> Cities [1, 3, 1]
    # Truck 1: 2 2 1    -> Cities [2, 1]
    # Truck 2: 3 3 1 3  -> Cities [3, 1, 3]
    
    trucks = [
        [1, 3, 1],
        [2, 1],
        [3, 1, 3]
    ]
    
    queries = [
        (0, 1), # 1 2
        (1, 2), # 2 3
        (2, 0)  # 3 1
    ]
    
    expected = [1, 0, 2]
    
    # Load Routes
    dut.config_en.value = 0
    for i, route in enumerate(trucks):
        dut.addr_in.value = i
        # Send Length
        dut.data_in.value = len(route)
        await RisingEdge(dut.clk)
        # Send Cities
        for city in route:
            dut.data_in.value = city
            await RisingEdge(dut.clk)
            
    # Load Queries
    dut.config_en.value = 1
    for i, (a, b) in enumerate(queries):
        dut.addr_in.value = i
        # Pack 4-bit truck IDs into 8-bit
        dut.data_in.value = (a << 4) | b
        await RisingEdge(dut.clk)
        
    # Start Processing
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for results
    # The module should output results sequentially
    for i, exp in enumerate(expected):
        # Wait for result_valid or check output directly if pipelined
        # Assuming polling or waiting for valid signal
        timeout = 0
        while not has_signal(dut, 'result_valid') or int(dut.result_valid.value) == 0:
            await RisingEdge(dut.clk)
            timeout += 1
            if timeout > 500:
                raise TestFailure(f"Timeout waiting for result {i}")
        
        result = int(dut.result_count.value)
        if result != exp:
            raise TestFailure(f"Query {i+1}: Expected {exp}, got {result}")
            
        await RisingEdge(dut.clk) # Consume result

    # Test Case 2
    # Reset for second test case
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Truck 0: 4 1 6 3 6 -> [1, 6, 3, 6]
    # Truck 1: 7 3 4 2 6 5 6 1 -> [3, 4, 2, 6, 5, 6, 1]
    trucks_2 = [
        [1, 6, 3, 6],
        [3, 4, 2, 6, 5, 6, 1]
    ]
    queries_2 = [(0, 1)]
    expected_2 = [3]
    
    dut.config_en.value = 0
    for i, route in enumerate(trucks_2):
        dut.addr_in.value = i
        dut.data_in.value = len(route)
        await RisingEdge(dut.clk)
        for city in route:
            dut.data_in.value = city
            await RisingEdge(dut.clk)
            
    dut.config_en.value = 1
    dut.addr_in.value = 0
    dut.data_in.value = (0 << 4) | 1
    await RisingEdge(dut.clk)
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for exp in expected_2:
        timeout = 0
        while not has_signal(dut, 'result_valid') or int(dut.result_valid.value) == 0:
            await RisingEdge(dut.clk)
            timeout += 1
            if timeout > 500:
                raise TestFailure(f"Timeout waiting for result (Case 2)")
        
        result = int(dut.result_count.value)
        if result != exp:
            raise TestFailure(f"Case 2: Expected {exp}, got {result}")
            
        await RisingEdge(dut.clk)