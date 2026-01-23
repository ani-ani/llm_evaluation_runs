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

// Comb Sort parameters: gap shrink factor 1.3 (fixed-point 13/10)
// For 8 elements: initial gap = 8, gap sequence: 8→6→4→3→2→1
// Maximum iterations bounded by 5 gap cycles + 8 comparisons per cycle
// Complete sort requires approximately 40 clock cycles worst-case

reg [7:0] array [0:7];  // Internal array storage
reg [3:0] gap;          // Current gap value (0-8)
reg [3:0] i;            // Index counter (0-7)
reg swapped;            // Swapped flag
reg processing;         // Processing flag

// State machine states
localparam IDLE = 2'b00;
localparam CALC_GAP = 2'b01;
localparam COMPARE = 2'b10;
localparam DONE = 2'b11;

reg [1:0] state;
reg [1:0] next_state;

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
            if (start) next_state = CALC_GAP;
            else next_state = IDLE;
        end
        CALC_GAP: begin
            if (gap > 1 || swapped) next_state = COMPARE;
            else next_state = DONE;
        end
        COMPARE: begin
            if (i >= 8 || (gap > 0 && i + gap >= 8)) begin
                if (gap <= 1 && !swapped) next_state = DONE;
                else next_state = CALC_GAP;
            end else begin
                next_state = COMPARE;
            end
        end
        DONE: next_state = IDLE;
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
        processing <= 1'b0;
        // Initialize array from inputs
        array[0] <= 8'b0; array[1] <= 8'b0; array[2] <= 8'b0; array[3] <= 8'b0;
        array[4] <= 8'b0; array[5] <= 8'b0; array[6] <= 8'b0; array[7] <= 8'b0;
    end else begin
        case (state)
            IDLE: begin
                if (start) begin
                    // Load input array
                    array[0] <= data_in_0; array[1] <= data_in_1; array[2] <= data_in_2; array[3] <= data_in_3;
                    array[4] <= data_in_4; array[5] <= data_in_5; array[6] <= data_in_6; array[7] <= data_in_7;
                    gap <= 4'd8;
                    swapped <= 1'b0;
                    i <= 4'd0;
                    done <= 1'b0;
                    processing <= 1'b1;
                end
            end
            CALC_GAP: begin
                // Calculate next gap: gap = gap / 1.3 = gap * 10 / 13
                if (gap > 1) begin
                    gap <= (gap * 4'd10) >> 4;  // Divide by 13 (approx 1.3)
                end else begin
                    gap <= 4'd1;
                end
                i <= 4'd0;
                swapped <= swapped;  // Keep previous swapped state
            end
            COMPARE: begin
                if (i + gap < 4'd8) begin
                    // Compare and swap if needed
                    if (array[i] > array[i + gap]) begin
                        array[i] <= array[i + gap];
                        array[i + gap] <= array[i];
                        swapped <= 1'b1;
                    end
                    i <= i + 4'd1;
                end else begin
                    i <= 4'd0;
                end
            end
            DONE: begin
                sorted_out_0 <= array[0]; sorted_out_1 <= array[1]; sorted_out_2 <= array[2]; sorted_out_3 <= array[3];
                sorted_out_4 <= array[4]; sorted_out_5 <= array[5]; sorted_out_6 <= array[6]; sorted_out_7 <= array[7];
                done <= 1'b1;
                processing <= 1'b0;
            end
        endcase
    end
end

endmodule