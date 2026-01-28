module MatrixColumnAverages(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [127:0] matrix_in,
    output reg signed [15:0] result_col0,
    output reg signed [15:0] result_col1,
    output reg signed [15:0] result_col2,
    output reg signed [15:0] result_col3,
    output reg done
);

    // State declarations
    localparam [3:0] IDLE    = 4'd0;
    localparam [3:0] COMPUTE = 4'd1;
    localparam [3:0] FINISH  = 4'd2;
    
    reg [3:0] state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd16;

    // Extract columns from packed input
    wire signed [7:0] col0_row0 = matrix_in[7:0];
    wire signed [7:0] col0_row1 = matrix_in[39:32];
    wire signed [7:0] col0_row2 = matrix_in[71:64];
    wire signed [7:0] col0_row3 = matrix_in[103:96];
    
    wire signed [7:0] col1_row0 = matrix_in[15:8];
    wire signed [7:0] col1_row1 = matrix_in[47:40];
    wire signed [7:0] col1_row2 = matrix_in[79:72];
    wire signed [7:0] col1_row3 = matrix_in[111:104];
    
    wire signed [7:0] col2_row0 = matrix_in[23:16];
    wire signed [7:0] col2_row1 = matrix_in[55:48];
    wire signed [7:0] col2_row2 = matrix_in[87:80];
    wire signed [7:0] col2_row3 = matrix_in[119:112];
    
    wire signed [7:0] col3_row0 = matrix_in[31:24];
    wire signed [7:0] col3_row1 = matrix_in[63:56];
    wire signed [7:0] col3_row2 = matrix_in[95:88];
    wire signed [7:0] col3_row3 = matrix_in[127:120];

    // Compute sums
    wire signed [15:0] sum_col0 = col0_row0 + col0_row1 + col0_row2 + col0_row3;
    wire signed [15:0] sum_col1 = col1_row0 + col1_row1 + col1_row2 + col1_row3;
    wire signed [15:0] sum_col2 = col2_row0 + col2_row1 + col2_row2 + col2_row3;
    wire signed [15:0] sum_col3 = col3_row0 + col3_row1 + col3_row2 + col3_row3;

    // Compute averages in Q8.8 format: (sum * 256) / 4 = sum * 64
    wire signed [15:0] avg_col0 = sum_col0 << 6;
    wire signed [15:0] avg_col1 = sum_col1 << 6;
    wire signed [15:0] avg_col2 = sum_col2 << 6;
    wire signed [15:0] avg_col3 = sum_col3 << 6;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result_col0 <= 16'd0;
            result_col1 <= 16'd0;
            result_col2 <= 16'd0;
            result_col3 <= 16'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= COMPUTE;
                    end
                end
                
                COMPUTE: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // After 16 cycles, move to FINISH
                    if (cycle_count >= MAX_CYCLES - 1) begin
                        state <= FINISH;
                    end
                end
                
                FINISH: begin
                    // Output results
                    result_col0 <= avg_col0;
                    result_col1 <= avg_col1;
                    result_col2 <= avg_col2;
                    result_col3 <= avg_col3;
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule