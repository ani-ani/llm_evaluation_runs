module max_product_finder (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire signed [7:0] arr_0,
    input wire signed [7:0] arr_1,
    input wire signed [7:0] arr_2,
    input wire signed [7:0] arr_3,
    input wire signed [7:0] arr_4,
    input wire signed [7:0] arr_5,
    input wire signed [7:0] arr_6,
    input wire signed [7:0] arr_7,
    input wire [3:0] len,
    output reg signed [15:0] result_x,
    output reg signed [15:0] result_y,
    output reg done
);

    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] COMPARE = 2'd1;
    localparam [1:0] FINISHED = 2'd2;
    
    reg [1:0] state;
    reg [3:0] i;
    reg [3:0] j;
    reg signed [15:0] best_x;
    reg signed [15:0] best_y;
    reg signed [15:0] best_product;
    reg signed [15:0] current_product;
    
    reg signed [7:0] arr_reg [0:7];
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result_x <= 16'sd0;
            result_y <= 16'sd0;
            i <= 4'd0;
            j <= 4'd0;
            best_x <= 16'sd0;
            best_y <= 16'sd0;
            best_product <= 16'sd0;
            current_product <= 16'sd0;
            arr_reg[0] <= 8'sd0;
            arr_reg[1] <= 8'sd0;
            arr_reg[2] <= 8'sd0;
            arr_reg[3] <= 8'sd0;
            arr_reg[4] <= 8'sd0;
            arr_reg[5] <= 8'sd0;
            arr_reg[6] <= 8'sd0;
            arr_reg[7] <= 8'sd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start && len >= 4'd2) begin
                        arr_reg[0] <= arr_0;
                        arr_reg[1] <= arr_1;
                        arr_reg[2] <= arr_2;
                        arr_reg[3] <= arr_3;
                        arr_reg[4] <= arr_4;
                        arr_reg[5] <= arr_5;
                        arr_reg[6] <= arr_6;
                        arr_reg[7] <= arr_7;
                        best_x <= {8'sd0, arr_0};
                        best_y <= {8'sd0, arr_1};
                        best_product <= arr_0 * arr_1;
                        i <= 4'd0;
                        j <= 4'd1;
                        state <= COMPARE;
                    end
                end
                COMPARE: begin
                    current_product <= arr_reg[i] * arr_reg[j];
                    if (arr_reg[i] * arr_reg[j] > best_product) begin
                        best_x <= {8'sd0, arr_reg[i]};
                        best_y <= {8'sd0, arr_reg[j]};
                        best_product <= arr_reg[i] * arr_reg[j];
                    end
                    if (j < len - 4'd1) begin
                        j <= j + 4'd1;
                    end else begin
                        j <= i + 4'd2;
                        if (i < len - 4'd2) begin
                            i <= i + 4'd1;
                        end else begin
                            state <= FINISHED;
                        end
                    end
                    if (i >= len - 4'd2 && j >= len - 4'd1) begin
                        state <= FINISHED;
                    end
                end
                FINISHED: begin
                    result_x <= best_x;
                    result_y <= best_y;
                    done <= 1'b1;
                    state <= IDLE;
                end
                default: state <= IDLE;
            endcase
        end
    end
endmodule