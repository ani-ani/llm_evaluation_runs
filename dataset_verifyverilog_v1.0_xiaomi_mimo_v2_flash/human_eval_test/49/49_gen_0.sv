module modp (
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
    localparam [1:0] DONE    = 2'd2;
    
    reg [1:0] state;
    reg [2:0] bit_counter; // 0 to 7 for 8 bits
    reg [7:0] base;
    reg [7:0] current_result;
    
    // Intermediate calculation registers
    reg [7:0] base_squared;
    reg [7:0] temp_result;
    reg [15:0] mult_temp;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 8'd0;
            done <= 1'b0;
            bit_counter <= 3'd0;
            base <= 8'd0;
            current_result <= 8'd0;
            base_squared <= 8'd0;
            temp_result <= 8'd0;
            mult_temp <= 16'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    bit_counter <= 3'd0;
                    if (start) begin
                        // Initialize: base = 2 % p, result = 1 % p
                        base <= 8'd2 % p;
                        current_result <= 8'd1 % p;
                        state <= COMPUTE;
                    end
                end
                
                COMPUTE: begin
                    // Cycle 0: Square the base modulo p
                    if (bit_counter == 3'd0) begin
                        mult_temp <= base * base;
                    end
                    // Cycle 1: Compute base_squared = (base * base) % p
                    else if (bit_counter == 3'd1) begin
                        base_squared <= mult_temp % p;
                    end
                    // Cycle 2: Check if current bit of n is set
                    else if (bit_counter == 3'd2) begin
                        if (n[7 - (bit_counter - 2'd2)]) begin
                            temp_result <= current_result;
                        end
                    end
                    // Cycle 3: Prepare multiplication if bit is set
                    else if (bit_counter == 3'd3) begin
                        if (n[7 - (bit_counter - 2'd3)]) begin
                            mult_temp <= temp_result * base_squared;
                        end
                    end
                    // Cycle 4: Compute result modulo p
                    else if (bit_counter == 3'd4) begin
                        if (n[7 - (bit_counter - 2'd4)]) begin
                            current_result <= mult_temp % p;
                        end
                    end
                    // Cycle 5: Update base for next iteration
                    else if (bit_counter == 3'd5) begin
                        base <= base_squared;
                    end
                    
                    // Increment bit counter
                    bit_counter <= bit_counter + 3'd1;
                    
                    // Transition to DONE after 8 cycles
                    if (bit_counter == 3'd7) begin
                        state <= DONE;
                        result <= current_result;
                    end
                end
                
                DONE: begin
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule