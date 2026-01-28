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

    // State declarations
    localparam [2:0] IDLE    = 3'd0;
    localparam [2:0] PROCESS = 3'd1;
    localparam [2:0] DONE_STATE = 3'd2;

    reg [2:0] state, next_state;
    reg [3:0] current_index;
    reg [127:0] char_in_reg;
    reg [3:0] length_reg;
    reg start_reg;

    // Clamp length to 16 if greater
    wire [3:0] clamped_length = (length > 4'd16) ? 4'd16 : length;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            current_index <= 4'd0;
            char_out <= 8'd0;
            index_out <= 4'd0;
            valid <= 1'b0;
            done <= 1'b0;
            char_in_reg <= 128'd0;
            length_reg <= 4'd0;
            start_reg <= 1'b0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    valid <= 1'b0;
                    done <= 1'b0;
                    if (start) begin
                        char_in_reg <= char_in;
                        length_reg <= clamped_length;
                        start_reg <= 1'b1;
                        current_index <= 4'd0;
                    end
                end
                
                PROCESS: begin
                    if (start_reg) begin
                        // Extract character
                        char_out <= char_in_reg[(current_index * 8) + 7 : current_index * 8];
                        index_out <= current_index;
                        valid <= 1'b1;
                        
                        // Check if last character
                        if (current_index == length_reg - 1) begin
                            next_state <= DONE_STATE;
                        end else begin
                            current_index <= current_index + 1'b1;
                        end
                    end
                end
                
                DONE_STATE: begin
                    done <= 1'b1;
                    valid <= 1'b0;
                    char_out <= 8'd0;
                    index_out <= 4'd0;
                    start_reg <= 1'b0;
                end
                
                default: begin
                    state <= IDLE;
                    valid <= 1'b0;
                    done <= 1'b0;
                    char_out <= 8'd0;
                    index_out <= 4'd0;
                    start_reg <= 1'b0;
                end
            endcase
        end
    end

    // Next state logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = PROCESS;
                end else begin
                    next_state = IDLE;
                end
            end
            
            PROCESS: begin
                if (current_index == length_reg - 1) begin
                    next_state = DONE_STATE;
                end else begin
                    next_state = PROCESS;
                end
            end
            
            DONE_STATE: next_state = IDLE;
            
            default: next_state = IDLE;
        endcase
    end

endmodule