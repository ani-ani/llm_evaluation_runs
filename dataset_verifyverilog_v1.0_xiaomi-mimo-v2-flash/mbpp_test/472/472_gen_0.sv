module check_consecutive (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] arr [0:7],
    output reg consecutive,
    output reg done
);

// State definitions
localparam [2:0] IDLE = 3'd0;
localparam [2:0] FIND_MIN_MAX = 3'd1;
localparam [2:0] CHECK_DIFF = 3'd2;
localparam [2:0] CHECK_DUPLICATES = 3'd3;
localparam [2:0] CHECK_RANGE = 3'd4;
localparam [2:0] DONE_STATE = 3'd5;

// Registers and wires
reg [2:0] state, next_state;
reg [7:0] min_val, max_val;
reg [7:0] temp_min, temp_max;
reg [7:0] diff_min, diff_max;
reg [7:0] current_element;
reg [7:0] element_to_check;
reg [8:0] diff_calc;
reg [3:0] counter; // For iteration (0-8)
reg [3:0] counter2; // For second iteration (0-8)
reg has_duplicate;
reg all_in_range;
reg [7:0] cycle_count;
localparam [7:0] MAX_CYCLES = 8'd100;

// For duplicate checking
reg duplicate_found;
reg [7:0] check_element;
reg [7:0] compare_element;
reg [3:0] i, j;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        consecutive <= 1'b0;
        done <= 1'b0;
        min_val <= 8'd0;
        max_val <= 8'd0;
        temp_min <= 8'd0;
        temp_max <= 8'd0;
        diff_min <= 8'd0;
        diff_max <= 8'd0;
        current_element <= 8'd0;
        element_to_check <= 8'd0;
        diff_calc <= 9'd0;
        counter <= 4'd0;
        counter2 <= 4'd0;
        has_duplicate <= 1'b0;
        all_in_range <= 1'b0;
        cycle_count <= 8'd0;
        duplicate_found <= 1'b0;
        check_element <= 8'd0;
        compare_element <= 8'd0;
        i <= 4'd0;
        j <= 4'd0;
    end else begin
        case (state)
            IDLE: begin
                consecutive <= 1'b0;
                done <= 1'b0;
                cycle_count <= 8'd0;
                min_val <= arr[0];
                max_val <= arr[0];
                temp_min <= arr[0];
                temp_max <= arr[0];
                counter <= 4'd1; // Start from index 1
                if (start) begin
                    state <= FIND_MIN_MAX;
                end
            end

            FIND_MIN_MAX: begin
                cycle_count <= cycle_count + 8'd1;
                if (counter < 8) begin
                    // Compare current element with temp_min and temp_max
                    if (arr[counter] < temp_min) begin
                        temp_min <= arr[counter];
                    end
                    if (arr[counter] > temp_max) begin
                        temp_max <= arr[counter];
                    end
                    counter <= counter + 4'd1;
                    state <= FIND_MIN_MAX;
                end else begin
                    // Finished finding min and max
                    min_val <= temp_min;
                    max_val <= temp_max;
                    counter <= 4'd0;
                    state <= CHECK_DIFF;
                end
            end

            CHECK_DIFF: begin
                cycle_count <= cycle_count + 8'd1;
                // Calculate max - min
                diff_calc <= {1'b0, max_val} - {1'b0, min_val};
                counter <= 4'd0;
                state <= CHECK_DUPLICATES;
                has_duplicate <= 1'b0;
                duplicate_found <= 1'b0;
                i <= 4'd0;
            end

            CHECK_DUPLICATES: begin
                cycle_count <= cycle_count + 8'd1;
                // Check for duplicates: compare each element with others
                if (i < 8) begin
                    check_element <= arr[i];
                    j <= i + 4'd1; // Start from next element
                    state <= CHECK_DUPLICATES; // Continue with same i
                end else begin
                    // Finished checking all pairs
                    state <= CHECK_RANGE;
                    counter <= 4'd0;
                    all_in_range <= 1'b1;
                end
                
                // Inner loop for duplicate check
                if (i < 8 && j < 8) begin
                    if (arr[i] == arr[j] && i != j) begin
                        has_duplicate <= 1'b1;
                        duplicate_found <= 1'b1;
                    end
                    j <= j + 4'd1;
                end else if (i < 8) begin
                    i <= i + 4'd1;
                end
            end

            CHECK_RANGE: begin
                cycle_count <= cycle_count + 8'd1;
                // Check if all numbers are within [min_val, max_val]
                // This is implicitly true if diff == 7 and no duplicates for 8 elements
                // But we'll verify explicitly
                if (counter < 8) begin
                    if (arr[counter] < min_val || arr[counter] > max_val) begin
                        all_in_range <= 1'b0;
                    end
                    counter <= counter + 4'd1;
                    state <= CHECK_RANGE;
                end else begin
                    state <= DONE_STATE;
                end
            end

            DONE_STATE: begin
                // Final condition check
                if (diff_calc == 9'd7 && !has_duplicate && all_in_range) begin
                    consecutive <= 1'b1;
                end else begin
                    consecutive <= 1'b0;
                end
                done <= 1'b1;
                state <= IDLE;
            end

            default: begin
                state <= IDLE;
            end
        endcase
        
        // Timeout check
        if (cycle_count >= MAX_CYCLES && state != IDLE && state != DONE_STATE) begin
            state <= DONE_STATE;
            consecutive <= 1'b0;
            done <= 1'b1;
        end
    end
end

endmodule