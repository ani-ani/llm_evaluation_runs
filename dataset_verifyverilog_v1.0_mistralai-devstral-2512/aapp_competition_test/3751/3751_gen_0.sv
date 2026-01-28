module KostyaValidator(
    input clk,
    input rst_n,
    input start,
    input [7:0] char_in,
    input valid_in,
    input done_in,
    output reg result,
    output reg ready,
    output reg busy,
    output reg done
);

    // State declarations
    localparam [3:0] IDLE       = 4'd0;
    localparam [3:0] RECEIVING  = 4'd1;
    localparam [3:0] VALIDATING = 4'd2;
    localparam [3:0] COMPLETE   = 4'd3;
    localparam [3:0] ERROR      = 4'd4;

    reg [3:0] state, next_state;

    // String processing
    reg [8:0] char_count;  // 0-500 (9-bit)
    reg [8:0] max_length = 9'd500;

    // First position tracking (26 letters, 9-bit each)
    reg [8:0] first_pos [0:25];
    integer i;

    // Letter appearance flags
    reg [25:0] letter_seen;

    // Validation tracking
    reg [4:0] current_letter;  // 0-25 (5-bit)
    reg validation_passed;

    // Timeout counter
    reg [9:0] cycle_count;
    localparam [9:0] MAX_CYCLES = 10'd1000;

    // Initialize all registers
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            char_count <= 9'd0;
            result <= 1'b0;
            ready <= 1'b1;
            busy <= 1'b0;
            done <= 1'b0;
            validation_passed <= 1'b0;
            cycle_count <= 10'd0;
            current_letter <= 5'd0;
            letter_seen <= 26'd0;
            for (i = 0; i < 26; i = i + 1) begin
                first_pos[i] <= 9'd501;  // Initialize to invalid position
            end
        end else begin
            state <= next_state;
            case (state)
                IDLE: begin
                    ready <= 1'b1;
                    busy <= 1'b0;
                    done <= 1'b0;
                    result <= 1'b0;
                    if (start) begin
                        next_state <= RECEIVING;
                        ready <= 1'b0;
                        busy <= 1'b1;
                        char_count <= 9'd0;
                        letter_seen <= 26'd0;
                        for (i = 0; i < 26; i = i + 1) begin
                            first_pos[i] <= 9'd501;
                        end
                    end
                end

                RECEIVING: begin
                    ready <= 1'b0;
                    busy <= 1'b1;
                    done <= 1'b0;
                    if (done_in) begin
                        next_state <= VALIDATING;
                        current_letter <= 5'd0;
                        validation_passed <= 1'b1;
                    end else if (valid_in) begin
                        // Process character
                        if (char_in >= 8'd97 && char_in <= 8'd122) begin
                            reg [4:0] letter_index;
                            letter_index = char_in - 8'd97;
                            
                            // Record first position
                            if (first_pos[letter_index] == 9'd501) begin
                                first_pos[letter_index] <= char_count;
                                letter_seen[letter_index] <= 1'b1;
                            end
                            
                            // Increment character count
                            if (char_count < max_length) begin
                                char_count <= char_count + 9'd1;
                            end
                        end
                    end
                end

                VALIDATING: begin
                    ready <= 1'b0;
                    busy <= 1'b1;
                    done <= 1'b0;
                    
                    // Check timeout
                    if (cycle_count >= MAX_CYCLES) begin
                        next_state <= ERROR;
                    end else begin
                        cycle_count <= cycle_count + 10'd1;
                        
                        // Check if we've processed all letters
                        if (current_letter == 5'd26) begin
                            next_state <= COMPLETE;
                        end else begin
                            // Check current letter
                            if (letter_seen[current_letter]) begin
                                // Must be contiguous from 'a'
                                if (current_letter > 5'd0 && !letter_seen[current_letter - 5'd1]) begin
                                    validation_passed <= 1'b0;
                                end
                                
                                // Check ordering with next letter
                                if (current_letter < 5'd25 && letter_seen[current_letter + 5'd1]) begin
                                    if (first_pos[current_letter] > first_pos[current_letter + 5'd1]) begin
                                        validation_passed <= 1'b0;
                                    end
                                end
                                
                                current_letter <= current_letter + 5'd1;
                            end else begin
                                // If current letter not seen, all higher letters must not be seen
                                reg [4:0] j;
                                reg all_higher_unseen;
                                all_higher_unseen = 1'b1;
                                for (j = current_letter + 5'd1; j < 5'd26; j = j + 5'd1) begin
                                    if (letter_seen[j]) begin
                                        all_higher_unseen = 1'b0;
                                    end
                                end
                                
                                if (all_higher_unseen) begin
                                    current_letter <= current_letter + 5'd1;
                                end else begin
                                    validation_passed <= 1'b0;
                                    current_letter <= current_letter + 5'd1;
                                end
                            end
                        end
                    end
                end

                COMPLETE: begin
                    ready <= 1'b1;
                    busy <= 1'b0;
                    done <= 1'b1;
                    result <= validation_passed;
                    next_state <= IDLE;
                end

                ERROR: begin
                    ready <= 1'b1;
                    busy <= 1'b0;
                    done <= 1'b1;
                    result <= 1'b0;
                    next_state <= IDLE;
                end

                default: begin
                    next_state <= IDLE;
                    ready <= 1'b1;
                    busy <= 1'b0;
                    done <= 1'b0;
                    result <= 1'b0;
                end
            endcase
        end
    end

    // Default assignments for outputs
    always @(*) begin
        if (state == IDLE) begin
            ready = 1'b1;
            busy = 1'b0;
            done = 1'b0;
        end else if (state == COMPLETE || state == ERROR) begin
            ready = 1'b1;
            busy = 1'b0;
            done = 1'b1;
        end else begin
            ready = 1'b0;
            busy = 1'b1;
            done = 1'b0;
        end
    end

endmodule