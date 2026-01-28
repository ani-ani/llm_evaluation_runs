module GraphEvenParitySolver (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] node_count,
    input wire [5:0] edge_count,
    input wire [3:0] edge_a [0:31],
    input wire [3:0] edge_b [0:31],
    output reg [31:0] result,
    output reg done,
    output reg valid
);

    // Constants
    localparam [31:0] MOD = 32'h3B9ACA69;
    localparam [5:0] MAX_EDGES = 6'd32;
    localparam [3:0] MAX_NODES = 4'd16;
    
    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] BUILD_MATRIX = 3'd1;
    localparam [2:0] GAUSSIAN = 3'd2;
    localparam [2:0] COUNT_RANK = 3'd3;
    localparam [2:0] COMPUTE_RESULT = 3'd4;
    localparam [2:0] OUTPUT_RESULT = 3'd5;
    
    reg [2:0] state;
    reg [2:0] next_state;
    
    // Matrix storage: 16 rows (nodes) x 32 columns (edges)
    // Transposed: each row is a 32-bit vector representing edges for that node
    reg [31:0] matrix [0:15];
    reg [31:0] row_pivot;
    
    // Control registers
    reg [5:0] edge_idx;
    reg [3:0] row_idx;
    reg [3:0] pivot_row;
    reg [5:0] rank;
    reg [5:0] shift_val;
    
    // Result calculation registers
    reg [31:0] pow2_table [0:31];
    reg [31:0] pow2_result;
    reg [31:0] temp_mult;
    reg [1:0] mult_step;
    
    // Helper signals
    wire [31:0] row_xor;
    wire [31:0] pivot_mask;
    
    // Initialize pow2 table (combinational)
    integer i;
    always @(*) begin
        pow2_table[0] = 32'd1;
        pow2_table[1] = 32'd2;
        pow2_table[2] = 32'd4;
        pow2_table[3] = 32'd8;
        pow2_table[4] = 32'd16;
        pow2_table[5] = 32'd32;
        pow2_table[6] = 32'd64;
        pow2_table[7] = 32'd128;
        pow2_table[8] = 32'd256;
        pow2_table[9] = 32'd512;
        pow2_table[10] = 32'd1024;
        pow2_table[11] = 32'd2048;
        pow2_table[12] = 32'd4096;
        pow2_table[13] = 32'd8192;
        pow2_table[14] = 32'd16384;
        pow2_table[15] = 32'd32768;
        pow2_table[16] = 32'd65536;
        pow2_table[17] = 32'd131072;
        pow2_table[18] = 32'd262144;
        pow2_table[19] = 32'd524288;
        pow2_table[20] = 32'd1048576;
        pow2_table[21] = 32'd2097152;
        pow2_table[22] = 32'd4194304;
        pow2_table[23] = 32'd8388608;
        pow2_table[24] = 32'd16777216;
        pow2_table[25] = 32'd33554432;
        pow2_table[26] = 32'd67108864;
        pow2_table[27] = 32'd134217728;
        pow2_table[28] = 32'd268435456;
        pow2_table[29] = 32'd536870912;
        pow2_table[30] = 32'd1073741824;
        pow2_table[31] = 32'd2147483648;
    end
    
    // State transition
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            valid <= 1'b0;
            result <= 32'd0;
            edge_idx <= 6'd0;
            row_idx <= 4'd0;
            pivot_row <= 4'd0;
            rank <= 6'd0;
            shift_val <= 6'd0;
            pow2_result <= 32'd0;
            temp_mult <= 32'd0;
            mult_step <= 2'd0;
            for (i = 0; i < 16; i = i + 1) begin
                matrix[i] <= 32'd0;
            end
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    valid <= 1'b0;
                    result <= 32'd0;
                    edge_idx <= 6'd0;
                    row_idx <= 4'd0;
                    pivot_row <= 4'd0;
                    rank <= 6'd0;
                    shift_val <= 6'd0;
                    pow2_result <= 32'd0;
                    temp_mult <= 32'd0;
                    mult_step <= 2'd0;
                    for (i = 0; i < 16; i = i + 1) begin
                        matrix[i] <= 32'd0;
                    end
                end
                
                BUILD_MATRIX: begin
                    if (edge_idx < edge_count) begin
                        if (edge_a[edge_idx] < node_count) begin
                            matrix[edge_a[edge_idx]][edge_idx] <= 1'b1;
                        end
                        if (edge_b[edge_idx] < node_count) begin
                            matrix[edge_b[edge_idx]][edge_idx] <= 1'b1;
                        end
                        edge_idx <= edge_idx + 6'd1;
                    end
                end
                
                GAUSSIAN: begin
                    if (pivot_row < node_count && row_idx < node_count) begin
                        // Check if current row has a pivot
                        if (matrix[row_idx][pivot_row] == 1'b1) begin
                            // Found pivot, eliminate from other rows
                            for (i = 0; i < 16; i = i + 1) begin
                                if (i != row_idx && matrix[i][pivot_row] == 1'b1) begin
                                    matrix[i] <= matrix[i] ^ matrix[row_idx];
                                end
                            end
                            row_idx <= row_idx + 4'd1;
                            pivot_row <= pivot_row + 4'd1;
                        end else begin
                            // No pivot in this row, check next row
                            row_idx <= row_idx + 4'd1;
                        end
                    end
                end
                
                COUNT_RANK: begin
                    // Count non-zero rows
                    rank <= 6'd0;
                    for (i = 0; i < 16; i = i + 1) begin
                        if (i < node_count && matrix[i] != 32'd0) begin
                            rank <= rank + 6'd1;
                        end
                    end
                end
                
                COMPUTE_RESULT: begin
                    // Calculate pow2[edge_count - rank] mod MOD
                    shift_val <= (edge_count >= rank) ? (edge_count - rank) : 6'd0;
                    if (edge_count < rank) begin
                        pow2_result <= 32'd0;
                    end else begin
                        case (mult_step)
                            2'd0: begin
                                pow2_result <= pow2_table[shift_val[4:0]];
                                mult_step <= 2'd1;
                            end
                            2'd1: begin
                                // Handle bits 5+ if edge_count > 31
                                if (shift_val >= 6'd32) begin
                                    temp_mult <= pow2_result;
                                    pow2_result <= 32'd0;
                                end else begin
                                    temp_mult <= pow2_result;
                                end
                                mult_step <= 2'd2;
                            end
                            2'd2: begin
                                // Apply modular reduction if needed
                                if (shift_val >= 6'd32) begin
                                    // 2^32 mod MOD = 1598769 (0x1868BD)
                                    pow2_result <= 32'd1598769;
                                end else begin
                                    pow2_result <= temp_mult;
                                end
                                mult_step <= 2'd3;
                            end
                            default: begin
                                mult_step <= 2'd0;
                            end
                        endcase
                    end
                end
                
                OUTPUT_RESULT: begin
                    if (edge_count < rank) begin
                        result <= 32'd0;
                    end else begin
                        result <= pow2_result;
                    end
                    done <= 1'b1;
                    valid <= 1'b1;
                end
                
                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end
    
    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = BUILD_MATRIX;
                end
            end
            
            BUILD_MATRIX: begin
                if (edge_idx >= edge_count) begin
                    next_state = GAUSSIAN;
                end
            end
            
            GAUSSIAN: begin
                if (pivot_row >= node_count || row_idx >= node_count) begin
                    next_state = COUNT_RANK;
                end
            end
            
            COUNT_RANK: begin
                next_state = COMPUTE_RESULT;
            end
            
            COMPUTE_RESULT: begin
                if (mult_step == 2'd3) begin
                    next_state = OUTPUT_RESULT;
                end
            end
            
            OUTPUT_RESULT: begin
                next_state = IDLE;
            end
            
            default: begin
                next_state = IDLE;
            end
        endcase
    end

endmodule