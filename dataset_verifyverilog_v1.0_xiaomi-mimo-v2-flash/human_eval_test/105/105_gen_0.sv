module DigitProcessor(
    input clk,
    input rst_n,
    input start,
    input signed [7:0] arr [0:15],
    input [3:0] len,
    output reg [63:0] result [0:15],
    output reg done,
    output reg [3:0] result_len
);

// State definitions
localparam [2:0] IDLE      = 3'd0;
localparam [2:0] FILTER    = 3'd1;
localparam [2:0] SORT      = 3'd2;
localparam [2:0] REVERSE   = 3'd3;
localparam [2:0] MAP       = 3'd4;
localparam [2:0] FINISH    = 3'd5;

// Internal registers
reg [2:0] state, next_state;
reg [3:0] filtered_count;
reg [3:0] sort_counter;
reg [3:0] reverse_counter;
reg [3:0] map_counter;
reg [7:0] valid_digits [0:15];  // Filtered array
reg [63:0] mapped_strings [0:15];

// Helper signals
reg [3:0] i, j;
reg signed [7:0] temp_val;
reg [63:0] temp_str;
reg done_reg;
reg [3:0] result_len_reg;

// Initialize all arrays and regs
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        done <= 1'b0;
        result_len <= 4'd0;
        filtered_count <= 4'd0;
        sort_counter <= 4'd0;
        reverse_counter <= 4'd0;
        map_counter <= 4'd0;
        done_reg <= 1'b0;
        result_len_reg <= 4'd0;
        for (i = 0; i < 16; i = i + 1) begin
            valid_digits[i] <= 8'd0;
            mapped_strings[i] <= 64'd0;
            result[i] <= 64'd0;
        end
    end else begin
        state <= next_state;
        done <= done_reg;
        result_len <= result_len_reg;
    end
end

// Main FSM
always @(*) begin
    next_state = state;
    done_reg = 1'b0;
    result_len_reg = result_len;
    
    case (state)
        IDLE: begin
            if (start) begin
                next_state = FILTER;
                result_len_reg = 4'd0;
                done_reg = 1'b0;
            end
        end
        
        FILTER: begin
            // Done after one cycle (combinatorial filter)
            next_state = SORT;
            sort_counter = 4'd0;
        end
        
        SORT: begin
            // Odd-even transposition sort - 15 passes for 16 elements
            if (sort_counter >= 4'd15) begin
                next_state = REVERSE;
                reverse_counter = 4'd0;
            end else begin
                next_state = SORT;
            end
        end
        
        REVERSE: begin
            if (reverse_counter >= filtered_count) begin
                next_state = MAP;
                map_counter = 4'd0;
            end else begin
                next_state = REVERSE;
            end
        end
        
        MAP: begin
            if (map_counter >= filtered_count) begin
                next_state = FINISH;
            end else begin
                next_state = MAP;
            end
        end
        
        FINISH: begin
            done_reg = 1'b1;
            result_len_reg = filtered_count;
            next_state = IDLE;
        end
        
        default: next_state = IDLE;
    endcase
end

// Combinatorial Filter Logic
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        filtered_count <= 4'd0;
        for (i = 0; i < 16; i = i + 1) begin
            valid_digits[i] <= 8'd0;
        end
    end else if (state == IDLE && start) begin
        // Reset filtered array
        filtered_count <= 4'd0;
        for (i = 0; i < 16; i = i + 1) begin
            valid_digits[i] <= 8'd0;
        end
    end else if (state == FILTER) begin
        // Filter: keep only values in [1,9]
        filtered_count <= 4'd0;
        for (i = 0; i < 16; i = i + 1) begin
            if (i < len && arr[i] >= 8'sd1 && arr[i] <= 8'sd9) begin
                valid_digits[filtered_count] <= arr[i];
                filtered_count <= filtered_count + 4'd1;
            end
        end
    end
end

// Sorting Logic (Odd-Even Transposition Sort)
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        sort_counter <= 4'd0;
    end else if (state == SORT) begin
        if (sort_counter < 4'd15) begin
            // Each cycle, do one pass of odd-even sort
            if (sort_counter[0] == 1'b0) begin
                // Even phase: compare pairs (0,1), (2,3), ...
                for (j = 0; j < 15; j = j + 2) begin
                    if (j + 1 < filtered_count && valid_digits[j] > valid_digits[j + 1]) begin
                        valid_digits[j] <= valid_digits[j + 1];
                        valid_digits[j + 1] <= valid_digits[j];
                    end
                end
            end else begin
                // Odd phase: compare pairs (1,2), (3,4), ...
                for (j = 1; j < 15; j = j + 2) begin
                    if (j + 1 < filtered_count && valid_digits[j] > valid_digits[j + 1]) begin
                        valid_digits[j] <= valid_digits[j + 1];
                        valid_digits[j + 1] <= valid_digits[j];
                    end
                end
            end
            sort_counter <= sort_counter + 4'd1;
        end
    end
end

// Reverse Logic
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        reverse_counter <= 4'd0;
    end else if (state == REVERSE) begin
        if (reverse_counter < filtered_count) begin
            // Reverse in place: swap element i with (filtered_count-1-i)
            if (reverse_counter < (filtered_count >> 1)) begin
                valid_digits[reverse_counter] <= valid_digits[filtered_count - 1 - reverse_counter];
                valid_digits[filtered_count - 1 - reverse_counter] <= valid_digits[reverse_counter];
            end
            reverse_counter <= reverse_counter + 4'd1;
        end
    end
end

// Mapping Logic (Digit to ASCII String)
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        map_counter <= 4'd0;
        for (i = 0; i < 16; i = i + 1) begin
            mapped_strings[i] <= 64'd0;
            result[i] <= 64'd0;
        end
    end else if (state == MAP) begin
        if (map_counter < filtered_count) begin
            // Lookup table for digit to string mapping
            case (valid_digits[map_counter])
                8'sd1: mapped_strings[map_counter] <= 64'h4F6E650000000000;  // "One"
                8'sd2: mapped_strings[map_counter] <= 64'h54776F0000000000;  // "Two"
                8'sd3: mapped_strings[map_counter] <= 64'h5468726565000000; // "Three"
                8'sd4: mapped_strings[map_counter] <= 64'h466F757200000000; // "Four"
                8'sd5: mapped_strings[map_counter] <= 64'h4669766500000000; // "Five"
                8'sd6: mapped_strings[map_counter] <= 64'h5369780000000000; // "Six"
                8'sd7: mapped_strings[map_counter] <= 64'h536576656E000000; // "Seven"
                8'sd8: mapped_strings[map_counter] <= 64'h4569676874000000; // "Eight"
                8'sd9: mapped_strings[map_counter] <= 64'h4E696E6500000000; // "Nine"
                default: mapped_strings[map_counter] <= 64'd0;
            endcase
            
            // Copy to output
            result[map_counter] <= mapped_strings[map_counter];
            map_counter <= map_counter + 4'd1;
        end
    end
end

endmodule