module grade_rounder(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] n,
    input wire [31:0] t,
    input wire [99:0] grade_int,
    input wire [99:0] grade_frac,
    output reg [100:0] result_int,
    output reg [99:0] result_frac,
    output reg [7:0] result_len,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE     = 3'd0;
    localparam [2:0] PARSE    = 3'd1;
    localparam [2:0] SCAN     = 3'd2;
    localparam [2:0] ROUND    = 3'd3;
    localparam [2:0] FINALIZE = 3'd4;
    localparam [2:0] DONE_STATE = 3'd5;

    reg [2:0] state, next_state;

    // Internal registers
    reg [7:0] int_len, frac_len;
    reg [99:0] int_digits, frac_digits;
    reg [99:0] rounded_int, rounded_frac;
    reg [7:0] round_pos;
    reg [7:0] round_count;
    reg [7:0] carry_pos;
    reg carry;

    // Cycle counter to prevent infinite loops
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd200;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            done <= 1'b0;
            cycle_count <= 8'd0;
            int_len <= 8'd0;
            frac_len <= 8'd0;
            int_digits <= 100'd0;
            frac_digits <= 100'd0;
            rounded_int <= 100'd0;
            rounded_frac <= 100'd0;
            round_pos <= 8'd0;
            round_count <= 8'd0;
            carry_pos <= 8'd0;
            carry <= 1'b0;
            result_int <= 101'd0;
            result_frac <= 100'd0;
            result_len <= 8'd0;
        end else begin
            state <= next_state;
            cycle_count <= cycle_count + 8'd1;

            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        next_state <= PARSE;
                        cycle_count <= 8'd0;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                PARSE: begin
                    // Extract integer and fractional lengths
                    int_len <= n[7:4];  // Upper 4 bits for integer length
                    frac_len <= n[3:0];  // Lower 4 bits for fractional length
                    
                    // Store digits
                    int_digits <= grade_int;
                    frac_digits <= grade_frac;
                    
                    next_state <= SCAN;
                end

                SCAN: begin
                    // Find first fractional digit >= 5
                    integer i;
                    round_pos <= 8'd0;
                    for (i = 0; i < frac_len; i = i + 1) begin
                        if (frac_digits[i*8 +: 8] >= 8'd5) begin
                            round_pos <= i;
                            break;
                        end
                    end
                    
                    // If no digit >= 5, output original
                    if (round_pos == 8'd0 && frac_digits[0*8 +: 8] < 8'd5) begin
                        next_state <= FINALIZE;
                    end else begin
                        next_state <= ROUND;
                    end
                end

                ROUND: begin
                    // Calculate how many consecutive digits >= 5
                    integer i, k;
                    k = 0;
                    for (i = round_pos; i < frac_len; i = i + 1) begin
                        if (frac_digits[i*8 +: 8] >= 8'd5) begin
                            k = k + 1;
                        end else begin
                            break;
                        end
                    end
                    
                    // Determine number of rounds
                    if (k <= t) begin
                        round_count <= k;
                    end else begin
                        round_count <= t;
                    end
                    
                    // Perform rounding
                    rounded_int <= int_digits;
                    rounded_frac <= frac_digits;
                    
                    // Start from the rightmost digit to round
                    carry_pos <= round_pos + round_count - 1;
                    carry <= 1'b1;
                    
                    // Propagate carry through fractional part
                    for (i = carry_pos; i >= 0; i = i - 1) begin
                        if (carry) begin
                            if (rounded_frac[i*8 +: 8] + 8'd1 >= 8'd10) begin
                                rounded_frac[i*8 +: 8] <= 8'd0;
                                carry <= 1'b1;
                            end else begin
                                rounded_frac[i*8 +: 8] <= rounded_frac[i*8 +: 8] + 8'd1;
                                carry <= 1'b0;
                            end
                        end
                    end
                    
                    // Propagate carry to integer part if needed
                    if (carry) begin
                        integer j;
                        for (j = int_len - 1; j >= 0; j = j - 1) begin
                            if (rounded_int[j*8 +: 8] + 8'd1 >= 8'd10) begin
                                rounded_int[j*8 +: 8] <= 8'd0;
                                carry <= 1'b1;
                            end else begin
                                rounded_int[j*8 +: 8] <= rounded_int[j*8 +: 8] + 8'd1;
                                carry <= 1'b0;
                                break;
                            end
                        end
                        
                        // If carry still exists, add new digit
                        if (carry) begin
                            rounded_int[100*8 +: 8] <= 8'd1;
                        end
                    end
                    
                    next_state <= FINALIZE;
                end

                FINALIZE: begin
                    // Prepare output
                    result_int <= {1'b0, rounded_int};
                    result_frac <= rounded_frac;
                    
                    // Calculate result length
                    if (rounded_frac == 100'd0) begin
                        result_len <= int_len + 1'b1;  // Only integer part
                    end else begin
                        result_len <= int_len + frac_len + 1'b1;  // Include decimal point
                    end
                    
                    next_state <= DONE_STATE;
                end

                DONE_STATE: begin
                    done <= 1'b1;
                    next_state <= IDLE;
                end

                default: begin
                    next_state <= IDLE;
                end
            endcase
        end
    end

    // Prevent infinite loops
    always @(posedge clk) begin
        if (cycle_count >= MAX_CYCLES) begin
            next_state <= IDLE;
            cycle_count <= 8'd0;
        end
    end

endmodule