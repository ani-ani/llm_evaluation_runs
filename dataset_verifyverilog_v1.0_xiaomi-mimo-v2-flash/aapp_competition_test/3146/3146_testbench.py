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
    return min((1 << bits) - 1, max(0, v))

def to_fixed_point(val, frac=16):
    return int(val * (1 << frac))

def from_fixed_point(val, frac=16):
    return val / (1 << frac)

async def reset_dut(dut):
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.presc_valid.value = 0
    dut.num_technicians.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def send_prescriptions(dut, prescs, num_tech):
    # Send num_tech first
    dut.num_technicians.value = num_tech
    await RisingEdge(dut.clk)
    
    for d, t, k in prescs:
        dut.presc_valid.value = 1
        dut.presc_time.value = clamp_to_width(d, 32)
        dut.presc_type.value = 1 if t == 'S' else 0
        dut.presc_duration.value = clamp_to_width(k, 9)
        await RisingEdge(dut.clk)
    
    dut.presc_valid.value = 0

async def wait_for_done(dut, max_cycles=3000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_pharmacy(dut):
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    await reset_dut(dut)
    
    test_cases = [
        {
            "name": "Sample 1: 3 Techs",
            "prescs": [
                (1, 'R', 4),
                (2, 'R', 2),
                (3, 'R', 2),
                (4, 'S', 2),
                (5, 'S', 1)
            ],
            "num_tech": 3,
            "exp_store": 1.5,
            "exp_remote": 2.666667
        },
        {
            "name": "Sample 2: 2 Techs",
            "prescs": [
                (1, 'R', 4),
                (2, 'R', 2),
                (3, 'R', 2),
                (4, 'S', 2),
                (5, 'S', 1)
            ],
            "num_tech": 2,
            "exp_store": 1.5,
            "exp_remote": 3.666667
        },
        {
            "name": "Sample 3: 1 Tech",
            "prescs": [
                (1, 'R', 4),
                (2, 'R', 2),
                (3, 'R', 2),
                (4, 'S', 2),
                (5, 'S', 1)
            ],
            "num_tech": 1,
            "exp_store": 3.0,
            "exp_remote": 7.0
        },
        {
            "name": "Edge: No In-Store",
            "prescs": [(1, 'R', 10), (2, 'R', 5)],
            "num_tech": 2,
            "exp_store": 0.0,
            "exp_remote": 7.5
        },
        {
            "name": "Edge: No Remote",
            "prescs": [(1, 'S', 10), (2, 'S', 5)],
            "num_tech": 2,
            "exp_store": 7.5,
            "exp_remote": 0.0
        }
    ]
    
    for tc in test_cases:
        cocotb.log.info(f"Running {tc['name']}")
        
        # Reset for new test case
        dut.rst_n.value = 0
        dut.start.value = 0
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
        
        # Send data
        await send_prescriptions(dut, tc['prescs'], tc['num_tech'])
        
        # Assert start
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        await wait_for_done(dut)
        
        # Check results
        if has_signal(dut, 'error') and is_value_defined(dut.error.value) and int(dut.error.value) == 1:
            if tc['num_tech'] == 0:
                cocotb.log.info("Correctly handled zero technicians")
                continue
            else:
                raise TestFailure(f"Unexpected error signal")
        
        if not is_value_defined(dut.avg_store.value) or not is_value_defined(dut.avg_remote.value):
            raise TestFailure("Result signals undefined")
        
        store_val = from_fixed_point(int(dut.avg_store.value))
        remote_val = from_fixed_point(int(dut.avg_remote.value))
        
        exp_store = tc['exp_store']
        exp_remote = tc['exp_remote']
        
        # Tolerance check (1e-6)
        err_store = abs(store_val - exp_store)
        err_remote = abs(remote_val - exp_remote)
        
        if err_store > 1e-6 and abs(err_store / exp_store) > 1e-6 if exp_store != 0 else err_store > 1e-6:
            raise TestFailure(f"Store avg mismatch: exp {exp_store}, got {store_val}")
        if err_remote > 1e-6 and abs(err_remote / exp_remote) > 1e-6 if exp_remote != 0 else err_remote > 1e-6:
            raise TestFailure(f"Remote avg mismatch: exp {exp_remote}, got {remote_val}")
        
        cocotb.log.info(f"PASS: Store={store_val:.6f}, Remote={remote_val:.6f}")
