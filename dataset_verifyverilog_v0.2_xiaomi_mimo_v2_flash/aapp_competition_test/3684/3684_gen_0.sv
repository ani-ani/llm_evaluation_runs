module p2p_streaming(
    input clk,
    input rst_n,
    input start,
    input [7:0] p_i [0:3],
    input [7:0] b_i [0:3],
    input [7:0] u_i [0:3],
    input [4:0] C,
    output reg [7:0] result,
    output reg done
);

    // State encoding
    localparam IDLE = 4'b0000;
    localparam INIT = 4'b0001;
    localparam CHECK_BUFFER = 4'b0010;
    localparam UPLOAD_CALC = 4'b0011;
    localparam VALIDATE = 4'b0100;
    localparam UPDATE_RESULT = 4'b0101;
    localparam INCREMENT = 4'b0110;
    localparam DONE = 4'b0111;

    reg [3:0] state;
    reg [3:0] next_state;

    // Loop variables
    // B ranges from -128 to 127 (8-bit signed)
    reg signed [7:0] B;
    reg [1:0] user_idx; // 0 to 3
    
    // Accumulators
    reg signed [15:0] total_upload_req; // Sum of required uploads (can be large)
    reg signed [15:0] total_bandwidth;  // Sum of all bandwidths
    reg signed [15:0] current_req;      // Current user's required upload
    
    // Result tracking
    reg signed [7:0] max_B;

    // Temporary calculations
    reg signed [15:0] diff; // B + C + p_i - b_i
    reg signed [15:0] upload_i; // max(0, diff)

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 8'sd0;
            done <= 1'b0;
            B <= -8'sd128;
            user_idx <= 2'd0;
            total_upload_req <= 16'sd0;
            total_bandwidth <= 16'sd0;
            current_req <= 16'sd0;
            max_B <= -8'sd128;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        // Initialize total bandwidth once on start
                        total_bandwidth <= u_i[0] + u_i[1] + u_i[2] + u_i[3];
                    end
                end
                
                INIT: begin
                    B <= -8'sd128;
                    max_B <= -8'sd128;
                    total_upload_req <= 16'sd0;
                    user_idx <= 2'd0;
                end
                
                CHECK_BUFFER: begin
                    // Reset user index and accumulators for new B check
                    user_idx <= 2'd0;
                    total_upload_req <= 16'sd0;
                end
                
                UPLOAD_CALC: begin
                    // Calculate requirement for current user
                    // diff = B + C + p_i - b_i
                    // Q8.8: p_i and b_i are scaled 0-255. C is 0-31 (scaled by 256 implicitly? No, C is a scalar)
                    // Requirement: B + C + p_i - b_i. B is Q8.8. C is integer 0-31.
                    // To match B, C needs to be scaled to Q8.8 (C << 8)
                    // p_i and b_i are 0-255, which is 0.0 to 1.0 in Q8.8 range (0 to 255). 
                    // If p_i and b_i are raw 0-255, they represent 0.0 to 1.0 * 256 = 0 to 256.
                    // Let's assume inputs are raw integers, and B is Q8.8.
                    // To compute in Q8.8, we need to scale C, p_i, b_i to Q8.8 format.
                    // C: 0-31. Multiply by 256 (<<8).
                    // p_i/b_i: 0-255. They are already scaled by 1 relative to 255? 
                    // Let's treat p_i, b_i as Q8.8 values by appending 0 fraction.
                    // diff = B + (C<<8) + (p_i<<8) - (b_i<<8).
                    
                    // Optimization: B is 8-bit signed, C is 5-bit, p_i/b_i are 8-bit unsigned.
                    // We compute B + C + p_i - b_i as integers to match the logic.
                    // If the algorithm implies B is Q8.8, then inputs likely need scaling.
                    // However, checking sum of upload bandwidths: u_i are 0-255. 
                    // If u_i is bandwidth in bytes/sec, and requirement is bytes, they might match directly.
                    // Let's assume the arithmetic is strictly integer on the input values as given, 
                    // but B is tracked as Q8.8.
                    // Let's stick to: Requirement = B + C + p_i - b_i. 
                    // If B is Q8.8, then C, p_i, b_i must be Q8.8.
                    // C << 8. p_i << 8. b_i << 8.
                    
                    diff <= B + (({3'd0, C}) << 8) + ({p_i[user_idx], 8'd0}) - ({b_i[user_idx], 8'd0});
                    
                    // Wait one cycle for diff if needed, or compute in next state. 
                    // To save states, we calculate upload_i directly here but based on previous diff? 
                    // Better to use a combinational block for calculations or separate state.
                    // Let's assume UPLOAD_CALC updates current_req based on diff calculated in previous cycle.
                    // Wait, we just calculated diff. We need max(0, diff).
                end
                
                VALIDATE: begin
                    // Accumulate
                    total_upload_req <= total_upload_req + current_req;
                end
                
                UPDATE_RESULT: begin
                    // Check condition: total_upload_req <= total_bandwidth
                    // Since B is Q8.8, we should compare total_upload_req with total_bandwidth scaled to Q8.8?
                    // Wait, u_i are 0-255. If u_i is bandwidth, it should be scaled same as upload requirement.
                    // If C, p, b are scaled by 256, u_i must be too.
                    // Let's assume u_i is also Q8.8 (<< 8). 
                    // Total bandwidth check: total_upload_req <= (total_bandwidth << 8).
                    // Wait, the prompt says inputs are raw integers 0-255. 
                    // If B is Q8.8, the arithmetic B + C + p - b implies C, p, b are integers added to B.
                    // This implies B is treated as integer part for arithmetic, but output is Q8.8.
                    // Or perhaps B is simply the integer value being tested, and result is B << 8.
                    // Let's assume we test integer B values -128..127. 
                    // Requirement = max(0, B + C + p_i - b_i).
                    // Bandwidth sum is sum(u_i). u_i is 0-255.
                    // This implies B, C, p, b are all in same units as u_i.
                    // Then result is B (integer), but output should be Q8.8.
                    // So result = B << 8.
                    
                    // Let's use integer arithmetic for the loop:
                    // diff = B + C + p_i - b_i (all integer interpretation).
                    // If sum(req) <= sum(u_i), B is valid.
                    // Result is max_B << 8.
                    
                    // Correcting the logic based on integer interpretation of inputs:
                    // diff <= B + C + p_i[user_idx] - b_i[user_idx];
                    // But wait, B is signed. p_i/b_i unsigned. C unsigned.
                    // B + C + p_i - b_i can be negative.
                    
                    // Let's go back to Q8.8 for B. B is signed 8-bit, range -128 to 127.
                    // Let's stick to the requirement: "B represents actual value divided by 256".
                    // Inputs p_i, b_i, u_i are 0-255. 
                    // If p_i is 0-255, it is 0.0 to 1.0 in 8 fractional bits.
                    // So p_i << 8 is correct.
                    // C is 0-31. << 8 is correct.
                    // B is already Q8.8.
                    // diff = B + (C << 8) + (p_i << 8) - (b_i << 8).
                    // Upload requirement = max(0, diff).
                    // Total bandwidth = sum(u_i). u_i is 0-255. To match Q8.8, sum(u_i) << 8.
                    
                    // Logic check:
                    // B (Q8.8) range: -128 to 127.996
                    // C (scaled) range: 0 to 31<<8 = 7936.
                    // p, b (scaled) range: 0 to 255<<8 = 65280.
                    // diff range: ~ -65k to ~73k. Fits in signed 16-bit (32k to 32k)?? No, 73k > 32k.
                    // Need 17 bits or use 32-bit math or assume C/p/b are NOT scaled.
                    
                    // Re-read: "Q8.8 fixed-point format throughout".
                    // BUT: Input values represent raw integers.
                    // Usually "raw integers" 0-255 implies 8-bit values.
                    // If Q8.8, raw integer 10 represents 10/256 = 0.039.
                    // However, C is 0-31. If C is integer 1, it represents 1 second advance.
                    // If B is Q8.8, C must be Q8.8. So C << 8.
                    // But B is limited to -128..127. This implies B integer part is -128..127.
                    // If B is 127, it is 127.996. 
                    // C is 0-31. 
                    // Sum p_i - b_i. p_i and b_i 0-255. 
                    // If p_i is raw 255, it is 255/256 = 0.996. 
                    // So p_i << 8 is wrong, it should be p_i * 1 (if we assume 1.0 = 256).
                    // Wait. "Output B should also be in Q8.8 format."
                    // If the algorithm tests B from -128 to +127, these are INTEGER steps.
                    // Does it mean B -128 means -128.000?
                    // If B -128 means -0.5 (if mapped -128..127 to -0.5..0.5)? 
                    // No, "-128 to +127 in steps of 1" implies integer values of the 8-bit signed integer.
                    // Let's assume the test B is a signed 8-bit integer.
                    // The equation is: B + C + p_i - b_i <= u_i (total).
                    // If B is Q8.8, B is big. p_i is 0-255. 
                    // If we treat p_i as Q8.8 (p_i * 1), then p_i is 0-255. 
                    // But Q8.8 max is 255.996.
                    // C max is 31. 
                    // So likely, p_i, b_i, u_i are NOT scaled to 256, but represent values 0-255.
                    // And B is the integer value we want to maximize.
                    // Then result is B * 256 (Q8.8).
                    // So arithmetic is:
                    // req = B + C + p_i - b_i. (All integers or B signed).
                    // If req < 0, req = 0.
                    // Sum req <= Sum u_i.
                    // Result = max_B << 8.
                    // Let's go with this interpretation: Integer arithmetic for logic, shift result for output.
                    
                    if (total_upload_req <= total_bandwidth) begin
                        max_B <= B;
                    end
                end
                
                INCREMENT: begin
                    B <= B + 8'sd1;
                    total_upload_req <= 16'sd0;
                    user_idx <= 2'd0;
                end
                
                DONE: begin
                    result <= {max_B, 8'd0}; // Convert integer B to Q8.8
                    done <= 1'b1;
                end
            endcase
        end
    end

    // Combinational Logic for calculations to reduce state count/delay
    always @(*) begin
        // Default next state
        next_state = state;
        
        case (state)
            IDLE: begin
                if (start) next_state = INIT;
            end
            
            INIT: begin
                next_state = CHECK_BUFFER;
            end
            
            CHECK_BUFFER: begin
                // Check if B has reached limit 127
                if (B > 8'sd127) begin
                    next_state = DONE;
                end else begin
                    next_state = UPLOAD_CALC;
                end
            end
            
            UPLOAD_CALC: begin
                // Calculate diff: B + C + p_i - b_i
                // Inputs are reg, so we need to read them here if combinational.
                // However, we are in sequential block.
                // Let's use combinational logic for calculation to feed into state logic.
                // But since we are in state machine, we calculate values for current user.
                
                // Logic moved to combinational block below for clarity or keep here?
                // In always block, we can calculate.
                // diff = B + C + p_i[user_idx] - b_i[user_idx];
                // current_req = (diff < 0) ? 0 : diff;
                
                next_state = VALIDATE;
            end
            
            VALIDATE: begin
                if (user_idx < 2'd3) begin
                    // Next user
                    user_idx <= user_idx + 1;
                    next_state = UPLOAD_CALC;
                end else begin
                    // All users done, check total
                    next_state = UPDATE_RESULT;
                end
            end
            
            UPDATE_RESULT: begin
                next_state = INCREMENT;
            end
            
            INCREMENT: begin
                // Check loop condition? Or let CHECK_BUFFER handle it.
                // We just incremented B.
                next_state = CHECK_BUFFER;
            end
            
            DONE: begin
                if (!start) next_state = IDLE; // Wait for start to go low
            end
            
            default: next_state = IDLE;
        endcase
    end

    // Calculation combinational logic
    always @(*) begin
        // Current user's requirement calculation
        // Using integer arithmetic as reasoned
        // B is signed 8-bit. C is 5-bit. p_i, b_i are 8-bit unsigned.
        // diff = B + C + p_i[user_idx] - b_i[user_idx];
        // Note: C is 5-bit, p_i is 8-bit. B is 8-bit.
        // We must sign extend to avoid overflow in intermediate math.
        
        // I will assume the logic: B (integer) + C + p - b
        // Note: C is input [4:0].
        // p_i, b_i are [7:0].
        
        // 16-bit signed accumulator for diff
        // B extended to 16 bits
        // C extended to 16 bits (unsigned, so upper bits 0)
        // p_i, b_i extended similarly.
        
        // Let's construct the calculation for UPLOAD_CALC state:
        // In UPLOAD_CALC, we compute current_req for user_idx.
        
        // We need access to inputs in combinational logic.
        // But the state machine logic above updates registers.
        
        // We need a combinational helper to calculate "what would be uploaded for current user"
        // to feed into the sequential update.
        
        // However, in the sequential block above, I didn't assign current_req.
        // Let's fix that. I'll add a combinational block to calculate current_req, 
        // and use it in the sequential block.
    end
    
    // Revisiting Sequential Logic to fill in the gaps (current_req calculation)
    // Since I cannot edit the previous block easily in this response format without rewriting,
    // I will rely on the state transitions defined and a combinational block to drive current_req.
    
    // To make this synthesizable and correct, let's define the calculation explicitly.
    // The calculation `diff` was defined in UPLOAD_CALC block in the sequential logic, but wasn't used.
    // I will fix the sequential logic by adding the current_req update.

endmodule

// Corrected module with full logic
module p2p_streaming_final(
    input clk,
    input rst_n,
    input start,
    input [7:0] p_i [0:3],
    input [7:0] b_i [0:3],
    input [7:0] u_i [0:3],
    input [4:0] C,
    output reg [7:0] result,
    output reg done
);

    // State encoding
    localparam IDLE = 4'b0000;
    localparam INIT = 4'b0001;
    localparam CHECK_BUFFER = 4'b0010;
    localparam UPLOAD_CALC = 4'b0011;
    localparam VALIDATE = 4'b0100;
    localparam UPDATE_RESULT = 4'b0101;
    localparam INCREMENT = 4'b0110;
    localparam DONE = 4'b0111;

    reg [3:0] state;
    reg signed [7:0] B;
    reg [1:0] user_idx;
    reg signed [15:0] total_upload_req;
    reg signed [15:0] total_bandwidth;
    reg signed [7:0] max_B;
    
    // Intermediate calculation registers
    reg signed [15:0] current_req_reg;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 8'sd0;
            done <= 1'b0;
            B <= -8'sd128;
            user_idx <= 2'd0;
            total_upload_req <= 16'sd0;
            total_bandwidth <= 16'sd0;
            max_B <= -8'sd128;
            current_req_reg <= 16'sd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        // Sum bandwidths once. u_i are 8-bit unsigned.
                        total_bandwidth <= {8'd0, u_i[0]} + {8'd0, u_i[1]} + {8'd0, u_i[2]} + {8'd0, u_i[3]};
                        state <= INIT;
                    end
                end
                
                INIT: begin
                    B <= -8'sd128;
                    max_B <= -8'sd128;
                    total_upload_req <= 16'sd0;
                    user_idx <= 2'd0;
                    state <= CHECK_BUFFER;
                end
                
                CHECK_BUFFER: begin
                    // Check if we finished all B values (B > 127)
                    if (B > 8'sd127) begin
                        state <= DONE;
                    end else begin
                        // Start calculating uploads for this B
                        total_upload_req <= 16'sd0;
                        user_idx <= 2'd0;
                        state <= UPLOAD_CALC;
                    end
                end
                
                UPLOAD_CALC: begin
                    // Calculate requirement for current user
                    // Formula: req = max(0, B + C + p_i - b_i)
                    // Inputs: B (signed 8), C (unsigned 5), p_i/b_i (unsigned 8).
                    // We treat them as integer values.
                    
                    // diff = B + C + p_i[user_idx] - b_i[user_idx]
                    // Sign extend all to 16 bits for safe math
                    
                    // Note: C is small, p_i/b_i are 8-bit. Max value ~ 127 + 31 + 255 = 413. Fits in signed 16-bit.
                    
                    current_req_reg <= B + {11'd0, C} + {8'd0, p_i[user_idx]} - {8'd0, b_i[user_idx]};
                    
                    state <= VALIDATE;
                end
                
                VALIDATE: begin
                    // Clamp to 0 if negative
                    if (current_req_reg < 0) begin
                        total_upload_req <= total_upload_req + 16'sd0;
                    end else begin
                        total_upload_req <= total_upload_req + current_req_reg;
                    end
                    
                    // Check if all users processed
                    if (user_idx < 2'd3) begin
                        user_idx <= user_idx + 1;
                        state <= UPLOAD_CALC;
                    end else begin
                        // Check if sum requirement <= total bandwidth
                        // Bandwidth is sum of u_i. Requirements are sums of calculated reqs.
                        // If total_upload_req <= total_bandwidth, B is valid.
                        // Note: We can just check this condition in UPDATE_RESULT state to save logic path
                        state <= UPDATE_RESULT;
                    end
                end
                
                UPDATE_RESULT: begin
                    if (total_upload_req <= total_bandwidth) begin
                        max_B <= B;
                    end
                    B <= B + 8'sd1;
                    state <= CHECK_BUFFER;
                end
                
                DONE: begin
                    // Output is Q8.8. max_B is integer, so shift left by 8.
                    result <= {max_B, 8'd0};
                    done <= 1'b1;
                    if (!start) state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end

endmodule
