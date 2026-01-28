module CubeVolumeCalculator(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] side,
    output reg [23:0] volume,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] COMPUTE = 2'd1;
    localparam [1:0] FINISH = 2'd2;
    
    // Internal registers
    reg [1:0] state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd100;
    
    // Pipeline registers
    reg [15:0] intermediate;
    reg [23:0] final_result;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            volume <= 24'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            intermediate <= 16'd0;
            final_result <= 24'd0;
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
                    
                    // Pipeline stage 1: side * side
                    intermediate <= side * side;
                    
                    // Pipeline stage 2: intermediate * side
                    final_result <= intermediate * side;
                    
                    // Exit conditions
                    if (cycle_count >= 2'd2 || cycle_count >= MAX_CYCLES) begin
                        state <= FINISH;
                    end
                end
                
                FINISH: begin
                    volume <= final_result;
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule