module split_string (
    input clk,
    input rst_n,
    input start,
    input [127:0] char_in,
    input [3:0] length,
    output reg [7:0] char_out,
    output reg [3:0] index_out,
    output reg valid,
    output reg done
);

    // State definitions
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] PROCESS = 2'd1;
    localparam [1:0] DONE_STATE = 2'd2;

    // Internal registers
    reg [1:0] state;
    reg [1:0] next_state;
    reg [3:0] count;
    reg [3:0] length_reg;
    reg [127:0] char_buffer;
    reg [3:0] max_index;

    // Next state logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start)
                    next_state = PROCESS;
                else
                    next_state = IDLE;
            end
            PROCESS: begin
                if (count == max_index)
                    next_state = DONE_STATE;
                else
                    next_state = PROCESS;
            end
            DONE_STATE: begin
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

    // State and output logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            char_out <= 8'd0;
            index_out <= 4'd0;
            valid <= 1'b0;
            done <= 1'b0;
            count <= 4'd0;
            length_reg <= 4'd0;
            char_buffer <= 128'd0;
            max_index <= 4'd0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    valid <= 1'b0;
                    char_out <= 8'd0;
                    index_out <= 4'd0;
                    count <= 4'd0;
                    
                    if (start) begin
                        char_buffer <= char_in;
                        // Clamp length to 16 if > 16
                        if (length > 4'd16)
                            length_reg <= 4'd16;
                        else
                            length_reg <= length;
                    end
                end
                
                PROCESS: begin
                    // Calculate which byte to extract based on current count
                    case (count)
                        4'd0: char_out <= char_buffer[7:0];
                        4'd1: char_out <= char_buffer[15:8];
                        4'd2: char_out <= char_buffer[23:16];
                        4'd3: char_out <= char_buffer[31:24];
                        4'd4: char_out <= char_buffer[39:32];
                        4'd5: char_out <= char_buffer[47:40];
                        4'd6: char_out <= char_buffer[55:48];
                        4'd7: char_out <= char_buffer[63:56];
                        4'd8: char_out <= char_buffer[71:64];
                        4'd9: char_out <= char_buffer[79:72];
                        4'd10: char_out <= char_buffer[87:80];
                        4'd11: char_out <= char_buffer[95:88];
                        4'd12: char_out <= char_buffer[103:96];
                        4'd13: char_out <= char_buffer[111:104];
                        4'd14: char_out <= char_buffer[119:112];
                        4'd15: char_out <= char_buffer[127:120];
                        default: char_out <= 8'd0;
                    endcase
                    
                    index_out <= count;
                    valid <= 1'b1;
                    done <= 1'b0;
                    
                    // Set max_index to length-1 (or 0 if length is 0)
                    if (length_reg == 4'd0)
                        max_index <= 4'd0;
                    else
                        max_index <= length_reg - 4'd1;
                    
                    // Increment counter unless at max
                    if (count < max_index)
                        count <= count + 4'd1;
                end
                
                DONE_STATE: begin
                    done <= 1'b1;
                    valid <= 1'b0;
                    char_out <= 8'd0;
                    index_out <= 4'd0;
                    count <= 4'd0;
                end
                
                default: begin
                    state <= IDLE;
                    char_out <= 8'd0;
                    index_out <= 4'd0;
                    valid <= 1'b0;
                    done <= 1'b0;
                    count <= 4'd0;
                end
            endcase
        end
    end

endmodule