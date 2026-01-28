module sum_of_squares(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [5:0] n,
    output reg [15:0] result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE    = 2'd0;
    localparam [1:0] COMPUTE = 2'd1;
    localparam [1:0] FINISH  = 2'd2;
    
    reg [1:0] state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd100;
    
    reg [5:0] n_reg;
    reg [19:0] intermediate;
    reg [15:0] result_reg;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            n_reg <= 6'd0;
            intermediate <= 20'd0;
            result_reg <= 16'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        n_reg <= n;
                        state <= COMPUTE;
                    end
                end
                
                COMPUTE: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Calculate using closed-form formula: 2*n*(n+1)*(2*n+1)/3
                    intermediate <= 20'd2 * n_reg * (n_reg + 6'd1) * (20'd2 * n_reg + 20'd1);
                    result_reg <= intermediate / 20'd3;
                    
                    // Exit condition
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= FINISH;
                    end else begin
                        state <= FINISH;
                    end
                end
                
                FINISH: begin
                    result <= result_reg;
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule