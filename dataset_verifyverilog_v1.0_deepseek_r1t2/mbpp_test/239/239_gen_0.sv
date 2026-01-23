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
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] INIT_BASE = 3'd1;
    localparam [2:0] COMPUTE = 3'd2;
    localparam [2:0] FINISH = 3'd3;
    
    reg [2:0] state;
    
    // Table storage
    reg [15:0] T [0:16][0:4];
    
    // Iteration counters
    reg [4:0] i;
    reg [2:0] j;
    
    // Computation registers
    reg [15:0] temp_sum;
    reg [4:0] k;
    reg [4:0] i_half;
    reg computing;
    reg [7:0] cycle_count;
    
    integer a, b;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            result <= 16'd0;
            done <= 1'b0;
            state <= IDLE;
            i <= 5'd0;
            j <= 3'd0;
            temp_sum <= 16'd0;
            k <= 5'd0;
            i_half <= 5'd0;
            computing <= 1'b0;
            cycle_count <= 8'd0;
            
            // Initialize T array to 0
            for (a = 0; a <= 16; a = a + 1) begin
                for (b = 0; b <= 4; b = b + 1) begin
                    T[a][b] <= 16'd0;
                end
            end
        end
        else begin
            cycle_count <= cycle_count + 8'd1;
            
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
                    // Base case handling
                    if (i == 5'd0 || j == 3'd0 || i < j) begin
                        T[i][j] <= 16'd0;
                    end
                    else if (j == 3'd1) begin
                        T[i][j] <= {11'd0, i};
                    end
                    
                    // Iteration logic
                    if (j < n && j < 3'd4) begin
                        j <= j + 3'd1;
                    end
                    else begin
                        j <= 3'd0;
                        if (i < m && i < 5'd16) begin
                            i <= i + 5'd1;
                        end
                        else begin
                            i <= 5'd2;
                            j <= 3'd2;
                            state <= COMPUTE;
                        end
                    end
                end
                
                COMPUTE: begin
                    if (!computing) begin
                        if (i > m || j > n) begin
                            result <= T[m][n];
                            done <= 1'b1;
                            state <= FINISH;
                        end
                        else if (i < j || j < 3'd2) begin
                            // Skip to next cell
                            if (j < n && j < 3'd4) begin
                                j <= j + 3'd1;
                            end
                            else begin
                                j <= 3'd2;
                                if (i < m && i < 5'd16) begin
                                    i <= i + 5'd1;
                                end
                                else begin
                                    result <= T[m][n];
                                    done <= 1'b1;
                                    state <= FINISH;
                                end
                            end
                        end
                        else begin
                            // Start computation for current cell
                            temp_sum <= T[i-5'd1][j];
                            k <= 5'd1;
                            i_half <= i >> 1;
                            computing <= 1'b1;
                        end
                    end
                    else begin
                        if (k <= i_half) begin
                            temp_sum <= temp_sum + T[k][j-3'd1];
                            k <= k + 5'd1;
                        end
                        else begin
                            T[i][j] <= temp_sum;
                            computing <= 1'b0;
                            // Move to next cell
                            if (j < n && j < 3'd4) begin
                                j <= j + 3'd1;
                            end
                            else begin
                                j <= 3'd2;
                                if (i < m && i < 5'd16) begin
                                    i <= i + 5'd1;
                                end
                                else begin
                                    result <= T[m][n];
                                    done <= 1'b1;
                                    state <= FINISH;
                                end
                            end
                        end
                    end
                end
                
                FINISH: begin
                    done <= 1'b0;
                    state <= IDLE;
                end
                
                default: begin
                    state <= IDLE;
                end
            endcase
            
            // Timeout handling
            if (cycle_count > 8'd200) begin
                result <= T[m][n];
                done <= 1'b1;
                state <= FINISH;
            end
        end
    end
    
endmodule