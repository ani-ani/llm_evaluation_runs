module barbarian_query(
    input clk,
    input rst_n,
    input start,
    input mode,
    input [3:0] addr,
    input [1:0] op,
    input [79:0] data,
    output reg [31:0] result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] LOAD_BARBARIAN = 3'd1;
    localparam [2:0] STORE_QUERY = 3'd2;
    localparam [2:0] QUERY_COUNT = 3'd3;
    localparam [2:0] COMPUTE = 3'd4;
    localparam [2:0] FINISH = 3'd5;

    reg [2:0] state, next_state;

    // Storage for barbarian words (16 words, each 80 bits)
    reg [79:0] barbarian_words [0:15];
    integer i, j;

    // Query storage
    reg [79:0] query_P;

    // Internal registers
    reg [31:0] match_count;
    reg [3:0] current_addr;
    reg [3:0] current_pos;
    reg [3:0] current_char;
    reg [4:0] char_match;
    reg [3:0] cycle_count;
    localparam [3:0] MAX_CYCLES = 4'd15;

    // State transition logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 32'd0;
            done <= 1'b0;
            cycle_count <= 4'd0;
            match_count <= 32'd0;
            current_addr <= 4'd0;
            current_pos <= 4'd0;
            current_char <= 4'd0;
            char_match <= 5'd0;
            for (i = 0; i < 16; i = i + 1) begin
                barbarian_words[i] <= 80'd0;
            end
            query_P <= 80'd0;
        end else begin
            state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) begin
                    if (mode == 1'b0) begin
                        next_state = LOAD_BARBARIAN;
                    end else if (mode == 1'b1) begin
                        if (op == 2'd1) begin
                            next_state = STORE_QUERY;
                        end else if (op == 2'd2) begin
                            next_state = QUERY_COUNT;
                        end
                    end
                end
            end

            LOAD_BARBARIAN: begin
                next_state = IDLE;
            end

            STORE_QUERY: begin
                next_state = IDLE;
            end

            QUERY_COUNT: begin
                next_state = COMPUTE;
            end

            COMPUTE: begin
                if (cycle_count >= MAX_CYCLES) begin
                    next_state = FINISH;
                end
            end

            FINISH: begin
                next_state = IDLE;
            end

            default: next_state = IDLE;
        endcase
    end

    // Output logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            result <= 32'd0;
            done <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                end

                LOAD_BARBARIAN: begin
                    barbarian_words[addr] <= data;
                    done <= 1'b1;
                end

                STORE_QUERY: begin
                    query_P <= data;
                    done <= 1'b1;
                end

                QUERY_COUNT: begin
                    current_addr <= addr;
                    match_count <= 32'd0;
                    current_pos <= 4'd0;
                    current_char <= 4'd0;
                    char_match <= 5'd0;
                    cycle_count <= 4'd0;
                    done <= 1'b0;
                end

                COMPUTE: begin
                    // Check if current position matches
                    if (current_char == 4'd0) begin
                        // Start new comparison at current_pos
                        char_match <= 5'd1;
                    end else begin
                        // Compare character
                        if (barbarian_words[current_addr][(15 - current_char) * 5 +: 5] == 
                            query_P[(15 - (current_pos + current_char)) * 5 +: 5]) begin
                            char_match <= char_match + 5'd1;
                        end else begin
                            char_match <= 5'd0;
                        end
                    end

                    // Update counters
                    if (current_char == 4'd15) begin
                        current_char <= 4'd0;
                        if (current_pos == 4'd15) begin
                            current_pos <= 4'd0;
                            cycle_count <= cycle_count + 4'd1;
                        end else begin
                            current_pos <= current_pos + 4'd1;
                        end
                    end else begin
                        current_char <= current_char + 4'd1;
                    end

                    // Check for full match
                    if (char_match == 5'd16) begin
                        match_count <= match_count + 32'd1;
                        char_match <= 5'd0;
                    end

                    // Check completion
                    if (cycle_count >= MAX_CYCLES) begin
                        result <= match_count;
                        done <= 1'b0;
                    end
                end

                FINISH: begin
                    result <= match_count;
                    done <= 1'b1;
                end

                default: begin
                    result <= 32'd0;
                    done <= 1'b0;
                end
            endcase
        end
    end

endmodule