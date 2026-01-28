module PopulatedRowsCounter(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] data [0:7] [0:15],
    output reg [3:0] count,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] LOAD = 3'd1;
    localparam [2:0] CHECK_ROW = 3'd2;
    localparam [2:0] INCREMENT = 3'd3;
    localparam [2:0] NEXT_ROW = 3'd4;
    localparam [2:0] FINISH = 3'd5;

    // Internal registers and variables
    reg [2:0] state;
    reg [3:0] row_index;       // Current row being checked (0-7)
    reg [4:0] col_index;       // Current column being checked (0-15)
    reg row_has_data;          // Flag if current row has non-zero data
    reg [3:0] cycle_count;     // Safety counter for maximum cycles (100)

    // Main sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            count <= 4'd0;
            done <= 1'b0;
            row_index <= 3'd0;
            col_index <= 5'd0;
            row_has_data <= 1'b0;
            cycle_count <= 4'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    count <= 4'd0;
                    row_index <= 3'd0;
                    col_index <= 5'd0;
                    row_has_data <= 1'b0;
                    cycle_count <= 4'd0;
                    
                    if (start) begin
                        state <= CHECK_ROW;
                    end
                end

                CHECK_ROW: begin
                    // Check current column in current row
                    if (data[row_index][col_index] != 8'd0) begin
                        row_has_data <= 1'b1;
                    end
                    
                    col_index <= col_index + 5'd1;
                    
                    // Check if reached end of row
                    if (col_index == 5'd15) begin
                        if (row_has_data) begin
                            state <= INCREMENT;
                        end else begin
                            state <= NEXT_ROW;
                        end
                    end else begin
                        state <= CHECK_ROW;
                    end
                end

                INCREMENT: begin
                    count <= count + 4'd1;
                    row_has_data <= 1'b0;
                    col_index <= 5'd0;
                    state <= NEXT_ROW;
                end

                NEXT_ROW: begin
                    row_has_data <= 1'b0;
                    col_index <= 5'd0;
                    row_index <= row_index + 3'd1;
                    
                    if (row_index == 3'd7) begin
                        state <= FINISH;
                    end else begin
                        state <= CHECK_ROW;
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