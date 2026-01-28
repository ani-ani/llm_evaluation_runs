module max_fill (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] grid [0:7],
    input wire [3:0] capacity,
    output reg [15:0] result,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE       = 3'd0;
    localparam [2:0] COUNT_ROW  = 3'd1;
    localparam [2:0] ADD_DROPS  = 3'd2;
    localparam [2:0] NEXT_ROW   = 3'd3;
    localparam [2:0] DONE_STATE = 3'd4;
    
    // Internal registers
    reg [2:0] state;
    reg [2:0] row_index;        // 0-7
    reg [3:0] row_water;        // 0-8 (count of bits in current row)
    reg [3:0] col_index;        // 0-7 for column iteration
    reg [15:0] drops_total;     // Accumulated drops
    reg [3:0] capacity_reg;     // Registered capacity
    reg [7:0] current_row;      // Current row data
    reg [15:0] drops_temp;      // Temporary for division
    
    // State transition logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            row_index <= 3'd0;
            row_water <= 4'd0;
            col_index <= 4'd0;
            drops_total <= 16'd0;
            capacity_reg <= 4'd0;
            current_row <= 8'd0;
            drops_temp <= 16'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        row_index <= 3'd0;
                        row_water <= 4'd0;
                        col_index <= 4'd0;
                        drops_total <= 16'd0;
                        capacity_reg <= capacity;
                        current_row <= grid[0];
                        state <= COUNT_ROW;
                    end
                end
                
                COUNT_ROW: begin
                    if (col_index < 4'd8) begin
                        // Count set bits in current row
                        if (current_row[col_index]) begin
                            row_water <= row_water + 4'd1;
                        end
                        col_index <= col_index + 4'd1;
                    end else begin
                        col_index <= 4'd0;
                        state <= ADD_DROPS;
                    end
                end
                
                ADD_DROPS: begin
                    // Calculate ceil(row_water / capacity) = (row_water + capacity - 1) / capacity
                    drops_temp <= (row_water + capacity_reg - 4'd1) / capacity_reg;
                    state <= NEXT_ROW;
                end
                
                NEXT_ROW: begin
                    // Accumulate drops
                    drops_total <= drops_total + drops_temp;
                    row_index <= row_index + 3'd1;
                    
                    if (row_index < 3'd7) begin
                        // Move to next row
                        row_index <= row_index + 3'd1;
                        row_water <= 4'd0;
                        col_index <= 4'd0;
                        current_row <= grid[row_index + 3'd1];
                        state <= COUNT_ROW;
                    end else begin
                        // All rows processed
                        state <= DONE_STATE;
                    end
                end
                
                DONE_STATE: begin
                    result <= drops_total;
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end

endmodule