module magic_square_checker(
    input clk,
    input rst_n,
    input start,
    input [127:0] matrix,
    output reg result,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE      = 3'd0;
    localparam [2:0] ROW_SUM   = 3'd1;
    localparam [2:0] COL_SUM   = 3'd2;
    localparam [2:0] DIAG_SUM  = 3'd3;
    localparam [2:0] COMPARE   = 3'd4;
    localparam [2:0] DONE_STATE = 3'd5;

    // Internal registers
    reg [2:0] state, next_state;
    reg [15:0] row_sums [0:3];
    reg [15:0] col_sums [0:3];
    reg [15:0] diag_main, diag_anti;
    reg [3:0] row_idx, col_idx;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd200;

    // Extract matrix elements
    wire [7:0] m00 = matrix[7:0];
    wire [7:0] m01 = matrix[15:8];
    wire [7:0] m02 = matrix[23:16];
    wire [7:0] m03 = matrix[31:24];
    wire [7:0] m10 = matrix[39:32];
    wire [7:0] m11 = matrix[47:40];
    wire [7:0] m12 = matrix[55:48];
    wire [7:0] m13 = matrix[63:56];
    wire [7:0] m20 = matrix[71:64];
    wire [7:0] m21 = matrix[79:72];
    wire [7:0] m22 = matrix[87:80];
    wire [7:0] m23 = matrix[95:88];
    wire [7:0] m30 = matrix[103:96];
    wire [7:0] m31 = matrix[111:104];
    wire [7:0] m32 = matrix[119:112];
    wire [7:0] m33 = matrix[127:120];

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            result <= 1'b0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            row_idx <= 4'd0;
            col_idx <= 4'd0;
            
            // Initialize all sums
            row_sums[0] <= 16'd0;
            row_sums[1] <= 16'd0;
            row_sums[2] <= 16'd0;
            row_sums[3] <= 16'd0;
            col_sums[0] <= 16'd0;
            col_sums[1] <= 16'd0;
            col_sums[2] <= 16'd0;
            col_sums[3] <= 16'd0;
            diag_main <= 16'd0;
            diag_anti <= 16'd0;
        end else begin
            state <= next_state;
            cycle_count <= cycle_count + 8'd1;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        next_state <= ROW_SUM;
                        row_idx <= 4'd0;
                        col_idx <= 4'd0;
                        cycle_count <= 8'd0;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                ROW_SUM: begin
                    // Compute row sums
                    if (row_idx == 4'd0) begin
                        row_sums[0] <= m00 + m01 + m02 + m03;
                    end else if (row_idx == 4'd1) begin
                        row_sums[1] <= m10 + m11 + m12 + m13;
                    end else if (row_idx == 4'd2) begin
                        row_sums[2] <= m20 + m21 + m22 + m23;
                    end else if (row_idx == 4'd3) begin
                        row_sums[3] <= m30 + m31 + m32 + m33;
                    end
                    
                    if (row_idx == 4'd3) begin
                        next_state <= COL_SUM;
                        col_idx <= 4'd0;
                    end else begin
                        row_idx <= row_idx + 4'd1;
                    end
                end

                COL_SUM: begin
                    // Compute column sums
                    if (col_idx == 4'd0) begin
                        col_sums[0] <= m00 + m10 + m20 + m30;
                    end else if (col_idx == 4'd1) begin
                        col_sums[1] <= m01 + m11 + m21 + m31;
                    end else if (col_idx == 4'd2) begin
                        col_sums[2] <= m02 + m12 + m22 + m32;
                    end else if (col_idx == 4'd3) begin
                        col_sums[3] <= m03 + m13 + m23 + m33;
                    end
                    
                    if (col_idx == 4'd3) begin
                        next_state <= DIAG_SUM;
                    end else begin
                        col_idx <= col_idx + 4'd1;
                    end
                end

                DIAG_SUM: begin
                    // Compute diagonal sums
                    diag_main <= m00 + m11 + m22 + m33;
                    diag_anti <= m03 + m12 + m21 + m30;
                    next_state <= COMPARE;
                end

                COMPARE: begin
                    // Compare all sums to row_sums[0]
                    result <= 1'b1;
                    
                    if (row_sums[1] != row_sums[0]) result <= 1'b0;
                    if (row_sums[2] != row_sums[0]) result <= 1'b0;
                    if (row_sums[3] != row_sums[0]) result <= 1'b0;
                    if (col_sums[0] != row_sums[0]) result <= 1'b0;
                    if (col_sums[1] != row_sums[0]) result <= 1'b0;
                    if (col_sums[2] != row_sums[0]) result <= 1'b0;
                    if (col_sums[3] != row_sums[0]) result <= 1'b0;
                    if (diag_main != row_sums[0]) result <= 1'b0;
                    if (diag_anti != row_sums[0]) result <= 1'b0;
                    
                    next_state <= DONE_STATE;
                end

                DONE_STATE: begin
                    done <= 1'b1;
                    next_state <= IDLE;
                end

                default: begin
                    next_state <= IDLE;
                    done <= 1'b0;
                    result <= 1'b0;
                end
            endcase
            
            // Safety: prevent infinite loops
            if (cycle_count >= MAX_CYCLES) begin
                next_state <= IDLE;
                done <= 1'b1;
                result <= 1'b0;
            end
        end
    end

endmodule