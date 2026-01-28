module sequence_counter(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] m,
    input wire [3:0] n,
    output reg [15:0] result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE     = 2'd0;
    localparam [1:0] INIT     = 2'd1;
    localparam [1:0] COMPUTE  = 2'd2;
    localparam [1:0] COMPLETE = 2'd3;

    // Table dimensions: 17x17 (m+1 x n+1)
    reg [15:0] T [0:16][0:16];

    // State registers
    reg [1:0] state;
    reg [3:0] i_reg;
    reg [3:0] j_reg;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd256;

    // Initialize table
    integer k, l;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            i_reg <= 4'd0;
            j_reg <= 4'd0;
            cycle_count <= 8'd0;
            // Initialize entire table to 0
            for (k = 0; k < 17; k = k + 1) begin
                for (l = 0; l < 17; l = l + 1) begin
                    T[k][l] <= 16'd0;
                end
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= INIT;
                    end
                end

                INIT: begin
                    // Initialize boundary conditions
                    for (k = 1; k < 17; k = k + 1) begin
                        T[k][1] <= k;
                    end
                    state <= COMPUTE;
                    i_reg <= 4'd1;
                    j_reg <= 4'd2;
                end

                COMPUTE: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Compute T[i][j] = T[i-1][j] + T[i//2][j-1]
                    if (j_reg <= n && i_reg <= m) begin
                        if (i_reg >= j_reg) begin
                            T[i_reg][j_reg] <= T[i_reg - 1][j_reg] + T[i_reg >> 1][j_reg - 1];
                        end else begin
                            T[i_reg][j_reg] <= 16'd0;
                        end
                        
                        // Move to next position
                        if (j_reg == n) begin
                            if (i_reg == m) begin
                                state <= COMPLETE;
                            end else begin
                                i_reg <= i_reg + 4'd1;
                                j_reg <= 4'd2;
                            end
                        end else begin
                            j_reg <= j_reg + 4'd1;
                        end
                    end else begin
                        state <= COMPLETE;
                    end
                    
                    // Safety: prevent infinite loops
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= COMPLETE;
                    end
                end

                COMPLETE: begin
                    result <= T[m][n];
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule