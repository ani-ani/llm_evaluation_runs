module bisect_left(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] arr_0,
    input wire [7:0] arr_1,
    input wire [7:0] arr_2,
    input wire [7:0] arr_3,
    input wire [7:0] arr_4,
    input wire [7:0] arr_5,
    input wire [7:0] arr_6,
    input wire [7:0] arr_7,
    input wire [7:0] len,
    input wire [7:0] x,
    output reg [7:0] result,
    output reg done
);

    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] SEARCH = 2'd1;
    localparam [1:0] FINISH = 2'd2;

    reg [1:0] state;
    reg [7:0] left, right, mid;
    reg [7:0] arr_val;

    always @(*) begin
        case(mid)
            8'd0: arr_val = arr_0;
            8'd1: arr_val = arr_1;
            8'd2: arr_val = arr_2;
            8'd3: arr_val = arr_3;
            8'd4: arr_val = arr_4;
            8'd5: arr_val = arr_5;
            8'd6: arr_val = arr_6;
            8'd7: arr_val = arr_7;
            default: arr_val = 8'd0;
        endcase
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result <= 8'd0;
            left <= 8'd0;
            right <= 8'd0;
            mid <= 8'd0;
        end else begin
            case(state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        left <= 8'd0;
                        right <= len;
                        state <= SEARCH;
                    end
                end

                SEARCH: begin
                    if (left < right) begin
                        mid <= (left + right) >> 1;
                    end else begin
                        result <= left;
                        state <= FINISH;
                    end
                end

                FINISH: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            left <= 8'd0;
            right <= 8'd0;
        end else if (state == SEARCH && left < right) begin
            if (arr_val < x) begin
                left <= mid + 8'd1;
            end else begin
                right <= mid;
            end
        end
    end

endmodule