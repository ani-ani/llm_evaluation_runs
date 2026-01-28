module max_pair_product(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] pairs [0:7][0:1],
    output reg [15:0] result,
    output reg done
);

    // State declarations
    localparam [3:0] IDLE = 4'd0;
    localparam [3:0] COMPUTE_0 = 4'd1;
    localparam [3:0] COMPUTE_1 = 4'd2;
    localparam [3:0] COMPUTE_2 = 4'd3;
    localparam [3:0] COMPUTE_3 = 4'd4;
    localparam [3:0] COMPUTE_4 = 4'd5;
    localparam [3:0] COMPUTE_5 = 4'd6;
    localparam [3:0] COMPUTE_6 = 4'd7;
    localparam [3:0] COMPUTE_7 = 4'd8;
    localparam [3:0] FINISH = 4'd9;

    reg [3:0] state;
    reg [15:0] current_max;
    reg [15:0] current_product;
    reg [15:0] abs_product;
    reg [3:0] pair_index;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            current_max <= 16'd0;
            current_product <= 16'd0;
            abs_product <= 16'd0;
            pair_index <= 4'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= COMPUTE_0;
                        current_max <= 16'd0;
                        pair_index <= 4'd0;
                    end
                end

                COMPUTE_0: begin
                    current_product <= $signed(pairs[0][0]) * $signed(pairs[0][1]);
                    state <= COMPUTE_1;
                end

                COMPUTE_1: begin
                    abs_product <= (current_product[15]) ? (~current_product + 16'd1) : current_product;
                    state <= COMPUTE_2;
                end

                COMPUTE_2: begin
                    if (abs_product > current_max) begin
                        current_max <= abs_product;
                    end
                    state <= COMPUTE_3;
                end

                COMPUTE_3: begin
                    current_product <= $signed(pairs[1][0]) * $signed(pairs[1][1]);
                    state <= COMPUTE_4;
                end

                COMPUTE_4: begin
                    abs_product <= (current_product[15]) ? (~current_product + 16'd1) : current_product;
                    state <= COMPUTE_5;
                end

                COMPUTE_5: begin
                    if (abs_product > current_max) begin
                        current_max <= abs_product;
                    end
                    state <= COMPUTE_6;
                end

                COMPUTE_6: begin
                    current_product <= $signed(pairs[2][0]) * $signed(pairs[2][1]);
                    state <= COMPUTE_7;
                end

                COMPUTE_7: begin
                    abs_product <= (current_product[15]) ? (~current_product + 16'd1) : current_product;
                    state <= COMPUTE_8;
                end

                COMPUTE_8: begin
                    if (abs_product > current_max) begin
                        current_max <= abs_product;
                    end
                    state <= COMPUTE_9;
                end

                COMPUTE_9: begin
                    current_product <= $signed(pairs[3][0]) * $signed(pairs[3][1]);
                    state <= COMPUTE_10;
                end

                COMPUTE_10: begin
                    abs_product <= (current_product[15]) ? (~current_product + 16'd1) : current_product;
                    state <= COMPUTE_11;
                end

                COMPUTE_11: begin
                    if (abs_product > current_max) begin
                        current_max <= abs_product;
                    end
                    state <= COMPUTE_12;
                end

                COMPUTE_12: begin
                    current_product <= $signed(pairs[4][0]) * $signed(pairs[4][1]);
                    state <= COMPUTE_13;
                end

                COMPUTE_13: begin
                    abs_product <= (current_product[15]) ? (~current_product + 16'd1) : current_product;
                    state <= COMPUTE_14;
                end

                COMPUTE_14: begin
                    if (abs_product > current_max) begin
                        current_max <= abs_product;
                    end
                    state <= COMPUTE_15;
                end

                COMPUTE_15: begin
                    current_product <= $signed(pairs[5][0]) * $signed(pairs[5][1]);
                    state <= COMPUTE_16;
                end

                COMPUTE_16: begin
                    abs_product <= (current_product[15]) ? (~current_product + 16'd1) : current_product;
                    state <= COMPUTE_17;
                end

                COMPUTE_17: begin
                    if (abs_product > current_max) begin
                        current_max <= abs_product;
                    end
                    state <= COMPUTE_18;
                end

                COMPUTE_18: begin
                    current_product <= $signed(pairs[6][0]) * $signed(pairs[6][1]);
                    state <= COMPUTE_19;
                end

                COMPUTE_19: begin
                    abs_product <= (current_product[15]) ? (~current_product + 16'd1) : current_product;
                    state <= COMPUTE_20;
                end

                COMPUTE_20: begin
                    if (abs_product > current_max) begin
                        current_max <= abs_product;
                    end
                    state <= COMPUTE_21;
                end

                COMPUTE_21: begin
                    current_product <= $signed(pairs[7][0]) * $signed(pairs[7][1]);
                    state <= COMPUTE_22;
                end

                COMPUTE_22: begin
                    abs_product <= (current_product[15]) ? (~current_product + 16'd1) : current_product;
                    state <= COMPUTE_23;
                end

                COMPUTE_23: begin
                    if (abs_product > current_max) begin
                        current_max <= abs_product;
                    end
                    state <= FINISH;
                end

                FINISH: begin
                    result <= current_max;
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule