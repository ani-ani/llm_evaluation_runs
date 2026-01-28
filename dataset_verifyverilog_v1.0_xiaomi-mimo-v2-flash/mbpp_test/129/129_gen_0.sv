module magic_square_checker (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [127:0] matrix,  // 16 elements * 8 bits
    output reg result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] ROW_SUM = 3'd1;
    localparam [2:0] COL_SUM = 3'd2;
    localparam [2:0] DIAG_SUM = 3'd3;
    localparam [2:0] COMPARE = 3'd4;
    localparam [2:0] FINISH = 3'd5;

    // Internal registers
    reg [2:0] state, next_state;
    reg [15:0] row_sums [0:3];  // 4 row sums
    reg [15:0] col_sums [0:3];  // 4 column sums
    reg [15:0] diag_main;       // main diagonal sum
    reg [15:0] diag_anti;       // anti-diagonal sum
    reg [3:0] index;            // index for rows/columns
    reg [3:0] elem_idx;         // index for matrix elements
    reg [15:0] sum_temp;        // temporary sum accumulator
    reg [15:0] target_sum;      // reference sum (row 0)
    reg all_equal;              // comparison result
    reg [7:0] cycle_count;      // cycle counter
    localparam [7:0] MAX_CYCLES = 8'd200;

    // Matrix element extraction helper (combinational)
    wire [7:0] matrix_elem [0:15];
    assign matrix_elem[0] = matrix[7:0];
    assign matrix_elem[1] = matrix[15:8];
    assign matrix_elem[2] = matrix[23:16];
    assign matrix_elem[3] = matrix[31:24];
    assign matrix_elem[4] = matrix[39:32];
    assign matrix_elem[5] = matrix[47:40];
    assign matrix_elem[6] = matrix[55:48];
    assign matrix_elem[7] = matrix[63:56];
    assign matrix_elem[8] = matrix[71:64];
    assign matrix_elem[9] = matrix[79:72];
    assign matrix_elem[10] = matrix[87:80];
    assign matrix_elem[11] = matrix[95:88];
    assign matrix_elem[12] = matrix[103:96];
    assign matrix_elem[13] = matrix[111:104];
    assign matrix_elem[14] = matrix[119:112];
    assign matrix_elem[15] = matrix[127:120];

    // State transition
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 1'b0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            index <= 4'd0;
            elem_idx <= 4'd0;
            sum_temp <= 16'd0;
            target_sum <= 16'd0;
            diag_main <= 16'd0;
            diag_anti <= 16'd0;
            all_equal <= 1'b1;
            // Initialize all row and column sums
            row_sums[0] <= 16'd0;
            row_sums[1] <= 16'd0;
            row_sums[2] <= 16'd0;
            row_sums[3] <= 16'd0;
            col_sums[0] <= 16'd0;
            col_sums[1] <= 16'd0;
            col_sums[2] <= 16'd0;
            col_sums[3] <= 16'd0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    result <= 1'b0;
                    cycle_count <= 8'd0;
                    index <= 4'd0;
                    elem_idx <= 4'd0;
                    sum_temp <= 16'd0;
                    target_sum <= 16'd0;
                    all_equal <= 1'b1;
                end
                
                ROW_SUM: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Accumulate row sum
                    sum_temp <= sum_temp + matrix_elem[elem_idx];
                    elem_idx <= elem_idx + 4'd1;
                    
                    // Store row sum when row complete
                    if ((elem_idx % 4) == 3) begin
                        if (index == 4'd0) begin
                            target_sum <= sum_temp + matrix_elem[elem_idx];
                            row_sums[index] <= sum_temp + matrix_elem[elem_idx];
                        end else begin
                            row_sums[index] <= sum_temp + matrix_elem[elem_idx];
                        end
                        sum_temp <= 16'd0;
                        index <= index + 4'd1;
                    end
                    
                    if (elem_idx == 15) begin
                        index <= 4'd0;
                        elem_idx <= 4'd0;
                        sum_temp <= 16'd0;
                    end
                end
                
                COL_SUM: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Accumulate column sum
                    sum_temp <= sum_temp + matrix_elem[elem_idx];
                    
                    // Move to next element in column (skip 4 rows)
                    if (elem_idx < 12) begin
                        elem_idx <= elem_idx + 4'd4;
                    end else begin
                        // Column complete
                        col_sums[index] <= sum_temp + matrix_elem[elem_idx];
                        index <= index + 4'd1;
                        elem_idx <= index + 4'd1;  // Start next column
                        sum_temp <= 16'd0;
                    end
                    
                    if (index == 4'd4) begin
                        index <= 4'd0;
                        elem_idx <= 4'd0;
                        sum_temp <= 16'd0;
                    end
                end
                
                DIAG_SUM: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Main diagonal: 0,5,10,15
                    diag_main <= matrix_elem[0] + matrix_elem[5] + matrix_elem[10] + matrix_elem[15];
                    // Anti-diagonal: 3,6,9,12
                    diag_anti <= matrix_elem[3] + matrix_elem[6] + matrix_elem[9] + matrix_elem[12];
                end
                
                COMPARE: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Check all sums against target_sum
                    if ((row_sums[0] == target_sum) &&
                        (row_sums[1] == target_sum) &&
                        (row_sums[2] == target_sum) &&
                        (row_sums[3] == target_sum) &&
                        (col_sums[0] == target_sum) &&
                        (col_sums[1] == target_sum) &&
                        (col_sums[2] == target_sum) &&
                        (col_sums[3] == target_sum) &&
                        (diag_main == target_sum) &&
                        (diag_anti == target_sum)) begin
                        all_equal <= 1'b1;
                    end else begin
                        all_equal <= 1'b0;
                    end
                end
                
                FINISH: begin
                    done <= 1'b1;
                    result <= all_equal;
                end
                
                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

    // Next state logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start) next_state = ROW_SUM;
                else next_state = IDLE;
            end
            
            ROW_SUM: begin
                if (elem_idx == 15 && index == 4'd4) next_state = COL_SUM;
                else next_state = ROW_SUM;
            end
            
            COL_SUM: begin
                if (index == 4'd4) next_state = DIAG_SUM;
                else next_state = COL_SUM;
            end
            
            DIAG_SUM: begin
                next_state = COMPARE;
            end
            
            COMPARE: begin
                next_state = FINISH;
            end
            
            FINISH: begin
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
        
        // Safety: prevent infinite loops
        if (cycle_count >= MAX_CYCLES) begin
            next_state = FINISH;
        end
    end

endmodule