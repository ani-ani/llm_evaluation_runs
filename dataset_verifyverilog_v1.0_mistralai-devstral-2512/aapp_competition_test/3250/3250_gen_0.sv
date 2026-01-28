module DivisibilityHack(
    input clk,
    input rst_n,
    input start,
    input [15:0] b,
    input [15:0] d,
    output reg result,
    output reg done
);
    
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] COMPUTE = 2'd1;
    localparam [1:0] FINISH = 2'd2;
    
    reg [1:0] state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd100;
    
    reg [15:0] b_reg;
    reg [15:0] d_reg;
    reg [15:0] b_mod_d;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 1'b0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            b_reg <= 16'd0;
            d_reg <= 16'd0;
            b_mod_d <= 16'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        b_reg <= b;
                        d_reg <= d;
                        state <= COMPUTE;
                    end
                end
                
                COMPUTE: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    if (d_reg == 16'd0) begin
                        b_mod_d <= 16'd0;
                    end else begin
                        b_mod_d <= b_reg % d_reg;
                    end
                    
                    if (b_mod_d == 16'd1) begin
                        result <= 1'b1;
                    end else begin
                        result <= 1'b0;
                    end
                    
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= FINISH;
                    end else begin
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