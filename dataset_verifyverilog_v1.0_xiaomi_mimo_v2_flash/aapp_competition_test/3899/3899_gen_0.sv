module compute_threshold(
    input clk,
    input rst_n,
    input start,
    input [3:0] a0,
    input [3:0] a1,
    input [3:0] a2,
    input [3:0] a3,
    input [3:0] b0,
    input [3:0] b1,
    input [3:0] b2,
    input [3:0] b3,
    output reg [15:0] result,
    output reg done
);
    localparam [3:0] IDLE   = 4'd0;
    localparam [3:0] S0     = 4'd1;
    localparam [3:0] S1     = 4'd2;
    localparam [3:0] S2     = 4'd3;
    localparam [3:0] S3     = 4'd4;
    localparam [3:0] S4     = 4'd5;
    localparam [3:0] S5     = 4'd6;
    localparam [3:0] S6     = 4'd7;
    localparam [3:0] S7     = 4'd8;
    localparam [3:0] S8     = 4'd9;
    localparam [3:0] S9     = 4'd10;
    localparam [3:0] DONE   = 4'd11;

    reg [3:0] state;
    reg [3:0] next_state;
    reg [15:0] min_scaled;
    reg [15:0] result_reg;
    
    // Internal calculation registers
    reg [5:0] sum_a;  // max 4*15 = 60, fits in 6 bits
    reg [5:0] sum_b;  // max 4*15 = 60, fits in 6 bits
    reg [31:0] scaled;  // sum_a * 1000 needs up to 16 bits, but we compute with more
    reg [31:0] temp_scaled;
    reg [31:0] temp_div;
    reg skip_partition;

    // State transitions and calculations
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            min_scaled <= 16'd0;
            sum_a <= 6'd0;
            sum_b <= 6'd0;
            temp_scaled <= 32'd0;
            temp_div <= 32'd0;
            scaled <= 32'd0;
            skip_partition <= 1'b0;
            result_reg <= 16'd0;
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
                    sum_a <= {2'b0, a0} + {2'b0, a1} + {2'b0, a2} + {2'b0, a3};
                    sum_b <= {2'b0, b0} + {2'b0, b1} + {2'b0, b2} + {2'b0, b3};
                    skip_partition <= 1'b0;
                    state <= S1;
                end

                S1: begin
                    // Pair (0,1) with singles 2,3
                    if (a0 == a1) begin
                        skip_partition <= 1'b1;
                    end else begin
                        skip_partition <= 1'b0;
                        if (a0 > a1) begin
                            sum_a <= {2'b0, a0} + {2'b0, a2} + {2'b0, a3};
                            sum_b <= {2'b0, b0} + {2'b0, b2} + {2'b0, b3};
                        end else begin
                            sum_a <= {2'b0, a1} + {2'b0, a2} + {2'b0, a3};
                            sum_b <= {2'b0, b1} + {2'b0, b2} + {2'b0, b3};
                        end
                    end
                    state <= S2;
                end

                S2: begin
                    // Pair (0,2) with singles 1,3
                    if (a0 == a2) begin
                        skip_partition <= 1'b1;
                    end else begin
                        skip_partition <= 1'b0;
                        if (a0 > a2) begin
                            sum_a <= {2'b0, a0} + {2'b0, a1} + {2'b0, a3};
                            sum_b <= {2'b0, b0} + {2'b0, b1} + {2'b0, b3};
                        end else begin
                            sum_a <= {2'b0, a2} + {2'b0, a1} + {2'b0, a3};
                            sum_b <= {2'b0, b2} + {2'b0, b1} + {2'b0, b3};
                        end
                    end
                    state <= S3;
                end

                S3: begin
                    // Pair (0,3) with singles 1,2
                    if (a0 == a3) begin
                        skip_partition <= 1'b1;
                    end else begin
                        skip_partition <= 1'b0;
                        if (a0 > a3) begin
                            sum_a <= {2'b0, a0} + {2'b0, a1} + {2'b0, a2};
                            sum_b <= {2'b0, b0} + {2'b0, b1} + {2'b0, b2};
                        end else begin
                            sum_a <= {2'b0, a3} + {2'b0, a1} + {2'b0, a2};
                            sum_b <= {2'b0, b3} + {2'b0, b1} + {2'b0, b2};
                        end
                    end
                    state <= S4;
                end

                S4: begin
                    // Pair (1,2) with singles 0,3
                    if (a1 == a2) begin
                        skip_partition <= 1'b1;
                    end else begin
                        skip_partition <= 1'b0;
                        if (a1 > a2) begin
                            sum_a <= {2'b0, a1} + {2'b0, a0} + {2'b0, a3};
                            sum_b <= {2'b0, b1} + {2'b0, b0} + {2'b0, b3};
                        end else begin
                            sum_a <= {2'b0, a2} + {2'b0, a0} + {2'b0, a3};
                            sum_b <= {2'b0, b2} + {2'b0, b0} + {2'b0, b3};
                        end
                    end
                    state <= S5;
                end

                S5: begin
                    // Pair (1,3) with singles 0,2
                    if (a1 == a3) begin
                        skip_partition <= 1'b1;
                    end else begin
                        skip_partition <= 1'b0;
                        if (a1 > a3) begin
                            sum_a <= {2'b0, a1} + {2'b0, a0} + {2'b0, a2};
                            sum_b <= {2'b0, b1} + {2'b0, b0} + {2'b0, b2};
                        end else begin
                            sum_a <= {2'b0, a3} + {2'b0, a0} + {2'b0, a2};
                            sum_b <= {2'b0, b3} + {2'b0, b0} + {2'b0, b2};
                        end
                    end
                    state <= S6;
                end

                S6: begin
                    // Pair (2,3) with singles 0,1
                    if (a2 == a3) begin
                        skip_partition <= 1'b1;
                    end else begin
                        skip_partition <= 1'b0;
                        if (a2 > a3) begin
                            sum_a <= {2'b0, a2} + {2'b0, a0} + {2'b0, a1};
                            sum_b <= {2'b0, b2} + {2'b0, b0} + {2'b0, b1};
                        end else begin
                            sum_a <= {2'b0, a3} + {2'b0, a0} + {2'b0, a1};
                            sum_b <= {2'b0, b3} + {2'b0, b0} + {2'b0, b1};
                        end
                    end
                    state <= S7;
                end

                S7: begin
                    // Two pairs: (0,1) and (2,3)
                    if (a0 == a1 || a2 == a3) begin
                        skip_partition <= 1'b1;
                    end else begin
                        skip_partition <= 1'b0;
                        if (a0 > a1) begin
                            sum_a <= {2'b0, a0};
                            sum_b <= {2'b0, b0};
                        end else begin
                            sum_a <= {2'b0, a1};
                            sum_b <= {2'b0, b1};
                        end
                        if (a2 > a3) begin
                            sum_a <= sum_a + {2'b0, a2};
                            sum_b <= sum_b + {2'b0, b2};
                        end else begin
                            sum_a <= sum_a + {2'b0, a3};
                            sum_b <= sum_b + {2'b0, b3};
                        end
                    end
                    state <= S8;
                end

                S8: begin
                    // Two pairs: (0,2) and (1,3)
                    if (a0 == a2 || a1 == a3) begin
                        skip_partition <= 1'b1;
                    end else begin
                        skip_partition <= 1'b0;
                        if (a0 > a2) begin
                            sum_a <= {2'b0, a0};
                            sum_b <= {2'b0, b0};
                        end else begin
                            sum_a <= {2'b0, a2};
                            sum_b <= {2'b0, b2};
                        end
                        if (a1 > a3) begin
                            sum_a <= sum_a + {2'b0, a1};
                            sum_b <= sum_b + {2'b0, b1};
                        end else begin
                            sum_a <= sum_a + {2'b0, a3};
                            sum_b <= sum_b + {2'b0, b3};
                        end
                    end
                    state <= S9;
                end

                S9: begin
                    // Two pairs: (0,3) and (1,2)
                    if (a0 == a3 || a1 == a2) begin
                        skip_partition <= 1'b1;
                    end else begin
                        skip_partition <= 1'b0;
                        if (a0 > a3) begin
                            sum_a <= {2'b0, a0};
                            sum_b <= {2'b0, b0};
                        end else begin
                            sum_a <= {2'b0, a3};
                            sum_b <= {2'b0, b3};
                        end
                        if (a1 > a2) begin
                            sum_a <= sum_a + {2'b0, a1};
                            sum_b <= sum_b + {2'b0, b1};
                        end else begin
                            sum_a <= sum_a + {2'b0, a2};
                            sum_b <= sum_b + {2'b0, b2};
                        end
                    end
                    state <= DONE;
                end

                DONE: begin
                    result_reg <= min_scaled;
                    result <= min_scaled;
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

    // Compute scaled = ceil(sum_a * 1000 / sum_b)
    // scaled = (sum_a * 1000 + sum_b - 1) / sum_b
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            scaled <= 32'd0;
            temp_scaled <= 32'd0;
            temp_div <= 32'd0;
        end else begin
            case (state)
                S0: begin
                    if (!skip_partition) begin
                        temp_scaled <= sum_a * 10'd1000;
                        temp_div <= sum_b;
                        if (sum_b != 6'd0) begin
                            scaled <= (sum_a * 10'd1000 + sum_b - 6'd1) / sum_b;
                        end else begin
                            scaled <= 32'hFFFFFFFF;
                        end
                    end
                end
                S1, S2, S3, S4, S5, S6, S7, S8, S9: begin
                    if (!skip_partition) begin
                        temp_scaled <= sum_a * 10'd1000;
                        temp_div <= sum_b;
                        if (sum_b != 6'd0) begin
                            scaled <= (sum_a * 10'd1000 + sum_b - 6'd1) / sum_b;
                        end else begin
                            scaled <= 32'hFFFFFFFF;
                        end
                    end
                end
                default: begin
                    scaled <= scaled;
                    temp_scaled <= temp_scaled;
                    temp_div <= temp_div;
                end
            endcase
        end
    end

    // Update min_scaled
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            min_scaled <= 16'd0;
        end else begin
            if (state == S0 && !skip_partition && scaled < min_scaled) begin
                min_scaled <= scaled[15:0];
            end else if ((state == S1 || state == S2 || state == S3 || state == S4 || state == S5 || state == S6 || state == S7 || state == S8 || state == S9) && !skip_partition && scaled < min_scaled) begin
                min_scaled <= scaled[15:0];
            end
        end
    end

endmodule