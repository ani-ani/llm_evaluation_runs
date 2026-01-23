module remove_parenthesis (
    input clk,
    input rst_n,
    input start,
    input [7:0] char_in,
    input char_valid,
    output reg [7:0] char_out,
    output reg char_out_valid,
    output reg done
);

    // State encoding
    localparam IDLE = 2'b00;
    localparam COPY_CHAR = 2'b01;
    localparam SKIP_CHARS = 2'b10;
    localparam DONE = 2'b11;

    reg [1:0] current_state;
    reg [1:0] next_state;

    // State register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            current_state <= IDLE;
        else
            current_state <= next_state;
    end

    // Next state logic
    always @(*) begin
        case (current_state)
            IDLE: begin
                if (start)
                    next_state = COPY_CHAR;
                else
                    next_state = IDLE;
            end
            COPY_CHAR: begin
                if (char_valid) begin
                    if (char_in == 8'h28) // '(' character
                        next_state = SKIP_CHARS;
                    else if (char_in == 8'h00) // Null terminator
                        next_state = DONE;
                    else
                        next_state = COPY_CHAR;
                end else begin
                    next_state = COPY_CHAR;
                end
            end
            SKIP_CHARS: begin
                if (char_valid) begin
                    if (char_in == 8'h29) // ')' character
                        next_state = COPY_CHAR;
                    else if (char_in == 8'h00) // Null terminator
                        next_state = DONE;
                    else
                        next_state = SKIP_CHARS;
                end else begin
                    next_state = SKIP_CHARS;
                end
            end
            DONE: begin
                next_state = DONE; // Stay done until reset
            end
            default: next_state = IDLE;
        endcase
    end

    // Output logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            char_out <= 8'h00;
            char_out_valid <= 1'b0;
            done <= 1'b0;
        end else begin
            case (current_state)
                IDLE: begin
                    char_out_valid <= 1'b0;
                    done <= 1'b0;
                    // Don't care about char_out value here
                end
                COPY_CHAR: begin
                    if (char_valid) begin
                        if (char_in == 8'h28) begin // '(' found, transitioning to SKIP_CHARS
                            char_out_valid <= 1'b0;
                            done <= 1'b0;
                        end else if (char_in == 8'h00) begin // Null found, transitioning to DONE
                            char_out <= 8'h00;
                            char_out_valid <= 1'b1; // Output the null terminator
                            done <= 1'b1;
                        end else begin // Normal character copy
                            char_out <= char_in;
                            char_out_valid <= 1'b1;
                            done <= 1'b0;
                        end
                    end else begin
                        char_out_valid <= 1'b0;
                        done <= 1'b0;
                    end
                end
                SKIP_CHARS: begin
                    if (char_valid) begin
                        if (char_in == 8'h29) begin // ')' found, transitioning to COPY_CHAR
                            char_out_valid <= 1'b0;
                            done <= 1'b0;
                        end else if (char_in == 8'h00) begin // Null found, transitioning to DONE
                            char_out <= 8'h00;
                            char_out_valid <= 1'b1; // Output the null terminator
                            done <= 1'b1;
                        end else begin // Skipped character
                            char_out_valid <= 1'b0;
                            done <= 1'b0;
                        end
                    end else begin
                        char_out_valid <= 1'b0;
                        done <= 1'b0;
                    end
                end
                DONE: begin
                    // Outputs are held from the transition cycle
                    // done stays high, char_out_valid was set to 1 (for null) or 0 (if input ended mid-skip)
                    // Actually, we set done=1 on transition. We keep it high.
                    // char_out_valid logic for DONE state is handled by default values or the transition logic.
                    // In this cycle (after entering DONE), we might want to hold values or reset valid.
                    // Requirement says: done goes high after null processed.
                    // It implies char_out_valid is 1 only for valid chars.
                    // The previous state logic handles the specific cycle.
                    // Here we just ensure done stays high.
                    done <= 1'b1;
                end
            endcase
        end
    end

endmodule
