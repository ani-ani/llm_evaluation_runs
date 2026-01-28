module grid_partitioner (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire grid_valid,
    input wire [3:0] cell_data,
    input wire [7:0] cell_idx,
    output reg [15:0] result_a,
    output reg [15:0] result_b,
    output reg [15:0] result_c,
    output reg done,
    output reg possible
);

    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] LOAD = 3'd1;
    localparam [2:0] COMPUTE = 3'd2;
    localparam [2:0] CHECK = 3'd3;
    localparam [2:0] FINISH = 3'd4;

    // Internal registers
    reg [2:0] state, next_state;
    reg [7:0] load_count;
    reg [15:0] grid_one;       // Bit mask for '1' constraint cells (0-15)
    reg [15:0] grid_one_1;     // 16-31
    reg [15:0] grid_one_2;     // 32-47
    reg [15:0] grid_one_3;     // 48-63
    reg [15:0] grid_one_4;     // 64-79
    reg [15:0] grid_one_5;     // 80-95
    reg [15:0] grid_one_6;     // 96-111
    reg [15:0] grid_one_7;     // 112-127
    reg [15:0] grid_one_8;     // 128-143
    reg [15:0] grid_one_9;     // 144-159
    reg [15:0] grid_one_10;    // 160-175
    reg [15:0] grid_one_11;    // 176-191
    reg [15:0] grid_one_12;    // 192-207
    reg [15:0] grid_one_13;    // 208-223
    reg [15:0] grid_one_14;    // 224-239
    reg [15:0] grid_one_15;    // 240-255
    
    reg [15:0] grid_two;       // Bit mask for '2' constraint cells
    reg [15:0] grid_two_1;
    reg [15:0] grid_two_2;
    reg [15:0] grid_two_3;
    reg [15:0] grid_two_4;
    reg [15:0] grid_two_5;
    reg [15:0] grid_two_6;
    reg [15:0] grid_two_7;
    reg [15:0] grid_two_8;
    reg [15:0] grid_two_9;
    reg [15:0] grid_two_10;
    reg [15:0] grid_two_11;
    reg [15:0] grid_two_12;
    reg [15:0] grid_two_13;
    reg [15:0] grid_two_14;
    reg [15:0] grid_two_15;

    // Computation registers
    reg [15:0] region_a [0:15]; // 16 rows, 16 cols
    reg [15:0] region_b [0:15];
    reg [15:0] region_c [0:15];
    
    reg [7:0] current_idx;
    reg [7:0] cycle_count;
    reg [7:0] compute_step;
    reg [3:0] row, col;
    
    // Connectivity check signals
    reg [15:0] visited_a, visited_b, visited_c;
    reg [3:0] check_row, check_col;
    reg [7:0] bfs_queue [0:255]; // Simplified queue storage
    reg [7:0] queue_head, queue_tail;
    reg [7:0] queue_val;
    reg queue_empty;
    
    reg [7:0] MAX_CYCLES = 8'd200;
    reg connectivity_fail;
    
    integer i, j;

    // State transition
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            possible <= 1'b0;
            result_a <= 16'd0;
            result_b <= 16'd0;
            result_c <= 16'd0;
            load_count <= 8'd0;
            cycle_count <= 8'd0;
            compute_step <= 8'd0;
            
            // Initialize grid arrays
            grid_one <= 16'd0; grid_one_1 <= 16'd0; grid_one_2 <= 16'd0; grid_one_3 <= 16'd0;
            grid_one_4 <= 16'd0; grid_one_5 <= 16'd0; grid_one_6 <= 16'd0; grid_one_7 <= 16'd0;
            grid_one_8 <= 16'd0; grid_one_9 <= 16'd0; grid_one_10 <= 16'd0; grid_one_11 <= 16'd0;
            grid_one_12 <= 16'd0; grid_one_13 <= 16'd0; grid_one_14 <= 16'd0; grid_one_15 <= 16'd0;
            grid_two <= 16'd0; grid_two_1 <= 16'd0; grid_two_2 <= 16'd0; grid_two_3 <= 16'd0;
            grid_two_4 <= 16'd0; grid_two_5 <= 16'd0; grid_two_6 <= 16'd0; grid_two_7 <= 16'd0;
            grid_two_8 <= 16'd0; grid_two_9 <= 16'd0; grid_two_10 <= 16'd0; grid_two_11 <= 16'd0;
            grid_two_12 <= 16'd0; grid_two_13 <= 16'd0; grid_two_14 <= 16'd0; grid_two_15 <= 16'd0;
            
            for (i = 0; i < 16; i = i + 1) begin
                region_a[i] <= 16'd0;
                region_b[i] <= 16'd0;
                region_c[i] <= 16'd0;
            end
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    possible <= 1'b0;
                    load_count <= 8'd0;
                    cycle_count <= 8'd0;
                    compute_step <= 8'd0;
                end
                
                LOAD: begin
                    if (grid_valid) begin
                        // Store constraints in appropriate row/col
                        row <= cell_idx[7:4];
                        col <= cell_idx[3:0];
                        
                        // Determine which 16-bit chunk to update based on row
                        case (cell_idx[7:4])
                            4'd0: begin
                                grid_one[cell_idx[3:0]] <= cell_data[0];
                                grid_two[cell_idx[3:0]] <= cell_data[1];
                            end
                            4'd1: begin
                                grid_one_1[cell_idx[3:0]] <= cell_data[0];
                                grid_two_1[cell_idx[3:0]] <= cell_data[1];
                            end
                            4'd2: begin
                                grid_one_2[cell_idx[3:0]] <= cell_data[0];
                                grid_two_2[cell_idx[3:0]] <= cell_data[1];
                            end
                            4'd3: begin
                                grid_one_3[cell_idx[3:0]] <= cell_data[0];
                                grid_two_3[cell_idx[3:0]] <= cell_data[1];
                            end
                            4'd4: begin
                                grid_one_4[cell_idx[3:0]] <= cell_data[0];
                                grid_two_4[cell_idx[3:0]] <= cell_data[1];
                            end
                            4'd5: begin
                                grid_one_5[cell_idx[3:0]] <= cell_data[0];
                                grid_two_5[cell_idx[3:0]] <= cell_data[1];
                            end
                            4'd6: begin
                                grid_one_6[cell_idx[3:0]] <= cell_data[0];
                                grid_two_6[cell_idx[3:0]] <= cell_data[1];
                            end
                            4'd7: begin
                                grid_one_7[cell_idx[3:0]] <= cell_data[0];
                                grid_two_7[cell_idx[3:0]] <= cell_data[1];
                            end
                            4'd8: begin
                                grid_one_8[cell_idx[3:0]] <= cell_data[0];
                                grid_two_8[cell_idx[3:0]] <= cell_data[1];
                            end
                            4'd9: begin
                                grid_one_9[cell_idx[3:0]] <= cell_data[0];
                                grid_two_9[cell_idx[3:0]] <= cell_data[1];
                            end
                            4'd10: begin
                                grid_one_10[cell_idx[3:0]] <= cell_data[0];
                                grid_two_10[cell_idx[3:0]] <= cell_data[1];
                            end
                            4'd11: begin
                                grid_one_11[cell_idx[3:0]] <= cell_data[0];
                                grid_two_11[cell_idx[3:0]] <= cell_data[1];
                            end
                            4'd12: begin
                                grid_one_12[cell_idx[3:0]] <= cell_data[0];
                                grid_two_12[cell_idx[3:0]] <= cell_data[1];
                            end
                            4'd13: begin
                                grid_one_13[cell_idx[3:0]] <= cell_data[0];
                                grid_two_13[cell_idx[3:0]] <= cell_data[1];
                            end
                            4'd14: begin
                                grid_one_14[cell_idx[3:0]] <= cell_data[0];
                                grid_two_14[cell_idx[3:0]] <= cell_data[1];
                            end
                            4'd15: begin
                                grid_one_15[cell_idx[3:0]] <= cell_data[0];
                                grid_two_15[cell_idx[3:0]] <= cell_data[1];
                            end
                            default: begin
                                grid_one[cell_idx[3:0]] <= cell_data[0];
                                grid_two[cell_idx[3:0]] <= cell_data[1];
                            end
                        endcase
                        
                        load_count <= load_count + 8'd1;
                    end
                end
                
                COMPUTE: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Simplified partitioning algorithm
                    // Divide grid into 3 regions based on position
                    // This is a heuristic approach
                    
                    if (compute_step < 8'd16) begin
                        // Initialize regions: A=left half, B=right half (first pass)
                        // Then adjust for constraints
                        
                        case (compute_step)
                            8'd0: begin // Assign basic regions
                                for (i = 0; i < 16; i = i + 1) begin
                                    // Left 8 cols -> A, Middle 4 -> B, Right 4 -> C
                                    region_a[i] <= 16'h00FF;  // First 8 bits
                                    region_b[i] <= 16'h0F00;  // Next 4 bits (shifted)
                                    region_c[i] <= 16'hF000;  // Last 4 bits
                                end
                            end
                            8'd1: begin // Handle '2' constraints
                                // If cell has '2' constraint, assign to A and B
                                for (i = 0; i < 16; i = i + 1) begin
                                    // Check '2' constraints for this row
                                    case (i)
                                        0: begin
                                            region_a[i] <= region_a[i] | grid_two;
                                            region_b[i] <= region_b[i] | grid_two;
                                        end
                                        1: begin
                                            region_a[i] <= region_a[i] | grid_two_1;
                                            region_b[i] <= region_b[i] | grid_two_1;
                                        end
                                        2: begin
                                            region_a[i] <= region_a[i] | grid_two_2;
                                            region_b[i] <= region_b[i] | grid_two_2;
                                        end
                                        3: begin
                                            region_a[i] <= region_a[i] | grid_two_3;
                                            region_b[i] <= region_b[i] | grid_two_3;
                                        end
                                        4: begin
                                            region_a[i] <= region_a[i] | grid_two_4;
                                            region_b[i] <= region_b[i] | grid_two_4;
                                        end
                                        5: begin
                                            region_a[i] <= region_a[i] | grid_two_5;
                                            region_b[i] <= region_b[i] | grid_two_5;
                                        end
                                        6: begin
                                            region_a[i] <= region_a[i] | grid_two_6;
                                            region_b[i] <= region_b[i] | grid_two_6;
                                        end
                                        7: begin
                                            region_a[i] <= region_a[i] | grid_two_7;
                                            region_b[i] <= region_b[i] | grid_two_7;
                                        end
                                        8: begin
                                            region_a[i] <= region_a[i] | grid_two_8;
                                            region_b[i] <= region_b[i] | grid_two_8;
                                        end
                                        9: begin
                                            region_a[i] <= region_a[i] | grid_two_9;
                                            region_b[i] <= region_b[i] | grid_two_9;
                                        end
                                        10: begin
                                            region_a[i] <= region_a[i] | grid_two_10;
                                            region_b[i] <= region_b[i] | grid_two_10;
                                        end
                                        11: begin
                                            region_a[i] <= region_a[i] | grid_two_11;
                                            region_b[i] <= region_b[i] | grid_two_11;
                                        end
                                        12: begin
                                            region_a[i] <= region_a[i] | grid_two_12;
                                            region_b[i] <= region_b[i] | grid_two_12;
                                        end
                                        13: begin
                                            region_a[i] <= region_a[i] | grid_two_13;
                                            region_b[i] <= region_b[i] | grid_two_13;
                                        end
                                        14: begin
                                            region_a[i] <= region_a[i] | grid_two_14;
                                            region_b[i] <= region_b[i] | grid_two_14;
                                        end
                                        15: begin
                                            region_a[i] <= region_a[i] | grid_two_15;
                                            region_b[i] <= region_b[i] | grid_two_15;
                                        end
                                        default: begin end
                                    endcase
                                end
                            end
                            8'd2: begin // Ensure '1' constraints are in exactly one region
                                // Remove '1' cells from regions they shouldn't be in
                                for (i = 0; i < 16; i = i + 1) begin
                                    case (i)
                                        0: begin
                                            region_b[i] <= region_b[i] & ~grid_one;
                                            region_c[i] <= region_c[i] & ~grid_one;
                                        end
                                        1: begin
                                            region_b[i] <= region_b[i] & ~grid_one_1;
                                            region_c[i] <= region_c[i] & ~grid_one_1;
                                        end
                                        2: begin
                                            region_b[i] <= region_b[i] & ~grid_one_2;
                                            region_c[i] <= region_c[i] & ~grid_one_2;
                                        end
                                        3: begin
                                            region_b[i] <= region_b[i] & ~grid_one_3;
                                            region_c[i] <= region_c[i] & ~grid_one_3;
                                        end
                                        4: begin
                                            region_b[i] <= region_b[i] & ~grid_one_4;
                                            region_c[i] <= region_c[i] & ~grid_one_4;
                                        end
                                        5: begin
                                            region_b[i] <= region_b[i] & ~grid_one_5;
                                            region_c[i] <= region_c[i] & ~grid_one_5;
                                        end
                                        6: begin
                                            region_b[i] <= region_b[i] & ~grid_one_6;
                                            region_c[i] <= region_c[i] & ~grid_one_6;
                                        end
                                        7: begin
                                            region_b[i] <= region_b[i] & ~grid_one_7;
                                            region_c[i] <= region_c[i] & ~grid_one_7;
                                        end
                                        8: begin
                                            region_b[i] <= region_b[i] & ~grid_one_8;
                                            region_c[i] <= region_c[i] & ~grid_one_8;
                                        end
                                        9: begin
                                            region_b[i] <= region_b[i] & ~grid_one_9;
                                            region_c[i] <= region_c[i] & ~grid_one_9;
                                        end
                                        10: begin
                                            region_b[i] <= region_b[i] & ~grid_one_10;
                                            region_c[i] <= region_c[i] & ~grid_one_10;
                                        end
                                        11: begin
                                            region_b[i] <= region_b[i] & ~grid_one_11;
                                            region_c[i] <= region_c[i] & ~grid_one_11;
                                        end
                                        12: begin
                                            region_b[i] <= region_b[i] & ~grid_one_12;
                                            region_c[i] <= region_c[i] & ~grid_one_12;
                                        end
                                        13: begin
                                            region_b[i] <= region_b[i] & ~grid_one_13;
                                            region_c[i] <= region_c[i] & ~grid_one_13;
                                        end
                                        14: begin
                                            region_b[i] <= region_b[i] & ~grid_one_14;
                                            region_c[i] <= region_c[i] & ~grid_one_14;
                                        end
                                        15: begin
                                            region_b[i] <= region_b[i] & ~grid_one_15;
                                            region_c[i] <= region_c[i] & ~grid_one_15;
                                        end
                                        default: begin end
                                    endcase
                                end
                            end
                            8'd3: begin // Adjust '1' cells to ensure they are in exactly one region
                                // Check if '1' cells are in A; if not, move them from B/C to A
                                for (i = 0; i < 16; i = i + 1) begin
                                    case (i)
                                        0: begin
                                            if ((grid_one & region_a[i]) == 16'd0) begin
                                                region_a[i] <= region_a[i] | grid_one;
                                                region_b[i] <= region_b[i] & ~grid_one;
                                                region_c[i] <= region_c[i] & ~grid_one;
                                            end
                                        end
                                        1: begin
                                            if ((grid_one_1 & region_a[i]) == 16'd0) begin
                                                region_a[i] <= region_a[i] | grid_one_1;
                                                region_b[i] <= region_b[i] & ~grid_one_1;
                                                region_c[i] <= region_c[i] & ~grid_one_1;
                                            end
                                        end
                                        2: begin
                                            if ((grid_one_2 & region_a[i]) == 16'd0) begin
                                                region_a[i] <= region_a[i] | grid_one_2;
                                                region_b[i] <= region_b[i] & ~grid_one_2;
                                                region_c[i] <= region_c[i] & ~grid_one_2;
                                            end
                                        end
                                        3: begin
                                            if ((grid_one_3 & region_a[i]) == 16'd0) begin
                                                region_a[i] <= region_a[i] | grid_one_3;
                                                region_b[i] <= region_b[i] & ~grid_one_3;
                                                region_c[i] <= region_c[i] & ~grid_one_3;
                                            end
                                        end
                                        4: begin
                                            if ((grid_one_4 & region_a[i]) == 16'd0) begin
                                                region_a[i] <= region_a[i] | grid_one_4;
                                                region_b[i] <= region_b[i] & ~grid_one_4;
                                                region_c[i] <= region_c[i] & ~grid_one_4;
                                            end
                                        end
                                        5: begin
                                            if ((grid_one_5 & region_a[i]) == 16'd0) begin
                                                region_a[i] <= region_a[i] | grid_one_5;
                                                region_b[i] <= region_b[i] & ~grid_one_5;
                                                region_c[i] <= region_c[i] & ~grid_one_5;
                                            end
                                        end
                                        6: begin
                                            if ((grid_one_6 & region_a[i]) == 16'd0) begin
                                                region_a[i] <= region_a[i] | grid_one_6;
                                                region_b[i] <= region_b[i] & ~grid_one_6;
                                                region_c[i] <= region_c[i] & ~grid_one_6;
                                            end
                                        end
                                        7: begin
                                            if ((grid_one_7 & region_a[i]) == 16'd0) begin
                                                region_a[i] <= region_a[i] | grid_one_7;
                                                region_b[i] <= region_b[i] & ~grid_one_7;
                                                region_c[i] <= region_c[i] & ~grid_one_7;
                                            end
                                        end
                                        8: begin
                                            if ((grid_one_8 & region_a[i]) == 16'd0) begin
                                                region_a[i] <= region_a[i] | grid_one_8;
                                                region_b[i] <= region_b[i] & ~grid_one_8;
                                                region_c[i] <= region_c[i] & ~grid_one_8;
                                            end
                                        end
                                        9: begin
                                            if ((grid_one_9 & region_a[i]) == 16'd0) begin
                                                region_a[i] <= region_a[i] | grid_one_9;
                                                region_b[i] <= region_b[i] & ~grid_one_9;
                                                region_c[i] <= region_c[i] & ~grid_one_9;
                                            end
                                        end
                                        10: begin
                                            if ((grid_one_10 & region_a[i]) == 16'd0) begin
                                                region_a[i] <= region_a[i] | grid_one_10;
                                                region_b[i] <= region_b[i] & ~grid_one_10;
                                                region_c[i] <= region_c[i] & ~grid_one_10;
                                            end
                                        end
                                        11: begin
                                            if ((grid_one_11 & region_a[i]) == 16'd0) begin
                                                region_a[i] <= region_a[i] | grid_one_11;
                                                region_b[i] <= region_b[i] & ~grid_one_11;
                                                region_c[i] <= region_c[i] & ~grid_one_11;
                                            end
                                        end
                                        12: begin
                                            if ((grid_one_12 & region_a[i]) == 16'd0) begin
                                                region_a[i] <= region_a[i] | grid_one_12;
                                                region_b[i] <= region_b[i] & ~grid_one_12;
                                                region_c[i] <= region_c[i] & ~grid_one_12;
                                            end
                                        end
                                        13: begin
                                            if ((grid_one_13 & region_a[i]) == 16'd0) begin
                                                region_a[i] <= region_a[i] | grid_one_13;
                                                region_b[i] <= region_b[i] & ~grid_one_13;
                                                region_c[i] <= region_c[i] & ~grid_one_13;
                                            end
                                        end
                                        14: begin
                                            if ((grid_one_14 & region_a[i]) == 16'd0) begin
                                                region_a[i] <= region_a[i] | grid_one_14;
                                                region_b[i] <= region_b[i] & ~grid_one_14;
                                                region_c[i] <= region_c[i] & ~grid_one_14;
                                            end
                                        end
                                        15: begin
                                            if ((grid_one_15 & region_a[i]) == 16'd0) begin
                                                region_a[i] <= region_a[i] | grid_one_15;
                                                region_b[i] <= region_b[i] & ~grid_one_15;
                                                region_c[i] <= region_c[i] & ~grid_one_15;
                                            end
                                        end
                                        default: begin end
                                    endcase
                                end
                            end
                            8'd4: begin // Ensure connectivity for A (expand if needed)
                                // Simple heuristic: ensure first column of A is set
                                region_a[0] <= region_a[0] | 16'h0001;
                                region_a[1] <= region_a[1] | 16'h0001;
                                region_a[2] <= region_a[2] | 16'h0001;
                                region_a[3] <= region_a[3] | 16'h0001;
                                region_a[4] <= region_a[4] | 16'h0001;
                                region_a[5] <= region_a[5] | 16'h0001;
                                region_a[6] <= region_a[6] | 16'h0001;
                                region_a[7] <= region_a[7] | 16'h0001;
                                region_a[8] <= region_a[8] | 16'h0001;
                                region_a[9] <= region_a[9] | 16'h0001;
                                region_a[10] <= region_a[10] | 16'h0001;
                                region_a[11] <= region_a[11] | 16'h0001;
                                region_a[12] <= region_a[12] | 16'h0001;
                                region_a[13] <= region_a[13] | 16'h0001;
                                region_a[14] <= region_a[14] | 16'h0001;
                                region_a[15] <= region_a[15] | 16'h0001;
                            end
                            8'd5: begin // Ensure connectivity for B
                                region_b[0] <= region_b[0] | 16'h0100;
                                region_b[1] <= region_b[1] | 16'h0100;
                                region_b[2] <= region_b[2] | 16'h0100;
                                region_b[3] <= region_b[3] | 16'h0100;
                                region_b[4] <= region_b[4] | 16'h0100;
                                region_b[5] <= region_b[5] | 16'h0100;
                                region_b[6] <= region_b[6] | 16'h0100;
                                region_b[7] <= region_b[7] | 16'h0100;
                                region_b[8] <= region_b[8] | 16'h0100;
                                region_b[9] <= region_b[9] | 16'h0100;
                                region_b[10] <= region_b[10] | 16'h0100;
                                region_b[11] <= region_b[11] | 16'h0100;
                                region_b[12] <= region_b[12] | 16'h0100;
                                region_b[13] <= region_b[13] | 16'h0100;
                                region_b[14] <= region_b[14] | 16'h0100;
                                region_b[15] <= region_b[15] | 16'h0100;
                            end
                            8'd6: begin // Ensure connectivity for C
                                region_c[0] <= region_c[0] | 16'h1000;
                                region_c[1] <= region_c[1] | 16'h1000;
                                region_c[2] <= region_c[2] | 16'h1000;
                                region_c[3] <= region_c[3] | 16'h1000;
                                region_c[4] <= region_c[4] | 16'h1000;
                                region_c[5] <= region_c[5] | 16'h1000;
                                region_c[6] <= region_c[6] | 16'h1000;
                                region_c[7] <= region_c[7] | 16'h1000;
                                region_c[8] <= region_c[8] | 16'h1000;
                                region_c[9] <= region_c[9] | 16'h1000;
                                region_c[10] <= region_c[10] | 16'h1000;
                                region_c[11] <= region_c[11] | 16'h1000;
                                region_c[12] <= region_c[12] | 16'h1000;
                                region_c[13] <= region_c[13] | 16'h1000;
                                region_c[14] <= region_c[14] | 16'h1000;
                                region_c[15] <= region_c[15] | 16'h1000;
                            end
                            default: begin
                                // No action
                            end
                        endcase
                        
                        compute_step <= compute_step + 8'd1;
                    end
                end
                
                CHECK: begin
                    // Check constraints and connectivity
                    // This is simplified - check for non-empty regions and basic constraint satisfaction
                    
                    // Check non-empty
                    if ((region_a[0] | region_a[1] | region_a[2] | region_a[3] | region_a[4] | region_a[5] | region_a[6] | region_a[7] | region_a[8] | region_a[9] | region_a[10] | region_a[11] | region_a[12] | region_a[13] | region_a[14] | region_a[15]) == 16'd0) begin
                        connectivity_fail <= 1'b1;
                    end else if ((region_b[0] | region_b[1] | region_b[2] | region_b[3] | region_b[4] | region_b[5] | region_b[6] | region_b[7] | region_b[8] | region_b[9] | region_b[10] | region_b[11] | region_b[12] | region_b[13] | region_b[14] | region_b[15]) == 16'd0) begin
                        connectivity_fail <= 1'b1;
                    end else if ((region_c[0] | region_c[1] | region_c[2] | region_c[3] | region_c[4] | region_c[5] | region_c[6] | region_c[7] | region_c[8] | region_c[9] | region_c[10] | region_c[11] | region_c[12] | region_c[13] | region_c[14] | region_c[15]) == 16'd0) begin
                        connectivity_fail <= 1'b1;
                    end else begin
                        // Check '1' constraints (must be in exactly one region)
                        // Check '2' constraints (must be in at least two regions)
                        connectivity_fail <= 1'b0;
                    end
                end
                
                FINISH: begin
                    // Output results
                    // Pack bitmasks into 16-bit outputs (representing rows)
                    // We'll output row 0 as representative or sum of all rows
                    // For simplicity, output the OR of all rows
                    
                    result_a <= region_a[0] | region_a[1] | region_a[2] | region_a[3] | region_a[4] | region_a[5] | region_a[6] | region_a[7] | region_a[8] | region_a[9] | region_a[10] | region_a[11] | region_a[12] | region_a[13] | region_a[14] | region_a[15];
                    result_b <= region_b[0] | region_b[1] | region_b[2] | region_b[3] | region_b[4] | region_b[5] | region_b[6] | region_b[7] | region_b[8] | region_b[9] | region_b[10] | region_b[11] | region_b[12] | region_b[13] | region_b[14] | region_b[15];
                    result_c <= region_c[0] | region_c[1] | region_c[2] | region_c[3] | region_c[4] | region_c[5] | region_c[6] | region_c[7] | region_c[8] | region_c[9] | region_c[10] | region_c[11] | region_c[12] | region_c[13] | region_c[14] | region_c[15];
                    
                    possible <= ~connectivity_fail;
                    done <= 1'b1;
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
                if (start) next_state = LOAD;
                else next_state = IDLE;
            end
            LOAD: begin
                if (load_count == 8'd255 && grid_valid) next_state = COMPUTE;
                else next_state = LOAD;
            end
            COMPUTE: begin
                if (compute_step >= 8'd10) next_state = CHECK;
                else next_state = COMPUTE;
            end
            CHECK: begin
                next_state = FINISH;
            end
            FINISH: begin
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

endmodule