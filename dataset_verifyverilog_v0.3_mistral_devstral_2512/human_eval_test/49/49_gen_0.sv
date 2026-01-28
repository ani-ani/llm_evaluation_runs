module modp(
    input clk,
    input rst_n,
    input start,
    input [7:0] n,
    input [7:0] p,
    output reg [7:0] result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE    = 2'd0;
    localparam [1:0] COMPUTE = 2'd1;
    localparam [1:0] DONE_STATE = 2'd2;
    
    reg [1:0] state;
    reg [7:0] base;
    reg [7:0] current_result;
    reg [7:0] bit_counter;
    reg [7:0] temp;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 8'd0;
            done <= 1'b0;
            base <= 8'd0;
            current_result <= 8'd0;
            bit_counter <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= COMPUTE;
                        base <= 2'd2;  // Initialize base to 2
                        current_result <= 8'd1;  // Initialize result to 1
                        bit_counter <= 8'd0;  // Start with bit 0
                    end
                end
                
                COMPUTE: begin
                    // Square the base modulo p
                    temp <= (base * base) % p;
                    base <= temp;
                    
                    // If current bit of n is set, multiply result by base modulo p
                    if (n[bit_counter]) begin
                        temp <= (current_result * base) % p;
                        current_result <= temp;
                    end
                    
                    // Increment bit counter
                    bit_counter <= bit_counter + 8'd1;
                    
                    // Check if all 8 bits processed
                    if (bit_counter == 8'd8) begin
                        result <= current_result;
                        state <= DONE_STATE;
                    end
                end
                
                DONE_STATE: begin
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule