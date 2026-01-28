module chess_spread(
    input clk,
    input rst_n,
    input start,
    input [255:0] board_flat,
    output reg [15:0] mirko_spread,
    output reg [15:0] slavko_spread,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE     = 3'd0;
    localparam [2:0] SCAN     = 3'd1;
    localparam [2:0] CALC_M   = 3'd2;
    localparam [2:0] CALC_S   = 3'd3;
    localparam [2:0] DONE     = 3'd4;

    // Registers
    reg [2:0] state, next_state;
    reg [7:0] scan_idx;           // 0-255 for cell scanning
    reg [3:0] mirko_count, slavko_count;  // 0-8
    reg [3:0] mirko_r [0:7];      // Row coordinates
    reg [3:0] mirko_c [0:7];      // Col coordinates
    reg [3:0] slavko_r [0:7];
    reg [3:0] slavko_c [0:7];
    
    // Calculation registers
    reg [3:0] i_idx, j_idx;       // Pair indices
    reg [15:0] temp_sum;          // Temporary accumulator
    reg [3:0] r1, r2, c1, c2;     // Coordinate temporaries
    reg [3:0] dr, dc;             // Differences
    reg [3:0] max_dist;           // Chebyshev distance
    
    // Control flags
    reg calc_done;

    // FSM: State transition
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end

    // FSM: Next state logic
    always @(*) begin
        next_state = state;  // Default
        case (state)
            IDLE: begin
                if (start) next_state = SCAN;
            end
            SCAN: begin
                if (scan_idx >= 8'd255) next_state = CALC_M;
            end
            CALC_M: begin
                if (calc_done) next_state = CALC_S;
            end
            CALC_S: begin
                if (calc_done) next_state = DONE;
            end
            DONE: begin
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

    // Main logic: State outputs and operations
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Initialize all registers
            scan_idx <= 8'd0;
            mirko_count <= 4'd0;
            slavko_count <= 4'd0;
            i_idx <= 4'd0;
            j_idx <= 4'd0;
            temp_sum <= 16'd0;
            mirko_spread <= 16'd0;
            slavko_spread <= 16'd0;
            done <= 1'b0;
            calc_done <= 1'b0;
            r1 <= 4'd0; r2 <= 4'd0; c1 <= 4'd0; c2 <= 4'd0;
            dr <= 4'd0; dc <= 4'd0; max_dist <= 4'd0;
            // Initialize coordinate arrays
            mirko_r[0] <= 4'd0; mirko_r[1] <= 4'd0; mirko_r[2] <= 4'd0; mirko_r[3] <= 4'd0;
            mirko_r[4] <= 4'd0; mirko_r[5] <= 4'd0; mirko_r[6] <= 4'd0; mirko_r[7] <= 4'd0;
            mirko_c[0] <= 4'd0; mirko_c[1] <= 4'd0; mirko_c[2] <= 4'd0; mirko_c[3] <= 4'd0;
            mirko_c[4] <= 4'd0; mirko_c[5] <= 4'd0; mirko_c[6] <= 4'd0; mirko_c[7] <= 4'd0;
            slavko_r[0] <= 4'd0; slavko_r[1] <= 4'd0; slavko_r[2] <= 4'd0; slavko_r[3] <= 4'd0;
            slavko_r[4] <= 4'd0; slavko_r[5] <= 4'd0; slavko_r[6] <= 4'd0; slavko_r[7] <= 4'd0;
            slavko_c[0] <= 4'd0; slavko_c[1] <= 4'd0; slavko_c[2] <= 4'd0; slavko_c[3] <= 4'd0;
            slavko_c[4] <= 4'd0; slavko_c[5] <= 4'd0; slavko_c[6] <= 4'd0; slavko_c[7] <= 4'd0;
        end else begin
            done <= 1'b0;  // Default done clear
            calc_done <= 1'b0;
            
            case (state)
                IDLE: begin
                    if (start) begin
                        scan_idx <= 8'd0;
                        mirko_count <= 4'd0;
                        slavko_count <= 4'd0;
                        i_idx <= 4'd0;
                        j_idx <= 4'd0;
                        temp_sum <= 16'd0;
                        // Arrays already initialized, will be overwritten as needed
                    end
                end
                
                SCAN: begin
                    // Check current cell
                    // cell bits: board_flat[2*scan_idx + 1:2*scan_idx]
                    // For Icarus compatibility, we compute index manually
                    // scan_idx[7:4] is row (0-15), scan_idx[3:0] is col (0-15)
                    // row = scan_idx >> 4, col = scan_idx[3:0]
                    // However, spec says index = row*16+col, so row = scan_idx[7:4], col = scan_idx[3:0]
                    
                    if (board_flat[2*scan_idx + 1:2*scan_idx] == 2'b01 && mirko_count < 4'd8) begin
                        // Mirko piece
                        mirko_r[mirko_count] <= scan_idx[7:4];  // Row
                        mirko_c[mirko_count] <= scan_idx[3:0];  // Col
                        mirko_count <= mirko_count + 4'd1;
                    end else if (board_flat[2*scan_idx + 1:2*scan_idx] == 2'b10 && slavko_count < 4'd8) begin
                        // Slavko piece
                        slavko_r[slavko_count] <= scan_idx[7:4];  // Row
                        slavko_c[slavko_count] <= scan_idx[3:0];  // Col
                        slavko_count <= slavko_count + 4'd1;
                    end
                    
                    scan_idx <= scan_idx + 8'd1;
                end
                
                CALC_M: begin
                    // Initialize for Mirko calculation
                    if (i_idx == 4'd0 && j_idx == 4'd0) begin
                        temp_sum <= 16'd0;
                    end
                    
                    if (mirko_count > 4'd1) begin
                        // Compute distance for pair (i_idx, j_idx)
                        r1 <= mirko_r[i_idx];
                        r2 <= mirko_r[j_idx];
                        c1 <= mirko_c[i_idx];
                        c2 <= mirko_c[j_idx];
                        
                        // Chebyshev distance calculation in same cycle
                        // dr = abs(r1 - r2)
                        // dc = abs(c1 - c2)
                        // max_dist = dr > dc ? dr : dc
                        // Use comparator and mux
                        if (r1 > r2) dr <= r1 - r2;
                        else dr <= r2 - r1;
                        
                        if (c1 > c2) dc <= c1 - c2;
                        else dc <= c2 - c1;
                        
                        // Wait 1 cycle for subtraction to complete
                        // Actually, we can do max in next state logic, but let's pipeline
                        // We'll compute max_dist in next cycle or combinational
                        // For simplicity, do combinational here
                        if (dr > dc) max_dist <= dr;
                        else max_dist <= dc;
                        
                        // Add to temp_sum
                        temp_sum <= temp_sum + {12'd0, max_dist};
                        
                        // Increment indices
                        j_idx <= j_idx + 4'd1;
                        if (j_idx >= mirko_count - 4'd1) begin
                            j_idx <= i_idx + 4'd2;
                            i_idx <= i_idx + 4'd1;
                        end
                    end else begin
                        // 0 or 1 piece: spread is 0
                        calc_done <= 1'b1;
                    end
                    
                    // Completion check
                    if (mirko_count <= 4'd1) begin
                        calc_done <= 1'b1;
                    end else if (i_idx >= mirko_count - 4'd1) begin
                        calc_done <= 1'b1;
                    end
                end
                
                CALC_S: begin
                    // Initialize for Slavko calculation
                    if (i_idx == 4'd0 && j_idx == 4'd0) begin
                        temp_sum <= 16'd0;
                    end
                    
                    if (slavko_count > 4'd1) begin
                        // Compute distance for pair (i_idx, j_idx)
                        r1 <= slavko_r[i_idx];
                        r2 <= slavko_r[j_idx];
                        c1 <= slavko_c[i_idx];
                        c2 <= slavko_c[j_idx];
                        
                        // Chebyshev distance calculation
                        if (r1 > r2) dr <= r1 - r2;
                        else dr <= r2 - r1;
                        
                        if (c1 > c2) dc <= c1 - c2;
                        else dc <= c2 - c1;
                        
                        if (dr > dc) max_dist <= dr;
                        else max_dist <= dc;
                        
                        temp_sum <= temp_sum + {12'd0, max_dist};
                        
                        // Increment indices
                        j_idx <= j_idx + 4'd1;
                        if (j_idx >= slavko_count - 4'd1) begin
                            j_idx <= i_idx + 4'd2;
                            i_idx <= i_idx + 4'd1;
                        end
                    end else begin
                        calc_done <= 1'b1;
                    end
                    
                    // Completion check
                    if (slavko_count <= 4'd1) begin
                        calc_done <= 1'b1;
                    end else if (i_idx >= slavko_count - 4'd1) begin
                        calc_done <= 1'b1;
                    end
                end
                
                DONE: begin
                    // Output results and pulse done
                    mirko_spread <= (mirko_count > 4'd1) ? temp_sum : 16'd0;
                    slavko_spread <= (slavko_count > 4'd1) ? temp_sum : 16'd0;
                    done <= 1'b1;
                end
                
                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule