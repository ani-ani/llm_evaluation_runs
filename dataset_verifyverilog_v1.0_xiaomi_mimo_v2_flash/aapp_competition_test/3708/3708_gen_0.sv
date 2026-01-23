module min_time_path (
    input wire clk,              // Clock signal
    input wire rst_n,            // Active-low reset
    input wire start,            // Start computation
    input wire setup_mode,       // Setup mode for volcano input
    input wire volcano_valid,    // Valid volcano coordinate
    input wire [3:0] volcano_x,  // Volcano x-coordinate (0-indexed)
    input wire [3:0] volcano_y,  // Volcano y-coordinate (0-indexed)
    input wire [3:0] n,          // Grid size (1-16)
    output reg done,             // Computation complete
    output reg [7:0] result      // Result: steps or 8'hFF for -1
);

    // State encoding
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] COMPUTE = 2'd1;
    localparam [1:0] DONE = 2'd2;

    // Registers
    reg [1:0] state_reg;
    reg [3:0] i_reg, j_reg;       // Current cell indices
    reg [15:0] prev_row_reg;      // Previous row of DP
    reg [15:0] curr_row_reg;      // Current row of DP
    reg [15:0] blocked_rows [0:15]; // Blocked grid (16x16)

    // Combinational bit calculation
    wire bit_val;
    assign bit_val = blocked_rows[i_reg][j_reg] ? 1'b0 :
                     (i_reg == 4'd0 && j_reg == 4'd0) ? 1'b1 :
                     ((i_reg > 4'd0 ? prev_row_reg[j_reg] : 1'b0) |
                      (j_reg > 4'd0 ? curr_row_reg[j_reg-1] : 1'b0));

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset state
            state_reg <= IDLE;
            done <= 1'b0;
            result <= 8'd0;
            i_reg <= 4'd0;
            j_reg <= 4'd0;
            prev_row_reg <= 16'd0;
            curr_row_reg <= 16'd0;
            // Clear blocked grid
            blocked_rows[0] <= 16'd0;
            blocked_rows[1] <= 16'd0;
            blocked_rows[2] <= 16'd0;
            blocked_rows[3] <= 16'd0;
            blocked_rows[4] <= 16'd0;
            blocked_rows[5] <= 16'd0;
            blocked_rows[6] <= 16'd0;
            blocked_rows[7] <= 16'd0;
            blocked_rows[8] <= 16'd0;
            blocked_rows[9] <= 16'd0;
            blocked_rows[10] <= 16'd0;
            blocked_rows[11] <= 16'd0;
            blocked_rows[12] <= 16'd0;
            blocked_rows[13] <= 16'd0;
            blocked_rows[14] <= 16'd0;
            blocked_rows[15] <= 16'd0;
        end else begin
            done <= 1'b0;
            case (state_reg)
                IDLE: begin
                    // Handle volcano setup
                    if (setup_mode && volcano_valid) 
                        blocked_rows[volcano_x][volcano_y] <= 1'b1;
                    
                    if (start) begin
                        // Initialize computation
                        i_reg <= 4'd0;
                        j_reg <= 4'd0;
                        prev_row_reg <= 16'd0;
                        curr_row_reg <= 16'd0;
                        state_reg <= COMPUTE;
                    end
                end
                
                COMPUTE: begin
                    // Update current cell
                    curr_row_reg[j_reg] <= bit_val;
                    
                    // Move to next cell
                    if (j_reg == n - 4'd1) begin
                        j_reg <= 4'd0;
                        if (i_reg == n - 4'd1) begin
                            // Grid complete
                            state_reg <= DONE;
                            result <= bit_val ? ((n - 4'd1) << 1) : 8'hFF;
                        end else begin
                            // Next row
                            i_reg <= i_reg + 4'd1;
                            prev_row_reg <= curr_row_reg;
                        end
                    end else begin
                        j_reg <= j_reg + 4'd1;
                    end
                end
                
                DONE: begin
                    done <= 1'b1;
                    state_reg <= IDLE;
                end
                
                default: state_reg <= IDLE;
            endcase
        end
    end
endmodule