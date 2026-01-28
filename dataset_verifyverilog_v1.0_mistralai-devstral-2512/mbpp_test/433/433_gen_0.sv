module greater_than_all(
    input clk,
    input rst_n,
    input start,
    input [15:0] number,
    input [7:0] arr_0,
    input [7:0] arr_1,
    input [7:0] arr_2,
    input [7:0] arr_3,
    input [7:0] arr_4,
    input [7:0] arr_5,
    input [7:0] arr_6,
    input [7:0] arr_7,
    input valid_in,
    output reg result,
    output reg done
);

    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] COMPARE = 3'd1;
    localparam [2:0] FINISH = 3'd2;

    reg [2:0] state;
    reg [3:0] cycle_count;
    localparam [3:0] MAX_CYCLES = 4'd8;

    reg [7:0] arr_reg [0:7];
    reg [15:0] number_reg;
    reg valid_reg;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 1'b0;
            done <= 1'b0;
            cycle_count <= 4'd0;
            number_reg <= 16'd0;
            valid_reg <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 4'd0;
                    if (start && valid_in) begin
                        state <= COMPARE;
                        number_reg <= number;
                        arr_reg[0] <= arr_0;
                        arr_reg[1] <= arr_1;
                        arr_reg[2] <= arr_2;
                        arr_reg[3] <= arr_3;
                        arr_reg[4] <= arr_4;
                        arr_reg[5] <= arr_5;
                        arr_reg[6] <= arr_6;
                        arr_reg[7] <= arr_7;
                        valid_reg <= 1'b1;
                    end
                end

                COMPARE: begin
                    cycle_count <= cycle_count + 4'd1;
                    if (cycle_count >= MAX_CYCLES || !valid_reg) begin
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

    always @(*) begin
        if (valid_reg) begin
            result = (number_reg > arr_reg[0]) &&
                     (number_reg > arr_reg[1]) &&
                     (number_reg > arr_reg[2]) &&
                     (number_reg > arr_reg[3]) &&
                     (number_reg > arr_reg[4]) &&
                     (number_reg > arr_reg[5]) &&
                     (number_reg > arr_reg[6]) &&
                     (number_reg > arr_reg[7]);
        end else begin
            result = 1'b0;
        end
    end

endmodule