module RebusSolver (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [127:0] expr_data,
    input wire signed [31:0] n_value,  // Q16.16 format
    input wire [3:0] num_qmarks,
    output reg [2047:0] result,
    output reg done,
    output reg possible
);

    // State definitions
    localparam [3:0] IDLE         = 4'd0;
    localparam [3:0] PARSE_EXPR   = 4'd1;
    localparam [3:0] INITIALIZE   = 4'd2;
    localparam [3:0] CHECK_SUM    = 4'd3;
    localparam [3:0] ADJUST       = 4'd4;
    localparam [3:0] BUILD_OUTPUT = 4'd5;
    localparam [3:0] FINISHED     = 4'd6;

    // Internal registers
    reg [3:0] state, next_state;
    reg [7:0] cycle_count;
    reg [3:0] qmark_idx;
    reg [3:0] num_plus;
    reg [3:0] num_minus;
    reg signed [15:0] current_sum;  // 16-bit integer sum
    reg signed [31:0] target_n;      // Q16.16 target
    reg signed [15:0] adjustment;
    reg [3:0] current_qmark;
    reg [1:0] sign_array [0:15];    // Store sign: 1=plus, 0=minus
    reg [15:0] value_array [0:15];  // Store assigned values (16-bit each)
    reg [4:0] token_idx;
    reg [1:0] current_token;
    reg [2047:0] temp_result;
    reg [7:0] out_idx;
    reg [3:0] i;

    // Token definitions
    localparam [1:0] TOKEN_QMARK = 2'd1;
    localparam [1:0] TOKEN_PLUS  = 2'd2;
    localparam [1:0] TOKEN_MINUS = 2'd3;
    localparam [1:0] TOKEN_EQ    = 2'd4;
    localparam [1:0] TOKEN_END   = 2'd0;

    // State transition
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            possible <= 1'b0;
            cycle_count <= 8'd0;
            result <= 2048'd0;
            // Initialize arrays
            for (i = 0; i < 16; i = i + 1) begin
                sign_array[i] <= 2'd0;
                value_array[i] <= 16'd1;
            end
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    possible <= 1'b0;
                    cycle_count <= 8'd0;
                    qmark_idx <= 4'd0;
                    num_plus <= 4'd0;
                    num_minus <= 4'd0;
                    token_idx <= 5'd0;
                    current_sum <= 16'd0;
                    target_n <= 32'd0;
                    adjustment <= 16'd0;
                    current_qmark <= 4'd0;
                end

                PARSE_EXPR: begin
                    cycle_count <= cycle_count + 8'd1;
                    // Extract 2-bit token from expr_data
                    current_token <= expr_data[(token_idx * 2) +: 2];
                    
                    if (expr_data[(token_idx * 2) +: 2] == TOKEN_QMARK) begin
                        // Count question marks and track sign
                        if (qmark_idx < num_qmarks) begin
                            sign_array[qmark_idx] <= 2'd1;  // Default positive
                            value_array[qmark_idx] <= 16'd1;
                            qmark_idx <= qmark_idx + 4'd1;
                        end
                    end else if (expr_data[(token_idx * 2) +: 2] == TOKEN_PLUS) begin
                        num_plus <= num_plus + 4'd1;
                        // Set next qmark to positive
                        if (qmark_idx > 4'd0 && qmark_idx <= num_qmarks) begin
                            sign_array[qmark_idx - 4'd1] <= 2'd1;
                        end
                    end else if (expr_data[(token_idx * 2) +: 2] == TOKEN_MINUS) begin
                        num_minus <= num_minus + 4'd1;
                        // Set next qmark to negative
                        if (qmark_idx > 4'd0 && qmark_idx <= num_qmarks) begin
                            sign_array[qmark_idx - 4'd1] <= 2'd0;
                        end
                    end else if (expr_data[(token_idx * 2) +: 2] == TOKEN_EQ) begin
                        target_n <= n_value;
                    end
                    
                    token_idx <= token_idx + 5'd1;
                end

                INITIALIZE: begin
                    // Calculate initial sum: (#pos) - (#neg)
                    current_sum <= num_plus - num_minus;
                    current_qmark <= 4'd0;
                    adjustment <= 16'd0;
                end

                CHECK_SUM: begin
                    // Convert target to 16-bit integer (divide by 65536)
                    // target_n is Q16.16, so upper 16 bits are integer part
                    // If target_n is negative, need proper handling
                    if (target_n[31]) begin
                        // Negative target
                        if (current_sum > target_n[31:16]) begin
                            adjustment <= current_sum - target_n[31:16];
                        end else begin
                            adjustment <= 16'd0;
                        end
                    end else begin
                        // Positive target
                        if (current_sum < target_n[31:16]) begin
                            adjustment <= target_n[31:16] - current_sum;
                        end else begin
                            adjustment <= 16'd0;
                        end
                    end
                end

                ADJUST: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    if (adjustment > 16'd0 && current_qmark < num_qmarks) begin
                        // Adjust values based on sign
                        if (sign_array[current_qmark] == 2'd1) begin
                            // Positive term - increase value
                            if (value_array[current_qmark] < 16'd1000) begin
                                value_array[current_qmark] <= value_array[current_qmark] + 16'd1;
                                adjustment <= adjustment - 16'd1;
                            end
                        end else begin
                            // Negative term - increase absolute value
                            if (value_array[current_qmark] < 16'd1000) begin
                                value_array[current_qmark] <= value_array[current_qmark] + 16'd1;
                                adjustment <= adjustment - 16'd1;
                            end
                        end
                        
                        if (adjustment > 16'd1) begin
                            current_qmark <= current_qmark + 4'd1;
                        end
                    end
                end

                BUILD_OUTPUT: begin
                    // Build output string: "?+?-?+...=n"
                    out_idx <= 8'd0;
                    temp_result <= 2048'd0;
                    qmark_idx <= 4'd0;
                end

                FINISHED: begin
                    done <= 1'b1;
                    // Check if solution found
                    if (adjustment == 16'd0 && cycle_count < 8'd100) begin
                        possible <= 1'b1;
                        result <= temp_result;
                    end else begin
                        possible <= 1'b0;
                        result <= 2048'd0;
                    end
                end
            endcase
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        
        case (state)
            IDLE: begin
                if (start) next_state = PARSE_EXPR;
            end
            
            PARSE_EXPR: begin
                if (token_idx >= 5'd32 || expr_data[(token_idx * 2) +: 2] == TOKEN_END) begin
                    next_state = INITIALIZE;
                end
            end
            
            INITIALIZE: begin
                next_state = CHECK_SUM;
            end
            
            CHECK_SUM: begin
                next_state = ADJUST;
            end
            
            ADJUST: begin
                if (adjustment == 16'd0 || cycle_count >= 8'd95) begin
                    next_state = BUILD_OUTPUT;
                end
            end
            
            BUILD_OUTPUT: begin
                // Build simplified output
                next_state = FINISHED;
            end
            
            FINISHED: begin
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end

    // Output string generation (simplified)
    always @(posedge clk) begin
        if (state == BUILD_OUTPUT) begin
            // Generate simplified output: "vals..=n"
            // For now, just show "result"
            temp_result[7:0] <= 8'd114;  // 'r'
            temp_result[15:8] <= 8'd101; // 'e'
            temp_result[23:16] <= 8'd115; // 's'
            temp_result[31:24] <= 8'd117; // 'u'
            temp_result[39:32] <= 8'd108; // 'l'
            temp_result[47:40] <= 8'd116; // 't'
            temp_result[55:48] <= 8'd58;  // ':'
            
            // If solution exists, append value
            if (adjustment == 16'd0) begin
                temp_result[63:56] <= 8'd50; // '2' (placeholder)
            end else begin
                temp_result[63:56] <= 8'd48; // '0'
            end
        end
    end

endmodule