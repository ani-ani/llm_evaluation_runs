module sequence_counter(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [4:0] m,
    input wire [2:0] n,
    output reg [15:0] result,
    output reg done
);

    // FSM states
    reg [2:0] state;
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] INIT_BASE = 3'd1;
    localparam [2:0] COMPUTE = 3'd2;
    localparam [2:0] FINISH = 3'd3;

    // Table storage: T[17][5] for i=0..16, j=0..4
    reg [15:0] T[16:0][4:0];
    
    // Iteration counters
    reg [4:0] i;
    reg [2:0] j;
    
    // Computation registers
    reg [15:0] temp_sum;
    reg [4:0] i_half;
    reg computing;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd200;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            i <= 5'd0;
            j <= 3'd0;
            computing <= 1'b0;
            cycle_count <= 8'd0;
            // Initialize table
            integer k, l;
            for (k = 0; k < 17; k = k + 1) begin
                for (l = 0; l < 5; l = l + 1) begin
                    T[k][l] <= 16'd0;
                end
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        i <= 5'd0;
                        j <= 3'd0;
                        state <= INIT_BASE;
                    end
                end
                
                INIT_BASE: begin
                    cycle_count <= cycle_count + 8'd1;
                    // Initialize base cases
                    if (i == 0 || j == 0 || i < j) begin
                        T[i][j] <= 16'd0;
                    end else if (j == 1) begin
                        T[i][j] <= i;
                    end
                    
                    // Move to next cell
                    if (j < 4 && j < n) begin
                        j <= j + 1;
                    end else begin
                        j <= 3'd0;
                        if (i < 16 && i < m) begin
                            i <= i + 1;
                        end else if (i == m && j == 0) begin
                            // All initialized, now compute recursively
                            i <= 2;
                            j <= 2;
                            computing <= 1'b0;
                            state <= COMPUTE;
                        end else begin
                            i <= i + 1;
                            j <= 3'd0;
                        end
                    end
                    
                    // Safety check
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= FINISH;
                    end
                end
                
                COMPUTE: begin
                    cycle_count <= cycle_count + 8'd1;
                    if (computing) begin
                        // Complete recursive computation
                        if (j > 1 && i_half > 0) begin
                            temp_sum <= temp_sum + T[i_half][j-1];
                        end
                        T[i][j] <= temp_sum;
                        computing <= 1'b0;
                        
                        // Move to next entry
                        if (j < 4 && j < n) begin
                            j <= j + 1;
                        end else begin
                            j <= 2;
                            if (i < 16 && i < m) begin
                                i <= i + 1;
                            end else begin
                                result <= T[m][n];
                                done <= 1'b1;
                                state <= FINISH;
                            end
                        end
                    end else if (i <= m && j <= n) begin
                        // Check if base case
                        if (i < j || j == 0 || j == 1) begin
                            // Skip or already initialized
                            if (j < n) begin
                                j <= j + 1;
                            end else begin
                                j <= 2;
                                if (i < m) begin
                                    i <= i + 1;
                                end else begin
                                    result <= T[m][n];
                                    done <= 1'b1;
                                    state <= FINISH;
                                end
                            end
                        end else begin
                            // Need to compute
                            computing <= 1'b1;
                            i_half <= i >> 1;
                            temp_sum <= T[i-1][j];
                        end
                    end
                    
                    // Safety check
                    if (cycle_count >= MAX_CYCLES) begin
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