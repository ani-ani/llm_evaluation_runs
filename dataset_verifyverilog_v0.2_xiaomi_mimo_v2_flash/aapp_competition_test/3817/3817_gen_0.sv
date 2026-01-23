module wool_sequence_counter (
    input clk,
    input rst_n,
    input start,
    input [31:0] n,
    input [31:0] m,
    output reg [31:0] result,
    output reg done
);

    // Constants
    localparam [31:0] MOD = 32'd1000000009;

    // States
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] CALC_POW = 3'd1;
    localparam [2:0] CALC_LOOP = 3'd2;
    localparam [2:0] DONE = 3'd3;

    // Registers
    reg [2:0] state;
    reg [31:0] pow_accum;
    reg [31:0] loop_counter;
    reg [31:0] current_result;
    reg [31:0] temp_mult;
    reg [31:0] exponent_counter;

    // 64-bit intermediate for multiplication
    reg [63:0] mult_result;

    // Next State Logic & Datapath
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 32'd0;
            done <= 1'b0;
            pow_accum <= 32'd0;
            loop_counter <= 32'd0;
            current_result <= 32'd0;
            temp_mult <= 32'd0;
            exponent_counter <= 32'd0;
            mult_result <= 64'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        if (n == 32'd0) begin
                            current_result <= 32'd1;
                            state <= DONE;
                        end else begin
                            state <= CALC_POW;
                            pow_accum <= 32'd1;
                            exponent_counter <= 32'd0;
                            loop_counter <= 32'd0;
                            current_result <= 32'd1;
                        end
                    end
                end

                CALC_POW: begin
                    if (exponent_counter < m) begin
                        mult_result <= pow_accum << 1;
                        if ((pow_accum << 1) >= MOD) begin
                            pow_accum <= (pow_accum << 1) - MOD;
                        end else begin
                            pow_accum <= pow_accum << 1;
                        end
                        exponent_counter <= exponent_counter + 32'd1;
                    end else begin
                        if (pow_accum > 0) begin
                            temp_mult <= pow_accum - 32'd1;
                        end else begin
                            temp_mult <= MOD - 32'd1;
                        end
                        current_result <= 32'd1;
                        state <= CALC_LOOP;
                    end
                end

                CALC_LOOP: begin
                    if (loop_counter < n) begin
                        mult_result <= current_result * temp_mult;
                        current_result <= (current_result * temp_mult) % MOD;
                        if (temp_mult == 0) begin
                            temp_mult <= MOD - 32'd1;
                        end else begin
                            temp_mult <= temp_mult - 32'd1;
                        end
                        loop_counter <= loop_counter + 32'd1;
                    end else begin
                        state <= DONE;
                    end
                end

                DONE: begin
                    result <= current_result;
                    done <= 1'b1;
                    if (!start) begin
                        state <= IDLE;
                        done <= 1'b0;
                    end
                end
            endcase
        end
    end

endmodule