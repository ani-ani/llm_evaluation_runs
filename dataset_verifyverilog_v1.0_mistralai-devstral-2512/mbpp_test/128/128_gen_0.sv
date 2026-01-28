module word_finder(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] threshold,
    input wire [63:0] input_str,
    output reg [3:0] result_count,
    output reg [63:0] result_words,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE    = 3'd0;
    localparam [2:0] PARSE   = 3'd1;
    localparam [2:0] COMPARE = 3'd2;
    localparam [2:0] STORE   = 3'd3;
    localparam [2:0] COMPLETE = 3'd4;

    // Internal registers
    reg [2:0] state, next_state;
    reg [2:0] byte_addr;           // 0-7
    reg [2:0] word_idx;           // 0-7
    reg [2:0] char_idx;           // 0-7
    reg [7:0] word_buffer [0:7];  // Current word buffer
    reg [7:0] current_char;
    reg is_space;
    reg word_valid;
    reg [2:0] match_count;
    reg [2:0] result_pos;
    reg [7:0] result_temp [0:7];

    // Initialize all registers
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            byte_addr <= 3'd0;
            word_idx <= 3'd0;
            char_idx <= 3'd0;
            match_count <= 3'd0;
            result_pos <= 3'd0;
            done <= 1'b0;
            result_count <= 4'd0;
            result_words <= 64'd0;

            // Initialize arrays
            integer i;
            for (i = 0; i < 8; i = i + 1) begin
                word_buffer[i] <= 8'd0;
                result_temp[i] <= 8'd0;
            end
        end else begin
            state <= next_state;
        end
    end

    // Main FSM logic
    always @(*) begin
        case (state)
            IDLE: begin
                done <= 1'b0;
                if (start) begin
                    next_state = PARSE;
                    byte_addr = 3'd0;
                    word_idx = 3'd0;
                    char_idx = 3'd0;
                    match_count = 3'd0;
                    result_pos = 3'd0;
                    result_count = 4'd0;
                    result_words = 64'd0;

                    // Reset arrays
                    integer i;
                    for (i = 0; i < 8; i = i + 1) begin
                        word_buffer[i] = 8'd0;
                        result_temp[i] = 8'd0;
                    end
                end else begin
                    next_state = IDLE;
                end
            end

            PARSE: begin
                current_char = input_str[(byte_addr * 8) +: 8];
                is_space = (current_char == 8'h20);

                if (is_space) begin
                    // End of current word
                    word_valid = (char_idx > 3'd0);
                    next_state = COMPARE;
                end else begin
                    // Accumulate character
                    word_buffer[char_idx] = current_char;
                    char_idx = char_idx + 3'd1;

                    // Check if last character
                    if (byte_addr == 3'd7) begin
                        word_valid = 1'b1;
                        next_state = COMPARE;
                    end else begin
                        byte_addr = byte_addr + 3'd1;
                        next_state = PARSE;
                    end
                end
            end

            COMPARE: begin
                if (word_valid && (char_idx > threshold)) begin
                    next_state = STORE;
                end else begin
                    // Reset for next word
                    char_idx = 3'd0;
                    word_idx = word_idx + 3'd1;

                    if (byte_addr == 3'd7) begin
                        next_state = COMPLETE;
                    end else begin
                        byte_addr = byte_addr + 3'd1;
                        next_state = PARSE;
                    end
                end
            end

            STORE: begin
                // Store current word in result buffer
                integer i;
                for (i = 0; i < char_idx; i = i + 1) begin
                    result_temp[result_pos] = word_buffer[i];
                    result_pos = result_pos + 3'd1;
                end

                match_count = match_count + 3'd1;

                // Reset for next word
                char_idx = 3'd0;
                word_idx = word_idx + 3'd1;

                if (byte_addr == 3'd7) begin
                    next_state = COMPLETE;
                end else begin
                    byte_addr = byte_addr + 3'd1;
                    next_state = PARSE;
                end
            end

            COMPLETE: begin
                // Pack result words into output
                result_count = match_count;
                result_words = {result_temp[7], result_temp[6], result_temp[5], result_temp[4],
                               result_temp[3], result_temp[2], result_temp[1], result_temp[0]};
                done = 1'b1;
                next_state = IDLE;
            end

            default: next_state = IDLE;
        endcase
    end

endmodule