module grade_rounding(
    input clk,
    input rst_n,
    input start,
    input [7:0] t,
    input [127:0] input_number_packed,
    output reg [127:0] result_number,
    output reg [7:0] result_length,
    output reg done
);

    localparam ASCII_DOT = 8'h2E;
    localparam ASCII_0 = 8'h30;
    localparam ASCII_9 = 8'h39;
    localparam ASCII_5 = 8'h35;
    localparam ASCII_NUL = 8'h00;

    localparam IDLE = 4'd0;
    localparam FIND_TRIGGER = 4'd1;
    localparam ROUNDING = 4'd2;
    localparam CARRY_PROP = 4'd3;
    localparam FORMAT = 4'd4;
    localparam DONE = 4'd5;

    reg [3:0] state, next_state;
    reg [7:0] t_reg;
    reg [127:0] work_str;
    reg [7:0] cursor;
    reg [7:0] length;
    reg [7:0] scan_idx;
    reg found_dot;
    reg trigger_found;
    reg carry_pending;
    reg [7:0] dot_pos;

    // Combinational Next State Logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) next_state = FIND_TRIGGER;
            end
            FIND_TRIGGER: begin
                if (trigger_found || (scan_idx >= 16)) next_state = ROUNDING;
            end
            ROUNDING: begin
                if (!trigger_found) next_state = FORMAT;
                else if (carry_pending) next_state = CARRY_PROP;
                else if (t_reg == 0) next_state = FORMAT;
                else next_state = ROUNDING;
            end
            CARRY_PROP: begin
                if (carry_pending) next_state = CARRY_PROP;
                else if (t_reg > 0) next_state = ROUNDING;
                else next_state = FORMAT;
            end
            FORMAT: begin
                if ( (length > 0 && work_str[ (15 - (length - 1))*8 +: 8 ] == ASCII_DOT) ||
                     (length > 0 && work_str[ (15 - (length - 1))*8 +: 8 ] == ASCII_0 && (length - 1) > dot_pos) ) begin
                    next_state = FORMAT;
                end else begin
                    next_state = DONE;
                end
            end
            DONE: begin
                if (!start) next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

    // Sequential Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result_number <= 0;
            result_length <= 0;
            done <= 0;
            work_str <= 0;
            t_reg <= 0;
            cursor <= 0;
            length <= 0;
            scan_idx <= 0;
            found_dot <= 0;
            trigger_found <= 0;
            carry_pending <= 0;
            dot_pos <= 0;
        end else begin
            state <= next_state;
            done <= (next_state == DONE);

            case (state)
                IDLE: begin
                    if (start) begin
                        work_str <= input_number_packed;
                        t_reg <= t;
                        scan_idx <= 0;
                        found_dot <= 0;
                        trigger_found <= 0;
                        carry_pending <= 0;
                        length <= 16;
                    end
                end

                FIND_TRIGGER: begin
                    if (scan_idx < 16) begin
                        if (work_str[ (15 - scan_idx)*8 +: 8 ] == ASCII_NUL) begin
                            length <= scan_idx;
                            scan_idx <= 16;
                        end else begin
                            if (!found_dot) begin
                                if (work_str[ (15 - scan_idx)*8 +: 8 ] == ASCII_DOT) begin
                                    found_dot <= 1;
                                    dot_pos <= scan_idx;
                                end
                            end else begin
                                if (work_str[ (15 - scan_idx)*8 +: 8 ] >= ASCII_5) begin
                                    trigger_found <= 1;
                                    cursor <= scan_idx;
                                    scan_idx <= 16;
                                end
                            end
                            if (scan_idx < 15) scan_idx <= scan_idx + 1;
                            else scan_idx <= 16;
                        end
                    end
                end

                ROUNDING: begin
                    if (trigger_found && t_reg > 0 && !carry_pending) begin
                        t_reg <= t_reg - 1;
                        
                        if (cursor == 0) begin
                            t_reg <= 0;
                        end else begin
                            if (work_str[ (15 - (cursor - 1))*8 +: 8 ] == ASCII_DOT) begin
                                cursor <= cursor - 2;
                                length <= cursor - 1;
                                if (work_str[ (15 - (cursor - 2))*8 +: 8 ] == ASCII_9) begin
                                    work_str[ (15 - (cursor - 2))*8 +: 8 ] <= ASCII_0;
                                    carry_pending <= 1;
                                end else begin
                                    work_str[ (15 - (cursor - 2))*8 +: 8 ] <= work_str[ (15 - (cursor - 2))*8 +: 8 ] + 1;
                                    carry_pending <= 0;
                                end
                            end else begin
                                cursor <= cursor - 1;
                                length <= cursor;
                                if (work_str[ (15 - (cursor - 1))*8 +: 8 ] == ASCII_9) begin
                                    work_str[ (15 - (cursor - 1))*8 +: 8 ] <= ASCII_0;
                                    carry_pending <= 1;
                                end else begin
                                    work_str[ (15 - (cursor - 1))*8 +: 8 ] <= work_str[ (15 - (cursor - 1))*8 +: 8 ] + 1;
                                    carry_pending <= 0;
                                end
                            end
                        end
                    end
                end

                CARRY_PROP: begin
                    if (carry_pending) begin
                        if (cursor == 0) begin
                            work_str <= {ASCII_1, work_str[127:8]};
                            length <= length + 1;
                            dot_pos <= dot_pos + 1;
                            carry_pending <= 0;
                            t_reg <= 0;
                            cursor <= 0;
                        end else begin
                            if (work_str[ (15 - (cursor - 1))*8 +: 8 ] == ASCII_DOT) begin
                                cursor <= cursor - 2;
                                length <= cursor - 1;
                                if (work_str[ (15 - (cursor - 2))*8 +: 8 ] == ASCII_9) begin
                                    work_str[ (15 - (cursor - 2))*8 +: 8 ] <= ASCII_0;
                                end else begin
                                    work_str[ (15 - (cursor - 2))*8 +: 8 ] <= work_str[ (15 - (cursor - 2))*8 +: 8 ] + 1;
                                    carry_pending <= 0;
                                end
                            end else begin
                                cursor <= cursor - 1;
                                length <= cursor;
                                if (work_str[ (15 - (cursor - 1))*8 +: 8 ] == ASCII_9) begin
                                    work_str[ (15 - (cursor - 1))*8 +: 8 ] <= ASCII_0;
                                end else begin
                                    work_str[ (15 - (cursor - 1))*8 +: 8 ] <= work_str[ (15 - (cursor - 1))*8 +: 8 ] + 1;
                                    carry_pending <= 0;
                                end
                            end
                        end
                    end
                end

                FORMAT: begin
                    if (length > 0) begin
                        if (work_str[ (15 - (length - 1))*8 +: 8 ] == ASCII_DOT) begin
                            length <= length - 1;
                        end else if (work_str[ (15 - (length - 1))*8 +: 8 ] == ASCII_0 && 
                                   (length - 1) > dot_pos) begin
                            length <= length - 1;
                        end
                    end
                end

                DONE: begin
                    result_number <= work_str;
                    result_length <= length;
                end
            endcase
        end
    end

endmodule