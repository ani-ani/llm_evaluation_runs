import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Helper functions
def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def safe_int(v, default=0):
    try: return int(v)
    except ValueError: return default

def clamp_to_width(v, bits):
    if v < 0: return 0
    max_val = (1 << bits) - 1
    return v if v <= max_val else max_val

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

async def reset_dut(dut, cycles=2):
    if has_signal(dut, 'rst_n'):
        dut.rst_n.value = 0
        if has_signal(dut, 'start'): dut.start.value = 0
        for _ in range(cycles): await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=300):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def setup_inputs(dut, plants, jump_cost):
    # Set number of plants
    if has_signal(dut, 'num_plants'):
        dut.num_plants.value = len(plants)
    
    # Set jump cost
    if has_signal(dut, 'jump_cost'):
        dut.jump_cost.value = clamp_to_width(jump_cost, 10)
    
    # Set plant data (using individual element access)
    n = len(plants)
    for i in range(n):
        x, y, f = plants[i]
        # Access plant_x[i], plant_y[i], plant_f[i]
        try:
            getattr(dut, f'plant_x')[i].value = clamp_to_width(x, 16)
        except Exception:
            try: getattr(dut, f'plant_x_{i}').value = clamp_to_width(x, 16)
            except Exception: pass
        
        try:
            getattr(dut, f'plant_y')[i].value = clamp_to_width(y, 16)
        except Exception:
            try: getattr(dut, f'plant_y_{i}').value = clamp_to_width(y, 16)
            except Exception: pass
        
        try:
            getattr(dut, f'plant_f')[i].value = clamp_to_width(f, 10)
        except Exception:
            try: getattr(dut, f'plant_f_{i}').value = clamp_to_width(f, 10)
            except Exception: pass

@cocotb.test(timeout_time=100, timeout_unit="ms")
async def test_barica(dut):
    # Setup clock
    if has_signal(dut, 'clk'):
        clock = Clock(dut.clk, 10, units='ns')
        cocotb.start_soon(clock.start())
        await reset_dut(dut)
    else:
        raise TestFailure("Module requires 'clk' signal")
    
    # Test Cases
    test_cases = [
        {
            "plants": [(1, 1, 5), (2, 1, 5), (1, 2, 4), (2, 3, 5), (3, 2, 30), (3, 3, 5)],
            "jump_cost": 5,
            "expected_energy": 5,
            "expected_path_len": 4,
            "expected_path_indices": [0, 1, 3, 5]  # Indices 0-based: 1->2->4->6
        },
        {
            "plants": [(1, 1, 15), (2, 2, 30), (1, 2, 8), (2, 1, 7), (3, 2, 8), (2, 3, 7), (4, 2, 100), (3, 3, 15)],
            "jump_cost": 10,
            "expected_energy": 36,
            "expected_path_len": 5,
            "expected_path_indices": [0, 2, 1, 4, 7]  # Indices 0-based
        },
        {
            "plants": [(5, 5, 10), (6, 5, 2), (7, 5, 1), (5, 6, 2), (6, 6, 6), (7, 6, 2), (5, 7, 1), (6, 7, 2), (7, 7, 1)],
            "jump_cost": 5,
            "expected_energy": 2,
            "expected_path_len": 3,
            "expected_path_indices": [0, 2, 8]  # Indices 0-based: 1->3->9
        }
    ]
    
    passed = 0
    failed = 0
    
    for idx, tc in enumerate(test_cases):
        cocotb.log.info(f"Running Test Case {idx+1} with {len(tc['plants'])} plants")
        
        try:
            # Setup inputs
            await setup_inputs(dut, tc['plants'], tc['jump_cost'])
            
            # Trigger start
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Wait for done
            await wait_for_done(dut, max_cycles=500)
            
            # Read results
            if not is_value_defined(dut.result_energy.value):
                raise TestFailure("Result energy is undefined")
            
            result_energy = int(dut.result_energy.value)
            result_path_len = int(dut.path_count.value) if has_signal(dut, 'path_count') else 0
            
            # Clamp expected to width for comparison (16-bit)
            exp_energy = clamp_to_width(tc['expected_energy'], 16)
            
            if result_energy != exp_energy:
                raise TestFailure(f"Energy mismatch: Expected {exp_energy}, Got {result_energy}")
            
            if result_path_len != tc['expected_path_len']:
                 raise TestFailure(f"Path length mismatch: Expected {tc['expected_path_len']}, Got {result_path_len}")
            
            # Check path indices if available
            if has_signal(dut, 'path_idx') and result_path_len > 0:
                path = []
                for i in range(result_path_len):
                    try:
                        idx_val = int(getattr(dut, f'path_idx')[i].value)
                    except Exception:
                        try: idx_val = int(getattr(dut, f'path_idx_{i}').value)
                        except Exception: idx_val = 0
                    path.append(idx_val)
                
                if path != tc['expected_path_indices']:
                    raise TestFailure(f"Path mismatch: Expected {tc['expected_path_indices']}, Got {path}")
            
            cocotb.log.info(f"Test Case {idx+1} Passed. Energy: {result_energy}")
            passed += 1
            
            # Short pause between tests
            await Timer(100, units='ns')
            
        except TestFailure as e:
            cocotb.log.error(f"Test Case {idx+1} FAILED: {e}")
            failed += 1
    
    if failed > 0:
        raise TestFailure(f"{failed} out of {len(test_cases)} test cases failed")
    else:
        cocotb.log.info(f"All {passed} test cases passed successfully")