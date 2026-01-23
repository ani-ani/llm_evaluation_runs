module signed_binary_converter (
    input clk,
    input rst_n,
    input start,
    input [15:0] binary_in,
    output reg [17:0] signed_out,
    output reg [4:0] length,
    output reg done
);

    // State encoding
    localparam IDLE = 2'b00;
    localparam PROCESSING = 2'b01;
    localparam DONE = 2'b10;

    reg [1:0] state, next_state;
    reg [4:0] count, next_count; // Counter for 18 cycles (0 to 17)
    reg carry, next_carry;
    reg [17:0] next_signed_out;
    reg [4:0] next_length;
    reg next_done;
    reg [15:0] stored_binary; // Store input to free up port
    reg [15:0] next_stored_binary;

    // State transition and output logic
    always @(*) begin
        next_state = state;
        next_count = count;
        next_carry = carry;
        next_signed_out = signed_out;
        next_length = length;
        next_done = done;
        next_stored_binary = stored_binary;

        case (state)
            IDLE: begin
                next_done = 1'b0;
                if (start) begin
                    next_state = PROCESSING;
                    next_count = 5'd0;
                    next_carry = 1'b0;
                    next_stored_binary = binary_in;
                    next_signed_out = 18'd0;
                    next_length = 5'd0;
                end
            end

            PROCESSING: begin
                if (count < 16) begin
                    // Process bits 0 to 15 from stored_binary
                    // bit index is count[3:0] (0 to 15)
                    // current bit b_i = stored_binary[count[3:0]]
                    case ({stored_binary[count[3:0]], carry})
                        2'b00: begin // 0 + 0
                            next_signed_out[count +: 2] = 2'b00; // Output 0
                            next_carry = 1'b0;
                        end
                        2'b01: begin // 0 + 1
                            next_signed_out[count +: 2] = 2'b01; // Output +1
                            next_carry = 1'b0;
                        end
                        2'b10: begin // 1 + 0
                            next_signed_out[count +: 2] = 2'b01; // Output +1
                            next_carry = 1'b0;
                        end
                        2'b11: begin // 1 + 1 -> 2
                            next_signed_out[count +: 2] = 2'b11; // Output -1
                            next_carry = 1'b1;
                        end
                    endcase
                    
                    // Update length (max check)
                    if (count >= next_length) begin
                        if (next_signed_out[count +: 2] != 2'b00) begin
                            next_length = count + 1;
                        end
                    end
                    
                    next_count = count + 1;
                end else begin
                    // Process extra bits for carry (count 16 and 17)
                    // b_i is implicitly 0
                    case (carry)
                        1'b0: begin // 0 + 0
                            next_signed_out[count +: 2] = 2'b00;
                            next_carry = 1'b0;
                        end
                        1'b1: begin // 0 + 1
                            next_signed_out[count +: 2] = 2'b01;
                            next_carry = 1'b0;
                        end
                    endcase
                    
                    if (count >= next_length) begin
                        if (next_signed_out[count +: 2] != 2'b00) begin
                            next_length = count + 1;
                        end
                    end

                    if (count == 17) begin
                        next_state = DONE;
                        next_done = 1'b1;
                    end else begin
                        next_count = count + 1;
                    end
                end
            end

            DONE: begin
                // Wait for reset or start
                if (start) begin
                    next_state = PROCESSING;
                    next_count = 5'd0;
                    next_carry = 1'b0;
                    next_stored_binary = binary_in;
                    next_signed_out = 18'd0;
                    next_length = 5'd0;
                    next_done = 1'b0;
                end
            end
        endcase
    end

    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            count <= 5'd0;
            carry <= 1'b0;
            signed_out <= 18'd0;
            length <= 5'd0;
            done <= 1'b0;
            stored_binary <= 16'd0;
        end else begin
            state <= next_state;
            count <= next_count;
            carry <= next_carry;
            signed_out <= next_signed_out;
            length <= next_length;
            done <= next_done;
            stored_binary <= next_stored_binary;
        end
    end

endmodule
