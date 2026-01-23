module pattern_matcher (
    input clk,
    input rst_n,
    input start,
    input [7:0] str [0:15],
    input [3:0] valid_len,
    output reg result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE  = 2'd0;
    localparam [1:0] SCAN  = 2'd1;
    localparam [1:0] COUNT_B = 2'd2;
    localparam [1:0] DONE  = 2'd3;

    reg [1:0] state, next_state;
    reg [3:0] index;
    reg [2:0] b_count;
    reg found_pattern;
    reg in_ab_sequence;
    reg [7:0] char_data;
    reg [3:0] cycle_counter;
    
    // Character codes
    localparam [7:0] CHAR_A = 8'd97;
    localparam [7:0] CHAR_B = 8'd98;

    // State transition and output logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start)
                    next_state = SCAN;
                else
                    next_state = IDLE;
            end
            
            SCAN: begin
                if (index >= valid_len) begin
                    next_state = DONE;
                end else begin
                    // Check current character
                    if (char_data == CHAR_A && !in_ab_sequence) begin
                        next_state = COUNT_B;
                    end else if (in_ab_sequence && char_data == CHAR_B) begin
                        next_state = COUNT_B;
                    end else if (in_ab_sequence && char_data != CHAR_B) begin
                        // Pattern interrupted by non-b
                        next_state = SCAN;
                    end else begin
                        next_state = SCAN;
                    end
                end
            end
            
            COUNT_B: begin
                if (index >= valid_len) begin
                    next_state = DONE;
                end else begin
                    if (char_data == CHAR_B) begin
                        next_state = COUNT_B;
                    end else begin
                        next_state = SCAN;
                    end
                end
            end
            
            DONE: begin
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end

    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 1'b0;
            done <= 1'b0;
            index <= 4'd0;
            b_count <= 3'd0;
            found_pattern <= 1'b0;
            in_ab_sequence <= 1'b0;
            char_data <= 8'd0;
            cycle_counter <= 4'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    index <= 4'd0;
                    b_count <= 3'd0;
                    found_pattern <= 1'b0;
                    in_ab_sequence <= 1'b0;
                    char_data <= 8'd0;
                    cycle_counter <= 4'd0;
                    if (start) begin
                        if (valid_len == 4'd0) begin
                            state <= DONE;
                        end else begin
                            char_data <= str[0];
                            state <= SCAN;
                            index <= 4'd1;
                        end
                    end
                end
                
                SCAN: begin
                    if (index >= valid_len) begin
                        state <= DONE;
                    end else begin
                        char_data <= str[index];
                        index <= index + 4'd1;
                        cycle_counter <= cycle_counter + 4'd1;
                        
                        if (char_data == CHAR_A && !in_ab_sequence) begin
                            in_ab_sequence <= 1'b1;
                            b_count <= 3'd0;
                            state <= COUNT_B;
                        end else if (in_ab_sequence && char_data == CHAR_B) begin
                            b_count <= b_count + 3'd1;
                            state <= COUNT_B;
                        end else if (in_ab_sequence && char_data != CHAR_B) begin
                            in_ab_sequence <= 1'b0;
                            b_count <= 3'd0;
                            state <= SCAN;
                        end else begin
                            state <= SCAN;
                        end
                    end
                end
                
                COUNT_B: begin
                    if (index >= valid_len) begin
                        // Check pattern at end of string
                        if (in_ab_sequence && (b_count == 3'd2 || b_count == 3'd3)) begin
                            found_pattern <= 1'b1;
                        end
                        state <= DONE;
                    end else begin
                        char_data <= str[index];
                        index <= index + 4'd1;
                        cycle_counter <= cycle_counter + 4'd1;
                        
                        if (char_data == CHAR_B) begin
                            b_count <= b_count + 3'd1;
                            state <= COUNT_B;
                        end else begin
                            // Check if pattern found before non-b
                            if (in_ab_sequence && (b_count == 3'd2 || b_count == 3'd3)) begin
                                found_pattern <= 1'b1;
                            end
                            in_ab_sequence <= 1'b0;
                            b_count <= 3'd0;
                            state <= SCAN;
                        end
                    end
                end
                
                DONE: begin
                    if (!found_pattern && in_ab_sequence && (b_count == 3'd2 || b_count == 3'd3)) begin
                        result <= 1'b1;
                    end else if (found_pattern) begin
                        result <= 1'b1;
                    end else begin
                        result <= 1'b0;
                    end
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end

endmodule