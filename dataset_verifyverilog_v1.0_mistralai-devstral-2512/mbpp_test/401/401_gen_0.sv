module add_nested_tuples(
    input clk,
    input rst_n,
    input start,
    input [7:0] a [0:3][0:1],
    input [7:0] b [0:3][0:1],
    output reg [15:0] result [0:3][0:1],
    output reg done
);

    // State declarations
    localparam [2:0] IDLE    = 3'd0;
    localparam [2:0] LOAD    = 3'd1;
    localparam [2:0] COMPUTE = 3'd2;
    localparam [2:0] FINISH  = 3'd3;
    
    reg [2:0] state;
    reg [1:0] row_counter;
    reg [7:0] a_reg [0:3][0:1];
    reg [7:0] b_reg [0:3][0:1];
    reg [15:0] result_reg [0:3][0:1];
    
    // Initialize all registers
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            row_counter <= 2'd0;
            done <= 1'b0;
            
            // Initialize result array
            integer i, j;
            for (i = 0; i < 4; i = i + 1) begin
                for (j = 0; j < 2; j = j + 1) begin
                    result[i][j] <= 16'd0;
                    result_reg[i][j] <= 16'd0;
                    a_reg[i][j] <= 8'd0;
                    b_reg[i][j] <= 8'd0;
                end
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= LOAD;
                    end
                end
                
                LOAD: begin
                    // Load input arrays into registers
                    integer i, j;
                    for (i = 0; i < 4; i = i + 1) begin
                        for (j = 0; j < 2; j = j + 1) begin
                            a_reg[i][j] <= a[i][j];
                            b_reg[i][j] <= b[i][j];
                        end
                    end
                    row_counter <= 2'd0;
                    state <= COMPUTE;
                end
                
                COMPUTE: begin
                    // Compute one row per cycle
                    integer j;
                    for (j = 0; j < 2; j = j + 1) begin
                        result_reg[row_counter][j] <= a_reg[row_counter][j] + b_reg[row_counter][j];
                    end
                    
                    // Update output
                    for (j = 0; j < 2; j = j + 1) begin
                        result[row_counter][j] <= result_reg[row_counter][j];
                    end
                    
                    // Move to next row or finish
                    if (row_counter == 3) begin
                        state <= FINISH;
                    end else begin
                        row_counter <= row_counter + 1'b1;
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