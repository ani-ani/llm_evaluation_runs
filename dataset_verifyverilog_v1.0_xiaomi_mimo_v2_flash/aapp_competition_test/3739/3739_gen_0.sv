module goldbach_checker(
    input clk,
    input rst_n,
    input start,
    input [5:0] len,
    input [7:0] arr [0:63],
    output reg result,
    output reg done
);

    // State definitions
    localparam [3:0] IDLE      = 4'd0;
    localparam [3:0] SKIP_WS   = 4'd1;
    localparam [3:0] IN_TOKEN  = 4'd2;
    localparam [3:0] CHECK_TOK = 4'd3;
    localparam [3:0] CHECK_SUM = 4'd4;
    localparam [3:0] DONE      = 4'd5;
    localparam [3:0] ERROR     = 4'd6;

    // Internal registers
    reg [3:0] state, next_state;
    reg [5:0] idx;              // Current character index
    reg [7:0] token_val;        // Current token value (0-255)
    reg [7:0] token_len;        // Current token length
    reg [1:0] token_cnt;        // Number of tokens parsed (0-3)
    reg [7:0] nums [0:2];       // Parsed numbers: 0=first, 1=second, 2=third
    reg valid_char;             // Flag for valid digit/whitespace
    reg digit_seen;             // Flag for at least one digit in current token
    reg overflow;               // Flag for overflow (>255)
    reg [7:0] i_reg;            // Loop counter
    reg [2:0] bits;             // Number of bits for primality lookup

    // Reset and state update
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 1'b0;
            done <= 1'b0;
            idx <= 6'd0;
            token_val <= 8'd0;
            token_len <= 8'd0;
            token_cnt <= 2'd0;
            nums[0] <= 8'd0;
            nums[1] <= 8'd0;
            nums[2] <= 8'd0;
            valid_char <= 1'b0;
            digit_seen <= 1'b0;
            overflow <= 1'b0;
            i_reg <= 8'd0;
            bits <= 3'd0;
        end else begin
            state <= next_state;
        end
    end

    // Next state logic and combinational outputs
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) begin
                    // Validate len range
                    if (len > 64) begin
                        next_state = ERROR;
                    end else begin
                        next_state = SKIP_WS;
                    end
                end
            end

            SKIP_WS: begin
                // Skip whitespace, check bounds
                if (idx < len) begin
                    if (arr[idx] == 8'h20 || arr[idx] == 8'h09 || arr[idx] == 8'h0A || arr[idx] == 8'h0D) begin
                        next_state = SKIP_WS;
                    end else begin
                        // Start new token if not all tokens parsed
                        if (token_cnt < 3) begin
                            next_state = IN_TOKEN;
                        end else begin
                            next_state = ERROR;
                        end
                    end
                end else begin
                    // End of string
                    if (token_cnt == 3) begin
                        next_state = CHECK_SUM;
                    end else begin
                        next_state = ERROR;
                    end
                end
            end

            IN_TOKEN: begin
                if (idx < len) begin
                    if (arr[idx] >= 8'h30 && arr[idx] <= 8'h39) begin
                        // Digit
                        next_state = IN_TOKEN;
                    end else begin
                        // Non-digit - token ends
                        if (digit_seen && !overflow) begin
                            next_state = CHECK_TOK;
                        end else begin
                            next_state = ERROR;
                        end
                    end
                end else begin
                    // End of string
                    if (digit_seen && !overflow) begin
                        next_state = CHECK_TOK;
                    end else begin
                        next_state = ERROR;
                    end
                end
            end

            CHECK_TOK: begin
                // Validate token based on position
                if (token_cnt == 3) begin
                    next_state = ERROR; // Too many tokens
                end else begin
                    next_state = SKIP_WS;
                end
            end

            CHECK_SUM: begin
                // Validate numbers and sum
                // Numbers are already validated in CHECK_TOK
                next_state = DONE;
            end

            DONE: begin
                next_state = IDLE;
            end

            ERROR: begin
                next_state = IDLE;
            end

            default: next_state = IDLE;
        endcase
    end

    // Sequential operations
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Already reset in main block
        end else begin
            case (state)
                IDLE: begin
                    // Clear outputs
                    result <= 1'b0;
                    done <= 1'b0;
                    idx <= 6'd0;
                    token_val <= 8'd0;
                    token_len <= 8'd0;
                    token_cnt <= 2'd0;
                    digit_seen <= 1'b0;
                    overflow <= 1'b0;
                end

                SKIP_WS: begin
                    if (idx < len) begin
                        if (arr[idx] == 8'h20 || arr[idx] == 8'h09 || arr[idx] == 8'h0A || arr[idx] == 8'h0D) begin
                            idx <= idx + 6'd1;
                        end else begin
                            // Start token
                            token_val <= 8'd0;
                            token_len <= 8'd0;
                            digit_seen <= 1'b0;
                            overflow <= 1'b0;
                        end
                    end
                end

                IN_TOKEN: begin
                    if (idx < len) begin
                        if (arr[idx] >= 8'h30 && arr[idx] <= 8'h39) begin
                            // Accumulate: val = val*10 + digit
                            token_val <= (token_val << 3) + (token_val << 1) + (arr[idx] - 8'h30);
                            token_len <= token_len + 8'd1;
                            digit_seen <= 1'b1;
                            // Check overflow (>255) or length >3
                            if ((token_val > 8'd25) || (token_len >= 3 && (token_val > 8'd25 || (arr[idx] > 8'h35)))) begin
                                overflow <= 1'b1;
                            end
                            idx <= idx + 6'd1;
                        end else begin
                            // End token - keep idx same for next state
                        end
                    end else begin
                        // End of string - finish token
                    end
                end

                CHECK_TOK: begin
                    // Store token, validate based on position
                    if (token_cnt == 0) begin
                        nums[0] <= token_val;
                        // Check: even, >3, <=255
                        if (token_val > 8'd3 && token_val[0] == 1'b0) begin
                            // Valid first token
                        end else begin
                            // Will error in next state
                        end
                    end else if (token_cnt == 1) begin
                        nums[1] <= token_val;
                        // Check: prime (validated via lookup later)
                    end else if (token_cnt == 2) begin
                        nums[2] <= token_val;
                        // Check: prime
                    end
                    token_cnt <= token_cnt + 2'd1;
                end

                CHECK_SUM: begin
                    // Validate all tokens
                    // nums[0] must be even >3 <=255
                    // nums[1], nums[2] must be prime <=255
                    // nums[0] == nums[1] + nums[2]
                    // We will set result in DONE state
                end

                DONE: begin
                    done <= 1'b1;
                    // Determine result
                    result <= 1'b0; // Default fail
                    // Check nums[0] validity
                    if (nums[0] > 8'd3 && nums[0][0] == 1'b0 && nums[0] <= 8'd255) begin
                        // Check nums[1] primality
                        if (nums[1] <= 8'd255 && is_prime(nums[1])) begin
                            // Check nums[2] primality
                            if (nums[2] <= 8'd255 && is_prime(nums[2])) begin
                                // Check sum
                                if (nums[0] == (nums[1] + nums[2])) begin
                                    result <= 1'b1;
                                end
                            end
                        end
                    end
                end

                ERROR: begin
                    done <= 1'b1;
                    result <= 1'b0;
                end
            endcase
        end
    end

    // Helper function for primality check (combinational)
    function automatic is_prime(input [7:0] n);
        begin
            if (n < 2) begin
                is_prime = 1'b0;
            end else begin
                // Case lookup for 0-255 (2 is prime, 3 is prime, etc.)
                case (n)
                    8'd0: is_prime = 1'b0;
                    8'd1: is_prime = 1'b0;
                    8'd2: is_prime = 1'b1;
                    8'd3: is_prime = 1'b1;
                    8'd5: is_prime = 1'b1;
                    8'd7: is_prime = 1'b1;
                    8'd11: is_prime = 1'b1;
                    8'd13: is_prime = 1'b1;
                    8'd17: is_prime = 1'b1;
                    8'd19: is_prime = 1'b1;
                    8'd23: is_prime = 1'b1;
                    8'd29: is_prime = 1'b1;
                    8'd31: is_prime = 1'b1;
                    8'd37: is_prime = 1'b1;
                    8'd41: is_prime = 1'b1;
                    8'd43: is_prime = 1'b1;
                    8'd47: is_prime = 1'b1;
                    8'd53: is_prime = 1'b1;
                    8'd59: is_prime = 1'b1;
                    8'd61: is_prime = 1'b1;
                    8'd67: is_prime = 1'b1;
                    8'd71: is_prime = 1'b1;
                    8'd73: is_prime = 1'b1;
                    8'd79: is_prime = 1'b1;
                    8'd83: is_prime = 1'b1;
                    8'd89: is_prime = 1'b1;
                    8'd97: is_prime = 1'b1;
                    8'd101: is_prime = 1'b1;
                    8'd103: is_prime = 1'b1;
                    8'd107: is_prime = 1'b1;
                    8'd109: is_prime = 1'b1;
                    8'd113: is_prime = 1'b1;
                    8'd127: is_prime = 1'b1;
                    8'd131: is_prime = 1'b1;
                    8'd137: is_prime = 1'b1;
                    8'd139: is_prime = 1'b1;
                    8'd149: is_prime = 1'b1;
                    8'd151: is_prime = 1'b1;
                    8'd157: is_prime = 1'b1;
                    8'd163: is_prime = 1'b1;
                    8'd167: is_prime = 1'b1;
                    8'd173: is_prime = 1'b1;
                    8'd179: is_prime = 1'b1;
                    8'd181: is_prime = 1'b1;
                    8'd191: is_prime = 1'b1;
                    8'd193: is_prime = 1'b1;
                    8'd197: is_prime = 1'b1;
                    8'd199: is_prime = 1'b1;
                    8'd211: is_prime = 1'b1;
                    8'd223: is_prime = 1'b1;
                    8'd227: is_prime = 1'b1;
                    8'd229: is_prime = 1'b1;
                    8'd233: is_prime = 1'b1;
                    8'd239: is_prime = 1'b1;
                    8'd241: is_prime = 1'b1;
                    8'd251: is_prime = 1'b1;
                    default: is_prime = 1'b0;
                endcase
            end
        end
    endfunction

endmodule