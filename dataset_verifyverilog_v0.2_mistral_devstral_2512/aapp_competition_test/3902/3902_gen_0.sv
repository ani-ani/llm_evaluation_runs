module reberland_suffix (
    input clk,
    input rst_n,
    input start,
    input [4:0] char_in,
    input [3:0] len_in,
    output reg valid,
    output reg [4:0] suffix_out,
    output reg [3:0] suffix_len,
    output reg done
);

    // State definitions
    typedef enum logic [2:0] {
        IDLE,
        LOAD,
        PROCESS,
        OUTPUT,
        DONE
    } state_t;

    state_t state = IDLE;
    reg [3:0] char_buffer [0:15]; // Buffer to store input string
    reg [3:0] buffer_index = 0; // Current index for loading
    reg [3:0] current_pos = 0; // Current position in traversal
    reg [3:0] last_suffix_pos = 0; // Position of last suffix
    reg [4:0] last_suffix [0:1]; // Last suffix (2 or 3 chars)
    reg [4:0] current_suffix [0:1]; // Current suffix being checked
    reg [3:0] suffix_count = 0; // Count of valid suffixes found
    reg [4:0] suffix_memory [0:15]; // Store valid suffixes (2 or 3 chars)
    reg [3:0] suffix_len_memory [0:15]; // Store lengths of valid suffixes
    reg [3:0] output_index = 0; // Index for outputting suffixes
    reg [3:0] stack_ptr = 0; // Stack pointer for DFS
    reg [3:0] stack [0:11]; // Stack for DFS (max depth 12)

    // Reset logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            buffer_index <= 0;
            current_pos <= 0;
            last_suffix_pos <= 0;
            suffix_count <= 0;
            output_index <= 0;
            stack_ptr <= 0;
            valid <= 0;
            done <= 0;
            for (int i = 0; i < 16; i = i + 1) begin
                char_buffer[i] <= 0;
            end
            for (int i = 0; i < 16; i = i + 1) begin
                suffix_memory[i] <= 0;
                suffix_len_memory[i] <= 0;
            end
            for (int i = 0; i < 12; i = i + 1) begin
                stack[i] <= 0;
            end
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        state <= LOAD;
                        buffer_index <= 0;
                    end
                end
                LOAD: begin
                    if (buffer_index < len_in) begin
                        char_buffer[buffer_index] <= char_in;
                        buffer_index <= buffer_index + 1;
                    end else begin
                        state <= PROCESS;
                        current_pos <= len_in - 1;
                        stack_ptr <= 0;
                        stack[stack_ptr] <= current_pos;
                        stack_ptr <= stack_ptr + 1;
                    end
                end
                PROCESS: begin
                    if (stack_ptr > 0) begin
                        stack_ptr <= stack_ptr - 1;
                        current_pos <= stack[stack_ptr];
                        // Check for suffix of length 2
                        if (current_pos >= 1 && (current_pos - 1) >= 4) begin
                            current_suffix[0] <= char_buffer[current_pos - 1];
                            current_suffix[1] <= char_buffer[current_pos];
                            // Check if current suffix is different from last suffix
                            if (last_suffix_pos != current_pos - 1 || 
                                (last_suffix[0] != current_suffix[0] || last_suffix[1] != current_suffix[1])) begin
                                // Add to valid suffixes
                                suffix_memory[suffix_count] <= {current_suffix[0], current_suffix[1]};
                                suffix_len_memory[suffix_count] <= 2;
                                suffix_count <= suffix_count + 1;
                                last_suffix_pos <= current_pos - 1;
                                last_suffix[0] <= current_suffix[0];
                                last_suffix[1] <= current_suffix[1];
                                // Push new state
                                stack[stack_ptr] <= current_pos - 2;
                                stack_ptr <= stack_ptr + 1;
                            end
                        end
                        // Check for suffix of length 3
                        if (current_pos >= 2 && (current_pos - 2) >= 4) begin
                            current_suffix[0] <= char_buffer[current_pos - 2];
                            current_suffix[1] <= char_buffer[current_pos - 1];
                            // Check if current suffix is different from last suffix
                            if (last_suffix_pos != current_pos - 2 || 
                                (last_suffix[0] != current_suffix[0] || last_suffix[1] != current_suffix[1])) begin
                                // Add to valid suffixes
                                suffix_memory[suffix_count] <= {current_suffix[0], current_suffix[1], char_buffer[current_pos]};
                                suffix_len_memory[suffix_count] <= 3;
                                suffix_count <= suffix_count + 1;
                                last_suffix_pos <= current_pos - 2;
                                last_suffix[0] <= current_suffix[0];
                                last_suffix[1] <= current_suffix[1];
                                // Push new state
                                stack[stack_ptr] <= current_pos - 3;
                                stack_ptr <= stack_ptr + 1;
                            end
                        end
                    end else begin
                        state <= OUTPUT;
                        output_index <= 0;
                    end
                end
                OUTPUT: begin
                    if (output_index < suffix_count) begin
                        valid <= 1;
                        suffix_out <= suffix_memory[output_index];
                        suffix_len <= suffix_len_memory[output_index];
                        output_index <= output_index + 1;
                    end else begin
                        valid <= 0;
                        state <= DONE;
                        done <= 1;
                    end
                end
                DONE: begin
                    if (!start) begin
                        state <= IDLE;
                        done <= 0;
                    end
                end
            endcase
        end
    end

endmodule