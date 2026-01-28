module frequency_counter (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] arr [0:7],
    input wire [3:0] len,
    output reg done,
    output reg [7:0] result_keys [0:7],
    output reg [7:0] result_counts [0:7],
    output reg [3:0] valid_pairs
);

    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] COUNTING = 3'd1;
    localparam [2:0] FILTERING = 3'd2;
    localparam [2:0] SORTING = 3'd3;
    localparam [2:0] DONE = 3'd4;

    // Registers and state
    reg [2:0] state;
    reg [2:0] next_state;
    reg [3:0] i, j, k;
    reg [7:0] frequency_table [0:7]; // Store counts for values 0-7
    reg [7:0] temp_keys [0:7];
    reg [7:0] temp_counts [0:7];
    reg [3:0] temp_count;
    reg [7:0] temp_key, temp_val;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd200;

    // Internal variables for sorting
    reg swap_flag;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset all registers
            state <= IDLE;
            done <= 1'b0;
            valid_pairs <= 4'd0;
            i <= 4'd0;
            j <= 4'd0;
            k <= 4'd0;
            temp_count <= 4'd0;
            temp_key <= 8'd0;
            temp_val <= 8'd0;
            swap_flag <= 1'b0;
            cycle_count <= 8'd0;
            
            // Initialize arrays
            result_keys[0] <= 8'd0;
            result_keys[1] <= 8'd0;
            result_keys[2] <= 8'd0;
            result_keys[3] <= 8'd0;
            result_keys[4] <= 8'd0;
            result_keys[5] <= 8'd0;
            result_keys[6] <= 8'd0;
            result_keys[7] <= 8'd0;
            result_counts[0] <= 8'd0;
            result_counts[1] <= 8'd0;
            result_counts[2] <= 8'd0;
            result_counts[3] <= 8'd0;
            result_counts[4] <= 8'd0;
            result_counts[5] <= 8'd0;
            result_counts[6] <= 8'd0;
            result_counts[7] <= 8'd0;
            
            frequency_table[0] <= 8'd0;
            frequency_table[1] <= 8'd0;
            frequency_table[2] <= 8'd0;
            frequency_table[3] <= 8'd0;
            frequency_table[4] <= 8'd0;
            frequency_table[5] <= 8'd0;
            frequency_table[6] <= 8'd0;
            frequency_table[7] <= 8'd0;
            
            temp_keys[0] <= 8'd0;
            temp_keys[1] <= 8'd0;
            temp_keys[2] <= 8'd0;
            temp_keys[3] <= 8'd0;
            temp_keys[4] <= 8'd0;
            temp_keys[5] <= 8'd0;
            temp_keys[6] <= 8'd0;
            temp_keys[7] <= 8'd0;
            temp_counts[0] <= 8'd0;
            temp_counts[1] <= 8'd0;
            temp_counts[2] <= 8'd0;
            temp_counts[3] <= 8'd0;
            temp_counts[4] <= 8'd0;
            temp_counts[5] <= 8'd0;
            temp_counts[6] <= 8'd0;
            temp_counts[7] <= 8'd0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        i <= 4'd0;
                        temp_count <= 4'd0;
                        // Clear frequency table
                        frequency_table[0] <= 8'd0;
                        frequency_table[1] <= 8'd0;
                        frequency_table[2] <= 8'd0;
                        frequency_table[3] <= 8'd0;
                        frequency_table[4] <= 8'd0;
                        frequency_table[5] <= 8'd0;
                        frequency_table[6] <= 8'd0;
                        frequency_table[7] <= 8'd0;
                    end
                end
                
                COUNTING: begin
                    cycle_count <= cycle_count + 8'd1;
                    if (i < len && i < 4'd8) begin
                        if (arr[i] < 8'd8) begin
                            // Only count values 0-7
                            case (arr[i])
                                8'd0: frequency_table[0] <= frequency_table[0] + 8'd1;
                                8'd1: frequency_table[1] <= frequency_table[1] + 8'd1;
                                8'd2: frequency_table[2] <= frequency_table[2] + 8'd1;
                                8'd3: frequency_table[3] <= frequency_table[3] + 8'd1;
                                8'd4: frequency_table[4] <= frequency_table[4] + 8'd1;
                                8'd5: frequency_table[5] <= frequency_table[5] + 8'd1;
                                8'd6: frequency_table[6] <= frequency_table[6] + 8'd1;
                                8'd7: frequency_table[7] <= frequency_table[7] + 8'd1;
                            endcase
                        end
                        i <= i + 4'd1;
                    end
                end
                
                FILTERING: begin
                    cycle_count <= cycle_count + 8'd1;
                    if (i < 4'd8) begin
                        if (frequency_table[i] > 8'd0) begin
                            temp_keys[temp_count] <= i;
                            temp_counts[temp_count] <= frequency_table[i];
                            temp_count <= temp_count + 4'd1;
                        end
                        i <= i + 4'd1;
                    end
                end
                
                SORTING: begin
                    cycle_count <= cycle_count + 8'd1;
                    if (temp_count > 4'd1 && j < (temp_count - 4'd1)) begin
                        if (temp_keys[j] > temp_keys[j + 4'd1]) begin
                            // Swap adjacent elements
                            temp_keys[j] <= temp_keys[j + 4'd1];
                            temp_keys[j + 4'd1] <= temp_keys[j];
                            temp_counts[j] <= temp_counts[j + 4'd1];
                            temp_counts[j + 4'd1] <= temp_counts[j];
                        end
                        if (j + 4'd2 >= temp_count) begin
                            j <= 4'd0;
                            k <= k + 4'd1;
                        end else begin
                            j <= j + 4'd1;
                        end
                    end else if (temp_count <= 4'd1) begin
                        j <= 4'd0;
                        k <= 4'd0;
                    end else begin
                        j <= 4'd0;
                        k <= 4'd0;
                    end
                end
                
                DONE: begin
                    done <= 1'b1;
                    valid_pairs <= temp_count;
                    // Copy temp arrays to output arrays
                    result_keys[0] <= temp_keys[0];
                    result_keys[1] <= temp_keys[1];
                    result_keys[2] <= temp_keys[2];
                    result_keys[3] <= temp_keys[3];
                    result_keys[4] <= temp_keys[4];
                    result_keys[5] <= temp_keys[5];
                    result_keys[6] <= temp_keys[6];
                    result_keys[7] <= temp_keys[7];
                    result_counts[0] <= temp_counts[0];
                    result_counts[1] <= temp_counts[1];
                    result_counts[2] <= temp_counts[2];
                    result_counts[3] <= temp_counts[3];
                    result_counts[4] <= temp_counts[4];
                    result_counts[5] <= temp_counts[5];
                    result_counts[6] <= temp_counts[6];
                    result_counts[7] <= temp_counts[7];
                end
                
                default: state <= IDLE;
            endcase
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) next_state = COUNTING;
            end
            COUNTING: begin
                if (i >= len || i >= 4'd8) next_state = FILTERING;
            end
            FILTERING: begin
                if (i >= 4'd8) next_state = SORTING;
            end
            SORTING: begin
                // Bubble sort for up to temp_count-1 passes
                if (k >= temp_count || (temp_count <= 4'd1)) next_state = DONE;
            end
            DONE: begin
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

endmodule