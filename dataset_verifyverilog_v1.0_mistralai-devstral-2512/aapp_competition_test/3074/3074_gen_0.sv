module subset_counter(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] data_in,
    input wire [3:0] len,
    output reg [31:0] result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE    = 2'd0;
    localparam [1:0] LOAD    = 2'd1;
    localparam [1:0] COMPUTE = 2'd2;
    localparam [1:0] OUTPUT  = 2'd3;

    // Constants
    localparam [31:0] MOD = 32'd1000000007;
    localparam [3:0] MAX_LEN = 4'd16;

    // Internal registers
    reg [1:0] state, next_state;
    reg [3:0] index;
    reg [3:0] digit_count;
    reg [3:0] current_digit;
    reg [3:0] digits [0:15];
    reg [31:0] count_mod3 [0:2];
    reg [31:0] new_counts [0:2];
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd100;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            index <= 4'd0;
            digit_count <= 4'd0;
            current_digit <= 4'd0;
            result <= 32'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            
            // Initialize digits array
            integer i;
            for (i = 0; i < 16; i = i + 1) begin
                digits[i] <= 4'd0;
            end
            
            // Initialize count_mod3
            count_mod3[0] <= 32'd0;
            count_mod3[1] <= 32'd0;
            count_mod3[2] <= 32'd0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        next_state = LOAD;
                    end else begin
                        next_state = IDLE;
                    end
                end
                
                LOAD: begin
                    if (index < len) begin
                        // Store digit as integer (0-9)
                        digits[index] <= data_in[7:0] - 8'd48;
                        index <= index + 4'd1;
                        next_state = LOAD;
                    end else begin
                        index <= 4'd0;
                        digit_count <= len;
                        next_state = COMPUTE;
                    end
                end
                
                COMPUTE: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    if (index < digit_count) begin
                        current_digit <= digits[index];
                        
                        // Initialize new_counts with current counts
                        new_counts[0] <= count_mod3[0];
                        new_counts[1] <= count_mod3[1];
                        new_counts[2] <= count_mod3[2];
                        
                        // Handle digit 0 separately
                        if (current_digit == 4'd0) begin
                            // The subset {0} is valid
                            new_counts[0] <= (new_counts[0] + 32'd1) % MOD;
                        end
                        
                        // Process all possible remainders
                        integer r;
                        for (r = 0; r < 3; r = r + 1) begin
                            reg [1:0] new_rem;
                            new_rem <= (r + (current_digit % 3)) % 3;
                            new_counts[new_rem] <= (new_counts[new_rem] + count_mod3[r]) % MOD;
                        end
                        
                        // Update counts
                        count_mod3[0] <= new_counts[0];
                        count_mod3[1] <= new_counts[1];
                        count_mod3[2] <= new_counts[2];
                        
                        index <= index + 4'd1;
                        next_state = COMPUTE;
                    end else begin
                        // Final result is count_mod3[0]
                        result <= count_mod3[0];
                        next_state = OUTPUT;
                    end
                end
                
                OUTPUT: begin
                    done <= 1'b1;
                    next_state = IDLE;
                end
                
                default: begin
                    next_state = IDLE;
                    done <= 1'b0;
                end
            endcase
        end
    end

endmodule