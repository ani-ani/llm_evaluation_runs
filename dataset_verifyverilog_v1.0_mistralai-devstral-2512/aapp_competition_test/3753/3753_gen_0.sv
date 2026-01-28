module min_block_cells(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [255:0] grid_in,
    input wire [3:0] H,
    input wire [3:0] W,
    output reg [1:0] result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] COMPUTE = 2'd1;
    localparam [1:0] FINISH = 2'd2;
    
    reg [1:0] state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd256;

    // Grid dimensions
    reg [3:0] h_reg;
    reg [3:0] w_reg;

    // Reachability arrays
    reg [15:0] from_start [0:15];
    reg [15:0] to_end [0:15];

    // Current processing position
    reg [3:0] i_reg;
    reg [3:0] j_reg;

    // Diagonal counts
    reg [3:0] diag_count [0:31];

    // Intermediate signals
    reg [3:0] diag_index;
    reg [3:0] diag_count_reg;

    // Initialize arrays
    integer k;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 2'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            h_reg <= 4'd0;
            w_reg <= 4'd0;
            i_reg <= 4'd0;
            j_reg <= 4'd0;
            diag_index <= 4'd0;
            diag_count_reg <= 4'd0;
            
            // Initialize arrays
            for (k = 0; k < 16; k = k + 1) begin
                from_start[k] <= 16'd0;
                to_end[k] <= 16'd0;
            end
            
            for (k = 0; k < 32; k = k + 1) begin
                diag_count[k] <= 4'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= COMPUTE;
                        h_reg <= H;
                        w_reg <= W;
                        i_reg <= 4'd0;
                        j_reg <= 4'd0;
                        
                        // Initialize arrays
                        for (k = 0; k < 16; k = k + 1) begin
                            from_start[k] <= 16'd0;
                            to_end[k] <= 16'd0;
                        end
                        
                        for (k = 0; k < 32; k = k + 1) begin
                            diag_count[k] <= 4'd0;
                        end
                        
                        // Set start cell
                        from_start[0][0] <= ~grid_in[0];
                        to_end[h_reg-1][w_reg-1] <= ~grid_in[(h_reg-1)*16 + (w_reg-1)];
                    end
                end
                
                COMPUTE: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Forward pass
                    if (i_reg < h_reg && j_reg < w_reg) begin
                        if (i_reg == 0 && j_reg == 0) begin
                            // Already initialized
                            j_reg <= j_reg + 4'd1;
                        end else if (i_reg == 0) begin
                            // First row
                            from_start[i_reg][j_reg] <= ~grid_in[i_reg*16 + j_reg] & from_start[i_reg][j_reg-1];
                            j_reg <= j_reg + 4'd1;
                        end else if (j_reg == 0) begin
                            // First column
                            from_start[i_reg][j_reg] <= ~grid_in[i_reg*16 + j_reg] & from_start[i_reg-1][j_reg];
                            j_reg <= j_reg + 4'd1;
                        end else begin
                            from_start[i_reg][j_reg] <= ~grid_in[i_reg*16 + j_reg] & (from_start[i_reg-1][j_reg] | from_start[i_reg][j_reg-1]);
                            j_reg <= j_reg + 4'd1;
                        end
                        
                        if (j_reg >= w_reg) begin
                            j_reg <= 4'd0;
                            i_reg <= i_reg + 4'd1;
                        end
                    end
                    
                    // Backward pass
                    else if (i_reg < h_reg && j_reg < w_reg) begin
                        if (i_reg == h_reg-1 && j_reg == w_reg-1) begin
                            // Already initialized
                            j_reg <= j_reg + 4'd1;
                        end else if (i_reg == h_reg-1) begin
                            // Last row
                            to_end[i_reg][j_reg] <= ~grid_in[i_reg*16 + j_reg] & to_end[i_reg][j_reg+1];
                            j_reg <= j_reg + 4'd1;
                        end else if (j_reg == w_reg-1) begin
                            // Last column
                            to_end[i_reg][j_reg] <= ~grid_in[i_reg*16 + j_reg] & to_end[i_reg+1][j_reg];
                            j_reg <= j_reg + 4'd1;
                        end else begin
                            to_end[i_reg][j_reg] <= ~grid_in[i_reg*16 + j_reg] & (to_end[i_reg+1][j_reg] | to_end[i_reg][j_reg+1]);
                            j_reg <= j_reg + 4'd1;
                        end
                        
                        if (j_reg >= w_reg) begin
                            j_reg <= 4'd0;
                            i_reg <= i_reg + 4'd1;
                        end
                    end
                    
                    // Count diagonal cells
                    else if (diag_index < 32) begin
                        if (diag_count_reg < 4'd1) begin
                            if (diag_index < h_reg + w_reg - 1) begin
                                for (k = 0; k < h_reg; k = k + 1) begin
                                    if (k < h_reg && (diag_index - k) < w_reg && (diag_index - k) >= 0) begin
                                        if (from_start[k][diag_index - k] & to_end[k][diag_index - k]) begin
                                            diag_count[diag_index] <= diag_count[diag_index] + 4'd1;
                                        end
                                    end
                                end
                            end
                            diag_count_reg <= diag_count_reg + 4'd1;
                        end else begin
                            diag_count_reg <= 4'd0;
                            diag_index <= diag_index + 4'd1;
                        end
                    end
                    
                    // Determine result
                    else begin
                        reg found_single;
                        reg path_exists;
                        integer m;
                        
                        found_single <= 1'b0;
                        path_exists <= from_start[h_reg-1][w_reg-1];
                        
                        for (m = 0; m < 32; m = m + 1) begin
                            if (diag_count[m] == 4'd1) begin
                                found_single <= 1'b1;
                            end
                        end
                        
                        if (!path_exists) begin
                            result <= 2'd0;
                        end else if (found_single) begin
                            result <= 2'd1;
                        end else begin
                            result <= 2'd2;
                        end
                        
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