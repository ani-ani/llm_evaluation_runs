module barbarian_substring_matcher (
    input clk,
    input rst_n,
    input start,
    input [2:0] operation_type,
    input [2:0] barbarian_id,
    input [63:0] string_input,
    input [2:0] string_length,
    output reg [15:0] result,
    output reg done,
    output reg valid
);

    // State encodings
    localparam IDLE = 3'b000;
    localparam LOAD_PATTERN = 3'b001;
    localparam PROCESS_TYPE1 = 3'b010;
    localparam PROCESS_TYPE2 = 3'b011;
    localparam DONE = 3'b100;

    // Registers for storage
    reg [63:0] patterns [0:7];
    reg [2:0] pattern_lengths [0:7];
    reg [15:0] counters [0:7];

    // Temporary match registers
    reg match_found;
    reg [2:0] current_barbarian;
    reg [2:0] current_pos;
    reg [2:0] current_char_idx;
    reg [7:0] char_from_pattern;
    reg [7:0] char_from_string;

    // State register
    reg [2:0] state;
    reg [2:0] next_state;

    // Control flags
    reg load_done;
    reg processing_done;
    reg increment_flag;
    reg [2:0] load_idx;

    integer i;

    // Next state logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start && operation_type == 3'b000)
                    next_state = LOAD_PATTERN;
                else if (start && operation_type == 3'b001)
                    next_state = PROCESS_TYPE1;
                else if (start && operation_type == 3'b010)
                    next_state = PROCESS_TYPE2;
                else
                    next_state = IDLE;
            end

            LOAD_PATTERN: begin
                if (load_done)
                    next_state = DONE;
                else
                    next_state = LOAD_PATTERN;
            end

            PROCESS_TYPE1: begin
                if (processing_done)
                    next_state = DONE;
                else
                    next_state = PROCESS_TYPE1;
            end

            PROCESS_TYPE2: begin
                next_state = DONE;
            end

            DONE: begin
                next_state = IDLE;
            end

            default: next_state = IDLE;
        endcase
    end

    // State transition
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end

    // Sequential logic for operations
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset all counters and patterns
            for (i = 0; i < 8; i = i + 1) begin
                counters[i] <= 16'b0;
                patterns[i] <= 64'b0;
                pattern_lengths[i] <= 3'b0;
            end
            load_idx <= 3'b0;
            load_done <= 1'b0;
            processing_done <= 1'b0;
            current_barbarian <= 3'b0;
            current_pos <= 3'b0;
            current_char_idx <= 3'b0;
            increment_flag <= 1'b0;
            done <= 1'b0;
            valid <= 1'b0;
            result <= 16'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    valid <= 1'b0;
                    load_done <= 1'b0;
                    processing_done <= 1'b0;
                    increment_flag <= 1'b0;
                    if (start && operation_type == 3'b000) begin
                        // Loading pattern for specific barbarian
                        if (barbarian_id < 8) begin
                            patterns[barbarian_id] <= string_input;
                            pattern_lengths[barbarian_id] <= string_length;
                        end
                    end
                end

                LOAD_PATTERN: begin
                    if (start) begin
                        if (barbarian_id < 8) begin
                            patterns[barbarian_id] <= string_input;
                            pattern_lengths[barbarian_id] <= string_length;
                        end
                        load_idx <= load_idx + 1;
                    end
                    if (load_idx == 3'd7) begin
                        load_done <= 1'b1;
                    end
                end

                PROCESS_TYPE1: begin
                    // Matching logic
                    if (current_barbarian == 8) begin
                        processing_done <= 1'b1;
                    end else begin
                        reg [2:0] current_pl;
                        current_pl <= pattern_lengths[current_barbarian];
                        if (current_pl == 0 || current_pl > string_length) begin
                            current_barbarian <= current_barbarian + 1;
                            current_pos <= 3'b0;
                            current_char_idx <= 3'b0;
                        end else if (current_pos > (string_length - current_pl)) begin
                            current_barbarian <= current_barbarian + 1;
                            current_pos <= 3'b0;
                            current_char_idx <= 3'b0;
                        end else begin
                            if (patterns[current_barbarian][current_char_idx*8 +: 8] == string_input[(current_pos + current_char_idx)*8 +: 8]) begin
                                if (current_char_idx == current_pl - 1) begin
                                    counters[current_barbarian] <= counters[current_barbarian] + 1;
                                    current_barbarian <= current_barbarian + 1;
                                    current_pos <= 3'b0;
                                    current_char_idx <= 3'b0;
                                end else begin
                                    current_char_idx <= current_char_idx + 1;
                                end
                            end else begin
                                current_pos <= current_pos + 1;
                                current_char_idx <= 3'b0;
                            end
                        end
                    end
                end

                PROCESS_TYPE2: begin
                    result <= counters[barbarian_id];
                end

                DONE: begin
                    // Nothing to do here, just wait for transition to IDLE.
                    // Outputs are handled in comb block.
                end
            endcase
        end
    end

    // Output logic
    always @(*) begin
        case (state)
            PROCESS_TYPE2: begin
                result = counters[barbarian_id];
                done = 1'b1;
                valid = 1'b1;
            end
            DONE: begin
                done = 1'b1;
                valid = 1'b1;
                result = counters[barbarian_id];
            end
            default: begin
                result = 16'b0;
                done = 1'b0;
                valid = 1'b0;
            end
        endcase
    end

endmodule