module palindrome_counter (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [9:0] n_in,
    output reg [8:0] even_count,
    output reg [8:0] odd_count,
    output reg done
);

    // State definitions
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] COMPUTE = 2'd1;
    localparam [1:0] COMPLETE = 2'd2;

    // Internal registers
    reg [1:0] state, next_state;
    reg [9:0] current_number;
    reg [9:0] reversed_number;
    reg [9:0] temp_number;
    reg [3:0] digit_count;
    reg [9:0] digit_values [0:3];
    reg [9:0] digit_positions [0:3];
    reg [9:0] i;
    reg [7:0] cycle_counter;
    localparam [7:0] MAX_CYCLES = 8'd1200;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            even_count <= 9'd0;
            odd_count <= 9'd0;
            done <= 1'b0;
            current_number <= 10'd0;
            reversed_number <= 10'd0;
            temp_number <= 10'd0;
            digit_count <= 4'd0;
            i <= 10'd0;
            cycle_counter <= 8'd0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_counter <= 8'd0;
                    if (start) begin
                        next_state <= COMPUTE;
                        i <= 10'd1;
                        even_count <= 9'd0;
                        odd_count <= 9'd0;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                COMPUTE: begin
                    cycle_counter <= cycle_counter + 8'd1;
                    
                    // Extract digits
                    temp_number <= current_number;
                    digit_count <= 4'd0;
                    
                    // Digit extraction loop (unrolled for synthesis)
                    digit_values[0] <= temp_number % 10;
                    digit_positions[0] <= digit_values[0];
                    temp_number <= temp_number / 10;
                    
                    digit_values[1] <= temp_number % 10;
                    digit_positions[1] <= digit_values[1];
                    temp_number <= temp_number / 10;
                    
                    digit_values[2] <= temp_number % 10;
                    digit_positions[2] <= digit_values[2];
                    temp_number <= temp_number / 10;
                    
                    digit_values[3] <= temp_number % 10;
                    digit_positions[3] <= digit_values[3];
                    
                    // Build reversed number
                    reversed_number <= digit_values[0] * 1000 + 
                                     digit_values[1] * 100 + 
                                     digit_values[2] * 10 + 
                                     digit_values[3];
                    
                    // Check if palindrome
                    if (reversed_number == current_number) begin
                        // Check parity
                        if (current_number[0] == 1'b0) begin
                            even_count <= even_count + 9'd1;
                        end else begin
                            odd_count <= odd_count + 9'd1;
                        end
                    end
                    
                    // Increment counter
                    i <= i + 10'd1;
                    current_number <= i;
                    
                    // Check completion
                    if (i == n_in || cycle_counter >= MAX_CYCLES) begin
                        next_state <= COMPLETE;
                    end else begin
                        next_state <= COMPUTE;
                    end
                end

                COMPLETE: begin
                    done <= 1'b1;
                    next_state <= IDLE;
                end

                default: next_state <= IDLE;
            endcase
        end
    end

endmodule