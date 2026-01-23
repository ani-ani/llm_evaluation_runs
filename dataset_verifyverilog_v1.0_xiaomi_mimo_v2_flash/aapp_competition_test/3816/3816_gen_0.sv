module triangle_ways (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [4:0] a,
    input wire [4:0] b,
    input wire [4:0] c,
    input wire [4:0] l,
    output reg [15:0] result,
    output reg done
);

    // State machine states
    localparam [3:0] IDLE = 4'd0;
    localparam [3:0] START_COMPUTE = 4'd1;
    localparam [3:0] COMPUTE_TOTAL = 4'd2;
    localparam [3:0] INVALID_A_LOOP = 4'd3;
    localparam [3:0] INVALID_B_LOOP = 4'd4;
    localparam [3:0] INVALID_C_LOOP = 4'd5;
    localparam [3:0] FINAL_SUBTRACT = 4'd6;
    localparam [3:0] DONE_STATE = 4'd7;

    // Registers
    reg [3:0] state;
    reg [4:0] side_val, other1_val, other2_val;
    reg [4:0] x;
    reg [4:0] m_temp;
    reg signed [15:0] count_invalid;
    reg [15:0] total_sum;
    reg [15:0] temp_result;
    reg [4:0] delta;
    reg [15:0] term;
    reg [15:0] numerator;
    reg [4:0] loop_limit;

    // Combinational logic for term calculation
    // term = (M+1)*(M+2)/2
    // M is 5-bit (0-31), (M+1)*(M+2) is at most 32*33=1056, fits in 11 bits
    // division by 2 yields max 528, fits in 10 bits
    wire [10:0] num_mult;
    wire [9:0] term_comb;
    assign num_mult = (m_temp + 5'd1) * (m_temp + 5'd2);
    assign term_comb = num_mult[10:1];  // Divide by 2

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            side_val <= 5'd0;
            other1_val <= 5'd0;
            other2_val <= 5'd0;
            x <= 5'd0;
            m_temp <= 5'd0;
            count_invalid <= 16'd0;
            total_sum <= 16'd0;
            temp_result <= 16'd0;
            delta <= 5'd0;
            term <= 16'd0;
            numerator <= 16'd0;
            loop_limit <= 5'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= START_COMPUTE;
                    end
                end

                START_COMPUTE: begin
                    // Initialize for total sum calculation
                    // total = C(l+3, 3) = (l+3)*(l+2)*(l+1)/6
                    numerator <= (l + 5'd3) * (l + 5'd2) * (l + 5'd1);
                    total_sum <= 16'd0;
                    state <= COMPUTE_TOTAL;
                end

                COMPUTE_TOTAL: begin
                    // Divide numerator by 6 (repeat by 2, then by 3)
                    if (total_sum == 16'd0) begin
                        total_sum <= numerator[15:1];  // Divide by 2
                    end else if (total_sum != 16'd0 && total_sum != 16'd1) begin
                        total_sum <= total_sum / 6'd3;
                        state <= INVALID_A_LOOP;
                        // Setup for first side (a)
                        side_val <= a;
                        other1_val <= b;
                        other2_val <= c;
                        x <= 5'd0;
                        count_invalid <= 16'd0;
                    end else begin
                        // Should not happen, but safety
                        state <= INVALID_A_LOOP;
                        side_val <= a;
                        other1_val <= b;
                        other2_val <= c;
                        x <= 5'd0;
                        count_invalid <= 16'd0;
                    end
                end

                INVALID_A_LOOP: begin
                    // Check if side_val >= other1_val + other2_val
                    if (side_val >= other1_val + other2_val) begin
                        delta <= side_val - other1_val - other2_val;
                        loop_limit <= l;
                    end else begin
                        // Should not happen for valid triangle sides, but handle
                        loop_limit <= 5'd0;
                    end
                    
                    if (x <= loop_limit) begin
                        if (x >= delta && x <= l) begin
                            m_temp <= (l - x) < (x - delta) ? (l - x) : (x - delta);
                            term <= term_comb;
                            count_invalid <= count_invalid + term_comb;
                        end
                        x <= x + 5'd1;
                    end else begin
                        // End of loop for side a
                        // Save invalid count for a and setup for b
                        temp_result <= count_invalid;
                        state <= INVALID_B_LOOP;
                        side_val <= b;
                        other1_val <= a;
                        other2_val <= c;
                        x <= 5'd0;
                        count_invalid <= 16'd0;
                    end
                end

                INVALID_B_LOOP: begin
                    if (side_val >= other1_val + other2_val) begin
                        delta <= side_val - other1_val - other2_val;
                        loop_limit <= l;
                    end else begin
                        loop_limit <= 5'd0;
                    end
                    
                    if (x <= loop_limit) begin
                        if (x >= delta && x <= l) begin
                            m_temp <= (l - x) < (x - delta) ? (l - x) : (x - delta);
                            term <= term_comb;
                            count_invalid <= count_invalid + term_comb;
                        end
                        x <= x + 5'd1;
                    end else begin
                        // End of loop for side b
                        temp_result <= temp_result + count_invalid;
                        state <= INVALID_C_LOOP;
                        side_val <= c;
                        other1_val <= a;
                        other2_val <= b;
                        x <= 5'd0;
                        count_invalid <= 16'd0;
                    end
                end

                INVALID_C_LOOP: begin
                    if (side_val >= other1_val + other2_val) begin
                        delta <= side_val - other1_val - other2_val;
                        loop_limit <= l;
                    end else begin
                        loop_limit <= 5'd0;
                    end
                    
                    if (x <= loop_limit) begin
                        if (x >= delta && x <= l) begin
                            m_temp <= (l - x) < (x - delta) ? (l - x) : (x - delta);
                            term <= term_comb;
                            count_invalid <= count_invalid + term_comb;
                        end
                        x <= x + 5'd1;
                    end else begin
                        // End of loop for side c
                        temp_result <= temp_result + count_invalid;
                        state <= FINAL_SUBTRACT;
                    end
                end

                FINAL_SUBTRACT: begin
                    // Result = total - (invalid_a + invalid_b + invalid_c)
                    if (total_sum >= temp_result) begin
                        result <= total_sum - temp_result;
                    end else begin
                        result <= 16'd0;  // Should not happen, but safety
                    end
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