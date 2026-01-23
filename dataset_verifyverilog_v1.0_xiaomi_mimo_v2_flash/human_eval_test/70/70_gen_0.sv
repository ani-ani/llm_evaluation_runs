module strange_sort (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] len,
    input wire [7:0] arr [0:7],
    output reg [7:0] result,
    output reg done
);

    // State definitions
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] SORT = 2'd1;
    localparam [1:0] OUTPUT = 2'd2;
    localparam [1:0] FINISH = 2'd3;

    // Internal registers and variables
    reg [1:0] state, next_state;
    reg [7:0] buffer [0:7];          // Internal buffer for sorted elements
    reg [7:0] temp [0:7];            // Temporary buffer for sorting
    reg [3:0] input_idx;             // Index for reading input array
    reg [3:0] output_idx;            // Index for outputting result
    reg [3:0] sorted_count;          // Number of sorted elements
    reg [3:0] i, j;                  // Loop counters
    reg [7:0] min_val, max_val;      // For min/max selection
    reg [3:0] min_idx, max_idx;      // Indices for min/max
    reg [7:0] cycle_count;           // Cycle counter for bounds
    reg pick_small;                  // Flag to alternate selection
    reg start_d;                     // Delayed start signal
    integer k;                       // Loop variable

    // State transition logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 8'd0;
            done <= 1'b0;
            input_idx <= 4'd0;
            output_idx <= 4'd0;
            sorted_count <= 4'd0;
            cycle_count <= 8'd0;
            pick_small <= 1'b1;
            start_d <= 1'b0;
            // Initialize buffers
            for (k = 0; k < 8; k = k + 1) begin
                buffer[k] <= 8'd0;
                temp[k] <= 8'd0;
            end
        end else begin
            start_d <= start;
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    sorted_count <= 4'd0;
                    output_idx <= 4'd0;
                    pick_small <= 1'b1;
                    // Initialize temp buffer with input
                    if (start && !start_d) begin
                        for (k = 0; k < 8; k = k + 1) begin
                            if (k < len)
                                temp[k] <= arr[k];
                            else
                                temp[k] <= 8'd0;
                        end
                        state <= SORT;
                    end
                end

                SORT: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Simple selection sort for min/max alternation
                    if (sorted_count < len) begin
                        // Find min and max in unsorted portion
                        if (cycle_count == 8'd0) begin
                            min_val <= temp[0];
                            max_val <= temp[0];
                            min_idx <= 4'd0;
                            max_idx <= 4'd0;
                            i <= 4'd1;
                        end else if (cycle_count < len) begin
                            if (i < len) begin
                                if (temp[i] < min_val) begin
                                    min_val <= temp[i];
                                    min_idx <= i;
                                end
                                if (temp[i] > max_val) begin
                                    max_val <= temp[i];
                                    max_idx <= i;
                                end
                                i <= i + 4'd1;
                            end
                        end else if (cycle_count == len) begin
                            // Select min or max based on pick_small flag
                            if (pick_small) begin
                                buffer[sorted_count] <= min_val;
                                // Remove min from temp
                                for (k = min_idx; k < 7; k = k + 1) begin
                                    temp[k] <= temp[k + 1];
                                end
                                temp[7] <= 8'd0;
                            end else begin
                                buffer[sorted_count] <= max_val;
                                // Remove max from temp
                                for (k = max_idx; k < 7; k = k + 1) begin
                                    temp[k] <= temp[k + 1];
                                end
                                temp[7] <= 8'd0;
                            end
                            sorted_count <= sorted_count + 4'd1;
                            pick_small <= !pick_small;
                            cycle_count <= 8'd0;
                        end
                    end else begin
                        state <= OUTPUT;
                    end
                end

                OUTPUT: begin
                    if (output_idx < len) begin
                        result <= buffer[output_idx];
                        output_idx <= output_idx + 4'd1;
                        done <= 1'b1;
                        if (output_idx == len - 4'd1) begin
                            state <= FINISH;
                        end
                    end
                end

                FINISH: begin
                    done <= 1'b0;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule