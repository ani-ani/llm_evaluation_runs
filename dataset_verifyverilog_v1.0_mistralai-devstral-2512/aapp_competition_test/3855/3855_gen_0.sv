module bit_length_calculator(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [29:0] n,
    output reg [4:0] result,
    output reg done
);
    
    // State declarations
    localparam [1:0] IDLE    = 2'd0;
    localparam [1:0] COMPUTE = 2'd1;
    localparam [1:0] FINISH  = 2'd2;
    
    reg [1:0] state;
    reg [7:0] cycle_count;
    reg [29:0] temp_n;
    reg [4:0] bit_count;
    localparam [7:0] MAX_CYCLES = 8'd100;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 5'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            temp_n <= 30'd0;
            bit_count <= 5'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        temp_n <= n;
                        bit_count <= 5'd0;
                        state <= COMPUTE;
                    end
                end
                
                COMPUTE: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Count bits by shifting right until zero
                    if (temp_n > 30'd0) begin
                        temp_n <= temp_n >> 1;
                        bit_count <= bit_count + 5'd1;
                    end
                    
                    // Exit conditions
                    if ((temp_n == 30'd0) || (cycle_count >= MAX_CYCLES)) begin
                        // Handle n=0 case (should be 1 bit by definition)
                        if (n == 30'd0) begin
                            result <= 5'd1;
                        end else begin
                            result <= bit_count;
                        end
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