module sweet_diet (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [2:0] m,
    input wire [3:0] k,
    input wire [7:0] a_0, a_1, a_2, a_3,
    input wire [3:0] b_0, b_1, b_2, b_3, b_4, b_5, b_6, b_7,
    output reg [7:0] result,
    output reg done,
    output reg error
);

    // State definitions
    localparam [2:0] IDLE    = 3'd0;
    localparam [2:0] INIT    = 3'd1;
    localparam [2:0] CHECK   = 3'd2;
    localparam [2:0] ADD     = 3'd3;
    localparam [2:0] FINISH  = 3'd4;
    localparam [2:0] FOREVER = 3'd5;

    // Constants
    localparam [7:0] MAX_ITER = 8'd50;
    localparam [7:0] FOREVER_CODE = 8'd255;

    // Internal registers
    reg [2:0] state;
    reg [7:0] s [0:3];
    reg [7:0] n;
    reg [7:0] sum_a;
    reg [7:0] iteration;
    reg [7:0] temp_result;
    reg [7:0] a_idx_val;
    reg [15:0] left_bound;
    reg [15:0] right_bound;
    reg [15:0] mid_val;
    reg can_add;
    reg [2:0] type_idx;
    reg [2:0] i;
    reg [3:0] k_temp;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 8'd0;
            done <= 1'b0;
            error <= 1'b0;
            n <= 8'd0;
            sum_a <= 8'd0;
            iteration <= 8'd0;
            temp_result <= 8'd0;
            s[0] <= 8'd0;
            s[1] <= 8'd0;
            s[2] <= 8'd0;
            s[3] <= 8'd0;
            can_add <= 1'b0;
            type_idx <= 3'd0;
            a_idx_val <= 8'd0;
            left_bound <= 16'd0;
            right_bound <= 16'd0;
            mid_val <= 16'd0;
            k_temp <= 4'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    error <= 1'b0;
                    if (start) begin
                        state <= INIT;
                        iteration <= 8'd0;
                        // Compute sum_a
                        sum_a <= a_0 + a_1 + a_2 + a_3;
                    end
                end

                INIT: begin
                    // Initialize arrays
                    s[0] <= 8'd0;
                    s[1] <= 8'd0;
                    s[2] <= 8'd0;
                    s[3] <= 8'd0;
                    n <= 8'd0;
                    k_temp <= k;
                    // Count from b sequence
                    if (k > 0) begin
                        if (b_0 >= 1 && b_0 <= m) begin
                            case (b_0)
                                1: s[0] <= s[0] + 1;
                                2: s[1] <= s[1] + 1;
                                3: s[2] <= s[2] + 1;
                                4: s[3] <= s[3] + 1;
                            endcase
                        end
                    end
                    if (k > 1) begin
                        if (b_1 >= 1 && b_1 <= m) begin
                            case (b_1)
                                1: s[0] <= s[0] + 1;
                                2: s[1] <= s[1] + 1;
                                3: s[2] <= s[2] + 1;
                                4: s[3] <= s[3] + 1;
                            endcase
                        end
                    end
                    if (k > 2) begin
                        if (b_2 >= 1 && b_2 <= m) begin
                            case (b_2)
                                1: s[0] <= s[0] + 1;
                                2: s[1] <= s[1] + 1;
                                3: s[2] <= s[2] + 1;
                                4: s[3] <= s[3] + 1;
                            endcase
                        end
                    end
                    if (k > 3) begin
                        if (b_3 >= 1 && b_3 <= m) begin
                            case (b_3)
                                1: s[0] <= s[0] + 1;
                                2: s[1] <= s[1] + 1;
                                3: s[2] <= s[2] + 1;
                                4: s[3] <= s[3] + 1;
                            endcase
                        end
                    end
                    if (k > 4) begin
                        if (b_4 >= 1 && b_4 <= m) begin
                            case (b_4)
                                1: s[0] <= s[0] + 1;
                                2: s[1] <= s[1] + 1;
                                3: s[2] <= s[2] + 1;
                                4: s[3] <= s[3] + 1;
                            endcase
                        end
                    end
                    if (k > 5) begin
                        if (b_5 >= 1 && b_5 <= m) begin
                            case (b_5)
                                1: s[0] <= s[0] + 1;
                                2: s[1] <= s[1] + 1;
                                3: s[2] <= s[2] + 1;
                                4: s[3] <= s[3] + 1;
                            endcase
                        end
                    end
                    if (k > 6) begin
                        if (b_6 >= 1 && b_6 <= m) begin
                            case (b_6)
                                1: s[0] <= s[0] + 1;
                                2: s[1] <= s[1] + 1;
                                3: s[2] <= s[2] + 1;
                                4: s[3] <= s[3] + 1;
                            endcase
                        end
                    end
                    if (k > 7) begin
                        if (b_7 >= 1 && b_7 <= m) begin
                            case (b_7)
                                1: s[0] <= s[0] + 1;
                                2: s[1] <= s[1] + 1;
                                3: s[2] <= s[2] + 1;
                                4: s[3] <= s[3] + 1;
                            endcase
                        end
                    end
                    n <= k;
                    i <= 3'd0;
                    state <= CHECK;
                end

                CHECK: begin
                    can_add <= 1'b0;
                    type_idx <= 3'd0;
                    i <= 3'd0;
                    if (iteration >= MAX_ITER) begin
                        temp_result <= FOREVER_CODE;
                        state <= FOREVER;
                    end else begin
                        state <= ADD;
                    end
                end

                ADD: begin
                    if (i < m) begin
                        case (i)
                            0: a_idx_val <= a_0;
                            1: a_idx_val <= a_1;
                            2: a_idx_val <= a_2;
                            3: a_idx_val <= a_3;
                        endcase
                        // Check if we can add this type
                        left_bound <= (n * a_idx_val) - sum_a;
                        right_bound <= (n * a_idx_val) + sum_a;
                        mid_val <= (s[i] + 1) * sum_a;
                        i <= i + 1;
                        // Check condition in next cycle
                        if (!can_add && mid_val > ((n * a_idx_val) - sum_a) && mid_val < ((n * a_idx_val) + sum_a)) begin
                            can_add <= 1'b1;
                            type_idx <= i;
                        end
                    end else begin
                        if (can_add) begin
                            // Add sweet
                            case (type_idx)
                                0: s[0] <= s[0] + 1;
                                1: s[1] <= s[1] + 1;
                                2: s[2] <= s[2] + 1;
                                3: s[3] <= s[3] + 1;
                            endcase
                            n <= n + 1;
                            iteration <= iteration + 1;
                            state <= CHECK;
                        end else begin
                            temp_result <= iteration;
                            state <= FINISH;
                        end
                    end
                end

                FINISH: begin
                    result <= temp_result;
                    done <= 1'b1;
                    state <= IDLE;
                end

                FOREVER: begin
                    result <= FOREVER_CODE;
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule