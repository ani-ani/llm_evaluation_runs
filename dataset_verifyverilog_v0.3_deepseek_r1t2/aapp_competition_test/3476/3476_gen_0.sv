module matrix_max_sum #(parameter R=8, C=8)(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire signed [7:0] matrix_in [0:R-1][0:C-1],
    output reg signed [15:0] max_sum,
    output reg [R-1:0] row_mask,
    output reg [C-1:0] col_mask,
    output reg [7:0] op_count,
    output reg done
);
    
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] COMPUTE = 2'd1;
    localparam [1:0] DONE_STATE = 2'd2;
    
    reg [1:0] state;
    reg [7:0] current_row_pattern;
    reg signed [7:0] matrix_reg [0:R-1][0:C-1];
    reg [R-1:0] best_row_mask_reg;
    reg [C-1:0] best_col_mask_reg;
    reg signed [15:0] best_sum_reg;
    reg [7:0] best_op_count_reg;
    
    reg signed [15:0] col_sum [0:C-1];
    reg [C-1:0] current_col_mask;
    reg signed [15:0] current_total_sum;
    reg [7:0] row_ones_current;
    reg [7:0] col_ones_current;
    reg [7:0] op_count_current;
    integer i, j;
    
    always @(*) begin
        for (j = 0; j < C; j = j + 1) col_sum[j] = 0;
        
        for (i = 0; i < R; i = i + 1) begin
            for (j = 0; j < C; j = j + 1) begin
                if (current_row_pattern[i]) 
                    col_sum[j] = col_sum[j] - matrix_reg[i][j];
                else 
                    col_sum[j] = col_sum[j] + matrix_reg[i][j];
            end
        end
        
        current_total_sum = 0;
        for (j = 0; j < C; j = j + 1) begin
            current_col_mask[j] = col_sum[j] < 0;
            current_total_sum = current_col_mask[j] ? 
                current_total_sum - col_sum[j] : current_total_sum + col_sum[j];
        end
    end
    
    always @(*) begin
        row_ones_current = 0;
        for (i = 0; i < R; i = i + 1) 
            row_ones_current = row_ones_current + current_row_pattern[i];
        
        col_ones_current = 0;
        for (j = 0; j < C; j = j + 1) 
            col_ones_current = col_ones_current + current_col_mask[j];
        
        op_count_current = row_ones_current + col_ones_current;
    end
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            max_sum <= 16'd0;
            row_mask <= {R{1'b0}};
            col_mask <= {C{1'b0}};
            op_count <= 8'd0;
            current_row_pattern <= 8'd0;
            best_sum_reg <= -32768;
            best_row_mask_reg <= {R{1'b0}};
            best_col_mask_reg <= {C{1'b0}};
            best_op_count_reg <= 8'd0;
            
            for (i = 0; i < R; i = i + 1) begin
                for (j = 0; j < C; j = j + 1) begin
                    matrix_reg[i][j] <= 8'd0;
                end
            end
        end 
        else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        for (i = 0; i < R; i = i + 1) begin
                            for (j = 0; j < C; j = j + 1) begin
                                matrix_reg[i][j] <= matrix_in[i][j];
                            end
                        end
                        current_row_pattern <= 8'd0;
                        best_sum_reg <= -32768;
                        state <= COMPUTE;
                    end
                end
                
                COMPUTE: begin
                    if (current_total_sum > best_sum_reg) begin
                        best_sum_reg <= current_total_sum;
                        best_row_mask_reg <= current_row_pattern[R-1:0];
                        best_col_mask_reg <= current_col_mask[C-1:0];
                        best_op_count_reg <= op_count_current;
                    end
                    
                    if (current_row_pattern == (1 << R) - 1) state <= DONE_STATE;
                    else current_row_pattern <= current_row_pattern + 8'd1;
                end
                
                DONE_STATE: begin
                    max_sum <= best_sum_reg;
                    row_mask <= best_row_mask_reg;
                    col_mask <= best_col_mask_reg;
                    op_count <= best_op_count_reg;
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule