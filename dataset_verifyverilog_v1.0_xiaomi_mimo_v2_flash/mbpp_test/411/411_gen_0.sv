module snake_to_camel (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] char_in,
    input wire [3:0] char_index,
    input wire input_valid,
    output reg [7:0] char_out,
    output reg [3:0] out_index,
    output reg output_valid,
    output reg done
);

    // Parameters
    localparam [3:0] MAX_LEN = 4'd8;
    localparam [7:0] UNDERSCORE = 8'h5F;
    localparam [7:0] LOWER_A = 8'h61;
    localparam [7:0] LOWER_Z = 8'h7A;
    localparam [7:0] TO_UPPER = 8'h20;
    localparam [7:0] MAX_CYCLES = 8'd200;
    
    // State machine states
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] READ_CHAR = 3'd1;
    localparam [2:0] CHECK_UNDERSCORE = 3'd2;
    localparam [2:0] CAPITALIZE = 3'd3;
    localparam [2:0] OUTPUT_CHAR = 3'd4;
    localparam [2:0] WAIT_DONE = 3'd5;
    
    // Internal registers
    reg [2:0] state, next_state;
    reg [7:0] input_buffer_0;
    reg [7:0] input_buffer_1;
    reg [7:0] input_buffer_2;
    reg [7:0] input_buffer_3;
    reg [7:0] input_buffer_4;
    reg [7:0] input_buffer_5;
    reg [7:0] input_buffer_6;
    reg [7:0] input_buffer_7;
    reg [3:0] in_idx;
    reg [3:0] out_idx;
    reg [3:0] read_count;
    reg capitalize_next;
    reg [7:0] current_char;
    reg [7:0] cycle_count;
    
    // State transition
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end
    
    // Next state logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start)
                    next_state = READ_CHAR;
                else
                    next_state = IDLE;
            end
            
            READ_CHAR: begin
                if (input_valid && read_count < MAX_LEN)
                    next_state = CHECK_UNDERSCORE;
                else if ((!input_valid && read_count > 0) || read_count >= MAX_LEN)
                    next_state = WAIT_DONE;
                else
                    next_state = READ_CHAR;
            end
            
            CHECK_UNDERSCORE: begin
                if (current_char == UNDERSCORE) begin
                    next_state = READ_CHAR;
                end else begin
                    next_state = CAPITALIZE;
                end
            end
            
            CAPITALIZE: begin
                next_state = OUTPUT_CHAR;
            end
            
            OUTPUT_CHAR: begin
                if (out_idx < read_count)
                    next_state = READ_CHAR;
                else
                    next_state = WAIT_DONE;
            end
            
            WAIT_DONE: begin
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end
    
    // Output logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            char_out <= 8'h00;
            out_index <= 4'b0000;
            output_valid <= 1'b0;
            done <= 1'b0;
            in_idx <= 4'b0000;
            out_idx <= 4'b0000;
            read_count <= 4'b0000;
            capitalize_next <= 1'b1;
            cycle_count <= 8'd0;
            input_buffer_0 <= 8'd0;
            input_buffer_1 <= 8'd0;
            input_buffer_2 <= 8'd0;
            input_buffer_3 <= 8'd0;
            input_buffer_4 <= 8'd0;
            input_buffer_5 <= 8'd0;
            input_buffer_6 <= 8'd0;
            input_buffer_7 <= 8'd0;
            current_char <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    output_valid <= 1'b0;
                    done <= 1'b0;
                    in_idx <= 4'b0000;
                    out_idx <= 4'b0000;
                    read_count <= 4'b0000;
                    capitalize_next <= 1'b1;
                    cycle_count <= 8'd0;
                end
                
                READ_CHAR: begin
                    if (input_valid && read_count < MAX_LEN) begin
                        case (in_idx)
                            4'd0: input_buffer_0 <= char_in;
                            4'd1: input_buffer_1 <= char_in;
                            4'd2: input_buffer_2 <= char_in;
                            4'd3: input_buffer_3 <= char_in;
                            4'd4: input_buffer_4 <= char_in;
                            4'd5: input_buffer_5 <= char_in;
                            4'd6: input_buffer_6 <= char_in;
                            4'd7: input_buffer_7 <= char_in;
                            default: begin end
                        endcase
                        current_char <= char_in;
                        in_idx <= in_idx + 4'd1;
                        read_count <= read_count + 4'd1;
                    end
                end
                
                CHECK_UNDERSCORE: begin
                    cycle_count <= cycle_count + 8'd1;
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= WAIT_DONE;
                    end
                end
                
                CAPITALIZE: begin
                    if (capitalize_next && (current_char >= LOWER_A) && (current_char <= LOWER_Z)) begin
                        char_out <= current_char - TO_UPPER;
                    end else begin
                        char_out <= current_char;
                    end
                    capitalize_next <= 1'b0;
                end
                
                OUTPUT_CHAR: begin
                    output_valid <= 1'b1;
                    out_index <= out_idx;
                    out_idx <= out_idx + 4'd1;
                    
                    if (current_char == UNDERSCORE) begin
                        capitalize_next <= 1'b1;
                    end
                    
                    // Read next char from buffer if available
                    if (out_idx < read_count) begin
                        case (out_idx)
                            4'd0: current_char <= input_buffer_0;
                            4'd1: current_char <= input_buffer_1;
                            4'd2: current_char <= input_buffer_2;
                            4'd3: current_char <= input_buffer_3;
                            4'd4: current_char <= input_buffer_4;
                            4'd5: current_char <= input_buffer_5;
                            4'd6: current_char <= input_buffer_6;
                            4'd7: current_char <= input_buffer_7;
                            default: current_char <= 8'd0;
                        endcase
                    end
                end
                
                WAIT_DONE: begin
                    output_valid <= 1'b0;
                    done <= 1'b1;
                end
                
                default: begin
                    char_out <= 8'h00;
                    out_index <= 4'b0000;
                    output_valid <= 1'b0;
                    done <= 1'b0;
                end
            endcase
        end
    end

endmodule