module hex_key_counter(
    input clk,
    input rst_n,
    input start,
    input [7:0] char_in,
    input [4:0] len,
    output reg [4:0] result,
    output reg done,
    output reg [3:0] char_addr
);

    // State declarations
    localparam [1:0] IDLE        = 2'd0;
    localparam [1:0] PROCESSING  = 2'd1;
    localparam [1:0] DONE_STATE  = 2'd2;
    
    reg [1:0] state;
    reg [3:0] addr_counter;
    
    // Prime hex digit ASCII values
    localparam [7:0] PRIME_2 = 8'h32;  // '2'
    localparam [7:0] PRIME_3 = 8'h33;  // '3'
    localparam [7:0] PRIME_5 = 8'h35;  // '5'
    localparam [7:0] PRIME_7 = 8'h37;  // '7'
    localparam [7:0] PRIME_B = 8'h42;  // 'B'
    localparam [7:0] PRIME_D = 8'h44;  // 'D'
    
    wire is_prime;
    assign is_prime = (char_in == PRIME_2) ||
                     (char_in == PRIME_3) ||
                     (char_in == PRIME_5) ||
                     (char_in == PRIME_7) ||
                     (char_in == PRIME_B) ||
                     (char_in == PRIME_D);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 5'd0;
            done <= 1'b0;
            char_addr <= 4'd0;
            addr_counter <= 4'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= PROCESSING;
                        result <= 5'd0;
                        char_addr <= 4'd0;
                        addr_counter <= 4'd0;
                    end
                end
                
                PROCESSING: begin
                    // Read current character and check if prime
                    if (is_prime) begin
                        result <= result + 5'd1;
                    end
                    
                    // Increment address
                    addr_counter <= addr_counter + 4'd1;
                    char_addr <= addr_counter + 4'd1;
                    
                    // Check if done with string
                    if ((addr_counter + 4'd1) >= len) begin
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