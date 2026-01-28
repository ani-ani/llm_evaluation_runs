module stellar_counter (
    input clk,
    input rst_n,
    input start,
    input [15:0] row_data [0:7],
    input row_valid,
    output reg [5:0] count,
    output reg done
);
    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] WAIT_ROW = 3'd1;
    localparam [2:0] PROCESS_PIXEL = 3'd2;
    localparam [2:0] NEXT_ROW = 3'd3;
    localparam [2:0] DONE_STATE = 3'd4;
    
    reg [2:0] state, next_state;
    reg [7:0] row_buffer;
    reg [7:0] current_row;
    reg [2:0] row_index;
    reg [2:0] col_index;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            count <= 6'd0;
            row_buffer <= 8'd0;
            current_row <= 8'd0;
            row_index <= 3'd0;
            col_index <= 3'd0;
            done <= 1'b0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        count <= 6'd0;
                        row_buffer <= 8'd0;
                        current_row <= 8'd0;
                        row_index <= 3'd0;
                        col_index <= 3'd0;
                    end
                end
                
                WAIT_ROW: begin
                    if (row_valid)
                        col_index <= 3'd0;
                end
                
                PROCESS_PIXEL: begin
                    if (row_data[col_index] == 16'hFFFF) begin
                        // Check neighbors
                        if ((row_index == 3'd0 || row_buffer[col_index] == 1'b0) && 
                            (col_index == 3'd0 || current_row[col_index - 3'd1] == 1'b0))
                            count <= count + 6'd1;
                        
                        current_row[col_index] <= 1'b1;
                    end else begin
                        current_row[col_index] <= 1'b0;
                    end
                    
                    if (col_index < 3'd7)
                        col_index <= col_index + 3'd1;
                end
                
                NEXT_ROW: begin
                    row_buffer <= current_row;
                    current_row <= 8'd0;
                    if (row_index < 3'd7)
                        row_index <= row_index + 3'd1;
                    else
                        done <= 1'b1;
                end
                
                DONE_STATE: begin
                    done <= 1'b1;
                end
                
                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end
    
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: next_state = start ? WAIT_ROW : IDLE;
            WAIT_ROW: next_state = row_valid ? PROCESS_PIXEL : WAIT_ROW;
            PROCESS_PIXEL: next_state = (col_index >= 3'd7) ? NEXT_ROW : PROCESS_PIXEL;
            NEXT_ROW: next_state = (row_index < 3'd7) ? WAIT_ROW : DONE_STATE;
            DONE_STATE: next_state = DONE_STATE;
            default: next_state = IDLE;
        endcase
    end
endmodule