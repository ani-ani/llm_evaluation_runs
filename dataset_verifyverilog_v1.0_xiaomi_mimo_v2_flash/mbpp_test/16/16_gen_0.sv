module text_lowercase_underscore(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] char_array [0:15],
    input wire [3:0] length,
    output reg result,
    output reg done
);

    localparam [2:0] IDLE           = 3'd0;
    localparam [2:0] CHECK_START    = 3'd1;
    localparam [2:0] CHECK_UNDERSCORE = 3'd2;
    localparam [2:0] CHECK_END      = 3'd3;
    localparam [2:0] FINISHED       = 3'd4;

    reg [2:0] state, next_state;
    reg [3:0] pos;
    reg [7:0] current_char;
    reg valid_sofar;
    reg [3:0] i;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            pos <= 4'd0;
            result <= 1'b0;
            done <= 1'b0;
            valid_sofar <= 1'b0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    if (start) begin
                        pos <= 4'd0;
                        valid_sofar <= 1'b1;
                        done <= 1'b0;
                    end
                end
                
                CHECK_START: begin
                    if (pos < length && pos < 16) begin
                        current_char <= char_array[pos];
                    end else begin
                        current_char <= 8'd0;
                    end
                    
                    if (length == 4'd0 || current_char < 8'h61 || current_char > 8'h7a) begin
                        valid_sofar <= 1'b0;
                    end
                    pos <= pos + 1;
                end
                
                CHECK_UNDERSCORE: begin
                    if (pos < length && pos < 16) begin
                        current_char <= char_array[pos];
                    end else begin
                        current_char <= 8'd0;
                    end
                    
                    if (current_char != 8'h5f || pos >= length) begin
                        valid_sofar <= 1'b0;
                    end
                    pos <= pos + 1;
                end
                
                CHECK_END: begin
                    if (pos < length && pos < 16) begin
                        current_char <= char_array[pos];
                    end else begin
                        current_char <= 8'd0;
                    end
                    
                    if (current_char < 8'h61 || current_char > 8'h7a) begin
                        valid_sofar <= 1'b0;
                    end
                    pos <= pos + 1;
                end
                
                FINISHED: begin
                    result <= valid_sofar;
                    done <= 1'b1;
                end
            endcase
        end
    end

    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) next_state = CHECK_START;
            end
            
            CHECK_START: begin
                if (current_char == 8'h5f && pos > 4'd1 && valid_sofar) begin
                    next_state = CHECK_UNDERSCORE;
                end else if (pos >= length) begin
                    next_state = FINISHED;
                end
            end
            
            CHECK_UNDERSCORE: begin
                if (pos >= length) begin
                    next_state = FINISHED;
                end else begin
                    next_state = CHECK_END;
                end
            end
            
            CHECK_END: begin
                if (pos >= length) begin
                    next_state = FINISHED;
                end
            end
            
            FINISHED: begin
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end

endmodule