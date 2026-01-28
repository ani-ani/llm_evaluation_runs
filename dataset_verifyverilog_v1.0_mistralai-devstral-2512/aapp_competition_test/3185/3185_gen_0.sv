module inverse_factorial(
    input wire clk,
    input wire rst_n,
    input wire [63:0] x,
    output reg [7:0] n,
    output reg valid,
    output reg done
);
    
    // State declarations
    localparam [2:0] IDLE    = 3'd0;
    localparam [2:0] COMPUTE = 3'd1;
    localparam [2:0] FINISH  = 3'd2;
    
    reg [2:0] state;
    reg [63:0] accumulator;
    reg [7:0] i;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd30;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            accumulator <= 64'd1;
            i <= 8'd2;
            n <= 8'd0;
            valid <= 1'b0;
            done <= 1'b0;
            cycle_count <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    valid <= 1'b0;
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (x != 64'd0) begin
                        state <= COMPUTE;
                    end
                end
                
                COMPUTE: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Multiply accumulator by i
                    if (accumulator * i >= x || cycle_count >= MAX_CYCLES) begin
                        n <= i - 8'd1;
                        state <= FINISH;
                    end else begin
                        accumulator <= accumulator * i;
                        i <= i + 8'd1;
                    end
                end
                
                FINISH: begin
                    valid <= 1'b1;
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
    
    // Reset valid after one cycle
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            valid <= 1'b0;
        end else if (state == FINISH) begin
            valid <= 1'b0;
        end
    end

endmodule