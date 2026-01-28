module max_fill(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] grid [0:7],
    input wire [3:0] capacity,
    output reg [15:0] result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE      = 3'd0;
    localparam [2:0] COUNT_ROW = 3'd1;
    localparam [2:0] ADD_DROPS = 3'd2;
    localparam [2:0] NEXT_ROW  = 3'd3;
    localparam [2:0] DONE_STATE = 3'd4;

    // Internal registers
    reg [2:0] state;
    reg [2:0] row_idx;           // 0-7 (3 bits)
    reg [3:0] row_water;         // 0-8 (4 bits)
    reg [3:0] col_idx;           // 0-7 (3 bits)
    reg [9:0] total_drops;       // 0-640 (10 bits)
    reg [7:0] cycle_count;       // Prevent infinite loops
    localparam [7:0] MAX_CYCLES = 8'd100;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            row_idx <= 3'd0;
            row_water <= 4'd0;
            col_idx <= 3'd0;
            total_drops <= 10'd0;
            cycle_count <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= COUNT_ROW;
                        row_idx <= 3'd0;
                        row_water <= 4'd0;
                        col_idx <= 3'd0;
                        total_drops <= 10'd0;
                    end
                end

                COUNT_ROW: begin
                    cycle_count <= cycle_count + 8'd1;
                    if (col_idx < 3'd7) begin
                        if (grid[row_idx][col_idx]) begin
                            row_water <= row_water + 4'd1;
                        end
                        col_idx <= col_idx + 3'd1;
                    end else begin
                        state <= ADD_DROPS;
                    end
                end

                ADD_DROPS: begin
                    cycle_count <= cycle_count + 8'd1;
                    // Compute drops = ceil(row_water / capacity)
                    // Using formula: (row_water + capacity - 1) / capacity
                    reg [7:0] temp_sum;
                    reg [7:0] temp_capacity;
                    temp_sum = row_water + capacity - 4'd1;
                    temp_capacity = capacity;
                    if (temp_capacity == 4'd0) begin
                        temp_capacity = 4'd1;  // Prevent division by zero
                    end
                    total_drops <= total_drops + (temp_sum / temp_capacity);
                    state <= NEXT_ROW;
                end

                NEXT_ROW: begin
                    cycle_count <= cycle_count + 8'd1;
                    if (row_idx < 3'd7) begin
                        row_idx <= row_idx + 3'd1;
                        col_idx <= 3'd0;
                        row_water <= 4'd0;
                        state <= COUNT_ROW;
                    end else begin
                        state <= DONE_STATE;
                    end
                end

                DONE_STATE: begin
                    result <= total_drops;
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: begin
                    state <= IDLE;
                    done <= 1'b0;
                    result <= 16'd0;
                end
            endcase
        end
    end
endmodule