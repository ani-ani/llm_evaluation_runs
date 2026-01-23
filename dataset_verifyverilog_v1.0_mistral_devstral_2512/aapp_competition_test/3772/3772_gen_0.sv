module resistor_network(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [63:0] a_in,
    input wire [63:0] b_in,
    output reg [63:0] result,
    output reg done
);

    // State declarations
    localparam [0:0] IDLE = 1'b0;
    localparam [0:0] COMPUTE = 1'b1;
    
    // Internal registers
    reg [0:0] state;
    reg [63:0] a_reg;
    reg [63:0] b_reg;
    reg [63:0] count_reg;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd200;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            a_reg <= 64'd0;
            b_reg <= 64'd0;
            count_reg <= 64'd0;
            result <= 64'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        a_reg <= a_in;
                        b_reg <= b_in;
                        count_reg <= 64'd0;
                        state <= COMPUTE;
                    end
                end
                
                COMPUTE: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    if (b_reg == 64'd0 || cycle_count >= MAX_CYCLES) begin
                        result <= count_reg;
                        done <= 1'b1;
                        state <= IDLE;
                    end else begin
                        // GCD computation
                        count_reg <= count_reg + (a_reg / b_reg);
                        a_reg <= b_reg;
                        b_reg <= a_reg % b_reg;
                    end
                end
                
                default: state <= IDLE;
            endcase
        end
    end

endmodule