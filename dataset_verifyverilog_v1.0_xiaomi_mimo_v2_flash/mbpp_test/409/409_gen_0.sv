module min_product_tuple (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] arr_0_x, arr_0_y,
    input wire [7:0] arr_1_x, arr_1_y,
    input wire [7:0] arr_2_x, arr_2_y,
    input wire [7:0] arr_3_x, arr_3_y,
    input wire [2:0] num_pairs,
    output reg [15:0] result,
    output reg done
);

    localparam [1:0] IDLE    = 2'd0;
    localparam [1:0] CALC    = 2'd1;
    localparam [1:0] UPDATE  = 2'd2;
    localparam [1:0] FINISH  = 2'd3;

    reg [1:0] state;
    reg [2:0] index;
    reg [15:0] current_min;
    reg [7:0] curr_x, curr_y;
    reg signed [15:0] product;
    reg [15:0] abs_product;

    always @(*) begin
        case(index)
            3'd0: begin curr_x = arr_0_x; curr_y = arr_0_y; end
            3'd1: begin curr_x = arr_1_x; curr_y = arr_1_y; end
            3'd2: begin curr_x = arr_2_x; curr_y = arr_2_y; end
            3'd3: begin curr_x = arr_3_x; curr_y = arr_3_y; end
            default: begin curr_x = 8'd0; curr_y = 8'd0; end
        endcase
    end

    always @(*) begin
        product = curr_x * curr_y;
        if (product[15]) begin
            abs_product = -product;
        end else begin
            abs_product = product;
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            index <= 3'd0;
            current_min <= 16'hFFFF;
            result <= 16'd0;
            done <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        index <= 3'd0;
                        current_min <= 16'hFFFF;
                        state <= CALC;
                    end
                end

                CALC: begin
                    state <= UPDATE;
                end

                UPDATE: begin
                    if (abs_product < current_min) begin
                        current_min <= abs_product;
                    end
                    if (index + 3'd1 < num_pairs) begin
                        index <= index + 3'd1;
                        state <= CALC;
                    end else begin
                        state <= FINISH;
                    end
                end

                FINISH: begin
                    result <= current_min;
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule