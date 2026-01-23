module count_upper(
    input clk,
    input rst_n,
    input start,
    input [7:0] char_in,
    input [3:0] length,
    output reg [3:0] result,
    output reg done
);
    // State declarations
    localparam [1:0] IDLE        = 2'd0;
    localparam [1:0] READING     = 2'd1;
    localparam [1:0] PROCESSING  = 2'd2;
    localparam [1:0] DONE_STATE  = 2'd3;
    
    reg [1:0] state, next_state;
    reg [3:0] index_counter;      // Track current character index (0-15)
    reg [3:0] result_reg;         // Internal result register
    reg [7:0] char_reg;           // Buffer for input character
    
    // State transition logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start)
                    next_state = READING;
                else
                    next_state = IDLE;
            end
            READING: begin
                next_state = PROCESSING;
            end
            PROCESSING: begin
                if (index_counter == length)
                    next_state = DONE_STATE;
                else
                    next_state = READING;
            end
            DONE_STATE: begin
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end
    
    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 4'd0;
            done <= 1'b0;
            index_counter <= 4'd0;
            result_reg <= 4'd0;
            char_reg <= 8'd0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    index_counter <= 4'd0;
                    result_reg <= 4'd0;
                    char_reg <= 8'd0;
                end
                
                READING: begin
                    char_reg <= char_in;
                end
                
                PROCESSING: begin
                    // Check if current index is even
                    if ((index_counter[0] == 1'b0) && (index_counter < length)) begin
                        // Check if character is uppercase vowel
                        if (char_reg == 8'h41 || // 'A'
                            char_reg == 8'h45 || // 'E'
                            char_reg == 8'h49 || // 'I'
                            char_reg == 8'h4F || // 'O'
                            char_reg == 8'h55) begin // 'U'
                            result_reg <= result_reg + 4'd1;
                        end
                    end
                    index_counter <= index_counter + 4'd1;
                end
                
                DONE_STATE: begin
                    result <= result_reg;
                    done <= 1'b1;
                end
                
                default: begin
                    state <= IDLE;
                    result <= 4'd0;
                    done <= 1'b0;
                    index_counter <= 4'd0;
                    result_reg <= 4'd0;
                    char_reg <= 8'd0;
                end
            endcase
        end
    end
endmodule