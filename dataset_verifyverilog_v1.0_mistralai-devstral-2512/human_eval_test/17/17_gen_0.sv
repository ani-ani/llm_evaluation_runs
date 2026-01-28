module NoteParser(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [127:0] str_in,
    input wire [3:0] str_len,
    output reg [79:0] result,
    output reg [2:0] note_count,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE      = 3'd0;
    localparam [2:0] CHECK_CHAR = 3'd1;
    localparam [2:0] DECIDE     = 3'd2;
    localparam [2:0] SKIP_SPACE = 3'd3;
    localparam [2:0] OUTPUT     = 3'd4;
    localparam [2:0] DONE_STATE = 3'd5;

    reg [2:0] state, next_state;
    reg [3:0] char_idx;
    reg [3:0] temp_note;
    reg [3:0] note_idx;
    reg [7:0] current_char;
    reg [7:0] next_char;
    reg [3:0] cycle_count;
    localparam [3:0] MAX_CYCLES = 4'd50;

    // Initialize all registers
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            char_idx <= 4'd0;
            temp_note <= 4'd0;
            note_idx <= 4'd0;
            current_char <= 8'd0;
            next_char <= 8'd0;
            cycle_count <= 4'd0;
            result <= 80'd0;
            note_count <= 3'd0;
            done <= 1'b0;
        end else begin
            state <= next_state;
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 4'd0;
                    if (start) begin
                        next_state <= CHECK_CHAR;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                CHECK_CHAR: begin
                    cycle_count <= cycle_count + 4'd1;
                    if (char_idx < str_len) begin
                        current_char <= str_in[(char_idx * 8) +: 8];
                        if (char_idx + 4'd1 < str_len) begin
                            next_char <= str_in[((char_idx + 4'd1) * 8) +: 8];
                        end else begin
                            next_char <= 8'd0;
                        end
                        next_state <= DECIDE;
                    end else begin
                        next_state <= DONE_STATE;
                    end
                end

                DECIDE: begin
                    cycle_count <= cycle_count + 4'd1;
                    if (current_char == 8'd111) begin // 'o'
                        if (next_char == 8'd124) begin // '|'
                            temp_note <= 4'd2;
                            char_idx <= char_idx + 4'd2;
                        end else begin
                            temp_note <= 4'd4;
                            char_idx <= char_idx + 4'd1;
                        end
                        next_state <= OUTPUT;
                    end else if (current_char == 8'd46) begin // '.'
                        if (next_char == 8'd124) begin // '|'
                            temp_note <= 4'd1;
                            char_idx <= char_idx + 4'd2;
                        end else begin
                            char_idx <= char_idx + 4'd1;
                            next_state <= CHECK_CHAR;
                        end
                        if (next_char == 8'd124) begin
                            next_state <= OUTPUT;
                        end else begin
                            next_state <= CHECK_CHAR;
                        end
                    end else if (current_char == 8'd32) begin // space
                        char_idx <= char_idx + 4'd1;
                        next_state <= SKIP_SPACE;
                    end else begin
                        char_idx <= char_idx + 4'd1;
                        next_state <= CHECK_CHAR;
                    end
                end

                SKIP_SPACE: begin
                    cycle_count <= cycle_count + 4'd1;
                    if (char_idx < str_len) begin
                        current_char <= str_in[(char_idx * 8) +: 8];
                        if (current_char == 8'd32) begin
                            char_idx <= char_idx + 4'd1;
                            next_state <= SKIP_SPACE;
                        end else begin
                            next_state <= CHECK_CHAR;
                        end
                    end else begin
                        next_state <= DONE_STATE;
                    end
                end

                OUTPUT: begin
                    cycle_count <= cycle_count + 4'd1;
                    if (note_idx < 5) begin
                        result[(note_idx * 16) +: 16] <= {12'd0, temp_note};
                        note_idx <= note_idx + 4'd1;
                        note_count <= note_count + 3'd1;
                    end
                    if (char_idx >= str_len || note_idx >= 5) begin
                        next_state <= DONE_STATE;
                    end else begin
                        next_state <= CHECK_CHAR;
                    end
                end

                DONE_STATE: begin
                    done <= 1'b1;
                    next_state <= IDLE;
                end

                default: begin
                    next_state <= IDLE;
                    done <= 1'b0;
                end
            endcase
        end
    end
endmodule