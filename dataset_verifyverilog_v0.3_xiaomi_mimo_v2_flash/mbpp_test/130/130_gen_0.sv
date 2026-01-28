module max_frequency (
    input clk,
    input rst_n,
    input start,
    input [7:0] arr_0,
    input [7:0] arr_1,
    input [7:0] arr_2,
    input [7:0] arr_3,
    input [7:0] arr_4,
    input [7:0] arr_5,
    input [7:0] arr_6,
    input [7:0] arr_7,
    input [7:0] arr_8,
    input [7:0] arr_9,
    input [7:0] arr_10,
    input [7:0] arr_11,
    input [7:0] arr_12,
    input [7:0] arr_13,
    input [7:0] arr_14,
    input [7:0] arr_15,
    input [7:0] arr_16,
    input [7:0] arr_17,
    input [7:0] arr_18,
    input [7:0] arr_19,
    input [7:0] arr_20,
    output reg [7:0] result,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] STORE = 3'd1;
    localparam [2:0] COUNT = 3'd2;
    localparam [2:0] FIND_MAX = 3'd3;
    localparam [2:0] FINISH = 3'd4;

    // Constants
    localparam [7:0] INPUT_SIZE = 8'd21;
    localparam [7:0] MAX_VAL = 8'd255;
    localparam [7:0] MAX_CYCLES = 8'd200;

    // Registers
    reg [2:0] state, next_state;
    reg [7:0] idx;              // Index for input array
    reg [7:0] freq_idx;         // Index for frequency lookup
    reg [7:0] max_freq;         // Maximum frequency found so far
    reg [7:0] max_val;          // Value with maximum frequency
    reg [7:0] cycle_count;      // Prevent infinite loops
    reg [7:0] i;                // General purpose index
    reg [7:0] temp_val;         // Temporary storage for current value

    // Frequency lookup table (256 entries)
    reg [7:0] freq_table [0:255];

    // Input array storage
    reg [7:0] stored_arr [0:20];

    // Next state logic
    always @(state, start, idx, freq_idx) begin
        case (state)
            IDLE: begin
                if (start)
                    next_state = STORE;
                else
                    next_state = IDLE;
            end
            STORE: begin
                if (idx >= INPUT_SIZE)
                    next_state = COUNT;
                else
                    next_state = STORE;
            end
            COUNT: begin
                if (idx >= INPUT_SIZE)
                    next_state = FIND_MAX;
                else
                    next_state = COUNT;
            end
            FIND_MAX: begin
                if (freq_idx > MAX_VAL)
                    next_state = FINISH;
                else
                    next_state = FIND_MAX;
            end
            FINISH: begin
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            idx <= 8'd0;
            freq_idx <= 8'd0;
            max_freq <= 8'd0;
            max_val <= 8'd0;
            result <= 8'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            i <= 8'd0;
            temp_val <= 8'd0;
            // Initialize freq_table
            for (i = 0; i < 8'd256; i = i + 1) begin
                freq_table[i] <= 8'd0;
            end
        end else begin
            state <= next_state;
            cycle_count <= cycle_count + 8'd1;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    idx <= 8'd0;
                    freq_idx <= 8'd0;
                    max_freq <= 8'd0;
                    max_val <= 8'd0;
                    cycle_count <= 8'd0;
                    // Reset frequency table (partially) as needed
                    for (i = 0; i < 8'd20; i = i + 1) begin
                        // We'll reset only entries we might use
                        freq_table[stored_arr[i]] <= 8'd0;
                    end
                end

                STORE: begin
                    if (idx < INPUT_SIZE) begin
                        // Store inputs sequentially
                        case (idx)
                            8'd0: stored_arr[0] <= arr_0;
                            8'd1: stored_arr[1] <= arr_1;
                            8'd2: stored_arr[2] <= arr_2;
                            8'd3: stored_arr[3] <= arr_3;
                            8'd4: stored_arr[4] <= arr_4;
                            8'd5: stored_arr[5] <= arr_5;
                            8'd6: stored_arr[6] <= arr_6;
                            8'd7: stored_arr[7] <= arr_7;
                            8'd8: stored_arr[8] <= arr_8;
                            8'd9: stored_arr[9] <= arr_9;
                            8'd10: stored_arr[10] <= arr_10;
                            8'd11: stored_arr[11] <= arr_11;
                            8'd12: stored_arr[12] <= arr_12;
                            8'd13: stored_arr[13] <= arr_13;
                            8'd14: stored_arr[14] <= arr_14;
                            8'd15: stored_arr[15] <= arr_15;
                            8'd16: stored_arr[16] <= arr_16;
                            8'd17: stored_arr[17] <= arr_17;
                            8'd18: stored_arr[18] <= arr_18;
                            8'd19: stored_arr[19] <= arr_19;
                            8'd20: stored_arr[20] <= arr_20;
                        endcase
                        idx <= idx + 8'd1;
                    end
                end

                COUNT: begin
                    if (idx < INPUT_SIZE) begin
                        temp_val <= stored_arr[idx];
                        // Increment frequency count for current value
                        freq_table[stored_arr[idx]] <= freq_table[stored_arr[idx]] + 8'd1;
                        idx <= idx + 8'd1;
                    end
                end

                FIND_MAX: begin
                    if (freq_idx <= MAX_VAL) begin
                        if (freq_table[freq_idx] > max_freq) begin
                            max_freq <= freq_table[freq_idx];
                            max_val <= freq_idx;
                        end
                        freq_idx <= freq_idx + 8'd1;
                    end
                end

                FINISH: begin
                    result <= max_val;
                    done <= 1'b1;
                end
            endcase

            // Timeout protection
            if (cycle_count >= MAX_CYCLES && state != IDLE && state != FINISH) begin
                // Force transition to finish
                state <= FINISH;
            end
        end
    end

endmodule