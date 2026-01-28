module snake_to_camel_case (
    input clk,
    input rst_n,
    input start,
    input [7:0] str_in [0:15],
    input [3:0] len_in,
    output reg [7:0] str_out [0:15],
    output reg [3:0] len_out,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE       = 3'd0;
    localparam [2:0] FETCH      = 3'd1;
    localparam [2:0] CAPITALIZE = 3'd2;
    localparam [2:0] WRITE      = 3'd3;
    localparam [2:0] DONE_STATE = 3'd4;
    localparam [2:0] FINISH     = 3'd5;

    // Registers
    reg [2:0] state;
    reg [2:0] next_state;
    reg [3:0] in_idx;
    reg [3:0] out_idx;
    reg prev_was_underscore;
    reg capitalize_next;
    reg [7:0] current_char;
    reg [7:0] modified_char;
    reg [3:0] input_len_counter;
    reg [5:0] cycle_count;
    localparam [5:0] MAX_CYCLES = 6'd64;
    integer i;

    // Next state logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start)
                    next_state = FETCH;
                else
                    next_state = IDLE;
            end
            FETCH: begin
                next_state = CAPITALIZE;
            end
            CAPITALIZE: begin
                if (current_char == 8'h5F) // Underscore
                    next_state = FETCH;
                else
                    next_state = WRITE;
            end
            WRITE: begin
                if (input_len_counter >= len_in || out_idx >= 4'd15)
                    next_state = DONE_STATE;
                else
                    next_state = FETCH;
            end
            DONE_STATE: begin
                next_state = FINISH;
            end
            FINISH: begin
                next_state = IDLE;
            end
            default: begin
                next_state = IDLE;
            end
        endcase
    end

    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            len_out <= 4'd0;
            in_idx <= 4'd0;
            out_idx <= 4'd0;
            prev_was_underscore <= 1'b1; // First char should be capitalized
            capitalize_next <= 1'b0;
            current_char <= 8'd0;
            modified_char <= 8'd0;
            input_len_counter <= 4'd0;
            cycle_count <= 6'd0;
            for (i = 0; i < 16; i = i + 1) begin
                str_out[i] <= 8'd0;
            end
        end else begin
            cycle_count <= cycle_count + 6'd1;
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    in_idx <= 4'd0;
                    out_idx <= 4'd0;
                    prev_was_underscore <= 1'b1;
                    capitalize_next <= 1'b0;
                    input_len_counter <= 4'd0;
                    cycle_count <= 6'd0;
                end
                FETCH: begin
                    if (input_len_counter < len_in) begin
                        current_char <= str_in[in_idx];
                    end else begin
                        current_char <= 8'd0;
                    end
                end
                CAPITALIZE: begin
                    if (current_char == 8'h5F) begin
                        // Underscore detected
                        prev_was_underscore <= 1'b1;
                        capitalize_next <= 1'b1;
                        in_idx <= in_idx + 4'd1;
                        input_len_counter <= input_len_counter + 4'd1;
                    end else begin
                        // Not underscore
                        if (prev_was_underscore || input_len_counter == 4'd0) begin
                            // Capitalize if lowercase a-z
                            if (current_char >= 8'h61 && current_char <= 8'h7A) begin
                                modified_char <= current_char - 8'd32;
                            end else begin
                                modified_char <= current_char;
                            end
                            prev_was_underscore <= 1'b0;
                        end else begin
                            // Keep as is
                            modified_char <= current_char;
                        end
                        in_idx <= in_idx + 4'd1;
                        input_len_counter <= input_len_counter + 4'd1;
                    end
                end
                WRITE: begin
                    if (current_char != 8'h5F) begin
                        if (out_idx < 4'd15) begin
                            str_out[out_idx] <= modified_char;
                            out_idx <= out_idx + 4'd1;
                        end
                    end
                end
                DONE_STATE: begin
                    len_out <= out_idx;
                end
                FINISH: begin
                    done <= 1'b1;
                end
                default: begin
                    state <= IDLE;
                end
            endcase
            
            // State transition
            state <= next_state;
        end
    end

endmodule