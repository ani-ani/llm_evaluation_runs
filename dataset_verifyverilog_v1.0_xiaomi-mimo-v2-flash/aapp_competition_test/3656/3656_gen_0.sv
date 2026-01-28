module max_severity_scheduler (
    input wire clk,
    input wire rst_n,
    input wire [3:0] B,
    input wire [7:0] T,
    input wire [15:0] p_in, // Q8.8
    input wire [15:0] s_in,
    input wire [15:0] f_in, // Q8.8
    input wire load_en,
    output reg [31:0] result, // Q16.16
    output reg done
);

    // State Declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] LOAD = 3'd1;
    localparam [2:0] COMPUTE_FIND_MAX = 3'd2;
    localparam [2:0] COMPUTE_UPDATE = 3'd3;
    localparam [2:0] UPDATE_TIMER = 3'd4;
    localparam [2:0] FINISH = 3'd5;

    // Register Arrays (Unpacked arrays are synthesizable in always blocks)
    reg [15:0] p_reg [0:9];  // Q8.8
    reg [15:0] s_reg [0:9];  // Severity
    
    // Internal Registers
    reg [2:0] state;
    reg [2:0] next_state;
    reg [3:0] load_idx;
    reg [7:0] time_remain;
    reg [4:0] search_idx; // 0 to 10
    reg [3:0] max_idx;
    reg [31:0] max_val; // Q16.16
    reg [31:0] current_val; // Q16.16
    reg [31:0] temp_score; // Q16.16
    reg [31:0] result_accum; // Q16.16
    reg [31:0] mult_op_a;
    reg [31:0] mult_op_b;
    wire [31:0] mult_result;

    // Multiplier (Q8.8 * Q8.8 = Q16.16)
    // Input A: p_reg[search_idx] (Q8.8)
    // Input B: s_reg[search_idx] (16-bit integer, treat as Q16.0 -> shifted to Q16.16 for consistency or raw mul)
    // Actually, p (Q8.8) * s (integer) = Q8.8 result. We want Q16.16 for accumulation.
    // p_reg is 16 bits (8.8). s_reg is 16 bits (integer).
    // Product = p_reg * s_reg. Max value: 255 * 10000 ~ 2.5e6. Fits in 22 bits.
    // Let's do p_reg * s_reg. Result is Q8.8 (since s is integer).
    // We will normalize to Q16.16 later.
    
    // To keep logic simple and avoid division during execution, we stick to integer math where possible.
    // However, the problem implies floating point arithmetic. We use fixed point.
    // p is Q8.8. s is integer (max 10000).
    // p * s = (p << 8) * s >> 8. 
    // Let's use a 32-bit multiplier for p * s.
    assign mult_result = mult_op_a * mult_op_b; // 32x32 -> 64 bits, truncated to 32

    // FSM State Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result <= 32'd0;
            load_idx <= 4'd0;
            time_remain <= 8'd0;
            search_idx <= 5'd0;
            max_idx <= 4'd0;
            max_val <= 32'd0;
            current_val <= 32'd0;
            temp_score <= 32'd0;
            result_accum <= 32'd0;
            mult_op_a <= 32'd0;
            mult_op_b <= 32'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (load_en && B > 4'd0) begin
                        state <= LOAD;
                        load_idx <= 4'd0;
                        time_remain <= T;
                        result_accum <= 32'd0;
                    end
                end

                LOAD: begin
                    // Load p and s for current bug
                    p_reg[load_idx] <= p_in;
                    s_reg[load_idx] <= s_in;
                    load_idx <= load_idx + 4'd1;
                    
                    // If loaded all bugs, move to compute
                    if (load_idx == B - 4'd1) begin
                        state <= COMPUTE_FIND_MAX;
                        search_idx <= 5'd0;
                        max_val <= 32'd0;
                    end
                end

                COMPUTE_FIND_MAX: begin
                    // Calculate p_reg[search_idx] * s_reg[search_idx]
                    // p is Q8.8 (16 bits), s is 16 bits.
                    // Result is Q8.8 (scaled by 256).
                    mult_op_a <= {16'd0, p_reg[search_idx]};
                    mult_op_b <= {16'd0, s_reg[search_idx]};
                    // Allow 1 cycle for multiplier
                    
                    // Check next cycle
                    state <= COMPUTE_UPDATE;
                end

                COMPUTE_UPDATE: begin
                    // mult_result holds p * s (Q8.8).
                    // We want to compare Q16.16 values.
                    // Convert Q8.8 to Q16.16: result << 8.
                    current_val <= mult_result << 8;
                    
                    if (search_idx == 5'd0 || (mult_result << 8) > max_val) begin
                        max_val <= mult_result << 8;
                        max_idx <= search_idx;
                    end

                    search_idx <= search_idx + 5'd1;

                    // Done searching all bugs?
                    if (search_idx == B - 1) begin
                        // Add max_val to result_accum
                        result_accum <= result_accum + max_val;
                        state <= UPDATE_TIMER;
                    end else begin
                        state <= COMPUTE_FIND_MAX;
                    end
                end

                UPDATE_TIMER: begin
                    // Update probability of the selected bug: p = p * f
                    // p_reg[max_idx] = p_reg[max_idx] * f_in (Q8.8 * Q8.8)
                    // f is Q8.8. p is Q8.8. Product is Q16.16. We keep high byte (Q8.8).
                    mult_op_a <= {16'd0, p_reg[max_idx]};
                    mult_op_b <= {16'd0, f_in};
                    
                    // Next cycle apply update
                    state <= UPDATE_TIMER + 1;
                end
                
                // Split UPDATE_TIMER logic to separate state for sequential update
                3'(UPDATE_TIMER) + 1: begin // Intermediate state for mult result
                    // mult_result is Q16.16. Shift right 8 to get Q8.8.
                    p_reg[max_idx] <= mult_result[23:8];
                    
                    time_remain <= time_remain - 8'd1;
                    
                    if (time_remain == 8'd1) begin
                        state <= FINISH;
                    end else begin
                        state <= COMPUTE_FIND_MAX;
                        search_idx <= 5'd0;
                        max_val <= 32'd0;
                    end
                end

                FINISH: begin
                    result <= result_accum;
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule