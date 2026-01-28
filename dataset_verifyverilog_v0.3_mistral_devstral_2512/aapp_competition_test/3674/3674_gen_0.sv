module find_number_small(
    input clk,
    input rst_n,
    input start,
    input [5:0] m,
    input [5:0] n,
    input [7:0] p,
    input [7:0] q,
    output reg [31:0] result,
    output reg done,
    output reg valid
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] INIT = 3'd1;
    localparam [2:0] COMPUTE = 3'd2;
    localparam [2:0] CHECK = 3'd3;
    localparam [2:0] FINISH = 3'd4;

    // Internal registers
    reg [2:0] state, next_state;
    reg [31:0] current_A;
    reg [31:0] current_B;
    reg [31:0] current_N;
    reg [31:0] current_remainder;
    reg [31:0] min_N;
    reg [31:0] max_N;
    reg [31:0] M;
    reg [31:0] L;
    reg [31:0] d;
    reg [31:0] solution;
    reg [31:0] found;
    reg [31:0] cycle_count;
    localparam [31:0] MAX_CYCLES = 32'd300000;

    // Power of 10 lookup table (for m=1-6)
    wire [31:0] pow10_m;
    always @(*) begin
        case (m)
            6'd1: pow10_m = 32'd10;
            6'd2: pow10_m = 32'd100;
            6'd3: pow10_m = 32'd1000;
            6'd4: pow10_m = 32'd10000;
            6'd5: pow10_m = 32'd100000;
            6'd6: pow10_m = 32'd1000000;
            default: pow10_m = 32'd1;
        endcase
    end

    // Power of 10 for d (1-3 digits)
    wire [31:0] pow10_d;
    always @(*) begin
        case (d)
            32'd1: pow10_d = 32'd10;
            32'd2: pow10_d = 32'd100;
            32'd3: pow10_d = 32'd1000;
            default: pow10_d = 32'd1;
        endcase
    end

    // Number of digits in p
    wire [31:0] p_digits;
    always @(*) begin
        if (p < 8'd10) p_digits = 32'd1;
        else if (p < 8'd100) p_digits = 32'd2;
        else p_digits = 32'd3;
    end

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            current_A <= 32'd0;
            current_B <= 32'd0;
            current_N <= 32'd0;
            current_remainder <= 32'd0;
            min_N <= 32'd0;
            max_N <= 32'd0;
            M <= 32'd0;
            L <= 32'd0;
            d <= 32'd0;
            solution <= 32'd0;
            found <= 32'd0;
            cycle_count <= 32'd0;
            result <= 32'd0;
            done <= 1'b0;
            valid <= 1'b0;
        end else begin
            state <= next_state;
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    valid <= 1'b0;
                    cycle_count <= 32'd0;
                    if (start) begin
                        next_state <= INIT;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                INIT: begin
                    L <= m - n;
                    d <= p_digits;
                    min_N <= pow10_m / 32'd10;
                    max_N <= pow10_m - 32'd1;
                    M <= (L > 32'd0) ? pow10_m / pow10_m : 32'd1;
                    current_A <= 32'd0;
                    solution <= 32'd0;
                    found <= 32'd0;
                    next_state <= COMPUTE;
                end

                COMPUTE: begin
                    cycle_count <= cycle_count + 32'd1;
                    current_B <= current_A * pow10_d + p;
                    current_N <= q * current_B;
                    next_state <= CHECK;
                end

                CHECK: begin
                    if (current_N >= min_N && current_N <= max_N) begin
                        current_remainder <= (L > 32'd0) ? (current_N % M) : 32'd0;
                        if (current_remainder == current_A) begin
                            if (found == 32'd0 || current_N < solution) begin
                                solution <= current_N;
                                found <= 32'd1;
                            end
                        end
                    end

                    if (current_A < M - 32'd1) begin
                        current_A <= current_A + 32'd1;
                        next_state <= COMPUTE;
                    end else begin
                        next_state <= FINISH;
                    end
                end

                FINISH: begin
                    if (found == 32'd1) begin
                        result <= solution;
                        valid <= 1'b1;
                    end else begin
                        result <= 32'd0;
                        valid <= 1'b0;
                    end
                    done <= 1'b1;
                    next_state <= IDLE;
                end

                default: next_state <= IDLE;
            endcase
        end
    end

endmodule