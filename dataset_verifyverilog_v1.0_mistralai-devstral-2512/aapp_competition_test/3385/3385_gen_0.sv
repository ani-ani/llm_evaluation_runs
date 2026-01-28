module ParityCounter(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] N,
    input wire [3:0] l [0:15],
    input wire [3:0] r [0:15],
    input wire x [0:15],
    output reg [31:0] result,
    output reg valid,
    output reg done
);

    // Constants
    localparam [31:0] MOD = 32'd1000000007;
    localparam [3:0] MAX_N = 4'd16;

    // States
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] SETUP = 3'd1;
    localparam [2:0] ELIMINATE = 3'd2;
    localparam [2:0] COMPUTE = 3'd3;
    localparam [2:0] FINISH = 3'd4;

    // State registers
    reg [2:0] state;
    reg [3:0] row, col;
    reg [3:0] rank;
    reg [3:0] pivot_row;
    reg [3:0] i, j, k;

    // System matrix (N x (N+1)) - flattened
    reg [7:0] matrix [0:255];

    // Temporary registers
    reg [7:0] temp;
    reg [31:0] count;
    reg [3:0] current_N;

    // Cycle counter to prevent infinite loops
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd200;

    // Initialize all registers
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            row <= 4'd0;
            col <= 4'd0;
            rank <= 4'd0;
            pivot_row <= 4'd0;
            i <= 4'd0;
            j <= 4'd0;
            k <= 4'd0;
            temp <= 8'd0;
            count <= 32'd0;
            current_N <= 4'd0;
            cycle_count <= 8'd0;
            result <= 32'd0;
            valid <= 1'b0;
            done <= 1'b0;

            // Initialize matrix
            for (i = 0; i < 16; i = i + 1) begin
                for (j = 0; j < 17; j = j + 1) begin
                    matrix[i * 17 + j] <= 8'd0;
                end
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    valid <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= SETUP;
                        current_N <= N;
                    end
                end

                SETUP: begin
                    // Build system matrix
                    for (i = 0; i < current_N; i = i + 1) begin
                        // Set x_i in last column
                        matrix[i * 17 + 16] <= x[i];
                        
                        // Set coefficients for children in range [i-l_i, i+r_i]
                        for (j = 0; j < current_N; j = j + 1) begin
                            if ((j >= (i - l[i])) && (j <= (i + r[i]))) begin
                                matrix[i * 17 + j] <= 1'b1;
                            end else begin
                                matrix[i * 17 + j] <= 1'b0;
                            end
                        end
                    end
                    
                    // Initialize elimination variables
                    row <= 4'd0;
                    col <= 4'd0;
                    rank <= 4'd0;
                    state <= ELIMINATE;
                end

                ELIMINATE: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Find pivot in current column
                    pivot_row <= 4'd0;
                    for (i = row; i < current_N; i = i + 1) begin
                        if (matrix[i * 17 + col] == 1'b1) begin
                            pivot_row <= i;
                            break;
                        end
                    end
                    
                    // If pivot found
                    if (pivot_row != 4'd0) begin
                        // Swap rows if needed
                        if (pivot_row != row) begin
                            for (j = 0; j < 17; j = j + 1) begin
                                temp <= matrix[row * 17 + j];
                                matrix[row * 17 + j] <= matrix[pivot_row * 17 + j];
                                matrix[pivot_row * 17 + j] <= temp;
                            end
                        end
                        
                        // Eliminate this column in all other rows
                        for (i = 0; i < current_N; i = i + 1) begin
                            if (i != row && matrix[i * 17 + col] == 1'b1) begin
                                for (j = 0; j < 17; j = j + 1) begin
                                    matrix[i * 17 + j] <= matrix[i * 17 + j] ^ matrix[row * 17 + j];
                                end
                            end
                        end
                        
                        // Move to next row and column
                        rank <= rank + 4'd1;
                        row <= row + 4'd1;
                    end
                    
                    // Move to next column
                    col <= col + 4'd1;
                    
                    // Check if elimination is complete
                    if (col >= current_N || row >= current_N) begin
                        state <= COMPUTE;
                    end
                    
                    // Safety check
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= FINISH;
                    end
                end

                COMPUTE: begin
                    // Check for consistency (last column all zeros in zero rows)
                    valid <= 1'b1;
                    for (i = rank; i < current_N; i = i + 1) begin
                        if (matrix[i * 17 + 16] != 1'b0) begin
                            valid <= 1'b0;
                        end
                    end
                    
                    // Compute result = 2^(N - rank) mod MOD
                    if (valid) begin
                        count <= 32'd1;
                        for (i = 0; i < (current_N - rank); i = i + 1) begin
                            count <= (count * 32'd2) % MOD;
                        end
                        result <= count;
                    end else begin
                        result <= 32'd0;
                    end
                    
                    state <= FINISH;
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