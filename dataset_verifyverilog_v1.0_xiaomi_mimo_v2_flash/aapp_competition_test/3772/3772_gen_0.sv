module resistor_network (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [63:0] a_in,
    input wire [63:0] b_in,
    output reg [63:0] result,
    output reg done
);

    // State encoding
    localparam [0:0] IDLE = 1'd0;
    localparam [0:0] COMPUTE = 1'd1;
    
    // Internal registers
    reg state;
    reg [63:0] a, b, count;
    reg [63:0] temp_a, temp_b;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            a <= 64'd0;
            b <= 64'd0;
            temp_a <= 64'd0;
            temp_b <= 64'd0;
            count <= 64'd0;
            result <= 64'd0;
            done <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        a <= a_in;
                        b <= b_in;
                        count <= 64'd0;
                        state <= COMPUTE;
                    end
                end
                
                COMPUTE: begin
                    if (b == 64'd0) begin
                        result <= count;
                        done <= 1'b1;
                        state <= IDLE;
                    end else begin
                        // quotient = a / b (integer division)
                        count <= count + (a / b);
                        // Update: a = b, b = a % b
                        temp_a <= b;
                        temp_b <= a % b;
                        a <= b;
                        b <= a % b;
                    end
                end
                
                default: state <= IDLE;
            endcase
        end
    end

endmodule