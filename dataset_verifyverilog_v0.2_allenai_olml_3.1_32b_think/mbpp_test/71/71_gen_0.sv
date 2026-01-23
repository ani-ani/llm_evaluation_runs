module comb_sort_seq (
    input clk,
    input rst_n,
    input start,
    input [7:0] data_in_0,
    input [7:0] data_in_1,
    input [7:0] data_in_2,
    input [7:0] data_in_3,
    input [7:0] data_in_4,
    input [7:0] data_in_5,
    input [7:0] data_in_6,
    input [7:0] data_in_7,
    output reg [7:0] sorted_out_0,
    output reg [7:0] sorted_out_1,
    output reg [7:0] sorted_out_2,
    output reg [7:0] sorted_out_3,
    output reg [7:0] sorted_out_4,
    output reg [7:0] sorted_out_5,
    output reg [7:0] sorted_out_6,
    output reg [7:0] sorted_out_7,
    output reg done
);

localparam IDLE = 2'b00;
localparam CALC_GAP = 2'b01;
localparam COMPARE = 2'b10;
localparam DONE_STATE = 2'b11;

reg [1:0] state;
reg [1:0] next_state;
reg [7:0] array [0:7];
reg [3:0] gap;
reg [3:0] i;
reg swapped;
reg processing;

// State machine next state logic
always @(*) begin
    case (state)
        IDLE: begin
            if (start) next_state = CALC_GAP;
            else next_state = IDLE;
        end
        CALC_GAP: begin
            case (gap)
                8: gap <=6;
                6: gap <=4;
                4: gap <=3;
                3: gap <=2;
                2: gap <=1;
                1: gap <=1;
                default: gap <=1;
            endcase
            next_state = COMPARE;
        end
        COMPARE: begin
            if (i >= 8 || (gap > 0 && i + gap >= 8)) begin
                if (gap == 1 && !swapped) begin
                    next_state = DONE_STATE;
                end else begin
                    next_state = CALC_GAP;
                end
            end else begin
                next_state = COMPARE;
            end
        end
        DONE_STATE: next_state = IDLE;
        default: next_state = IDLE;
    endcase
end

// Main logic
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        next_state <= IDLE;
        sorted_out_0 <= 8'b0;
        sorted_out_1 <= 8'b0;
        sorted_out_2 <= 8'b0;
        sorted_out_3 <= 8'b0;
        sorted_out_4 <= 8'b0;
        sorted_out_5 <= 8'b0;
        sorted_out_6 <= 8'b0;
        sorted_out_7 <= 8'b0;
        done <= 1'b0;
        gap <= 4'd0;
        i <= 4'd0;
        swapped <= 1'b0;
        processing <= 1'b0;
        array [0] <= 8'b0;
        array [1] <= 8'b0;
        array [2] <= 8'b0;
        array [3] <= 8'b0;
        array [4] <= 8'b0;
        array [5] <= 8'b0;
        array [6] <= 8'b0;
        array [7] <= 8'b0;
    end else begin
        case (state)
            IDLE: begin
                if (start) begin
                    array[0] <= data_in_0;
                    array[1] <= data_in_1;
                    array[2] <= data_in_2;
                    array[3] <= data_in_3;
                    array[4] <= data_in_4;
                    array[5] <= data_in_5;
                    array[6] <= data_in_6;
                    array[7] <= data_in_7;
                    gap <= 4'd8;
                    swapped <= 1'b0;
                    i <= 4'd0;
                    processing <= 1'b1;
                end
            end
            CALC_GAP: // gap is updated combinatorially, no action here
                ;
            COMPARE: begin
                if (i + gap < 8) begin
                    if (array[i] > array[i + gap]) begin
                        array[i] <= array[i + gap];
                        array[i + gap] <= array[i];
                        swapped <= 1'b1;
                    end
                    i <= i + 1;
                end else begin
                    i <= 4'd0;
                end
            end
            DONE_STATE: begin
                sorted_out_0 <= array[0];
                sorted_out_1 <= array[1];
                sorted_out_2 <= array[2];
                sorted_out_3 <= array[3];
                sorted_out_4 <= array[4];
                sorted_out_5 <= array[5];
                sorted_out_6 <= array[6];
                sorted_out_7 <= array[7];
                done <= 1'b1;
                processing <= 1'b0;
            end
        endcase
    end
end

endmodule