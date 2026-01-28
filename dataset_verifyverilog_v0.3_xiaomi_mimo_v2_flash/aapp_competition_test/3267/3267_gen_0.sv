module KingSpread (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [255:0] board_packed, // 8x8x2 = 128 bits? Wait: 8*8*2 = 128 bits. Spec says 255:0 which is 256 bits. Using 255:0 as per spec.
    output reg [31:0] mirko_spread,
    output reg [31:0] slavko_spread,
    output reg done
);

    // --- Parameters ---
    localparam [3:0] MAX_ROWS = 4'd8;
    localparam [3:0] MAX_COLS = 4'd8;
    localparam [4:0] MAX_PIECES = 5'd16; // 16 pieces max
    localparam [7:0] MAX_CELLS = 8'd64;
    localparam [7:0] MAX_DIST = 8'd7; // Max distance on 8x8 board

    // --- States ---
    localparam [3:0] IDLE       = 4'd0;
    localparam [3:0] SCAN       = 4'd1;
    localparam [3:0] COMPUTE_M  = 4'd2;
    localparam [3:0] CALC_DIST_M = 4'd3;
    localparam [3:0] NEXT_PAIR_M = 4'd4;
    localparam [3:0] COMPUTE_S  = 4'd5;
    localparam [3:0] CALC_DIST_S = 4'd6;
    localparam [3:0] NEXT_PAIR_S = 4'd7;
    localparam [3:0] DONE       = 4'd8;

    // --- Registers ---
    reg [3:0] state, next_state;
    
    // Counters
    reg [7:0] scan_idx; // 0 to 63
    reg [3:0] M_count, S_count;
    
    // Arrays for coordinates
    reg [7:0] M_x [0:15];
    reg [7:0] M_y [0:15];
    reg [7:0] S_x [0:15];
    reg [7:0] S_y [0:15];
    
    // Computation indices
    reg [3:0] i_idx, j_idx;
    
    // Computation variables
    reg [7:0] dx, dy;
    reg [7:0] dist;
    reg [31:0] temp_spread;
    reg [7:0] row_val, col_val;
    
    // Loop counters
    integer i;

    // --- Next State Logic ---
    always @(*) begin
        case (state)
            IDLE: begin
                if (start) next_state = SCAN;
                else next_state = IDLE;
            end
            SCAN: begin
                if (scan_idx == MAX_CELLS - 8'd1) next_state = COMPUTE_M;
                else next_state = SCAN;
            end
            COMPUTE_M: begin
                if (M_count <= 4'd1) next_state = COMPUTE_S;
                else next_state = CALC_DIST_M;
            end
            CALC_DIST_M: begin
                // Always go to next pair logic after calculating dist
                next_state = NEXT_PAIR_M;
            end
            NEXT_PAIR_M: begin
                if (j_idx < M_count) next_state = CALC_DIST_M;
                else if (i_idx < M_count - 4'd2) next_state = CALC_DIST_M; // Next i, j starts at i+1
                else next_state = COMPUTE_S;
            end
            COMPUTE_S: begin
                if (S_count <= 4'd1) next_state = DONE;
                else next_state = CALC_DIST_S;
            end
            CALC_DIST_S: begin
                next_state = NEXT_PAIR_S;
            end
            NEXT_PAIR_S: begin
                if (j_idx < S_count) next_state = CALC_DIST_S;
                else if (i_idx < S_count - 4'd2) next_state = CALC_DIST_S;
                else next_state = DONE;
            end
            DONE: begin
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

    // --- Sequential Logic ---
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            mirko_spread <= 32'd0;
            slavko_spread <= 32'd0;
            scan_idx <= 8'd0;
            M_count <= 4'd0;
            S_count <= 4'd0;
            i_idx <= 4'd0;
            j_idx <= 4'd0;
            dx <= 8'd0;
            dy <= 8'd0;
            dist <= 8'd0;
            temp_spread <= 32'd0;
            row_val <= 8'd0;
            col_val <= 8'd0;
            // Initialize arrays to avoid X propagation
            for (i = 0; i < 16; i = i + 1) begin
                M_x[i] <= 8'd0;
                M_y[i] <= 8'd0;
                S_x[i] <= 8'd0;
                S_y[i] <= 8'd0;
            end
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        scan_idx <= 8'd0;
                        M_count <= 4'd0;
                        S_count <= 4'd0;
                        mirko_spread <= 32'd0;
                        slavko_spread <= 32'd0;
                    end
                end

                SCAN: begin
                    // Read cell
                    // Index calculation: row * 8 + col
                    // scan_idx is 0..63. row = scan_idx / 8, col = scan_idx % 8
                    // Bit offset: (row * 8 + col) * 2
                    // We use scan_idx directly: bit offset = scan_idx * 2
                    if (board_packed[scan_idx*2 +: 2] == 2'b01) begin
                        if (M_count < MAX_PIECES) begin
                            M_x[M_count] <= scan_idx[7:4]; // row = scan_idx / 16 is wrong. scan_idx 0..63. 
                            // scan_idx[5:3] is row (0-7). scan_idx[2:0] is col (0-7).
                            // Actually, row = scan_idx[5:3], col = scan_idx[2:0] if we use 3 bits for col.
                            // Let's calculate explicitly:
                            M_x[M_count] <= {4'd0, scan_idx[5:3]}; // row (0-7)
                            M_y[M_count] <= {4'd0, scan_idx[2:0]}; // col (0-7)
                            M_count <= M_count + 4'd1;
                        end
                    end else if (board_packed[scan_idx*2 +: 2] == 2'b10) begin
                        if (S_count < MAX_PIECES) begin
                            S_x[S_count] <= {4'd0, scan_idx[5:3]};
                            S_y[S_count] <= {4'd0, scan_idx[2:0]};
                            S_count <= S_count + 4'd1;
                        end
                    end
                    
                    if (scan_idx < MAX_CELLS - 8'd1)
                        scan_idx <= scan_idx + 8'd1;
                end

                COMPUTE_M: begin
                    i_idx <= 4'd0;
                    j_idx <= 4'd1;
                    temp_spread <= 32'd0;
                end

                CALC_DIST_M: begin
                    // dx = |M_x[i] - M_x[j]|
                    if (M_x[i_idx] > M_x[j_idx]) 
                        dx <= M_x[i_idx] - M_x[j_idx];
                    else 
                        dx <= M_x[j_idx] - M_x[i_idx];
                    
                    // dy = |M_y[i] - M_y[j]|
                    if (M_y[i_idx] > M_y[j_idx]) 
                        dy <= M_y[i_idx] - M_y[j_idx];
                    else 
                        dy <= M_y[j_idx] - M_y[i_idx];
                    
                    // dist = max(dx, dy) - computed in next cycle or combinational?
                    // Let's do it combinationally outside or use next state calc.
                    // To keep logic simple, we compute max here using if-else.
                    if (dx > dy) dist <= dx;
                    else dist <= dy;
                end

                NEXT_PAIR_M: begin
                    // Add dist to temp_spread
                    temp_spread <= temp_spread + dist;
                    
                    // Increment j
                    j_idx <= j_idx + 4'd1;
                    
                    // Check if inner loop done
                    if (j_idx >= M_count - 4'd1) begin
                        // Reset j for next i, increment i
                        i_idx <= i_idx + 4'd1;
                        j_idx <= i_idx + 4'd2; // j starts at i+2 because i+1 was just processed?
                        // Wait, logic: if i=0, j goes 1..N-1. 
                        // If j finishes (j==N-1), i becomes 1. j should become 2.
                        // So j = i + 2 is correct.
                    end
                end

                COMPUTE_S: begin
                    // Transfer accumulated Mirko spread
                    mirko_spread <= temp_spread;
                    
                    i_idx <= 4'd0;
                    j_idx <= 4'd1;
                    temp_spread <= 32'd0;
                end

                CALC_DIST_S: begin
                    // Same as M
                    if (S_x[i_idx] > S_x[j_idx]) 
                        dx <= S_x[i_idx] - S_x[j_idx];
                    else 
                        dx <= S_x[j_idx] - S_x[i_idx];
                    
                    if (S_y[i_idx] > S_y[j_idx]) 
                        dy <= S_y[i_idx] - S_y[j_idx];
                    else 
                        dy <= S_y[j_idx] - S_y[i_idx];
                    
                    if (dx > dy) dist <= dx;
                    else dist <= dy;
                end

                NEXT_PAIR_S: begin
                    temp_spread <= temp_spread + dist;
                    j_idx <= j_idx + 4'd1;
                    
                    if (j_idx >= S_count - 4'd1) begin
                        i_idx <= i_idx + 4'd1;
                        j_idx <= i_idx + 4'd2;
                    end
                end

                DONE: begin
                    // Transfer accumulated Slavko spread
                    slavko_spread <= temp_spread;
                    done <= 1'b1;
                end
            endcase
        end
    end

endmodule