module GearRatioSolver (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] ratio_n [0:11],
    input wire [7:0] ratio_d [0:11],
    output reg [7:0] front0,
    output reg [7:0] front1,
    output reg [7:0] rear0,
    output reg [7:0] rear1,
    output reg [7:0] rear2,
    output reg [7:0] rear3,
    output reg [7:0] rear4,
    output reg [7:0] rear5,
    output reg valid,
    output reg done
);

    // State definitions
    localparam [3:0] IDLE         = 4'd0;
    localparam [3:0] INIT         = 4'd1;
    localparam [3:0] SETUP_FRONT  = 4'd2;
    localparam [3:0] CHECK_RATIO  = 4'd3;
    localparam [3:0] CALC_REAR    = 4'd4;
    localparam [3:0] VERIFY       = 4'd5;
    localparam [3:0] CHECK_SET    = 4'd6;
    localparam [3:0] VALIDATE     = 4'd7;
    localparam [3:0] STORE_RESULT = 4'd8;
    localparam [3:0] DONE_STATE   = 4'd9;

    reg [3:0] state;
    reg [7:0] f_idx;        // Front sprocket candidate (1-100)
    reg [3:0] ratio_idx;    // Index of ratio being processed (0-11)
    reg [7:0] rear_calc;    // Calculated rear sprocket
    reg [15:0] product;     // Product (front * d_i)
    reg [7:0] rear_set [0:5];  // Buffer for rear sprockets for current front
    reg [2:0] rear_cnt;     // Count of unique rears for current front
    reg [7:0] f0_candidate; // Candidate front 0
    reg [7:0] f1_candidate; // Candidate front 1
    reg found_f0;           // Flag if f0 found
    reg found_f1;           // Flag if f1 found
    reg rear_valid;         // Flag for current rear calculation
    reg [15:0] cycle_count; // Safety counter
    localparam [15:0] MAX_CYCLES = 16'd5000;

    integer i;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            front0 <= 8'd0;
            front1 <= 8'd0;
            rear0 <= 8'd0;
            rear1 <= 8'd0;
            rear2 <= 8'd0;
            rear3 <= 8'd0;
            rear4 <= 8'd0;
            rear5 <= 8'd0;
            valid <= 1'b0;
            done <= 1'b0;
            f_idx <= 8'd0;
            ratio_idx <= 4'd0;
            rear_calc <= 8'd0;
            product <= 16'd0;
            rear_cnt <= 3'd0;
            f0_candidate <= 8'd0;
            f1_candidate <= 8'd0;
            found_f0 <= 1'b0;
            found_f1 <= 1'b0;
            rear_valid <= 1'b0;
            cycle_count <= 16'd0;
            for (i = 0; i < 6; i = i + 1) begin
                rear_set[i] <= 8'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    valid <= 1'b0;
                    if (start) begin
                        state <= INIT;
                    end
                end

                INIT: begin
                    // Initialize search
                    f_idx <= 8'd1; // Start searching from front 1
                    found_f0 <= 1'b0;
                    found_f1 <= 1'b0;
                    cycle_count <= 16'd0;
                    state <= SETUP_FRONT;
                end

                SETUP_FRONT: begin
                    // Setup to check ratios for this front
                    ratio_idx <= 4'd0;
                    rear_cnt <= 3'd0;
                    rear_valid <= 1'b1; // Assume valid until proven otherwise
                    // Clear rear set for this iteration
                    for (i = 0; i < 6; i = i + 1) begin
                        rear_set[i] <= 8'd0;
                    end
                    state <= CHECK_RATIO;
                end

                CHECK_RATIO: begin
                    // Check if we are done with all ratios for this front
                    if (ratio_idx >= 12) begin
                        // All ratios processed for this front
                        if (rear_valid) begin
                            // Valid rear set found, check if it matches criteria
                            state <= VALIDATE;
                        end else begin
                            // This front failed, try next
                            f_idx <= f_idx + 8'd1;
                            cycle_count <= cycle_count + 16'd1;
                            if (f_idx >= 8'd100 || cycle_count >= MAX_CYCLES) begin
                                state <= DONE_STATE; // Exhausted search space
                            end else begin
                                state <= SETUP_FRONT;
                            end
                        end
                    end else begin
                        // Process this ratio
                        state <= CALC_REAR;
                    end
                end

                CALC_REAR: begin
                    // Calculate required rear: r = (f * d) / n
                    product <= f_idx * ratio_d[ratio_idx];
                    // Check division is exact: (f * d) % n == 0
                    // We need to wait one cycle for product or use combinational logic
                    // For simplicity in this sequential block, we compute next cycle
                    // Actually, let's compute in combinational logic or next state
                    state <= VERIFY;
                end

                VERIFY: begin
                    // Verify the calculated rear
                    if (product % ratio_n[ratio_idx] == 16'd0) begin
                        rear_calc <= product / ratio_n[ratio_idx];
                        // Check if rear is within bounds (1-100)
                        if (product / ratio_n[ratio_idx] > 8'd0 && product / ratio_n[ratio_idx] <= 8'd100) begin
                            state <= CHECK_SET;
                        end else begin
                            rear_valid <= 1'b0; // Out of bounds
                            state <= CHECK_RATIO;
                            ratio_idx <= ratio_idx + 4'd1;
                        end
                    end else begin
                        // Not an integer rear sprocket
                        rear_valid <= 1'b0;
                        state <= CHECK_RATIO;
                        ratio_idx <= ratio_idx + 4'd1;
                    end
                end

                CHECK_SET: begin
                    // Check if rear_calc is already in rear_set
                    // If rear_cnt < 6, we add if unique
                    if (rear_cnt < 3'd6) begin
                        // Check for uniqueness in current set
                        rear_valid <= 1'b1; // Assume unique
                        // We check against indices 0 to rear_cnt-1
                        if (rear_cnt > 3'd0 && rear_set[0] == rear_calc) rear_valid <= 1'b0;
                        if (rear_cnt > 3'd1 && rear_set[1] == rear_calc) rear_valid <= 1'b0;
                        if (rear_cnt > 3'd2 && rear_set[2] == rear_calc) rear_valid <= 1'b0;
                        if (rear_cnt > 3'd3 && rear_set[3] == rear_calc) rear_valid <= 1'b0;
                        if (rear_cnt > 3'd4 && rear_set[4] == rear_calc) rear_valid <= 1'b0;
                        
                        // If unique and space available, add it
                        if (rear_valid) begin
                            rear_set[rear_cnt] <= rear_calc;
                            rear_cnt <= rear_cnt + 3'd1;
                        end
                    end else begin
                        // We already have 6 rears, check if this one matches one of them
                        rear_valid <= 1'b0;
                        if (rear_set[0] == rear_calc || rear_set[1] == rear_calc || 
                            rear_set[2] == rear_calc || rear_set[3] == rear_calc ||
                            rear_set[4] == rear_calc || rear_set[5] == rear_calc) begin
                            rear_valid <= 1'b1;
                        end
                    end
                    
                    ratio_idx <= ratio_idx + 4'd1;
                    state <= CHECK_RATIO;
                end

                VALIDATE: begin
                    // Check if rear_cnt is exactly 6 (we have 6 distinct rears)
                    // And check if we have assigned fronts
                    if (rear_cnt == 3'd6) begin
                        if (!found_f0) begin
                            f0_candidate <= f_idx;
                            found_f0 <= 1'b1;
                            state <= CHECK_RATIO; // Continue search for second front
                        end else if (!found_f1) begin
                            f1_candidate <= f_idx;
                            found_f1 <= 1'b1;
                            // We found two fronts with 6 rears each.
                            // Ideally they share the same rears, but problem statement 
                            // says "find two front sprocket sizes and six rear sprocket sizes".
                            // It implies one set of rears for both fronts.
                            // However, if we found two fronts with *valid* rear sets (6 rears each),
                            // we might take the first front's rears as the solution set.
                            // To be safe, let's store the rears from f0_candidate.
                            // Wait, we need to verify they produce the exact same rears?
                            // Problem says "find two front and six rear sizes such that 12 ratios equal f/r".
                            // This implies a common set of 6 rears used by both fronts.
                            // The logic above checks one front at a time. 
                            // If f0 has 6 rears, and f1 has 6 rears, they might be different.
                            // We need to check if the set of rears is IDENTICAL for both fronts.
                            // But we only store one rear_set at a time.
                            // Modification: If found_f0 is true, verify current f_idx produces EXACTLY the same rears.
                            if (found_f0) begin
                                // Verify current rear_set matches f0's rear_set
                                // Since we overwrote rear_set, we need to compare against stored ones (rear0..rear5)
                                // But we haven't stored them yet. 
                                // Let's assume: if we found f0, we immediately fill outputs and verify subsequent fronts match those outputs.
                            end
                            // For simplicity in this HW block: 
                            // We will accept the first f0 found with 6 rears.
                            // Then we look for a second f1 such that it produces the EXACT SAME 6 rears.
                            // To do this, we need to remember the rears from f0.
                            // Let's store rears in outputs when f0 is found.
                            rear0 <= rear_set[0];
                            rear1 <= rear_set[1];
                            rear2 <= rear_set[2];
                            rear3 <= rear_set[3];
                            rear4 <= rear_set[4];
                            rear5 <= rear_set[5];
                            front0 <= f_idx;
                            state <= CHECK_RATIO; // Continue search for f1 matching these rears
                        end else begin
                            // found_f0 and found_f1 are true.
                            // We already found f0 and rears. Now we check if current f_idx is a valid f1.
                            // We need to verify current rear_set matches stored rear0..rear5.
                            // (We are already in VALIDATE because rear_cnt==6).
                            // Let's check the set equality.
                            // Since we are in state VALIDATE, rear_set contains the rears for current f_idx.
                            // We compare rear_set with stored outputs.
                            if (rear_set[0]==rear0 && rear_set[1]==rear1 && rear_set[2]==rear2 &&
                                rear_set[3]==rear3 && rear_set[4]==rear4 && rear_set[5]==rear5) begin
                                front1 <= f_idx;
                                state <= STORE_RESULT;
                            end else begin
                                // This f1 has 6 rears but they don't match.
                                // Keep looking.
                                f_idx <= f_idx + 8'd1;
                                state <= SETUP_FRONT;
                            end
                        end
                    end else begin
                        // Rear count < 6, invalid for this front
                        f_idx <= f_idx + 8'd1;
                        state <= SETUP_FRONT;
                    end
                end

                STORE_RESULT: begin
                    valid <= 1'b1;
                    state <= DONE_STATE;
                end

                DONE_STATE: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule