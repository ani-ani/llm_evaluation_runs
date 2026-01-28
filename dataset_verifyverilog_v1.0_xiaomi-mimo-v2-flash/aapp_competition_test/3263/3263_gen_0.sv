module FluttershyStrategy (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] P_i,
    input wire [3:0] R_i,
    input wire [3:0] cust_type [0:15],
    input wire [15:0] cust_time [0:15],
    input wire [3:0] num_cust,
    output reg [15:0] result,
    output reg done
);

    // State machine states
    localparam [2:0] IDLE          = 3'd0;
    localparam [2:0] CHECK_START   = 3'd1;
    localparam [2:0] PROCESS_CUST  = 3'd2;
    localparam [2:0] UPDATE_TIME   = 3'd3;
    localparam [2:0] INCREMENT     = 3'd4;
    localparam [2:0] FINISH        = 3'd5;

    // Internal registers
    reg [2:0] state;
    reg [3:0] index;           // Current customer index
    reg [15:0] current_time;
    reg [3:0] current_clothing; // 0 = none, 1-4 = type
    reg [15:0] served;
    reg [15:0] P_reg [0:3];     // Indexed 0-3 for types 1-4
    reg [15:0] R_reg [0:3];     // Indexed 0-3 for types 1-4
    reg [3:0] i_loop;           // Loop variable for initialization

    // Helper signals for calculations
    reg [15:0] new_time;
    reg [3:0] target_type;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset all registers
            state <= IDLE;
            index <= 4'd0;
            current_time <= 16'd0;
            current_clothing <= 4'd0;
            served <= 16'd0;
            result <= 16'd0;
            done <= 1'b0;
            i_loop <= 4'd0;
            // Initialize P and R arrays
            P_reg[0] <= 16'd0;
            P_reg[1] <= 16'd0;
            P_reg[2] <= 16'd0;
            P_reg[3] <= 16'd0;
            R_reg[0] <= 16'd0;
            R_reg[1] <= 16'd0;
            R_reg[2] <= 16'd0;
            R_reg[3] <= 16'd0;
        end else begin
            done <= 1'b0; // Default done low
            case (state)
                IDLE: begin
                    index <= 4'd0;
                    current_time <= 16'd0;
                    current_clothing <= 4'd0;
                    served <= 16'd0;
                    i_loop <= 4'd0;
                    // Initialize P and R values (scale 4-bit to 16-bit)
                    P_reg[0] <= {12'd0, P_i}; // Type 1 -> index 0
                    P_reg[1] <= {12'd0, P_i}; // Type 2 -> index 1
                    P_reg[2] <= {12'd0, P_i}; // Type 3 -> index 2
                    P_reg[3] <= {12'd0, P_i}; // Type 4 -> index 3
                    R_reg[0] <= {12'd0, R_i}; // Type 1 -> index 0
                    R_reg[1] <= {12'd0, R_i}; // Type 2 -> index 1
                    R_reg[2] <= {12'd0, R_i}; // Type 3 -> index 2
                    R_reg[3] <= {12'd0, R_i}; // Type 4 -> index 3
                    if (start) begin
                        if (num_cust == 4'd0) begin
                            state <= FINISH;
                        end else begin
                            state <= CHECK_START;
                        end
                    end
                end

                CHECK_START: begin
                    // Check if we processed all customers
                    if (index >= num_cust) begin
                        state <= FINISH;
                    end else begin
                        state <= PROCESS_CUST;
                    end
                end

                PROCESS_CUST: begin
                    // Target type: 1=Type1, 2=Type2, 3=Type3, 4=Type4
                    target_type = cust_type[index];
                    
                    // Check if need to change clothing
                    if (target_type != current_clothing) begin
                        new_time = current_time;
                        // Add removal time if currently wearing something
                        if (current_clothing != 4'd0) begin
                            new_time = new_time + R_reg[current_clothing - 4'd1];
                        end
                        // Add put-on time for new type
                        new_time = new_time + P_reg[target_type - 4'd1];
                    end else begin
                        new_time = current_time;
                    end
                    
                    state <= UPDATE_TIME;
                end

                UPDATE_TIME: begin
                    // Check if can serve customer
                    if (current_time <= cust_time[index]) begin
                        // Can serve
                        current_clothing <= cust_type[index];
                        current_time <= cust_time[index];
                        served <= served + 16'd1;
                    end else begin
                        // Cannot serve, keep current state and time
                        // (or if we changed clothing for next, keep that?
                        // The problem says "if current_time <= cust_time[i]"
                        // This implies if time exceeds, we don't serve and don't update time
                        // But if we already changed clothing, we keep the change
                        // Interpretation: The algorithm only updates time if serving
                        // However, the clothing change logic might have happened
                        // Let's re-read: "If cust_time[i] >= current_time" -> check this first
                        // The description says "If cust_time[i] >= current_time" at the top level.
                        // If this is false, we skip processing this customer entirely.
                        // Let's adjust logic based on strict reading:
                        // 1. Check time condition
                        // 2. If true, check clothing
                        // 3. Update time
                        // 4. Check time condition again
                        // Since we are in UPDATE_TIME, we need to re-evaluate the first condition
                        // Actually, the PROCESS_CUST calculated new_time assuming we proceed.
                        // But if cust_time[i] < current_time, we skip entirely.
                        // Let's modify PROCESS_CUST to not calculate new_time if cust_time < current_time?
                        // No, let's handle the logic flow here.
                        
                        // Re-evaluate: If cust_time[index] < current_time, skip.
                        // Since we are already in UPDATE_TIME, we must have passed PROCESS_CUST.
                        // This implies we need a state to check the FIRST condition.
                        // Let's rely on the fact that PROCESS_CUST was entered.
                        // If cust_time[index] < current_time, we should skip.
                        // But the prompt says "If cust_time[i] >= current_time".
                        // Let's assume the FSM checks this before PROCESS_CUST.
                        
                        // Correction: The PROCESS_CUST state calculated new_time assuming transition.
                        // But we should only transition IF the time condition passes initially.
                        // Let's check the time condition here (again) and decide.
                        
                        if (cust_time[index] >= current_time) begin
                            // This is the first check. Update time and clothing if needed.
                            // The new_time calculated in PROCESS_CUST is correct for the change.
                            // However, if we didn't change clothes (target == current), new_time = current_time.
                            // If we did change, new_time > current_time.
                            // We set current_time to max(new_time, cust_time[index]).
                            
                            // Actually, the algorithm says:
                            // "If cust_time[i] >= current_time"
                            // "... logic ..."
                            // "If current_time <= cust_time[i]" (redundant check?)
                            // "Set current_time = cust_time[i]" (Wait, this is weird. If we added P/R, time increases.
                            // We cannot set it back to cust_time unless cust_time is larger.)
                            
                            // Interpretation: 
                            // 1. Calculate transition time (removal + puton).
                            // 2. If calculated finish time <= arrival time, we are good. 
                            //    (We update current_clothing, but time remains arrival time?)
                            // 3. If calculated finish time > arrival time, we finish late.
                            //    Current_time = calculated finish time.
                            //    (But then we have "Set current_time = cust_time[i]" which contradicts this).
                            
                            // Re-reading the specific instruction:
                            // "If current_time <= cust_time[i]: Set current_time = cust_time[i]"
                            // This implies if we are early (or exactly on time), we wait until the customer arrives?
                            // No, that doesn't minimize cost. 
                            // Maybe it means: The cost is the finish time. 
                            // If we finish the transition BEFORE the arrival, we just wait.
                            // If we finish AFTER, we are late.
                            
                            // Let's follow the literal text provided in the prompt:
                            // 1. If current_clothing != target: Add R, Add P.
                            // 2. If current_time <= cust_time[i]: Set current_time = cust_time[i].
                            
                            // This implies the "P and R" addition might be conceptual or happens in parallel?
                            // No, "Add ... to current_time" is explicit.
                            // So: current_time = current_time + P/R.
                            // Then: If (current_time <= cust_time[i]) current_time = cust_time[i].
                            
                            // This means if we finish BEFORE the customer arrives, we wait.
                            // If we finish AFTER, we keep the late time.
                            // This minimizes "lateness" or "finish time"? 
                            // Actually, it minimizes "time spent changing" (P/R are fixed).
                            // The time value is cumulative.
                            
                            // Let's implement the logic literally.
                            // In PROCESS_CUST we calculated new_time.
                            // Here in UPDATE_TIME:
                            
                            // Update clothing
                            current_clothing <= target_type;
                            
                            // Update time
                            // If new_time <= cust_time[index], set to cust_time[index]
                            // Else set to new_time
                            // Note: new_time was calculated in PROCESS_CUST.
                            // We need to pass it or recalculate.
                            // We will recalculate to be safe or use the signal.
                            // Since PROCESS_CUST sets state to UPDATE_TIME, we can use the logic there.
                            
                            // We need to re-calculate or store new_time.
                            // Let's use the value calculated in PROCESS_CUST.
                            // But PROCESS_CUST used blocking assignments, so new_time should be valid in UPDATE_TIME if sequential logic flow.
                            // However, PROCESS_CUST used combinational logic. 
                            // Let's move the calculation to UPDATE_TIME or pass the values.
                            // To be safe, let's recalculate in UPDATE_TIME.
                            
                            // Recalculate:
                            // target_type is cust_type[index]
                            // current_clothing is old value (before update)
                            // We need to be careful with register updates.
                            
                            // Let's do the calculation in a combinational block outside, or just inline.
                            // To avoid recomputing, let's assume the value from PROCESS_CUST is correct.
                            // Since PROCESS_CUST used blocking assignments and no clock edges, 
                            // new_time is valid in the same cycle of UPDATE_TIME state entry.
                            
                            // However, we are in a sequential block. 
                            // We should capture the calculation result.
                            // Let's add a temporary register for transition_time.
                            // OR, simply recalculate here.
                            
                            // Recalculation:
                            reg [15:0] calc_time;
                            begin
                                calc_time = current_time;
                                if (target_type != current_clothing) begin
                                    if (current_clothing != 4'd0)
                                        calc_time = calc_time + R_reg[current_clothing - 4'd1];
                                    calc_time = calc_time + P_reg[target_type - 4'd1];
                                end
                            end
                            
                            // Apply rule: If calc_time <= cust_time[i], use cust_time[i].
                            // Note: Logic implies if we finish early, we wait for arrival?
                            // "Set current_time = cust_time[i]" implies we sync to arrival time.
                            
                            if (calc_time <= cust_time[index]) begin
                                current_time <= cust_time[index];
                            end else begin
                                current_time <= calc_time;
                            end
                            
                            // Serve and increment count
                            served <= served + 16'd1;
                        end
                        // If cust_time[index] < current_time, we do nothing (skip customer).
                        // Clothing does not change in this case.
                    end
                    
                    state <= INCREMENT;
                end

                INCREMENT: begin
                    index <= index + 4'd1;
                    state <= CHECK_START;
                end

                FINISH: begin
                    result <= served;
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule