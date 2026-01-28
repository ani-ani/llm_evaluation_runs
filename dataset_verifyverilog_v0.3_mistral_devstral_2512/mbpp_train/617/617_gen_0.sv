module JumpCalculator(
    input clk,
    input rst_n,
    input start,
    input [7:0] step_a,
    input [7:0] step_b,
    input [7:0] target_d,
    output reg [15:0] result,
    output reg done
);

    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] COMPUTE = 2'd1;
    localparam [1:0] FINISH = 2'd2;
    
    reg [1:0] state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd100;

    reg [7:0] min_step;
    reg [7:0] max_step;
    reg [15:0] temp_result;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            min_step <= 8'd0;
            max_step <= 8'd0;
            temp_result <= 16'd0;
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
                    
                    min_step <= (step_a < step_b) ? step_a : step_b;
                    max_step <= (step_a > step_b) ? step_a : step_b;
                    
                    if (target_d == 8'd0) begin
                        temp_result <= 16'd0;
                    end else if (target_d == min_step) begin
                        temp_result <= 16'd256;
                    end else if (target_d >= max_step) begin
                        temp_result <= (target_d << 8) / max_step;
                    end else begin
                        temp_result <= 16'd512;
                    end
                    
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= FINISH;
                    end else begin
                        state <= FINISH;
                    end
                end
                
                FINISH: begin
                    result <= temp_result;
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule