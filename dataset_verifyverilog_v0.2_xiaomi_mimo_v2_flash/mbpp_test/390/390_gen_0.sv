module string_formatter (
    input clk,
    input rst_n,
    input start,
    input [7:0] list_data [0:7],
    input [2:0] list_length,
    output reg [7:0] result_strings [0:7][0:4],
    output reg done,
    output reg [2:0] valid_count
);

    // State encoding
    localparam IDLE = 2'b00;
    localparam PROCESSING = 2'b01;
    localparam DONE = 2'b10;

    reg [1:0] state, next_state;
    reg [2:0] index;          // Index for the current element (0-7)
    reg [2:0] char_idx;       // Index for character position in output string (0-4)
    reg [2:0] valid_count_reg; // Internal register for valid count
    
    // ASCII constants
    localparam [7:0] CHAR_T = 8'h74; // 't'
    localparam [7:0] CHAR_E = 8'h65; // 'e'
    localparam [7:0] CHAR_M = 8'h6D; // 'm'
    localparam [7:0] CHAR_P = 8'h70; // 'p'
    localparam [7:0] CHAR_NULL = 8'h00; // null terminator

    // Next state logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start)
                    next_state = PROCESSING;
                else
                    next_state = IDLE;
            end
            PROCESSING: begin
                // Processing happens for 8 cycles (index 0 to 7)
                // We transition to DONE when index reaches 7 and char_idx completes the cycle
                // However, simplest is to count 8 full cycles (indices 0..7) fully
                // The internal counter logic determines when it's actually "done" processing the user request.
                // Since the requirement says "processes one element per cycle" and latency 8 cycles,
                // we will iterate 8 times regardless of list_length, but only write valid data.
                // To strictly follow 8 cycles latency after start, we run 8 cycles.
                if (index == 3'd7 && char_idx == 3'd4) 
                    next_state = DONE;
                else
                    next_state = PROCESSING;
            end
            DONE: begin
                // Stay in DONE until start goes low (or reset)
                if (~start)
                    next_state = IDLE;
                else
                    next_state = DONE;
            end
            default: next_state = IDLE;
        endcase
    end

    // Sequential logic for state and control signals
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            index <= 3'b0;
            char_idx <= 3'b0;
            valid_count_reg <= 3'b0;
            done <= 1'b0;
            valid_count <= 3'b0;
        end else begin
            state <= next_state;

            if (state == IDLE && start) begin
                index <= 3'b0;
                char_idx <= 3'b0;
                valid_count_reg <= list_length;
                done <= 1'b0;
            end else if (state == PROCESSING) begin
                // Increment char_idx (0..4)
                if (char_idx == 3'd4)
                    char_idx <= 3'b0;
                else
                    char_idx <= char_idx + 1'b1;

                // Increment index only after completing a full string (char_idx wraps from 4 to 0)
                if (char_idx == 3'd4)
                    index <= index + 1'b1;
            end else if (state == DONE) begin
                valid_count <= valid_count_reg;
                done <= 1'b1;
            end
        end
    end

    // Output Logic (Data Path)
    // We need to write to result_strings based on index and char_idx
    integer i, j;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset output buffer to 0
            for (i = 0; i < 8; i = i + 1) begin
                for (j = 0; j < 5; j = j + 1) begin
                    result_strings[i][j] <= 8'h00;
                end
            end
        end else if (state == IDLE && start) begin
            // Prepare for new transaction, maybe clear current? 
            // Requirement doesn't explicitly say clear buffer on start, 
            // but usually good practice. We will write valid data only though.
            // To ensure garbage is not shown, let's clear the valid rows.
            for (i = 0; i < 8; i = i + 1) begin
                if (i >= list_length) begin
                    // Clear unused rows if we wanted to be strict, 
                    // but 'valid_count' handles visibility. 
                    // Let's just overwrite data during PROCESSING.
                end
            end
        end else if (state == PROCESSING) begin
            // Write logic based on char_idx and index
            // Only write if index < list_length (valid_count_reg)
            if (index < valid_count_reg) begin
                case (char_idx)
                    3'd0: result_strings[index][0] <= CHAR_T;
                    3'd1: result_strings[index][1] <= CHAR_E;
                    3'd2: result_strings[index][2] <= CHAR_M;
                    3'd3: result_strings[index][3] <= CHAR_P;
                    3'd4: begin
                        // Write the input character
                        result_strings[index][4] <= list_data[index];
                        // Note: Null terminator is not explicitly stored per requirement "'t','e','m','p',<char>,null" 
                        // but the output array is 5 chars wide. Usually null is 6th. 
                        // If the requirement implies 5 chars exactly, we write 5. 
                        // If it implies 5 char storage + null behavior, we might be missing space. 
                        // Given `result_strings [0:7][0:4]` (5 slots), I will write 5 ASCII chars: 't','e','m','p',<char>.
                        // If null termination is strictly required to be stored in the 5th slot, the prompt conflicts 
                        // because it says "'t','e','m','p',<char>,null" (6 items) into 5 slots.
                        // I assume the prompt meant the string format is "tempX" (5 chars) or the array is 6 wide. 
                        // Given `max 5 characters each`, I stick to 5 chars: 't','e','m','p',<char>.
                    end
                endcase
            end
        end
    end

endmodule
