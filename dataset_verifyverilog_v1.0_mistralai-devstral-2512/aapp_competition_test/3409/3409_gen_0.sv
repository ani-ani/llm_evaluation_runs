module peg_hammering_game(
    input clk,
    input rst_n,
    input start,
    input [7:0] start_board [0:7],
    input [7:0] target_board [0:7],
    output reg result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] COMPUTE = 3'd1;
    localparam [2:0] CHECK = 3'd2;
    localparam [2:0] FINISH = 3'd3;
    
    reg [2:0] state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd100;
    
    // Intermediate signals
    reg [7:0] diff_row [0:7];
    reg [7:0] diff_col [0:7];
    reg [7:0] row_xor [0:7];
    reg [7:0] col_xor [0:7];
    reg [7:0] row_parity [0:7];
    reg [7:0] col_parity [0:7];
    reg [7:0] row_check [0:7];
    reg [7:0] col_check [0:7];
    
    integer i, j;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 1'b0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            
            // Initialize all registers
            for (i = 0; i < 8; i = i + 1) begin
                diff_row[i] <= 8'd0;
                diff_col[i] <= 8'd0;
                row_xor[i] <= 8'd0;
                col_xor[i] <= 8'd0;
                row_parity[i] <= 8'd0;
                col_parity[i] <= 8'd0;
                row_check[i] <= 8'd0;
                col_check[i] <= 8'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= COMPUTE;
                    end
                end
                
                COMPUTE: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Compute difference matrix
                    for (i = 0; i < 8; i = i + 1) begin
                        for (j = 0; j < 8; j = j + 1) begin
                            diff_row[i][j] <= start_board[i][j] ^ target_board[i][j];
                            diff_col[j][i] <= start_board[i][j] ^ target_board[i][j];
                        end
                    end
                    
                    // Compute row XOR
                    for (i = 0; i < 8; i = i + 1) begin
                        row_xor[i] <= ^diff_row[i];
                    end
                    
                    // Compute column XOR
                    for (j = 0; j < 8; j = j + 1) begin
                        col_xor[j] <= ^diff_col[j];
                    end
                    
                    state <= CHECK;
                end
                
                CHECK: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Compute row parity
                    for (i = 0; i < 8; i = i + 1) begin
                        row_parity[i] <= ^row_xor[i];
                    end
                    
                    // Compute column parity
                    for (j = 0; j < 8; j = j + 1) begin
                        col_parity[j] <= ^col_xor[j];
                    end
                    
                    // Check if all row parities are equal
                    row_check[0] <= row_parity[0];
                    for (i = 1; i < 8; i = i + 1) begin
                        row_check[i] <= row_check[i-1] ^ row_parity[i];
                    end
                    
                    // Check if all column parities are equal
                    col_check[0] <= col_parity[0];
                    for (j = 1; j < 8; j = j + 1) begin
                        col_check[j] <= col_check[j-1] ^ col_parity[j];
                    end
                    
                    // Determine result
                    if ((row_check[7] == 1'b0) && (col_check[7] == 1'b0)) begin
                        result <= 1'b1;
                    end else begin
                        result <= 1'b0;
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