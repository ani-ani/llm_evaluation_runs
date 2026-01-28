module matrix_reconstructor(
    input clk,
    input rst_n,
    input start,
    input [15:0] row_parity,
    input [15:0] col_parity,
    input [3:0] n,
    input [3:0] m,
    output reg [255:0] matrix_out,
    output reg valid,
    output reg done,
    output reg impossible
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] INIT = 3'd1;
    localparam [2:0] ROW_PROCESS = 3'd2;
    localparam [2:0] COL_PROCESS = 3'd3;
    localparam [2:0] VALIDATE = 3'd4;
    localparam [2:0] FINISH = 3'd5;

    reg [2:0] state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd500;

    // Internal matrix storage (16x16)
    reg [15:0] matrix [0:15];

    // Counters
    reg [3:0] row_counter;
    reg [3:0] col_counter;

    // Row and column parity validation
    reg [15:0] row_parity_calc;
    reg [15:0] col_parity_calc;

    // Temporary registers
    reg [3:0] temp_row;
    reg [3:0] temp_col;
    reg [15:0] temp_parity;

    // Main FSM
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            cycle_count <= 8'd0;
            valid <= 1'b0;
            done <= 1'b0;
            impossible <= 1'b0;
            matrix_out <= 256'd0;
            row_counter <= 4'd0;
            col_counter <= 4'd0;
            temp_row <= 4'd0;
            temp_col <= 4'd0;
            temp_parity <= 16'd0;
            row_parity_calc <= 16'd0;
            col_parity_calc <= 16'd0;
            for (temp_row = 0; temp_row < 16; temp_row = temp_row + 1) begin
                matrix[temp_row] <= 16'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    valid <= 1'b0;
                    impossible <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= INIT;
                    end
                end

                INIT: begin
                    cycle_count <= cycle_count + 8'd1;
                    // Initialize matrix to all zeros
                    for (temp_row = 0; temp_row < 16; temp_row = temp_row + 1) begin
                        matrix[temp_row] <= 16'd0;
                    end
                    row_counter <= 4'd0;
                    col_counter <= 4'd0;
                    state <= ROW_PROCESS;
                end

                ROW_PROCESS: begin
                    cycle_count <= cycle_count + 8'd1;
                    if (row_counter < n) begin
                        // Set last element of row if parity is 1
                        if (row_parity[row_counter]) begin
                            matrix[row_counter][m-1] <= 1'b1;
                        end
                        row_counter <= row_counter + 4'd1;
                    end else begin
                        row_counter <= 4'd0;
                        state <= COL_PROCESS;
                    end
                end

                COL_PROCESS: begin
                    cycle_count <= cycle_count + 8'd1;
                    if (col_counter < m) begin
                        // Calculate current column parity
                        temp_parity <= 16'd0;
                        for (temp_row = 0; temp_row < n; temp_row = temp_row + 1) begin
                            temp_parity <= temp_parity ^ matrix[temp_row][col_counter];
                        end
                        
                        // If mismatch, set last row element
                        if (temp_parity != col_parity[col_counter]) begin
                            matrix[n-1][col_counter] <= 1'b1;
                        end
                        col_counter <= col_counter + 4'd1;
                    end else begin
                        col_counter <= 4'd0;
                        state <= VALIDATE;
                    end
                end

                VALIDATE: begin
                    cycle_count <= cycle_count + 8'd1;
                    // Calculate row parities
                    row_parity_calc <= 16'd0;
                    for (temp_row = 0; temp_row < n; temp_row = temp_row + 1) begin
                        temp_parity <= 16'd0;
                        for (temp_col = 0; temp_col < m; temp_col = temp_col + 1) begin
                            temp_parity <= temp_parity ^ matrix[temp_row][temp_col];
                        end
                        row_parity_calc[temp_row] <= temp_parity;
                    end
                    
                    // Calculate column parities
                    col_parity_calc <= 16'd0;
                    for (temp_col = 0; temp_col < m; temp_col = temp_col + 1) begin
                        temp_parity <= 16'd0;
                        for (temp_row = 0; temp_row < n; temp_row = temp_row + 1) begin
                            temp_parity <= temp_parity ^ matrix[temp_row][temp_col];
                        end
                        col_parity_calc[temp_col] <= temp_parity;
                    end
                    
                    // Check if all parities match
                    if ((row_parity_calc[15:0] == row_parity[15:0]) && 
                        (col_parity_calc[15:0] == col_parity[15:0])) begin
                        valid <= 1'b1;
                        impossible <= 1'b0;
                    end else begin
                        valid <= 1'b0;
                        impossible <= 1'b1;
                    end
                    state <= FINISH;
                end

                FINISH: begin
                    done <= 1'b1;
                    // Pack matrix into output
                    for (temp_row = 0; temp_row < 16; temp_row = temp_row + 1) begin
                        matrix_out[(15-temp_row)*16 + 15 : (15-temp_row)*16] <= matrix[temp_row];
                    end
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule