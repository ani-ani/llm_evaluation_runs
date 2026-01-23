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

// Internal array storage
reg [7:0] array [0:7];
reg [3:0] gap;
reg [3:0] i;
reg swapped;
reg is_sorted;

// State machine states
localparam IDLE = 3'b000;
localparam LOAD = 3'b001;
localparam CALC_GAP = 3'b010;
localparam SWEEP = 3'b011;
localparam CHECK = 3'b100;
localparam OUTPUT = 3'b105;
localparam DONE_STATE = 3'b110;

reg [2:0] state;
reg [2:0] next_state;

// State transition logic
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
    end else begin
        state <= next_state;
    end
end

// Next state logic
always @(*) begin
    case (state)
        IDLE: begin
            if (start) next_state = LOAD;
            else next_state = IDLE;
        end
        LOAD: begin
            next_state = CALC_GAP;
        end
        CALC_GAP: begin
            next_state = SWEEP;
        end
        SWEEP: begin
            if (i >= 8'd8) next_state = CHECK;
            else next_state = SWEEP;
        end
        CHECK: begin
            if (is_sorted) next_state = OUTPUT;
            else if (gap == 4'd1 && !swapped) next_state = OUTPUT;
            else next_state = CALC_GAP;
        end
        OUTPUT: begin
            next_state = DONE_STATE;
        end
        DONE_STATE: begin
            next_state = IDLE;
        end
        default: next_state = IDLE;
    endcase
end

// Main processing logic
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        sorted_out_0 <= 8'b0; sorted_out_1 <= 8'b0; sorted_out_2 <= 8'b0; sorted_out_3 <= 8'b0;
        sorted_out_4 <= 8'b0; sorted_out_5 <= 8'b0; sorted_out_6 <= 8'b0; sorted_out_7 <= 8'b0;
        done <= 1'b0;
        gap <= 4'd8;
        i <= 4'd0;
        swapped <= 1'b0;
        is_sorted <= 1'b0;
    end else begin
        case (state)
            IDLE: begin
                done <= 1'b0;
            end
            LOAD: begin
                // Load input array
                array[0] <= data_in_0; array[1] <= data_in_1; array[2] <= data_in_2; array[3] <= data_in_3;
                array[4] <= data_in_4; array[5] <= data_in_5; array[6] <= data_in_6; array[7] <= data_in_7;
                gap <= 4'd8;
                swapped <= 1'b0;
                is_sorted <= 1'b0;
            end
            CALC_GAP: begin
                // Calculate gap: gap = ceil(gap / 1.3)
                // Using approximation: gap = (gap * 10) / 13
                if (gap > 1) begin
                    case (gap)
                        4'd8: gap <= 4'd6;
                        4'd7: gap <= 4'd5;
                        4'd6: gap <= 4'd5;
                        4'd5: gap <= 4'd4;
                        4'd4: gap <= 4'd3;
                        4'd3: gap <= 4'd2;
                        4'd2: gap <= 4'd2;
                        default: gap <= 4'd1;
                    endcase
                end else begin
                    gap <= 4'd1;
                end
                i <= 4'd0;
                swapped <= 1'b0;
            end
            SWEEP: begin
                if (i + gap < 4'd8) begin
                    // Compare and swap if needed
                    if (array[i] > array[i + gap]) begin
                        array[i] <= array[i + gap];
                        array[i + gap] <= array[i];
                        swapped <= 1'b1;
                    end
                    i <= i + 4'd1;
                end else begin
                    i <= 4'd8; // Mark sweep complete
                end
            end
            CHECK: begin
                // Check if sorted (bubble sort pass with gap=1 completed without swaps)
                if (gap == 4'd1 && !swapped) begin
                    is_sorted <= 1'b1;
                end else begin
                    is_sorted <= 1'b0;
                end
            end
            OUTPUT: begin
                sorted_out_0 <= array[0]; sorted_out_1 <= array[1]; sorted_out_2 <= array[2]; sorted_out_3 <= array[3];
                sorted_out_4 <= array[4]; sorted_out_5 <= array[5]; sorted_out_6 <= array[6]; sorted_out_7 <= array[7];
            end
            DONE_STATE: begin
                done <= 1'b1;
            end
        endcase
    end
end

endmodule

module comb_sort_comb (
    input [7:0] in_0,
    input [7:0] in_1,
    input [7:0] in_2,
    input [7:0] in_3,
    input [7:0] in_4,
    input [7:0] in_5,
    input [7:0] in_6,
    input [7:0] in_7,
    output [7:0] out_0,
    output [7:0] out_1,
    output [7:0] out_2,
    output [7:0] out_3,
    output [7:0] out_4,
    output [7:0] out_5,
    output [7:0] out_6,
    output [7:0] out_7
);

// Fully unrolled Comb Sort for 8 elements using gap sequence: 8, 6, 4, 3, 2, 1
// Each gap phase is unrolled as combinational swaps

wire [7:0] s0 [0:7];
wire [7:0] s1 [0:7];
wire [7:0] s2 [0:7];
wire [7:0] s3 [0:7];
wire [7:0] s4 [0:7];
wire [7:0] s5 [0:7];
wire [7:0] s6 [0:7];
wire [7:0] s7 [0:7];
wire [7:0] s8 [0:7];
wire [7:0] s9 [0:7];
wire [7:0] s10[0:7];
wire [7:0] s11[0:7];
wire [7:0] s12[0:7];
wire [7:0] s13[0:7];

// Initial state
assign s0[0] = in_0; assign s0[1] = in_1; assign s0[2] = in_2; assign s0[3] = in_3;
assign s0[4] = in_4; assign s0[5] = in_5; assign s0[6] = in_6; assign s0[7] = in_7;

// Gap 8: no comparisons (i=0, gap=8, i+8=8 >= 8)
assign s1[0] = s0[0]; assign s1[1] = s0[1]; assign s1[2] = s0[2]; assign s1[3] = s0[3];
assign s1[4] = s0[4]; assign s1[5] = s0[5]; assign s1[6] = s0[6]; assign s1[7] = s0[7];

// Gap 6: comparison (0,6), (1,7)
assign s2[0] = (s1[0] > s1[6]) ? s1[6] : s1[0];
assign s2[6] = (s1[0] > s1[6]) ? s1[0] : s1[6];
assign s2[1] = (s1[1] > s1[7]) ? s1[7] : s1[1];
assign s2[7] = (s1[1] > s1[7]) ? s1[1] : s1[7];
assign s2[2] = s1[2]; assign s2[3] = s1[3]; assign s2[4] = s1[4]; assign s2[5] = s1[5];

// Gap 4: comparisons (0,4), (1,5), (2,6), (3,7)
assign s3[0] = (s2[0] > s2[4]) ? s2[4] : s2[0];
assign s3[4] = (s2[0] > s2[4]) ? s2[0] : s2[4];
assign s3[1] = (s2[1] > s2[5]) ? s2[5] : s2[1];
assign s3[5] = (s2[1] > s2[5]) ? s2[1] : s2[5];
assign s3[2] = (s2[2] > s2[6]) ? s2[6] : s2[2];
assign s3[6] = (s2[2] > s2[6]) ? s2[2] : s2[6];
assign s3[3] = (s2[3] > s2[7]) ? s2[7] : s2[3];
assign s3[7] = (s2[3] > s2[7]) ? s2[3] : s2[7];

// Gap 3: comparisons (0,3), (1,4), (2,5), (3,6), (4,7)
assign s4[0] = (s3[0] > s3[3]) ? s3[3] : s3[0];
assign s4[3] = (s3[0] > s3[3]) ? s3[0] : s3[3];
assign s4[1] = (s3[1] > s3[4]) ? s3[4] : s3[1];
assign s4[4] = (s3[1] > s3[4]) ? s3[1] : s3[4];
assign s4[2] = (s3[2] > s3[5]) ? s3[5] : s3[2];
assign s4[5] = (s3[2] > s3[5]) ? s3[2] : s3[5];
assign s4[3] = (s4[3] > s3[6]) ? s3[6] : s4[3];
assign s4[6] = (s4[3] > s3[6]) ? s4[3] : s3[6];
assign s4[4] = (s4[4] > s3[7]) ? s3[7] : s4[4];
assign s4[7] = (s4[4] > s3[7]) ? s4[4] : s3[7];

// Gap 2: comparisons (0,2), (1,3), (2,4), (3,5), (4,6), (5,7)
assign s5[0] = (s4[0] > s4[2]) ? s4[2] : s4[0];
assign s5[2] = (s4[0] > s4[2]) ? s4[0] : s4[2];
assign s5[1] = (s4[1] > s4[3]) ? s4[3] : s4[1];
assign s5[3] = (s4[1] > s4[3]) ? s4[1] : s4[3];
assign s5[2] = (s5[2] > s4[4]) ? s4[4] : s5[2];
assign s5[4] = (s5[2] > s4[4]) ? s5[2] : s4[4];
assign s5[3] = (s5[3] > s4[5]) ? s4[5] : s5[3];
assign s5[5] = (s5[3] > s4[5]) ? s5[3] : s4[5];
assign s5[4] = (s5[4] > s4[6]) ? s4[6] : s5[4];
assign s5[6] = (s5[4] > s4[6]) ? s5[4] : s4[6];
assign s5[5] = (s5[5] > s4[7]) ? s4[7] : s5[5];
assign s5[7] = (s5[5] > s4[7]) ? s5[5] : s4[7];

// Gap 1: bubble sort pass 1
assign s6[0] = (s5[0] > s5[1]) ? s5[1] : s5[0];
assign s6[1] = (s5[0] > s5[1]) ? s5[0] : s5[1];
assign s6[1] = (s6[1] > s5[2]) ? s5[2] : s6[1];
assign s6[2] = (s6[1] > s5[2]) ? s6[1] : s5[2];
assign s6[2] = (s6[2] > s5[3]) ? s5[3] : s6[2];
assign s6[3] = (s6[2] > s5[3]) ? s6[2] : s5[3];
assign s6[3] = (s6[3] > s5[4]) ? s5[4] : s6[3];
assign s6[4] = (s6[3] > s5[4]) ? s6[3] : s5[4];
assign s6[4] = (s6[4] > s5[5]) ? s5[5] : s6[4];
assign s6[5] = (s6[4] > s5[5]) ? s6[4] : s5[5];
assign s6[5] = (s6[5] > s5[6]) ? s5[6] : s6[5];
assign s6[6] = (s6[5] > s5[6]) ? s6[5] : s5[6];
assign s6[6] = (s6[6] > s5[7]) ? s5[7] : s6[6];
assign s6[7] = (s6[6] > s5[7]) ? s6[6] : s5[7];

// Gap 1: bubble sort pass 2
assign s7[0] = (s6[0] > s6[1]) ? s6[1] : s6[0];
assign s7[1] = (s6[0] > s6[1]) ? s6[0] : s6[1];
assign s7[1] = (s7[1] > s6[2]) ? s6[2] : s7[1];
assign s7[2] = (s7[1] > s6[2]) ? s7[1] : s6[2];
assign s7[2] = (s7[2] > s6[3]) ? s6[3] : s7[2];
assign s7[3] = (s7[2] > s6[3]) ? s7[2] : s6[3];
assign s7[3] = (s7[3] > s6[4]) ? s6[4] : s7[3];
assign s7[4] = (s7[3] > s6[4]) ? s7[3] : s6[4];
assign s7[4] = (s7[4] > s6[5]) ? s6[5] : s7[4];
assign s7[5] = (s7[4] > s6[5]) ? s7[4] : s6[5];
assign s7[5] = (s7[5] > s6[6]) ? s6[6] : s7[5];
assign s7[6] = (s7[5] > s6[6]) ? s7[5] : s6[6];
assign s7[6] = (s7[6] > s6[7]) ? s6[7] : s7[6];
assign s7[7] = (s7[6] > s6[7]) ? s7[6] : s6[7];

// Gap 1: bubble sort pass 3
assign s8[0] = (s7[0] > s7[1]) ? s7[1] : s7[0];
assign s8[1] = (s7[0] > s7[1]) ? s7[0] : s7[1];
assign s8[1] = (s8[1] > s7[2]) ? s7[2] : s8[1];
assign s8[2] = (s8[1] > s7[2]) ? s8[1] : s7[2];
assign s8[2] = (s8[2] > s7[3]) ? s7[3] : s8[2];
assign s8[3] = (s8[2] > s7[3]) ? s8[2] : s7[3];
assign s8[3] = (s8[3] > s7[4]) ? s7[4] : s8[3];
assign s8[4] = (s8[3] > s7[4]) ? s8[3] : s7[4];
assign s8[4] = (s8[4] > s7[5]) ? s7[5] : s8[4];
assign s8[5] = (s8[4] > s7[5]) ? s8[4] : s7[5];
assign s8[5] = (s8[5] > s7[6]) ? s7[6] : s8[5];
assign s8[6] = (s8[5] > s7[6]) ? s8[5] : s7[6];
assign s8[6] = (s8[6] > s7[7]) ? s7[7] : s8[6];
assign s8[7] = (s8[6] > s7[7]) ? s8[6] : s7[7];

// Gap 1: bubble sort pass 4
assign s9[0] = (s8[0] > s8[1]) ? s8[1] : s8[0];
assign s9[1] = (s8[0] > s8[1]) ? s8[0] : s8[1];
assign s9[1] = (s9[1] > s8[2]) ? s8[2] : s9[1];
assign s9[2] = (s9[1] > s8[2]) ? s9[1] : s8[2];
assign s9[2] = (s9[2] > s8[3]) ? s8[3] : s9[2];
assign s9[3] = (s9[2] > s8[3]) ? s9[2] : s8[3];
assign s9[3] = (s9[3] > s8[4]) ? s8[4] : s9[3];
assign s9[4] = (s9[3] > s8[4]) ? s9[3] : s8[4];
assign s9[4] = (s9[4] > s8[5]) ? s8[5] : s9[4];
assign s9[5] = (s9[4] > s8[5]) ? s9[4] : s8[5];
assign s9[5] = (s9[5] > s8[6]) ? s8[6] : s9[5];
assign s9[6] = (s9[5] > s8[6]) ? s9[5] : s8[6];
assign s9[6] = (s9[6] > s8[7]) ? s8[7] : s9[6];
assign s9[7] = (s9[6] > s8[7]) ? s9[6] : s8[7];

// Gap 1: bubble sort pass 5
assign s10[0] = (s9[0] > s9[1]) ? s9[1] : s9[0];
assign s10[1] = (s9[0] > s9[1]) ? s9[0] : s9[1];
assign s10[1] = (s10[1] > s9[2]) ? s9[2] : s10[1];
assign s10[2] = (s10[1] > s9[2]) ? s10[1] : s9[2];
assign s10[2] = (s10[2] > s9[3]) ? s9[3] : s10[2];
assign s10[3] = (s10[2] > s9[3]) ? s10[2] : s9[3];
assign s10[3] = (s10[3] > s9[4]) ? s9[4] : s10[3];
assign s10[4] = (s10[3] > s9[4]) ? s10[3] : s9[4];
assign s10[4] = (s10[4] > s9[5]) ? s9[5] : s10[4];
assign s10[5] = (s10[4] > s9[5]) ? s10[4] : s9[5];
assign s10[5] = (s10[5] > s9[6]) ? s9[6] : s10[5];
assign s10[6] = (s10[5] > s9[6]) ? s10[5] : s9[6];
assign s10[6] = (s10[6] > s9[7]) ? s9[7] : s10[6];
assign s10[7] = (s10[6] > s9[7]) ? s10[6] : s9[7];

// Gap 1: bubble sort pass 6
assign s11[0] = (s10[0] > s10[1]) ? s10[1] : s10[0];
assign s11[1] = (s10[0] > s10[1]) ? s10[0] : s10[1];
assign s11[1] = (s11[1] > s10[2]) ? s10[2] : s11[1];
assign s11[2] = (s11[1] > s10[2]) ? s11[1] : s10[2];
assign s11[2] = (s11[2] > s10[3]) ? s10[3] : s11[2];
assign s11[3] = (s11[2] > s10[3]) ? s11[2] : s10[3];
assign s11[3] = (s11[3] > s10[4]) ? s10[4] : s11[3];
assign s11[4] = (s11[3] > s10[4]) ? s11[3] : s10[4];
assign s11[4] = (s11[4] > s10[5]) ? s10[5] : s11[4];
assign s11[5] = (s11[4] > s10[5]) ? s11[4] : s10[5];
assign s11[5] = (s11[5] > s10[6]) ? s10[6] : s11[5];
assign s11[6] = (s11[5] > s10[6]) ? s11[5] : s10[6];
assign s11[6] = (s11[6] > s10[7]) ? s10[7] : s11[6];
assign s11[7] = (s11[6] > s10[7]) ? s11[6] : s10[7];

// Gap 1: bubble sort pass 7
assign s12[0] = (s11[0] > s11[1]) ? s11[1] : s11[0];
assign s12[1] = (s11[0] > s11[1]) ? s11[0] : s11[1];
assign s12[1] = (s12[1] > s11[2]) ? s11[2] : s12[1];
assign s12[2] = (s12[1] > s11[2]) ? s12[1] : s11[2];
assign s12[2] = (s12[2] > s11[3]) ? s11[3] : s12[2];
assign s12[3] = (s12[2] > s11[3]) ? s12[2] : s11[3];
assign s12[3] = (s12[3] > s11[4]) ? s11[4] : s12[3];
assign s12[4] = (s12[3] > s11[4]) ? s12[3] : s11[4];
assign s12[4] = (s12[4] > s11[5]) ? s11[5] : s12[4];
assign s12[5] = (s12[4] > s11[5]) ? s12[4] : s11[5];
assign s12[5] = (s12[5] > s11[6]) ? s11[6] : s12[5];
assign s12[6] = (s12[5] > s11[6]) ? s12[5] : s11[6];
assign s12[6] = (s12[6] > s11[7]) ? s11[7] : s12[6];
assign s12[7] = (s12[6] > s11[7]) ? s12[6] : s11[7];

// Gap 1: bubble sort pass 8 (final pass to ensure sorted)
assign s13[0] = (s12[0] > s12[1]) ? s12[1] : s12[0];
assign s13[1] = (s12[0] > s12[1]) ? s12[0] : s12[1];
assign s13[1] = (s13[1] > s12[2]) ? s12[2] : s13[1];
assign s13[2] = (s13[1] > s12[2]) ? s13[1] : s12[2];
assign s13[2] = (s13[2] > s12[3]) ? s12[3] : s13[2];
assign s13[3] = (s13[2] > s12[3]) ? s13[2] : s12[3];
assign s13[3] = (s13[3] > s12[4]) ? s12[4] : s13[3];
assign s13[4] = (s13[3] > s12[4]) ? s13[3] : s12[4];
assign s13[4] = (s13[4] > s12[5]) ? s12[5] : s13[4];
assign s13[5] = (s13[4] > s12[5]) ? s13[4] : s12[5];
assign s13[5] = (s13[5] > s12[6]) ? s12[6] : s13[5];
assign s13[6] = (s13[5] > s12[6]) ? s13[5] : s12[6];
assign s13[6] = (s13[6] > s12[7]) ? s12[7] : s13[6];
assign s13[7] = (s13[6] > s12[7]) ? s13[6] : s12[7];

// Output assignments
assign out_0 = s13[0];
assign out_1 = s13[1];
assign out_2 = s13[2];
assign out_3 = s13[3];
assign out_4 = s13[4];
assign out_5 = s13[5];
assign out_6 = s13[6];
assign out_7 = s13[7];

endmodule