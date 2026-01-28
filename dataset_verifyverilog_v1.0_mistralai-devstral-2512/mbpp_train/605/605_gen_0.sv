module prime_checker (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] num_in,
    output reg result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE          = 2'd0;
    localparam [1:0] CHECK_SPECIAL = 2'd1;
    localparam [1:0] ITERATE       = 2'd2;
    localparam [1:0] DONE_STATE    = 2'd3;

    // Internal registers
    reg [1:0] state;
    reg [7:0] num_reg;
    reg [7:0] divisor;
    reg [7:0] remainder;
    reg [7:0] cycle_count;
    reg [7:0] i;
    reg is_prime;
    reg start_captured;

    // Maximum cycle count to prevent infinite loops
    localparam [7:0] MAX_CYCLES = 8'd200;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            num_reg <= 8'd0;
            divisor <= 8'd0;
            remainder <= 8'd0;
            cycle_count <= 8'd0;
            i <= 8'd0;
            is_prime <= 1'b0;
            result <= 1'b0;
            done <= 1'b0;
            start_captured <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start && !start_captured) begin
                        num_reg <= num_in;
                        start_captured <= 1'b1;
                        state <= CHECK_SPECIAL;
                    end else if (!start) begin
                        start_captured <= 1'b0;
                    end
                end

                CHECK_SPECIAL: begin
                    cycle_count <= cycle_count + 8'd1;
                    is_prime <= 1'b0;
                    
                    // Check for numbers < 2
                    if (num_reg < 8'd2) begin
                        is_prime <= 1'b0;
                        state <= DONE_STATE;
                    end
                    // Check for number 2
                    else if (num_reg == 8'd2) begin
                        is_prime <= 1'b1;
                        state <= DONE_STATE;
                    end
                    // Check for even numbers > 2
                    else if (num_reg[0] == 1'b0) begin
                        is_prime <= 1'b0;
                        state <= DONE_STATE;
                    end
                    else begin
                        // Initialize divisor for trial division
                        divisor <= 8'd3;
                        state <= ITERATE;
                    end
                end

                ITERATE: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Check if we've exceeded max cycles
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= DONE_STATE;
                    end
                    else begin
                        // Check if divisor squared exceeds num_reg (divisor > sqrt(num_reg))
                        // Since we're using 8-bit, we approximate by checking divisor*divisor > num_reg
                        // Compute divisor*divisor via iterative addition
                        reg [7:0] divisor_squared;
                        reg [7:0] temp_divisor;
                        reg [7:0] j;
                        
                        temp_divisor <= divisor;
                        divisor_squared <= 8'd0;
                        for (j = 0; j < 8; j = j + 1) begin
                            if (temp_divisor[0]) begin
                                divisor_squared <= divisor_squared + divisor;
                            end
                            temp_divisor <= temp_divisor >> 1;
                        end
                        
                        if (divisor_squared > num_reg) begin
                            is_prime <= 1'b1;
                            state <= DONE_STATE;
                        end
                        else begin
                            // Compute remainder = num_reg % divisor
                            remainder <= num_reg;
                            for (i = 0; i < 8; i = i + 1) begin
                                if (remainder >= divisor) begin
                                    remainder <= remainder - divisor;
                                end
                            end
                            
                            if (remainder == 8'd0) begin
                                is_prime <= 1'b0;
                                state <= DONE_STATE;
                            end
                            else begin
                                // Increment divisor by 2 (only check odd divisors)
                                divisor <= divisor + 8'd2;
                            end
                        end
                    end
                end

                DONE_STATE: begin
                    result <= is_prime;
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule