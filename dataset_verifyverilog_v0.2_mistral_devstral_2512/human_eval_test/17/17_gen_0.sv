module parse_music (
    input clk,
    input rst_n,
    input start,
    input [127:0] music_string,
    input [4:0] length,
    output reg [3:0] result,
    output reg result_valid,
    output reg done
);

    // Define states
    typedef enum logic [1:0] {
        IDLE,
        PROCESSING,
        DONE
    } state_t;

    // State register
    state_t current_state, next_state;

    // Index counter
    reg [3:0] index;

    // Note detection logic
    reg [7:0] current_byte, next_byte;

    // State transition logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            index <= 0;
            result <= 0;
            result_valid <= 0;
            done <= 0;
        end else begin
            current_state <= next_state;
            if (current_state == PROCESSING && next_state == PROCESSING) begin
                index <= index + 1;
            end
        end
    end

    // Next state logic
    always @(*) begin
        next_state = current_state;
        case (current_state)
            IDLE: begin
                if (start) next_state = PROCESSING;
            end
            PROCESSING: begin
                if (index >= length) next_state = DONE;
            end
            DONE: begin
                if (!start) next_state = IDLE;
            end
        endcase
    end

    // Extract current and next bytes
    always @(*) begin
        current_byte = music_string[(index)*8 +: 8];
        next_byte = (index + 1 < 16) ? music_string[(index + 1)*8 +: 8] : 0;
    end

    // Note parsing logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            result <= 0;
            result_valid <= 0;
            done <= 0;
        end else begin
            result_valid <= 0;
            done <= (current_state == DONE);

            if (current_state == PROCESSING) begin
                if (current_byte == 8'h6F && next_byte == 8'h7C) begin
                    result <= 2;
                    result_valid <= 1;
                    index <= index + 1; // Skip next byte
                end else if (current_byte == 8'h6F) begin
                    result <= 4;
                    result_valid <= 1;
                end else if (current_byte == 8'h2E && next_byte == 8'h7C) begin
                    result <= 1;
                    result_valid <= 1;
                    index <= index + 1; // Skip next byte
                end else if (current_byte == 8'h20) begin
                    // Skip space
                end
            end
        end
    end

endmodule