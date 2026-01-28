module SumCommonDivisors(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [15:0] a,
    input wire [15:0] b,
    input wire [11:0] max_iter,
    output reg [23:0] result,
    output reg done,
    output reg busy
);

    // Parameters
    parameter MIN_WIDTH = 16;
    parameter ITER_WIDTH = 12;
    parameter RESULT_WIDTH = 24;

    // State declarations
    localparam [2:0] IDLE     = 3'd0;
    localparam [2:0] INIT     = 3'd1;
    localparam [2:0] CHECK    = 3'd2;
    localparam [2:0] MODULO   = 3'd3;
    localparam [2:0] ACCUM    = 3'd4;
    localparam [2:0] INCREMENT = 3'd5;
    localparam [2:0] FINISH   = 3'd6;

    // Registers and wires
    reg [2:0] state;
    reg [2:0] next_state;
    reg [15:0] counter;
    reg [15:0] bound;
    reg [23:0] accumulator;
    reg [15:0] mod_a;
    reg [15:0] mod_b;
    reg [15:0] divisor;
    reg [15:0] dividend_a;
    reg [15:0] dividend_b;
    reg [15:0] temp_a;
    reg [15:0] temp_b;
    reg [15:0] quotient_a;
    reg [15:0] quotient_b;
    reg [3:0] mod_state;
    reg mod_done;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd255;

    // Modulo computation using repeated subtraction (sequential)
    // State machine for modulo calculation
    localparam [1:0] MOD_IDLE  = 2'd0;
    localparam [1:0] MOD_CALC  = 2'd1;
    localparam [1:0] MOD_DONE  = 2'd2;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 24'd0;
            done <= 1'b0;
            busy <= 1'b0;
            counter <= 16'd0;
            bound <= 16'd0;
            accumulator <= 24'd0;
            mod_a <= 16'd0;
            mod_b <= 16'd0;
            divisor <= 16'd0;
            dividend_a <= 16'd0;
            dividend_b <= 16'd0;
            temp_a <= 16'd0;
            temp_b <= 16'd0;
            quotient_a <= 16'd0;
            quotient_b <= 16'd0;
            mod_state <= MOD_IDLE;
            mod_done <= 1'b0;
            cycle_count <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    busy <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= INIT;
                        busy <= 1'b1;
                    end
                end

                INIT: begin
                    // Compute min(a, b)
                    if (a < b) begin
                        bound <= a;
                    end else begin
                        bound <= b;
                    end
                    // Cap bound at max_iter
                    if (bound > max_iter) begin
                        bound <= max_iter;
                    end
                    counter <= 16'd1;
                    accumulator <= 24'd0;
                    mod_state <= MOD_IDLE;
                    mod_done <= 1'b0;
                    state <= CHECK;
                end

                CHECK: begin
                    cycle_count <= cycle_count + 8'd1;
                    // Check termination conditions
                    if (counter > bound || cycle_count >= MAX_CYCLES) begin
                        state <= FINISH;
                    end else begin
                        // Start modulo computation
                        divisor <= counter;
                        dividend_a <= a;
                        dividend_b <= b;
                        temp_a <= a;
                        temp_b <= b;
                        quotient_a <= 16'd0;
                        quotient_b <= 16'd0;
                        mod_state <= MOD_CALC;
                        mod_done <= 1'b0;
                        state <= MODULO;
                    end
                end

                MODULO: begin
                    // Sequential modulo using repeated subtraction
                    case (mod_state)
                        MOD_CALC: begin
                            if (divisor == 16'd0) begin
                                mod_a <= temp_a;
                                mod_b <= temp_b;
                                mod_done <= 1'b1;
                                mod_state <= MOD_DONE;
                            end else begin
                                // Subtract for A
                                if (temp_a >= divisor) begin
                                    temp_a <= temp_a - divisor;
                                    quotient_a <= quotient_a + 16'd1;
                                end
                                // Subtract for B
                                if (temp_b >= divisor) begin
                                    temp_b <= temp_b - divisor;
                                    quotient_b <= quotient_b + 16'd1;
                                end
                                // Check if done for both
                                if (temp_a < divisor && temp_b < divisor) begin
                                    mod_a <= temp_a;
                                    mod_b <= temp_b;
                                    mod_done <= 1'b1;
                                    mod_state <= MOD_DONE;
                                end
                            end
                        end
                        MOD_DONE: begin
                            // Remain in done state until processed
                        end
                        default: begin
                            mod_state <= MOD_IDLE;
                        end
                    endcase
                    
                    if (mod_done) begin
                        state <= ACCUM;
                    end
                end

                ACCUM: begin
                    // Check if both modulos are 0
                    if (mod_a == 16'd0 && mod_b == 16'd0) begin
                        accumulator <= accumulator + {8'd0, counter[15:0]};
                    end
                    mod_state <= MOD_IDLE;
                    mod_done <= 1'b0;
                    state <= INCREMENT;
                end

                INCREMENT: begin
                    counter <= counter + 16'd1;
                    state <= CHECK;
                end

                FINISH: begin
                    result <= accumulator;
                    done <= 1'b1;
                    busy <= 1'b0;
                    state <= IDLE;
                end

                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule