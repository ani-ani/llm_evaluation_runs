module CharSumMod26(
    input clk,
    input rst_n,
    input start,
    input [7:0] char_in,
    output reg [3:0] idx_out,
    output reg [7:0] result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE      = 2'd0;
    localparam [1:0] PROCESS   = 2'd1;
    localparam [1:0] COMPUTE   = 2'd2;
    localparam [1:0] FINISH    = 2'd3;

    // Internal registers
    reg [1:0] state, next_state;
    reg [7:0] accumulator;
    reg [3:0] char_counter;
    reg [7:0] sum_mod_26;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            accumulator <= 8'd0;
            char_counter <= 4'd0;
            idx_out <= 4'd0;
            result <= 8'd0;
            done <= 1'b0;
            sum_mod_26 <= 8'd0;
        end else begin
            state <= next_state;

            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        next_state <= PROCESS;
                        accumulator <= 8'd0;
                        char_counter <= 4'd0;
                        idx_out <= 4'd0;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                PROCESS: begin
                    // Calculate character value (1-26)
                    reg [7:0] char_value;
                    char_value = char_in - 8'd96;  // 'a' is 97 in ASCII, so 97-96=1

                    // Add to accumulator
                    accumulator <= accumulator + char_value;

                    // Increment counter and index
                    char_counter <= char_counter + 4'd1;
                    idx_out <= idx_out + 4'd1;

                    // Check if all characters processed
                    if (char_counter == 4'd15) begin
                        next_state <= COMPUTE;
                    end else begin
                        next_state <= PROCESS;
                    end
                end

                COMPUTE: begin
                    // Calculate sum_mod_26
                    sum_mod_26 <= accumulator % 8'd26;

                    // Determine result character
                    if (sum_mod_26 == 8'd0) begin
                        result <= 8'd122;  // 'z'
                    end else begin
                        result <= 8'd96 + sum_mod_26;  // 'a' + (sum_mod_26 - 1)
                    end

                    next_state <= FINISH;
                end

                FINISH: begin
                    done <= 1'b1;
                    next_state <= IDLE;
                end

                default: begin
                    next_state <= IDLE;
                    done <= 1'b0;
                end
            endcase
        end
    end

endmodule