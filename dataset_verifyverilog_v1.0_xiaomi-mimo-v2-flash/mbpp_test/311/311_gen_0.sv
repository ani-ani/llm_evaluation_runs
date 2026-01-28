module SetLeftmostUnsetBit (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] n_in,
    output reg [7:0] result,
    output reg done
);
    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] CHECK_ALL_ONES = 3'd1;
    localparam [2:0] SCAN_BITS = 3'd2;
    localparam [2:0] OUTPUT_RESULT = 3'd3;
    localparam [2:0] FINISH = 3'd4;

    // Registers
    reg [2:0] state;
    reg [2:0] next_state;
    reg [7:0] temp_n;
    reg [2:0] bit_index; // 0-7 for bits
    reg found_zero;
    reg [7:0] result_reg;
    reg done_reg;

    // Combinational next state logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start)
                    next_state = CHECK_ALL_ONES;
                else
                    next_state = IDLE;
            end
            CHECK_ALL_ONES: begin
                // Check if n_in == 255
                if (temp_n == 8'd255)
                    next_state = FINISH;
                else
                    next_state = SCAN_BITS;
            end
            SCAN_BITS: begin
                // Scan from MSB (7) to LSB (0)
                if (found_zero || bit_index == 3'd0)
                    next_state = OUTPUT_RESULT;
                else
                    next_state = SCAN_BITS;
            end
            OUTPUT_RESULT: begin
                next_state = FINISH;
            end
            FINISH: begin
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            temp_n <= 8'd0;
            bit_index <= 3'd7;
            found_zero <= 1'b0;
            result_reg <= 8'd0;
            done_reg <= 1'b0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done_reg <= 1'b0;
                    if (start) begin
                        temp_n <= n_in;
                        bit_index <= 3'd7;
                        found_zero <= 1'b0;
                    end
                end
                CHECK_ALL_ONES: begin
                    // No action needed here, just transition
                    // temp_n already holds n_in from IDLE
                end
                SCAN_BITS: begin
                    if (!found_zero) begin
                        // Check current bit (bit_index) in temp_n
                        // MSB is bit 7, LSB is bit 0
                        if (temp_n[bit_index] == 1'b0) begin
                            found_zero <= 1'b1;
                            // Set this bit in result
                            result_reg <= temp_n | (8'b1 << bit_index);
                        end else if (bit_index > 3'd0) begin
                            bit_index <= bit_index - 3'd1;
                        end else begin
                            // bit_index is 0 and it's 1, meaning all bits were 1
                            // but we already handled 255 case. This is a safeguard.
                            found_zero <= 1'b0;
                            result_reg <= temp_n;
                        end
                    end
                end
                OUTPUT_RESULT: begin
                    result <= result_reg;
                end
                FINISH: begin
                    done_reg <= 1'b1;
                end
                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

    // Output assignment
    always @(*) begin
        done = done_reg;
    end

endmodule