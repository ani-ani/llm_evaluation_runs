import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
from collections import defaultdict

# ============================================================================
# MANDATORY HELPER FUNCTIONS
# ============================================================================

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

def clamp_to_width(value, bits):
    max_val = (1 << bits) - 1
    return min(max_val, max(0, value))

# ============================================================================
# PYTHON REFERENCE IMPLEMENTATION
# ============================================================================

def reference_solve(N, trains):
    """Reference implementation for verification."""
    by_station = defaultdict(list)
    for station, S, T, L in trains:
        by_station[station].append((S, T, L))
    
    for station in by_station:
        by_station[station].sort(key=lambda x: x[0])
    
    trains1 = by_station.get(0, [])
    if not trains1:
        return None
    
    best_s = None
    
    for s, t, l in trains1:
        # On-time simulation
        time = s
        station = 1
        feasible_on = True
        while station < N:
            next_train = None
            for ts, tt, tl in by_station.get(station, []):
                if ts >= time:
                    next_train = (ts, tt, tl)
                    break
            if not next_train:
                feasible_on = False
                break
            time = next_train[1]
            station += 1
        
        if not feasible_on:
            continue
        
        a_on = time
        
        # Actual simulation
        time = s
        station = 1
        feasible_actual = True
        while station < N:
            next_train = None
            for ts, tt, tl in by_station.get(station, []):
                if ts + tl >= time:
                    next_train = (ts, tt, tl)
                    break
            if not next_train:
                feasible_actual = False
                break
            time = next_train[1] + next_train[2]
            station += 1
        
        if not feasible_actual:
            if best_s is None or s < best_s:
                best_s = s
        elif time - a_on >= 1800:
            if best_s is None or s < best_s:
                best_s = s
    
    return best_s

# ============================================================================
# MAIN TESTBENCH
# ============================================================================

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_train_compensation(dut):
    """Test train compensation module."""
    
    TIME_WIDTH = 12
    STATION_WIDTH = 3
    
    # Detect interface
    is_sequential = has_signal(dut, 'clk')
    has_packed = has_signal(dut, 'train_data')
    has_rst = has_signal(dut, 'rst_n')
    has_start = has_signal(dut, 'start')
    
    # Clock and reset
    if is_sequential:
        cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
        if has_rst:
            dut.rst_n.value = 0
            if has_start:
                dut.start.value = 0
            for _ in range(2):
                await RisingEdge(dut.clk)
            dut.rst_n.value = 1
            await RisingEdge(dut.clk)
    
    # Test cases
    test_cases = [
        (2, 3, [(0, 1800, 9000, 1800), (0, 2000, 9200, 1600), (0, 2200, 9400, 1400)]),
        (2, 2, [(0, 1800, 3600, 1800), (0, 1900, 3600, 1600)]),
        (3, 2, [(0, 10, 20, 1), (1, 20, 30, 0)]),
    ]
    
    for case_idx, (N, M, trains) in enumerate(test_cases):
        cocotb.log.info(f"Test {case_idx + 1}: N={N}, M={M}")
        
        # Compute expected
        expected = reference_solve(N, trains)
        if expected is None:
            cocotb.log.info(f"  Expected: impossible")
        else:
            cocotb.log.info(f"  Expected: {expected}")
        
        # Load configuration
        if has_signal(dut, 'N'):
            dut.N.value = N
        if has_signal(dut, 'M'):
            dut.M.value = M
        
        # Load trains
        if has_packed:
            for idx, (station, S, T, L) in enumerate(trains):
                packed = (station << 36) | (S << 24) | (T << 12) | L
                dut.train_data.value = clamp_to_width(packed, 48)
                dut.train_valid.value = 1
                if idx == len(trains) - 1 and has_signal(dut, 'train_last'):
                    dut.train_last.value = 1
                await RisingEdge(dut.clk)
            dut.train_valid.value = 0
            if has_signal(dut, 'train_last'):
                dut.train_last.value = 0
        else:
            # Handle individual ports
            for idx, (station, S, T, L) in enumerate(trains):
                port_found = False
                # Try arr_i pattern
                if has_signal(dut, f'train_{idx}_station'):
                    getattr(dut, f'train_{idx}_station').value = station
                    getattr(dut, f'train_{idx}_S').value = S
                    getattr(dut, f'train_{idx}_T').value = T
                    getattr(dut, f'train_{idx}_L').value = L
                    port_found = True
                # Try array pattern
                elif has_signal(dut, 'train_station') and has_signal(dut, 'train_S'):
                    try:
                        dut.train_station[idx].value = station
                        dut.train_S[idx].value = S
                        dut.train_T[idx].value = T
                        dut.train_L[idx].value = L
                        port_found = True
                    except:
                        pass
                
                if not port_found:
                    cocotb.log.warning(f"  Warning: Could not load train {idx}")
            
            if has_signal(dut, 'load_done'):
                dut.load_done.value = 1
                await RisingEdge(dut.clk)
                dut.load_done.value = 0
        
        # Start computation
        if has_signal(dut, 'start'):
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
        
        # Wait for result
        for _ in range(10000):
            await RisingEdge(dut.clk)
            if has_signal(dut, 'result_valid') and is_value_defined(dut.result_valid.value):
                if int(dut.result_valid.value) == 1:
                    break
            if has_signal(dut, 'done') and is_value_defined(dut.done.value):
                if int(dut.done.value) == 1:
                    break
        else:
            raise TestFailure("Timeout waiting for result")
        
        # Read result
        if not is_value_defined(dut.result.value):
            raise TestFailure("Result signal is undefined")
        
        result = int(dut.result.value)
        
        # Check impossible flag
        impossible = False
        if has_signal(dut, 'impossible') and is_value_defined(dut.impossible.value):
            impossible = int(dut.impossible.value) == 1
        
        # Verify
        if expected is None:
            if not impossible:
                raise TestFailure(f"Expected impossible, got {result}")
        else:
            if impossible:
                raise TestFailure(f"Expected {expected}, got impossible")
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
        
        cocotb.log.info(f"  PASS")
