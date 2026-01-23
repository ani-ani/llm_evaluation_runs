module magic_square_test (
    input clk,
    input rst_n, // active-low reset
    input start,
    input [7:0] matrix_cell_i,
    input [3:0] write_addr,
    input write_en,
    output reg result,
    output reg done
);

// Registers
reg [7:0] matrix [15:0];
reg [9:0] sums [9:0];
reg [2:0] state;
reg [3:0] matrix_count;
reg result_int;
reg done_int;

// State definitions
localparam IDLE = 3'd0,
        LOAD_MATRIX = 3'd1,
        COMPUTE_ROWS = 3'd2,
        COMPUTE_COLS = 3'd3,
        COMPUTE_DIAG1 = 3'd4,
        COMPUTE_DIAG2 = 3'd5,
        CHECK_RESULT = 3'd6,
        DONE_STATE = 3'd7;

// Reset
always_ff @(posedge clk)
if (!rst_n) begin
    matrix <= 16'b0;
    sums <= 10'b0;
    state <= IDLE;
    matrix_count <= 4'd0;
    result_int <= 1'b0;
    done_int <= 1'b0;
end
else begin
    case (state)
        IDLE: 
            if (start) begin
                state <= LOAD_MATRIX;
            end else begin
                state <= IDLE;
            end
        LOAD_MATRIX: 
            if (write_en && (write_addr >= 4'd0 && write_addr <= 4'd15)) begin
                matrix[write_addr] <= matrix_cell_i;
                matrix_count <= matrix_count + 1;
            end
            if (matrix_count == 4'd16) begin
                state <= COMPUTE_ROWS;
            end else begin
                state <= LOAD_MATRIX;
            end
        COMPUTE_ROWS: 
            sums[0] = matrix[0] + matrix[1] + matrix[2] + matrix[3];
            sums[1] = matrix[4] + matrix[5] + matrix[6] + matrix[7];
            sums[2] = matrix[8] + matrix[9] + matrix[10] + matrix[11];
            sums[3] = matrix[12] + matrix[13] + matrix[14] + matrix[15];
            state <= COMPUTE_COLS;
        COMPUTE_COLS: 
            sums[4] = matrix[0] + matrix[4] + matrix[8] + matrix[12];
            sums[5] = matrix[1] + matrix[5] + matrix[9] + matrix[13];
            sums[6] = matrix[2] + matrix[6] + matrix[10] + matrix[14];
            sums[7] = matrix[3] + matrix[7] + matrix[11] + matrix[15];
            state <= COMPUTE_DIAG1;
        COMPUTE_DIAG1: 
            sums[8] = matrix[0] + matrix[5] + matrix[10] + matrix[15];
            state <= COMPUTE_DIAG2;
        COMPUTE_DIAG2: 
            sums[9] = matrix[3] + matrix[6] + matrix[9] + matrix[12];
            state <= CHECK_RESULT;
        CHECK_RESULT: 
            result_int = 1'b1;
            if (sums[1] != sums[0]) result_int = 1'b0;
            else if (sums[2] != sums[0]) result_int = 1'b0;
            else if (sums[3] != sums[0]) result_int = 1'b0;
            else if (sums[4] != sums[0]) result_int = 1'b0;
            else if (sums[5] != sums[0]) result_int = 1'b0;
            else if (sums[6] != sums[0]) result_int = 1'b0;
            else if (sums[7] != sums[0]) result_int = 1'b0;
            else if (sums[8] != sums[0]) result_int = 1'b0;
            else if (sums[9] != sums[0]) result_int = 1'b0;
            state <= DONE_STATE;
        DONE_STATE: 
            done_int <= 1'b1;
            state <= IDLE;
    endcase
end

// Outputs
assign result = result_int;
assign done = done_int;

endmodule