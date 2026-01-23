module array3x3_mult(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire signed [15:0] matrix_a [0:2][0:2],
    input wire signed [15:0] matrix_b [0:2][0:2],
    output reg signed [31:0] result_matrix [0:2][0:2],
    output reg done
);

    // State machine states
    reg [2:0] state;
    localparam IDLE = 3'b000;
    localparam COMPUTE_ROW0 = 3'b001;
    localparam COMPUTE_ROW1 = 3'b010;
    localparam COMPUTE_ROW2 = 3'b011;
    localparam FINISH = 3'b100;
    
    // Internal counters and registers
    reg [1:0] row, col, k;
    reg signed [31:0] sum;
    
    integer i, j;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset all registers
            state <= IDLE;
            done <= 1'b0;
            row <= 2'b0;
            col <= 2'b0;
            k <= 2'b0;
            sum <= 32'sd0;
            for (i = 0; i < 3; i = i + 1) begin
                for (j = 0; j < 3; j = j + 1) begin
                    result_matrix[i][j] <= 32'sd0;
                end
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= COMPUTE_ROW0;
                        row <= 2'b0;
                        col <= 2'b0;
                        k <= 2'b0;
                        sum <= 32'sd0;
                    end
                end
                
                COMPUTE_ROW0: begin
                    if (col < 2'd3 && k < 2'd3) begin
                        sum <= sum + matrix_a[row][k] * matrix_b[k][col];
                        k <= k + 2'd1;
                    end else if (col < 2'd3) begin
                        result_matrix[row][col] <= sum;
                        col <= col + 2'd1;
                        sum <= 32'sd0;
                        k <= 2'd0;
                    end else begin
                        row <= row + 2'd1;
                        col <= 2'd0;
                        sum <= 32'sd0;
                        k <= 2'd0;
                        state <= COMPUTE_ROW1;
                    end
                end
                
                COMPUTE_ROW1: begin
                    if (col < 2'd3 && k < 2'd3) begin
                        sum <= sum + matrix_a[row][k] * matrix_b[k][col];
                        k <= k + 2'd1;
                    end else if (col < 2'd3) begin
                        result_matrix[row][col] <= sum;
                        col <= col + 2'd1;
                        sum <= 32'sd0;
                        k <= 2'd0;
                    end else begin
                        row <= row + 2'd1;
                        col <= 2'd0;
                        sum <= 32'sd0;
                        k <= 2'd0;
                        state <= COMPUTE_ROW2;
                    end
                end
                
                COMPUTE_ROW2: begin
                    if (col < 2'd3 && k < 2'd3) begin
                        sum <= sum + matrix_a[row][k] * matrix_b[k][col];
                        k <= k + 2'd1;
                    end else if (col < 2'd3) begin
                        result_matrix[row][col] <= sum;
                        col <= col + 2'd1;
                        sum <= 32'sd0;
                        k <= 2'd0;
                    end else begin
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