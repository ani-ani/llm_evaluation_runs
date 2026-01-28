module maximum_k(
    input clk,
    input rst_n,
    input start,
    input [2:0] k,
    input [2:0] arr_len,
    input [15:0] arr [0:7],
    output reg [15:0] result_0,
    output reg [15:0] result_1,
    output reg [15:0] result_2,
    output reg [15:0] result_3,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE       = 3'd0;
    localparam [2:0] FIND_MAX   = 3'd1;
    localparam [2:0] STORE      = 3'd2;
    localparam [2:0] DONE_STATE = 3'd3;
    localparam [2:0] INITIALIZE = 3'd4;

    // Internal registers
    reg [2:0] state;
    reg [2:0] next_state;
    reg [2:0] k_reg;                    // Store k value
    reg [2:0] arr_len_reg;              // Store arr_len value
    reg [2:0] remaining_k;              // How many more elements to find
    reg [2:0] max_index;                // Index of current maximum
    reg [15:0] current_max;             // Value of current maximum
    reg [2:0] compare_idx;              // Index for comparison loop
    reg [2:0] result_pos;               // Position in result array
    reg valid [0:7];                    // Valid flags for each element
    reg [2:0] i;                        // Loop variable
    reg [2:0] cycle_counter;            // Safety counter

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result_0 <= 16'd0;
            result_1 <= 16'd0;
            result_2 <= 16'd0;
            result_3 <= 16'd0;
            done <= 1'b0;
            k_reg <= 3'd0;
            arr_len_reg <= 3'd0;
            remaining_k <= 3'd0;
            max_index <= 3'd0;
            current_max <= 16'd0;
            compare_idx <= 3'd0;
            result_pos <= 3'd0;
            cycle_counter <= 3'd0;
            for (i = 0; i < 8; i = i + 1) begin
                valid[i] <= 1'b0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= INITIALIZE;
                        k_reg <= k;
                        arr_len_reg <= arr_len;
                    end
                end

                INITIALIZE: begin
                    // Initialize valid array and result registers
                    for (i = 0; i < 8; i = i + 1) begin
                        valid[i] <= (i < arr_len_reg) ? 1'b1 : 1'b0;
                    end
                    remaining_k <= k_reg;
                    result_pos <= 3'd0;
                    cycle_counter <= 3'd0;
                    
                    if (k_reg == 3'd0) begin
                        state <= DONE_STATE;
                    end else begin
                        state <= FIND_MAX;
                        compare_idx <= 3'd0;
                        max_index <= 3'd0;
                        // Find first valid element as initial max
                        current_max <= arr[0];
                    end
                end

                FIND_MAX: begin
                    if (cycle_counter >= 3'd7) begin
                        // Safety timeout
                        state <= DONE_STATE;
                    end else if (compare_idx < arr_len_reg) begin
                        // Check if current index is valid
                        if (valid[compare_idx]) begin
                            // Compare with current max
                            if (compare_idx == 3'd0) begin
                                max_index <= compare_idx;
                                current_max <= arr[compare_idx];
                            end else if (arr[compare_idx] > current_max) begin
                                max_index <= compare_idx;
                                current_max <= arr[compare_idx];
                            end
                        end
                        compare_idx <= compare_idx + 3'd1;
                        cycle_counter <= cycle_counter + 3'd1;
                        state <= FIND_MAX;
                    end else begin
                        // Finished comparison for this round
                        state <= STORE;
                    end
                end

                STORE: begin
                    // Mark as used
                    valid[max_index] <= 1'b0;
                    
                    // Store result
                    case (result_pos)
                        3'd0: result_0 <= current_max;
                        3'd1: result_1 <= current_max;
                        3'd2: result_2 <= current_max;
                        3'd3: result_3 <= current_max;
                    endcase
                    
                    remaining_k <= remaining_k - 3'd1;
                    
                    if (remaining_k == 3'd1) begin
                        // All elements found
                        state <= DONE_STATE;
                    end else begin
                        // Continue finding next maximum
                        result_pos <= result_pos + 3'd1;
                        compare_idx <= 3'd0;
                        cycle_counter <= 3'd0;
                        state <= FIND_MAX;
                        // Need to re-find first valid element
                        current_max <= 16'd0; // Reset
                        max_index <= 3'd0;
                    end
                end

                DONE_STATE: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule