module compute_threshold(
    input clk,
    input rst_n,
    input start,
    input [3:0] a0, a1, a2, a3,
    input [3:0] b0, b1, b2, b3,
    output reg [15:0] result,
    output reg done
);

    // State declarations
    localparam [3:0] IDLE = 4'd0;
    localparam [3:0] S0   = 4'd1;
    localparam [3:0] S1   = 4'd2;
    localparam [3:0] S2   = 4'd3;
    localparam [3:0] S3   = 4'd4;
    localparam [3:0] S4   = 4'd5;
    localparam [3:0] S5   = 4'd6;
    localparam [3:0] S6   = 4'd7;
    localparam [3:0] S7   = 4'd8;
    localparam [3:0] S8   = 4'd9;
    localparam [3:0] S9   = 4'd10;
    localparam [3:0] DONE = 4'd11;

    reg [3:0] state;
    reg [15:0] min_scaled;
    reg [15:0] current_scaled;
    reg [7:0] sum_a;
    reg [7:0] sum_b;
    reg [3:0] first_a, first_b;
    reg valid;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result <= 16'd0;
            min_scaled <= 16'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        min_scaled <= 16'hFFFF;
                        state <= S0;
                    end
                end

                S0: begin
                    // All singletons
                    sum_a <= a0 + a1 + a2 + a3;
                    sum_b <= b0 + b1 + b2 + b3;
                    current_scaled <= (sum_a * 16'd1000 + sum_b - 16'd1) / sum_b;
                    if (current_scaled < min_scaled) begin
                        min_scaled <= current_scaled;
                    end
                    state <= S1;
                end

                S1: begin
                    // Pair (0,1) and singles 2,3
                    valid <= (a0 != a1);
                    if (valid) begin
                        if (a0 > a1) begin
                            first_a <= a0;
                            first_b <= b0;
                        end else begin
                            first_a <= a1;
                            first_b <= b1;
                        end
                        sum_a <= first_a + a2 + a3;
                        sum_b <= first_b + b2 + b3;
                        current_scaled <= (sum_a * 16'd1000 + sum_b - 16'd1) / sum_b;
                        if (current_scaled < min_scaled) begin
                            min_scaled <= current_scaled;
                        end
                    end
                    state <= S2;
                end

                S2: begin
                    // Pair (0,2) and singles 1,3
                    valid <= (a0 != a2);
                    if (valid) begin
                        if (a0 > a2) begin
                            first_a <= a0;
                            first_b <= b0;
                        end else begin
                            first_a <= a2;
                            first_b <= b2;
                        end
                        sum_a <= first_a + a1 + a3;
                        sum_b <= first_b + b1 + b3;
                        current_scaled <= (sum_a * 16'd1000 + sum_b - 16'd1) / sum_b;
                        if (current_scaled < min_scaled) begin
                            min_scaled <= current_scaled;
                        end
                    end
                    state <= S3;
                end

                S3: begin
                    // Pair (0,3) and singles 1,2
                    valid <= (a0 != a3);
                    if (valid) begin
                        if (a0 > a3) begin
                            first_a <= a0;
                            first_b <= b0;
                        end else begin
                            first_a <= a3;
                            first_b <= b3;
                        end
                        sum_a <= first_a + a1 + a2;
                        sum_b <= first_b + b1 + b2;
                        current_scaled <= (sum_a * 16'd1000 + sum_b - 16'd1) / sum_b;
                        if (current_scaled < min_scaled) begin
                            min_scaled <= current_scaled;
                        end
                    end
                    state <= S4;
                end

                S4: begin
                    // Pair (1,2) and singles 0,3
                    valid <= (a1 != a2);
                    if (valid) begin
                        if (a1 > a2) begin
                            first_a <= a1;
                            first_b <= b1;
                        end else begin
                            first_a <= a2;
                            first_b <= b2;
                        end
                        sum_a <= first_a + a0 + a3;
                        sum_b <= first_b + b0 + b3;
                        current_scaled <= (sum_a * 16'd1000 + sum_b - 16'd1) / sum_b;
                        if (current_scaled < min_scaled) begin
                            min_scaled <= current_scaled;
                        end
                    end
                    state <= S5;
                end

                S5: begin
                    // Pair (1,3) and singles 0,2
                    valid <= (a1 != a3);
                    if (valid) begin
                        if (a1 > a3) begin
                            first_a <= a1;
                            first_b <= b1;
                        end else begin
                            first_a <= a3;
                            first_b <= b3;
                        end
                        sum_a <= first_a + a0 + a2;
                        sum_b <= first_b + b0 + b2;
                        current_scaled <= (sum_a * 16'd1000 + sum_b - 16'd1) / sum_b;
                        if (current_scaled < min_scaled) begin
                            min_scaled <= current_scaled;
                        end
                    end
                    state <= S6;
                end

                S6: begin
                    // Pair (2,3) and singles 0,1
                    valid <= (a2 != a3);
                    if (valid) begin
                        if (a2 > a3) begin
                            first_a <= a2;
                            first_b <= b2;
                        end else begin
                            first_a <= a3;
                            first_b <= b3;
                        end
                        sum_a <= first_a + a0 + a1;
                        sum_b <= first_b + b0 + b1;
                        current_scaled <= (sum_a * 16'd1000 + sum_b - 16'd1) / sum_b;
                        if (current_scaled < min_scaled) begin
                            min_scaled <= current_scaled;
                        end
                    end
                    state <= S7;
                end

                S7: begin
                    // Two pairs: (0,1) and (2,3)
                    valid <= (a0 != a1) && (a2 != a3);
                    if (valid) begin
                        if (a0 > a1) begin
                            first_a <= a0;
                            first_b <= b0;
                        end else begin
                            first_a <= a1;
                            first_b <= b1;
                        end
                        sum_a <= first_a;
                        sum_b <= first_b;
                        if (a2 > a3) begin
                            first_a <= a2;
                            first_b <= b2;
                        end else begin
                            first_a <= a3;
                            first_b <= b3;
                        end
                        sum_a <= sum_a + first_a;
                        sum_b <= sum_b + first_b;
                        current_scaled <= (sum_a * 16'd1000 + sum_b - 16'd1) / sum_b;
                        if (current_scaled < min_scaled) begin
                            min_scaled <= current_scaled;
                        end
                    end
                    state <= S8;
                end

                S8: begin
                    // Two pairs: (0,2) and (1,3)
                    valid <= (a0 != a2) && (a1 != a3);
                    if (valid) begin
                        if (a0 > a2) begin
                            first_a <= a0;
                            first_b <= b0;
                        end else begin
                            first_a <= a2;
                            first_b <= b2;
                        end
                        sum_a <= first_a;
                        sum_b <= first_b;
                        if (a1 > a3) begin
                            first_a <= a1;
                            first_b <= b1;
                        end else begin
                            first_a <= a3;
                            first_b <= b3;
                        end
                        sum_a <= sum_a + first_a;
                        sum_b <= sum_b + first_b;
                        current_scaled <= (sum_a * 16'd1000 + sum_b - 16'd1) / sum_b;
                        if (current_scaled < min_scaled) begin
                            min_scaled <= current_scaled;
                        end
                    end
                    state <= S9;
                end

                S9: begin
                    // Two pairs: (0,3) and (1,2)
                    valid <= (a0 != a3) && (a1 != a2);
                    if (valid) begin
                        if (a0 > a3) begin
                            first_a <= a0;
                            first_b <= b0;
                        end else begin
                            first_a <= a3;
                            first_b <= b3;
                        end
                        sum_a <= first_a;
                        sum_b <= first_b;
                        if (a1 > a2) begin
                            first_a <= a1;
                            first_b <= b1;
                        end else begin
                            first_a <= a2;
                            first_b <= b2;
                        end
                        sum_a <= sum_a + first_a;
                        sum_b <= sum_b + first_b;
                        current_scaled <= (sum_a * 16'd1000 + sum_b - 16'd1) / sum_b;
                        if (current_scaled < min_scaled) begin
                            min_scaled <= current_scaled;
                        end
                    end
                    state <= DONE;
                end

                DONE: begin
                    done <= 1'b1;
                    result <= min_scaled;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule