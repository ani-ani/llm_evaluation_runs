module timmy_counter (
    input clk,
    input rst_n,
    input start,
    input [3:0] num_balls_total,
    input [2:0] num_colors,
    input [3:0] color_counts [0:7],
    input [2:0] restricted_count,
    input [2:0] restricted_colors [0:7],
    input [2:0] sequence_len,
    input [2:0] sequence_colors [0:7],
    output reg [31:0] result,
    output reg done
);

    // Constants
    localparam MOD = 32'd1000000007;
    localparam MAX_BALLS = 16;
    localparam MAX_COLORS = 8;
    localparam MAX_SEQ_LEN = 4;
    localparam MAX_STATES = 1024;

    // State machine states
    typedef enum logic [2:0] {
        IDLE,
        INIT,
        COMPUTE,
        DONE
    } state_t;

    // State registers
    state_t state_reg, state_next;
    reg [31:0] result_reg;
    reg done_reg;

    // Stack and memoization structures
    reg [3:0] stack_ptr;
    reg [3:0] stack_last_color [0:MAX_STATES-1];
    reg [3:0] stack_remaining [0:7][0:MAX_STATES-1];
    reg [3:0] stack_seq_pos [0:MAX_STATES-1];

    reg [31:0] memo [0:MAX_STATES-1];
    reg [31:0] memo_key [0:MAX_STATES-1];

    // Current state variables
    reg [3:0] current_last_color;
    reg [3:0] current_remaining [0:7];
    reg [3:0] current_seq_pos;

    // Temporary variables
    reg [3:0] next_color;
    reg [31:0] temp_count;
    reg [3:0] i, j;

    // Restricted colors lookup
    reg restricted_lookup [0:7];

    // Initialize restricted colors lookup
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i = 0; i < 8; i = i + 1) begin
                restricted_lookup[i] = 0;
            end
        end else if (start) begin
            for (i = 0; i < 8; i = i + 1) begin
                restricted_lookup[i] = 0;
            end
            for (i = 0; i < restricted_count; i = i + 1) begin
                restricted_lookup[restricted_colors[i]] = 1;
            end
        end
    end

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state_reg <= IDLE;
            result_reg <= 0;
            done_reg <= 0;
            stack_ptr <= 0;
        end else begin
            state_reg <= state_next;
        end
    end

    // State machine next state logic
    always @(*) begin
        state_next = state_reg;
        case (state_reg)
            IDLE: begin
                if (start) state_next = INIT;
            end
            INIT: begin
                state_next = COMPUTE;
            end
            COMPUTE: begin
                if (stack_ptr == 0) state_next = DONE;
            end
            DONE: begin
                state_next = IDLE;
            end
        endcase
    end

    // Stack and computation logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            stack_ptr <= 0;
            for (i = 0; i < MAX_STATES; i = i + 1) begin
                stack_last_color[i] <= 0;
                for (j = 0; j < 8; j = j + 1) begin
                    stack_remaining[j][i] <= 0;
                end
                stack_seq_pos[i] <= 0;
                memo[i] <= 0;
                memo_key[i] <= 0;
            end
            current_last_color <= 0;
            for (i = 0; i < 8; i = i + 1) begin
                current_remaining[i] <= 0;
            end
            current_seq_pos <= 0;
        end else begin
            case (state_reg)
                INIT: begin
                    // Initialize stack with initial state
                    stack_ptr <= 1;
                    stack_last_color[0] <= 0;
                    for (i = 0; i < 8; i = i + 1) begin
                        stack_remaining[i][0] <= color_counts[i];
                    end
                    stack_seq_pos[0] <= 0;
                    current_last_color <= stack_last_color[0];
                    for (i = 0; i < 8; i = i + 1) begin
                        current_remaining[i] <= stack_remaining[i][0];
                    end
                    current_seq_pos <= stack_seq_pos[0];
                end
                COMPUTE: begin
                    // Check if current state is terminal
                    temp_count = 0;
                    for (i = 0; i < 8; i = i + 1) begin
                        temp_count = temp_count + current_remaining[i];
                    end
                    if (temp_count == 0) begin
                        // Terminal state, pop stack
                        stack_ptr <= stack_ptr - 1;
                        if (stack_ptr > 0) begin
                            current_last_color <= stack_last_color[stack_ptr - 1];
                            for (i = 0; i < 8; i = i + 1) begin
                                current_remaining[i] <= stack_remaining[i][stack_ptr - 1];
                            end
                            current_seq_pos <= stack_seq_pos[stack_ptr - 1];
                        end
                    end else begin
                        // Check for sequence completion
                        if (current_seq_pos == sequence_len - 1) begin
                            // Force next color to be sequence[sequence_len-1]
                            next_color = sequence_colors[sequence_len - 1];
                            if (current_remaining[next_color] > 0 && 
                                (current_last_color == 0 || !restricted_lookup[current_last_color] || !restricted_lookup[next_color])) begin
                                // Push new state
                                stack_last_color[stack_ptr] <= next_color;
                                for (i = 0; i < 8; i = i + 1) begin
                                    stack_remaining[i][stack_ptr] <= current_remaining[i];
                                end
                                stack_remaining[next_color][stack_ptr] <= current_remaining[next_color] - 1;
                                stack_seq_pos[stack_ptr] <= (next_color == sequence_colors[current_seq_pos + 1]) ? current_seq_pos + 1 : 0;
                                stack_ptr <= stack_ptr + 1;
                                current_last_color <= next_color;
                                for (i = 0; i < 8; i = i + 1) begin
                                    current_remaining[i] <= stack_remaining[i][stack_ptr - 1];
                                end
                                current_seq_pos <= stack_seq_pos[stack_ptr - 1];
                            end else begin
                                // Pop stack
                                stack_ptr <= stack_ptr - 1;
                                if (stack_ptr > 0) begin
                                    current_last_color <= stack_last_color[stack_ptr - 1];
                                    for (i = 0; i < 8; i = i + 1) begin
                                        current_remaining[i] <= stack_remaining[i][stack_ptr - 1];
                                    end
                                    current_seq_pos <= stack_seq_pos[stack_ptr - 1];
                                end
                            end
                        end else begin
                            // Try all possible next colors
                            for (next_color = 0; next_color < 8; next_color = next_color + 1) begin
                                if (current_remaining[next_color] > 0 && 
                                    (current_last_color == 0 || !restricted_lookup[current_last_color] || !restricted_lookup[next_color])) begin
                                    // Check if this color continues the sequence
                                    reg [3:0] new_seq_pos = (next_color == sequence_colors[current_seq_pos + 1]) ? current_seq_pos + 1 : 0;
                                    // Push new state
                                    stack_last_color[stack_ptr] <= next_color;
                                    for (i = 0; i < 8; i = i + 1) begin
                                        stack_remaining[i][stack_ptr] <= current_remaining[i];
                                    end
                                    stack_remaining[next_color][stack_ptr] <= current_remaining[next_color] - 1;
                                    stack_seq_pos[stack_ptr] <= new_seq_pos;
                                    stack_ptr <= stack_ptr + 1;
                                    current_last_color <= next_color;
                                    for (i = 0; i < 8; i = i + 1) begin
                                        current_remaining[i] <= stack_remaining[i][stack_ptr - 1];
                                    end
                                    current_seq_pos <= stack_seq_pos[stack_ptr - 1];
                                    break;
                                end
                            end
                            if (next_color == 8) begin
                                // No valid next color, pop stack
                                stack_ptr <= stack_ptr - 1;
                                if (stack_ptr > 0) begin
                                    current_last_color <= stack_last_color[stack_ptr - 1];
                                    for (i = 0; i < 8; i = i + 1) begin
                                        current_remaining[i] <= stack_remaining[i][stack_ptr - 1];
                                    end
                                    current_seq_pos <= stack_seq_pos[stack_ptr - 1];
                                end
                            end
                        end
                    end
                end
                DONE: begin
                    // Calculate result (simplified for this example)
                    result_reg <= 1; // Placeholder for actual result calculation
                    done_reg <= 1;
                end
            endcase
        end
    end

    // Output registers
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            result <= 0;
            done <= 0;
        end else begin
            result <= result_reg;
            done <= done_reg;
        end
    end

endmodule