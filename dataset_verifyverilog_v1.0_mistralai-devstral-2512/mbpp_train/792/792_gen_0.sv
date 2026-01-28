module RowCounter(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] data [0:7][0:15],
    output reg [3:0] count,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE    = 3'd0;
    localparam [2:0] COUNT   = 3'd1;
    localparam [2:0] FINISH  = 3'd2;
    
    reg [2:0] state;
    reg [3:0] row_index;
    reg [3:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd100;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            count <= 4'd0;
            done <= 1'b0;
            row_index <= 4'd0;
            cycle_count <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= COUNT;
                        row_index <= 4'd0;
                        count <= 4'd0;
                    end
                end
                
                COUNT: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Check if current row has any non-zero value
                    reg row_has_data;
                    integer j;
                    row_has_data = 1'b0;
                    for (j = 0; j < 16; j = j + 1) begin
                        if (data[row_index][j] != 8'd0) begin
                            row_has_data = 1'b1;
                        end
                    end
                    
                    if (row_has_data) begin
                        count <= count + 4'd1;
                    end
                    
                    // Move to next row
                    row_index <= row_index + 4'd1;
                    
                    // Check if all rows processed or max cycles reached
                    if (row_index == 4'd8 || cycle_count >= MAX_CYCLES) begin
                        state <= FINISH;
                    end
                end
                
                FINISH: begin
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule