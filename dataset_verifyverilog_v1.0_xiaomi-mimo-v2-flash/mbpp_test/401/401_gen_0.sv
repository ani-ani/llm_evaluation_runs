module add_nested_tuples (
    input clk,
    input rst_n,
    input start,
    input [7:0] a [3:0][1:0],
    input [7:0] b [3:0][1:0],
    output reg [15:0] result [3:0][1:0],
    output reg done
);

    // State declarations
    localparam [1:0] IDLE    = 2'd0;
    localparam [1:0] PROCESS = 2'd1;
    localparam [1:0] FINISH  = 2'd2;

    reg [1:0] state;
    reg [2:0] cycle_count;  // 0-3 for 4 rows
    reg start_captured;
    reg [7:0] a_reg [3:0][1:0];
    reg [7:0] b_reg [3:0][1:0];

    integer i, j;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset all registers
            state <= IDLE;
            done <= 1'b0;
            cycle_count <= 3'd0;
            start_captured <= 1'b0;
            
            // Initialize result array
            for (i = 0; i < 4; i = i + 1) begin
                result[i][0] <= 16'd0;
                result[i][1] <= 16'd0;
                a_reg[i][0] <= 8'd0;
                a_reg[i][1] <= 8'd0;
                b_reg[i][0] <= 8'd0;
                b_reg[i][1] <= 8'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 3'd0;
                    
                    if (start) begin
                        // Capture inputs into internal registers
                        start_captured <= 1'b1;
                        for (i = 0; i < 4; i = i + 1) begin
                            a_reg[i][0] <= a[i][0];
                            a_reg[i][1] <= a[i][1];
                            b_reg[i][0] <= b[i][0];
                            b_reg[i][1] <= b[i][1];
                        end
                        state <= PROCESS;
                    end
                end
                
                PROCESS: begin
                    // Compute one row per cycle (4 cycles total)
                    result[cycle_count][0] <= a_reg[cycle_count][0] + b_reg[cycle_count][0];
                    result[cycle_count][1] <= a_reg[cycle_count][1] + b_reg[cycle_count][1];
                    
                    if (cycle_count == 3'd3) begin
                        state <= FINISH;
                    end else begin
                        cycle_count <= cycle_count + 3'd1;
                    end
                end
                
                FINISH: begin
                    done <= 1'b1;  // Assert done for 1 cycle
                    start_captured <= 1'b0;
                    state <= IDLE;
                end
                
                default: begin
                    state <= IDLE;
                    done <= 1'b0;
                    cycle_count <= 3'd0;
                    start_captured <= 1'b0;
                end
            endcase
        end
    end

endmodule