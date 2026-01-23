import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer
import random

# Helper to convert probability to Q8.8 format
def prob_to_q8_8(p):
    return int(p * 256)

@cocotb.test()
async def test_rain_accumulator(dut):
    """Test the rain accumulator module with various scenarios"""
    
    # Test Cases: (d, t, wait, clouds, roofs, expected_rain_scaled)
    # Scaled expected = Expected_Rain * 256 (to match Q8.8 prob accumulation)
    test_cases = [
        # Case 1: Sample Input 2 Adapted
        # d=3, t=4. Clouds: [1,3, 0.25, 8], [2,4, 0.66667, 15]. Roof: [1,2]
        # Optimal walk: Wait 0 (Rain: C1(1s): 2, C2(2s): 10) = 12? 
        # Let's simulate wait=1 at start (under roof 0-1? No, roof is 1-2. Home is 0. Wait=1 means wait seconds 0 only.
        # At t=0: C1 active (0.25*8=2), C2 not active. Wait rain=2.
        # Walk t=1 to 3. Arrive t=4. 
        # t=1: C1(2), C2(15*0.666=10). Rain=12. 
        # t=2: C1(2), C2(10). Rain=12. 
        # t=3: C1 finished? C1 [1,3) -> active 1,2. C2 [2,4) -> active 2,3. 
        # Total: Wait(0) + Walk(1,2) = 2 + 12 + 12 = 26. (Sample says 10.00005 - this implies different logic)
        # Let's stick to the problem logic: Minimize rain. 
        # In Python example 2, output is 10.00005.
        # Let's try wait=0, walk instantly. t=0: C1(2). t=1: C1(2), C2(10). t=2: C1(2), C2(10). 
        # Sum = 2+12+12 = 26. 
        # Wait=1 (under roof? No, roof 1-2. Wait at 0 covers t=0). 
        # If we use a verifiable simplified case:
        
        # CASE A: Simple Walking
        # d=3, t=3. 1 Cloud [0, 5, 1.0, 10]. 0 Roofs. Wait=0.
        # Walk time 3s. Rain at t=0,1,2. Rain=30. Scaled=30*256=7680.
        (3, 3, 0, 1, 0, [[0, 5, 1.0, 10]], [], 7680),
        
        # CASE B: Waiting under Roof
        # d=3, t=5. 1 Cloud [0, 5, 1.0, 10]. 1 Roof [0, 4]. Wait=2.
        # Wait at t=0,1: Under roof -> 0 rain.
        # Walk t=2,3,4: Rain at 2,3,4 -> 30. Scaled=7680.
        (3, 5, 2, 1, 1, [[0, 5, 1.0, 10]], [[0, 4]], 7680),
        
        # CASE C: Waiting without Roof
        # d=3, t=5. 1 Cloud [0, 5, 1.0, 10]. 0 Roofs. Wait=2.
        # Wait t=0,1: Rain 20.
        # Walk t=2,3,4: Rain 30. Total 50. Scaled=12800.
        (3, 5, 2, 1, 0, [[0, 5, 1.0, 10]], [], 12800),

        # CASE D: Out of time
        # d=5, t=5. 1 Cloud [0, 5, 1.0, 10]. Wait=1. 
        # Walk needs 5s. Total 6s > t=5. Result 0.
        (5, 5, 1, 1, 0, [[0, 5, 1.0, 10]], [], 0),
        
        # CASE E: Probability
        # d=1, t=1. 1 Cloud [0, 10, 0.5, 20]. Wait=0. Walk 1s.
        # Rain = 20 * 0.5 = 10. Scaled = 10 * 256 = 2560.
        (1, 1, 0, 1, 0, [[0, 10, 0.5, 20]], [], 2560)
    ]

    passed = 0
    total = len(test_cases)

    for i, (d, t, wait, n_cloud, n_roof, clouds, roofs, expected_scaled) in enumerate(test_cases):
        # Setup inputs
        dut.d.value = d
        dut.t.value = t
        dut.wait_duration.value = wait
        dut.num_clouds.value = n_cloud
        dut.num_roofs.value = n_roof

        # Initialize arrays to 0
        for k in range(8):
            dut.cloud_start[k].value = 0
            dut.cloud_end[k].value = 0
            dut.cloud_prob[k].value = 0
            dut.cloud_amount[k].value = 0
            dut.roof_start[k].value = 0
            dut.roof_end[k].value = 0

        # Fill cloud data
        for idx, (cs, ce, cp, ca) in enumerate(clouds):
            dut.cloud_start[idx].value = cs
            dut.cloud_end[idx].value = ce
            dut.cloud_prob[idx].value = prob_to_q8_8(cp)
            dut.cloud_amount[idx].value = ca

        # Fill roof data
        for idx, (rs, re) in enumerate(roofs):
            dut.roof_start[idx].value = rs
            dut.roof_end[idx].value = re

        # Wait for combinational logic to settle
        await Timer(10, units='ns')

        result = int(dut.total_rain.value)
        
        # Check result
        if result == expected_scaled:
            passed += 1
            print(f"Test {i+1}: PASS (Rain={result/256.0:.2f} expected={expected_scaled/256.0:.2f})")
        else:
            print(f"Test {i+1}: FAIL (Got {result}, Expected {expected_scaled})")

    print(f"
Summary: {passed}/{total} tests passed")
    assert passed == total, f"Only {passed}/{total} tests passed"