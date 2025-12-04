import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
import struct

@cocotb.test()
async def test_scheduler(dut):
    # Fixed-point conversion helpers
    def fp32_to_float(val):
        return val.integer / 65536.0
    def float_to_fp32(val):
        return struct.unpack("<I", struct.pack("<f", val))[0] 
    
    clock = Clock(dut.clk, 10, units="ns") # 100 MHz clock
    cocotb.start_soon(clock.start())
    
    # Test cases (original scaled to 5 prescriptions, max tech=3)
    test_cases = [
        { # Test 1: 5 presc, 3 tech
            "num_presc": 5,
            "num_tech": 3,
            "prescriptions": [
                (1, 'R', 4), (2, 'R', 2), (3, 'R', 2), (4, 'S', 2), (5, 'S', 1)
            ],
            "expected_s": 1.5,
            "expected_r": 8/3.0 # ~2.666667
        },
        { # Test 2: 5 presc, 2 tech
            "num_presc": 5,
            "num_tech": 2,
            "prescriptions": [
                (1, 'R', 4), (2, 'R', 2), (3, 'R', 2), (4, 'S', 2), (5, 'S', 1)
            ],
            "expected_s": 1.5,
            "expected_r": 11/3.0 # ~3.666667
        },
        { # Test 3: 5 presc, 1 tech
            "num_presc": 5,
            "num_tech": 1,
            "prescriptions": [
                (1, 'R', 4), (2, 'R', 2), (3, 'R', 2), (4, 'S', 2), (5, 'S', 1)
            ],
            "expected_s": 3.0,
            "expected_r": 7.0
        },
        { # Edge case: No S prescriptions
            "num_presc": 2,
            "num_tech": 1,
            "prescriptions": [(1, 'R', 1), (2, 'R', 1)],
            "expected_s": 0.0,
            "expected_r": 1.0
        }
    ]
    
    passed = 0
    for idx, test in enumerate(test_cases):
        # Reset
        dut.rst_n.value = 0
        dut.start.value = 0
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
        
        # Load inputs
        dut.num_prescriptions.value = test["num_presc"]
        dut.num_techs.value = test["num_tech"]
        for i in range(8):
            if i < len(test["prescriptions"]):
                drop, typ, fill = test["prescriptions"][i]
                dut.presc_drop_time[i].value = drop
                dut.presc_type[i].value = 0 if typ == 'R' else 1
                dut.presc_fill_time[i].value = fill
            else: # Default fill unused
                dut.presc_drop_time[i].value = 0
                dut.presc_type[i].value = 0
                dut.presc_fill_time[i].value = 0
        
        # Start processing
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for completion (max 200 cycles)
        timeout = 200
        while not dut.done.value and timeout > 0:
            await RisingEdge(dut.clk)
            timeout -= 1
        
        if timeout == 0:
            dut._log.error(f"Test {idx+1} timed out!")
            continue
        
        # Check results
        s_val = fp32_to_float(dut.avg_s.value)
        r_val = fp32_to_float(dut.avg_r.value)
        eps = 1e-4 # Allowable error
        
        s_ok = abs(s_val - test["expected_s"]) < eps or 
               (test["expected_s"] == 0 and dut.avg_s.value == 0)
        r_ok = abs(r_val - test["expected_r"]) < eps or 
               (test["expected_r"] == 0 and dut.avg_r.value == 0)
        
        if s_ok and r_ok:
            passed += 1
            dut._log.info(f"Test {idx+1} passed")
        else:
            dut._log.error(f"Test {idx+1} failed: S={s_val:.6f} vs {test['expected_s']:.6f}, R={r_val:.6f} vs {test['expected_r']:.6f}")
        await RisingEdge(dut.clk)
    
    dut._log.info(f"SUMMARY: {passed}/{len(test_cases)} tests passed")