module JacobsthalFSM(
    input clk,
    input rst_n,
    input start,
    input [3:0] n,
    output reg [15:0] result,
    output reg done
);
    
    // State declarations
    localparam [2:0] IDLE    = 3'd0;
    localparam [2:0] COMPUTE = 3'd1;
    localparam [2:0] FINISH  = 3'd2;
    
    // Internal registers
    reg [2:0] state;
    reg [15:0] j_prev;
    reg [15:0] j_curr;
    reg [3:0] cycle_count;
    localparam [3:0] MAX_CYCLES = 4'd15;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            j_prev <= 16'd0;
            j_curr <= 16'd0;
            cycle_count <= 4'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 4'd0;
                    if (start) begin
                        // Handle n=0 and n=1 cases immediately
                        if (n == 4'd0) begin
                            result <= 16'd0;
                            state <= FINISH;
                        end else if (n == 4'd1) begin
                            result <= 16'd1;
                            state <= FINISH;
                        end else begin
                            // Initialize for n >= 2
                            j_prev <= 16'd0;  // J(0)
                            j_curr <= 16'd1;  // J(1)
                            state <= COMPUTE;
                        end
                    end
                end
                
                COMPUTE: begin
                    cycle_count <= cycle_count + 4'd1;
                    
                    // Compute next Jacobsthal number
                    j_curr <= j_curr + (j_prev << 1);
                    j_prev <= j_curr - (j_prev << 1);
                    
                    // Check if computation is complete
                    if (cycle_count == (n - 4'd2)) begin
                        result <= j_curr;
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