module char_counter (
    input clk,
    input rst_n,
    input start,
    input [7:0] char_array [0:15],
    input [4:0] str_len,
    output reg [7:0] result,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] CHECK = 3'd1;
    localparam [2:0] INCREMENT = 3'd2;
    localparam [2:0] NEXT_CHAR = 3'd3;
    localparam [2:0] FINISH = 3'd4;

    // Internal registers
    reg [2:0] state;
    reg [2:0] next_state;
    reg [4:0] pos;
    reg [7:0] count;
    reg [7:0] current_char;
    reg [7:0] left_neighbor;
    reg [7:0] right_neighbor;
    reg is_current_vowel;
    reg has_vowel_neighbor;
    reg [7:0] result_reg;
    reg done_reg;

    // Vowel check function (combinational)
    function automatic is_vowel;
        input [7:0] ch;
        begin
            case (ch)
                8'd97, 8'd101, 8'd105, 8'd111, 8'd117: is_vowel = 1'b1;
                default: is_vowel = 1'b0;
            endcase
        end
    endfunction

    // Combinational logic for checking
    always @(*) begin
        // Get current character
        current_char = char_array[pos];
        
        // Get left neighbor (if exists)
        if (pos > 5'd0) begin
            left_neighbor = char_array[pos - 5'd1];
        end else begin
            left_neighbor = 8'd0;
        end
        
        // Get right neighbor (if exists)
        if (pos < str_len - 5'd1) begin
            right_neighbor = char_array[pos + 5'd1];
        end else begin
            right_neighbor = 8'd0;
        end
        
        // Check if current is vowel
        is_current_vowel = is_vowel(current_char);
        
        // Check if at least one neighbor is vowel
        has_vowel_neighbor = is_vowel(left_neighbor) | is_vowel(right_neighbor);
    end

    // State transition logic
    always @(*) begin
        case (state)
            IDLE: next_state = start ? CHECK : IDLE;
            CHECK: begin
                if (!is_current_vowel && has_vowel_neighbor) begin
                    next_state = INCREMENT;
                end else begin
                    next_state = NEXT_CHAR;
                end
            end
            INCREMENT: next_state = NEXT_CHAR;
            NEXT_CHAR: begin
                if (pos < str_len - 5'd1) begin
                    next_state = CHECK;
                end else begin
                    next_state = FINISH;
                end
            end
            FINISH: next_state = IDLE;
            default: next_state = IDLE;
        endcase
    end

    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            pos <= 5'd0;
            count <= 8'd0;
            result_reg <= 8'd0;
            done_reg <= 1'b0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done_reg <= 1'b0;
                    if (start) begin
                        pos <= 5'd0;
                        count <= 8'd0;
                    end
                end
                
                CHECK: begin
                    // No action needed, combinational logic handles it
                end
                
                INCREMENT: begin
                    count <= count + 8'd1;
                end
                
                NEXT_CHAR: begin
                    if (pos < str_len - 5'd1) begin
                        pos <= pos + 5'd1;
                    end
                end
                
                FINISH: begin
                    result_reg <= count;
                    done_reg <= 1'b1;
                end
                
                default: begin
                    state <= IDLE;
                    pos <= 5'd0;
                    count <= 8'd0;
                    result_reg <= 8'd0;
                    done_reg <= 1'b0;
                end
            endcase
        end
    end

    // Assign outputs
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            result <= 8'd0;
            done <= 1'b0;
        end else begin
            result <= result_reg;
            done <= done_reg;
        end
    end

endmodule