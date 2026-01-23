module chef_dinner_counter (
    input clk,
    input rst_n,
    input start,
    input [5:0] r_num,
    input [3:0] s_num,
    input [3:0] m_num,
    input [3:0] d_num,
    input [3:0] n_num,
    input [6:0] brands [0:15],
    input [7:0] dish_ing_count [0:191],
    input [3:0] incompat_dish1 [0:15],
    input [3:0] incompat_dish2 [0:15],
    output reg [31:0] result,
    output reg done,
    output reg too_many_flag
);

    localparam IDLE = 3'd0,
    CHECK_COMPAT = 3'd1,
    CALC_PRODUCT = 3'd2,
    SUM_UP = 3'd3,
    DONE = 3'd4;

    reg [2:0] state;
    reg [31:0] current_triplet_counter;
    reg [31:0] total_triplets;
    reg [31:0] total_sum;
    reg too_many;
    reg [31:0] result_reg;
    reg done_reg;

    // Reset
    always @(posedge clk) begin
        if (!rst_n) begin
            state <= IDLE;
            current_triplet_counter <= 32'd0;
            total_triplets <= 32'd0;
            total_sum <= 32'd0;
            too_many <= 1'b0;
            result_reg <= 32'd0;
            done_reg <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        total_triplets <= s_num * m_num * d_num;
                        current_triplet_counter <= 32'd0;
                        state <= CHECK_COMPAT;
                    end
                end
                CHECK_COMPAT: begin
                    state <= CALC_PRODUCT;
                end
                CALC_PRODUCT: begin
                    total_sum <= total_sum + 1;
                    too_many <= (total_sum > 32'd1000000);
                    state <= SUM_UP;
                end
                SUM_UP: begin
                    result_reg <= (too_many) ? 32'd0 : total_sum;
                    if (current_triplet_counter == total_triplets - 1) begin
                        state <= DONE;
                        done_reg <= 1'b1;
                    end else begin
                        current_triplet_counter <= current_triplet_counter + 1;
                        state <= CHECK_COMPAT;
                    end
                end
                DONE: begin
                    // Stay in DONE
                end
            endcase
        end
    end

    assign result = result_reg;
    assign done = done_reg;
    assign too_many_flag = too_many;

endmodule