module bitstring_xor(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] a,
    input wire [7:0] b,
    input wire [3:0] len,
    output reg [7:0] result,
    output reg done
);
    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] COMPUTE = 2'd1;
    localparam [1:0] FINISH = 2'd2;
    
    reg [1:0] state;
    reg [3:0] bit_counter;
    reg [7:0] result_temp;
    reg [7:0] a_reg;
    reg [7:0] b_reg;
    reg [3:0] len_reg;
    reg start_reg;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 8'd0;
            done <= 1'b0;
            bit_counter <= 4'd0;
            result_temp <= 8'd0;
            a_reg <= 8'd0;
            b_reg <= 8'd0;
            len_reg <= 4'd0;
            start_reg <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    result <= 8'd0;
                    bit_counter <= 4'd0;
                    result_temp <= 8'd0;
                    
                    if (start) begin
                        a_reg <= a;
                        b_reg <= b;
                        len_reg <= len;
                        start_reg <= 1'b1;
                        state <= COMPUTE;
                    end
                end
                
                COMPUTE: begin
                    start_reg <= 1'b0;
                    
                    if (bit_counter < len_reg) begin
                        // Compute XOR for current bit position
                        result_temp[bit_counter] <= a_reg[bit_counter] ^ b_reg[bit_counter];
                        bit_counter <= bit_counter + 4'd1;
                    end else begin
                        // All bits processed
                        state <= FINISH;
                    end
                end
                
                FINISH: begin
                    result <= result_temp;
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule